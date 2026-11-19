# M3.7 — DDL DOOM: cartoon campus / static sky textures

> **Unofficial offline parody.** This is not a surveyed reconstruction of NUS, a real coursework system, an official map, or a depiction of actual staff/students. All props, jokes, texture SVGs and fictional backdrop buildings are original game assets.

## Experience goal

A deliberately exaggerated, low-stakes five-minute slapstick game: the campus should feel inhabited rather than empty. Background scenes are absurd (coffee vending, lost assignments, paper scraps, "Library 404", panic-club notices) and should make exploration rewarding without affecting accessibility of the existing schematic paths. Preserve student/teacher comedy toys, weather, NPC conversations, interiors, shuttle, bicycle, and local account work.

## Static cloud sky

- Three authored SVGs: `cloud_wisps.svg`, `cloud_cumulus.svg`, `cloud_storm.svg`. Godot imports them as texture resources. Later art polish enlarged the fixed sprites, varied the static silhouette dimensions, and introduced time-of-day tinting so unshaded cloud artwork is not bright white at night.
- Existing weather owns three layers of **11 Sprite3D billboards each** (33 reusable static cloud-image instances). The cloud dome stays centered over the player horizontally and **does not rotate or drift**.
- Clear: thin bright clouds; Cloudy: thin + larger clouds; Overcast: larger clouds; Rain: larger + dark thunderclouds; Thunderstorm: dark clouds. Interiors hide cloud sprites. Existing rain, puddles, lightning and lighting still run.
- No downloadable external photo-textures, volumetric cloud simulation, or dynamic image creation.

## Street-level art and performance

- `UTownStreetscape` samples existing approximate walkways and checks clearance using existing building, tree and path data. Bounded at 56 small decor clusters.
- Five sets of original 3D furniture props: benches with comically large coffees; paper notices and poster boards; snack/caffeine machines; tropical planter boxes; bins and lost pens.
- Four comic route banners. Twelve distant *fictional*, non-colliding skyline shapes add horizon context; these are *not* real NUS buildings.
- Four original 64px SVG prop tiles `comic_brick.svg`, `comic_paper.svg`, `comic_poster.svg`, `comic_tile.svg`. Two additional authored SVGs `comic_lawn.svg` and `comic_pavers.svg` now tile the large terrain, Town Green, walkways and plaza (world-space UVs on box geometry, explicit UVs on triangulated Town Green). All materials remain weather-responsive. Repeated prop meshes/materials are cached; scattered paper uses one MultiMesh (156 max).
- Added one bounded MultiMesh for roadside shrubs (200 max) and one for colorful flowers (72 max), filtered against existing building/path/tree clearances. Props contain **no collision shapes**, so they cannot obstruct paths and existing NPC/shuttle routes. No external network requests, background threads or runtime scene spawning.

## Story: DDL DOOM

Press **H** at an illuminated stage marker (the scene HUD displays the current target). The timer now has a prominent separate headline, larger quest text, distance-to-objective readout, a final-minute red/orange warning and subtly pulsing markers. Each stage has its own non-colliding giant comic prop (email, printer, coffee, upload portal).

| Stage | Location (approximate game loop) | Punchline |
| --- | --- | --- |
| 1. THE EMAIL OF DOOM | Town Green | An email arriving at 2 AM claims the coursework was due yesterday |
| 2. THE CURSED PRINTER | ERC | The printer produces 37 pages of “et al.” and says brain cells were not found |
| 3. THE CAFFEINE RITUAL | SRC | Imaginary coffee provides +99 energy and -999 sleep |
| 4. THE SUBMISSION PORTAL | Town Plaza | A huge PDF gets "compressed" by rubber chicken; the player earns Master of Panic |

Starting stage 1 begins a **5-minute in-game countdown**. The clock advances only while the scene is running. If it reaches zero, the objective resets to Town Green without deleting the player's other exploration progress. Interaction is blocked in buildings, on the shuttle, during movement lock, or with hidden HUD. Photo mode (F7) hides quest overlays and markers.

Successful first submission gives **80 arcade XP exactly once**. Replays are welcome but cannot farm the completion reward; story progress, retries and best time live in an independent `user://nus3d_ddl_story.cfg` file. Existing save formats are unchanged.

## Verification

The CI workflow headlessly imports SVG textures and executes `res://tests/m3_7_smoke_test.gd`, in addition to all pre-existing Godot tests. This tests 33 fixed cloud sprites and readable scale, sky mode switches, indoor hide, all 6 authored textures including tiling checks, bounded scattered paper/shrub/flower MultiMeshes, absence of scenery collisions, all four story acts, timers, replay/save, first-completion XP guard and F7 photo mode.

For visual QA, `godot/tests/render_viewpoints.gd` now adds **eleven M3.7 real-engine screenshots** to the existing review artifact: clear/overcast/thunder sky, street furniture, street density, tiled grass/shrubbery, the DDL quest HUD and four distinct giant checkpoint prop close-ups, with manifest counts. In Godot 4.4+, open `godot/project.godot`, use **Y** for weather and **H** near the DDL marker. Actual GPU frame pacing and crowd/cloud occlusion still require manual checks; automated Linux rendering is not a substitute for Windows GPU performance.

## Integration discipline

M3.7 was branched from `feature/m3-5-campus-slapstick-20261119` instead of modifying active M3.6, M5 or M6 branches. Changes to existing files are confined to the weather cloud-image subscene, two new children and title/help copy in `main.tscn`, comedy labeling in the existing HUD and `project.godot`, and a CI test step. Gameplay systems and existing save schemas stay isolated.


## M3.8 guidance redesign

Persistent roof labels, waypoint spheres, roadside joke banners and hovering collectible text have been removed. The remaining logical waypoint coordinates are used by the existing map, tour and shuttle. A short P-key UI compass ping and a near-object H interaction prompt replace permanent route signage for DDL. The four oversized fictional task props remain in the world as objects, not directional signboards. F1 reveals the full control list on demand; F7 hides HUD-only navigation without removing scenery. A compass ping gives direct bearing, not a collision-aware or real NUS navigation route.
