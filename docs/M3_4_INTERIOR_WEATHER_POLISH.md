# M3.4 — Sheltered room design and wet-weather visuals

**Status:** Offline Godot 4.4.1 playable prototype. No real NUS floor plans, real elevator behavior, or live weather are represented.

## Indoor spaces

ERC and SRC now include:
- A complete opaque primitive-mesh roof for directional-light shadowing. The visual skylight diffusers are not real daylight apertures.
- Recessed ERC warm / SRC cool lighting, colored accents, circulation strips, wall signs and planters.
- A clear central aisle, with ERC study desks relocated to side bays and selected solid furniture.
- ERC cafe corner, reading nook, quieter upper-floor study desks.
- SRC activity equipment wall, water-refill counter, spectator lounge.
- Mezzanine deck, guardrails and 16 visible stair treads with one continuous inclined physics collider instead of impassable 0.205 m per-step box collision. **L** remains an anytime lift shortcut rather than a simulated elevator.
- Indoor minimap in room-local coordinates, switching between ground and mezzanine layouts; not an architectural floor plan.

## Six indoor activity discoveries

Press **F** within 3.1 m. Visit all six stations:

| ERC | SRC |
|---|---|
| Cafe corner | Water-refill station |
| Reading nook | Warm-up area |
| Mezzanine study | Viewing gallery |

First-time discovery counts progress. The minimap marker turns amber to green. Unique IDs persist locally in user://nus3d_campus_activities.cfg. Repeated interactions do not increase the count. No network service.

## Weather and material response

Five offline presets remain on **Y**; **T** controls artistic time-of-day. M3.4 adds:
- Two shared StandardMaterial3D instances registered for the conceptual walkway and plaza paving.
- Wetness grows during rain, darkening pavement and decreasing roughness; rain stopping triggers slower drying and restores each material's original color, roughness and metallic values.
- Puddles temporarily remain visible after rain; ripple transparency follows wetness.
- Sky color, sunlight, ambient light and fog density transition smoothly.
- Existing GPU rain particles and 220 MultiMesh rain streaks remain.

This is stylized wetness/specularity, **not** actual mirror reflections, fluid dynamics or forecast data. Rain is hidden in the standalone indoor pockets.

## Controls

| Key | Action |
|---|---|
| I | Enter/exit ERC / SRC interior |
| L | Switch ground / mezzanine floor |
| F | Discover nearby indoor activity |
| Y | Cycle weather presets |
| T | Change artistic time-of-day |
| M | Toggle indoor / outdoor minimap |

Original E/G/C/V challenges, Q dialogues, B bicycle and X shuttle remain.

## Code and QA

- godot/scripts/utown_interior_details.gd — original finishing kit and 3+3 activity spots
- godot/scripts/utown_campus_life.gd — indoor rooms, stair collider, interaction and save data
- godot/scripts/minimap.gd — room-local schematics
- godot/scripts/utown_world.gd — shared outdoor material registry
- godot/scripts/utown_weather.gd — smooth lighting and reversible pavement wetness
- godot/tests/smoke_test.gd — roofs, stairs, activity and wet/dry checks
- godot/scripts/export_self_test.gd — Windows exported-runtime integrity contract
- godot/tests/render_viewpoints.gd — five new Godot screenshots in CI artifact

**Manual desktop GUI playtesting remains necessary** for stair ascent/descent, furnished-room collision, rain look on physical GPUs, indoor lighting comfort, 1080p frame rates and small-window HUD. Automated smoke tests and software-rendered screenshots cannot establish those qualities. All geography and indoor layouts are unofficial and schematic.
