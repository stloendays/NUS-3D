#!/usr/bin/env python3
"""NUS-3D optional local-only AI and weather bridge.

No secrets ship in the game. The bridge listens only on 127.0.0.1 and only
accepts manual, small requests. It never reads user:// profiles or game saves.
Python 3.10+; no third-party Python dependencies.
"""
from __future__ import annotations

import json
import os
import re
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

HOST = "127.0.0.1"
PORT = 8765
MAX_REQUEST_BYTES = 16_384
MAX_REPLY_BYTES = 160_000
MAX_USER_CHARS = 1_200
MAX_HISTORY = 8
CHAT_COOLDOWN_SECONDS = 1.5

SYSTEM_INSTRUCTIONS = (
    "You are Campus Buddy, a lighthearted fictional study partner inside "
    "NUS-3D, an unofficial comedy video game. Reply in the user's language "
    "with a concise, helpful answer, optionally one gentle campus-themed joke. "
    "Never claim to be NUS staff or have real student records, exam answers, "
    "bus arrival data, or the ability to change XP or quests. Avoid pretending "
    "to have used tools or accessed the player's account. "
    "Do not request personal passwords or API keys."
)

PROVIDERS = {
    "openai": {
        "key_env": "OPENAI_API_KEY",
        "model_env": "NUS3D_OPENAI_MODEL",
        "default_model": "gpt-4.1-mini",
    },
    "gemini": {
        "key_env": "GEMINI_API_KEY",
        "model_env": "NUS3D_GEMINI_MODEL",
        "default_model": "gemini-2.5-flash",
    },
    "claude": {
        "key_env": "ANTHROPIC_API_KEY",
        "model_env": "NUS3D_CLAUDE_MODEL",
        "default_model": "claude-haiku-4-5-20251001",
    },
}

_weather_url = (
    "https://api.open-meteo.com/v1/forecast"
    "?latitude=1.3050&longitude=103.7732"
    "&current=temperature_2m,relative_humidity_2m,precipitation,weather_code"
    "&timezone=Asia%2FSingapore"
)
_chat_lock = threading.Lock()
_last_chat_at = 0.0


class InputError(Exception):
    pass


class ProviderError(Exception):
    pass


def _model_name(provider: str) -> str:
    cfg = PROVIDERS[provider]
    model = os.environ.get(cfg["model_env"], cfg["default_model"]).strip()
    if re.fullmatch(r"[a-zA-Z0-9._-]{1,90}", model) is None:
        raise ProviderError("Invalid server model setting; check NUS3D_*_MODEL.")
    return model


def validate_chat(payload: object) -> tuple[str, list[dict[str, str]]]:
    """Only the prompt and bounded prior chat text can go to an AI provider."""
    if not isinstance(payload, dict):
        raise InputError("Expected a JSON object.")
    provider = payload.get("provider", "openai")
    if not isinstance(provider, str) or provider not in PROVIDERS:
        raise InputError("Unsupported provider.")
    prompt = payload.get("message")
    if not isinstance(prompt, str) or not prompt.strip() or len(prompt) > MAX_USER_CHARS:
        raise InputError("Message must contain 1 to 1200 characters.")
    history = payload.get("history", [])
    if not isinstance(history, list) or len(history) > MAX_HISTORY:
        raise InputError("History must contain at most eight messages.")
    messages: list[dict[str, str]] = []
    for item in history:
        if not isinstance(item, dict) or item.get("role") not in ("user", "assistant"):
            raise InputError("Invalid history role.")
        content = item.get("content")
        if not isinstance(content, str) or len(content) > MAX_USER_CHARS:
            raise InputError("Invalid history content.")
        if content.strip():
            messages.append({"role": item["role"], "content": content.strip()})
    messages.append({"role": "user", "content": prompt.strip()})
    return provider, messages


def make_upstream_request(
    provider: str, messages: list[dict[str, str]]
) -> tuple[str, dict[str, str], dict]:
    cfg = PROVIDERS[provider]
    api_key = os.environ.get(cfg["key_env"], "").strip()
    if not api_key:
        raise ProviderError(
            "Provider not configured. Set " + cfg["key_env"] + " on the local bridge."
        )
    model = _model_name(provider)
    headers = {"Content-Type": "application/json", "Accept": "application/json"}
    if provider == "openai":
        headers["Authorization"] = "Bearer " + api_key
        url = "https://api.openai.com/v1/responses"
        body = {
            "model": model,
            "instructions": SYSTEM_INSTRUCTIONS,
            "input": messages,
            "max_output_tokens": 400,
            "store": False,
        }
    elif provider == "gemini":
        headers["x-goog-api-key"] = api_key
        url = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            + model
            + ":generateContent"
        )
        body = {
            "systemInstruction": {"parts": [{"text": SYSTEM_INSTRUCTIONS}]},
            "contents": [
                {
                    "role": "model" if entry["role"] == "assistant" else "user",
                    "parts": [{"text": entry["content"]}],
                }
                for entry in messages
            ],
            "generationConfig": {"maxOutputTokens": 400},
        }
    else:
        headers["x-api-key"] = api_key
        headers["anthropic-version"] = "2023-06-01"
        url = "https://api.anthropic.com/v1/messages"
        body = {
            "model": model,
            "system": SYSTEM_INSTRUCTIONS,
            "messages": messages,
            "max_tokens": 400,
        }
    return url, headers, body


def extract_reply(provider: str, response: object) -> str:
    if not isinstance(response, dict):
        raise ProviderError("AI provider returned an unexpected response.")
    parts: list[str] = []
    if provider == "openai":
        if isinstance(response.get("output_text"), str):
            parts.append(response["output_text"])
        for item in response.get("output", []):
            if isinstance(item, dict) and item.get("type") == "message":
                for block in item.get("content", []):
                    if isinstance(block, dict) and block.get("type") == "output_text":
                        if isinstance(block.get("text"), str):
                            parts.append(block["text"])
    elif provider == "gemini":
        for item in response.get("candidates", []):
            if isinstance(item, dict):
                content = item.get("content", {})
                if isinstance(content, dict):
                    for block in content.get("parts", []):
                        if isinstance(block, dict) and isinstance(block.get("text"), str):
                            parts.append(block["text"])
    else:
        for item in response.get("content", []):
            if isinstance(item, dict) and item.get("type") == "text":
                if isinstance(item.get("text"), str):
                    parts.append(item["text"])
    result = "\n".join(part.strip() for part in parts if part.strip()).strip()
    if not result:
        raise ProviderError("The AI provider returned no usable text.")
    return result[:5_000]


def _fetch_json(url: str, headers: dict[str, str], body: dict | None = None) -> dict:
    request = Request(
        url,
        data=json.dumps(body, ensure_ascii=False).encode("utf-8") if body else None,
        headers=headers,
        method="POST" if body is not None else "GET",
    )
    try:
        with urlopen(request, timeout=18) as response:
            payload = response.read(MAX_REPLY_BYTES + 1)
            if len(payload) > MAX_REPLY_BYTES:
                raise ProviderError("Upstream response exceeded the size limit.")
            parsed = json.loads(payload.decode("utf-8"))
            if not isinstance(parsed, dict):
                raise ProviderError("Unexpected upstream response format.")
            return parsed
    except HTTPError as exc:
        # Never relay upstream error bodies: they can contain prompt or key details.
        raise ProviderError("Upstream request failed (HTTP %s)." % exc.code) from None
    except (URLError, TimeoutError, OSError) as exc:
        raise ProviderError("Network unavailable or upstream timed out.") from None
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ProviderError("Upstream response was not valid JSON.") from None


def generate_reply(provider: str, messages: list[dict[str, str]]) -> str:
    url, headers, body = make_upstream_request(provider, messages)
    return extract_reply(provider, _fetch_json(url, headers, body))


def weather_snapshot() -> dict:
    current = _fetch_json(
        _weather_url,
        {"Accept": "application/json", "User-Agent": "NUS-3D-Unofficial/1.0"},
    ).get("current", {})
    if not isinstance(current, dict):
        raise ProviderError("Weather service supplied no current values.")
    result = {
        "location": "UTown, Singapore (fixed approximate reference)",
        "source": "Open-Meteo; indicative only",
    }
    for key in ("time", "temperature_2m", "relative_humidity_2m", "precipitation", "weather_code"):
        if isinstance(current.get(key), (int, float, str)):
            result[key] = current[key]
    return result


class Handler(BaseHTTPRequestHandler):
    server_version = "NUS3DLocalBridge/1.0"

    def log_message(self, fmt: str, *args: object) -> None:
        # No prompt bodies, chat histories or authorization headers in logs.
        print("[campus-ai] " + fmt % args)

    def _allowed_local_request(self) -> bool:
        host = self.headers.get("Host", "")
        allowed_hosts = {"127.0.0.1:%s" % PORT, "localhost:%s" % PORT}
        if host not in allowed_hosts or self.headers.get("Origin") is not None:
            self._send_json(403, {"error": "Local game requests only."})
            return False
        return True

    def _send_json(self, code: int, item: dict) -> None:
        data = json.dumps(item, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        if not self._allowed_local_request():
            return
        if self.path == "/v1/status":
            self._send_json(200, {
                "status": "local_only",
                "providers": {
                    name: bool(os.environ.get(cfg["key_env"], "").strip())
                    for name, cfg in PROVIDERS.items()
                },
                "weather": "manual_refresh_only",
            })
            return
        if self.path == "/v1/weather":
            try:
                self._send_json(200, weather_snapshot())
            except ProviderError as exc:
                self._send_json(502, {"error": str(exc)})
            return
        self._send_json(404, {"error": "Unknown route."})

    def do_POST(self) -> None:
        if not self._allowed_local_request():
            return
        if self.path != "/v1/chat":
            self._send_json(404, {"error": "Unknown route."})
            return
        if self.headers.get("Content-Type", "").split(";")[0].strip().lower() != "application/json":
            self._send_json(415, {"error": "Use application/json."})
            return
        try:
            length = int(self.headers.get("Content-Length", "-1"))
        except ValueError:
            length = -1
        if not 0 < length <= MAX_REQUEST_BYTES or self.headers.get("Transfer-Encoding"):
            self._send_json(413, {"error": "Request exceeds the size limit."})
            return
        try:
            provider, messages = validate_chat(
                json.loads(self.rfile.read(length).decode("utf-8"))
            )
        except (ValueError, UnicodeError, InputError) as exc:
            self._send_json(400, {"error": "Invalid chat request."})
            return

        # Rate limit on the local process, not on a player's identity.
        global _last_chat_at
        with _chat_lock:
            now = time.monotonic()
            if now - _last_chat_at < CHAT_COOLDOWN_SECONDS:
                self._send_json(429, {"error": "Please wait before sending another message."})
                return
            _last_chat_at = now

        try:
            answer = generate_reply(provider, messages)
            self._send_json(200, {"provider": provider, "reply": answer})
        except ProviderError as exc:
            self._send_json(502, {"error": str(exc)})


def main() -> None:
    print("NUS-3D Campus AI bridge: http://%s:%d (local device only)" % (HOST, PORT))
    print("Use environment variables for provider keys; never commit keys to GitHub.")
    print("Chat and weather make external requests only when clicked in the game.")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
