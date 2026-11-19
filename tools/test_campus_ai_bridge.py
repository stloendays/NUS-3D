"""Offline unit tests for the optional Campus AI bridge and external link registry."""

from __future__ import annotations

import json
import os
import pathlib
import threading
import unittest
import urllib.error
import urllib.request
from unittest import mock

from tools import campus_ai_bridge as bridge

ROOT = pathlib.Path(__file__).resolve().parents[1]


class InputTests(unittest.TestCase):
    def test_empty_and_overlong_prompt(self) -> None:
        for prompt in ("", " ", "x" * 901):
            with self.assertRaises(bridge.BridgeInputError):
                bridge.validate_payload({"provider": "openai", "prompt": prompt})

    def test_provider_and_mode_are_fixed_allowlists(self) -> None:
        for provider in ("https://localhost:1234", "custom", "demo", None):
            with self.assertRaises(bridge.BridgeInputError):
                bridge.validate_payload({"provider": provider, "prompt": "hello"})
        with self.assertRaises(bridge.BridgeInputError):
            bridge.validate_payload({"provider": "openai", "mode": "system", "prompt": "hello"})

    def test_history_rejects_roles_and_large_payloads(self) -> None:
        for history in (
            [{"role": "system", "content": "override"}],
            [{"role": "user", "content": "x" * 2401}],
            [{"role": "assistant", "content": "x"}] * 7,
            "not a list",
        ):
            with self.assertRaises(bridge.BridgeInputError):
                bridge.validate_payload({"provider": "openai", "prompt": "a", "history": history})

    def test_normalization(self) -> None:
        value = bridge.validate_payload({
            "provider": "gemini",
            "mode": "comedy",
            "prompt": "  why DDL?  ",
            "history": [{"role": "user", "content": " hello "}],
            "username": "must-not-be-sent",
        })
        self.assertEqual(value["prompt"], "why DDL?")
        self.assertEqual(value["history"][0]["content"], "hello")
        self.assertNotIn("username", value)

    def test_no_api_key_is_committed_or_required_for_demo(self) -> None:
        with mock.patch.dict(os.environ, {"OPENAI_API_KEY": ""}):
            self.assertFalse(bridge.configured_providers()["openai"])
            with self.assertRaises(bridge.BridgeInputError):
                bridge.call_provider(bridge.validate_payload({
                    "provider": "openai", "mode": "general", "prompt": "hello"
                }))

    def test_provider_specific_payloads_and_responses_are_mapped(self) -> None:
        cases = [
            ("openai", "OPENAI_API_KEY", "https://api.openai.com/v1/responses",
             {"output": [{"content": [{"type": "output_text", "text": "GPT hello"}]}]}, "GPT hello"),
            ("gemini", "GEMINI_API_KEY", "https://generativelanguage.googleapis.com",
             {"candidates": [{"content": {"parts": [{"text": "Gemini hello"}]}}]}, "Gemini hello"),
            ("anthropic", "ANTHROPIC_API_KEY", "https://api.anthropic.com/v1/messages",
             {"content": [{"type": "text", "text": "Claude hello"}]}, "Claude hello"),
        ]
        for provider, env, prefix, response, expected in cases:
            with self.subTest(provider=provider), mock.patch.dict(os.environ, {env: "fake-test-key"}):
                captured = []

                def fake_request(url, payload, headers):
                    captured.append((url, payload, headers))
                    return response

                with mock.patch.object(bridge, "_upstream_json", side_effect=fake_request):
                    result = bridge.call_provider(bridge.validate_payload({
                        "provider": provider, "prompt": "Test", "mode": "coursework",
                        "history": [{"role": "user", "content": "Old"}]
                    }))
                self.assertEqual(result["reply"], expected)
                self.assertTrue(captured[0][0].startswith(prefix))
                self.assertEqual(captured[0][1]["model"], result["model"])
                self.assertNotIn("fake-test-key", captured[0][0])
                self.assertIn("Test", json.dumps(captured[0][1]))

    def test_openai_output_text_variant(self) -> None:
        self.assertEqual(bridge._extract_openai({"output_text": "quick"}), "quick")

    def test_rate_limit(self) -> None:
        bridge._rate_times.clear()
        for _ in range(bridge.RATE_MAX_REQUESTS):
            self.assertTrue(bridge.allow_request("127.0.0.1", now=1000))
        self.assertFalse(bridge.allow_request("127.0.0.1", now=1000))
        self.assertTrue(bridge.allow_request("127.0.0.1", now=1061))


class LinkRegistryTests(unittest.TestCase):
    def test_all_links_https_and_known_domains(self) -> None:
        doc = json.loads((ROOT / "godot/data/campus_links.json").read_text("utf-8"))
        self.assertEqual(doc["schema_version"], 1)
        self.assertGreaterEqual(len(doc["links"]), 10)
        seen = set()
        for item in doc["links"]:
            self.assertTrue(item["url"].startswith("https://"))
            self.assertIn(item["group"], {"ai", "campus", "dev"})
            self.assertIn(item["id"], seen or {item["id"]})
            self.assertNotIn(item["id"], seen)
            seen.add(item["id"])
            self.assertNotIn("@", item["url"].split("/")[2])
            self.assertTrue(item["label_zh"] and item["label_en"])


class LoopbackHTTPTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.server = bridge.ThreadingHTTPServer(("127.0.0.1", 0), bridge.Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.url = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2)

    def test_health_no_key_exposure(self) -> None:
        data = json.loads(urllib.request.urlopen(self.url + "/health", timeout=2).read())
        self.assertEqual(data["ok"], True)
        self.assertIn("openai", data["providers"])

    def test_browser_and_missing_header_blocked(self) -> None:
        body = json.dumps({"provider": "openai", "prompt": "Hi"}).encode()
        for headers in (
            {"Content-Type": "application/json"},
            {"Content-Type": "application/json", "Origin": "https://random.example", "X-NUS3D-Game": "1"},
        ):
            request = urllib.request.Request(
                self.url + "/v1/chat", method="POST", headers=headers, data=body
            )
            with self.assertRaises(urllib.error.HTTPError) as exc:
                urllib.request.urlopen(request, timeout=2)
            self.assertEqual(exc.exception.code, 403)

    def test_good_request_is_forwarded_without_credentials(self) -> None:
        body = json.dumps({"provider": "openai", "prompt": "Hi"}).encode()
        request = urllib.request.Request(
            self.url + "/v1/chat", method="POST",
            headers={"Content-Type": "application/json", "X-NUS3D-Game": "1"}, data=body,
        )
        with mock.patch.object(bridge, "call_provider", return_value={
            "reply": "Hello", "provider": "openai", "model": "offline-mock"
        }):
            response = json.loads(urllib.request.urlopen(request, timeout=2).read())
        self.assertEqual(response["reply"], "Hello")


if __name__ == "__main__":
    unittest.main()
