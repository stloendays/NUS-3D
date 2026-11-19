# M11 — UTown Ambient Ecology and Soundscape

This independent scene module adds **illustrative**, non-surveyed campus wildlife and lightweight environmental feedback. It does not claim to reproduce actual animal populations or their precise positions.

## Implemented

- 10 stylized tropical mynas with proximity-triggered takeoff and simple wing animation.
- 12 butterflies that hover over Town Green and hide during rain, dusk, or indoor exploration.
- 2 campus cats with gentle tail movement and a short non-contact avoidance reaction.
- 40 drifting leaves in **one** MultiMesh, activated only near the existing procedural trees and disabled during rain or indoor scenes.
- Original in-memory PCM for grass, pavement, indoor footsteps, and short positional bird calls. Footsteps are movement-distance-triggered, disabled on bicycles, shuttle, movement lock and jumps; the UI sound toggle also mutes ambient audio.
- No new controls, account state, gameplay rewards, nav obstacles, colliders, external assets or map coordinates.

## Performance and compatibility

`AmbientEcology.detail_level` supports **0 / 1 / 2** for low/normal/high budgets: birds 5/10/14, butterflies 6/12/18, cats 1/2/3, leaves 20/40/64. Default is normal. Movement/animation is ticked every 120 ms; audio and step tracking use a small per-frame update. Distant animals are hidden; weather and interior conditions disable irrelevant effects. All geometry is procedurally generated and collision-free.

The branch is based on `integration/nus3d-qa-20261119-v1`, so it avoids editing existing NPC, quests, HUD, login, coins and multiplayer implementations.

## Validation

```sh
godot --headless --path godot --import --quit
godot --headless --path godot --script res://tests/ambient_ecology_smoke_test.gd
godot --headless --path godot --script res://tests/integration_smoke_test.gd
```

The smoke test covers counts, audio synthesis, collision isolation, weather/indoor visibility and movement lock. For visuals, inspect the lawn and trees at daytime, rainy and evening presets. All wildlife is game art rather than a real-world survey.
