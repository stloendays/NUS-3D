# MD1 — Tahir Foundation Building (Science/Medicine vicinity)

Adds MD1 as a named landmark to the existing Kent Ridge SCIENCE district, with a low-poly podium, glazed facade, vertical fins and entrance canopy.

**Grounding:** MD1 / Tahir Foundation Building, 12 Science Drive 2, Singapore 117549. The in-game placement is a **schematic district-relative offset**, not a georeferenced building footprint. Dimensions (29 × 32 × 46 game metres), 12 stylized floors, orientation and facade elements are provisional artistic estimates. The building is not a confirmed real-world reconstruction.

**Compatibility:** Existing Godot Compatibility renderer, low-poly box geometry and current collision system. No new textures, imported meshes, gameplay state, NPC logic, quests, network messages or save changes.

**QA before merge:** Run `godot --headless --path godot --script res://tests/md1_landmark_smoke_test.gd`; render Science district from the S16 and Frontier approaches; check no overlap with S7/S8 or footpaths, walkability and performance. Future phase: use verified footprint/orientation and improve entrance/connecting walkways.
