# M22 — Shared terrain height sampling

M21 introduced `KentRidgeTerrainMesh.height_at()` but M19 still used an unrelated 220 m distance blend for bus stops. M22 replaces that duplicate calculation with the M21 sampler, reducing discrepancies between the rendered surface and stop elevations.

The generated terrain surface has a deliberate -0.22 game-metre visual offset; stop platforms sit above their sampled height. This patch does not alter UTown coordinates, district building platforms, NPC navigation, persistence or multiplayer protocols.

**Still unresolved:** roads are straight graded strips between stop centers, not terrain-conforming curves; no continuous terrain collision; terrace-to-ground seams; building entrances, player spawn and bus clearance need scene QA. All height values are schematic and should not be represented as surveyed NUS topography.

Run `godot --headless --path godot --script res://tests/unified_height_sampler_smoke_test.gd` and integrated scene tests before merging.
