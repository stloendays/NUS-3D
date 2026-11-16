# M3 alpha — atmosphere controls and photo mode (2026-11-16)

**Implemented creative scene enhancement, not site-survey calibration.** The previous fixed afternoon daylight is preserved as the default. The light rig now offers four named, deterministic, offline presets: Daylight, Golden hour, Blue hour, Evening. These are artistic controls and do not calculate actual Singapore sunlight, local time or weather.

Keyboard controls in the running Godot project:
- **T** — cycle lighting among four presets, without touching geometry or camera.
- **F7** — hide/show all HUD, minimap, route labels and crosshair for a clean photo view. F4 continues to save original PNG + JSON source record via the existing review feature.
- **F3** — choose a repeatable evidence-linked camera, **F2** — compare M1/M2 detail, **F6** — add OSM outline overlays.

The script procedurally places at most ten low-impact **illustrative** path lanterns outside the proxy buildings and conceptual walking corridor; no real lamp locations or accessibility routes are asserted. The lamps use a few unshadowed OmniLight3D lights only in Blue hour or Evening. Additional placement exclusion keeps new trees at least six metres from those lamps. They add no collision or external images/audio.

Automated tests assert night lamp visibility/no shadow generation, mode reset, at least two decorative lights, preserved tree/route counts, and the original M1/M2/OSM smoke tests. Linux Xvfb CI produces two extra original-game PNGs (Golden hour and Evening at the synthetic SRC viewpoint) next to the existing reference comparisons. GPU timing, frame-rate and image quality on a Windows machine remain unmeasured; a Windows session still needs review for colour balance and performance.

Provenance: this is original procedural 3D authoring with no NUS logos, weather data, copyrighted photographs or proprietary geometry. Source map/OSM credits continue separately.

## Clean photo mode label visibility

F7 now hides/restores not only the CanvasLayer HUD but also in-world procedural Label3D building and route signage plus the glowing conceptual route spheres. The photo mode does not remove building meshes, path geometry, OSM comparison boundaries or lighting. Linux automatic screenshot capture similarly disables all world labels for reproducible uncluttered review images.
