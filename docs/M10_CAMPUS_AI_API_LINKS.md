# M10 — Campus AI, external links and opt-in network APIs

**Status:** isolated feature branch; not merged into main. Updated 2026-11-19.

This optional bilingual module fits the existing account shell and its reserved F11 Campus AI Hub entry. It does not change the 3D world, quests, NPC combat, XP, local passwords, save structure, or mailbox.

## New functionality

| Feature | What players can do | Network boundary |
| --- | --- | --- |
| Campus AI Hub | Open with F11 or the Campus AI button after local login; Esc closes | No automatic network |
| Offline demo | Ask for deterministic study hints and DDL jokes | Fully offline |
| OpenAI GPT | Ask a campus helper, fictional study coach, or funny NPC | Explicit local bridge POST only |
| Gemini and Claude | Same UI and optional providers | Explicit local bridge POST only |
| Weather | Read temperature and humidity near UTown | Open-Meteo HTTPS GET on click only |
| 10 links | ChatGPT, Claude, Gemini, Perplexity, OpenAI docs, NUS campus map, campus shuttle info, NUSMods, NUS website, GitHub issues | Default browser opens on click only |

### Setup on Windows (PowerShell)

Install Python 3.10+ and open a terminal in your NUS-3D repository directory.
Only configure the providers you want to use; each provider may charge fees.

~~~powershell
# Never commit API keys, screenshots of keys, or a .env with keys.
$env:OPENAI_API_KEY = "your-own-openai-api-key"
$env:NUS3D_OPENAI_MODEL = "gpt-4o-mini"

# Optional alternatives:
# $env:GEMINI_API_KEY = "your-gemini-api-key"
# $env:ANTHROPIC_API_KEY = "your-anthropic-api-key"

python tools/campus_ai_bridge.py
~~~

Then launch NUS-3D, sign in to a local game account, press F11, select the provider, type a question (max 900 characters), and click Ask AI. The server runs only at http://127.0.0.1:8765. Press Ctrl+C in the terminal to stop it. The game does not automatically launch or install the bridge.

To check the bridge without sending anything to a paid provider:

~~~powershell
Invoke-RestMethod http://127.0.0.1:8765/health
~~~

The health response exposes only booleans showing which provider keys have been configured, not the keys themselves.

**OpenAI API usage is separate from a ChatGPT subscription.** Players need their own credentials and provider quota; the game must never bundle a developer-paid shared API key in the exported EXE/PCK/ZIP.

### Privacy and security

- The optional bridge uses only the Python standard library and listens strictly on loopback (127.0.0.1), never an externally reachable address.
- The game never sends game usernames, password hashes, XP, coins, local mail, coursework save contents, or academic transcripts.
- If players submit a paid AI request, the **prompt and up to six prior session messages do leave the device** for the chosen provider. Do not paste personal or sensitive data. Provider billing and privacy terms apply.
- All network requests are user-triggered. Chat history is in memory only and is cleared on logout. Provider keys are environment variables in the bridge terminal only.
- The bridge requires JSON and a custom game header, denies browser Origin requests, enables no CORS, caps payload size and rates (12 per minute) and never exposes arbitrary outbound proxy URLs.
- External websites are explicitly allowlisted. The game never opens a URL until a player clicks Open selected website; schemes such as file:// and plain HTTP are forbidden.
- The weather button uses a fixed approximate UTown coordinate, not the player's location, and never changes in-game weather.
- AI answers are not authoritative university guidance. The game remains an unofficial comedic NUS-inspired simulation.

### Integration boundaries

PR #20 already reserved the F11 Campus AI Hub in the existing paused local-account shell. This feature supplies that missing hub component without editing main.tscn or modifying NPC, coursework, coins or player scripts. F11 and Close/Esc return to normal gameplay; menus remain protected during login, mail reading and modal faculty selection.

The existing Godot Windows export includes JSON files, and the runtime self-test now checks that the links catalog is packaged. The optional Python bridge is **not an embedded executable service** and requires a separately started local process to use paid providers.

### Automated testing

~~~powershell
python -m unittest discover -s tools -p "test_campus_ai_bridge.py" -v
godot --headless --path godot --import --quit
godot --headless --path godot --script res://tests/campus_ai_smoke_test.gd
~~~

The Python tests use mocked responses, not real API calls, and cover provider mapping, input validation, rate limiting, localhost HTTP request headers, and link URL safety. The Godot smoke tests the catalog, offline demo, opening/closing pause state, and account session cleanup. Existing Godot CI must pass before merge.

**Pending review:** desktop GUI sizing and Chinese/English font checks, actual provider-key integration with rate/quota caps, Windows packaged runtime and main-branch merge reconciliation. Successful headless tests alone are not proof of real GPU/GUI behavior.

### Official technical references

- OpenAI Responses API: https://platform.openai.com/docs/api-reference/responses
- Gemini API: https://ai.google.dev/gemini-api/docs
- Anthropic Messages API: https://docs.anthropic.com/en/api/messages
- Open-Meteo API: https://open-meteo.com/en/docs
- Godot HTTPRequest: https://docs.godotengine.org/en/4.4/classes/class_httprequest.html

## Current main integration

The original bridge and URL registry were already brought into current main with the local admin integration (#44). This follow-up adds only the optional F11 UI, account pause/session guards, dedicated headless AI UI regression and exported-link contract; it **does not overwrite** the newer `tools/campus_ai_bridge.py` or its security tests. F12 local administrator controls remain independent. External AI calls require a separately run localhost bridge with environment-provided provider keys and an explicit user action; the offline demo does not use a paid API.
