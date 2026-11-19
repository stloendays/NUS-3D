# M23 — Terrain-following campus links

Replaces each single straight graded strip in Kent Ridge's schematic walk connections with sampled segments using the shared M22 height function. Road, pedestrian and cycle strips now follow local interpolated relief at 18-game-metre spacing, with at most 64 segments per link.

Pedestrian and cycle segments retain static collision; road segments remain cosmetic. This is a visual/physics-path foundation, not a surveyed road map or continuous collision terrain. Segmented links may still intersect district terraces or buildings, have seams, and mismatch existing bus trajectories. The maximum segment cap can produce coarse steps on unusually long connections.

No changes to UTown coordinates, multiplayer/save schema, NPC behavior or economy. Must run Godot parse, walk collision tests, route screenshots, and low-end performance profiling before merging.
