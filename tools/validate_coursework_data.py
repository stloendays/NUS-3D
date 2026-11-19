#!/usr/bin/env python3
"""Validate original, explicitly fictional NUS-3D coursework gameplay data.

The university names are labels used for player roleplay, not real coursework,
academic records, admission information, or official NUS module metadata.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COURSEWORK = ROOT / "godot" / "data" / "coursework_quests.json"
MAP = ROOT / "godot" / "data" / "utown_core.json"

# Gameplay interaction IDs, not real campus coordinates.
ACTIVITIES = {
    "ERC/cafe", "ERC/reading", "ERC/mezzanine",
    "SRC/refill", "SRC/warmup", "SRC/viewing",
}
PARTNERS = {
    "ERC/Maya", "ERC/Ethan", "ERC/Mei",
    "SRC/Lucas", "SRC/Aisha", "SRC/Daniel",
}

def validate_coursework(data_path: Path = COURSEWORK, map_path: Path = MAP) -> list[str]:
    issues: list[str] = []
    try:
        data = json.loads(data_path.read_text(encoding="utf-8"))
        world = json.loads(map_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return [f"Invalid data input: {error}"]
    if data.get("schema") != "nus3d-coursework-v1":
        issues.append("Coursework schema must be nus3d-coursework-v1")
    if data.get("unofficial") is not True or data.get("offline") is not True:
        issues.append("All coursework must explicitly be unofficial and offline")
    if "fictional" not in str(data.get("status", "")).lower():
        issues.append("Coursework status must declare fictional gameplay")
    waypoints = {str(row["id"]) for row in world.get("loop", [])}
    faculties = data.get("faculty_options", [])
    if not isinstance(faculties, list) or len(faculties) != 13:
        issues.append(f"Expected 13 selectable faculties, got {len(faculties)}")
        return issues
    seen_faculties: set[str] = set()
    total_quests = 0
    for faculty in faculties:
        identity = str(faculty.get("id", ""))
        if not identity or identity in seen_faculties:
            issues.append(f"Missing/duplicate faculty id: {identity}")
        seen_faculties.add(identity)
        for key in ("name", "zh", "abbr", "flavor"):
            if not faculty.get(key):
                issues.append(f"{identity} missing {key}")
        quests = faculty.get("quests", [])
        if len(quests) != 3:
            issues.append(f"{identity} must have three course chapters")
        seen_quests: set[str] = set()
        for quest in quests:
            total_quests += 1
            chapter = str(quest.get("id", ""))
            if not chapter or chapter in seen_quests:
                issues.append(f"{identity} has duplicate/missing quest id {chapter}")
            seen_quests.add(chapter)
            for key in ("title", "story"):
                if not str(quest.get(key, "")).strip():
                    issues.append(f"{identity}/{chapter} is missing {key}")
            for key in ("pickup", "submit"):
                if quest.get(key) not in waypoints:
                    issues.append(f"{identity}/{chapter}: {key} is not a schematic waypoint")
            if quest.get("activity") not in ACTIVITIES:
                issues.append(f"{identity}/{chapter}: unknown F-key indoor activity")
            if quest.get("partner") not in PARTNERS:
                issues.append(f"{identity}/{chapter}: unknown Q-key character")
            if not 150 <= int(quest.get("deadline_s", 0)) <= 600:
                issues.append(f"{identity}/{chapter}: unrealistic game timer")
            if int(quest.get("xp", 0)) < 50 or int(quest.get("credits", 0)) < 10:
                issues.append(f"{identity}/{chapter}: invalid reward")
    if total_quests != 39:
        issues.append(f"Expected 39 coursework chapters, got {total_quests}")
    return issues


if __name__ == "__main__":
    failures = validate_coursework()
    if failures:
        raise SystemExit("FAIL: " + "; ".join(failures))
    print("PASS: 13 fictional selectable faculties, 39 quests and valid schematic waypoints/activities")
