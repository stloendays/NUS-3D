# M14 — Gameplay state consistency and account/session isolation

This patch hardens existing game mechanics instead of introducing new 3D resources, NPC counts or currencies.

## Fixes

| Player flow | Problem | Change |
| --- | --- | --- |
| First login / faculty selection | `GameShell._enter_game()` showed a mandatory faculty modal, then called `Player.reset_player()`, clearing `movement_locked`. | Reset the avatar first, **then** reapply the intro/faculty lock; an unselected new student cannot run behind the picker. |
| Coin shop | The shop released the mouse but did not prevent player movement or inputs from reopening Coursework/leisure UI. Mouse clicks could recapture the cursor through the player controller. | Shop now owns a modal lock, captures Escape/O, blocks other gameplay keys, preserves the prior mouse/lock state and restores it on exit. Coursework P/Shift+P, leisure Tab, and exam F8 do not overlap the shop. |
| Account A → logout → account B | Random coins, lunch delivery timer, shop state, active cartoon projectiles, NPC snack-break/focus and shot cooldown could survive the session boundary. | Save the account-specific wallet and arcade progression, clear **only** these transient objects in their existing bounded pools, and reload new account data. On account entry, reset transient state before loading; seed only five new session coins after spawn. |
| Returning to account A | Wallet, one-time reward IDs, purchased boosters, completed coursework or NPC arcade XP must not be wiped by temporary reset. | Keep all existing ConfigFile keys and separate profile storage; only per-session visuals/delivery are cleared. |
| Coin persistence | Purchases and credits reported success even if ConfigFile save failed. Lucky Badge pickup and lunch delivery used separate save passes and could desynchronize boosters and rewards. | Roll back unsaved balances, perk consumption and claimed IDs; persist pickup + consumed Lucky charge, and delivery payment + tip + delivery count in **one** save, without changing the file schema. |
| Modal player controls | First-person mouse clicks and R reset were still accepted while `movement_locked` was active. | Block these inputs while locked. Player movement was already gated in physics; now pointer capture and respawn are gated too. |

## Technical footprint

Changed `game_shell.gd`, `utown_coins.gd`, `utown_arcade.gd`, `player_controller.gd`, `utown_coursework_ui.gd`, and `utown_leisure_ui.gd`.

No new 3D meshes, audio streams, network calls or account fields. The projectile pool remains 8 and the coin pool 12. All changes are in a stacked feature branch based on the independently tested M12 loading screen PR #35. The original main branch is untouched.

## Tests

```bash
godot --headless --path godot --import --quit
godot --headless --path godot --script res://tests/gameplay_integrity_smoke_test.gd
godot --headless --path godot --script res://tests/coins_smoke_test.gd
godot --headless --path godot --script res://tests/account_smoke_test.gd
godot --headless --path godot --script res://tests/english_exams_smoke_test.gd
```

The new test creates disposable **Alpha and Beta** local profiles, verifies required faculty lock, shop exclusivity, ESC and mouse capture, persistent independent coin/XP ledgers, nonpersistent deliveries and NPC state, and retried reward idempotency. It deliberately simulates an unwritable ConfigFile path to verify failed purchases, credit, once-only quests and boosters do not mutate the state. The existing large Godot CI suite runs as well.

## Limitations

- This does **not** redesign the game economy or add new narrative content.
- ConfigFile is a local filesystem mechanism. A successful save call is not a crash-proof, transactional database guarantee; the changes narrow failure windows and handle immediate write errors, but cannot protect against every filesystem/power-loss event.
- M10 microphone presentation, M12 local admin controls, M13 wardrobe and other parallel branches are not merged by this patch. Their modal boundaries should be verified again when the common integration branch accepts them.
