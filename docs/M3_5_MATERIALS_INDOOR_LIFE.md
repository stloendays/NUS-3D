# M3.5 — Building material finish, artistic lighting and occupied interiors

**Status:** Godot 4.4.1 gameplay prototype. Source data, exterior footprint dimensions, room shapes and vehicle routes remain schematic. Original assets only; no downloaded textures, real student data or university logos.

## Architectural and material treatment

- A separate **M35ArchitecturalMaterialStudy** is attached beneath each priority-0 ERC and SRC **ArchitecturalStudy_NotSurveyed** node. Consequently existing F2 toggles the entire new detail layer off for original greybox comparison.
- Each of five original ERC/SRC wing masses gains individually subdivided tinted glass panes, brushed-aluminum mullions, window sills, two parapet edges and a shallow entrance canopy underside with low-cost emission.
- The finish is intentionally low polygon count and uses StandardMaterial3D roughness, metallic and emission parameters. Under Godot Compatibility renderer, tinted metallic glass is **stylized**, not true physically accurate ray-traced glazing.
- Both illustrative interior rooms gain stone-colored tile panels, transition grout, wall ribs, upper acoustic panels and glass trim. Added accent lights become visible only for the active room; one shadow-capable fixture per room is provided as a restrained performance compromise.

## Indoor campus characters

The M3.5 separate, modular script creates 6 non-colliding fictional NPC actors using the previously developed low-poly body and joint pivots:

| Location | Role | Behavior |
|---|---|---|
| ERC lower level | Maya, cafe attendant | Shifts arms, operates a coffee-order display |
| ERC lower level | Ethan, reader | Seated reading with animated arm motions |
| ERC mezzanine | Mei, studying | Slow 1.6 m patrol and satchel |
| SRC lower level | Lucas, warm-up | Alternating arm stretches |
| SRC lower level | Aisha, spectator | Seated reading |
| SRC lower level | Daniel, volunteer | Short walk near refill station |

Characters in the other room are hidden. Close to any character, **Q** starts an original dialogue line and turns the character toward the player. Existing outdoor Q dialogues, Field Notes, Sprint, room activity F interaction, L lift, weather, bicycle and shuttle are unchanged.

All roles, names, appearance and dialogue are original fictional game elements, not representations of actual students or staff.

## Lighting and performance trade-offs

- Entrance accents brighten during artistic evening and storm presets.
- ERC and SRC use warm/cool localized lights; boost intensity at night/in storm modes. Their lights are not left active in the remote room.
- No real-time ray tracing, screen-space reflections, imported texture maps or HDRI assets. Quality is limited by the Godot OpenGL 3.3 Compatibility renderer and platform drivers.
- CI smoke checks count layers and rooms, while viewport screenshots show NPC activity and day/evening light differences.
- **Manual GPU GUI playtesting** is still required to assess dynamic shadow performance, light bleed, view angle, indoor NPC intersections with furniture, frame pacing and color balance.

## Files

- godot/scripts/utown_visual_polish.gd — facade and interior material layers, adaptive lights
- godot/scripts/utown_indoor_npcs.gd — six characters, simple routines and dialogue
- godot/scripts/utown_campus_life.gd — Q routing between indoor and outdoor NPC
- godot/scenes/main.tscn — two additional module nodes
- godot/tests/smoke_test.gd — facade, NPC, dialogue, light registry regressions
- godot/scripts/export_self_test.gd — exported-Windows checks
- godot/tests/render_viewpoints.gd — new original M3.5 screenshots
