# Kent Ridge facility and model recovery (54 + 60 + 64)

Clean main-based, additive reconstruction of the facility work in PR #54, its prop-model refinements in PR #60, and geometry cache/bus polish from PR #64. Unlike the old stacked branches, this reconstruction preserves MD1 access (#49), the landscape/minimap makeover (#50), and the optional F11 Campus AI (#66) in `main`.

Nine schematic campus districts receive three recognizable activity zones each (maker/workshop, reading/printing, Computing desks, Business presentation/coffee, museum sculpture, YIH/UHC fixtures, PGP laundry and Kent Ridge MRT waiting). These are **decorative** assets, not interactable shops or surveyed interiors. The shuttle receives windows, bumpers, doors and cylindrical wheels. Repeated same-size BoxMesh objects share geometry within one world instance; materials remain cache-backed.

**QA:** `godot --headless --path godot --script res://tests/kent_ridge_expansion_smoke_test.gd` checks the zones, model details, bus parts and shared mesh cache. Existing Godot, bus, bilingual, multiplayer and Windows CI must remain green before merge. In-game navigation, walkable offsets, GPU visual screenshots, RAM/draw-call/FPS profiling and collision checks are still unverified on real hardware. Geometry caching does not imply fewer draw calls.

**Assets:** procedural original meshes, no downloaded or proprietary models or map tiles. No quests, NPC AI, accounts, input, network or save API changes.

Locale/UX integration (after #72): the schematic props are recognizable by silhouette rather than generic English floating labels. This keeps the login-selected single-language presentation clean and saves 27 Label3D nodes.
