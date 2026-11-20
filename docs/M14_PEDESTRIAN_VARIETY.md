# M14 — Crowd and height variation

- The six existing named characters remain intact, with Maya/Ethan/Mei as the only relationship-driven characters.
- Add 18 lightweight ambient pedestrians for a total of up to 24 outdoor walkers (subject to available valid walkway paths). Their role labels and brief lines cycle deterministically without persistent identity or relationship saves.
- Apply deterministic per-character height scaling (0.87–1.146 of existing base mesh height), with slight independent body-width scaling; the original mesh height is approximately 1.94 units. Indoor characters still use the existing baseline proportions to preserve room and interaction alignment.
- Reuse existing skin/hair/outfit palettes and walking animation; no new imported assets, shaders or high-frequency AI decision systems.
- Ambient dialogue bypasses the named-character dialogue bank; only authored characters receive affinity updates. Routes are reused with staggered starting positions.

**Limitations / QA:** More animated nodes increase draw calls and CPU cost. This is a prototype density increase, not yet crowd pooling or distance-based simulation throttling. Profile integrated campus performance on low-end hardware before raising density further. Check camera visibility, character overlap and the full height range in Godot. No performance improvement or passing runtime test is claimed.
