"""Top-down SVG audit report tests; no external GIS imagery is bundled."""
from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import unittest

from tools.render_utown_plan import render_plan

ROOT = Path(__file__).resolve().parents[1]


class RenderUTownPlanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.site = json.loads((ROOT / "godot/data/utown_core.json").read_text(encoding="utf-8"))

    def test_creates_original_svg_with_landmarks_and_provenance(self):
        svg = render_plan(self.site)
        self.assertTrue(svg.startswith('<svg xmlns="http://www.w3.org/2000/svg"'))
        self.assertIn("SCHEMATIC ONLY", svg)
        self.assertIn("ERC</text>", svg)
        self.assertIn("SRC</text>", svg)
        self.assertIn("11 pedestrian guide segments", svg)
        self.assertIn("0 proxy footprint conflicts", svg)
        self.assertEqual(svg.count('class="walkway"'), 4)
        self.assertEqual(svg.count('class="detour"'), 2)
        self.assertIn("No third-party map tiles", svg)

    def test_svg_labels_escape_xml(self):
        altered = deepcopy(self.site)
        altered["loop"][0]["name"] = "A & B <C>"
        svg = render_plan(altered)
        self.assertIn("A &amp; B &lt;C&gt;", svg)

    def test_bad_detour_indices_rejected(self):
        altered = deepcopy(self.site)
        altered["walkways"][1]["schematic_detour_indices"] = [100]
        with self.assertRaises(ValueError):
            render_plan(altered)

    def test_svg_generation_is_deterministic(self):
        self.assertEqual(render_plan(self.site), render_plan(self.site))


if __name__ == "__main__":
    unittest.main()
