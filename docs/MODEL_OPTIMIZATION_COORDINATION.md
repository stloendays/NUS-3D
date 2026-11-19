# Parallel modeling and performance optimization — coordination

Status: coordination document; not a merge authorization.

## Workstreams (verified 2026-11-19)
- [PR #64](https://github.com/stloendays/NUS-3D/pull/64) — modeling and mesh caching, head `visual/campus-modeling-optimization-20261119`, stacked on PR #60. **Ownership:** `godot/scripts/kent_ridge_world.gd` and `godot/tests/kent_ridge_expansion_smoke_test.gd`. Visual silhouette and reuse of repeated BoxMesh geometry. Do not edit shared input or global gameplay.
- [PR #57](https://github.com/stloendays/NUS-3D/pull/57) — wildlife, dining crowds and shop visuals memory optimizations, stacked on PR #25. **Ownership:** `godot/scripts/utown_ambient_ecology.gd`, `godot/scripts/utown_dining_crowds.gd`, `godot/scripts/utown_shop_visuals.gd`. Preserve its resource sharing and distance-squared culling.

## Non-overlap rule
No cherry-picking entire branches or merging stacked PRs directly into main before their bases. No duplicate geometry-cache singleton or global material cache without API review. Preserve scene node paths, scripts, coin/quest/save systems and player input. Coordinate changes to main.tscn, project.godot, HUD, player scripts and shared assets before editing.

## Integration sequence
1. Verify base PR dependencies (#60 for #64, #25 for #57), and resolve each stack in dependency order.
2. Review diffs for accidental shared changes, test/scene node path assumptions and resource lifetime.
3. Run Godot headless import and focused smoke tests on each branch, then run combined smoke tests on a temporary integration branch after both bases are available.
4. Profile identical camera positions and hardware settings before/after: FPS, 1% low, frame time, draw calls, mesh instance count, texture memory, RAM and loading time. Record raw values and device/resolution. Never infer measured improvement from caching alone.
5. Visually compare day/night and close/far views for bus, building, foliage, crowds and shop props. Ensure culling does not pop in distractingly and low-poly details remain readable.
6. Merge only after green checks, visual review and explicit approval. Keep each workstream's PR independent until then.

## Known risks
- Shared BoxMesh resources reduce duplicate mesh allocations but do **not** automatically reduce draw calls. MultiMesh/LOD should be evaluated separately with profiling.
- Material reuse is valid only when instances do not mutate shared materials independently.
- The two branches have different ancestry. A conflict-free file list is not proof of conflict-free integration.
- PR #57 and PR #64 are both open; test and performance verification remain pending.
