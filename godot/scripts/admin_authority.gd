extends Node
class_name NUS3DAdminAuthority
## Local-only owner permission boundary. Never expose this to AI, RPC or web APIs.
## There is NO default admin username or password.

const PASSWORD_MIN: int = 12
const PASSWORD_MAX: int = 128
const MAX_GRANT: int = 5000
const MAX_AUDIT: int = 100
const AUTH_ROUNDS: int = 20000
const BOOTSTRAP_ENV: String = "NUS3D_ADMIN_BOOTSTRAP_PASSWORD"

var accounts: NUS3DAccountStore
var game: Node3D
var unlocked_account_id: String = ""
var failed_attempts: int = 0
var lock_until_ms: int = 0


func _credential_path() -> String:
    return accounts.storage_root.path_join("admin_owner.json") if accounts != null else ""


func _audit_path() -> String:
    return accounts.storage_root.path_join("admin_actions.json") if accounts != null else ""


func _current_id() -> String:
    if accounts == null or not accounts.is_logged_in():
        return ""
    var record: Dictionary = accounts.accounts.get(accounts.active_username, {})
    return str(record.get("id", ""))


func _record() -> Dictionary:
    if accounts == null:
        return {}
    return accounts._read_json(_credential_path())


func has_owner() -> bool:
    return accounts != null and FileAccess.file_exists(_credential_path())


func is_current_owner() -> bool:
    if not has_owner() or _current_id().is_empty():
        return false
    var record: Dictionary = _record()
    return str(record.get("owner_id", "")) == _current_id()


func is_unlocked() -> bool:
    return not unlocked_account_id.is_empty() and unlocked_account_id == _current_id() and is_current_owner()


func lock() -> void:
    unlocked_account_id = ""
    failed_attempts = 0
    lock_until_ms = 0


func bootstrap_owner(secret: String) -> String:
    if _current_id().is_empty():
        return "Sign in to a local game account first."
    if has_owner():
        return "Admin owner already exists on this installation."
    if secret.length() < PASSWORD_MIN or secret.length() > PASSWORD_MAX:
        return "The admin password must be 12-128 characters."
    # Explicit out-of-band opt-in; never infer ownership from a username or
    # from being the first registered player.
    var supplied: String = OS.get_environment(BOOTSTRAP_ENV)
    if supplied.length() < PASSWORD_MIN or supplied.length() > PASSWORD_MAX:
        return "Set NUS3D_ADMIN_BOOTSTRAP_PASSWORD before launching the game."
    var crypto: Crypto = Crypto.new()
    if not crypto.constant_time_compare(secret.to_utf8_buffer(), supplied.to_utf8_buffer()):
        return "Admin setup password does not match the launch environment."
    var salt: String = crypto.generate_random_bytes(16).hex_encode()
    var record: Dictionary = {
        "schema_version": 1,
        "owner_id": _current_id(),
        "salt": salt,
        "rounds": AUTH_ROUNDS,
        "password_hash": accounts._password_hash(secret, salt, AUTH_ROUNDS).hex_encode()
    }
    if not accounts._write_json(_credential_path(), record):
        return "Could not persist the admin owner credential."
    unlocked_account_id = _current_id()
    failed_attempts = 0
    lock_until_ms = 0
    _append_audit("admin_enrolled", "-", "owner", "local_only")
    return ""


func unlock(secret: String) -> String:
    if not is_current_owner():
        return "This signed-in profile is not the local admin owner."
    var now_ms: int = Time.get_ticks_msec()
    if now_ms < lock_until_ms:
        return "Too many attempts. Try again shortly."
    var record: Dictionary = _record()
    var hash_hex: String = str(record.get("password_hash", ""))
    var expected: PackedByteArray = hash_hex.hex_decode()
    var salt_hex: String = str(record.get("salt", ""))
    var rounds: int = int(record.get("rounds", 0))
    if expected.size() != 32 or salt_hex.hex_decode().size() != 16 or rounds < 1000 or rounds > 200000:
        return "Admin owner credential is damaged. No access granted."
    if secret.length() < PASSWORD_MIN or secret.length() > PASSWORD_MAX:
        return "Invalid admin password."
    var actual: PackedByteArray = accounts._password_hash(secret, salt_hex, rounds)
    if not Crypto.new().constant_time_compare(expected, actual):
        failed_attempts += 1
        if failed_attempts >= 4:
            lock_until_ms = now_ms + 30000
            failed_attempts = 0
        return "Invalid admin password."
    unlocked_account_id = _current_id()
    failed_attempts = 0
    lock_until_ms = 0
    return ""


func _offline_game() -> bool:
    if game == null or not is_instance_valid(game):
        return false
    var shell: Node = game.get_parent()
    # In the optional LAN branch State.OFFLINE=0; even CONNECTING is denied.
    var net: Node = shell.get_node_or_null("MultiplayerAndGraphics/NetworkSession")
    if net != null and int(net.get("state")) != 0:
        return false
    return true


func _append_audit(action: String, before: String, after: String, scope: String) -> void:
    if accounts == null or not is_instance_valid(accounts):
        return
    var file: Dictionary = accounts._read_json(_audit_path())
    var entries: Array = file.get("events", [])
    entries.append({
        "time_utc": Time.get_datetime_string_from_system(true, true),
        "owner_id": _current_id(),
        "action": action,
        "before": before,
        "after": after,
        "scope": scope
    })
    if entries.size() > MAX_AUDIT:
        entries = entries.slice(entries.size() - MAX_AUDIT)
    if not accounts._write_json(_audit_path(), {"schema_version": 1, "events": entries}):
        push_warning("Local admin audit log could not be saved.")


func recent_actions() -> Array:
    if not is_unlocked():
        return []
    var file: Dictionary = accounts._read_json(_audit_path())
    var raw: Variant = file.get("events", [])
    return raw.duplicate(true) if typeof(raw) == TYPE_ARRAY else []


func apply(action: String, value: int = 0) -> String:
    if not is_unlocked():
        return "Admin authentication is required."
    if not _offline_game():
        return "Admin changes are disabled in LAN multiplayer sessions."
    var world: UTownWorld = game.get_node_or_null("World") as UTownWorld
    var weather: UTownWeather = game.get_node_or_null("Weather") as UTownWeather
    if action == "weather":
        if weather == null or value < 0 or value >= weather.mode_count():
            return "Invalid weather index."
        var old_mode: int = weather.mode
        if not weather.set_mode(value):
            return "Weather update failed."
        _append_audit("weather", str(old_mode), str(weather.mode), "world")
    elif action == "lighting":
        if world == null or value < 0 or value >= world.LIGHTING_NAMES.size():
            return "Invalid lighting index."
        var old_light: int = world.lighting_mode
        if not world.set_lighting_mode(value):
            return "Lighting update failed."
        _append_audit("lighting", str(old_light), str(world.lighting_mode), "world")
    elif action == "restore_atmosphere":
        if world == null or weather == null:
            return "World atmosphere is unavailable."
        var previous: String = "weather=%d,time=%d" % [weather.mode, world.lighting_mode]
        if not weather.set_mode(0) or not world.set_lighting_mode(0):
            return "Could not restore default atmosphere."
        _append_audit("restore_atmosphere", previous, "weather=0,time=0", "world")
    elif action == "grant_xp":
        if value < 1 or value > MAX_GRANT:
            return "XP grant must be 1-5000."
        var prior_xp: int = int(accounts.level_progress()["total"])
        var nonce: String = Crypto.new().generate_random_bytes(16).hex_encode()
        if not accounts.award_once("local_admin:" + nonce, value):
            return "Could not save the admin XP grant."
        _append_audit("grant_xp", str(prior_xp), str(accounts.level_progress()["total"]), "current_profile")
    elif action == "grant_coins":
        if value < 1 or value > MAX_GRANT:
            return "Coin grant must be 1-5000."
        var coins: UTownCoins = game.get_node_or_null("Coins") as UTownCoins
        if coins == null:
            return "Coin system is unavailable."
        var prior_coins: int = coins.balance
        if not coins.credit(value, "Local admin grant"):
            return "Coin balance is full or cannot be changed."
        _append_audit("grant_coins", str(prior_coins), str(coins.balance), "current_profile")
    elif action == "teleport":
        var player: UTownPlayer = game.get_node_or_null("Player") as UTownPlayer
        if world == null or player == null or value < 0 or value >= world.route_points.size():
            return "Invalid checkpoint."
        var old_position: Vector3 = player.global_position
        player.reset_player()
        player.global_position = world.route_points[value] + Vector3(0.0, 0.3, 0.0)
        _append_audit("teleport", str(old_position), str(player.global_position), "current_profile")
    else:
        return "Action is not in the admin allowlist."
    return ""
