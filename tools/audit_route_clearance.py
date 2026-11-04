#!/usr/bin/env python3
"""Audit conceptual UTown walking corridors against estimated building footprints.

All calculations are 2-D, in the same local metre coordinates as Godot.
A pass proves only proxy-collision clearance; it does not prove that a real,
accessible or level pedestrian connection exists on campus.
"""
from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
import math
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[1]
EPS = 1e-9
METRES_PER_DEG_LAT = 110574.0
METRES_PER_DEG_LON = 111320.0


@dataclass(frozen=True)
class SegmentAssessment:
    walkway_index: int
    segment_index: int
    nearest_building: str
    nearest_part: int
    gap_m: float
    required_m: float
    conflict: bool


def _sub(a: tuple[float, float], b: tuple[float, float]) -> tuple[float, float]:
    return a[0] - b[0], a[1] - b[1]


def _cross(a: tuple[float, float], b: tuple[float, float]) -> float:
    return a[0] * b[1] - a[1] * b[0]


def _dot(a: tuple[float, float], b: tuple[float, float]) -> float:
    return a[0] * b[0] + a[1] * b[1]


def _point_segment_distance(p: tuple[float, float], a: tuple[float, float],
                            b: tuple[float, float]) -> float:
    v = _sub(b, a)
    denom = _dot(v, v)
    t = max(0.0, min(1.0, _dot(_sub(p, a), v) / denom)) if denom > EPS else 0.0
    return math.hypot(p[0] - a[0] - t * v[0], p[1] - a[1] - t * v[1])


def _on_segment(p: tuple[float, float], a: tuple[float, float],
                b: tuple[float, float]) -> bool:
    return (abs(_cross(_sub(b, a), _sub(p, a))) <= EPS
            and min(a[0], b[0]) - EPS <= p[0] <= max(a[0], b[0]) + EPS
            and min(a[1], b[1]) - EPS <= p[1] <= max(a[1], b[1]) + EPS)


def _segments_intersect(a: tuple[float, float], b: tuple[float, float],
                        c: tuple[float, float], d: tuple[float, float]) -> bool:
    ab, cd = _sub(b, a), _sub(d, c)
    o1, o2 = _cross(ab, _sub(c, a)), _cross(ab, _sub(d, a))
    o3, o4 = _cross(cd, _sub(a, c)), _cross(cd, _sub(b, c))
    if ((o1 > EPS and o2 < -EPS or o1 < -EPS and o2 > EPS)
            and (o3 > EPS and o4 < -EPS or o3 < -EPS and o4 > EPS)):
        return True
    return (abs(o1) <= EPS and _on_segment(c, a, b)
            or abs(o2) <= EPS and _on_segment(d, a, b)
            or abs(o3) <= EPS and _on_segment(a, c, d)
            or abs(o4) <= EPS and _on_segment(b, c, d))


def _segment_gap(a: tuple[float, float], b: tuple[float, float],
                 c: tuple[float, float], d: tuple[float, float]) -> float:
    if _segments_intersect(a, b, c, d):
        return 0.0
    return min(_point_segment_distance(a, c, d),
               _point_segment_distance(b, c, d),
               _point_segment_distance(c, a, b),
               _point_segment_distance(d, a, b))


def _inside_convex_polygon(p: tuple[float, float],
                           vertices: list[tuple[float, float]]) -> bool:
    return all(_cross(_sub(vertices[(i + 1) % len(vertices)], vertices[i]),
                      _sub(p, vertices[i])) >= -EPS
               for i in range(len(vertices)))


def segment_footprint_gap(a: tuple[float, float], b: tuple[float, float],
                          vertices: list[tuple[float, float]]) -> float:
    """Exact planar distance between one centreline segment and a convex footprint."""
    if _inside_convex_polygon(a, vertices) or _inside_convex_polygon(b, vertices):
        return 0.0
    return min(_segment_gap(a, b, vertices[i], vertices[(i + 1) % len(vertices)])
               for i in range(len(vertices)))


def _project(pair: list[float], origin_lon: float,
             origin_lat: float) -> tuple[float, float]:
    lon, lat = pair
    return ((lon - origin_lon) * METRES_PER_DEG_LON * math.cos(math.radians(origin_lat)),
            -(lat - origin_lat) * METRES_PER_DEG_LAT)


def _rotate(x: float, z: float, angle: float) -> tuple[float, float]:
    """Match Godot Node3D rotation around +Y: X=east, -Z=north."""
    return math.cos(angle) * x + math.sin(angle) * z, -math.sin(angle) * x + math.cos(angle) * z


def footprint_vertices(building: dict[str, Any], part: dict[str, Any],
                       origin_lon: float, origin_lat: float) -> list[tuple[float, float]]:
    base_x, base_z = _project([building["lon"], building["lat"]], origin_lon, origin_lat)
    angle = math.radians(float(building.get("rotation_deg", 0)))
    dx, dz = _rotate(float(part.get("dx", 0)), -float(part.get("dn", 0)), angle)
    cx, cz = base_x + dx, base_z + dz
    half_w, half_d = float(part["w"]) / 2, float(part["d"]) / 2
    corners = [(-half_w, -half_d), (half_w, -half_d),
               (half_w, half_d), (-half_w, half_d)]
    return [(cx + _rotate(x, z, angle)[0], cz + _rotate(x, z, angle)[1])
            for x, z in corners]


def assess_layout(document: dict[str, Any],
                  margin_m: float = 0.75) -> list[SegmentAssessment]:
    """Return one assessment per route segment, with its nearest proxy part.

    Validate JSON structure separately with tools/validate_utown_data.py first.
    The caller must not interpret these 2-D checks as GIS/site accessibility.
    """
    if not math.isfinite(margin_m) or margin_m < 0:
        raise ValueError("margin_m must be a finite non-negative distance")
    reference = document["spatial_reference"]
    lon0, lat0 = float(reference["origin_lon"]), float(reference["origin_lat"])
    obstacles = [(str(b["id"]), i, footprint_vertices(b, part, lon0, lat0))
                 for b in document["buildings"] for i, part in enumerate(b["parts"])]
    if not obstacles:
        raise ValueError("no building massing available for route audit")
    results = []
    for walkway_idx, way in enumerate(document["walkways"]):
        line = [_project(pair, lon0, lat0) for pair in way["lonlat"]]
        required_m = float(way.get("width_m", 3.5)) / 2 + margin_m
        for segment_idx, (a, b) in enumerate(zip(line, line[1:])):
            nearest_id, nearest_part, nearest_gap = min(
                ((building_id, part_idx, segment_footprint_gap(a, b, polygon))
                 for building_id, part_idx, polygon in obstacles),
                key=lambda item: item[2])
            results.append(SegmentAssessment(
                walkway_idx, segment_idx, nearest_id, nearest_part,
                nearest_gap, required_m, nearest_gap < required_m - EPS))
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, default=REPO / "godot/data/utown_core.json")
    parser.add_argument("--margin-m", type=float, default=0.75)
    parser.add_argument("--strict", action="store_true",
                        help="exit 1 if any conceptual corridor intersects a proxy clearance buffer")
    parser.add_argument("--report", type=Path, help="write machine-readable audit JSON")
    args = parser.parse_args()
    document = json.loads(args.data.read_text(encoding="utf-8"))
    assessments = assess_layout(document, args.margin_m)
    conflicts = [result for result in assessments if result.conflict]
    for item in conflicts:
        print(f"CONFLICT walkway[{item.walkway_index}] segment[{item.segment_index}] "
              f"vs {item.nearest_building} part[{item.nearest_part}]: "
              f"gap={item.gap_m:.2f}m, required={item.required_m:.2f}m")
    print(f"Route proxy clearance: {len(assessments)} segments, "
          f"{len(conflicts)} conflict(s), {args.margin_m:.2f}m extra margin. "
          "PROVISIONAL: not a field-survey or accessible-route certificate.")
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        report = {
            "schema_version": 1,
            "status": "conceptual-2d-proxy-clearance-only-not-surveyed",
            "reference": "godot/data/utown_core.json",
            "margin_m": args.margin_m,
            "segment_count": len(assessments),
            "conflict_count": len(conflicts),
            "segments": [asdict(item) for item in assessments],
        }
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return 1 if conflicts and args.strict else 0


if __name__ == "__main__":
    raise SystemExit(main())
