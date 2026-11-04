#!/usr/bin/env python3
"""Validate camera photo provenance and avoid spawning inside building massing."""
from __future__ import annotations

import argparse
from datetime import date
import json
import math
from pathlib import Path
import re
from typing import Any
import sys

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.audit_route_clearance import _project, footprint_vertices, segment_footprint_gap
IDENTIFIER = re.compile(r"^[A-Z][A-Z0-9_]{2,47}$")


def validate_viewpoints(layout: dict[str, Any], document: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if document.get("schema_version") != 1:
        errors.append("expected schema_version 1")
    if document.get("status") != "photo-reference-viewpoints-not-survey-calibrated":
        errors.append("missing provisional status")
    if "not" not in str(document.get("attribution_notice", "")).lower():
        errors.append("missing survey/licensing notice")
    eye = document.get("common_eye_height_m")
    if isinstance(eye, bool) or not isinstance(eye, (int, float)) or not 1.4 <= float(eye) <= 2.2:
        errors.append("invalid estimated eye height")
    views = document.get("viewpoints")
    if not isinstance(views, list) or not views:
        return errors + ["no viewpoint records"]
    reference = layout["spatial_reference"]
    lon0, lat0 = reference["origin_lon"], reference["origin_lat"]
    width, depth = layout["ground_size_m"]
    footprints = [footprint_vertices(b, part, lon0, lat0)
                  for b in layout["buildings"] for part in b["parts"]]
    seen: set[str] = set()
    for idx, row in enumerate(views):
        key = f"viewpoints[{idx}]"
        if not isinstance(row, dict):
            errors.append(f"{key}: must be an object")
            continue
        ident = row.get("id")
        if not isinstance(ident, str) or not IDENTIFIER.fullmatch(ident):
            errors.append(f"{key}: invalid ID")
        elif ident in seen:
            errors.append(f"{key}: duplicate ID {ident}")
        if isinstance(ident, str):
            seen.add(ident)
        kind = row.get("kind")
        if kind not in ("geotagged_photo", "synthetic_proxy"):
            errors.append(f"{key}: unsupported kind")
        expected_status = "review-required" if kind == "geotagged_photo" else "synthetic-not-surveyed"
        if row.get("confidence") != expected_status:
            errors.append(f"{key}: source provenance incorrectly classified")
        for field in ("lon", "lat", "heading_deg", "pitch_deg", "fov_deg"):
            val = row.get(field)
            if isinstance(val, bool) or not isinstance(val, (int, float)) or not math.isfinite(val):
                errors.append(f"{key}.{field}: finite numeric value required")
        if all(isinstance(row.get(field), (int, float)) and math.isfinite(row[field]) for field in ("lon", "lat")):
            lon, lat = row["lon"], row["lat"]
            if not -180 <= lon <= 180 or not -90 <= lat <= 90:
                errors.append(f"{key}: invalid WGS84 lon/lat")
            else:
                x, z = _project([lon, lat], lon0, lat0)
                if abs(x) >= width / 2 - 5 or abs(z) >= depth / 2 - 5:
                    errors.append(f"{key}: outside ground")
                elif any(segment_footprint_gap((x, z), (x, z), poly) < 0.75 for poly in footprints):
                    errors.append(f"{key}: camera inside or near estimated building footprint")
        heading = row.get("heading_deg")
        if isinstance(heading, (int, float)) and math.isfinite(heading) and not 0 <= heading < 360:
            errors.append(f"{key}: heading must be 0..360")
        pitch = row.get("pitch_deg")
        if isinstance(pitch, (int, float)) and math.isfinite(pitch) and not -45 <= pitch <= 45:
            errors.append(f"{key}: pitch must be -45..45")
        fov = row.get("fov_deg")
        if isinstance(fov, (int, float)) and math.isfinite(fov) and not 35 <= fov <= 95:
            errors.append(f"{key}: fov must be 35..95")
        if row.get("heading_reference") not in ("magnetic", "true", "unknown"):
            errors.append(f"{key}: heading_reference required")
        if not row.get("label") or not row.get("subject") or not row.get("notes"):
            errors.append(f"{key}: label, subject, notes required")
        if kind == "geotagged_photo":
            if not str(row.get("source_url", "")).startswith("https://commons.wikimedia.org/wiki/File:"):
                errors.append(f"{key}: Commons source photo URL required")
            if not row.get("creator") or row.get("license") not in ("CC BY 4.0", "CC BY-SA 3.0", "CC BY-SA 4.0"):
                errors.append(f"{key}: creator and supported license required")
            try:
                date.fromisoformat(str(row.get("photo_date")))
            except ValueError:
                errors.append(f"{key}: ISO photo date required")
        elif kind == "synthetic_proxy" and any(row.get(field) is not None for field in ("photo_date", "creator", "license", "source_url")):
            errors.append(f"{key}: synthetic viewpoint must not claim photo evidence")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--layout", type=Path, default=ROOT / "godot/data/utown_core.json")
    parser.add_argument("--data", type=Path, default=ROOT / "godot/data/viewpoints.json")
    args = parser.parse_args()
    data = json.loads(args.layout.read_text(encoding="utf-8"))
    refs = json.loads(args.data.read_text(encoding="utf-8"))
    errors = validate_viewpoints(data, refs)
    for msg in errors:
        print("ERROR", msg)
    print(f"Viewpoint validation: {len(errors)} error(s), {len(refs.get('viewpoints', []))} viewpoint(s).")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
