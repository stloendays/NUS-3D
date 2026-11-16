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
