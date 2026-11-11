import copy
import json
from pathlib import Path
import unittest

from tools.validate_campus_life import validate_campus_life

ROOT = Path(__file__).resolve().parents[1]


class CampusLifeValidationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.life = json.loads((ROOT / "godot/data/campus_life.json").read_text(encoding="utf-8"))
        cls.layout = json.loads((ROOT / "godot/data/utown_core.json").read_text(encoding="utf-8"))

    def test_campus_props_and_discovery_points_are_valid(self):
        self.assertEqual(validate_campus_life(self.life, self.layout), [])
        self.assertEqual(len(self.life["furniture"]), 8)
        self.assertEqual({item["id"] for item in self.life["discoveries"]}, {"GREEN", "ERC", "SRC", "PLAZA"})

    def test_prop_cannot_be_moved_onto_a_walkway(self):
        altered = copy.deepcopy(self.life)
        altered["furniture"][0]["lon"] = 103.77314
        altered["furniture"][0]["lat"] = 1.305035
        self.assertTrue(any("walkway centreline" in error for error in validate_campus_life(altered, self.layout)))

    def test_props_must_remain_inside_town_green(self):
        altered = copy.deepcopy(self.life)
        altered["furniture"][0]["lon"] = 103.775
        altered["furniture"][0]["lat"] = 1.308
        self.assertTrue(any("outside the current Town Green polygon" in error for error in validate_campus_life(altered, self.layout)))

    def test_discovery_points_must_match_the_route(self):
        altered = copy.deepcopy(self.life)
        altered["discoveries"][0]["lon"] += 0.0001
        self.assertTrue(any("does not align with its route stop" in error for error in validate_campus_life(altered, self.layout)))

    def test_illustrative_props_must_not_be_presented_as_real_mapped_amenities(self):
        altered = copy.deepcopy(self.life)
        altered["status"] = "surveyed_existing_furniture"
        self.assertTrue(any("illustrative and not field verified" in error for error in validate_campus_life(altered, self.layout)))


if __name__ == "__main__":
    unittest.main()
