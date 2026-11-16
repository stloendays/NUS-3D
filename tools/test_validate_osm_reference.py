"""Frozen OSM debug overlay provenance / consistency checks."""
from copy import deepcopy
import json
from pathlib import Path
import unittest
from tools.validate_osm_reference import validate_snapshot

ROOT = Path(__file__).resolve().parents[1]


class ReferenceGeometryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = json.loads((ROOT / "godot/data/utown_core.json").read_text())
        cls.snapshot = json.loads((ROOT / "godot/data/osm_p0_reference.json").read_text())

    def test_current_snapshot_validates(self):
        self.assertEqual(validate_snapshot(self.snapshot, self.layout), [])
        self.assertEqual(len(self.snapshot["features"][0]["coordinates_lonlat"]), 38)
        self.assertEqual(len(self.snapshot["features"][1]["coordinates_lonlat"]), 72)

    def test_incorrect_license_detected(self):
        modified = deepcopy(self.snapshot)
        modified["license"] = "CC0"
        self.assertTrue(any("ODbL" in e for e in validate_snapshot(modified, self.layout)))

    def test_open_ring_detected(self):
        modified = deepcopy(self.snapshot)
        modified["features"][0]["coordinates_lonlat"].pop()
        self.assertTrue(any("closed" in e for e in validate_snapshot(modified, self.layout)))

    def test_wrong_source_id_detected(self):
        modified = deepcopy(self.snapshot)
        modified["features"][1]["osm_way_id"] = 999
        self.assertTrue(any("way URL" in e for e in validate_snapshot(modified, self.layout)))

    def test_area_mismatch_detected(self):
        modified = deepcopy(self.snapshot)
        modified["features"][0]["area_m2_approx"] *= 1.4
        self.assertTrue(any("area" in e for e in validate_snapshot(modified, self.layout)))


if __name__ == "__main__":
    unittest.main()
