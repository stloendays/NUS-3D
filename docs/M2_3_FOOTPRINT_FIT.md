# M2.3 — exact projected P0 polygon-delta scorecard (2026-11-16)

**Implemented:** deterministic comparison of the current 3D game's estimated ERC/SRC flat footprint parts against independently sourced OSM *outer-ring* building boundaries. **Not:** a terrain model, correct building envelope, field survey, photogrammetry, handicap accessibility map, or proof the game is geographically accurate.

## Why this stage

M1.6 originally checked the walking loop against its **own estimated 3D collision boxes**, so finding zero conflicts could conceal missing building geometry. M2.2 introduced the named source OSM outlines, and its route-vs-OSM audit correctly found additional plan-view intersections. Those are **not automatically physical walls**, particularly near SRC's upper/lower circulation.

M2.3 adds a quantified answer to the narrower question: *how different are these two plan-view shapes?* It leaves all current massing, vegetation, collision, conceptual paths, and viewpoint sources unchanged. We do **not** automatically replace the proxy geometry with OSM footprints.

## Sources and projection

- Frozen OSM metadata, rings, way versions, snapshot date and ODbL credit are in [osm_p0_reference.json](../godot/data/osm_p0_reference.json).
- ERC [way/124549217](https://www.openstreetmap.org/way/124549217), SRC [way/125774787](https://www.openstreetmap.org/way/125774787).
- © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), Open Database Licence (ODbL 1.0).
- Godot estimated proxy geometry: [utown_core.json](../godot/data/utown_core.json). The game's reference coordinates and local metre approximation are preserved exactly.
- OSM geometry may describe roof envelope, covered space, open atria, arcade footprint and multiple floors. No elevation or hole/multipolygon geometry is derived here.

## Computation (no Shapely / proprietary map API)

The standard-library implementation is [audit_osm_proxy_fit.py](../tools/audit_osm_proxy_fit.py), independently tested under tools/test_audit_osm_proxy_fit.py.

1. Project both datasets to the same local X=east, Z=south metre frame that Godot uses.
2. Ear-triangulate each concave OSM outer ring; reject invalid/untriangulable rings or loss of area.
3. Intersect its triangles with each rotated estimated proxy rectangle using convex half-plane clipping.
4. Use inclusion-exclusion to calculate the **union** of model parts and the corresponding source overlap exactly in the planar coordinate system; overlapping model parts are **not double counted**.
5. Report OSM and model plan-view areas, common area, OSM-only area, model-only area, IoU, percent of OSM area inside the model, percent of model area inside OSM, and centroid separation.

The area comparison is mathematically exact (up to floating point) for the **two input 2D outer boundaries in the chosen approximate map projection**. It does not quantify physical model error or positioning accuracy. Source polygons are only as accurate and complete as OSM contributors made them.

## Reproduce the result

From repository root:

    python tools/validate_utown_data.py
    python tools/validate_osm_reference.py
    python tools/audit_osm_proxy_fit.py --out build/osm-proxy-fit.json
    python tools/render_osm_proxy_fit.py --out build/utown-p0-fit-scorecard.svg
    python -m unittest discover -s tools -t . -v

The Godot GitHub Actions run generates the machine-readable comparison JSON and original source-attributed ERC/SRC vector scorecard SVG in artifact **utown-route-clearance-audit**. This runs alongside the old M1.6 and M2.2 route checks; **it never modifies the world or makes the new OSM boundaries collidable**.

## Next real-world acceptance gates

- Verify whether each OSM ring describes the ground footprint, roof projection, courtyard boundaries, or several connected buildings.
- Check the ERC entrance, Town Green terrace/café vertical offsets and curved glazing via licensed field photographs and onsite eye level.
- Record real SRC forum, low/high walkways, entrance transitions, stairs, ramps and accessible path heights.
- After manual sign-off, update game massing incrementally and run both conceptual-route checks again; use PNG/GLB comparisons and Windows GUI walkthroughs to catch new collisions.
- Include actual surveyed evidence and measurement uncertainty before presenting any 3D asset as an as-built NUS model.
