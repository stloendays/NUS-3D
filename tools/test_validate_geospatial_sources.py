import copy
import json
from pathlib import Path
import unittest

from tools.validate_geospatial_sources import validate_osm, validate_terrain

ROOT = Path(__file__).resolve().parents[1]


class GeospatialSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.osm = json.loads((ROOT / "godot/data/osm_utown_snapshot.json").read_text(encoding="utf-8"))
        cls.terrain = json.loads((ROOT / "godot/data/terrain_contours.json").read_text(encoding="utf-8"))

    def test_versioned_osm_snapshot_is_valid(self):
        self.assertEqual(validate_osm(self.osm), [])
        self.assertEqual(self.osm["summary"]["building_count"], 38)
        self.assertEqual(self.osm["summary"]["roof_count"], 4)
        self.assertEqual(self.osm["summary"]["path_count"], 118)

    def test_osm_requires_odbl_attribution(self):
        altered = copy.deepcopy(self.osm)
        altered["attribution"] = ""
        self.assertTrue(any("contributor attribution" in item for item in validate_osm(altered)))

    def test_osm_building_ring_must_be_closed(self):
        altered = copy.deepcopy(self.osm)
        index = next(i for i, item in enumerate(altered["features"]) if item["feature_type"] == "building")
        altered["features"][index]["coordinates"][-1] = altered["features"][index]["coordinates"][-2]
        self.assertTrue(any("ring must be closed" in item for item in validate_osm(altered)))

    def test_contour_reference_is_valid_and_keeps_datum_unknown(self):
        self.assertEqual(validate_terrain(self.terrain), [])
        self.assertEqual({item["height_m"] for item in self.terrain["contours"]}, {5, 10, 15, 20, 25})

    def test_terrain_datum_cannot_be_claimed_as_known(self):
        altered = copy.deepcopy(self.terrain)
        altered["source_metadata"]["vertical_datum"] = "mean sea level"
        self.assertTrue(any("unknown vertical datum" in item for item in validate_terrain(altered)))

    def test_terrain_must_not_be_promoted_to_a_surveyed_dem(self):
        altered = copy.deepcopy(self.terrain)
        altered["status"] = "surveyed_dem"
        self.assertTrue(any("planimetric contour reference only" in item for item in validate_terrain(altered)))

    def test_contour_reuse_terms_must_remain_under_review(self):
        altered = copy.deepcopy(self.terrain)
        altered["source_metadata"]["license_status"] = "open data"
        self.assertTrue(any("reuse status must remain under review" in item for item in validate_terrain(altered)))


if __name__ == "__main__":
    unittest.main()
