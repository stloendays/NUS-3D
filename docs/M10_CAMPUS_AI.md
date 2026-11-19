# M10 — Campus AI, external links, and optional API connectivity

Status (2026-11-19): feature branch, not yet merged or verified in Windows GUI.

## Features

- F11 or the Campus AI account-strip button opens an English/Chinese online-tools panel. F11 is chosen to avoid the multiplayer/graphics branch's F8 shortcut.
- Ten reviewed HTTPS shortcuts: ChatGPT, Claude, Gemini, Perplexity, OpenAI developer documentation, official NUS map, NUS shuttle information, NUSMods, NUS official website and NUS-3D issue reporting.
- One-click Open-Meteo weather using *fixed approximate* UTown coordinates, not user GPS. This does not change the game's weather.
- An offline demo assistant for fictional deadline jokes and study tips; no API key, payment or internet necessary.
- Optional real text chat using OpenAI GPT, Google Gemini or Anthropic Claude. Choose campus helper, study coach or funny NPC personas.
- The world pauses while the panel is open. Logout clears the non-persistent chat. No game account, mail, XP, passwords, grades or saved coursework are sent to AI automatically.

## Start an optional paid-provider bridge

Python 3.10+ required. Run the bridge manually from the repository root. Provider API access is **not** included with website subscriptions; providers may bill for API usage. The game EXE never contains provider credentials.

Windows PowerShell:

~~~powershell
$env:OPENAI_API_KEY = "<your-api-key>"
# Or additionally:
# $env:GEMINI_API_KEY = "<your-gemini-key>"
# $env:ANTHROPIC_API_KEY = "<your-anthropic-key>"
python tools/campus_ai_bridge.py
~~~

macOS/Linux:

~~~sh
export OPENAI_API_KEY="<your-api-key>"
python3 tools/campus_ai_bridge.py
~~~

Optional server model overrides: NUS3D_OPENAI_MODEL (default gpt-4o-mini), NUS3D_GEMINI_MODEL (gemini-2.5-flash), NUS3D_ANTHROPIC_MODEL (claude-haiku-4-5-20251001). Model access and identifiers may change; choose models available in your provider account. Do not commit API keys or include real keys in logs, screenshots or shared notes.

## API and security

- Local endpoint: POST http://127.0.0.1:8765/v1/chat with JSON provider, mode, prompt and bounded chat history; GET /health exposes availability only.
- Upstream provider endpoints and credentials are fixed *server-side*. No arbitrary URL, game save or NUS login is forwarded. The bridge binds only to loopback; it rejects browser Origin requests and requires a game-specific request header.
- Guardrails: 900-character prompt, 6 history messages, 2,400-character reply, 9 KB request, rate cap 12 requests/minute, upstream timeout. AI chat is sent **only when Ask AI is clicked**.
- This is a local convenience bridge, **not strong authentication against hostile software running on the same computer**. Do not expose the port to the internet or run on shared/untrusted machines with paid provider keys.
- AI may be incorrect. External providers have independent privacy and retention terms. Never submit sensitive student records, secrets or private mail.
- Site shortcuts are restricted to exact HTTPS hosts in the game source; they open **only on click** using the default browser, with no login or game data automatically transferred.
- Open-Meteo uses fixed NUS vicinity coordinates and is only requested upon user action. NUS official sites are informational links; the game contains no real timetable, university SSO or exam API.

## Verification

Commands for isolated offline tests:

~~~sh
python -m unittest tools.test_campus_ai_bridge -v
godot --headless --path godot --import --quit
godot --headless --path godot --script res://tests/campus_ai_smoke_test.gd
~~~

Check the linked CI results and manually validate 1280×720/1920×1080 Windows GUI, focus/keyboard handling, button layout and link launching before merging. These tests do **not** prove live paid-provider availability. This branch is stacked on the PR #20 integration code and must not be merged independently into main without reconciliation with live multiplayer, oral-presentation and UI work.

Reference documents: [OpenAI Responses API](https://platform.openai.com/docs/api-reference/responses), [Gemini API](https://ai.google.dev/gemini-api/docs), [Anthropic API](https://docs.anthropic.com/en/api/messages), [Open-Meteo API](https://open-meteo.com/en/docs).
