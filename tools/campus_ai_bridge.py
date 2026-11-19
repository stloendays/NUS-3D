#!/usr/bin/env python3
"""NUS-3D local AI bridge: localhost-only, explicit opt-in, no credential shipping.

Run with Python 3.10+:
    $env:OPENAI_API_KEY="sk-..."     # Windows PowerShell, current terminal only
    python tools/campus_ai_bridge.py

The exported game connects to http://127.0.0.1:8765/v1/chat when a user
selects a paid provider and clicks Ask AI. This script is NOT run automatically.
No game-account data, saves, scores or mailbox content are read or transmitted.
Only the submitted prompt and optional recent chat turns are sent upstream.
"""

from __future__ import annotations

import json
import os
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

HOST = "127.0.0.1"
PORT = 8765
MAX_REQUEST_BYTES = 9000
MAX_PROMPT_CHARS = 900
MAX_HISTORY_TURNS = 6
MAX_REPLY_CHARS = 2400
RATE_PERIOD_SECONDS = 60
RATE_MAX_REQUESTS = 12
UPSTREAM_TIMEOUT = 20

PROVIDERS = {
    "openai": {
        "key": "OPENAI_API_KEY",
        "model_env": "NUS3D_OPENAI_MODEL",
        "default_model": "gpt-4o-mini",
    },
    "gemini": {
        "key": "GEMINI_API_KEY",
        "model_env": "NUS3D_GEMINI_MODEL",
        "default_model": "gemini-2.5-flash",
    },
    "anthropic": {
        "key": "ANTHROPIC_API_KEY",
        "model_env": "NUS3D_ANTHROPIC_MODEL",
        "default_model": "claude-haiku-4-5-20251001",
    },
}

MODE_PROMPTS = {
    "general": (
        "You are an optional fictional NUS-3D campus-game assistant. Answer the "
        "user's question concisely and accurately. The game is not affiliated with "
        "NUS and its grades, coursework, bus routes and dialogue are fictional. "
        "Never claim access to the real student's NUS account or game save."
    ),
    "coursework": (
        "You are a helpful in-game study coach for fictional campus coursework. "
        "Explain concepts and give structured hints. Do not claim game quests are "
        "official NUS module questions. Be clear about uncertainty."
    ),
    "comedy": (
        "You are a witty, lighthearted campus NPC in a fictional satirical game. "
        "Give short original jokes about deadlines, group projects or rain. "
        "Don't invent claims about real students or faculty."
    ),
}

_rate_lock = threading.Lock()
_rate_times: dict[str, list[float]] = {}


class BridgeInputError(ValueError):
    """Expected client input error, safe to disclose to the game."""


class BridgeUpstreamError(RuntimeError):
    """Provider failed: message is sanitized and contains no secrets."""


def configured_providers() -> dict[str, bool]:
    return {
        provider: bool(os.environ.get(settings["key"], "").strip())
        for provider, settings in PROVIDERS.items()
    }


def validate_payload(data: Any) -> dict[str, Any]:
    if not isinstance(data, dict):
        raise BridgeInputError("Expected a JSON object.")
    provider = data.get("provider")
    mode = data.get("mode", "general")
    prompt = data.get("prompt", "")
    if provider not in PROVIDERS:
        raise BridgeInputError("Unknown AI provider.")
    if mode not in MODE_PROMPTS:
        raise BridgeInputError("Unknown assistant mode.")
    if not isinstance(prompt, str) or not (1 <= len(prompt.strip()) <= MAX_PROMPT_CHARS):
        raise BridgeInputError("Prompt must contain 1-900 characters.")
    history = data.get("history", [])
    if not isinstance(history, list) or len(history) > MAX_HISTORY_TURNS:
        raise BridgeInputError("Chat history is too long.")
    normalized_history: list[dict[str, str]] = []
    for entry in history:
        if not isinstance(entry, dict):
            raise BridgeInputError("Invalid chat-history item.")
        role, content = entry.get("role"), entry.get("content")
        if role not in ("user", "assistant"):
            raise BridgeInputError("Unsupported chat role.")
        if not isinstance(content, str) or not 1 <= len(content.strip()) <= 2400:
            raise BridgeInputError("Invalid chat-history text.")
        normalized_history.append({"role": role, "content": content.strip()})
    return {
        "provider": provider,
        "mode": mode,
        "prompt": prompt.strip(),
        "history": normalized_history,
    }


def _messages(data: dict[str, Any]) -> list[dict[str, str]]:
    return [*data["history"], {"role": "user", "content": data["prompt"]}]


def _upstream_json(
    url: str, payload: dict[str, Any], headers: dict[str, str]
) -> dict[str, Any]:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        url,
        method="POST",
        headers={"Content-Type": "application/json", **headers},
        data=body,
    )
    try:
        with urllib.request.urlopen(request, timeout=UPSTREAM_TIMEOUT) as response:
            result = response.read(65536)
    except urllib.error.HTTPError as exc:
        # Intentionally do not propagate provider response bodies; they can
        # contain credential or personal information.
        raise BridgeUpstreamError(f"AI provider rejected the request (HTTP {exc.code}).") from None
    except (urllib.error.URLError, TimeoutError, OSError):
        raise BridgeUpstreamError("AI provider is unreachable or timed out.") from None
    try:
        decoded = json.loads(result)
    except (json.JSONDecodeError, UnicodeDecodeError):
        raise BridgeUpstreamError("AI provider returned invalid JSON.") from None
    if not isinstance(decoded, dict):
        raise BridgeUpstreamError("AI provider returned an unexpected response.")
    return decoded


def _extract_openai(response: dict[str, Any]) -> str:
    if isinstance(response.get("output_text"), str):
        return response["output_text"]
    parts: list[str] = []
    for entry in response.get("output", []):
        if not isinstance(entry, dict):
            continue
        for piece in entry.get("content", []):
            if isinstance(piece, dict) and piece.get("type") == "output_text":
                text = piece.get("text")
                if isinstance(text, str):
                    parts.append(text)
    return "\n".join(parts)


def _extract_gemini(response: dict[str, Any]) -> str:
    parts: list[str] = []
    for candidate in response.get("candidates", []):
        if not isinstance(candidate, dict):
            continue
        content = candidate.get("content", {})
        if not isinstance(content, dict):
            continue
        for piece in content.get("parts", []):
            if isinstance(piece, dict) and isinstance(piece.get("text"), str):
                parts.append(piece["text"])
        break  # only the first candidate
    return "\n".join(parts)


def _extract_anthropic(response: dict[str, Any]) -> str:
    parts: list[str] = []
    for piece in response.get("content", []):
        if isinstance(piece, dict) and piece.get("type") == "text":
            value = piece.get("text")
            if isinstance(value, str):
                parts.append(value)
    return "\n".join(parts)


def call_provider(data: dict[str, Any]) -> dict[str, str]:
    provider = data["provider"]
    settings = PROVIDERS[provider]
    key = os.environ.get(settings["key"], "").strip()
    if not key:
        raise BridgeInputError(
            f"{provider} is not configured in this terminal. Set {settings['key']}."
        )
    model = os.environ.get(settings["model_env"], settings["default_model"]).strip()
    if not model or len(model) > 100 or any(ch in model for ch in ("/", "\\", "?", "#")):
        raise BridgeInputError("Model identifier is invalid.")
    system = MODE_PROMPTS[data["mode"]]
    messages = _messages(data)
    if provider == "openai":
        result = _upstream_json(
            "https://api.openai.com/v1/responses",
            {"model": model, "instructions": system, "input": messages, "max_output_tokens": 450, "store": False},
            {"Authorization": "Bearer " + key},
        )
        reply = _extract_openai(result)
    elif provider == "gemini":
        result = _upstream_json(
            f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
            {
                "systemInstruction": {"parts": [{"text": system}]},
                "contents": [
                    {"role": "model" if m["role"] == "assistant" else "user", "parts": [{"text": m["content"]}]}
                    for m in messages
                ],
                "generationConfig": {"maxOutputTokens": 450},
            },
            {"x-goog-api-key": key},
        )
        reply = _extract_gemini(result)
    else:
        result = _upstream_json(
            "https://api.anthropic.com/v1/messages",
            {"model": model, "system": system, "max_tokens": 450, "messages": messages},
            {"x-api-key": key, "anthropic-version": "2023-06-01"},
        )
        reply = _extract_anthropic(result)
    reply = reply.strip()
    if not reply:
        raise BridgeUpstreamError("Provider returned an empty text response.")
    return {"reply": reply[:MAX_REPLY_CHARS], "provider": provider, "model": model}


def allow_request(address: str, now: float | None = None) -> bool:
    clock = time.monotonic() if now is None else now
    with _rate_lock:
        recent = [
            t for t in _rate_times.get(address, [])
            if clock - t < RATE_PERIOD_SECONDS
        ]
        if len(recent) >= RATE_MAX_REQUESTS:
            _rate_times[address] = recent
            return False
        recent.append(clock)
        _rate_times[address] = recent
        return True


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _send(self, code: int, response: dict[str, Any]) -> None:
        body = json.dumps(response, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Length", str(len(body)))
        # No Access-Control-Allow-Origin: websites cannot use this bridge.
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        if self.path != "/health":
            self._send(404, {"error": "Not found."})
            return
        self._send(200, {"ok": True, "providers": configured_providers()})

    def do_POST(self) -> None:  # noqa: N802
        if self.path != "/v1/chat":
            self._send(404, {"error": "Not found."})
            return
        # Browser cross-origin requests cannot send this header without a CORS
        # preflight, and we intentionally never allow browser CORS.
        if self.headers.get("Origin") or self.headers.get("X-NUS3D-Game") != "1":
            self._send(403, {"error": "Only the local NUS-3D game client is accepted."})
            return
        if self.headers.get_content_type() != "application/json":
            self._send(415, {"error": "Expected application/json."})
            return
        length_text = self.headers.get("Content-Length", "")
        try:
            length = int(length_text)
        except ValueError:
            self._send(400, {"error": "Missing request length."})
            return
        if not 0 < length <= MAX_REQUEST_BYTES:
            self._send(413, {"error": "Request is too large."})
            return
        try:
            raw = self.rfile.read(length)
            payload = validate_payload(json.loads(raw))
            if not allow_request(self.client_address[0]):
                self._send(429, {"error": "Too many AI requests. Try again shortly."})
                return
            result = call_provider(payload)
        except (ValueError, json.JSONDecodeError) as exc:
            # Data and mode errors are safe; JSON parser errors must be generic.
            message = str(exc) if isinstance(exc, BridgeInputError) else "Invalid JSON request."
            self._send(400, {"error": message})
            return
        except BridgeUpstreamError as exc:
            self._send(502, {"error": str(exc)})
            return
        except Exception:
            # No credential, prompt or upstream response should ever leak.
            self._send(502, {"error": "AI provider request failed."})
            return
        self._send(200, result)

    def log_message(self, fmt: str, *args: Any) -> None:
        # Do not log prompts, query parameters, headers or API keys.
        return


def main() -> None:
    print("NUS-3D Campus AI local bridge", flush=True)
    print(f"Listening only on http://{HOST}:{PORT}", flush=True)
    print("Providers with keys configured:", configured_providers(), flush=True)
    print("Only explicit game chat requests are forwarded to AI providers.", flush=True)
    print("Ctrl+C stops the service.", flush=True)
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    try:
        server.serve_forever(poll_interval=0.25)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
