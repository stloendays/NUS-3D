# Technical design — reusable UTown model pipeline

Date: 2026-11-04 · Godot M2 alpha and Blender 4.0.2 CI-generated .blend/GLB assets implemented; field survey, GLB-in-Godot visual review and Windows checks remain pending.

## 1. Architecture and responsibilities

- **Data**: NUS map for place names and topological relations; OSM for approximate geometry; optional field-measured dimensions.
- **GIS process**: validate footprints and pathways, map geographic coordinates to a local metric coordinate system, attach evidence and precision.
- **Blender**: editable source for terrain, modular buildings, facade parts, vegetation proxies; exporter to **glTF 2.0 binary (.glb)**.
- **Godot 4**: initial runtime, player movement, collisions, lighting, streaming/profiling, Windows export.
- **Three.js (optional)**: later web tour consuming the same GLB assets and landmark inventory; no independent remodeling.
- **No dependency on external private proprietary 3D assets** for the first playable prototype.

## 2. Coordinate reference contract

1. Original geographic data: WGS84 lat/lon (EPSG:4326), with source and timestamp.
2. **Current M1 prototype** uses a documented local equirectangular approximation, with origin `(lon 103.77316, lat 1.305075)` near Town Green. It is not survey-grade, and elevations remain entirely provisional.
3. **Future validated model** should convert WGS84 to Singapore SVY21 (EPSG:3414), establish a verified anchor E0/N0 and measure an elevation datum H0. Replace the approximation only after reprojecting all related assets together.
4. 3D world axes (metres): `X = Easting - E0`, `Z = -(Northing - N0)`, `Y = Height - H0`. Thus positive X points east, negative Z points north, positive Y points upward.
5. Blender uses a Z-up authoring viewport, but export to glTF/Godot Y-up. Compare an exported test cube/arrow before producing real building assets.
6. All footprints and building IDs use this single shared origin; never center each file arbitrarily when producing site-level placement data.

Record a confidence per measurement: `verified`, `derived_from_OSM`, `estimated_from_reference`, or `unknown`. Elevation/steps require independent verification; assume no "flat UTown" guarantee.

## 3. Data and asset formats

| Type | Format | Notes |
|---|---|---|
| Landmarks | CSV or GeoJSON | Stable `id`, coordinates/source/status and bilingual names |
| Building footprint / roads | GeoJSON | Geometry with original CRS metadata and extraction date |
| Exported mesh | GLB | Metres, applied transforms, named meshes, PBR materials |
| Blender source | BLEND | Non-destructive editable masters |
| Texture | PNG/JPEG/WebP (as appropriate) | Prefer legal, self-made and tiling materials |
| Preview | PNG | Screenshot with a clear stage/viewpoint ID |
| Runtime scene | Godot `.tscn` | **M1** procedurally creates proxy geometry from `godot/data/utown_core.json`; future stages will reference GLB assets |

**Do not commit** personal account details, unofficial private building plans, unlicensed third-party models, or photos without re-distribution rights.

### Automated source-data checks

`tools/validate_utown_data.py` uses only the Python standard library. It validates WGS84 coordinate ranges, unique landmark IDs, Town Green polygon area and self-intersection, positive massing dimensions, rotated building bounds inside the ground plane (5 m safety margin), route-stop/walkway endpoint alignment (2 m tolerance), and public attribution fields. Warnings remain for unmeasured or approximate geometry. The validator is a consistency gate, not a survey-accuracy or licensing certificate.

## 4. Repository structure (current and planned)

```text
README.md
data/utown_landmarks.csv
godot/
  project.godot
  data/utown_core.json          # v0 approximate data, P0 and P1
  scenes/main.tscn              # player + HUD + world scene
  scripts/utown_world.gd        # procedural world
  scripts/utown_facades.gd      # M2 non-colliding ERC/SRC visual detail
  data/m2_profiles.json        # M2 estimated parameters and architectural sources
  scripts/player_controller.gd  # first-person controller
  scripts/hud.gd
  scripts/minimap.gd
  tests/smoke_test.gd
.github/workflows/godot.yml      # Godot 4.4.1 headless test
docs/M1_GREYBOX.md               # launch and limitations
assets/                           # planned editable or licensed GLBs
blender/                          # planned Blender master scenes
web/                              # future Three.js viewer
blender/build_m2_blockouts.py      # M2 architectural-study Blender/GLB generator\nblender/build_m2_4_osm_shells.py    # M2.4 OSM footprint shell Blender/GLB generator
.github/workflows/blender_m2.yml   # actual Blender 4.0.2 export and downloadable GLB artifacts
tools/validate_m2_profiles.py       # M2 profile/provenance validator
tools/validate_utown_data.py       # implemented source-data validator
  tools/test_validate_utown_data.py # Python regression tests
```

Only the paths with actual files above are implemented. Asset, Blender, web and tooling directories are future plans.

### Current Godot scene hierarchy

```text
UTown (Node3D)
  World (UTownWorld script)
    Terrain (box mesh + static collision)
    TownGreen_approximate (triangulated mesh)
    TownPlaza_approximate (plaza slab/canopy)
    ConceptualFootpaths_NotSurveyed (wide overlay strips)
    BuildingMassing_Estimated (9 named building groups)
    OSMBuildingShells_Estimated (non-colliding OSM ERC/SRC footprint extrusions; G toggle)\n    Vegetation_Procedural (64 trees in 2 MultiMeshInstance3D batches)
    RouteBeacons_Conceptual (4 markers)
    WorldEnvironment / DirectionalLight3D
  Player (CharacterBody3D + capsule + Head/Camera3D)
  HUD (CanvasLayer / status / minimap)
```

Player should have a capsule collider, slope support and a simple unstuck/reset function. Keep collision meshes distinct from high-detail rendering geometry.

## 5. Modeling rules

- Use one modular asset for repeated windows, columns, benches, lamp posts and curb units.
- Favor accurate **silhouette + road network + entrances** over hidden facades and detailed interiors.
- Buildings should support 3 levels: blockout, gameplay-resolution, optional hero asset.
- Name nodes `UT_<ID>_<type>_LOD<n>`, e.g. `UT_ERC_Facade_LOD0`.
- Place each building by a geographic transform, not by eyeballing offsets in a runtime scene.
- Tag legal provenance for each image/mesh/texture before putting it in `assets/`.

## 6. Performance targets (engineering objectives, not measured claims)

- Target a smooth 1080p walk-through on an ordinary Windows PC; measure on the actual target device.
- Aim initially for **60 FPS** at a reasonable preset; include a 30 FPS fallback on constrained hardware.
- Batch/instance trees and repeated facade details, avoid one draw call per leaf or window.
- Use LOD for vegetation and far buildings; cull occluded/offscreen geometry.
- Bake or simplify lighting for large static meshes; keep expensive shadow casters controlled.
- Tile large ground textures instead of shipping huge unique 8K aerial textures.
- Split larger eventual campus into spatial chunks (initial design range: 64–128 m, tune after profiling).
- Log build version, hardware, camera path, median/low-percentile FPS and load times in test reports.

### Route clearance (M1.6; provisional 2-D engineering gate)

The Python tool at tools/audit_route_clearance.py reconstructs rotated massing parts from the same WGS84-to-local-metre approximation as Godot, then checks each conceptual walkway segment against the nearest building part. It reports measured *proxy gap*, required half-width + 0.75 m margin and conflicts. A JSON audit is published by GitHub Actions. One ERC-to-SRC route portion has been offset schematically to avoid the original SRC proxy collision. This is **not** a real-world map update or a validation of levels/ramps/stairs; see docs/M1_6_ROUTE_CLEARANCE.md.

## 7. Validation protocol

0. **Machine data check**: run `python tools/validate_utown_data.py` and `python -m unittest discover -s tools -t . -v`.
1. **M2 source check**: validate `m2_profiles.json` and review [M2 architectural-study limitations](M2_ARCHITECTURE.md).
2. **Top-down**: compare placement of at least ERC/SRC/Plaza/Green with GIS and official orientation diagram.
2. **Eye-level**: three known standing viewpoints with screenshots and reference links.
3. **Walking path**: player completes Green → ERC → SRC → Plaza → Green without collision issues.
4. **Scale**: doors, person height, path widths and facade rhythm plausibly aligned; unknown real dimensions marked estimated.
5. **Performance**: repeatable graphics preset and recorded PC specifications.
6. **Rights**: review redistribution license before public packaging.

## 8. Initial implementation and next pass

- **Implemented**: source-driven Godot scene with approximate flat ground, nine compound/proxy buildings, Town Green and Plaza, pedestrian hints, 64 generated trees rendered in two MultiMesh batches, and capsule collision. CI instantiates and tests the scene. M1.5 adds Python data validation, regression tests and footprint/path-aware tree placement.
- **M2.4 implemented**: OSM-derived ERC/SRC footprint shells are switchable against the original proxy visuals; proxy collision remains active and the new shells are non-colliding. Height estimates are sourced from OSM level tags × estimated storey pitch, not measured elevations.\n- **Next**: inspect the M2.4 shell renders, verify footprint and entrances against permitted current evidence, establish a vertical datum, and only then plan polygon collision replacement.
- **After M1 walk-through acceptance**: build editable Blender GLBs with shared placement coordinates and replace individual proxy masses, preserving stable IDs.
