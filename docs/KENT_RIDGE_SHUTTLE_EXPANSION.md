# M4.3 — Kent Ridge campus & playable shuttle expansion

## What is new

The UTown 3D level remains the starting location. A separate low-poly extension places ten additional fictionalised, georeferenced campus areas outside UTown: NUS Museum & UCC; Engineering; Yusof Ishak House; Central Library & FASS; School of Computing (COM3); Business School (BIZ2); University Health Centre; Science S16; Kent Ridge MRT/NUH; and Prince George's Park.

- The **original UTown props, coursework, NPCs, coins, missions, F2/OSM tools, indoor rooms, bicycle and moving UTown shuttle stay unchanged**.
- The map has one much larger walkable base, campus-style promenades, district-scale procedural buildings, 11 bus shelters, an illustrative connecting-road network, and two moving low-poly campus buses.
- The original minimap tracks the player outside UTown, showing nearby districts, roads and stops. In UTown it retains its original north-up coverage.
- A new interactive bus route atlas shows all game stations and D1/D2 game lines. No new keyboard shortcut is registered.
- All campus geometry, bus journeys, stops, labels and jokes are fictional illustrative content, **not** a surveyed NUS building model, official campus navigation, official shuttle stop list, route direction, or live timetable.

## How to play

1. Walk from **Town Green toward Town Plaza**. Look for the new campus-bus direction sign and bus shelter.
2. Stand within about 17 metres of the **UTown / Town Plaza (game stop)**.
3. Press **Esc** to free the mouse pointer, then click **View bus routes** on the station card at the right.
4. Choose **D1** or **D2**, browse destinations on the campus atlas and click a destination.
5. A stylised short bus-ride transition moves the player to the chosen district, where normal walking, camera and existing quests continue.
6. To switch from one line to the other, visit a shared game stop such as UTown, Museum/UCC or COM3.

**Travel and user controls:** This is an express ride/travel transition rather than a physically simulated bus journey. The two moving buses on the road are visual atmosphere. No existing key mapping is changed. An opened bus menu temporarily pauses the game world. Closing it restores game, mouse and player control.

## Source provenance

- [NUS official campus map](https://map.nus.edu.sg/)
- [NUS official downloadable campus maps](https://map.nus.edu.sg/index.php/main/download_map)
- [NUS UCI internal shuttle buses (network effective 5 January 2026)](https://uci.nus.edu.sg/campus-life/campus-services/transportation/internal-shuttle-bus/)
- [2025 official UTown directions example](https://www.nus.edu.sg/celc/wp-content/uploads/2025/05/Directions-to-University-Town-UTown.pdf)

These references establish the campuses, named landmarks and existence of D1/D2, but **not** all coordinates in this prototype. The JSON coordinate anchors, inter-district links, simplified bus stop ordering and graphical building masses are intentionally approximate. For real trips use NUS UCI's route map and uNivUS real-time information.

Implementation sources:
- `godot/data/kent_ridge_expansion.json` — hand-checked approximate district and bus-stop anchors, station topology and source URLs
- `godot/scripts/kent_ridge_world.gd` — low-poly extension, ground, plazas, promenade, signages and cosmetic buses
- `godot/scripts/kent_ridge_bus.gd` — mouse-only station interactions, illustrated atlas and travel transition
- `godot/scripts/minimap.gd` — player-centered off-UTown minimap
- `godot/tests/kent_ridge_expansion_smoke_test.gd` — covers geometry, route availability, boarding, arrival, photo mode and controls

Run: `godot --headless --path godot --script res://tests/kent_ridge_expansion_smoke_test.gd`

## Limits / performance

- This is the first exploration pass, not a photogrammetry or GIS-grade campus replica.
- New areas use shared procedural meshes/materials and simple collisions. There is no imported large photo texture/photogrammetry dataset, online routing, student data, transport telemetry or new account save schema.
- The four original UTown checkpoints and indoor content remain local to UTown. Additional area-specific challenges can be layered later, without modifying the existing quest system.
