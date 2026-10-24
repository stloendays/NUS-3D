# UTown M1 — playable greybox (first implementation)

**Status:** initial Godot 4 source has been added. CI smoke checks the scene graph and generated geometry. No tested Windows binary or photo-verified facades have been delivered. The project is *not* an accurate navigational map.

## Open and run (Windows)

1. Install Godot **4.4.1 or newer** from https://godotengine.org/download/windows/.
2. Clone this repo or use GitHub **Code → Download ZIP** and extract it.
3. Open **Godot Project Manager → Import**, choose `NUS-3D/godot/project.godot`, then select the project.
4. Press **F6** from the main scene, or **F5** to run the project. A conceptual UTown site should appear, with Green, ERC, SRC and CREATE-side Plaza marked.
5. Start at Town Green. The HUD displays the next route target and a north-up schematic. Follow the gold beacons and labelled approximate footpaths.

## Controls

| Key | Action |
| --- | --- |
| W/A/S/D or arrows | Walk |
| Mouse | Look around |
| Shift | Sprint |
| Space | Jump |
| R | Reset to Town Green |
| Esc | Release mouse |
| Left click | Recapture mouse |
| M | Toggle north-up mini map |
| F1 | Toggle help |

## What is implemented

- Runtime generated flat ground (a **placeholder**, not an elevation model), an irregular green zone, and a plaza proxy.
- Approximately positioned **ERC** and **Stephen Riady Centre** compound volumes, plus **CREATE Tower, Tembusu, UTown Residences, CAPT, Cinnamon College and RC4** as simple neighboring landmarks.
- Free first-person camera with gravity, capsule collision, jump, sprint, and a reset if the avatar falls out of the site.
- Conceptual (not surveyed) paved loop, glowing markers and labels, ambient daylight, reproducible low-poly trees.
- Basic HUD: nearest building, distance to next stop, FPS, elapsed loop count, schematic mini map.
- **All graphics are original procedural placeholders**, not copied NUS photos or proprietary models. No external assets to install.

## Source precision and important limitations

`godot/data/utown_core.json` stores source-aware approximate WGS84 landmark centres; they are projected locally using a simple tangent-plane approximation to metres (X=east, -Z=north, Y=up). The anchor is chosen for the prototype, **not measured**.

- ERC/SRC/CREATE and residence positions were cross-checked against the building entries in [City-Syntax NUS Digital Twin](https://github.com/City-Syntax/nus-digital-twin/blob/main/src/content/buildings/buildings.json) and the [NUS 2025 University Town map](https://map.nus.edu.sg/download/University-Town-Map.pdf).
- Town Green's intentionally simplified outline references OSM-derived GIS data in the [City-Syntax public green-spaces layer](https://github.com/City-Syntax/nus-digital-twin/blob/main/public/shapefiles/green-spaces/natural.json). OSM contributors are acknowledged under [ODbL](https://www.openstreetmap.org/copyright). The upstream repository does not supply an explicit license for its own additional GIS modifications; review redistribution requirements before commercial release or bulk importing additional layers.
- **Dimensions, facade patterns, terrain, routing, rooflines and tree positions are all estimated or procedural**. Building centre points are not entry coordinates. Some walkways may overlap preliminary boxes and must be surveyed and reworked.
- In particular, the publicly listed SRC OSM polygon spans a broad complex; it is **not** safe to extrude its bounding rectangle as one building. The initial prototype uses manually shaped separate wings.
- Town Plaza is associated with CREATE Tower's lower levels; this is represented only by a surface proxy, not a valid interior.
- No NUS branding, official signage, satellite imagery, source 3D meshes or photography is embedded.

## What to validate on site before M1 acceptance

1. Confirm the ERC / SRC / Plaza entrances and the exact public walking loop.
2. Measure ground elevations (especially ramps, stair runs and raised linkways); flat terrain is currently inaccurate.
3. Check building footprints and heights, especially ERC and SRC complex roofs.
4. Run on the target Windows PC and measure 1080p FPS; the pipeline currently reports only runtime FPS, not benchmark claims.
5. Replace proxy buildings with editable Blender meshes exported as GLB, retaining the same geographical IDs.
6. Confirm use permissions and map attributions before any redistribution or game release.

**Do not mark M1 complete until route accessibility, geometry scale and performance have been verified in a real rendered session.**

## Developer checks

- Install Godot 4.4+ then run `godot --headless --path godot --import --quit`.
- Run `godot --headless --path godot --script res://tests/smoke_test.gd`.
- GitHub Actions is configured to run these checks on each main/feature branch update.

Next task: install on a Windows laptop, capture two eye-level screenshots, and revise building models against officially permitted reference views.
