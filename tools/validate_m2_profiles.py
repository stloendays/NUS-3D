#!/usr/bin/env python3
"""Validate M2 architecture profiles separately from real-world survey accuracy."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
REQUIRED = {"ERC": "erc", "SRC": "src"}


def validate_m2(layout: dict, document: dict) -> list[str]:
    errors: list[str] = []
    if document.get("schema_version") != 1:
        errors.append("m2_profiles: expected schema_version 1")
    if document.get("status") != "schematic-architecture-not-surveyed":
        errors.append("m2_profiles: unverified geometry disclaimer is required")
    source_ids = {item["id"] for item in layout.get("buildings", []) if isinstance(item, dict) and "id" in item}
    profiles = document.get("profiles", {})
    if not isinstance(profiles, dict):
        return errors + ["m2_profiles.profiles must be an object"]
    if set(profiles) != set(REQUIRED):
        errors.append("m2_profiles must contain exactly the ERC and SRC P0 records")
    for landmark, expected_style in REQUIRED.items():
        record = profiles.get(landmark)
        if not isinstance(record, dict):
            errors.append(f"{landmark}: missing profile object")
            continue
        if landmark not in source_ids:
            errors.append(f"{landmark}: building missing in utown_core.json")
        if record.get("building_id") != landmark or record.get("style") != expected_style:
            errors.append(f"{landmark}: style/building_id mismatch")
        if record.get("geometry_confidence") != "estimated":
            errors.append(f"{landmark}: estimated geometry must stay explicitly identified")
        if record.get("license_status") != "reference-only":
            errors.append(f"{landmark}: reference-only source permission status is required")
        references = record.get("evidence_links")
        if not isinstance(references, list) or not references or any(not isinstance(url, str) or not url.startswith("https://") for url in references):
            errors.append(f"{landmark}: provide at least one HTTPS reference URL")
        assumptions = record.get("estimates_m")
        if not isinstance(assumptions, dict) or not assumptions:
            errors.append(f"{landmark}: estimated dimensions are missing")
            continue
        for parameter, value in assumptions.items():
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or not (0 < value < 100):
                errors.append(f"{landmark}.estimates_m.{parameter}: value must be a finite positive estimate under 100m")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--core", type=Path, default=REPO / "godot/data/utown_core.json")
    parser.add_argument("--profiles", type=Path, default=REPO / "godot/data/m2_profiles.json")
    args = parser.parse_args()
    layout = json.loads(args.core.read_text(encoding="utf-8"))
    profiles = json.loads(args.profiles.read_text(encoding="utf-8"))
    errors = validate_m2(layout, profiles)
    for error in errors:
        print("ERROR", error)
    print(f"M2 profile validation: {len(errors)} error(s); {len(profiles.get('profiles', {}))} architecture profiles.")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
