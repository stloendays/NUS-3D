import copy
import json
import unittest
from pathlib import Path

from tools.validate_m2_profiles import validate_m2


ROOT = Path(__file__).resolve().parents[1]
LAYOUT = json.loads((ROOT / "godot/data/utown_core.json").read_text(encoding="utf-8"))
PROFILES = json.loads((ROOT / "godot/data/m2_profiles.json").read_text(encoding="utf-8"))


class M2ArchitectureValidationTests(unittest.TestCase):
    def test_current_profiles_are_consistent(self):
        self.assertEqual(validate_m2(LAYOUT, PROFILES), [])

    def test_missing_style_is_rejected(self):
        invalid = copy.deepcopy(PROFILES)
        invalid["profiles"]["SRC"]["style"] = "erc"
        self.assertTrue(any("style/building_id mismatch" in x for x in validate_m2(LAYOUT, invalid)))

    def test_non_estimated_size_claim_is_rejected(self):
        invalid = copy.deepcopy(PROFILES)
        invalid["profiles"]["ERC"]["geometry_confidence"] = "verified"
        self.assertTrue(any("explicitly identified" in x for x in validate_m2(LAYOUT, invalid)))

    def test_invalid_units_or_parameter_is_rejected(self):
        invalid = copy.deepcopy(PROFILES)
        invalid["profiles"]["SRC"]["estimates_m"]["disc_radius"] = -5
        self.assertTrue(any("finite positive estimate" in x for x in validate_m2(LAYOUT, invalid)))

    def test_reference_only_media_is_required(self):
        invalid = copy.deepcopy(PROFILES)
        invalid["profiles"]["ERC"]["license_status"] = "free-to-use"
        self.assertTrue(any("reference-only" in x for x in validate_m2(LAYOUT, invalid)))


if __name__ == "__main__":
    unittest.main()
