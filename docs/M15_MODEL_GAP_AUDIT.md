# M15 — 3D model gaps and licensed asset pipeline

## Verified gaps in repository
The current project contains procedural buildings, stylized NPCs and primitive shop merchandise. There are no imported GLB/GLTF/OBJ models in the inspected integration branch. ERC, SRC, CREATE and residences are estimated geometry, not surveyed or verified architectural meshes. Indoor props, shop stock, vehicles and animal models need an art pass.

## Priority
1. **P0 — player-facing:** coffee, snack, umbrella, chickens, NPC silhouettes and clothing. Improve recognizability and proportions before detail.
2. **P1 — frequently seen:** cafeteria counters, chairs, trays, vending machines, bicycle and bus exterior.
3. **P2 — landmarks:** ERC/SRC/CREATE/UTR architectural detailing using source-verified geometry and permission, not unlicensed Google imagery or scraped meshes.

## External model acquisition
Use models explicitly licensed **CC0 1.0** for a first pass. Good discovery sources include [Kenney](https://kenney.nl/assets), [Poly Pizza](https://poly.pizza/) (check **each asset** license), and [Poly Haven](https://polyhaven.com/models). A website's general license is not enough: record the exact model URL, author, license, download date, and modifications before redistribution. Do not import Sketchfab models without verifying individual licensing; do not copy NUS proprietary building models.

Place reviewed GLB files at:
- `godot/assets/models/coffee.glb`
- `godot/assets/models/snack.glb`
- `godot/assets/models/umbrella.glb`

The optional `godot/data/model_overrides.json` manifest maps these assets to the existing shop props. **No third-party binary model has been downloaded or committed in this change.** Missing files leave the procedural meshes visible. The loader rejects unknown targets, paths outside the model directory and non-CC0 manifest declarations. The manifest is a configuration guard, **not independent proof of licensing**.

Before committing assets: check visual silhouette, scale in metres, material slots, polygon count, normals, GL Compatibility renderer, and attribution; run Godot import and smoke tests. Optimize mesh counts and reuse textures. For landmarks, maintain collision geometry separately from visual mesh.

## Next acceptance gates
- Godot headless import and smoke tests pass.
- Each imported model has a traceable license record.
- No new collision or navigation blocker.
- Compare in-game screenshots at day, dusk and rain.
- Run on a lower-spec Windows laptop and inspect FPS/memory.
