# M3.3 — Weather, campus life, interiors and transport

**Status:** playable systems prototype in Godot. All effects and dialogue are original and offline. Geometry and routes reuse provisional project data and are not verified real-world campus infrastructure.

## Weather
Press **Y** to cycle five local presets:
1. Clear
2. Cloudy
3. Overcast
4. Rain
5. Thunderstorm

Cloud meshes, GPU rain particles plus a deterministic rain-streak MultiMesh, puddles and animated ripple rings, fog, reduced sunlight and occasional lightning are procedural effects. Time-of-day remains controlled separately with **T**. Weather is not connected to a forecast API and does not represent current Singapore weather. Rain and clouds are hidden while inside the illustrative room pockets.

## Pedestrian NPCs
Six fictional low-poly student characters walk back and forth along polylines taken from the existing utown_core.json walkways data. Arm/leg pivots animate during walking; NPCs pause at path ends and face the player during dialogue. They have no collision bodies and do not block the player. Press **Q** within approximately 5.5 m to display an original dialogue line. Names and dialogue are fictional game content, not representations of actual NUS students.

## Interior exploration
Press **I** near the conceptual ERC or SRC approach to enter a separate interior pocket:
- **ERC:** original study-lounge concept with tables, seats, shelves and a notice board.
- **SRC:** original recreation-atrium concept with benches, court markings and a display panel.

A visible mezzanine, guardrails, stair study and lift interaction add a second level. Press **L** to switch between the ground floor and mezzanine. Press **I** again to return to the exact saved outdoor position and view orientation. The rooms are isolated at separate game-space coordinates and entered by teleport; they are not connected to the exterior building meshes, measured floor plans or real accessible entrances.

## Bicycle and shuttle
- **B** toggles bicycle mode. The controller increases movement speed and eases to a third-person follow camera; wheel rotation, pedal crank and handlebar steering animate.
- A procedural shuttle loops between the existing GREEN, ERC, SRC and PLAZA waypoint positions, with visible seats, passenger silhouettes, rotating wheels, named stop signs and a longer stop dwell. Approach within approximately 7 m and press **X** to board; press **X** again to alight. The shuttle is a moving game object without passenger capacity simulation, timetable, collision or real-service claims.
- The minimap adds small pedestrian dots and a shuttle marker. The schematic minimap must not be used for actual campus navigation.

## Controls summary

| Key | Action |
|---|---|
| Y | Cycle weather |
| Q | Talk to nearby fictional NPC |
| I | Enter/exit ERC or SRC interior concept |
| L | Switch between interior ground floor and mezzanine |
| B | Toggle bicycle |
| X | Board/alight shuttle |
| T | Change artistic time-of-day |
| F7 | Hide HUD and navigation/collectible markers |

Existing E/G discovery, C Field Notes and V Campus Sprint controls remain unchanged.

## Validation and limitations
- The Godot smoke test checks weather modes and rain activation, NPC creation/dialogue, both room pockets and return teleport, bicycle mode, shuttle boarding/alighting, plus all previous exploration/challenge checks.
- The exported Windows runtime check records weather mode count, rain-streak/puddle counts, NPC count, interior count and bicycle/shuttle visual components. The CI artifact `nus3d-visual-review-and-m3-showcase` includes original software-rendered screenshots for rain, thunderstorm, NPCs, ERC/SRC interiors, bicycle and shuttle.
- CI/headless tests do not verify visual quality, rain readability, camera comfort, interior collision feel, bus motion smoothness or 1080p performance. Those require a manual GUI playtest.
- All route and waypoint positions remain schematic. No live weather, GPS, real bus timetable, network service, user account or telemetry is used.
