# NUS-3D integrated gameplay QA / 游戏集成验收

**Scope:** integrated branch `integration/nus3d-qa-20261119-v1` and PR #20. These checks validate an unofficial fictional game, not a surveyed digital twin of NUS.

## Features and input ownership
| Input | Owner / purpose |
| --- | --- |
| WASD / Shift / Space | First-person walk, run and jump |
| E / C / V | Campus discovery, Field Notes, Sprint |
| Q / I / L / F | NPC dialogue, interiors, floor shortcut and room activities |
| B / X | Bicycle and fictional campus shuttle |
| P / Shift+P / K | Coursework journal, faculty choice, task pickup/submit |
| Tab | Post-Course Club, unlocked after any full three-chapter faculty arc |
| Mouse-left / 1–3 / U | Cartoon toy throwing, switching toys and professor interaction |
| H | DDL story object interaction or short direction focus pulse |
| Z / O / N | Coin pickup, game-only shop and fictional lunch delivery |
| J | Local account mailbox (never the assignment journal or weapon firing) |
| M / F1 / F7 / F9 / F10 | Map, expanded help, photo HUD, UI sound toggle, language |
| T / Y / F2 / F6 | Artistic light, weather, provisional facades and sourced GIS overlay |

## How to validate automatically
```bash
python -m unittest discover -s tools -t . -v
python tools/validate_utown_data.py
python tools/audit_route_clearance.py --strict --report build/route-clearance.json
godot --headless --path godot --import --quit
godot --headless --path godot --script res://tests/smoke_test.gd
godot --headless --path godot --script res://tests/integration_smoke_test.gd
```

The CI job also runs separate accounts, localization, tactile UI, arcade, DDL, dining, coins, discovery, building envelope and leisure smokes, plus a Windows unsigned portable export and native headless EXE self-test. Read actual GitHub Actions results; tests have **no pass guarantee until checks finish**. Shell-level checks fail on Godot `SCRIPT ERROR:` and `ERROR:` as well as nonzero exit codes.

## Manual 1280×720 and 1920×1080 GPU acceptance
1. Register two local accounts. Check Chinese glyph fallback, F9 audio balance, tutorial scrolling, login/logout, mailbox and F10 language change.
2. Confirm the opening cinematic and first faculty picker are **not both overlaid**. Press skip and verify mouse focus and non-paused controls.
3. Walk from Green to ERC, SRC and Plaza; inspect proxy collision, steps, ramps, trees, furniture and 3-D labels. Recheck both exterior facades against licensed real-world reference photographs.
4. Check cloudy/rain/storm presets, authored static cloud textures, wet-ground transitions and no indoors rain.
5. Finish a coursework chain; test XP, credits, local coins, Post-Course Club Gomoku/cards, a saved session and switching accounts. Re-login must neither award extra XP nor inherit other users' progress.
6. Exercise arcade firing and professor interactions, coin pickups, O-shop, N deliveries, H/DDL steps, bicycles and shuttle; ensure no duplicate keyboard actions or blocked UI states.
7. Toggle F2/F6/F7/F1, verify status panels do not overlap or obscure the crosshair, and monitor FPS/frame pacing and resident memory on an actual Windows GPU.

## Evidence and limitations
- ERC/SRC OSM outline-based elevated facade studies are separate **non-colliding visual layers**. Existing collision-box plan IoU measurements are not made accurate by these decorations.
- CREATE 16 floors and UTR 25 levels are source-informed counts. Total modeled heights and facade dimensions remain **estimates**.
- SRC/ERC interiors and the shuttle route are illustrative, not as-built floors or official service stops.
- Automatic Linux software rendering and Windows exported EXE headless checks cannot substitute for manual GUI and sound testing.
- All NPCs, cartoon combat, deadlines, college roles and mail are fictional offline content; no official NUS authentication or external email integration.
