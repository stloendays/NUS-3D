"""Guarantee the in-game static OSM fit card remains in sync with raw GIS+proxy geometry."""
import json
from pathlib import Path
import unittest
from tools.audit_osm_proxy_fit import compare_layout

ROOT = Path(__file__).resolve().parents[1]


class FitCardSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = json.loads((ROOT / "godot/data/utown_core.json").read_text())
        cls.osm = json.loads((ROOT / "godot/data/osm_p0_reference.json").read_text())
        cls.card = json.loads((ROOT / "godot/data/osm_fit_baseline.json").read_text())

    def test_card_is_source_derived_not_hardcoded_unchecked(self):
        live = compare_layout(self.layout, self.osm)
        self.assertEqual(self.card["schema_version"], 1)
        self.assertEqual(self.card["status"], "M2.3-static-review-snapshot-not-surveyed")
        self.assertEqual(self.card["osm_snapshot_retrieved_utc"], live["source_snapshot_utc"])
        self.assertEqual(self.card["attribution"], live["attribution"])
        self.assertEqual(self.card["license"], live["license"])
        for item, observed in zip(self.card["metrics"], live["buildings"], strict=True):
            self.assertEqual(item, {key: observed[key] for key in item.keys()})

    def test_notice_is_explicit_and_no_route_accuracy_claim(self):
        self.assertIn("NOT true building fidelity", self.card["notice"])
        self.assertIn("routes", self.card["notice"])
        self.assertEqual({m["id"] for m in self.card["metrics"]}, {"ERC", "SRC"})


if __name__ == "__main__":
    unittest.main()
