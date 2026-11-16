# M3.1 — UTown Explorer (offline discovery activity)

**Status:** implemented, schematic and unofficial. This is an original four-stop exploration game inside the existing Godot procedural model. **Not real NUS navigation, measured geometry, accessible-route advice, or an official university guide.**

## Play

- **WASD** to walk, **Shift** to sprint, mouse to look and **M** to toggle the schematic minimap.
- Begin near **Town Green**. At a highlighted checkpoint, stand within **12 m** in the *game's horizontal plane* and press **E**. The action is deliberately manual: passing close to a stop does not automatically count.
- Each interaction unlocks a short original observation about that landmark and the model's own uncertainty. The persistent progress counter in the HUD advances from **0/4** to **4/4**, and the minimap turns visited stops teal. The active stop has a yellow outline; unvisited future stops appear muted.
- Discover **Town Green → Education Resource Centre → Stephen Riady Centre → Town Plaza** in sequence to finish the **UTown Explorer** challenge. Press **G** after completion to replay. Progress intentionally resets when the application closes; no account, telemetry or save file is created.
- **F2** toggles estimated ERC/SRC architectural layers; **F6** overlays attributed OSM source geometry for comparison; **T** switches artistic lighting, **F7** hides the HUD/world signs for photography, **F4** captures an original PNG with metadata.

The minimap represents *the scene's own provisional local coordinates*, not approved pedestrian routing. The path surfaces are currently flat proxy geometry; no real-world step-free access is implied. This mission is observational storytelling, not turn-by-turn navigation.

## Data contract

- `godot/data/discovery_tour.json` contains only original story text, check-in radius and **checkpoint IDs**.
- `godot/data/utown_core.json > loop` remains the **sole source of waypoint coordinates**. `UTownTour` resolves each stop ID into the existing local projection at scene start; it does **not** duplicate geographic coordinates.
- `tools/validate_discovery_tour.py` confirms the exact four-ID order, uniqueness, absence of duplicated lat/lon in tour data, reasonable proximity radius and explicit no-survey/non-affiliation/no-navigation notices.
- `tools/test_validate_discovery_tour.py` covers invalid stop order/IDs/coordinates, missing disclaimers and unsafe radius.
- `godot/tests/smoke_test.gd` verifies the initial nearby prompt, out-of-range rejection, ordered four-stop progression, no duplicate check-in, reward state and restart.
- The Windows-export self-test requires the tour JSON in the packaged PCK and the instantiated four-stop controller, and its CI checks the exported Windows executable.

## Creative content and licensing

Descriptions are original to this project and talk about *what the current model approximates*, rather than inventing campus history or promises of real facilities. Existing OpenStreetMap contributors/ODbL credits remain separately disclosed for the GIS comparison layer. No copyrighted photographs, logos, recordings, maps or paid model assets are shipped in this feature.

## Manual acceptance still needed

1. Open the real Godot GUI or packaged Windows executable. From spawn, verify Town Green offers **E**, and a distant **E** does nothing.
2. Walk the conceptual route, inspect directional meaning and whether any *proxy building* blocks the way; confirm the four discovery cards fit at **1280×720**.
3. Check minimap visibility with **M**, F7 clean photo mode, F3 camera review, F2/F6 visual overlays and all four T lighting states.
4. Test at different window sizes and keyboard layouts, then attach original in-game screenshots and measured frame time.
5. Do **not** publish this as a genuine NUS campus map until site elevations, entrances, paths and permissions are independently reviewed.
