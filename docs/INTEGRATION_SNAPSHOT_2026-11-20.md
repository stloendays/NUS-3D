# NUS-3D integration snapshot — 2026-11-20

This branch consolidates the current open feature work on top of the latest `main`. It is an integration candidate, not a release.

## Included feature families

- NPC personality, selective relationship tracking, appearance/height variety, classroom/campus/interior props.
- NPC negative-affinity rivalry and chase for selected story characters; A* obstacle-aware movement, separation and ground following.
- Campus elevation mesh, graded routes, unified height sampling and terrain-conforming paths.
- Five additional enterable UTown campus interiors.
- Physical SRC club stations (chess, cards, social), original procedural sound cues, secret ending and short victory feedback.
- Skippable cartoon ending cutscenes.
- Gameplay state isolation, account-safe reset and atomic coin reward behavior.
- Flat campus-cartoon login art and coordinated login skin.

## Compatibility decisions

- Club interaction stays on **Tab**; coursework remains on **P**.
- NPC rivalry uses **T** to tease and **Shift+U** to apologize so the existing U interaction is not shadowed.
- Only Maya, Ethan and Mei receive authored personality/chase behavior; the other 21 pedestrians are ambient passersby.
- New procedural prop systems are decorative unless explicitly stated; no external proprietary map or 3D assets are copied.
- Existing player controller, saves, mainline UI, weather, coins and quest progression are preserved and integrated additively.

## Automated validation

The integration workflow now includes:
- existing account, language, UI, arcade, economy, coursework, shop and leisure smokes;
- M14 gameplay integrity and M17 relationship/furniture/interior tests;
- NPC navigation, obstacle avoidance and terrain-following checks;
- M18–M23 elevation, graded route, continuous terrain and height sampler checks;
- cartoon login shell smoke and visual preview;
- Windows x64 export and exported executable headless launch.

CI results must be checked on the current commit before merging. A green headless pipeline is not a substitute for in-engine visual review or hardware performance measurements.

## Merge gate

Do not merge to `main` until all required checks pass on the latest commit, the game is launched and visually reviewed in relevant areas (UTown, SRC club, interiors, Kent Ridge, sports/Science, day/rain/night), and any remaining PR conflicts are resolved. Record FPS, 1% lows, RAM, draw calls and load times on a documented PC before claiming performance gains.
