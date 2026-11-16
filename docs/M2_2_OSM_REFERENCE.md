# M2.2 OSM footprint evidence acquisition (2026-11-16)

The existing Godot ERC/SRC 3D massing remains **estimated**. This workflow acquires independent OpenStreetMap vector outlines with source IDs, way versions, capture time, tags and coordinates for review; it does **not** silently replace the building or collision meshes.

- Workflow: https://github.com/stloendays/NUS-3D/actions/workflows/osm_reference.yml
- Command: python tools/fetch_osm_footprints.py --out build/osm-utown-candidates.json
- Output: GitHub Actions artifact utown-osm-candidate-geometry
- Source: OpenStreetMap contributors, Open Database Licence (ODbL): https://www.openstreetmap.org/copyright
- Acquisition: public OSM 0.6 map API for a small UTown bounding box, not third-party imagery or protected plans

Each candidate retains its way ID, original polygon coordinates, version and timestamp. A nearby-building match is **not** necessarily an ERC/SRC footprint; multipart buildings and courtyards require manual inspection. The selected ID defaults to null and every target remains manual-confirmation-required.

Before any polygon becomes in-game geometry, inspect the OSM feature, its geometry ring and potential holes, physical entrances, floor levels, slope/ramps, bounding consistency and whether a polygon is a building part rather than its overall outline. Only then measure change against the existing proxy and rerun route/vegetation collision checks. No grade or accessibility is inferred from this source.

Primary design/topology references: NUS ERC https://uci.nus.edu.sg/campus-life/campus-services/utown/education-resource-centre/ ; DP Architects SRC https://www.dpa.com.sg/projects/stephen-riady-centre/ . These references confirm the lower-ground café and stacked walking routes, not real metre heights.


## Frozen named P0 outlines and in-game comparison (16 November 2026)

The separate API acquisition job succeeded and yielded two unambiguously named OSM building ways:

| Scene ID | Public OSM way | Version and edit timestamp | Source polygon area (2-D, approximate) |
|---|---|---|---|
| ERC | 124549217 | v18, 2026-09-17 11:08:07 UTC | 5,546.18 square metres |
| SRC | 125774787 | v15, 2024-09-23 04:28:17 UTC | 12,605.60 square metres |

The retrieved longitude/latitude node sequences, source metadata and ODbL license notice are now stored in godot/data/osm_p0_reference.json. They are **NOT model collision geometry** and must not be described as survey-grade or accessible routes. The SRC OSM outline is substantially wider than the simplistic SRC multi-box model; automatic replacement would damage the route-clearance guarantee.

- **F6** in Godot toggles original source boundary ribbons (ERC gold, SRC cyan) drawn a little above the prototype's flat ground. Minimap overlays the same outlines.
- F6 begins **OFF**; the game keeps its original building meshes, collision, trees and schematic route unchanged.
- CI runs tools/validate_osm_reference.py and unit tests, generates an OSM-vs-model SVG and two additional screenshot frames with the debug boundary visible. This validates an independent comparison workflow rather than real-world fit.
- Source and license: OpenStreetMap contributors, ODbL 1.0: https://www.openstreetmap.org/copyright . Original feature pages: https://www.openstreetmap.org/way/124549217 and https://www.openstreetmap.org/way/125774787 .
