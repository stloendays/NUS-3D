# M5.2 — Flat campus-comedy startup and mailbox

This is a **visual-only** branch stacked on the M5–M11 integration branch (PR #20). It does not change local account identities, password storage, per-account saves, XP thresholds, reward deduplication, or mail routing.

## Art direction

Reference: accessible, readable, playful low-detail social-game UI, not a copied character or interface from Goose Goose Duck.

- Palette: ink **#30333B**, cream **#FFF9ED**, campus blue **#98C9DE**, grass green **#B4D494**, button yellow **#F7CA55**.
- Original hand-drawn Godot CanvasItem backdrop: campus building shapes, grass, clouds, one cartoon student buried in DDL pages, coffee. **No generated 3D menu scene, video, internet imagery or packaged high-resolution textures**.
- One account card on the right on desktop; centered on smaller windows. Username, masked password, one primary yellow submit button, secondary registration, small tutorial/language row and sound shortcut. Existing Chinese/English translation service remains.
- Mail remains the same offline Campus Post, with simpler white paper cards, two-column message reader and original Inbox/Sent/Compose actions.
- Compact, flat top profile card: XP and unread count, mail shortcut and logout. F9 sound and F10 language remain available without permanent toolbar clutter.

## Isolation and performance

The startup is a separately paused interface above the existing main world. Artwork ignores mouse input and redraws on resizing only. This change does **not** call registration, achievements, network APIs, saved game writes, or external mail servers.

**No genuine NUS SSO, Google login, or real internet email.** This is an unofficial fictional game.

## QA

Run from the repository root:

```sh
godot --headless --path godot --import --quit
godot --headless --path godot --script res://tests/cartoon_shell_smoke_test.gd
godot --headless --path godot --script res://tests/account_smoke_test.gd
godot --headless --path godot --script res://tests/integration_smoke_test.gd
```

The normal GitHub CI includes the new smoke test, then existing account/gameplay regression and Windows packaging checks. Visually verify the startup card at 1280×720 and a narrower window, Chinese text rendering, focus/Enter-to-login, J to open and close mail, F9 and F10, and a full logout/login cycle before merging. CI headless checks are not a substitute for the GUI review.
