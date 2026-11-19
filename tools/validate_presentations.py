#!/usr/bin/env python3
"""Validate original offline English presentation tasks against the major catalog."""
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "godot/data/presentation_briefs.json"
EXAMS = ROOT / "godot/data/english_exam_papers.json"

def validate_presentations(path: Path = DATA, exams_path: Path = EXAMS) -> list[str]:
    issues: list[str] = []
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
        exams = json.loads(exams_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as err:
        return [f"Cannot read presentation/exam JSON: {err}"]
    if doc.get("schema") != "nus3d-voice-presentations-v1":
        issues.append("Presentation schema mismatch")
    if doc.get("language") != "en" or doc.get("offline") is not True or doc.get("unofficial") is not True:
        issues.append("Presentation must be English-only, offline and fictional")
    if "No audio recording" not in str(doc.get("privacy", "")):
        issues.append("Privacy notice must disclose that audio is not recorded")
    scoring = doc.get("scoring", {})
    if (scoring.get("first_pass_xp"), scoring.get("first_pass_credits"), scoring.get("min_slide_voice_seconds")) != (70, 20, 5):
        issues.append("Presentation rewards and speech-duration rule changed")
    papers = {item["id"]: item for item in exams.get("papers", [])}
    tasks = doc.get("presentations", [])
    if len(tasks) != len(papers) or len(tasks) != 32:
        issues.append("Expected 32 distinct presentation briefs matched to 32 exam majors")
    unique_ids: set[str] = set()
    exam_link_ids: set[str] = set()
    def check_english(text: object, name: str, min_length: int = 10) -> None:
        if not isinstance(text, str) or len(text.strip()) < min_length or not text.isascii() or not text.isprintable():
            issues.append(f"{name} is missing or contains non-English characters")
    for task in tasks:
        key = str(task.get("id", ""))
        exam_id = str(task.get("exam_paper_id", ""))
        if not key.isidentifier() or key in unique_ids:
            issues.append(f"Duplicate/invalid presentation id: {key}")
        unique_ids.add(key)
        if exam_id in exam_link_ids or exam_id not in papers:
            issues.append(f"Unknown or duplicate major exam reference: {exam_id}")
        exam_link_ids.add(exam_id)
        if exam_id in papers:
            paper = papers[exam_id]
            if task.get("faculty_id") != paper.get("faculty_id") or task.get("major") != paper.get("major"):
                issues.append(f"Faculty or major mismatch on {key}")
        check_english(task.get("major"), f"{key}.major")
        check_english(task.get("title"), f"{key}.title", 16)
        if task.get("timer_seconds") != 150 or float(task.get("minimum_voiced_seconds_per_slide", 0)) != 5.0:
            issues.append(f"Wrong time or microphone activity rule on {key}")
        slides = task.get("slides", [])
        if len(slides) != 3:
            issues.append(f"Expected exactly three speaking slides on {key}")
        for i, slide in enumerate(slides):
            check_english(slide.get("title"), f"{key}.slide.{i}.title")
            check_english(slide.get("talk_prompt"), f"{key}.slide.{i}.prompt", 45)
        audience = task.get("audience_question", {})
        check_english(audience.get("prompt"), f"{key}.question", 20)
        choices = audience.get("options", [])
        if len(choices) != 3 or len({str(x).casefold() for x in choices}) != 3:
            issues.append(f"Three unique audience choices required on {key}")
        for choice in choices:
            check_english(choice, f"{key}.option", 3)
        correct = audience.get("correct_index", -1)
        if not isinstance(correct, int) or isinstance(correct, bool) or correct not in (0, 1, 2):
            issues.append(f"Invalid audience answer index: {key}")
        check_english(audience.get("explanation"), f"{key}.explanation", 30)
    return issues

if __name__ == "__main__":
    problems = validate_presentations()
    if problems:
        raise SystemExit("FAIL: " + "; ".join(problems))
    print("PASS: 32 English oral presentations, 96 spoken slides, 32 Q&A prompts, privacy and 13-faculty matching")
