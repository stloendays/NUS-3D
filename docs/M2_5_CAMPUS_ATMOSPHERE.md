# M2.5 — Campus atmosphere and exploration (2026-11-11)

**Status:** first atmosphere and discovery pass implemented. Procedural materials, illustrative furniture, manual day/night lighting, player motion feedback and a four-stop campus passport are integrated into the Godot scene. This is a visual/gameplay slice, not a surveyed landscape model or a claim that the new props exist at their exact coordinates on campus.

## Design cues grounded in public sources

- **Town Green:** NUS UCI describes daytime picnics and Frisbee, and evening concerts/performances. The landscape designer describes a large social lawn anchored by preserved trees.
- **ERC:** NUS UCI describes the 24-hour learning hub, Computer Commons, study clusters and the lower-ground Learning Café overlooking Town Green.
- **SRC:** DP Architects describes a three-storey mixed-use centre, a central Forum, and stacked pedestrian walkways that respond to the site's slope and connect multiple routes.
- **Town Plaza:** NUS UCI identifies it as a UTown facility and describes teaching/seminar spaces within the wider learning environment.

Sources:
- [NUS UCI — Town Green](https://uci.nus.edu.sg/campus-life/campus-services/utown/town-green/)
- [NUS UCI — Education Resource Centre](https://uci.nus.edu.sg/campus-life/campus-services/utown/education-resource-centre/)
- [NUS UCI — UTown](https://uci.nus.edu.sg/campus-life/campus-services/utown/)
- [DP Architects — Stephen Riady Centre](https://www.dpa.com.sg/projects/stephen-riady-centre/)
- [DP Architects — NUS University Town master plan](https://www.dpa.com.sg/projects/nus-university-town/)
- [LANDinc — NUS University Town landscape](https://www.landinc.ca/nus-university-town)

These references establish programme and design intent, not the precise coordinates or dimensions of the furniture in this prototype.

## What changed

### Landscape materials

- The broad ground plane and Town Green use original generated grass textures; no downloaded texture or third-party material is bundled.
- Conceptual walkways use a procedural staggered-paver texture.
- Tree instances now vary in scale and rotation while remaining in two MultiMesh batches.

### Illustrative campus furniture

godot/data/campus_life.json defines four benches, three warm-light poles and one generic wayfinding totem. The positions are selected inside the current approximate Town Green polygon and checked against the conceptual path centre-lines and estimated building proxies.

**These are illustrative art placements, not mapped existing benches, streetlights or a verified NUS sign.** The props have no collision in this milestone. The sign uses generic UTown wording and does not reproduce university logos or protected branding.

### Day/night preview

Press **N** to toggle between:
- Day: cool daylight sky, brighter ambient fill and sun directional light.
- Night: dark blue background, reduced ambient fill, warm lamp pools and subtle emissive proxy windows.

This is a manual presentation toggle. It is not a real-time clock, astronomical sun path, weather model or measured campus lighting study.

### Exploration / campus passport

Press **E** within 7 m of one of four discovery points:
1. Town Green
2. Education Resource Centre
3. Stephen Riady Centre
4. Town Plaza

The HUD shows the nearby prompt and a 0/4 progress counter. Each place can be revisited; it only increments the passport once. Short descriptions are stored with public source URLs in campus_life.json.

### First-person movement

The controller now uses acceleration/deceleration and a small, speed-dependent head bob to make walking and sprinting feel less mechanical. The amplitude is intentionally subtle; there are still no footsteps, stamina system or crouch mechanic.

## Controls

| Key | Action |
|---|---|
| WASD / arrows | Walk |
| Shift | Sprint |
| Space | Jump |
| E | Discover / revisit nearby campus place |
| N | Toggle day/night preview |
| R | Reset player |
| M | Show/hide minimap |
| G | Toggle OSM shell comparison |
| O / P / T | OSM buildings / paths / contours |
| F2 / F3 / F4 | Facade layer / review camera / screenshot |

## Validation

- tools/validate_campus_life.py checks that furniture points lie inside the approximate Town Green polygon, avoid proxy-building margins and stay clear of the conceptual walkway centre-lines.
- The same validator checks unique IDs, the four source-backed discovery entries and their alignment with the existing route stops.
- tools/test_validate_campus_life.py covers invalid placements and route mismatches.
- Godot smoke tests check prop counts, placement safety, day/night light switching, discovery recording and duplicate discovery handling.
- godot/tests/render_campus_life.gd captures Town Green day/night and wayfinding views in CI.

Passing tests proves deterministic placement against the current proxy data and software behaviour only. It does not prove that the furniture positions, ground elevations, tree species, lamp positions or routes match the real campus.

## Next acceptance gates

1. Compare the prop placements with current permitted photos or an on-site walk; remove or relocate anything that is not supported.
2. Improve Town Green planting with measured tree positions and species rather than increasing random tree density.
3. Add licensed or original ambient audio only after a clear source and volume policy is defined.
4. Replace the flat green and path surfaces only after reliable elevation and vertical-datum data are available.
5. Keep all decorative furniture non-colliding until the real pedestrian clearances are checked.
