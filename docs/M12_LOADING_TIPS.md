# M12 — Lightweight real-loading splash and gameplay tips

This feature adds a **real loading screen** before the existing account/login shell. It does not alter account data, the account UI, gameplay controllers, NPC behavior or save schemas.

## Startup sequence

1. Godot starts `res://scenes/boot.tscn`, a single `CanvasLayer` with light flat-color vector UI.
2. The boot loader requests `res://scenes/main.tscn` through `ResourceLoader.load_threaded_request` and polls `load_threaded_get_status` for the *actual* resource-loading fraction. The progress bar covers **0–83%** during this phase.
3. It asynchronously loads `res://scenes/game_shell.tscn` (**83–95%**) while retaining the preloaded world `PackedScene` for Godot's resource cache.
4. It displays **Initializing campus world and characters...** at 95%, then instantiates the original `NUS3DGameShell` and its existing 3D game world. The boot `CanvasLayer` stays above the login UI until `GameShell._ready()` has created `login_cover`, which is **not replaced**.
5. It sets **100% only after the real login and world nodes exist**, renders a frame and hands ownership to `SceneTree.current_scene = GameShell`. The boot nodes are then freed.

This is not a fixed animation or an artificial delay; on a slower computer the loader can stop at 95% while synchronous node/mesh generation finishes. It does not claim to report GPU draw-call or shader-compilation progress. On successful load, the boot scene and any UI-only resources it owns are freed.

The `--nus3d-self-test` launch argument **bypasses the loading UI**, preserving the existing exported Windows executable verification process, which expects the original game shell and export self-test logic.

## Visual design / tips

- Designed to resemble a restrained campus comedy game, not a complex account dashboard: dark forest/sky tones, warm amber progress fill, bold **NUS-3D** wordmark, and minimal panel graphics. No images, shaders, new web requests, or extra sound assets.
- Source file `godot/data/loading_tips.json` contains **11 distinct gameplay tips**, each with a title, a one-sentence explanation and keyboard shortcut.
- Tips rotate every **4.2 seconds**, including while the underlying resource-loader percentage is unchanged.
- Supports **English and Chinese**, following the existing `GameLanguage` preference (not hardcoded to the operating system).
- Included subjects: movement/running, map/controls, faculty/coursework, bicycle/shuttle, interiors, Field Notes/sprints, Fine Food lunch orders/coins, cartoon NPC toys, F8 exam papers, weather/photo mode, and post-course leisure games.
- Layout is centered and resizes with viewport width; there is a visible **Retry** button and error message if the scene cannot be loaded. The screen intentionally requires no 3D graphics.

## Isolation and performance

- This is the only change to `godot/project.godot`: `run/main_scene` points to the new `boot.tscn` rather than `game_shell.tscn`.
- There are no modifications to `godot/scripts/game_shell.gd`, `godot/scenes/game_shell.tscn`, `godot/scenes/main.tscn`, `game_language.gd` or existing tasks.
- The new main scene is **app-only** and does not affect code/tests that load `res://scenes/game_shell.tscn` or `main.tscn` directly.
- The UI updates loading values at no more than ~16.7 Hz; tip labels change every 4.2 s. It allocates no textures or 3D meshes.
- Godot's `ResourceLoader` cache avoids a second heavyweight parse of `main.tscn` when the original shell asks for it. Loading a PackedScene does not create a second instance of the 3D world.
- The old cinematic intro remains separate and starts only through the existing account/game lifecycle. The boot progress bar is distinct from the **12-second cinematic progress**.

## Validation

```bash
godot --headless --path godot --import --quit
godot --headless --path godot --script res://tests/boot_loading_smoke_test.gd
godot --headless --path godot --script res://tests/account_smoke_test.gd
godot --headless --path godot --script res://tests/integration_smoke_test.gd
```

The boot test verifies real threaded world/shell loading, tip content and locale, monotonic percentage, 95% vs 100% distinction, no duplicate login, old tutorial accessibility, the original login pause state and the scene ownership handoff. Existing Godot CI and Windows preview CI should be checked before merging.

**Limitations:** Loading progress reflects Godot's resource-loader status, not OS network/download speed or shader compilation. The final instantiation phase still runs on the main thread and may briefly pause a frame; a later optimization could spread procedural world generation over frames, but that would require changes to multiple gameplay scripts and is deliberately out of scope here.

## Main integration notes (2026-11-19)

This port is layered on the main-based oral-presentation integration branch (#52) so it retains optional microphone settings and the Science district from #48. The old parent branch is not merged. Loading tips were updated to current controls (P/Shift+P for coursework/faculty, Tab for leisure). UI/asset initialization still runs on the Godot main thread, so the bar holds at 95% until the shell reports readiness; this is not a guarantee of fully non-blocking startup.
