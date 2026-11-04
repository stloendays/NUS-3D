"""Validate evidence-linked camera metadata and proxy obstacle clearance."""
from copy import deepcopy
import json
from pathlib import Path
import unittest

from tools.validate_viewpoints import validate_viewpoints

ROOT = Path(__file__).resolve().parents[1]


class ViewpointTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = json.loads((ROOT / "godot/data/utown_core.json").read_text(encoding="utf-8"))
        cls.views = json.loads((ROOT / "godot/data/viewpoints.json").read_text(encoding="utf-8"))

    def test_valid_registry(self):
        self.assertEqual(validate_viewpoints(self.layout, self.views), [])

    def test_camera_inside_proxy_is_rejected(self):
        record = deepcopy(self.views)
        record["viewpoints"][0]["lon"] = self.layout["buildings"][0]["lon"]
        record["viewpoints"][0]["lat"] = self.layout["buildings"][0]["lat"]
        self.assertTrue(any("footprint" in err for err in validate_viewpoints(self.layout, record)))

    def test_duplicate_id_rejected(self):
        record = deepcopy(self.views)
        record["viewpoints"][1]["id"] = record["viewpoints"][0]["id"]
        self.assertTrue(any("duplicate" in err for err in validate_viewpoints(self.layout, record)))

    def test_missing_photo_license_rejected(self):
        record = deepcopy(self.views)
        record["viewpoints"][0]["license"] = None
        self.assertTrue(any("license" in err for err in validate_viewpoints(self.layout, record)))

    def test_heading_range_rejected(self):
        record = deepcopy(self.views)
        record["viewpoints"][0]["heading_deg"] = 360
        self.assertTrue(any("heading" in err for err in validate_viewpoints(self.layout, record)))

    def test_synthetic_claims_no_photo(self):
        record = deepcopy(self.views)
        record["viewpoints"][-1]["source_url"] = "https://fake.example.org/a.jpg"
        self.assertTrue(any("synthetic" in err for err in validate_viewpoints(self.layout, record)))


if __name__ == "__main__":
    unittest.main()
