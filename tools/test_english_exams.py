"""Contract tests for the English-only major-specific NUS-3D exam catalog."""
from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from tools.validate_english_exams import EXAMS, COURSEWORK, validate_exams

class EnglishExamCatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = json.loads(EXAMS.read_text(encoding="utf-8"))

    def _validate_modified(self, data):
        with TemporaryDirectory() as location:
            path = Path(location) / "exams.json"
            path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
            return validate_exams(path, COURSEWORK)

    def test_original_catalog_is_valid(self):
        self.assertEqual(validate_exams(), [])

    def test_all_13_faculties_and_32_major_papers(self):
        faculties = {p["faculty_id"] for p in self.catalog["papers"]}
        self.assertEqual(len(faculties), 13)
        self.assertEqual(len(self.catalog["papers"]), 32)
        self.assertEqual(sum(len(p["questions"]) for p in self.catalog["papers"]), 160)

    def test_detects_invalid_correct_answer(self):
        bad = deepcopy(self.catalog)
        bad["papers"][0]["questions"][0]["correct_index"] = 4
        self.assertTrue(any("correct choice" in problem for problem in self._validate_modified(bad)))

    def test_detects_non_english_text(self):
        bad = deepcopy(self.catalog)
        bad["papers"][1]["questions"][0]["prompt"] += " 中文"
        self.assertTrue(any("English-only" in problem for problem in self._validate_modified(bad)))

    def test_detects_duplicate_question(self):
        bad = deepcopy(self.catalog)
        bad["papers"][1]["questions"][0]["id"] = bad["papers"][0]["questions"][0]["id"]
        self.assertTrue(any("duplicate question" in problem for problem in self._validate_modified(bad)))

    def test_detects_missing_faculty_coverage(self):
        bad = deepcopy(self.catalog)
        bad["papers"] = [p for p in bad["papers"] if p["faculty_id"] != "dentistry"]
        self.assertTrue(any("dentistry" in problem for problem in self._validate_modified(bad)))

    def test_detects_unofficial_contract_regression(self):
        bad = deepcopy(self.catalog)
        bad["unofficial"] = False
        self.assertTrue(any("fictional" in problem for problem in self._validate_modified(bad)))

if __name__ == "__main__":
    unittest.main()
