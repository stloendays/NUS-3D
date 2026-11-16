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

## Baseline outputs (16 November 2026 source snapshot)

| Planar measure | ERC | SRC |
|---|---:|---:|
| OSM outer-ring area | 5,546.19 m² | 12,605.60 m² |
| Union of estimated game boxes | 1,976.00 m² | 3,392.00 m² |
| Shared plan area | 1,947.93 m² | 3,115.86 m² |
| OSM only (not represented by boxes) | 3,598.26 m² | 9,489.74 m² |
| Model only (outside OSM ring) | 28.07 m² | 276.14 m² |
| 2D intersection-over-union | **34.95%** | **24.19%** |
| OSM area covered by model | **35.1%** | **24.7%** |
| Model area inside OSM | **98.6%** | **91.9%** |
| Separation of planar area centroids | 4.46 m | 7.43 m |

The model's boxes are largely within the source polygons, but large parts of each OSM polygon are absent from the playable massing. **Do not automatically fill the remainder with solid floors or walls**: OSM may include several levels, sheltered concourses, atria and other non-solid ground areas.

## In-game F6 comparison card

When the user enables the existing **F6** source outline, the minimap and a compact right-hand HUD now show ERC/SRC source overlap IoU and OSM coverage from godot/data/osm_fit_baseline.json. F6 off hides the card; F7 clean photo mode hides all HUD. The baseline is generated from the report then frozen for deterministic Godot runtime use, and a Python unit test recomputes the actual source geometry and **fails CI if any displayed number becomes stale**. It is not independent evidence of field accuracy.

The graphical CI artifact utown-m2-1-view-review also includes SRC_GIS_F6_SCORECARD.png: a screenshot with the OSM boundary and the summary card enabled.

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
