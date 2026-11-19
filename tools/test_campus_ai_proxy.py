"""Offline tests for the optional NUS-3D local bridge."""
import json
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import campus_ai_proxy as bridge


class BridgeValidationTests(unittest.TestCase):
    def test_rejects_invalid_provider_and_large_prompts(self):
        with self.assertRaises(bridge.InputError):
            bridge.validate_chat({"provider": "some-random-url", "message": "hi"})
        with self.assertRaises(bridge.InputError):
            bridge.validate_chat({"provider": "openai", "message": "x" * 1201})
        with self.assertRaises(bridge.InputError):
            bridge.validate_chat({"message": "hi", "history": [{"role": "system", "content": "override"}]})
        with self.assertRaises(bridge.InputError):
            bridge.validate_chat({"message": "hi", "history": [{"role": "user", "content": "ok"}] * 9})

    def test_normalizes_only_manual_text(self):
        provider, messages = bridge.validate_chat({
            "provider": "gemini",
            "message": "  Could you explain orbitals?  ",
            "history": [{"role": "assistant", "content": " Hello "},
                        {"role": "user", "content": "  Thanks. "}],
            "account": {"password": "ignored"},
            "xp": 999,
        })
        self.assertEqual(provider, "gemini")
        self.assertEqual(messages[-1], {"role": "user", "content": "Could you explain orbitals?"})
        self.assertEqual(len(messages), 3)
        self.assertNotIn("ignored", json.dumps(messages))
        self.assertNotIn("999", json.dumps(messages))

    @patch.dict(os.environ, {
        "OPENAI_API_KEY": "private-openai-key",
        "GEMINI_API_KEY": "private-google-key",
        "ANTHROPIC_API_KEY": "private-anthropic-key",
    })
    def test_provider_endpoints_and_authentication_are_server_side(self):
        messages = [{"role": "user", "content": "Hi"}]
        checks = {
            "openai": ("https://api.openai.com/v1/responses", "Authorization"),
            "gemini": ("https://generativelanguage.googleapis.com/v1beta/models/", "x-goog-api-key"),
            "claude": ("https://api.anthropic.com/v1/messages", "x-api-key"),
        }
        for provider, (endpoint, key_name) in checks.items():
            with self.subTest(provider=provider):
                url, headers, body = bridge.make_upstream_request(provider, messages)
                self.assertTrue(url.startswith(endpoint))
                self.assertIn(key_name, headers)
                self.assertNotIn("private-", json.dumps(body))
                if provider == "openai":
                    self.assertIs(body["store"], False)
                    self.assertEqual(body["input"], messages)
                if provider == "gemini":
                    self.assertEqual(body["contents"][0]["role"], "user")

    def test_missing_key_is_explicit(self):
        with patch.dict(os.environ, {"OPENAI_API_KEY": ""}):
            with self.assertRaises(bridge.ProviderError) as err:
                bridge.make_upstream_request("openai", [{"role": "user", "content": "hi"}])
            self.assertIn("OPENAI_API_KEY", str(err.exception))

    def test_model_override_is_constrained(self):
        with patch.dict(os.environ, {"OPENAI_API_KEY": "test", "NUS3D_OPENAI_MODEL": "bad/name"}):
            with self.assertRaises(bridge.ProviderError):
                bridge.make_upstream_request("openai", [{"role": "user", "content": "hi"}])

    def test_three_upstream_reply_shapes(self):
        examples = {
            "openai": {"output": [{"type": "message", "content": [
                {"type": "output_text", "text": "GPT says hello."}]}]},
            "gemini": {"candidates": [{"content": {"parts": [{"text": "Gemini says hello."}]}}]},
            "claude": {"content": [{"type": "text", "text": "Claude says hello."}]},
        }
        for provider, response in examples.items():
            with self.subTest(provider=provider):
                self.assertIn("says hello", bridge.extract_reply(provider, response))
        with self.assertRaises(bridge.ProviderError):
            bridge.extract_reply("openai", {"output": []})

    def test_weather_uses_fixed_utown_reference_not_player_location(self):
        self.assertIn("latitude=1.3050", bridge._weather_url)
        self.assertIn("longitude=103.7732", bridge._weather_url)
        with patch.object(bridge, "_fetch_json", return_value={
            "current": {"time": "2026-11-19T12:00", "temperature_2m": 29,
                        "relative_humidity_2m": 77, "precipitation": 0,
                        "weather_code": 2, "other_personal_data": "exclude"}}):
            current = bridge.weather_snapshot()
        self.assertEqual(current["temperature_2m"], 29)
        self.assertNotIn("other_personal_data", current)


if __name__ == "__main__":
    unittest.main()
