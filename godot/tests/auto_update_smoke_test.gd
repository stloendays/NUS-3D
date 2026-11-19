extends SceneTree
## M16: release parsing, opt-in semantics and fixed trust-boundary contract.
## Does not access the network or run PowerShell.

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("M16 update smoke: " + reason)
    quit(1)

func _release(tag: String, digest: String) -> Dictionary:
    return {
        "draft": false, "prerelease": false, "tag_name": tag,
        "assets": [{
            "name": "NUS3D-UTown-Windows-Portable.zip",
            "state": "uploaded",
            "size": 25000000,
            "digest": digest,
            "browser_download_url":
                "https://github.com/stloendays/NUS-3D/releases/download/%s/NUS3D-UTown-Windows-Portable.zip" % tag
        }]
    }

func _run() -> void:
    var updater := NUS3DAutoUpdater.new()
    updater.test_mode = true
    root.add_child(updater)
    await process_frame
    if updater.current_version != "0.1.0" or not updater.enabled:
        _fail("canonical app version is missing from the exported game")
        return
    if updater.api != null or updater.downloader != null or updater.overlay != null:
        _fail("headless validation unexpectedly used network or gameplay UI")
        return
    if not NUS3DAutoUpdater._is_newer("0.1.1", "0.1.0"):
        _fail("patch upgrade not detected")
        return
    if not NUS3DAutoUpdater._is_newer("2.0.0", "1.50.99"):
        _fail("major-version upgrade not detected")
        return
    if NUS3DAutoUpdater._is_newer("0.1.0", "0.1.0") \
        or NUS3DAutoUpdater._is_newer("0.1.0", "0.2.0") \
        or NUS3DAutoUpdater._is_newer("1.2.3-rc.1", "1.2.2"):
        _fail("downgrade, same version or pre-release was accepted")
        return
    var release: Dictionary = _release("v0.1.1", "sha256:" + "a".repeat(64))
    if not updater._select_release(release):
        _fail("correct pinned stable release was rejected")
        return
    if updater.new_version != "0.1.1" or updater.release_sha256 != "a".repeat(64) or updater.release_bytes != 25000000:
        _fail("release SHA-256, version or size not bound to selected official asset")
        return
    release["draft"] = true
    if updater._select_release(release):
        _fail("draft release was accepted")
        return
    release["draft"] = false
    release["prerelease"] = true
    if updater._select_release(release):
        _fail("pre-release was accepted")
        return
    release["prerelease"] = false
    release["assets"][0]["digest"] = ""
    if updater._select_release(release):
        _fail("missing GitHub SHA-256 digest was accepted")
        return
    release["assets"][0]["digest"] = "sha256:" + "a".repeat(64)
    release["assets"][0]["browser_download_url"] = "https://evil.invalid/NUS3D.zip"
    if updater._select_release(release):
        _fail("asset outside the pinned repository was accepted")
        return
    release["assets"][0]["browser_download_url"] = "https://github.com/stloendays/NUS-3D/releases/download/v0.1.1/NUS3D-UTown-Windows-Portable.zip"
    release["assets"][0]["size"] = 400000001
    if updater._select_release(release):
        _fail("oversized release was accepted")
        return
    release["assets"][0]["size"] = 25000000
    release["tag_name"] = "v0.1.1-rc.1"
    if updater._select_release(release):
        _fail("nonstable SemVer tag was accepted")
        return
    release["tag_name"] = "v0.1.0"
    if updater._select_release(release):
        _fail("installed version was offered as update")
        return
    release["tag_name"] = "v0.1.1"
    release["assets"][0]["state"] = "starter"
    if updater._select_release(release):
        _fail("non-uploaded asset was accepted")
        return
    if updater.state != "inactive" or updater.download_path != "":
        _fail("release metadata check unexpectedly installed a package")
        return
    if not FileAccess.file_exists("res://scripts/auto_updater.gd") or not FileAccess.file_exists("res://data/app_version.json"):
        _fail("export does not include update logic and current version")
        return
    print("PASS: release SemVer order, official HTTPS, SHA-256, asset size, draft/prerelease rules and no network/install in headless mode.")
    updater.queue_free()
    quit(0)
