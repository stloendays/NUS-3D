# M1.5 — source-data validation and scene consistency

**Status:** implemented on 2026-11-03. M1 remains open until UTown geometry, pedestrian routes, elevations and Windows rendering are checked against real-world evidence.

## Why this stage exists

The first greybox is driven by `godot/data/utown_core.json`. Valid JSON can still contain invalid coordinates, duplicate IDs, degenerate polygons, disconnected route segments or buildings extending beyond the ground plane. These errors should be caught before opening the scene in Godot.

## Automated checks

Run from the repository root:

```bash
python tools/validate_utown_data.py
python -m unittest discover -s tools -t . -v
```

The validator checks WGS84 coordinate ranges, unique IDs, Town Green polygon area and self-intersections, positive massing dimensions, rotated building bounds with a 5 m ground margin, walkway continuity against the four-stop loop, and attribution/non-affiliation fields.

GitHub Actions runs the validator and its regression tests before the Godot import and smoke test. The tests cover valid input, duplicate IDs, disconnected paths, degenerate and self-intersecting polygons, invalid dimensions, and undersized ground bounds.

## Geometry correction

The RC4 proxy reaches approximately 372 m north of the local origin, while the previous 720 m ground depth extended only 360 m in that direction. The provisional ground depth is now 800 m to contain the current proxy. This is a containment correction, **not** evidence that the RC4 location or dimensions are accurate.

## Vegetation placement

Procedural trees now use rotated building-part footprints with an 8 m buffer, instead of excluding only a 35 m circle around building centres. Trees are also kept outside conceptual pedestrian corridors (half the path width plus 2 m). The 64 accepted tree positions are rendered in two MultiMesh batches (trunks and canopies), replacing 128 individual MeshInstance3D nodes. The Godot smoke test checks both batch counts and every generated tree position.

## What these checks do not prove

- Real building footprints, heights, entrances or facade details.
- Exact path geometry, ramps, stairs, slopes or accessible routes.
- Ground elevations or collision quality during a human play-through.
- Performance on the target Windows computer.
- Redistribution rights for maps, GIS data, photos or 3D assets.

Estimated geometry must remain labelled as estimated. Automated checks do not replace a field survey.

## Next acceptance work

1. Walk the Green → ERC → SRC → Town Plaza → Green loop in the running project.
2. Record real-world reference viewpoints and compare them with fixed in-engine camera positions.
3. Verify entrances, path widths, ramps, stairs and level changes; update source data with provenance and confidence.
4. Capture Windows hardware details and measure median FPS and 1% low at 1080p.
5. Only then replace P0 proxies with editable Blender assets and GLB exports.
