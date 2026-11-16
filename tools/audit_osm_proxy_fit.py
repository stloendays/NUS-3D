#!/usr/bin/env python3
"""Quantify planar agreement of estimated game massing with frozen OSM outer rings.

Uses the model's local WGS84-to-metre transform. Exact polygon operations in
that *approximate planar projection*; NOT field-survey accuracy, site navigation,
building access, building height, or a judgement of OSM completeness.
"""
from __future__ import annotations

import argparse
from itertools import combinations
import json
import math
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
from tools.audit_route_clearance import _project, footprint_vertices

EPS = 1e-8


def signed_area(ring):
    return 0.5 * sum(a[0] * b[1] - b[0] * a[1]
                     for a, b in zip(ring, ring[1:] + ring[:1]))


def area(ring):
    return abs(signed_area(ring)) if len(ring) >= 3 else 0.0


def centroid(ring):
    if len(ring) < 3 or abs(signed_area(ring)) < EPS:
        raise ValueError("Cannot compute centroid of a degenerate polygon")
    cross_sum = 0.0
    sx = 0.0
    sy = 0.0
    for a, b in zip(ring, ring[1:] + ring[:1]):
        cross = a[0] * b[1] - b[0] * a[1]
        cross_sum += cross
        sx += (a[0] + b[0]) * cross
        sy += (a[1] + b[1]) * cross
    return sx / (3.0 * cross_sum), sy / (3.0 * cross_sum)


def _cross(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def normalized_ring(points):
    """Strip closure, redundant neighbours and collinear vertices; force CCW."""
    points = list(points)
    if len(points) >= 2 and points[0] == points[-1]:
        points.pop()
    out = []
    for p in points:
        if not out or math.dist(out[-1], p) > EPS:
            out.append(tuple(p))
    if len(out) > 2 and math.dist(out[-1], out[0]) <= EPS:
        out.pop()
    if len(out) < 3:
        raise ValueError("Polygon must contain at least three distinct vertices")
    changed = True
    while changed and len(out) > 3:
        changed = False
        for i in range(len(out)):
            if abs(_cross(out[i - 1], out[i], out[(i + 1) % len(out)])) <= EPS:
                del out[i]
                changed = True
                break
    if abs(signed_area(out)) <= EPS:
        raise ValueError("Degenerate polygon with zero area")
    if signed_area(out) < 0:
        out.reverse()
    return out


def _inside_triangle(p, a, b, c):
    return min(_cross(a, b, p), _cross(b, c, p), _cross(c, a, p)) >= -EPS


def triangulate_simple_ring(points):
    """Ear-clip a simple OSM outer ring (holes and multipolygons not supported)."""
    ring = normalized_ring(points)
    pending = list(range(len(ring)))
    triangles = []
    while len(pending) > 3:
        found = False
        for j, middle in enumerate(pending):
            prev = pending[j - 1]
            following = pending[(j + 1) % len(pending)]
            a, b, c = ring[prev], ring[middle], ring[following]
            if _cross(a, b, c) <= EPS:
                continue
            if any(_inside_triangle(ring[k], a, b, c)
                   for k in pending if k not in (prev, middle, following)):
                continue
            triangles.append([a, b, c])
            del pending[j]
            found = True
            break
        if not found:
            raise ValueError("OSM ring cannot be triangulated; possible invalid outer boundary")
    triangles.append([ring[i] for i in pending])
    difference = abs(sum(area(t) for t in triangles) - area(ring))
    if difference > max(0.001, area(ring) * 1e-7):
        raise ValueError("Triangulation changes source polygon area")
    return triangles


def clip_convex(subject, cutter):
    """Sutherland-Hodgman convex clipping with signed planar half planes."""
    if len(subject) < 3 or len(cutter) < 3 or area(cutter) < EPS:
        return []
    if signed_area(cutter) < 0:
        cutter = list(reversed(cutter))
    output = list(subject)
    for a, b in zip(cutter, cutter[1:] + cutter[:1]):
        values = output
        output = []
        if not values:
            break
        prev = values[-1]
        prev_dist = _cross(a, b, prev)
        for cur in values:
            cur_dist = _cross(a, b, cur)
            prev_inside = prev_dist >= -EPS
            cur_inside = cur_dist >= -EPS
            if prev_inside != cur_inside:
                delta = prev_dist - cur_dist
                if abs(delta) > EPS:
                    t = prev_dist / delta
                    output.append((prev[0] + t * (cur[0] - prev[0]),
                                   prev[1] + t * (cur[1] - prev[1])))
            if cur_inside:
                output.append(cur)
            prev, prev_dist = cur, cur_dist
    return output if area(output) > EPS else []


def union_proxy_and_overlap(parts, source_triangles):
    """Inclusion-exclusion over small rotated-rectangle building part sets."""
    if not parts:
        raise ValueError("Empty estimated building parts")
    if len(parts) > 8:
        raise ValueError("Too many proxy parts for exact inclusion-exclusion")
    proxy_area, common_area = 0.0, 0.0
    cx_acc, cz_acc = 0.0, 0.0
    for n in range(1, len(parts) + 1):
        sign = 1 if n % 2 else -1
        for indices in combinations(range(len(parts)), n):
            inter = parts[indices[0]]
            for idx in indices[1:]:
                inter = clip_convex(inter, parts[idx])
                if not inter:
                    break
            if not inter:
                continue
            extent = area(inter)
            if extent <= EPS:
                continue
            proxy_area += sign * extent
            centre = centroid(inter)
            cx_acc += sign * centre[0] * extent
            cz_acc += sign * centre[1] * extent
            for triangle in source_triangles:
                common_area += sign * area(clip_convex(triangle, inter))
    if proxy_area <= EPS:
        raise ValueError("Proxy union has no measurable area")
    if common_area < -0.001 or common_area > proxy_area + 0.001:
        raise ValueError("Inconsistent polygon overlap area")
    return proxy_area, max(0.0, min(proxy_area, common_area)), (cx_acc / proxy_area, cz_acc / proxy_area)


def compare_layout(layout, osm):
    ref = layout["spatial_reference"]
    lon0, lat0 = float(ref["origin_lon"]), float(ref["origin_lat"])
    models = {b["id"]: b for b in layout["buildings"]}
    report = []
    for f in osm["features"]:
        if f["id"] not in models:
            raise ValueError("OSM feature has no model building: " + str(f["id"]))
        b = models[f["id"]]
        outer = normalized_ring([_project(p, lon0, lat0) for p in f["coordinates_lonlat"]])
        triangles = triangulate_simple_ring(outer)
        rectangles = [footprint_vertices(b, p, lon0, lat0) for p in b["parts"]]
        source = area(outer)
        model, common, model_center = union_proxy_and_overlap(rectangles, triangles)
        if common > min(source, model) + 0.001:
            raise ValueError("Polygon overlap exceeds constituent area")
        common = min(common, source, model)
        combined = source + model - common
        source_centre = centroid(outer)
        report.append({
            "id": f["id"], "osm_way_id": f["osm_way_id"],
            "osm_way_version": f["osm_version"],
            "source_area_m2": round(source, 2),
            "proxy_union_area_m2": round(model, 2),
            "overlap_area_m2": round(common, 2),
            "source_only_area_m2": round(max(0.0, source - common), 2),
            "proxy_only_area_m2": round(max(0.0, model - common), 2),
            "intersection_over_union": round(common / combined, 4),
            "osm_area_covered_pct": round(100.0 * common / source, 1),
            "proxy_area_inside_osm_pct": round(100.0 * common / model, 1),
            "centroid_shift_m": round(math.dist(source_centre, model_center), 2),
            "osm_centroid_local_xz_m": [round(v, 2) for v in source_centre],
            "proxy_centroid_local_xz_m": [round(v, 2) for v in model_center],
            "proxy_part_count": len(rectangles),
            "source_vertex_count": len(f["coordinates_lonlat"]) - 1
        })
    return {
        "schema_version": 1,
        "status": "planar-geometry-comparison-ONLY-not-as-built-survey-or-navigation",
        "method": "local-equirectangular-metres; OSM simple outer-ring ear triangulation; convex polygon clipping; inclusion-exclusion of overlapping rotated game parts",
        "limitations": "OSM outer rings may contain covered arcades, multiple elevations or incomplete footprint detail. No building part, entrance, slope, accessible path, polygon holes, or terrain height is certified. Numbers quantify two datasets, not real-world accuracy.",
        "attribution": osm["attribution"],
        "license": osm["license"],
        "source_snapshot_utc": osm["snapshot_retrieved_utc"],
        "source_url": osm["source_api_url"],
        "buildings": report
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--layout", type=Path, default=ROOT / "godot/data/utown_core.json")
    parser.add_argument("--osm", type=Path, default=ROOT / "godot/data/osm_p0_reference.json")
    parser.add_argument("--out", type=Path, default=ROOT / "build/osm-proxy-fit.json")
    args = parser.parse_args()
    comparison = compare_layout(json.loads(args.layout.read_text(encoding="utf-8")),
                                json.loads(args.osm.read_text(encoding="utf-8")))
    for item in comparison["buildings"]:
        print(f'{item["id"]}: IoU={item["intersection_over_union"]:.3f}; '
              f'OSM covered={item["osm_area_covered_pct"]:.1f}%; '
              f'proxy inside OSM={item["proxy_area_inside_osm_pct"]:.1f}%; '
              f'centroid offset={item["centroid_shift_m"]:.1f}m '
              "(plan-view only, NOT field-survey accuracy)")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(comparison, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
