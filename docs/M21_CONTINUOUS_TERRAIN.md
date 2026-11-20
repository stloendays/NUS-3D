# M21 — Continuous visual terrain mesh

Adds a bounded, generated triangle mesh spanning Kent Ridge district centers, with smooth interpolation of schematic elevations. Mesh generation is capped at 3000 grid cells and uses 24-game-metre spacing to control memory and draw calls. No external heightmap or texture dependencies.

**Important scope:** This mesh is VISUAL ONLY. Existing base-ground and terrace collisions remain authoritative. Player walking, NPC navigation, buses, ramps, buildings and spawns are not yet projected onto the continuous surface. As a result the new mesh may intersect roads and terraces, and its height samples may not match M19 bus stop elevation blending. It is not a georeferenced terrain reconstruction and does not yet provide full-campus seamless terrain.

Validation pending: Godot import, `continuous_terrain_smoke_test.gd`, screenshot checks, performance profiling and intersection audit. Future work must unify the height sampler, align roads/entrances and replace overlapping collision ground carefully, without breaking UTown coordinates.
