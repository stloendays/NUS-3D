# MD1 — Tahir Foundation Building (Science/Medicine vicinity)

Adds MD1 as a named landmark to the existing Kent Ridge SCIENCE district, with a low-poly podium, glazed facade, vertical fins and entrance canopy.

**Grounding:** MD1 / Tahir Foundation Building, 12 Science Drive 2, Singapore 117549. The in-game placement is a **schematic district-relative offset**, not a georeferenced building footprint. Dimensions (29 × 32 × 46 game metres), 12 stylized floors, orientation and facade elements are provisional artistic estimates. The building is not a confirmed real-world reconstruction.

**Compatibility:** Existing Godot Compatibility renderer, low-poly box geometry and current collision system. No new textures, imported meshes, gameplay state, NPC logic, quests, network messages or save changes.

**QA before merge:** Run `godot --headless --path godot --script res://tests/md1_landmark_smoke_test.gd`; render Science district from the S16 and Frontier approaches; check no overlap with S7/S8 or footpaths, walkability and performance. Future phase: use verified footprint/orientation and improve entrance/connecting walkways.

## Verified access and neighborhood (NUS official sources, 2026)

- Official address: 12 Science Drive 2, Singapore 117549.
- **No vehicle access from Science Drive 2**; the drop-off approach is from Science Drive 4.
- Pedestrian approach from NUH goes via the MD6 Centre for Translational Medicine, an alley/staircase and MD1 Level 2 lift lobby.
- MD1 is between the Science campus and NUH/medical cluster, not in UTown.
- Official references: https://sph.nus.edu.sg/about/contact-us/ and https://bpb-us-w2.wpmucdn.com/blog.nus.edu.sg/dist/4/6173/files/2026/06/Map-to-MD1-version-18-May-2026-Walk-ISB.pdf

## Geometry audit

- The current MD1 offset (+68, -43) is **east of** S7/S8 (+3, -43), toward the NUH side of the schematic Science district. This is directionally plausible but not a surveyed position.
- Axis-aligned landmark bounding boxes in the SCIENCE district must not overlap. The present MD1/S7-S8 footprints have a 29 m schematic x-axis gap; MD1/Frontier are separated in the z-axis.
- The 12-floor count, height 46 m and facade treatment remain unverified visual approximations. Do not present them as architectural facts.
- Vehicle and pedestrian access routes are **not yet modeled** as separate navigable connections. Do not route buses to MD1 through Science Drive 2.
