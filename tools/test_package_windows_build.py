"""Regression checks for the M4 portable Windows packaging contract."""
from __future__ import annotations

import json
import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.package_windows_build import (
    EXE_NAME, MANIFEST_NAME, PACK_NAME, README_NAME, UPDATER_NAME,
    build_archive, verify_archive,
)

COMMIT = "a" * 40


class WindowsPackageTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin_dir = self.root / "bin"
        self.bin_dir.mkdir()
        (self.bin_dir / EXE_NAME).write_bytes(b"MZ" + b"\x00" * 1_000_001)
        (self.bin_dir / PACK_NAME).write_bytes(b"GDPC" + b"\x00" * 1024)
        self.output = self.root / "preview.zip"

    def test_build_and_verify_round_trip(self) -> None:
        manifest = build_archive(self.bin_dir, self.output, COMMIT, "4.4.1")
        self.assertEqual(manifest["commit"], COMMIT)
        self.assertEqual(verify_archive(self.output), manifest)
        self.assertEqual(manifest["schema_version"], 2)
        self.assertEqual(manifest["release_version"], "0.1.0")
        self.assertEqual(len(manifest["files"][UPDATER_NAME]["sha256"]), 64)
        with zipfile.ZipFile(self.output) as archive:
            self.assertEqual(set(archive.namelist()), {EXE_NAME, PACK_NAME, MANIFEST_NAME, README_NAME, UPDATER_NAME})
            self.assertTrue(archive.read(PACK_NAME).startswith(b"GDPC"))

    def test_reject_bad_executable(self) -> None:
        (self.bin_dir / EXE_NAME).write_bytes(b"broken")
        with self.assertRaisesRegex(ValueError, "Windows PE"):
            build_archive(self.bin_dir, self.output, COMMIT, "4.4.1")

    def test_reject_bad_pck(self) -> None:
        (self.bin_dir / PACK_NAME).write_bytes(b"not-pck" * 200)
        with self.assertRaisesRegex(ValueError, "Godot PCK"):
            build_archive(self.bin_dir, self.output, COMMIT, "4.4.1")

    def test_reject_unpinned_source_commit(self) -> None:
        with self.assertRaisesRegex(ValueError, "Commit"):
            build_archive(self.bin_dir, self.output, "main", "4.4.1")

    def test_detect_tampered_payload(self) -> None:
        build_archive(self.bin_dir, self.output, COMMIT, "4.4.1")
        with zipfile.ZipFile(self.output) as original:
            original_members = {name: original.read(name) for name in original.namelist()}
        original_members[PACK_NAME] = b"GDPC" + b"\x01" * 1024
        with zipfile.ZipFile(self.output, "w") as out:
            for name, data in original_members.items():
                out.writestr(name, data)
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            verify_archive(self.output)

    def test_update_helper_is_checksum_protected(self) -> None:
        build_archive(self.bin_dir, self.output, COMMIT, "4.4.1")
        with zipfile.ZipFile(self.output) as original:
            files = {name: original.read(name) for name in original.namelist()}
        files[UPDATER_NAME] = b"# swapped updater with unsafe instructions"
        with zipfile.ZipFile(self.output, "w") as output:
            for name, content in files.items():
                output.writestr(name, content)
        with self.assertRaisesRegex(ValueError, "Invalid bundled updater helper"):
            verify_archive(self.output)

    def test_manifest_checksum_has_expected_length(self) -> None:
        build_archive(self.bin_dir, self.output, COMMIT, "4.4.1")
        with zipfile.ZipFile(self.output) as archive:
            payload = json.loads(archive.read(MANIFEST_NAME))
        self.assertEqual(len(payload["files"][EXE_NAME]["sha256"]), 64)


if __name__ == "__main__":
    unittest.main()
