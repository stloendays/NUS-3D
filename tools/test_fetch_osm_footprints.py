"""Offline tests for real-source OSM XML parsing and provenance."""
import json
from pathlib import Path
import unittest
from tools.fetch_osm_footprints import parse_osm_xml, make_report, polygon_area

ROOT = Path(__file__).resolve().parents[1]
XML = b'''<osm version="0.6">
<node id="1" lon="103.77248" lat="1.30457"/>
<node id="2" lon="103.77253" lat="1.30457"/>
<node id="3" lon="103.77253" lat="1.30463"/>
<node id="4" lon="103.77248" lat="1.30463"/>
<way id="125774787" version="7" timestamp="2026-01-01T00:00:00Z">
<nd ref="1"/><nd ref="2"/><nd ref="3"/><nd ref="4"/><nd ref="1"/>
<tag k="name" v="Stephen Riady Centre"/><tag k="building" v="university"/>
</way>
<way id="2"><nd ref="1"/><nd ref="2"/><nd ref="3"/><nd ref="4"/><nd ref="1"/><tag k="highway" v="footway"/></way>
</osm>'''


class OSMParserTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = json.loads((ROOT / "godot/data/utown_core.json").read_text())

    def test_parse_closed_building_only(self):
        result = parse_osm_xml(XML)
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["osm_way_id"], 125774787)
        self.assertEqual(result[0]["osm_version"], 7)
        self.assertEqual(result[0]["osm_timestamp"], "2026-01-01T00:00:00Z")
        self.assertGreater(result[0]["area_m2_approx"], 30)

    def test_report_not_auto_selected(self):
        report = make_report(XML, self.layout, "fixture://local", "2026-11-16T00:00:00Z")
        self.assertEqual(report["license"], "ODbL 1.0")
        src = report["targets"]["SRC"]
        self.assertEqual(src["candidates"][0]["candidate_reason"], "known-OSM-ID")
        self.assertIsNone(src["selected_way_id"])

    def test_non_osm_rejected(self):
        with self.assertRaises(ValueError):
            parse_osm_xml(b"<html/>")

    def test_unclosed_polygon_zero_area(self):
        self.assertEqual(polygon_area([[0,0],[1,0],[1,1]]), 0)


if __name__ == "__main__":
    unittest.main()
