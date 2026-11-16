# M4 alpha — Portable Windows export and native runtime integrity check (2026-11-16)

**Scope:** ship an unsigned Windows x86_64 **experimental** playable artifact, with a deterministic build recipe, manifest, ZIP integrity checks and an actual exported-program startup check on a GitHub-hosted Windows runner. This is NOT a graphical Windows acceptance test, benchmark, finished M4 release, installer or as-built campus digital twin.

## Download and run the Windows preview

1. Open [Windows portable preview Actions](https://github.com/stloendays/NUS-3D/actions/workflows/windows_build.yml). Select the latest **successful** run (do not assume the newest run is green).
2. Under **Artifacts**, download `NUS3D-UTown-Windows-Experimental`. GitHub wraps the deliverable ZIP in an artifact download. Extract it, then extract `NUS3D-UTown-Windows-Experimental.zip`.
3. Keep `NUS3D-UTown.exe` and `NUS3D-UTown.pck` side by side; launch the EXE. You do **not** need to install Godot. Requires 64-bit Windows 10/11 and an OpenGL 3.3 capable GPU/driver.
4. Inspect `READ_ME_FIRST.txt` and `BUILD_MANIFEST.json` for controls, project source SHA, 4.4.1 engine version, SHA-256 hashes and provenance. The executable is **unsigned**: Windows publisher reputation/SmartScreen and antivirus checks are not pre-validated. Do not override security warnings blindly.
5. WASD + mouse to explore. F2 compares M1/M2 facades; F3 cycles viewpoints; F6 shows source OSM outlines; T changes four *artistic* lighting presets; F7 hides the HUD for F4 screenshots. See README for full controls.

This 3D representation, schematic corridors, terrain and heights have not been field-surveyed. **Never use it as actual campus directions or accessibility advice.** OpenStreetMap source outlines (© OpenStreetMap contributors, ODbL) remain compare-only overlays, not verified 3D geometry. No NUS official logo, photography or proprietary model is bundled.

## Build pipeline

The workflow `.github/workflows/windows_build.yml` operates in two jobs:

1. **Linux export** pins Godot **4.4.1**. Standard-library geospatial/architecture validators plus Python regressions run, the Godot project imports, and the headless scene smoke test must pass. A version-matched, SHA-256 verified official export-template archive provides the x86_64 **release** template. Its extracted Windows template is cached. The preset `godot/export_presets.cfg` explicitly includes `*.json` data and keeps resources in a separate PCK, reducing avoidable binary-signing/AV complications.
2. The exporter creates `NUS3D-UTown.exe` and `NUS3D-UTown.pck`. `tools/package_windows_build.py` validates PE/PCK signatures, inventories both resources, computes per-file SHA-256 digests and packs an attribution/readme and JSON build manifest. Six unit tests cover correct packaging, malicious/accidental corruption and tamper detection.
3. **Native Windows runner** downloads the exact newly built ZIP, validates hashes again, extracts it and starts the **exported EXE** with `--headless -- --nus3d-self-test --nus3d-self-test-report=...`. Its scene-integrated test node reads the packed JSON and asserts 9 buildings, 64 trees, 2 facade detail layers, 4 waypoints, 2 OSM boundaries, four source view cameras, lighting infrastructure and the "NOT survey" disclaimer. A JSON smoke report is published as a separate artifact.

To reproduce locally with a matching Godot editor and installed Windows export templates:

```sh
python -m unittest discover -s tools -t . -v
godot --headless --path godot --import --quit
godot --headless --path godot --script res://tests/smoke_test.gd
mkdir -p build/windows
godot --headless --path godot --export-release "Windows Desktop" "$(pwd)/build/windows/NUS3D-UTown.exe"
python tools/package_windows_build.py --directory build/windows --output build/NUS3D-UTown-Windows-Experimental.zip --commit "$(git rev-parse HEAD)"
python tools/package_windows_build.py --verify build/NUS3D-UTown-Windows-Experimental.zip
```

Windows graphical launch, actual collision/walkthrough review, full-screen 1080p FPS/VRAM/CPU measurements, code signing and distribution licensing checks must still be done separately before the M4 release milestone can be marked complete.

## Manual Windows acceptance record (pending)

For each tested computer, note OS version, graphics GPU/driver, CPU, RAM, display resolution, test date and Git SHA. Walk Green → ERC → SRC → Plaza → Green without walkthrough-breaking collisions; use F2, F3, F4, F6, F7 and T; record 1080p FPS spread, scene load time, memory/VRAM and any rendering anomalies. Save screenshots (own-rendered only) and performance measurements with their provenance. A headless hosted Windows runner **cannot** supply these values or verify real-world accessibility.
