# M19 — Grade schematic roads and transit

Extends M18 terrain terraces by giving bus-stop anchors a blended district-based elevation and replacing flat visual road/footpath/cycle links with sloped mesh strips. The cosmetic buses now inherit stop heights through their existing route interpolation.

**Scope:** This is a visual integration pass, not a continuous terrain mesh or surveyed road geometry. The strip meshes are not solid colliders; player walkability across routes is **not yet guaranteed**. UTown retains its existing level and coordinate system. District terrace pads remain as in M18.

**Known risks:** stop heights from interpolation can differ from district terrace height, resulting in gaps; straight route segments can cross buildings, and buses can clip into terrace pads. The blended height field is schematic, not NUS elevation data. Need in-game checks at all stations, bridge transitions and Science/MD1; do not merge before testing.

Run `godot --headless --path godot --script res://tests/graded_routes_smoke_test.gd`, then run integrated smoke and visual route traversal. A later terrain-mesh and physics pass must provide continuous collision surfaces and smooth transitions.
