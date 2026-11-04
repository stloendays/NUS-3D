# M1.6 — Pedestrian clearance audit (2026-11-04)

**Engineering status: implemented. Site calibration: NOT completed.** This stage is a reproducible check of estimated *in-game* walkway geometry, not a claim of an actual pedestrian route, accessible entrance, elevation, measured building footprint or NUS endorsement.

## Defect identified and corrected

The M1 route connecting ERC to the SRC east approach (walkway index 1) previously cut across the SRC estimated east building wing. A pedestrian following the displayed path could encounter the static building collision although the four conceptual route stops themselves were connected.

We added two **schematic east-side offsets** to walkway 1 near longitude 103.773052, with latitude 1.30494 and 1.30458. This moves the conceptual guide east of the current SRC proxy massing. They are *not GPS survey points and should not be used as real navigation directions*. Real ground-level circulation, entrances, ramps, steps and overhead passages may differ.

## Deterministic validation

Run from repository root:

    python tools/validate_utown_data.py
    python tools/audit_route_clearance.py --strict --report build/route-clearance.json
    python -m unittest discover -s tools -t . -v

The audit transforms WGS84 to **the identical provisional local-metre basis used by the Godot scene**: X east, negative Z north. It reconstructs each building part as a rotated 2-D rectangle, including per-part offsets. For each conceptual walkway centreline segment, it calculates the shortest distance to each rectangle using segment intersection, endpoint inclusion and edge distances. A route segment is a conflict when its gap is below **half the walkway width + 0.75 m**. Because walkway parts are guide overlays without navigation meshes, this is an intentionally conservative envelope, not a slope/accessibility test.

- Current checked shape: **11 polyline segments, 9 building groups, zero proxy-envelope conflicts**.
- Previous ERC-to-SRC shortcut: regression fixture requires the old conflict with SRC to be detected.
- JSON report includes nearest building/part, gap, required clearance and conflict per segment.
- CI stores an artifact named **utown-route-clearance-audit** containing the JSON report. This is a machine-checkable engineering result.
- Geometry remains estimated; a result of zero does not validate actual campus widths or obstacles, precise building coordinates, height differences, terrain or wheelchair access.

## Field survey inputs still needed

For each P0 landmark (Town Green, ERC, SRC, Town Plaza), record from your own onsite observations or licensed sources:

| Input | Required evidence | Current disposition |
|---|---|---|
| Pedestrian connection and entrances | Ground-view photo and exact approach/level (with usage rights) | Unknown |
| Walkway path and width | OSM way ID or site waypoint; check against site photo | Schematic only |
| Stairs, ramps and linked floors | Accessibility and grade observations | Unknown |
| Building footprint and rotation | OSM extraction timestamp and feature ID, checked against photos | Massing estimated |
| Elevation | Surveyed datum / measured vertical separation | Flat prototype only |
| Matched eye-level screenshots | Standing coordinate, camera direction and timestamp | Pending GUI review |

Official UTown map: https://map.nus.edu.sg/ (not a scale-accurate survey). OSM data: https://www.openstreetmap.org/copyright (ODbL and attribution requirements). Neither map nor imagery is bundled.

## Next acceptance gate

Before declaring M1/M2 accurate, replace the schematic route and proxy geometry with documented GIS/site observations, rerun the checks, and test the complete walk in Godot GUI and on Windows. Current tests only prove *internal geometry consistency*.
