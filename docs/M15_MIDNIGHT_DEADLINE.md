# M15 — Midnight Deadline / 午夜 DDL 恐怖追逐模式

**Status:** implementation under test in an isolated PR, not yet included in released main. This is an **optional fictional, non-gory campus comedy-horror mini-game**. The normal game remains bright, funny and unchanged when this mode is not started.

## How to play

After signing in and finishing the opening animation/faculty picker, use the **Night Shift** account-bar button or **Ctrl+F6**. Confirm the mode prompt to start. The mode cannot be launched from login, a paused menu, online LAN, a shuttle/bicycle/interior, an active exam or a cinematic.

The 5-minute mission is intentionally sequential:

1. Find the glowing **Spectral Pulse Blaster** near Town Green. The player cannot damage pursuing NPCs or fire in horror mode before collecting it.
2. Retrieve three **cursed assignment files** at existing UTown route checkpoints. Walk over each glowing prop to pick it up.
3. **Banish two fictional Phantom Examiners** by aiming and using the standard LMB toy-shot control. Each has three hit points, so multiple hits are needed. Their search behavior transitions among patrol, chase, remembered last position, and stun; they can catch the player.
4. Once the blaster, documents, and both banishments are complete, return to the glowing **Town Green safe exit** for victory.

The pursuers are stylized imaginary comic ghosts, not real students, ethnic groups, staff or professors. No gore, severed bodies, realistic weaponry or user-generated violent imagery is present. A pursuer catching the player removes one of three lives and relocates the ghosts; three catches or zero time causes failure. At any time, **Ctrl+F6** can open the exit confirmation, which forfeits the current round.

## Visual and audio treatment

- Thunderstorm and evening lighting are applied only after opting in; previous weather, lighting and selected toy weapon are restored at round exit.
- A compact purple transparent fear overlay, objective tracker and countdown make danger legible without overwhelming the existing campus HUD.
- All geometry is made from primitive meshes and cached materials. The two enemy characters and four markers are constructed once and toggled visible only during the challenge; normal NPCs are untouched.
- The spectral blaster is a fictional glowing toy attached to the existing first-person camera. Combat uses the existing bounded projectile pool and physics LOS validation, rather than spawning unlimited projectiles. The new ambience is a short original synthesized drone, skipped in headless tests.

## Save, rewards and multiplayer restrictions

- Records are stored separately per local player via `feature_save_path("horror")`: number of clears and best completion time. No normal Coursework, exam, NPC-affinity, arcade weapon unlocks or account sign-in data are overwritten.
- **First clear only**: +160 XP and +100 in-game coins through the existing one-time reward ledgers. Replays update the best time and win count but cannot generate repeat XP/coins.
- LAN host/client/connecting states cannot start the mode. If a multiplayer session, shuttle or interior interruption somehow appears during the challenge, the game ends the challenge and restores normal scenery rather than running a non-host-authoritative combat state.
- Closing an account or changing users stops the mode, hides the fictional enemies, restores weather/time, and clears transient round progress. No AI API or network connection is required.

## Verification gates

Automated CI must pass:
- `godot --headless --path godot --import --quit`
- `godot --headless --path godot --script res://tests/midnight_horror_smoke_test.gd`
- Existing `arcade_smoke_test.gd`, `account_smoke_test.gd`, `integration_smoke_test.gd`, and the main Godot full regression matrix
- Windows x64 export and headless start; UI appearance and actual keyboard/mouse handling still require Windows visual QA.

The new test asserts that the horror environment is **off by default**, weapons are required, the pursuers can be banished, all three clues open the exit, failure restores normal mode, wins are account-specific and rewards cannot be farmed.

## Integration constraints

Do not overwrite unrelated ongoing branches: multiplayer/F11, professional exam/F8, local admin/F12, Campus AI, wardrobe, NPC affinity, loading screen, and campus geometry all remain independent. The horror mode is an optional node and a small routing hook in the existing shell and arcade. No unlicensed third-party models or audio are added.

Repository: [NUS-3D](https://github.com/stloendays/NUS-3D).
