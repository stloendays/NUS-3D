# Technical design — reusable UTown model pipeline

Date: 2026-10-24 · Proposed specification (not yet implemented)

## 1. Architecture and responsibilities

- **Data**: NUS map for place names and topological relations; OSM for approximate geometry; optional field-measured dimensions.
- **GIS process**: validate footprints and pathways, map geographic coordinates to a local metric coordinate system, attach evidence and precision.
- **Blender**: editable source for terrain, modular buildings, facade parts, vegetation proxies; exporter to **glTF 2.0 binary (.glb)**.
- **Godot 4**: initial runtime, player movement, collisions, lighting, streaming/profiling, Windows export.
- **Three.js (optional)**: later web tour consuming the same GLB assets and landmark inventory; no independent remodeling.
- **No dependency on external private proprietary 3D assets** for the first playable prototype.

## 2. Coordinate reference contract

1. Original geographic data: WGS84 lat/lon (EPSG:4326), with source and timestamp.
2. For local area metric geometry, transform geographic positions to Singapore SVY21 projected coordinates (EPSG:3414) when supported by GIS tools.
3. Set a **verified Town Green anchor**, stored as E0/N0 and an elevation reference H0. **Do not invent coordinates or heights now.**
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
| Runtime scene | Godot `.tscn` | References reusable GLB assets, not duplicated geometry |

**Do not commit** personal account details, unofficial private building plans, unlicensed third-party models, or photos without re-distribution rights.

## 4. Proposed structure (future)

```text
data/
  utown_landmarks.csv
  gis/                 # future cleaned footprint/route geometries + source metadata
assets/
  buildings/           # erc.glb, src.glb, ...
  terrain/
  props/
  vegetation/
  materials/
blender/
  utown_blockout.blend
  buildings/
godot/
  project.godot
  scenes/
    utown_world.tscn
    first_person_controller.tscn
  scripts/
web/
  src/                 # optional Three.js viewer
tools/
  gis/
  validators/
docs/
```

These paths are a proposal; only existing files are represented as implemented.

### Suggested Godot hierarchy

```text
UTownWorld (Node3D)
  Terrain (StaticBody3D)
  RoadsAndStairs (Node3D)
  Buildings (Node3D)
    ERC (Node3D)
    SRC (Node3D)
    SurroundingProxies (Node3D)
  Vegetation (Node3D / MultiMeshInstance3D)
  StaticProps (Node3D)
  Lighting (WorldEnvironment + DirectionalLight3D)
  Player (CharacterBody3D)
  LandmarkLabels (Node3D)
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

## 7. Validation protocol

1. **Top-down**: compare placement of at least ERC/SRC/Plaza/Green with GIS and official orientation diagram.
2. **Eye-level**: three known standing viewpoints with screenshots and reference links.
3. **Walking path**: player completes Green → Plaza → ERC → SRC → Green without collision issues.
4. **Scale**: doors, person height, path widths and facade rhythm plausibly aligned; unknown real dimensions marked estimated.
5. **Performance**: repeatable graphics preset and recorded PC specifications.
6. **Rights**: review redistribution license before public packaging.

## 8. Suggested first implementation

- Export a **single GLB** with ground plane, first rough terrain, four core blockout masses, footpaths and 5–10 placeholder trees.
- Import into Godot 4, add CharacterBody3D player controller and static collision.
- Make two comparison screenshots before investing in any detailed material.
- After the M1 walk-through passes, break apart buildings into independently editable GLBs.
