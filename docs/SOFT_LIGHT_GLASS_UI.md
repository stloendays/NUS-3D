# NUS-3D / Soft Light Glass UI

## Intent
Replace the previous dark opaque game overlays with a friendly, airy, accessible
original visual language informed by modern mobile OS design. This is NOT an
Apple UI reproduction, brand asset pack, or claim of native iOS material blur.

## Material
- Pearl translucent cards (~88–96% opacity), cool blue/teal hairline borders.
- Rounded cards 19–27 px, controls 12–13 px, antialiasing on.
- Shadows below 25% alpha and no more than 18px spread.
- Slate ink for readable text, gold only for targets/rewards, teal for actions.
- Light green/ivory map with differentiated road, building, player and goal.
- Original 11 keycaps still depress and play existing procedural sound.

## Performance
Use only native StyleBoxFlat primitives. No shader, offscreen viewport,
Gaussian blur, animated noise, new background textures or extra 3D geometry.
Low-spec mode therefore retains its existing rendering controls.

## Quality gates
- Run `godot --headless --path godot --script res://tests/soft_glass_ui_smoke_test.gd`.
- Keep existing ui_feedback, account, language, Coursework, minimap and camera tests.
- Compare 1280×720 and 1920×1080 screenshots against earlier dark version, in
  sunshine, sunset and rain. Check light sky behind white cards and readability.
- Live GPU validation is still needed for true antialiasing, text rasterisation,
  overlapping UI cards, button focus, actual FPS and audio.

## Boundaries
Do not change the NUS locations, player mechanics, quest rewards, network
state, language policy or settings hotkeys as part of a skin update.
