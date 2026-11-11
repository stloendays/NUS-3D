#!/usr/bin/env python3
"""Validate illustrative campus-life props against the current UTown proxy geometry."""
from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
LIFE_PATH = ROOT / "godot/data/campus_life.json"
LAYOUT_PATH = ROOT / "godot/data/utown_core.json"
EXPECTED_DISCOVERIES = {
    "GREEN": ("TOWN_GREEN", "GREEN"),
    "ERC": ("ERC", "ERC"),
    "SRC": ("SRC", "SRC"),
    "PLAZA": ("TOWN_PLAZA", "PLAZA"),
}
ALLOWED_TYPES = {"bench", "lamp", "guide"}


def local_xy(lon: float, lat: float, spatial: dict[str, Any]) -> tuple[float, float]:
    east = (lon - float(spatial["origin_lon"])) * 111320.0 * math.cos(math.radians(float(spatial["origin_lat"])))
    north = (lat - float(spatial["origin_lat"])) * 110574.0
    return east, -north


def point_in_polygon(point: tuple[float, float], polygon: list[tuple[float, float]]) -> bool:
    x, y = point
    inside = False
    for index, a in enumerate(polygon):
        b = polygon[index - 1]
        if (a[1] > y) != (b[1] > y):
            crossing_x = (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]
            if x < crossing_x:
                inside = not inside
    return inside


def distance_to_segment(point: tuple[float, float], start: tuple[float, float], end: tuple[float, float]) -> float:
    dx, dy = end[0] - start[0], end[1] - start[1]
    length_sq = dx * dx + dy * dy
    if length_sq < 1e-12:
        return math.dist(point, start)
    t = max(0.0, min(1.0, ((point[0] - start[0]) * dx + (point[1] - start[1]) * dy) / length_sq))
    return math.hypot(point[0] - start[0] - t * dx, point[1] - start[1] - t * dy)


def prop_clearance(point: tuple[float, float], layout: dict[str, Any], margin: float = 2.5) -> tuple[bool, str]:
    spatial = layout["spatial_reference"]
    for building in layout.get("buildings", []):
        centre = local_xy(float(building["lon"]), float(building["lat"]), spatial)
        relative_x, relative_z = point[0] - centre[0], point[1] - centre[1]
        angle = math.radians(float(building.get("rotation_deg", 0.0)))
        local_x = math.cos(angle) * relative_x - math.sin(angle) * relative_z
        local_z = math.sin(angle) * relative_x + math.cos(angle) * relative_z
        for part in building.get("parts", []):
            half_w = float(part.get("w", 24.0)) * 0.5 + margin
            half_d = float(part.get("d", 24.0)) * 0.5 + margin
            if abs(local_x - float(part.get("dx", 0.0))) <= half_w and abs(local_z + float(part.get("dn", 0.0))) <= half_d:
                return False, str(building.get("id", "building"))
    return True, ""


def validate_campus_life(life: Any, layout: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(life, dict) or not isinstance(layout, dict):
        return ["campus-life and layout roots must be JSON objects"]
    if life.get("schema_version") != 1:
        errors.append("campus-life schema_version must be 1")
    if life.get("status") != "illustrative_campus_life_not_field_verified":
        errors.append("campus-life props must remain labelled illustrative and not field verified")
    if "not claims" not in str(life.get("placement_policy", "")):
        errors.append("campus-life placement policy must disclose that props are not mapped real amenities")

    spatial = layout.get("spatial_reference", {})
    green = layout.get("green", {})
    polygon = [local_xy(float(p[0]), float(p[1]), spatial) for p in green.get("polygon_lonlat", [])]
    if len(polygon) < 3:
        return errors + ["Town Green polygon is missing"]
    paths = [
        [local_xy(float(p[0]), float(p[1]), spatial) for p in way.get("lonlat", [])]
        for way in layout.get("walkways", [])
    ]

    furniture = life.get("furniture")
    if not isinstance(furniture, list) or len(furniture) < 6:
        errors.append("campus-life requires at least six illustrative furniture placements")
        furniture = []
    seen_props: set[str] = set()
    for index, item in enumerate(furniture):
        path = f"furniture[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{path} must be an object")
            continue
        item_id = str(item.get("id", ""))
        if not item_id or item_id in seen_props:
            errors.append(f"{path} requires a unique non-empty id")
        seen_props.add(item_id)
        if item.get("type") not in ALLOWED_TYPES:
            errors.append(f"{path} has unsupported prop type")
        try:
            lon, lat = float(item["lon"]), float(item["lat"])
        except (KeyError, TypeError, ValueError):
            errors.append(f"{path} requires numeric WGS84 coordinates")
            continue
        if not math.isfinite(lon) or not math.isfinite(lat) or not -180 <= lon <= 180 or not -90 <= lat <= 90:
            errors.append(f"{path} contains invalid WGS84 coordinates")
            continue
        point = local_xy(lon, lat, spatial)
        if not point_in_polygon(point, polygon):
            errors.append(f"{path} is outside the current Town Green polygon")
        is_clear, building_id = prop_clearance(point, layout)
        if not is_clear:
            errors.append(f"{path} intrudes into the {building_id} proxy safety margin")
        required_path_clearance = 4.0
        for line in paths:
            for segment_index in range(len(line) - 1):
                clearance = distance_to_segment(point, line[segment_index], line[segment_index + 1])
                if clearance < required_path_clearance:
                    errors.append(f"{path} is only {clearance:.1f} m from a conceptual walkway centreline")
                    break

    discoveries = life.get("discoveries")
    if not isinstance(discoveries, list):
        return errors + ["discoveries must be an array"]
    by_id = {str(item.get("id", "")): item for item in discoveries if isinstance(item, dict)}
    if set(by_id) != set(EXPECTED_DISCOVERIES):
        errors.append("discoveries must contain exactly GREEN, ERC, SRC and PLAZA")
    loop_by_id = {str(item.get("id", "")): item for item in layout.get("loop", [])}
    for discovery_id, (landmark_id, loop_id) in EXPECTED_DISCOVERIES.items():
        item = by_id.get(discovery_id)
        if item is None:
            continue
        if item.get("landmark_id") != landmark_id:
            errors.append(f"discovery {discovery_id} has the wrong landmark_id")
        if not str(item.get("description", "")).strip():
            errors.append(f"discovery {discovery_id} requires a useful description")
        if not item.get("source_urls") or any(not str(url).startswith("https://") for url in item.get("source_urls", [])):
            errors.append(f"discovery {discovery_id} requires HTTPS source links")
        loop_item = loop_by_id.get(loop_id)
        if loop_item is None:
            errors.append(f"discovery {discovery_id} has no matching conceptual route stop")
            continue
        point = local_xy(float(item["lon"]), float(item["lat"]), spatial)
        route_point = local_xy(float(loop_item["lon"]), float(loop_item["lat"]), spatial)
        if math.dist(point, route_point) > 0.25:
            errors.append(f"discovery {discovery_id} does not align with its route stop")

    return errors


def main() -> int:
    try:
        life = json.loads(LIFE_PATH.read_text(encoding="utf-8"))
        layout = json.loads(LAYOUT_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}")
        return 2
    errors = validate_campus_life(life, layout)
    for error in errors:
        print("ERROR:", error)
    print(f"Campus-life validation: {len(errors)} error(s); {len(life.get('furniture', []))} props; {len(life.get('discoveries', []))} discovery points.")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
