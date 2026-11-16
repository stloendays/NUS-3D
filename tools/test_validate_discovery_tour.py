"""Regressions for the offline, non-navigational UTown discovery experience."""
from __future__ import annotations

import copy
import json
import unittest

from tools.validate_discovery_tour import LAYOUT_PATH, TOUR_PATH, validate_tour


class TourDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.layout = json.loads(LAYOUT_PATH.read_text(encoding="utf-8"))
        cls.tour = json.loads(TOUR_PATH.read_text(encoding="utf-8"))

    def test_checked_in_source_data_passes(self) -> None:
        self.assertEqual(validate_tour(self.tour, self.layout), [])

    def test_missing_waypoint_or_reorder_fails(self) -> None:
        changed = copy.deepcopy(self.tour)
        changed["stops"][0], changed["stops"][1] = changed["stops"][1], changed["stops"][0]
        self.assertTrue(any("order" in item for item in validate_tour(changed, self.layout)))

    def test_duplicate_stop_id_fails(self) -> None:
        changed = copy.deepcopy(self.tour)
        changed["stops"][1]["id"] = changed["stops"][0]["id"]
        self.assertTrue(any("unique" in item for item in validate_tour(changed, self.layout)))

    def test_duplicate_geocoordinates_rejected(self) -> None:
        changed = copy.deepcopy(self.tour)
        changed["stops"][0]["lat"] = 1.3
        self.assertTrue(any("duplicates" in item for item in validate_tour(changed, self.layout)))

    def test_disclaimer_required(self) -> None:
        changed = copy.deepcopy(self.tour)
        changed["route_disclaimer"] = "Enjoy the campus."
        self.assertTrue(any("navigation" in item for item in validate_tour(changed, self.layout)))

    def test_checkin_radius_safety(self) -> None:
        for value in [0, 40, float("inf"), True]:
            with self.subTest(value=value):
                changed = copy.deepcopy(self.tour)
                changed["check_in_radius_m"] = value
                self.assertTrue(any("radius" in item for item in validate_tour(changed, self.layout)))


if __name__ == "__main__":
    unittest.main()
