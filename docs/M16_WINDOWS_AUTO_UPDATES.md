# M16 — Windows portable stable version updates

NUS-3D on Windows checks the **official** GitHub stable Releases endpoint at startup, downloads a newer verified portable archive into the local update cache, and asks before closing the game and installing it. Internet and update failures never block offline play. This is an **unsigned community game**, not an official NUS application.

## Player flow

1. Start `NUS3D-UTown.exe` with its adjacent `NUS3D-UTown.pck`, `NUS3D-Updater.ps1`, and `BUILD_MANIFEST.json`.
2. If supported, the background updater requests `https://api.github.com/repos/stloendays/NUS-3D/releases/latest`. If there is no stable release, or the local version is current, nothing interrupts the player.
3. It compares strict `MAJOR.MINOR.PATCH` versions. Drafts, pre-releases, non-stable tags, wrong asset names, non-GitHub download URLs, missing GitHub SHA-256 digest and files outside the 1–400 MB bounds are **not** eligible.
4. The new ZIP is **streamed to disk** (`user://updates`) without keeping the full package in RAM. The game checks the exact file size and SHA-256 digest received from the official GitHub asset metadata.
5. The game shows **RESTART & INSTALL** or **LATER**; install is **never performed silently**. Playing, missions, locally stored accounts and mail remain usable during the download.
6. After confirmation, a **copy** of the bundled and checksum-verified local PowerShell installer runs and the Godot process exits.
7. The helper waits for the original EXE to stop, validates the ZIP hash, manifest, version, exact five-file inventory and each file hash. No arbitrary archive paths or executables are allowed. It extracts the fixed EXE/PCK/helper files into a temporary directory, performs the candidate game's built-in headless self-test, stages the old version as a backup, and replaces the files.
8. The new EXE launches from the original folder. The previous EXE/PCK/helper are retained in `.nus3d-previous` for manual restoration. If the operation fails during the file swap, the installer attempts to restore the old version. `user://` account data is never changed.

If Windows blocks PowerShell execution or the folder is not writable, the updater does not force elevation or bypass OS security prompts; players can download the official ZIP and replace the game files manually after exiting.

## Developer release checklist

Version source: `godot/data/app_version.json` (initial **0.1.0**, channel `stable`). A version must never be reused for different binaries.

**After PR review and merge to `main`:**

1. Increment `version` in `app_version.json` to the new stable version.
2. Merge a tested commit into `main`.
3. Tag that exact commit `vMAJOR.MINOR.PATCH` and push the tag. Example: `git tag v0.1.1 && git push origin v0.1.1`.
4. The `stable_release.yml` workflow checks the tag matches the bundled version **and is reachable from main**, runs Python/Godot tests, exports Godot 4.4.1 Windows EXE/PCK, and includes the local updater in the ZIP.
5. GitHub Actions verifies the ZIP and a real exported game self-test on Windows; **only if both jobs pass** does it publish `NUS3D-UTown-Windows-Portable.zip` and `SHA256SUMS.txt` to GitHub Releases.

An artifact uploaded by ordinary PR/CI builds is **not** a stable Release and must not be used as an automatic-update source. Do not create or push release tags automatically from every feature branch, and do not publish a tag until its changes are merged.

## Files and contracts

| File | Responsibility |
| --- | --- |
| `godot/data/app_version.json` | Canonical current SemVer, fixed GitHub channel and asset name |
| `godot/scripts/auto_updater.gd` | Asynchronous HTTPS check, strict asset/digest/size validation, streamed download, player-confirmed restart |
| `godot/scripts/game_shell.gd` | Adds one lightweight updater node to the existing account shell without changing game progress or key handling |
| `tools/windows_updater/NUS3D-Updater.ps1` | Post-exit ZIP validation, candidate self-test, staged replacement, backup and failure rollback |
| `tools/package_windows_build.py` | Package updater with EXE+PCK, schema-v2 build manifest, checksums and SemVer |
| `.github/workflows/stable_release.yml` | Strict stable tag -> build -> Windows verify -> publish pipeline |
| `godot/tests/auto_update_smoke_test.gd` | No-network checks for version ordering, SHA/URL pinning and prerelease refusal |
| `tools/test_package_windows_build.py` | ZIP inventory, helper integrity and checksum regression tests |

## Notes and limitations

- **Status at initial implementation:** No GitHub Release has been published yet. There is therefore no real newer version for the client to download. This workflow becomes active for players after the first verified `vX.Y.Z` release is created.
- Windows 10/11 x86_64 only. macOS, Linux and Godot editor/headless tests do not launch an installer.
- **Privacy:** Only public GitHub release metadata and ZIP are requested; no profile, password, mailbox, gameplay record or microphone data is uploaded.
- **OS support:** Windows may warn about unsigned applications. This updater does not grant admin rights and never installs from unrelated domains. Execution-policy options are scoped to the explicitly launched stock PowerShell process.
- Backups protect against many install errors but are not an atomic, crash-proof updater across arbitrary power loss. Keep the `.nus3d-previous` backup if troubleshooting. Future publisher code signing and a small native launcher would further strengthen recovery.
- CI uses headless checks and a Windows exported self-test; first public release still needs real player-machine validation, especially installation into a read-only directory, intermittent network and antivirus interference.
