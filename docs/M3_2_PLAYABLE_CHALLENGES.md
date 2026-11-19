# M3.2 — UTown Field Notes and Campus Sprint

**Status:** optional offline game loops on the existing Godot scene. The activity uses provisional walkway and waypoint data; it is not a real NUS navigation system, site survey or accessibility guide.

## Field Notes
- Eight glowing pickups are placed along existing conceptual walkway segments.
- Walk within **4.5 m** and press **C** to collect one.
- The HUD shows the collected count; the minimap shows uncollected pickups in violet.
- Each pickup reveals an original note about the coordinate frame, procedural environment, provisional building studies, GIS references or visual-review limits.
- Collected pickups disappear and remain collected after restart.

## Campus Sprint
- Stand within **12 m** of Town Green and press **V**.
- Follow **ERC → SRC → Town Plaza → Town Green**. Checkpoints advance automatically.
- Press **V** again to cancel.
- The HUD shows elapsed time, next checkpoint, last result and personal best.
- Medal thresholds are game-design targets: **Gold ≤ 78 s**, **Silver ≤ 100 s**, **Bronze ≤ 135 s**. Slower completed runs still count as a finish.
- The best time persists locally.

## Data and save contract
- The explorer_items.json file stores item IDs, original text and references to existing utown_core.json walkway segment indices plus an interpolation fraction.
- It introduces no new latitude/longitude values and does not claim that a pickup is a real campus object.
- UTownChallenge resolves positions through UTownWorld.lonlat_to_world().
- user://nus3d_explorer.cfg stores only collected item IDs and best Sprint time. No account, analytics, telemetry or network service is used.
- F7 clean photo mode hides Field Note markers.

## Validation
- Godot smoke tests cover eight pickups, proximity collection, duplicate rejection, save/reload, Sprint start radius, ordered completion, medal assignment, best-time persistence and marker hiding.
- The exported-runtime test checks the new JSON and challenge controller in the packaged PCK.
- The Windows workflow asserts eight Field Notes and five Sprint route points.

## Manual acceptance still needed
1. Run the Godot GUI or Windows experimental build and collect all eight notes.
2. Confirm each pickup is visible, reachable and not embedded in a proxy building or tree.
3. Complete a Sprint, cancel a second run, and confirm the personal best survives restart.
4. Check HUD and minimap at 1280×720 and a smaller window; verify F7 hides pickup markers.
5. Treat route positions, checkpoint radii and medal thresholds as game-design values only, never real directions or measured travel times.
