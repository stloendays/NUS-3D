#!/usr/bin/env python3
"""Detect 2-D overlaps between conceptual paths and OSM polygons.

These are map-plane overlaps, NEVER certified physical obstructions: arcade
passages, different floors, terraces and other SRC routes need real-world review.
"""
from __future__ import annotations
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
from tools.audit_route_clearance import _project, _segment_gap, _point_segment_distance


def inside_polygon(point, ring):
    x, y = point
    inside = False
    for a, b in zip(ring, ring[1:]):
        if _point_segment_distance(point, a, b) < 1e-8:
            return True
        if (a[1] > y) != (b[1] > y):
            crossing_x = a[0] + (y - a[1]) * (b[0] - a[0]) / (b[1] - a[1])
            if crossing_x > x:
                inside = not inside
    return inside


def segment_ring_gap(a, b, ring):
    if inside_polygon(a, ring) or inside_polygon(b, ring):
        return 0.0
    return min(_segment_gap(a, b, c, d) for c, d in zip(ring, ring[1:]))


def audit_osm_route(layout, osm):
    reference = layout["spatial_reference"]
    lon0, lat0 = reference["origin_lon"], reference["origin_lat"]
    rings = [(f["id"], f["osm_way_id"],
              [_project(point, lon0, lat0) for point in f["coordinates_lonlat"]])
             for f in osm["features"]]
    assessment = []
    for i, path in enumerate(layout["walkways"]):
        points = [_project(item, lon0, lat0) for item in path["lonlat"]]
        for j, (a, b) in enumerate(zip(points, points[1:])):
            for name, osm_id, ring in rings:
                gap = segment_ring_gap(a, b, ring)
                assessment.append({"walkway_index": i, "segment_index": j,
                                   "osm_building": name, "osm_way_id": osm_id,
                                   "gap_m": round(gap, 3),
                                   "plan_view_intersection": gap < 1e-7})
    flagged = [row for row in assessment if row["plan_view_intersection"]]
    return {"schema_version": 1,
            "status": "2D-OSM-footprint-overlap-NOT-pedestrian-blockage-or-accessibility",
            "source": osm["source_api_url"], "retrieved_at_utc": osm["snapshot_retrieved_utc"],
            "license": "ODbL 1.0", "attribution": "OpenStreetMap contributors",
            "note": "A polygon overlap does not prove physical obstruction. Evaluate floor levels, arcades, entrances and access on-site. Do not automatically modify walkways.",
            "segment_vs_polygon_tests": len(assessment),
            "plan_view_intersections": len(flagged),
            "intersections": flagged, "assessments": assessment}


def main():
    layout = json.loads((ROOT / "godot/data/utown_core.json").read_text(encoding="utf-8"))
    source = json.loads((ROOT / "godot/data/osm_p0_reference.json").read_text(encoding="utf-8"))
    report = audit_osm_route(layout, source)
    for row in report["intersections"]:
        print(f"REVIEW walkway[{row['walkway_index']}] part[{row['segment_index']}] "
              f"overlaps OSM {row['osm_building']} way/{row['osm_way_id']} in 2-D")
    print(f"OSM review: {report['segment_vs_polygon_tests']} tests, "
          f"{report['plan_view_intersections']} plan-view overlaps, "
          "NOT confirmed physical obstructions.")
    target = ROOT / "build/osm-route-overlap.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
