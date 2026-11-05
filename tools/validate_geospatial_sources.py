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
    args = parser.parse_args()
    try:
        osm = json.loads(args.osm.read_text(encoding="utf-8"))
        terrain = json.loads(args.terrain.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}")
        return 2
    osm_errors = validate_osm(osm)
    terrain_errors = validate_terrain(terrain)
    for error in osm_errors:
        print("ERROR OSM:", error)
    for error in terrain_errors:
        print("ERROR TERRAIN:", error)
    print(
        "Geospatial source validation: "
        f"{len(osm_errors) + len(terrain_errors)} error(s); "
        f"{len(osm.get('features', []))} OSM features; "
        f"{len(terrain.get('contours', []))} contour levels."
    )
    return 1 if osm_errors or terrain_errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
