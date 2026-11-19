extends Node
class_name NUS3DAutoUpdater
## Automatic check/download for VERIFIED stable GitHub Releases.
## No background installation: the player explicitly confirms restart.
## Existing user:// saves and local accounts are never moved or overwritten.

const CONFIG_PATH: String = "res://data/app_version.json"
const RELEASE_API: String = "https://api.github.com/repos/stloendays/NUS-3D/releases/latest"
const RELEASE_PREFIX: String = "https://github.com/stloendays/NUS-3D/releases/download/"
const HELPER_NAME: String = "NUS3D-Updater.ps1"
const BUILD_MANIFEST: String = "BUILD_MANIFEST.json"
const MAX_PACKAGE_BYTES: int = 400000000
const MAX_API_BYTES: int = 1048576
const MIN_PACKAGE_BYTES: int = 1000000

var test_mode: bool = false
var current_version: String = ""
var new_version: String = ""
var asset_name: String = ""
var release_url: String = ""
var release_sha256: String = ""
var release_bytes: int = 0
var download_path: String = ""
var state: String = "inactive"
var enabled: bool = false
var auto_download: bool = true
var ui_tick: float = 0.0
var api: HTTPRequest
var downloader: HTTPRequest
var overlay: CanvasLayer
var panel: PanelContainer
var message: Label
var progress: ProgressBar
var install_button: Button
var later_button: Button
var retry_button: Button

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _read_config()
    if test_mode or not enabled:
        return
    # Editor, headless tests and non-Windows builds cannot update their binaries.
    if OS.get_name() != "Windows" or Engine.is_editor_hint() \
        or DisplayServer.get_name() == "headless" \
        or OS.get_cmdline_user_args().has("--nus3d-self-test"):
        return
    _build_ui()
    call_deferred("_check_for_release")

func _read_config() -> void:
    var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
    if typeof(doc) != TYPE_DICTIONARY:
        return
    if int(doc.get("schema", 0)) != 1 or str(doc.get("channel", "")) != "stable" \
        or str(doc.get("repository", "")) != "stloendays/NUS-3D":
        return
    current_version = str(doc.get("version", ""))
    if _semver_parts(current_version).is_empty():
        return
    asset_name = str(doc.get("asset_name", ""))
    if asset_name != "NUS3D-UTown-Windows-Portable.zip":
        return
    auto_download = bool(doc.get("auto_download", true))
    enabled = bool(doc.get("check_on_launch", true))

static func _semver_parts(value: String) -> Array[int]:
    var parts: PackedStringArray = value.split(".")
    if parts.size() != 3:
        return []
    var result: Array[int] = []
    for part in parts:
        if part.is_empty() or part.length() > 9 or (part.length() > 1 and part.begins_with("0")):
            return []
        for character in part:
            if character < "0" or character > "9":
                return []
        result.append(int(part))
    return result

static func _is_newer(candidate: String, installed: String) -> bool:
    var next: Array[int] = _semver_parts(candidate)
    var old: Array[int] = _semver_parts(installed)
    if next.size() != 3 or old.size() != 3:
        return false
    for i in range(3):
        if next[i] > old[i]:
            return true
        if next[i] < old[i]:
            return false
    return false

static func _is_sha256_hex(value: String) -> bool:
    if value.length() != 64:
        return false
    for character in value:
        if not ("0" <= character and character <= "9") and not ("a" <= character and character <= "f"):
            return false
    return true

func _select_release(doc: Variant) -> bool:
    new_version = ""
    release_url = ""
    release_sha256 = ""
    release_bytes = 0
    if typeof(doc) != TYPE_DICTIONARY:
        return false
    if bool(doc.get("draft", true)) or bool(doc.get("prerelease", true)):
        return false
    var tag: String = str(doc.get("tag_name", ""))
    if not tag.begins_with("v") or not _is_newer(tag.substr(1), current_version):
        return false
    var candidate: String = tag.substr(1)
    var assets: Variant = doc.get("assets", [])
    if typeof(assets) != TYPE_ARRAY:
        return false
    for raw_asset in assets:
        if typeof(raw_asset) != TYPE_DICTIONARY:
            continue
        var asset: Dictionary = raw_asset
        if str(asset.get("name", "")) != asset_name or str(asset.get("state", "")) != "uploaded":
            continue
        var expected_url: String = RELEASE_PREFIX + tag + "/" + asset_name
        var url: String = str(asset.get("browser_download_url", ""))
        if url != expected_url:
            continue
        var digest: String = str(asset.get("digest", ""))
        if not digest.begins_with("sha256:"):
            continue
        var hex: String = digest.substr(7)
        if not _is_sha256_hex(hex):
            continue
        var bytes: int = int(asset.get("size", 0))
        if bytes < MIN_PACKAGE_BYTES or bytes > MAX_PACKAGE_BYTES:
            continue
        new_version = candidate
        release_url = url
        release_sha256 = hex
        release_bytes = bytes
        return true
    return false

func _build_ui() -> void:
    overlay = CanvasLayer.new()
    overlay.name = "ReleaseUpdateNotice"
    overlay.layer = 95
    overlay.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(overlay)
    panel = PanelContainer.new()
    panel.name = "UpdateNotice"
    panel.visible = false
    panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    panel.offset_left = -390
    panel.offset_top = -220
    panel.offset_right = -20
    panel.offset_bottom = -18
    var style := StyleBoxFlat.new()
    style.bg_color = Color.html("#17252c")
    style.border_color = Color.html("#526f73")
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    panel.add_theme_stylebox_override("panel", style)
    overlay.add_child(panel)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 9)
    panel.add_child(box)
    var title := Label.new()
    title.text = "NUS-3D  |  VERSION UPDATE"
    title.add_theme_font_size_override("font_size", 17)
    title.add_theme_color_override("font_color", Color.html("#ffdb91"))
    box.add_child(title)
    message = Label.new()
    message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message.add_theme_font_size_override("font_size", 13)
    message.add_theme_color_override("font_color", Color.html("#d7e8e6"))
    message.custom_minimum_size.y = 48
    box.add_child(message)
    progress = ProgressBar.new()
    progress.min_value = 0
    progress.max_value = 100
    progress.value = 0
    progress.show_percentage = false
    progress.custom_minimum_size.y = 12
    progress.visible = false
    box.add_child(progress)
    var buttons := HBoxContainer.new()
    box.add_child(buttons)
    install_button = Button.new()
    install_button.text = "RESTART & INSTALL"
    install_button.visible = false
    install_button.pressed.connect(_install_after_confirmation)
    buttons.add_child(install_button)
    retry_button = Button.new()
    retry_button.text = "DOWNLOAD UPDATE"
    retry_button.visible = false
    retry_button.pressed.connect(_start_download)
    buttons.add_child(retry_button)
    later_button = Button.new()
    later_button.text = "LATER"
    later_button.pressed.connect(_dismiss)
    buttons.add_child(later_button)

func _show_state(next: String, note: String) -> void:
    state = next
    if panel == null:
        return
    panel.visible = next not in ["inactive", "checking", "current", "dismissed"]
    message.text = note
    progress.visible = next == "downloading"
    install_button.visible = next == "ready"
    retry_button.visible = next in ["available", "failed"] and not release_url.is_empty()
    retry_button.text = "DOWNLOAD UPDATE" if next == "available" else "RETRY DOWNLOAD"

func _check_for_release() -> void:
    if not enabled or state not in ["inactive", "current", "failed"]:
        return
    api = HTTPRequest.new()
    api.use_threads = true
    api.timeout = 12.0
    api.max_redirects = 2
    api.body_size_limit = MAX_API_BYTES
    add_child(api)
    api.request_completed.connect(_on_release_response)
    _show_state("checking", "")
    var err: Error = api.request(RELEASE_API, ["Accept: application/vnd.github+json", "User-Agent: NUS3D-Windows-Updater", "X-GitHub-Api-Version: 2022-11-28"])
    if err != OK:
        _finish_api()
        _show_state("current", "")

func _finish_api() -> void:
    if api != null:
        api.queue_free()
        api = null

func _on_release_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    _finish_api()
    if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.size() > MAX_API_BYTES:
        _show_state("current", "")
        return
    var doc: Variant = JSON.parse_string(body.get_string_from_utf8())
    if not _select_release(doc):
        _show_state("current", "")
        return
    if auto_download:
        _start_download()
    else:
        _show_state("available", "Version %s is available. The update is optional." % new_version)

func _start_download() -> void:
    if release_url.is_empty() or release_sha256.is_empty() or new_version.is_empty():
        return
    if downloader != null:
        return
    var updates_dir: String = ProjectSettings.globalize_path("user://updates")
    if DirAccess.make_dir_recursive_absolute(updates_dir) != OK:
        _show_state("failed", "Cannot create update cache. This game remains playable.")
        return
    download_path = updates_dir.path_join("NUS3D-%s.zip" % new_version)
    if FileAccess.file_exists(download_path):
        DirAccess.remove_absolute(download_path)
    downloader = HTTPRequest.new()
    downloader.use_threads = true
    downloader.timeout = 180.0
    downloader.max_redirects = 6
    downloader.body_size_limit = MAX_PACKAGE_BYTES
    downloader.download_file = download_path
    add_child(downloader)
    downloader.request_completed.connect(_on_download_complete)
    _show_state("downloading", "Downloading verified version %s. Play normally while it downloads." % new_version)
    var err: Error = downloader.request(release_url, ["User-Agent: NUS3D-Windows-Updater"])
    if err != OK:
        _clear_downloader()
        _show_state("failed", "Download could not start. The installed version is unchanged.")

func _clear_downloader() -> void:
    if downloader != null:
        downloader.queue_free()
        downloader = null

func _on_download_complete(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
    _clear_downloader()
    if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not FileAccess.file_exists(download_path):
        _remove_cache()
        _show_state("failed", "Update download failed. Your game and saves are unchanged.")
        return
    var data: FileAccess = FileAccess.open(download_path, FileAccess.READ)
    if data == null or data.get_length() != release_bytes:
        data = null
        _remove_cache()
        _show_state("failed", "Release size check failed. No files were installed.")
        return
    data = null
    if FileAccess.get_sha256(download_path).to_lower() != release_sha256:
        _remove_cache()
        _show_state("failed", "SHA-256 verification failed. The update was rejected.")
        return
    _show_state("ready", "Version %s is verified. Restart to install, or continue playing and update later." % new_version)

func _remove_cache() -> void:
    if not download_path.is_empty() and FileAccess.file_exists(download_path):
        DirAccess.remove_absolute(download_path)

func _dismiss() -> void:
    # "Later" does not stop the game, its missions or the user's work.
    if downloader != null:
        downloader.cancel_request()
        _clear_downloader()
        _remove_cache()
    _show_state("dismissed", "")

func _read_helper_checksum() -> String:
    var path: String = OS.get_executable_path().get_base_dir().path_join(BUILD_MANIFEST)
    if not FileAccess.file_exists(path):
        return ""
    var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(doc) != TYPE_DICTIONARY:
        return ""
    if int(doc.get("schema_version", 0)) != 2 or str(doc.get("release_version", "")) != current_version \
        or str(doc.get("repository", "")) != "https://github.com/stloendays/NUS-3D":
        return ""
    var files: Variant = doc.get("files", {})
    if typeof(files) != TYPE_DICTIONARY or not files.has(HELPER_NAME):
        return ""
    var entry: Variant = files[HELPER_NAME]
    if typeof(entry) != TYPE_DICTIONARY:
        return ""
    var expected: String = str(entry.get("sha256", ""))
    return expected if _is_sha256_hex(expected) else ""

func _install_after_confirmation() -> void:
    if state != "ready" or OS.get_name() != "Windows":
        return
    if not FileAccess.file_exists(download_path) or FileAccess.get_sha256(download_path).to_lower() != release_sha256:
        _remove_cache()
        _show_state("failed", "Downloaded file changed. Please download again.")
        return
    var app_dir: String = OS.get_executable_path().get_base_dir()
    var helper: String = app_dir.path_join(HELPER_NAME)
    var manifest_sha: String = _read_helper_checksum()
    if manifest_sha.is_empty() or not FileAccess.file_exists(helper) \
        or FileAccess.get_sha256(helper).to_lower() != manifest_sha:
        _show_state("failed", "Trusted local installer was not found. Reinstall from the official release.")
        return
    var updater_copy: String = ProjectSettings.globalize_path("user://updates").path_join("nus3d-local-updater.ps1")
    if DirAccess.copy_absolute(helper, updater_copy) != OK \
        or FileAccess.get_sha256(updater_copy).to_lower() != manifest_sha:
        _show_state("failed", "Unable to prepare the updater. The current game is unchanged.")
        return
    var status_file: String = ProjectSettings.globalize_path("user://updates").path_join("last-update-result.json")
    var args := PackedStringArray([
        "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
        "-File", updater_copy,
        "-Package", download_path,
        "-ExpectedSha256", release_sha256,
        "-ExpectedVersion", new_version,
        "-InstallDir", app_dir,
        "-WaitPid", str(OS.get_process_id()),
        "-StatusFile", status_file
    ])
    # Persist quests, coins, exam records, profiles and progress before exit.
    var shell: Node = get_parent()
    if shell != null and shell.has_method("save_for_version_update"):
        shell.call("save_for_version_update")
    var spawned_pid: int = OS.create_process("powershell.exe", args)
    if spawned_pid <= 0:
        _show_state("failed", "Could not launch the local installer. No changes were made.")
        return
    _show_state("installing", "Closing NUS-3D to install verified version %s..." % new_version)
    get_tree().quit()

func _process(delta: float) -> void:
    if state != "downloading" or downloader == null or progress == null:
        return
    ui_tick += delta
    if ui_tick < 0.2:
        return
    ui_tick = 0.0
    var received: int = downloader.get_downloaded_bytes()
    var expected: int = maxi(1, release_bytes)
    progress.value = minf(100.0, 100.0 * float(received) / float(expected))
