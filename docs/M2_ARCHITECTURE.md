# M2 alpha — ERC and SRC architectural study (2026-11-04)

**Stage:** visual study implemented, **not** as-built reconstruction or a completed M2 acceptance milestone. ERC and SRC retain their M1 estimated massing and collision. The new visual detail layers are independent and non-colliding.

## What is based on sources

| Building | Source-backed features | Sources |
|---|---|---|
| ERC (Education Resource Centre) | Curved/faceted double-glazed facade; broad horizontal sunshades; clustered courtyard massing; four-storey building | [Meinhardt Facade Technology](https://www.mfacade.com/projects/education-resource-centre-nus/), [NUS Residential Life](https://blog.nus.edu.sg/reslife/2022/07/19/3-lesser-known-facts-about-utowns-design/), [NUS UCI](https://uci.nus.edu.sg/campus-life/campus-services/utown/education-resource-centre/) |
| SRC (Stephen Riady Centre) | Three-storey mixed-use centre; upper/lower circulation routes; open forum; elevated metallic disc | [DP Architects project](https://www.dpa.com.sg/projects/stephen-riady-centre/), [DP Design](https://www.dpa.com.sg/projects/dpd-stephen-riady-centre/) |

**Important:** Sources establish architectural design motifs, not our numeric model parameters. Existing ERC massing at around 11.5–12.5 m is not confirmed to represent the documented four-storey building correctly. Height, shape, entrances, level separation, facade spacing and disc dimensions still require survey/photo comparison.

## What the Godot prototype now builds

- `godot/scripts/utown_facades.gd` creates a separate `ArchitecturalStudy_NotSurveyed` child beneath both ERC and SRC.
- **ERC:** front/east glazing strips, horizontal sunshades, narrow mullions, a simplified canopy and an illustrative faceted curved glass bay.
- **SRC:** east/south glass bands, stacked balcony edges and an illustrative metallic forum disc supported by slender columns, plus a conceptual elevated link.
- The P1 building proxies remain unchanged.
- **F2** toggles the M2 study layer to compare it with the original M1 greybox.
- All architectural embellishments have **no collision**; original M1 building collision remains the only collision geometry. This prevents details from altering the unverified pedestrian loop.

The design uses original procedural materials and shapes. No third-party photos, textures, logos or meshes are bundled.

## Single-source parameters and provenance

`godot/data/m2_profiles.json` records the two architecture IDs, source URLs, reference-only license treatment, design motifs, and **estimated numerical parameters**. All lengths are in metres; they are not surveyed values.

To validate the data and scene:

```bash
python tools/validate_utown_data.py
python tools/validate_m2_profiles.py
python -m unittest discover -s tools -t . -v
godot --headless --path godot --import --quit
godot --headless --path godot --script res://tests/smoke_test.gd
```

GitHub Actions checks the Python profiles and Godot detail-layer nodes/toggling. Passing CI does **not** prove accuracy or real-device rendering performance.

## Optional Blender source and GLB export

A **reproducible authoring script** is provided at `blender/build_m2_blockouts.py`. It reads the same JSON data, creates independent editable Blender scenes, and exports GLB files. From the repository root with Blender **4.x** installed:

```bash
blender --background --python blender/build_m2_blockouts.py -- --out build/m2_assets
```

Expected generated files (not committed to the repository by default):

```text
build/m2_assets/erc_study.blend
build/m2_assets/erc_study.glb
build/m2_assets/src_study.blend
build/m2_assets/src_study.glb
```

The generator uses Blender X=east, Y=north, Z=up, then glTF Y-up export; imported Godot scene axes are intended to be X=east, -Z=north, Y=up. This coordinate handoff **must be tested visually on a cube/arrow reference before replacing assets**. The generated files contain source-building-local geometry, not a fully georeferenced combined campus scene. Position in Godot with each building's shared geographic transform.

The Blender generator's Python syntax is covered by the Godot CI workflow. A **separate GitHub Actions Blender 4.0.2 workflow successfully executed the script on 2026-11-04** and uploaded a ZIP artifact containing both .blend files and both .glb files. The GLB 2.0 headers and binary length were checked; the downloadable ZIP was independently inspected and contained **50 ERC mesh nodes and 61 SRC mesh nodes**. [Download the temporary GitHub Actions artifact](https://github.com/stloendays/NUS-3D/actions/workflows/blender_m2.yml) (30-day workflow retention). This is asset-generation validation, **not** a visual review or a claim of geographical accuracy. The procedural Godot detail layers remain the playable implementation until the GLB import, axis and scene checks pass.

## Remaining gates before M2 acceptance

1. Visit or obtain licensed, multi-angle visual references for ERC and SRC. Record date, photographer and viewpoint.
2. Replace guessed heights, curve radii, entrance locations, path slopes and forum geometry with evidence-backed data.
3. Check visual profiles at three fixed camera positions in a GUI Godot build.
4. Run Blender to produce .blend and GLB, check coordinate orientation, mesh topology and scale, then explicitly choose and implement the GLB asset swap.
5. Test the Green → ERC → SRC → Plaza → Green walk in a real windowed environment. Verify no collisions, clipping or wrong elevations.
6. Measure frame-time distributions on a Windows PC and confirm redistribution rights before public packaging.

## Evidence-based camera review (M2.1)

A repeatable photo-reference camera workflow and Linux Xvfb software-rendered screenshot artifacts are tracked separately in [M2.1 viewpoint documentation](M2_1_VIEWPOINT_CALIBRATION.md). Camera EXIF and creative-commons photo references do not validate real measured geometry.

## M2.4 OSM footprint shell comparison

The next geometry step is documented in [M2.4 OSM building shells](M2_4_OSM_BUILDING_SHELLS.md). ERC and SRC now have OSM-polygon extrusions in a separate `OSMBuildingShells_Estimated` node. **G** toggles between these visual shells and the original proxy masses. The proxy collision remains active; OSM shells do not collide. Heights are estimated from the OSM four-level tags and the existing estimated storey pitches. SRC's `layer=-1` tag is not converted to a vertical height. This remains a visual comparison, not an as-built or accessible-route acceptance.
