"""Exact projected planar polygon proxy fit, including overlapping massing parts."""
from __future__ import annotations

from copy import deepcopy
import json
import math
from pathlib import Path
import unittest

from tools.audit_osm_proxy_fit import (
    area, centroid, clip_convex, compare_layout, normalized_ring,
    triangulate_simple_ring, union_proxy_and_overlap,
)

ROOT = Path(__file__).resolve().parents[1]


class ProxyFitTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = json.loads((ROOT / "godot/data/utown_core.json").read_text())
        cls.osm = json.loads((ROOT / "godot/data/osm_p0_reference.json").read_text())

    def test_concave_polygon_triangulation_preserves_area(self):
        l = [(0, 0), (4, 0), (4, 1), (1, 1), (1, 4), (0, 4), (0, 0)]
        self.assertEqual(area(normalized_ring(l)), 7)
        self.assertAlmostEqual(sum(area(t) for t in triangulate_simple_ring(l)), 7)

    def test_clockwise_ring_centroid_and_triangle_area(self):
        clockwise = [(0, 0), (0, 4), (4, 4), (4, 0), (0, 0)]
        self.assertAlmostEqual(area(normalized_ring(clockwise)), 16)
        self.assertEqual(tuple(round(v, 2) for v in centroid(clockwise[:-1])), (2, 2))

    def test_convex_clip_partial_overlap(self):
        a = [(0,0),(2,0),(2,2),(0,2)]
        b = [(1,1),(3,1),(3,3),(1,3)]
        self.assertAlmostEqual(area(clip_convex(a,b)), 1)

    def test_convex_clip_disjoint(self):
        a = [(0,0),(1,0),(1,1),(0,1)]
        b = [(3,0),(4,0),(4,1),(3,1)]
        self.assertEqual(clip_convex(a,b), [])

    def test_overlapping_parts_union_not_double_counted(self):
        a = [(0,0),(2,0),(2,2),(0,2)]
        b = [(1,0),(3,0),(3,2),(1,2)]
        outer = [(0,0),(3,0),(3,2),(0,2),(0,0)]
        model, common, centre = union_proxy_and_overlap([a,b], triangulate_simple_ring(outer))
        self.assertAlmostEqual(model, 6)
        self.assertAlmostEqual(common, 6)
        self.assertAlmostEqual(centre[0], 1.5)

    def test_no_common_area(self):
        a = [(0,0),(2,0),(2,2),(0,2)]
        b = [(4,4),(6,4),(6,6),(4,6),(4,4)]
        model, common, _ = union_proxy_and_overlap([a], triangulate_simple_ring(b))
        self.assertAlmostEqual(model, 4)
        self.assertAlmostEqual(common, 0)

    def test_frozen_osm_and_proxy_comparison_is_bounded(self):
        result = compare_layout(self.layout, self.osm)
        self.assertEqual([r["id"] for r in result["buildings"]], ["ERC", "SRC"])
        self.assertEqual(result["license"], "ODbL 1.0")
        for item in result["buildings"]:
            self.assertGreater(item["source_area_m2"], 500)
            self.assertGreater(item["proxy_union_area_m2"], 100)
            self.assertLess(item["overlap_area_m2"], item["source_area_m2"] + 0.01)
            self.assertLess(item["overlap_area_m2"], item["proxy_union_area_m2"] + 0.01)
            self.assertGreaterEqual(item["intersection_over_union"], 0)
            self.assertLessEqual(item["intersection_over_union"], 1)
            self.assertGreater(item["source_only_area_m2"], 0)

    def test_malformed_ring_does_not_claim_metric(self):
        with self.assertRaises(ValueError):
            triangulate_simple_ring([(0,0),(1,1),(2,2)])

    def test_malformed_source_to_model_mapping_is_detected(self):
        fake = deepcopy(self.osm)
        fake["features"][0]["id"] = "UNMATCHED"
        with self.assertRaises(ValueError):
            compare_layout(self.layout, fake)


if __name__ == "__main__":
    unittest.main()
