import copy
import unittest

from tools.validate_utown_data import validate_document


def sample():
    return {
        "schema_version": 1,
        "spatial_reference": {
            "crs": "EPSG:4326 (WGS84)",
            "origin_lon": 103.77,
            "origin_lat": 1.30,
            "precision": "approximate, not survey grade",
        },
        "ground_size_m": [100, 100],
        "green": {"polygon_lonlat": [
            [103.7699, 1.2999], [103.7701, 1.2999],
            [103.7701, 1.3001], [103.7699, 1.3001],
        ]},
        "buildings": [{
            "id": "ERC", "name": "Education Resource Centre",
            "lon": 103.77, "lat": 1.30, "rotation_deg": 10,
            "dimensions_status": "estimated",
            "parts": [{"dx": 0, "dn": 0, "w": 10, "d": 12, "h": 15}],
        }],
        "loop": [
            {"id": "GREEN", "lon": 103.77, "lat": 1.30},
            {"id": "ERC", "lon": 103.7701, "lat": 1.30},
            {"id": "PLAZA", "lon": 103.7701, "lat": 1.3001},
        ],
        "walkways": [
            {"width_m": 3, "lonlat": [[103.77, 1.30], [103.7701, 1.30]]},
            {"width_m": 3, "lonlat": [[103.7701, 1.30], [103.7701, 1.3001]]},
            {"width_m": 3, "lonlat": [[103.7701, 1.3001], [103.77, 1.30]]},
        ],
        "no_official_affiliation": True,
        "data_credit": "OpenStreetMap contributors; sources listed in docs.",
    }


class ValidateUTownDataTests(unittest.TestCase):
    def errors(self, document):
        return [item for item in validate_document(document) if item.severity == "ERROR"]

    def test_valid_document(self):
        self.assertEqual(self.errors(sample()), [])

    def test_duplicate_building_id(self):
        document = sample()
        document["buildings"].append(copy.deepcopy(document["buildings"][0]))
        self.assertTrue(any("duplicate building id" in item.message for item in self.errors(document)))

    def test_disconnected_walkway(self):
        document = sample()
        document["walkways"][0]["lonlat"][0][0] += 0.0002
        self.assertTrue(any("start is more than 2 m" in item.message for item in self.errors(document)))

    def test_degenerate_green_polygon(self):
        document = sample()
        document["green"]["polygon_lonlat"] = [[103.77, 1.30]] * 4
        self.assertTrue(any("polygon area" in item.message for item in self.errors(document)))

    def test_invalid_building_dimensions(self):
        document = sample()
        document["buildings"][0]["parts"][0]["h"] = -2
        self.assertTrue(any("must be positive" in item.message for item in self.errors(document)))

    def test_ground_bounds(self):
        document = sample()
        document["ground_size_m"] = [20, 20]
        self.assertTrue(any("outside ground bounds" in item.message for item in self.errors(document)))

    def test_self_intersecting_polygon(self):
        document = sample()
        document["green"]["polygon_lonlat"] = [
            [103.7699, 1.2999], [103.7701, 1.3001],
            [103.7699, 1.3001], [103.7701, 1.2999],
        ]
        self.assertTrue(any("self-intersects" in item.message for item in self.errors(document)))


if __name__ == "__main__":
    unittest.main()
