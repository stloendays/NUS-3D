"""2-D concave ring and advisory route-overlap audit tests."""
import json
from pathlib import Path
import unittest
from tools.audit_osm_route import inside_polygon, segment_ring_gap, audit_osm_route

ROOT = Path(__file__).resolve().parents[1]


class OSMRouteTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = json.loads((ROOT / "godot/data/utown_core.json").read_text())
        cls.osm = json.loads((ROOT / "godot/data/osm_p0_reference.json").read_text())

    def test_concave_ring(self):
        ring = [(0,0),(4,0),(4,1),(1,1),(1,4),(0,4),(0,0)]
        self.assertTrue(inside_polygon((0.5,3), ring))
        self.assertFalse(inside_polygon((3,3), ring))
        self.assertEqual(segment_ring_gap((-1,2),(2,2),ring),0)
        self.assertGreater(segment_ring_gap((2,3),(4,3),ring),0)

    def test_live_reference_overlaps_are_advisory(self):
        audit = audit_osm_route(self.layout, self.osm)
        self.assertEqual(audit["segment_vs_polygon_tests"], 22)
        self.assertGreater(audit["plan_view_intersections"], 0)
        self.assertTrue(any(e["osm_building"]=="ERC" for e in audit["intersections"]))
        self.assertTrue(any(e["osm_building"]=="SRC" for e in audit["intersections"]))
        self.assertIn("NOT-pedestrian-blockage",audit["status"])


if __name__ == "__main__":
    unittest.main()
