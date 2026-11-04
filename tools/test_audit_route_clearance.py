"""Regression tests for provisional UTown 2-D pedestrian clearance."""
from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import unittest

from tools.audit_route_clearance import (
    _segments_intersect, assess_layout, footprint_vertices, segment_footprint_gap,
)

ROOT = Path(__file__).resolve().parents[1]


class RouteClearanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.site = json.loads((ROOT / "godot/data/utown_core.json").read_text(encoding="utf-8"))

    def test_current_provisional_route_clears_proxy_massings(self):
        segments = assess_layout(self.site)
        self.assertEqual(len(segments), 11)
        self.assertEqual([segment for segment in segments if segment.conflict], [])
        self.assertTrue(all(segment.nearest_building for segment in segments))

    def test_prior_direct_src_approach_is_detected(self):
        old = deepcopy(self.site)
        del old["walkways"][1]["lonlat"][3:5]
        conflicts = [row for row in assess_layout(old) if row.conflict]
        self.assertTrue(any(row.walkway_index == 1 and row.nearest_building == "SRC"
                            for row in conflicts))

    def test_segment_through_box_is_zero_gap(self):
        rect = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        self.assertEqual(segment_footprint_gap((-3, 0), (3, 0), rect), 0)

    def test_endpoint_inside_box_is_zero_gap(self):
        rect = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        self.assertEqual(segment_footprint_gap((0, 0), (4, 0), rect), 0)

    def test_parallel_outside_box_has_metric_gap(self):
        rect = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        self.assertAlmostEqual(segment_footprint_gap((-3, 4), (3, 4), rect), 3)

    def test_rotated_footprint_keeps_local_width(self):
        b = {"id": "TEST", "lon": 103.77316, "lat": 1.305075, "rotation_deg": 30}
        part = {"dx": 2, "dn": 3, "w": 10, "d": 6}
        corners = footprint_vertices(b, part, 103.77316, 1.305075)
        import math
        self.assertAlmostEqual(math.dist(corners[0], corners[1]), 10)
        self.assertAlmostEqual(math.dist(corners[1], corners[2]), 6)

    def test_collinear_endpoint_touch_and_parallel_disjoint(self):
        self.assertTrue(_segments_intersect((0, 0), (2, 0), (2, 0), (4, 0)))
        self.assertFalse(_segments_intersect((0, 0), (2, 0), (3, 0), (4, 0)))

    def test_invalid_margin_rejected(self):
        with self.assertRaises(ValueError):
            assess_layout(self.site, -0.1)


if __name__ == "__main__":
    unittest.main()
