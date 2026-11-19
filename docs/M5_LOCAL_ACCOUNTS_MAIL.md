# M5 — Offline login, progression and Campus Post

This is an **unofficial offline single-device prototype**. It is not NUS SSO, a university-approved service, an internet chat system or an email provider. No email address is required.

## How to play

Open the Godot project as usual or use the Windows portable build. The new opening screen offers **Sign in** and **Create a new local account**. Use a name of 3–20 ASCII letters/numbers/underscores plus a password of 8–128 characters. Log in again later to restore your progress.

After login, all the existing gameplay keys remain unchanged: WASD, E for UTown discovery, C for Field Notes, V for Campus Sprint, B for bicycle, Y for weather, and more. Press **J** or use the profile badge to open Campus Post. Gameplay and timers pause while reading mail, composing or at the login screen; closing mail resumes play. Log out to switch to another local account.

Campus Post lets you read/delete messages, view Sent mail, and write to another username registered on the **same computer**. Messages are local files; they never go over the network.

## Levels

| Event | One-time XP |
|---|---:|
| Each of 4 different tour checkpoints | 60 |
| Each of 8 different Field Notes | 40 |
| First finished Campus Sprint | 120 |
| First gold Campus Sprint medal | 80 |

Level 1 needs 100 XP to advance; subsequent level requirements grow by 50 XP each. Replay and reload do not duplicate XP thanks to saved event IDs. Every level-up delivers a system notification in the inbox.

## Save isolation and compatibility

- Accounts and salted PBKDF2-HMAC-SHA256 password hashes are stored at user://nus3d/accounts.json.
- Each profile has its own user://nus3d/profiles/USERNAME.json file with XP, claimed rewards, tour IDs and inbox/sent messages.
- Each profile has a unique user://nus3d/challenge_RANDOM_ID.cfg file for existing Field Notes and Sprint personal best.
- On the first account registration only, the previous user://nus3d_explorer.cfg is copied to that account's challenge file if present. The original is not moved or deleted.
- Mail keeps up to 100 messages per box, 80-character subjects and 2000-character bodies.
- Local profiles are not protection against somebody who has direct access to your computer's save files. Do not reuse important passwords.

The existing 3D scene, mechanics, weather, NPCs, interiors, HUD, player input, and original tests are preserved. A separate startup shell loads the original main.tscn and applies a pause layer. Godot CI and Windows export checks should continue to run; the special exported-runtime self-test skips the login overlay.

## Automated checks

Run these commands from the repository root:

    godot --headless --path godot --import --quit
    godot --headless --path godot --script res://tests/account_smoke_test.gd
    godot --headless --path godot --script res://tests/smoke_test.gd

Account smoke tests use unique temporary storage paths and cannot overwrite the real save.

## Explicit exclusions

No cloud account service, password reset, live multiplayer, real internet delivery, external account integration or cross-device synchronization is implemented. These would require a separate authenticated server and security/privacy work.
