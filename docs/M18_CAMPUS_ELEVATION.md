# M18 — Campus elevation foundation

Adds **illustrative**, non-surveyed terrace elevations to all ten Kent Ridge expansion districts, with solid terrace pads and sloped pedestrian ramps. Science / MD1 and the other Kent Ridge landmark buildings inherit their district elevation. The existing UTown area stays at its original level (0) to avoid invalidating player spawn, campus props, NPC paths, vehicle routes and saved coordinates.

This is a **first stage** of whole-map relief, not a surveyed terrain mesh. District height values are artistic placeholders and are not actual NUS altitudes. The existing straight bus/road links remain at their old heights and do not yet follow terrain; buses do not use the new pedestrian ramps. Ramp ends and paths must be inspected for gaps/overlap, and players must be tested walking up/down in the Godot scene.

Current design: terrace height stored as `elevation_m` in `kent_ridge_expansion.json`; solid collision for terrace, walk surface and landing. A 1:10 ramp run is used for accessible schematic routes. No new textures or terrain shader.

## Required before merge
- Godot headless import, `campus_elevation_smoke_test.gd`, integrated smoke, full scene render.
- Walk test UTown → Science/MD1 and other districts; ensure collision, gravity, ramps and landing line up.
- Validate bus stop/road terrain transitions and sightlines; no floating buses or blocked paths.
- Later: continuous terrain mesh and measured control-point elevations for **both** UTown and Kent Ridge, with aligned walkways, NPCs, spawn points and transport. Do not label the present version complete whole-campus terrain.
