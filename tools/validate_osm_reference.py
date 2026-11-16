#!/usr/bin/env python3
"""Validate source-frozen OSM outlines used ONLY as debug overlays."""
from __future__ import annotations
import json
import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
from tools.fetch_osm_footprints import polygon_area


def validate_snapshot(document: dict, layout: dict) -> list[str]:
    errors: list[str] = []
    if document.get("schema_version") != 1:
        errors.append("expected schema_version 1")
    if document.get("status") != "public-OSM-reference-only-not-surveyed":
        errors.append("missing explicit unverified status")
    if document.get("license") != "ODbL 1.0" or "OpenStreetMap" not in document.get("attribution", ""):
        errors.append("missing ODbL provenance")
    if not document.get("snapshot_retrieved_utc") or not document.get("source_api_url", "").startswith("https://api.openstreetmap.org/"):
        errors.append("missing source snapshot metadata")
    if document.get("use") != "debug-only-unverified-outline-comparison; no collision, no elevation, no route authority":
        errors.append("OSM must remain a debug overlay, not collision or route authority")
    if document.get("coordinate_reference") != "EPSG:4326 / WGS84, [longitude, latitude]":
        errors.append("expected WGS84 axis order declaration")
    entries = document.get("features", [])
    if not isinstance(entries, list) or len(entries) != 2:
        return errors + ["exactly ERC/SRC reference features required"]
    seen: set[str] = set()
    ids: set[int] = set()
    names = {b["id"] for b in layout["buildings"]}
    lon0, lat0 = layout["spatial_reference"]["origin_lon"], layout["spatial_reference"]["origin_lat"]
    half_w, half_d = (d / 2 for d in layout["ground_size_m"])
    for index, entry in enumerate(entries):
        root = f"features[{index}]"
        name = entry.get("id")
        if name in seen or name not in ("ERC", "SRC") or name not in names:
            errors.append(f"{root}: duplicate/missing/unknown landmark")
        seen.add(name)
        osm_id = entry.get("osm_way_id")
        if not isinstance(osm_id, int) or isinstance(osm_id, bool) or osm_id in ids or osm_id <= 0:
            errors.append(f"{root}: invalid duplicate OSM way")
        ids.add(osm_id)
        if entry.get("source_url") != f"https://www.openstreetmap.org/way/{osm_id}":
            errors.append(f"{root}: bad source way URL")
        if not isinstance(entry.get("osm_version"), int) or entry["osm_version"] < 1 or not entry.get("osm_edit_timestamp"):
            errors.append(f"{root}: missing OSM version/date")
        points = entry.get("coordinates_lonlat")
        if not isinstance(points, list) or len(points) < 4 or points[0] != points[-1]:
            errors.append(f"{root}: closed OSM geometry required")
            continue
        for lonlat in points:
            if not isinstance(lonlat, list) or len(lonlat) != 2 or not all(isinstance(x, (int, float)) and math.isfinite(x) for x in lonlat):
                errors.append(f"{root}: invalid [lon,lat] point")
                break
            lon, lat = lonlat
            if not (-180 <= lon <= 180 and -90 <= lat <= 90):
                errors.append(f"{root}: invalid WGS84 coordinate")
            x = (lon - lon0) * 111320.0 * math.cos(math.radians(lat0))
            z = -(lat - lat0) * 110574.0
            if abs(x) >= half_w - 3 or abs(z) >= half_d - 3:
                errors.append(f"{root}: outline outside current ground extent")
                break
        measured = polygon_area(points)
        if measured < 100 or abs(measured - float(entry.get("area_m2_approx", 0))) > 0.1:
            errors.append(f"{root}: area does not match frozen source coordinates")
    if seen != {"ERC", "SRC"}:
        errors.append("missing expected P0 building IDs")
    return errors


def main() -> int:
    data = json.loads((ROOT / "godot/data/osm_p0_reference.json").read_text(encoding="utf-8"))
    layout = json.loads((ROOT / "godot/data/utown_core.json").read_text(encoding="utf-8"))
    errors = validate_snapshot(data, layout)
    for error in errors:
        print("ERROR", error)
    print(f"OSM snapshot: {len(data['features'])} polygons; {len(errors)} error(s); source ODbL; overlay only.")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
