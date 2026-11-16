#!/usr/bin/env python3
"""Validate original guided-discovery text against the canonical proxy loop.

This is a software integrity check, not evidence of surveyed campus paths.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAYOUT_PATH = ROOT / "godot/data/utown_core.json"
TOUR_PATH = ROOT / "godot/data/discovery_tour.json"


def validate_tour(tour: dict, layout: dict) -> list[str]:
    errors: list[str] = []
    if not isinstance(tour, dict) or not isinstance(layout, dict):
        return ["Tour and layout must be JSON objects."]
    if tour.get("schema_version") != 1:
        errors.append("Unsupported tour schema version.")
    if tour.get("no_official_affiliation") is not True:
        errors.append("Tour must explicitly state non-affiliation.")
    if "not-surveyed" not in str(tour.get("status", "")).lower():
        errors.append("Tour status must say the scene is not surveyed.")
    disclaimer = str(tour.get("route_disclaimer", "")).lower()
    if "not surveyed" not in disclaimer or "not suitable for real navigation" not in disclaimer:
        errors.append("Tour must explicitly reject real navigation use.")
    radius = tour.get("check_in_radius_m")
    if isinstance(radius, bool) or not isinstance(radius, (int, float)) or not math.isfinite(radius) or not 4.0 <= radius <= 20.0:
        errors.append("Check-in radius must be finite and between 4 and 20 metres.")

    waypoint_ids = [row.get("id") for row in layout.get("loop", []) if isinstance(row, dict)]
    stops = tour.get("stops")
    if not isinstance(stops, list):
        return errors + ["Tour stops must be an array."]
    ids: list[str] = []
    for index, row in enumerate(stops):
        if not isinstance(row, dict):
            errors.append(f"Stop {index} must be an object.")
            continue
        stop_id = row.get("id")
        ids.append(stop_id if isinstance(stop_id, str) else "")
        if "lon" in row or "lat" in row or "position" in row:
            errors.append(f"Stop {index} duplicates the canonical loop coordinates.")
        for field in ("title", "observation", "discovery"):
            value = row.get(field)
            if not isinstance(value, str) or not 12 <= len(value.strip()) <= 260:
                errors.append(f"Stop {index}: {field} must have 12–260 characters of original text.")
    if len(set(ids)) != len(ids):
        errors.append("Tour stop IDs must be unique.")
    if ids != waypoint_ids or len(ids) != 4:
        errors.append("Tour stop IDs and order must match all four canonical loop waypoints.")
    return errors


def main() -> int:
    layout = json.loads(LAYOUT_PATH.read_text(encoding="utf-8"))
    tour = json.loads(TOUR_PATH.read_text(encoding="utf-8"))
    errors = validate_tour(tour, layout)
    for issue in errors:
        print("ERROR:", issue)
    print(f"UTown discovery tour validation: {len(errors)} error(s), {len(tour.get('stops', []))} stops.")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
