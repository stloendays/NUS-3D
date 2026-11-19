# M3.7 — DDL DOOM: cartoon campus / static sky textures

> **Unofficial offline parody.** This is not a surveyed reconstruction of NUS, a real coursework system, an official map, or a depiction of actual staff/students. All props, jokes, texture SVGs and fictional backdrop buildings are original game assets.

## Experience goal

A deliberately exaggerated, low-stakes five-minute slapstick game: the campus should feel inhabited rather than empty. Background scenes are absurd (coffee vending, lost assignments, paper scraps, "Library 404", panic-club notices) and should make exploration rewarding without affecting accessibility of the existing schematic paths. Preserve student/teacher comedy toys, weather, NPC conversations, interiors, shuttle, bicycle, and local account work.

## Static cloud sky

- Three authored SVGs: `cloud_wisps.svg`, `cloud_cumulus.svg`, `cloud_storm.svg`. Godot imports them as texture resources.
- Existing weather owns three layers of **11 Sprite3D billboards each** (33 reusable static cloud-image instances). The cloud dome stays centered over the player horizontally and **does not rotate or drift**.
- Clear: thin bright clouds; Cloudy: thin + larger clouds; Overcast: larger clouds; Rain: larger + dark thunderclouds; Thunderstorm: dark clouds. Interiors hide cloud sprites. Existing rain, puddles, lightning and lighting still run.
- No downloadable external photo-textures, volumetric cloud simulation, or dynamic image creation.

## Street-level art and performance

- `UTownStreetscape` samples existing approximate walkways and checks clearance using existing building, tree and path data. Bounded at 56 small decor clusters.
- Five sets of original 3D furniture props: benches with comically large coffees; paper notices and poster boards; snack/caffeine machines; tropical planter boxes; bins and lost pens.
- Four comic route banners. Twelve distant *fictional*, non-colliding skyline shapes add horizon context; these are *not* real NUS buildings.
- Four original 64px SVG surface tiles `comic_brick.svg`, `comic_paper.svg`, `comic_poster.svg`, `comic_tile.svg`. Shared `BoxMesh` dimensions and cached materials/textures; scattered paper uses a single capped MultiMesh (156 max).
- Props contain **no collision shapes** so they cannot obstruct the walkways and existing NPC/shuttle routes. No polling of external services, no background threads, no network requests.

## Story: DDL DOOM

Press **H** at an illuminated stage marker (the scene HUD displays the current target).

| Stage | Location (approximate game loop) | Punchline |
| --- | --- | --- |
| 1. THE EMAIL OF DOOM | Town Green | An email arriving at 2 AM claims the coursework was due yesterday |
| 2. THE CURSED PRINTER | ERC | The printer produces 37 pages of “et al.” and says brain cells were not found |
| 3. THE CAFFEINE RITUAL | SRC | Imaginary coffee provides +99 energy and -999 sleep |
| 4. THE SUBMISSION PORTAL | Town Plaza | A huge PDF gets "compressed" by rubber chicken; the player earns Master of Panic |

Starting stage 1 begins a **5-minute in-game countdown**. The clock advances only while the scene is running. If it reaches zero, the objective resets to Town Green without deleting the player's other exploration progress. Interaction is blocked in buildings, on the shuttle, during movement lock, or with hidden HUD. Photo mode (F7) hides quest overlays and markers.

Successful first submission gives **80 arcade XP exactly once**. Replays are welcome but cannot farm the completion reward; story progress, retries and best time live in an independent `user://nus3d_ddl_story.cfg` file. Existing save formats are unchanged.

## Verification

The CI workflow headlessly imports SVG textures and executes `res://tests/m3_7_smoke_test.gd`, in addition to all pre-existing Godot tests. This tests 33 fixed cloud sprites, sky mode switches, indoor hide, 4 texture resources and cached/bounded scene decorations, absence of path-blocking collisions, all four story acts, timers, replay/save, first-completion XP guard and F7 photo mode.

For manual QA in the Godot 4.4+ editor, select `godot/project.godot`, run main scene, press **Y** to cycle weather, **H** near the DDL mission marker, and inspect each location at day/night. Performance/fog and sprite overlap must still be visually reviewed on a real GPU.

## Integration discipline

M3.7 was branched from `feature/m3-5-campus-slapstick-20261119` instead of modifying active M3.6, M5 or M6 branches. The only modifications to existing game code are the weather cloud-image subscene, two new root children in `main.tscn`, a help shortcut, and a CI test step. Other modules stay isolated.
