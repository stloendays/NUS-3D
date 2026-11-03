#!/usr/bin/env python3
"""Validate the source data that drives the NUS-3D UTown greybox.

This checks data integrity and coordinate consistency, not survey accuracy or
the licensing status of source material.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class Finding:
    severity: str
    path: str
    message: str


def _number(value: Any, path: str, findings: list[Finding]) -> float | None:
    if isinstance(value, bool):
        findings.append(Finding("ERROR", path, "must be a finite number"))
        return None
    try:
        result = float(value)
    except (TypeError, ValueError):
        findings.append(Finding("ERROR", path, "must be a finite number"))
        return None
    if not math.isfinite(result):
        findings.append(Finding("ERROR", path, "must be a finite number"))
        return None
    return result


def _coordinate(lon: Any, lat: Any, path: str, findings: list[Finding]) -> tuple[float, float] | None:
    longitude = _number(lon, f"{path}.lon", findings)
    latitude = _number(lat, f"{path}.lat", findings)
    if longitude is None or latitude is None:
        return None
    if not -180 <= longitude <= 180:
        findings.append(Finding("ERROR", f"{path}.lon", "longitude outside [-180, 180]"))
        return None
    if not -90 <= latitude <= 90:
        findings.append(Finding("ERROR", f"{path}.lat", "latitude outside [-90, 90]"))
        return None
    return longitude, latitude


def _project(lon: float, lat: float, origin_lon: float, origin_lat: float) -> tuple[float, float]:
    east = (lon - origin_lon) * 111320.0 * math.cos(math.radians(origin_lat))
    north = (lat - origin_lat) * 110574.0
    return east, -north


def _cross(a: tuple[float, float], b: tuple[float, float], c: tuple[float, float]) -> float:
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def _on_segment(a: tuple[float, float], b: tuple[float, float], p: tuple[float, float]) -> bool:
    return (min(a[0], b[0]) - 1e-9 <= p[0] <= max(a[0], b[0]) + 1e-9
            and min(a[1], b[1]) - 1e-9 <= p[1] <= max(a[1], b[1]) + 1e-9)


def _segments_intersect(a: tuple[float, float], b: tuple[float, float],
                        c: tuple[float, float], d: tuple[float, float]) -> bool:
    o1, o2, o3, o4 = _cross(a, b, c), _cross(a, b, d), _cross(c, d, a), _cross(c, d, b)
    if ((o1 > 0 > o2) or (o2 > 0 > o1)) and ((o3 > 0 > o4) or (o4 > 0 > o3)):
        return True
    return ((abs(o1) <= 1e-9 and _on_segment(a, b, c))
            or (abs(o2) <= 1e-9 and _on_segment(a, b, d))
            or (abs(o3) <= 1e-9 and _on_segment(c, d, a))
            or (abs(o4) <= 1e-9 and _on_segment(c, d, b)))


def _polygon_area(points: list[tuple[float, float]]) -> float:
    return abs(sum(points[i][0] * points[(i + 1) % len(points)][1]
                   - points[(i + 1) % len(points)][0] * points[i][1]
                   for i in range(len(points)))) * 0.5


def _self_intersects(points: list[tuple[float, float]]) -> bool:
    count = len(points)
    for i in range(count):
        a, b = points[i], points[(i + 1) % count]
        for j in range(i + 1, count):
            if j == i + 1 or (i == 0 and j == count - 1):
                continue
            if _segments_intersect(a, b, points[j], points[(j + 1) % count]):
                return True
    return False


def validate_document(document: Any) -> list[Finding]:
    findings: list[Finding] = []
    if not isinstance(document, dict):
        return [Finding("ERROR", "$", "root must be a JSON object")]
    if document.get("schema_version") != 1:
        findings.append(Finding("ERROR", "schema_version", "expected schema version 1"))

    spatial = document.get("spatial_reference")
    if not isinstance(spatial, dict):
        findings.append(Finding("ERROR", "spatial_reference", "must be an object"))
        spatial = {}
    if "4326" not in str(spatial.get("crs", "")):
        findings.append(Finding("ERROR", "spatial_reference.crs", "expected WGS84 / EPSG:4326"))
    origin = _coordinate(spatial.get("origin_lon"), spatial.get("origin_lat"),
                         "spatial_reference.origin", findings) or (0.0, 0.0)
    origin_lon, origin_lat = origin
    if "approx" in str(spatial.get("precision", "")).lower() or "survey" in str(spatial.get("precision", "")).lower():
        findings.append(Finding("WARN", "spatial_reference.precision",
                                "coordinates are provisional; do not present them as survey-grade"))

    ground = document.get("ground_size_m")
    half_width = half_depth = None
    if not isinstance(ground, list) or len(ground) != 2:
        findings.append(Finding("ERROR", "ground_size_m", "must be [width_m, depth_m]"))
    else:
        width = _number(ground[0], "ground_size_m[0]", findings)
        depth = _number(ground[1], "ground_size_m[1]", findings)
        if width is not None and width <= 10:
            findings.append(Finding("ERROR", "ground_size_m[0]", "must exceed 10 m"))
        if depth is not None and depth <= 10:
            findings.append(Finding("ERROR", "ground_size_m[1]", "must exceed 10 m"))
        if width is not None and depth is not None and width > 10 and depth > 10:
            half_width, half_depth = width / 2, depth / 2

    def project_checked(lon: Any, lat: Any, path: str) -> tuple[float, float] | None:
        point = _coordinate(lon, lat, path, findings)
        return _project(point[0], point[1], origin_lon, origin_lat) if point else None

    def check_bounds(point: tuple[float, float], path: str) -> None:
        if half_width is None or half_depth is None:
            return
        if abs(point[0]) > half_width - 5 or abs(point[1]) > half_depth - 5:
            findings.append(Finding("ERROR", path,
                                    f"outside ground bounds with 5 m margin (x={point[0]:.1f}, z={point[1]:.1f})"))

    green = document.get("green")
    if not isinstance(green, dict):
        findings.append(Finding("ERROR", "green", "must be an object"))
    else:
        raw = green.get("polygon_lonlat")
        polygon: list[tuple[float, float]] = []
        if not isinstance(raw, list) or len(raw) < 3:
            findings.append(Finding("ERROR", "green.polygon_lonlat", "requires at least three coordinate pairs"))
        else:
            for i, pair in enumerate(raw):
                if not isinstance(pair, list) or len(pair) != 2:
                    findings.append(Finding("ERROR", f"green.polygon_lonlat[{i}]", "must be [lon, lat]"))
                    continue
                point = project_checked(pair[0], pair[1], f"green.polygon_lonlat[{i}]")
                if point:
                    polygon.append(point)
                    check_bounds(point, f"green.polygon_lonlat[{i}]")
            if len(polygon) >= 3:
                if _polygon_area(polygon) < 1:
                    findings.append(Finding("ERROR", "green.polygon_lonlat", "polygon area must be at least 1 m²"))
                if _self_intersects(polygon):
                    findings.append(Finding("ERROR", "green.polygon_lonlat", "polygon self-intersects"))

    buildings = document.get("buildings")
    if not isinstance(buildings, list) or not buildings:
        findings.append(Finding("ERROR", "buildings", "must be a non-empty array"))
        buildings = []
    seen_ids: set[str] = set()
    for i, record in enumerate(buildings):
        path = f"buildings[{i}]"
        if not isinstance(record, dict):
            findings.append(Finding("ERROR", path, "must be an object"))
            continue
        item_id = str(record.get("id", "")).strip()
        if not item_id:
            findings.append(Finding("ERROR", f"{path}.id", "must not be empty"))
        elif item_id in seen_ids:
            findings.append(Finding("ERROR", f"{path}.id", f"duplicate building id: {item_id}"))
        seen_ids.add(item_id)
        centre = project_checked(record.get("lon"), record.get("lat"), path)
        rotation = _number(record.get("rotation_deg", 0), f"{path}.rotation_deg", findings)
        parts = record.get("parts")
        if not isinstance(parts, list) or not parts:
            findings.append(Finding("ERROR", f"{path}.parts", "requires at least one massing part"))
            continue
        for j, part in enumerate(parts):
            part_path = f"{path}.parts[{j}]"
            if not isinstance(part, dict):
                findings.append(Finding("ERROR", part_path, "must be an object"))
                continue
            values = {key: _number(part.get(key, default), f"{part_path}.{key}", findings)
                      for key, default in (("dx", 0), ("dn", 0), ("w", 24), ("d", 24), ("h", 15))}
            if centre is None or rotation is None or any(v is None for v in values.values()):
                continue
            if values["w"] <= 0 or values["d"] <= 0 or values["h"] <= 0:
                findings.append(Finding("ERROR", part_path, "width, depth and height must be positive"))
                continue
            angle = math.radians(rotation)
            local_z = -values["dn"]
            cx = centre[0] + math.cos(angle) * values["dx"] + math.sin(angle) * local_z
            cz = centre[1] - math.sin(angle) * values["dx"] + math.cos(angle) * local_z
            ex = abs(math.cos(angle)) * values["w"] / 2 + abs(math.sin(angle)) * values["d"] / 2
            ez = abs(math.sin(angle)) * values["w"] / 2 + abs(math.cos(angle)) * values["d"] / 2
            check_bounds((cx - ex, cz - ez), f"{part_path}.bounds.min")
            check_bounds((cx + ex, cz + ez), f"{part_path}.bounds.max")
        if str(record.get("dimensions_status", "unknown")).lower() not in {"verified", "measured"}:
            findings.append(Finding("WARN", f"{path}.dimensions_status", "building dimensions are not verified measurements"))

    loop = document.get("loop")
    if not isinstance(loop, list) or len(loop) < 3:
        findings.append(Finding("ERROR", "loop", "requires at least three ordered stops"))
        loop = []
    route_points: list[tuple[float, float]] = []
    route_ids: set[str] = set()
    for i, stop in enumerate(loop):
        path = f"loop[{i}]"
        if not isinstance(stop, dict):
            findings.append(Finding("ERROR", path, "must be an object"))
            continue
        stop_id = str(stop.get("id", "")).strip()
        if not stop_id:
            findings.append(Finding("ERROR", f"{path}.id", "must not be empty"))
        elif stop_id in route_ids:
            findings.append(Finding("ERROR", f"{path}.id", f"duplicate route stop id: {stop_id}"))
        route_ids.add(stop_id)
        point = project_checked(stop.get("lon"), stop.get("lat"), path)
        if point:
            route_points.append(point)
            check_bounds(point, path)

    walkways = document.get("walkways")
    if not isinstance(walkways, list) or not walkways:
        findings.append(Finding("ERROR", "walkways", "must be a non-empty array"))
        walkways = []
    if loop and len(walkways) != len(loop):
        findings.append(Finding("ERROR", "walkways", "closed route requires one walkway segment per edge"))
    for i, way in enumerate(walkways):
        path = f"walkways[{i}]"
        if not isinstance(way, dict):
            findings.append(Finding("ERROR", path, "must be an object"))
            continue
        width = _number(way.get("width_m", 3.5), f"{path}.width_m", findings)
        if width is not None and width <= 0:
            findings.append(Finding("ERROR", f"{path}.width_m", "must be positive"))
        raw = way.get("lonlat")
        if not isinstance(raw, list) or len(raw) < 2:
            findings.append(Finding("ERROR", f"{path}.lonlat", "requires at least two coordinate pairs"))
            continue
        points: list[tuple[float, float]] = []
        for j, pair in enumerate(raw):
            if not isinstance(pair, list) or len(pair) != 2:
                findings.append(Finding("ERROR", f"{path}.lonlat[{j}]", "must be [lon, lat]"))
                continue
            point = project_checked(pair[0], pair[1], f"{path}.lonlat[{j}]")
            if point:
                points.append(point)
                check_bounds(point, f"{path}.lonlat[{j}]")
        if len(points) >= 2:
            if sum(math.dist(points[j], points[j + 1]) for j in range(len(points) - 1)) < 1:
                findings.append(Finding("ERROR", f"{path}.lonlat", "walkway must be at least 1 m long"))
            if loop and len(route_points) == len(loop) and i < len(route_points):
                if math.dist(points[0], route_points[i]) > 2:
                    findings.append(Finding("ERROR", f"{path}.lonlat[0]", "start is more than 2 m from route stop"))
                if math.dist(points[-1], route_points[(i + 1) % len(route_points)]) > 2:
                    findings.append(Finding("ERROR", f"{path}.lonlat[-1]", "end is more than 2 m from next route stop"))

    if not bool(document.get("no_official_affiliation", False)):
        findings.append(Finding("WARN", "no_official_affiliation", "keep the NUS non-affiliation notice enabled"))
    if not str(document.get("data_credit", "")).strip():
        findings.append(Finding("WARN", "data_credit", "add source attribution before redistribution"))
    return findings


def main() -> int:
    default_data = Path(__file__).resolve().parents[1] / "godot" / "data" / "utown_core.json"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", type=Path, default=default_data)
    args = parser.parse_args()
    try:
        document = json.loads(args.data.read_text(encoding="utf-8"))
    except OSError as exc:
        print(f"ERROR {args.data}: {exc}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as exc:
        print(f"ERROR {args.data}:{exc.lineno}:{exc.colno}: {exc.msg}", file=sys.stderr)
        return 2
    findings = validate_document(document)
    for finding in findings:
        print(f"{finding.severity} {finding.path}: {finding.message}")
    errors = sum(item.severity == "ERROR" for item in findings)
    warnings = sum(item.severity == "WARN" for item in findings)
    count = len(document.get("buildings", [])) if isinstance(document, dict) else 0
    print(f"\nUTown data validation: {errors} error(s), {warnings} warning(s), {count} building record(s).")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
