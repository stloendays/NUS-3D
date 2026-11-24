# M27 — Dynamic campus ecology

## Scope

M27 adds a compressed offline campus clock and uses the existing 18 ambient pedestrians to create time- and weather-dependent routines. It extends M26 rather than replacing the existing pedestrian, navigation, weather or story-character systems.

## Daily clock

- One in-game day lasts 30 real minutes; a new session starts at 11:15 so the lunch period becomes visible shortly after launch.
- 11:30–13:30 is the lunch peak. The ambient activity cap rises from 6 to 10, and food-focused routines route to the existing Town Plaza food court.
- Existing [T] lighting control remains available. Manually cycling the lighting preset synchronizes the campus clock to a representative time.

## Campus routines

- Six deterministic routine profiles are distributed across the 18 ambient pedestrians: social, studious, foodie, active, quiet and commuter.
- The existing food-court tables and stools are reused for 16 dining seats. Nine queue positions are derived from the existing stall layout.
- During rain or thunderstorms, ambient pedestrians leave exposed outdoor activities and move to covered waiting positions under the existing Town Plaza food-court roof or SRC Flavours awning. Covered lunch queue/eating routines remain available.
- Small occupancy discs use one MultiMesh draw call to distinguish available and reserved seats, queues, refill stations and vending positions.

## State and performance boundaries

- The six named story characters are not assigned ambient daily routines.
- No new collision geometry, account persistence, currency, quest rewards, input bindings or multiplayer RPCs are added.
- Occupancy indicators share one mesh/material and one MultiMesh; no per-frame pathfinding is added beyond the existing M26 activity scheduler.
- Cancelled routines release their reservation without being counted as completed activities.

## Validation

The M27 workflow checks clock/lighting synchronization, lunch crowd capacity, personality profile distribution, dining and queue anchors, rain-shelter routing, occupancy state and story-character isolation. It also renders lunch, rain-shelter and evening viewport captures.
