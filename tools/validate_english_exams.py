#!/usr/bin/env python3
"""Validate original, English-only, fictional major exam papers for NUS-3D."""
from __future__ import annotations

import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXAMS = ROOT / "godot/data/english_exam_papers.json"
COURSEWORK = ROOT / "godot/data/coursework_quests.json"
SCHEMA = "nus3d-english-exams-v1"

def validate_exams(exam_path: Path = EXAMS, coursework_path: Path = COURSEWORK) -> list[str]:
    issues: list[str] = []
    try:
        data = json.loads(exam_path.read_text(encoding="utf-8"))
        coursework = json.loads(coursework_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return [f"Cannot read exam or faculty catalog: {error}"]
    if data.get("schema") != SCHEMA:
        issues.append("Exam schema mismatch")
    if data.get("language") != "en" or data.get("unofficial") is not True or data.get("offline") is not True:
        issues.append("Exam data must be English-only, fictional and offline")
    if "fictional" not in str(data.get("status", "")).lower():
        issues.append("Missing fictional-assessment disclaimer")
    scoring = data.get("scoring", {})
    if scoring != {"points_per_correct": 20, "pass_mark": 60, "first_pass_xp": 90, "first_pass_credits": 25}:
        issues.append("Scoring rules must match the game implementation")
    known_faculties = {str(x["id"]) for x in coursework.get("faculty_options", [])}
    expected = 13
    if len(known_faculties) != expected:
        issues.append(f"Expected {expected} existing faculties, found {len(known_faculties)}")
    paper_ids: set[str] = set()
    majors: set[tuple[str, str]] = set()
    question_ids: set[str] = set()
    seen_prompts: set[str] = set()
    faculty_counts: Counter[str] = Counter()
    total_questions = 0
    papers = data.get("papers", [])
    if not isinstance(papers, list) or len(papers) < 26:
        issues.append("Exam catalog must contain at least 26 distinct majors")
        return issues
    def english_only(value: object, source: str) -> None:
        text = str(value)
        if not text.strip() or not text.isascii() or not all(ch.isprintable() for ch in text):
            issues.append(f"{source} must have printable English-only text")
    for paper in papers:
        identity = str(paper.get("id", ""))
        faculty_id = str(paper.get("faculty_id", ""))
        major = str(paper.get("major", ""))
        if not identity.isidentifier() or identity in paper_ids:
            issues.append(f"Invalid or duplicate paper ID: {identity}")
        paper_ids.add(identity)
        if faculty_id not in known_faculties:
            issues.append(f"Unknown faculty for paper {identity}: {faculty_id}")
        faculty_counts[faculty_id] += 1
        if (faculty_id, major) in majors:
            issues.append(f"Duplicate major in faculty: {faculty_id}/{major}")
        majors.add((faculty_id, major))
        english_only(major, f"{identity}.major")
        english_only(paper.get("title", ""), f"{identity}.title")
        if int(paper.get("duration_seconds", 0)) != 180 or int(paper.get("pass_mark", 0)) != 60:
            issues.append(f"{identity} must have a 180-second timer and 60% pass mark")
        questions = paper.get("questions", [])
        if not isinstance(questions, list) or len(questions) != 5:
            issues.append(f"{identity} must have exactly five questions")
            continue
        for question in questions:
            total_questions += 1
            qid = str(question.get("id", ""))
            prompt = str(question.get("prompt", ""))
            if not qid.isidentifier() or qid in question_ids:
                issues.append(f"Invalid or duplicate question ID: {qid}")
            question_ids.add(qid)
            if prompt in seen_prompts:
                issues.append(f"Repeated question prompt: {qid}")
            seen_prompts.add(prompt)
            english_only(prompt, f"{qid}.prompt")
            if len(prompt) < 35:
                issues.append(f"Insufficiently specific question: {qid}")
            options = question.get("options", [])
            if not isinstance(options, list) or len(options) != 4:
                issues.append(f"{qid} must have four answer choices")
                continue
            if len({str(option).casefold().strip() for option in options}) != 4:
                issues.append(f"{qid} has repeated answer choices")
            for n, option in enumerate(options):
                english_only(option, f"{qid}.option.{n}")
            index = question.get("correct_index", -1)
            if not isinstance(index, int) or isinstance(index, bool) or index not in range(4):
                issues.append(f"Invalid correct choice for {qid}")
            explanation = question.get("explanation", "")
            english_only(explanation, f"{qid}.explanation")
            if len(str(explanation)) < 35:
                issues.append(f"Answer explanation too short for {qid}")
    for faculty_id in sorted(known_faculties):
        if faculty_counts[faculty_id] < 2:
            issues.append(f"Faculty {faculty_id} needs at least two distinct major papers")
    if total_questions < 130:
        issues.append(f"Only {total_questions} questions, expected at least 130")
    return issues

if __name__ == "__main__":
    failures = validate_exams()
    if failures:
        raise SystemExit("FAIL: " + "; ".join(failures))
    print("PASS: English-only original major exam papers, 13 faculties, unique questions and scoring contracts")
