#!/usr/bin/env python3
"""Build and verify a checksum-backed, unsigned, portable Windows UTown preview.

Only the original Godot-generated .exe and its separate .pck belong in the
package. This tool does NOT sign the binary or claim Windows GPU certification.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path

EXE_NAME = "NUS3D-UTown.exe"
PACK_NAME = "NUS3D-UTown.pck"
MANIFEST_NAME = "BUILD_MANIFEST.json"
README_NAME = "READ_ME_FIRST.txt"
UPDATER_NAME = "NUS3D-Updater.ps1"
REPO_ROOT = Path(__file__).resolve().parents[1]
UPDATER_SOURCE = REPO_ROOT / "tools/windows_updater" / UPDATER_NAME
VERSION_SOURCE = REPO_ROOT / "godot/data/app_version.json"
ARCHIVE_MEMBERS = {EXE_NAME, PACK_NAME, UPDATER_NAME, MANIFEST_NAME, README_NAME}

README = """NUS-3D UTown — UNOFFICIAL experimental Windows preview

This is a community-made procedural study, NOT an official NUS product.
Building shapes, routes, terrain and elevations are provisional. Do not use
this preview for real-world navigation or accessible-route decisions.

Requirements: 64-bit Windows 10/11; an OpenGL 3.3 compatible graphics driver.
Both NUS3D-UTown.exe and NUS3D-UTown.pck MUST remain in the same directory.
Extract the ZIP and launch NUS3D-UTown.exe. No Godot editor is required.
On Windows, the game checks the official NUS-3D GitHub stable release feed
in the background, downloads checked updates, and asks before closing and
installing. Never delete the updater script next to your EXE. Automatic
update failures leave your existing game usable and account saves untouched.

Controls: WASD walk, mouse look, Shift sprint, Space jump, Esc release mouse,
R reset, M map, E discover checkpoint, G replay tour, C collect Field Notes,
V Campus Sprint, B bicycle, X shuttle, I enter interiors, L change floor,
F interact at activities, Q talk to fictional NPCs, Y weather, T lighting,
O choose/change faculty, J coursework journal, K take/submit coursework,
F1 help, F2 facade study, F3 viewpoints, F4 screenshot, F6 OSM reference,
F7 hide HUD. Deadlines/grades are fictional game mechanics.

The executable is unsigned; provenance and SHA-256 digests are in
BUILD_MANIFEST.json. Rebuild from the GitHub source rather than overriding
operating-system security warnings if you are unsure of the publisher.

Source: https://github.com/stloendays/NUS-3D
OSM reference: (c) OpenStreetMap contributors, ODbL 1.0
https://www.openstreetmap.org/copyright
NUS branding and map photographs are NOT distributed in this package.
"""


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _validate_payload(name: str, data: bytes) -> None:
    if name == EXE_NAME:
        if len(data) < 1_000_000 or data[:2] != b"MZ":
            raise ValueError("Invalid or undersized Windows PE executable")
    elif name == PACK_NAME:
        if len(data) < 256 or data[:4] != b"GDPC":
            raise ValueError("Invalid or undersized Godot PCK resource pack")
    else:
        raise ValueError(f"Unexpected binary payload: {name}")


def load_release_version() -> str:
    """Release channel/version must match the game's included configuration."""
    obj = json.loads(VERSION_SOURCE.read_text(encoding="utf-8"))
    version = obj.get("version")
    if obj.get("schema") != 1 or obj.get("channel") != "stable":
        raise ValueError("Only the canonical stable app version can be packaged")
    if obj.get("repository") != "stloendays/NUS-3D":
        raise ValueError("Cannot build release for an unexpected repository")
    if not isinstance(version, str) or not re.fullmatch(r"0|[1-9]\d*", version.split(".")[0]) or not re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", version):
        raise ValueError("Release version must be stable major.minor.patch")
    return version


def build_archive(directory: Path, output: Path, commit: str, godot_version: str) -> dict:
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Commit must be a full, lowercase 40-character Git SHA")
    if not re.fullmatch(r"\d+\.\d+\.\d+", godot_version):
        raise ValueError("Godot version must be major.minor.patch")
    sources = {}
    for name in (EXE_NAME, PACK_NAME):
        sources[name] = (directory / name).read_bytes()
        _validate_payload(name, sources[name])
    sources[UPDATER_NAME] = UPDATER_SOURCE.read_bytes()
    if len(sources[UPDATER_NAME]) < 1000 or not sources[UPDATER_NAME].startswith(b"# NUS-3D"):
        raise ValueError("Trusted local updater script is missing or malformed")
    release_version = load_release_version()
    manifest = {
        "schema_version": 2,
        "release_version": release_version,
        "project": "NUS-3D UTown",
        "repository": "https://github.com/stloendays/NUS-3D",
        "commit": commit,
        "godot_version": godot_version,
        "platform": "Windows x86_64",
        "distribution": "experimental, unsigned, non-official",
        "spatial_data": "provisional, NOT a field survey",
        "files": {
            name: {"bytes": len(data), "sha256": sha256(data)}
            for name, data in sources.items()
        },
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=8) as archive:
        for name, data in sources.items():
            archive.writestr(name, data)
        archive.writestr(MANIFEST_NAME, json.dumps(manifest, indent=2) + "\n")
        archive.writestr(README_NAME, README)
    verify_archive(output)
    return manifest


def verify_archive(path: Path) -> dict:
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(ARCHIVE_MEMBERS) or set(names) != ARCHIVE_MEMBERS:
            raise ValueError(f"Unexpected archive contents: {names}")
        if archive.testzip() is not None:
            raise ValueError("ZIP CRC check failed")
        manifest = json.loads(archive.read(MANIFEST_NAME))
        if manifest.get("schema_version") != 2 or manifest.get("platform") != "Windows x86_64":
            raise ValueError("Unexpected Windows package manifest")
        if manifest.get("repository") != "https://github.com/stloendays/NUS-3D":
            raise ValueError("Wrong release repository")
        if not isinstance(manifest.get("release_version"), str) or not re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)", manifest["release_version"]):
            raise ValueError("Invalid release version")
        if set(manifest.get("files", {})) != {EXE_NAME, PACK_NAME, UPDATER_NAME}:
            raise ValueError("Manifest payload inventory is incomplete")
        for name in (EXE_NAME, PACK_NAME, UPDATER_NAME):
            contents = archive.read(name)
            if name != UPDATER_NAME:
                _validate_payload(name, contents)
            elif len(contents) < 1000 or not contents.startswith(b"# NUS-3D"):
                raise ValueError("Invalid bundled updater helper")
            expected = manifest["files"][name]
            if expected["bytes"] != len(contents) or expected["sha256"] != sha256(contents):
                raise ValueError(f"SHA-256 or byte count mismatch in {name}")
        if "NOT an official NUS product" not in archive.read(README_NAME).decode("utf-8"):
            raise ValueError("Unofficial status disclaimer missing")
        return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, help="Directory containing .exe and .pck")
    parser.add_argument("--output", type=Path, help="Output ZIP")
    parser.add_argument("--commit", help="Exact source commit SHA")
    parser.add_argument("--godot-version", default="4.4.1")
    parser.add_argument("--verify", type=Path, help="Verify a completed ZIP instead of building")
    args = parser.parse_args()
    if args.verify:
        result = verify_archive(args.verify)
        print("PASS: Windows archive signatures, inventory and SHA-256 verified")
    else:
        if not args.directory or not args.output or not args.commit:
            parser.error("--directory, --output, --commit required when building")
        result = build_archive(args.directory, args.output, args.commit, args.godot_version)
        print(f"PASS: Windows portable bundle written to {args.output}")
    print(f"Project commit: {result['commit']} | Godot: {result['godot_version']}")


if __name__ == "__main__":
    main()
