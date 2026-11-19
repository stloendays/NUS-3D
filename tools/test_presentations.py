"""Data and source-isolation checks for original English oral presentation gameplay."""
from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from tools.validate_presentations import DATA, EXAMS, validate_presentations

class VoicePresentationDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(DATA.read_text(encoding="utf-8"))

    def _modified(self, altered: dict) -> list[str]:
        with TemporaryDirectory() as temp:
            path = Path(temp) / "presentation.json"
            path.write_text(json.dumps(altered, ensure_ascii=False), encoding="utf-8")
            return validate_presentations(path, EXAMS)

    def test_data_contract(self):
        self.assertEqual(validate_presentations(), [])

    def test_all_majors_and_faculties(self):
        tasks = self.data["presentations"]
        self.assertEqual(len(tasks), 32)
        self.assertEqual(sum(len(t["slides"]) for t in tasks), 96)
        self.assertEqual(len({t["faculty_id"] for t in tasks}), 13)
        self.assertEqual(len({t["exam_paper_id"] for t in tasks}), 32)

    def test_wrong_faculty_rejected(self):
        bad = deepcopy(self.data)
        bad["presentations"][0]["faculty_id"] = "law"
        self.assertTrue(any("Faculty or major mismatch" in e for e in self._modified(bad)))

    def test_wrong_slide_count_rejected(self):
        bad = deepcopy(self.data)
        bad["presentations"][0]["slides"].pop()
        self.assertTrue(any("three speaking slides" in e for e in self._modified(bad)))

    def test_non_english_prompt_rejected(self):
        bad = deepcopy(self.data)
        bad["presentations"][1]["slides"][0]["talk_prompt"] += " 中文"
        self.assertTrue(any("non-English" in e for e in self._modified(bad)))

    def test_mic_privacy_contract_rejected(self):
        bad = deepcopy(self.data)
        bad["privacy"] = "The game uploads audio to an external server."
        self.assertTrue(any("Privacy notice" in e for e in self._modified(bad)))

    def test_no_recording_code_path(self):
        code = (DATA.parents[1] / "scripts" / "utown_voice_presentation.gd").read_text(encoding="utf-8")
        forbidden = ("AudioEffectRecord.new(", "FileAccess.open(", "HTTPClient.new(", "HTTPRequest.new(", "AudioStreamWAV.new(")
        for signature in forbidden:
            self.assertNotIn(signature, code)
        self.assertIn("AudioEffectCapture.new()", code)
        self.assertIn("func _stop_microphone()", code)
        self.assertIn("AudioServer.set_bus_mute(bus_index, true)", code)

if __name__ == "__main__":
    unittest.main()
