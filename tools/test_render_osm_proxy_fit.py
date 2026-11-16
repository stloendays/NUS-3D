"""Render a self-contained, original and ODbL-attributed ERC/SRC GIS delta SVG."""
import json
from pathlib import Path
import unittest
from xml.etree import ElementTree

from tools.render_osm_proxy_fit import render_scorecard

ROOT = Path(__file__).resolve().parents[1]


class OSMScorecardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = json.loads((ROOT / "godot/data/utown_core.json").read_text())
        cls.osm = json.loads((ROOT / "godot/data/osm_p0_reference.json").read_text())

    def test_svg_has_both_buildings_and_license_and_measured_disagreement(self):
        rendered = render_scorecard(self.layout, self.osm)
        xml = ElementTree.fromstring(rendered)
        self.assertEqual(xml.attrib["width"], "1280")
        self.assertIn("Education Resource Centre", rendered)
        self.assertIn("Stephen Riady Centre", rendered)
        self.assertIn("ODbL 1.0", rendered)
        self.assertIn("OSM covered:", rendered)
        self.assertIn("Proxy within OSM:", rendered)
        self.assertIn("not a campus positioning accuracy score", rendered)
        self.assertEqual(rendered.count('fill-opacity=".41"'), 5)

    def test_output_is_deterministic(self):
        self.assertEqual(render_scorecard(self.layout, self.osm),
                         render_scorecard(self.layout, self.osm))


if __name__ == "__main__":
    unittest.main()
