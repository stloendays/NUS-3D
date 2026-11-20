# M16 — Outdoor campus furniture

Adds original low-poly campus props near four existing UTown waypoint anchors (Town Green, ERC, SRC and Town Plaza): 8 benches, 8 sorted waste/recycling bins, 4 water-refill cabinets, 2 bicycle racks, 2 event boards and 2 vending machines. All use primitive meshes and shared materials per cluster; no downloaded models or textures.

The prop kit is isolated in `utown_campus_props.gd` and instantiated from `UTownCampusLife._ready()`. It does not modify player movement, coins, XP, quests, saves, accounts, multiplayer protocol or the existing classroom kit.

**Important:** These are illustrative game objects, not verified real-world furniture coordinates. The anchors are schematic waypoints with offset positions. No collision bodies or gameplay interaction are attached yet; that keeps pathfinding and performance behavior unchanged, but players can pass through them. Before merging, inspect geometry and route clearance in Godot and profile low-spec GPU draw calls.

Validation command: `godot --headless --path godot --script res://tests/campus_furniture_smoke_test.gd` (not yet run). Review scene placement at all four waypoints and rerun integrated smoke tests.
