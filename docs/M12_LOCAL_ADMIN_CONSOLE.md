# M12 — Local Admin Console / 本机管理员控制台

**Integration status:** developed against current `main`, subject to GitHub Actions and Windows GUI acceptance before deployment. This guide describes a local offline owner function, not remote server administration.

## Player-facing control

Sign into a local NUS-3D game profile and open **F12 / Admin** (or press the account-strip Admin button). Other game buttons, the LAN/settings panel, and GPT responses do not grant admin permissions. The player must enter the separate admin-owner password each time this panel opens.

The console includes:
- **Weather**: choose one of the 5 existing weather modes. Changes are in-game effects, not a real-time weather service.
- **Lighting**: choose daylight, golden hour, blue hour, evening. This changes existing Godot lighting presets, **not** a real-world clock.
- **Restore atmosphere**: set weather + lighting to defaults.
- **XP grant**: add 1–5,000 XP to the signed-in *local* profile, tracked using the existing one-time reward ledger.
- **Coin grant**: add 1–5,000 in-game coins to the signed-in *local* profile. Existing wallet limits and persistent saves still apply.
- **Safe teleport**: jump to one of the four established UTown route checkpoints, with existing player reset/indoor-exit logic.
- **Audit trail**: inspect the latest 100 local administration actions (UTC timestamp, owner account ID, action, before/after and scope).
- **Session lock**: closing the console, switching accounts or logging out revokes the administrator session.

**Optional GPT proposal-only control:** after unlocking F12, you may type a short natural-language change request and press **Suggest with GPT**. The game sends **only your typed request** (not user identities, XP, mail, saves or password) through the optional locally started Python bridge (`python tools/campus_ai_bridge.py`). A separate `admin_plan` prompt constrains GPT to proposing a JSON object with one allowlisted action and integer value. The Godot client parses and bounds that result independently. A **second, explicit in-game confirmation is mandatory** before the already-authorized `AdminAuthority.apply()` is invoked. GPT cannot execute an operation by itself. Invalid, unrecognized, out-of-bounds and unsupported proposals are rejected without any changes. This path needs a locally configured OpenAI API key, may be billed separately, and can fail offline; all manual buttons continue working.

No arbitrary GDScript, shell command, game asset modification, API call, NUS SSO access, NPC identity editing, changing other players' saves or network-side administration is exposed. The game remains an unofficial comedy title.

## Owner setup — no built-in admin password

Creating the first local account does **not** automatically make it administrator. Explicit authorization is required. No username such as `admin` or `root` works by default.

On the intended owner's own Windows computer, choose a strong password (12–128 characters) and set it as a **temporary launch environment variable**, then launch the game from the **same PowerShell process**. Example:

~~~powershell
$env:NUS3D_ADMIN_BOOTSTRAP_PASSWORD = "choose-your-own-long-random-password"
& ".\NUS3D-UTown.exe"
~~~

Inside the game: sign in to the local game account that should own this installation, press **F12**, and enter the same password to enroll that profile. The owner mapping and salted PBKDF2-HMAC-SHA256 verifier are written to the game's **local user data** folder. The plaintext password is not written to the game's repository or local account index. Clear the launch environment variable after setup or restart the game from a normal launcher.

After one-time enrollment, only the selected local profile can unlock the panel with that password. Other profiles cannot enroll a second owner. Four incorrect unlock attempts introduce a 30-second session backoff; closing the panel does **not** reset it. The console never accepts an unconfigured password or auto-unlocks based only on username.

> This is a *local, developer/admin convenience feature*, not an online account/host authorization system. Someone with full operating-system access to the game's files and process can override local defenses. Protect the local machine and avoid distributing a globally preconfigured password.

## Data safety and permission boundary

- Game profile permission is checked **server-side of the UI**, inside `NUS3DAdminAuthority.apply`, not just by hiding buttons. Only six named actions are permitted and integer ranges are enforced before any mutation.
- The password verifier and owner ID are stored in `user://nus3d/admin_owner.json` by the existing profile store's atomic JSON writer; admin actions in `user://nus3d/admin_actions.json`, limited to 100 entries.
- XP grants write through `NUS3DAccountStore.award_once`, preserving normal progression and duplicate-reward protection. Coin grants reuse `UTownCoins.credit` with the game's maximum-wallet limit; neither action erases normal quest achievement ledgers.
- Rewards are additive, not arbitrary progress resets. **There is no automatic undo of XP/coins**. Use a backed-up offline profile if deliberate rollback is needed.
- Weather/time controls reuse existing `set_mode` and `set_lighting_mode` functions. Safe teleports reuse `reset_player` and known route points instead of setting uncontrolled coordinates.
- Optional LAN multiplayer: the admin service **refuses any world/save-changing action while the session is HOST, CONNECTING or CLIENT**, based on the existing network overlay's state. This is not an RPC privilege escalation or a replacement for host-authoritative server permissions.
- Campus AI / GPT responses are untrusted text: they **cannot call these methods** or become a privileged admin. API bridge and admin console remain entirely separate.

## Dependency, testing and release criteria

The integration was ported explicitly to the latest `main`. The separate Campus AI PR #30 and older PR #36 are **not merged or overwritten** by this change. The optional GPT proposal runs through the local bridge script included here; the standalone Campus AI chat screen remains separate work.

- Offline smoke test: `godot --headless --path godot --script res://tests/admin_console_smoke_test.gd`.
- Verify explicit enrollment, no default owner, incorrect password rejection, per-profile isolation, refusal of unknown actions and out-of-range numbers, persistence of XP/coins, weather/lighting, audit, modal pause/resume and logout revocation.
- Validate real Windows 1280×720 UI, Focus, Escape/F12 and touchscreen/gamepad edge cases before acceptance. Godot headless tests cannot certify the GPU/GUI experience.
- Integrate safely alongside other active branches: professional exams **F8**, UI sound **F9**, multiplayer/graphics **F11**, administrator **F12**. Do not reuse key bindings.
- Do not put real passwords into GitHub files, issues, CI logs or samples.

**Sources:** [NUS-3D main](https://github.com/stloendays/NUS-3D/tree/main) · [prior owner draft PR #36](https://github.com/stloendays/NUS-3D/pull/36) · [Campus AI PR #30](https://github.com/stloendays/NUS-3D/pull/30).
