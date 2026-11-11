#!/usr/bin/env python3
"""Validate versioned OSM geometry and contour reference data; not survey accuracy."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[1]
OSM_DEFAULT = REPO / "godot/data/osm_utown_snapshot.json"
TERRAIN_DEFAULT = REPO / "godot/data/terrain_contours.json"
SHELL_PROFILES_DEFAULT = REPO / "godot/data/osm_shell_profiles.json"


def _valid_lonlat(pair: Any) -> bool:
    if not isinstance(pair, list) or len(pair) < 2:
        return False
    try:
        lon, lat = float(pair[0]), float(pair[1])
    except (TypeError, ValueError):
        return False
    return math.isfinite(lon) and math.isfinite(lat) and -180 <= lon <= 180 and -90 <= lat <= 90


def validate_osm(document: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(document, dict):
        return ["OSM root must be a JSON object"]
    if document.get("schema_version") != 1:
        errors.append("OSM schema_version must be 1")
    if "OpenStreetMap" not in str(document.get("source", "")):
        errors.append("OSM source attribution is missing")
    if "OpenStreetMap contributors" not in str(document.get("attribution", "")):
        errors.append("OSM contributor attribution is required")
    if "ODbL" not in str(document.get("licence", "")):
        errors.append("OSM ODbL licence notice is required")

    boundary = document.get("campus_boundary")
    if not isinstance(boundary, dict):
        errors.append("campus_boundary must be an object")
    else:
        coordinates = boundary.get("coordinates")
        if not isinstance(coordinates, list) or len(coordinates) < 4:
            errors.append("campus boundary requires at least four coordinates")
        elif any(not _valid_lonlat(pair) for pair in coordinates):
            errors.append("campus boundary contains an invalid WGS84 coordinate")
        elif coordinates[0] != coordinates[-1]:
            errors.append("campus boundary polygon must be closed")

    features = document.get("features")
    if not isinstance(features, list) or not features:
        return errors + ["OSM features must be a non-empty array"]
    seen: set[tuple[str, int]] = set()
    counts = {"building": 0, "roof": 0, "path": 0, "landcover": 0}
    for index, feature in enumerate(features):
        path = f"features[{index}]"
        if not isinstance(feature, dict):
            errors.append(f"{path} must be an object")
            continue
        try:
            key = (str(feature.get("osm_type", "")), int(feature.get("osm_id")))
        except (TypeError, ValueError):
            errors.append(f"{path} requires a numeric OSM ID")
            continue
        if key in seen:
            errors.append(f"{path} duplicates OSM element {key}")
        seen.add(key)
        kind = str(feature.get("feature_type", ""))
        if kind in counts:
            counts[kind] += 1
        coordinates = feature.get("coordinates")
        if not isinstance(coordinates, list) or len(coordinates) < 2:
            errors.append(f"{path} requires at least two coordinates")
            continue
        if any(not _valid_lonlat(pair) for pair in coordinates):
            errors.append(f"{path} contains an invalid WGS84 coordinate")
            continue
        geometry_type = str(feature.get("geometry_type", ""))
        if kind in {"building", "roof"}:
            if geometry_type != "Polygon":
                errors.append(f"{path} building/roof geometry must be Polygon")
            if coordinates[0] != coordinates[-1]:
                errors.append(f"{path} building/roof ring must be closed")
            if feature.get("geometry_status") != "complete":
                errors.append(f"{path} building/roof geometry must be complete")
        if kind == "path" and geometry_type != "LineString":
            errors.append(f"{path} path geometry must be LineString")
        if kind not in counts:
            errors.append(f"{path} has unsupported feature_type {kind!r}")

    summary = document.get("summary", {})
    for key, value in counts.items():
        if summary.get(f"{key}_count") != value:
            errors.append(f"summary {key}_count does not match feature records")
    if summary.get("selected_feature_count") != len(features):
        errors.append("summary selected_feature_count does not match feature records")
    return errors



def validate_osm_shell_profiles(osm_document: Any, profiles_document: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(profiles_document, dict):
        return ["OSM shell profiles root must be a JSON object"]
    if profiles_document.get("schema_version") != 1:
        errors.append("OSM shell profiles schema_version must be 1")
    if profiles_document.get("status") != "estimated_extrusion_not_surveyed":
        errors.append("OSM shell profiles must remain labelled as estimated and not surveyed")
    if "Visual-only shell" not in str(profiles_document.get("collision_policy", "")):
        errors.append("OSM shells must remain visual-only until collision review")
    if "No vertical offset" not in str(profiles_document.get("vertical_offset_policy", "")):
        errors.append("OSM layer tags must not be interpreted as vertical offsets")

    source_features = osm_document.get("features", []) if isinstance(osm_document, dict) else []
    by_id = {int(item.get("osm_id", -1)): item for item in source_features if isinstance(item, dict)}
    buildings = profiles_document.get("buildings")
    if not isinstance(buildings, dict):
        return errors + ["OSM shell profiles buildings must be an object"]
    expected = {"ERC": 124549217, "SRC": 125774787}
    if set(buildings) != set(expected):
        errors.append("OSM shell profiles must contain exactly ERC and SRC")
    for building_id, expected_way_id in expected.items():
        profile = buildings.get(building_id)
        if not isinstance(profile, dict):
            errors.append(f"{building_id} shell profile is missing")
            continue
        try:
            way_id = int(profile.get("osm_way_id"))
            levels = int(profile.get("osm_levels"))
            pitch = float(profile.get("storey_pitch_m"))
            height = float(profile.get("height_m"))
        except (TypeError, ValueError):
            errors.append(f"{building_id} shell profile requires numeric way ID, levels, pitch and height")
            continue
        if way_id != expected_way_id:
            errors.append(f"{building_id} shell profile points to the wrong OSM way")
        feature = by_id.get(way_id)
        if feature is None:
            errors.append(f"{building_id} OSM footprint {way_id} is missing from the snapshot")
            continue
        if feature.get("landmark_id") != building_id:
            errors.append(f"{building_id} OSM footprint landmark link is inconsistent")
        if feature.get("geometry_type") != "Polygon" or feature.get("geometry_status") != "complete":
            errors.append(f"{building_id} OSM footprint must be a complete polygon")
        coordinates = feature.get("coordinates", [])
        if len(coordinates) < 4 or coordinates[0] != coordinates[-1]:
            errors.append(f"{building_id} OSM footprint ring must be closed")
        if abs(_signed_ring_area(coordinates)) < 1e-10:
            errors.append(f"{building_id} OSM footprint area must be non-zero")
        try:
            source_levels = int(feature.get("tags", {}).get("building:levels"))
        except (TypeError, ValueError):
            source_levels = -1
        if levels != source_levels:
            errors.append(f"{building_id} estimated levels do not match the OSM building:levels tag")
        if pitch <= 0 or not math.isfinite(pitch):
            errors.append(f"{building_id} estimated storey pitch must be positive")
        if height <= 0 or not math.isfinite(height):
            errors.append(f"{building_id} estimated shell height must be positive")
        if abs(height - levels * pitch) > 0.01:
            errors.append(f"{building_id} shell height must equal levels × estimated storey pitch")
        if not str(profile.get("height_confidence", "")).startswith("estimated"):
            errors.append(f"{building_id} shell height must be labelled estimated")
        source_layer = feature.get("tags", {}).get("layer")
        if profile.get("osm_layer_tag") != source_layer:
            errors.append(f"{building_id} relative OSM layer tag was not preserved")
    return errors


def _signed_ring_area(coordinates: Any) -> float:
    if not isinstance(coordinates, list) or len(coordinates) < 4:
        return 0.0
    area = 0.0
    for index in range(len(coordinates) - 1):
        try:
            x1, y1 = float(coordinates[index][0]), float(coordinates[index][1])
            x2, y2 = float(coordinates[index + 1][0]), float(coordinates[index + 1][1])
        except (TypeError, ValueError, IndexError):
            return 0.0
        area += x1 * y2 - x2 * y1
    return area * 0.5

def validate_terrain(document: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(document, dict):
        return ["terrain root must be a JSON object"]
    if document.get("schema_version") != 1:
        errors.append("terrain schema_version must be 1")
    if document.get("status") != "planimetric_contour_reference_only":
        errors.append("terrain must remain marked as planimetric contour reference only")
    metadata = document.get("source_metadata", {})
    if metadata.get("contour_interval_m") != 5:
        errors.append("terrain contour interval must remain 5 m")
    if metadata.get("vertical_unit") != "metres":
        errors.append("terrain vertical unit must be metres")
    if "not specified" not in str(metadata.get("vertical_datum", "")).lower():
        errors.append("unknown vertical datum must remain explicitly disclosed")
    if "review required" not in str(metadata.get("license_status", "")).lower():
        errors.append("contour data reuse status must remain under review")
    if "Do not treat as a surveyed DEM" not in str(document.get("use_policy", "")):
        errors.append("terrain use policy must prohibit survey-grade DEM claims")

    contours = document.get("contours")
    if not isinstance(contours, list) or not contours:
        return errors + ["contours must be a non-empty array"]
    heights: set[int] = set()
    for index, contour in enumerate(contours):
        path = f"contours[{index}]"
        try:
            height = int(contour.get("height_m"))
        except (TypeError, ValueError):
            errors.append(f"{path} requires an integer height_m")
            continue
        if height <= 0 or height % 5 != 0:
            errors.append(f"{path} height_m must be a positive multiple of 5")
        if height in heights:
            errors.append(f"{path} duplicates contour height {height}")
        heights.add(height)
        paths = contour.get("paths")
        if not isinstance(paths, list) or not paths:
            errors.append(f"{path} requires at least one clipped line path")
            continue
        for line_index, line in enumerate(paths):
            if not isinstance(line, list) or len(line) < 2:
                errors.append(f"{path}.paths[{line_index}] requires at least two coordinates")
            elif any(not _valid_lonlat(pair) for pair in line):
                errors.append(f"{path}.paths[{line_index}] contains invalid WGS84 coordinates")
    if heights != {5, 10, 15, 20, 25}:
        errors.append("UTown reference must contain the five observed contour heights: 5, 10, 15, 20, 25 m")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--osm", type=Path, default=OSM_DEFAULT)
    parser.add_argument("--terrain", type=Path, default=TERRAIN_DEFAULT)
    parser.add_argument("--shell-profiles", type=Path, default=SHELL_PROFILES_DEFAULT)
    args = parser.parse_args()
    try:
        osm = json.loads(args.osm.read_text(encoding="utf-8"))
        terrain = json.loads(args.terrain.read_text(encoding="utf-8"))
        shell_profiles = json.loads(args.shell_profiles.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}")
        return 2
    osm_errors = validate_osm(osm)
    terrain_errors = validate_terrain(terrain)
    shell_errors = validate_osm_shell_profiles(osm, shell_profiles)
    for error in osm_errors:
        print("ERROR OSM:", error)
    for error in terrain_errors:
        print("ERROR TERRAIN:", error)
    for error in shell_errors:
        print("ERROR OSM SHELL:", error)
    print(
        "Geospatial source validation: "
        f"{len(osm_errors) + len(terrain_errors) + len(shell_errors)} error(s); "
        f"{len(osm.get('features', []))} OSM features; "
        f"{len(terrain.get('contours', []))} contour levels."
    )
    return 1 if osm_errors or terrain_errors or shell_errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
