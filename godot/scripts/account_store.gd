extends Node
class_name NUS3DAccountStore
## Offline profiles for one installation. Not a remote identity provider or NUS SSO.

signal profile_changed
signal mailbox_changed

const DEFAULT_ROOT: String = "user://nus3d"
const LEGACY_CHALLENGE_SAVE: String = "user://nus3d_explorer.cfg"
const PBKDF2_ROUNDS: int = 20000
const MAX_MAIL: int = 100

var storage_root: String = DEFAULT_ROOT
var accounts: Dictionary = {}
var active_username: String = ""
var profile: Dictionary = {}


func _ready() -> void:
    _load_accounts()


func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return value if typeof(value) == TYPE_DICTIONARY else {}


func _write_json(path: String, data: Dictionary) -> bool:
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())) != OK:
        return false
    var temporary: String = path + ".tmp"
    var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(data, "  ") + "\n")
    file.flush()
    file.close()
    return DirAccess.rename_absolute(
        ProjectSettings.globalize_path(temporary),
        ProjectSettings.globalize_path(path)
    ) == OK


func _index_path() -> String:
    return storage_root.path_join("accounts.json")


func _profile_path(username: String) -> String:
    return storage_root.path_join("profiles").path_join(username + ".json")


func _load_accounts() -> void:
    var data: Dictionary = _read_json(_index_path())
    var users: Variant = data.get("users", {})
    accounts = users if typeof(users) == TYPE_DICTIONARY else {}


func _save_accounts() -> bool:
    return _write_json(_index_path(), {"schema_version": 1, "users": accounts})


func _load_profile(username: String) -> Dictionary:
    return _read_json(_profile_path(username))


func _save_profile() -> bool:
    return is_logged_in() and _write_json(_profile_path(active_username), profile)


func _normalize(username: String) -> String:
    return username.strip_edges().to_lower()


func _valid_username(username: String) -> bool:
    if username.length() < 3 or username.length() > 20:
        return false
    for i in range(username.length()):
        var letter: int = username.unicode_at(i)
        if not ((letter >= 97 and letter <= 122) or (letter >= 48 and letter <= 57) or letter == 95):
            return false
    return true


func _password_hash(password: String, salt: String, rounds: int) -> PackedByteArray:
    # PBKDF2-HMAC-SHA256, 32-byte derived key, one block.
    var key: PackedByteArray = password.to_utf8_buffer()
    var input_bytes: PackedByteArray = salt.hex_decode()
    input_bytes.append_array(PackedByteArray([0, 0, 0, 1]))
    var crypto: Crypto = Crypto.new()
    var block: PackedByteArray = crypto.hmac_digest(HashingContext.HASH_SHA256, key, input_bytes)
    var output: PackedByteArray = block.duplicate()
    for _iteration in range(1, rounds):
        block = crypto.hmac_digest(HashingContext.HASH_SHA256, key, block)
        for i in range(output.size()):
            output[i] = output[i] ^ block[i]
    return output


func register(username: String, password: String) -> String:
    var key: String = _normalize(username)
    if not _valid_username(key):
        return "Name: 3-20 lowercase letters, numbers or underscores."
    if password.length() < 8 or password.length() > 128:
        return "Password must have 8-128 characters."
    if accounts.has(key):
        return "That local account already exists."

    var crypto: Crypto = Crypto.new()
    var salt: String = crypto.generate_random_bytes(16).hex_encode()
    var account_id: String = crypto.generate_random_bytes(16).hex_encode()
    var initial: Dictionary = {
        "schema_version": 1, "username": key, "xp": 0,
        "awards": {}, "inbox": [], "sent": []
    }
    if not _write_json(_profile_path(key), initial):
        return "Cannot create local profile."
    var first_user: bool = accounts.is_empty()
    accounts[key] = {
        "id": account_id, "salt": salt,
        "password_hash": _password_hash(password, salt, PBKDF2_ROUNDS).hex_encode(),
        "rounds": PBKDF2_ROUNDS
    }
    if not _save_accounts():
        accounts.erase(key)
        return "Cannot save local account registry."

    active_username = key
    profile = initial
    if first_user:
        _migrate_legacy_progress()
    _system_mail("Welcome to NUS-3D!",
        "Your offline explorer account is ready.\n\nExplore the four-stop tour, collect Field Notes, and complete the Campus Sprint to gain XP. Press J to open the mailbox.\n\nUnofficial fan project; this is not NUS login or real internet email.")
    profile_changed.emit()
    return ""


func sign_in(username: String, password: String) -> String:
    var key: String = _normalize(username)
    if not accounts.has(key):
        return "Incorrect account name or password."
    var record: Dictionary = accounts[key]
    var expected: PackedByteArray = str(record.get("password_hash", "")).hex_decode()
    var rounds: int = int(record.get("rounds", 0))
    if expected.size() != 32 or rounds < 1000 or rounds > 200000:
        return "Account record is invalid."
    var actual: PackedByteArray = _password_hash(password, str(record.get("salt", "")), rounds)
    if not Crypto.new().constant_time_compare(expected, actual):
        return "Incorrect account name or password."
    var saved: Dictionary = _load_profile(key)
    if saved.is_empty():
        return "Local profile data is missing."
    active_username = key
    profile = saved
    profile_changed.emit()
    mailbox_changed.emit()
    return ""


func sign_out() -> void:
    active_username = ""
    profile = {}
    profile_changed.emit()
    mailbox_changed.emit()


func is_logged_in() -> bool:
    return not active_username.is_empty()


func get_username() -> String:
    return active_username


func challenge_save_path() -> String:
    if not is_logged_in():
        return LEGACY_CHALLENGE_SAVE
    var record: Dictionary = accounts.get(active_username, {})
    return storage_root.path_join("challenge_" + str(record.get("id", "unknown")) + ".cfg")


func feature_save_path(feature: String) -> String:
    # Keep profile-owned game saves separate from shared language and sound settings.
    if not is_logged_in() or not ["arcade", "coursework", "coins", "activities", "ddl_story", "leisure", "relationships"].has(feature):
        return ""
    var record: Dictionary = accounts.get(active_username, {})
    var path: String = storage_root.path_join("features").path_join(
        str(record.get("id", "unknown")) + "-" + feature + ".cfg")
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())) != OK:
        push_warning("Unable to create account feature save directory")
    return path


func sync_source_xp(source_id: String, cumulative_xp: int) -> int:
    # Imported XP is monotonic; relogging cannot replay the same reward.
    if not is_logged_in() or source_id.is_empty() or cumulative_xp < 0:
        return 0
    var totals: Dictionary = profile.get("source_xp_totals", {})
    var already: int = maxi(0, int(totals.get(source_id, 0)))
    if cumulative_xp <= already:
        return 0
    var old_level: int = int(level_progress()["level"])
    var gain: int = mini(1000000000 - maxi(0, int(profile.get("xp", 0))), cumulative_xp - already)
    totals[source_id] = cumulative_xp
    profile["source_xp_totals"] = totals
    profile["xp"] = mini(1000000000, maxi(0, int(profile.get("xp", 0))) + gain)
    var level: int = int(level_progress()["level"])
    if level > old_level:
        _append_inbox("Campus Office", "Level up! LV %d" % level,
            "New campus adventure rank unlocked. Keep exploring UTown!")
    if not _save_profile():
        push_warning("Unable to save feature XP checkpoint")
        return 0
    profile_changed.emit()
    if level > old_level:
        mailbox_changed.emit()
    return gain


func _migrate_legacy_progress() -> void:
    # Preserve pre-account offline progress for the first registered profile only.
    # The source save is never modified and later accounts never inherit it.
    var old_saves: Dictionary = {
        "arcade": "user://nus3d_arcade_progress.cfg",
        "coursework": "user://nus3d_coursework.cfg",
        "coins": "user://nus3d_coins.cfg",
        "activities": "user://nus3d_campus_activities.cfg",
        "ddl_story": "user://nus3d_ddl_story.cfg",
        "leisure": "user://nus3d_leisure.cfg"
    }
    for feature in old_saves.keys():
        var old_path: String = str(old_saves[feature])
        var account_path: String = feature_save_path(str(feature))
        if account_path.is_empty() or not FileAccess.file_exists(old_path) or FileAccess.file_exists(account_path):
            continue
        var result: Error = DirAccess.copy_absolute(
            ProjectSettings.globalize_path(old_path),
            ProjectSettings.globalize_path(account_path))
        if result != OK:
            push_warning("Legacy offline progress was left intact for " + str(feature))
    var destination: String = challenge_save_path()
    if FileAccess.file_exists(LEGACY_CHALLENGE_SAVE) and not FileAccess.file_exists(destination):
        var status: Error = DirAccess.copy_absolute(
            ProjectSettings.globalize_path(LEGACY_CHALLENGE_SAVE),
            ProjectSettings.globalize_path(destination)
        )
        if status != OK:
            push_warning("Old Field Notes save was left untouched because copy failed.")


func _xp_needed(level: int) -> int:
    return 100 + 50 * (level - 1)


func level_progress() -> Dictionary:
    var remaining: int = maxi(0, int(profile.get("xp", 0)))
    var total: int = remaining
    var level: int = 1
    while level < 100 and remaining >= _xp_needed(level):
        remaining -= _xp_needed(level)
        level += 1
    return {"level": level, "into": remaining, "required": _xp_needed(level), "total": total}


func award_once(event_id: String, xp: int) -> bool:
    if not is_logged_in() or event_id.is_empty() or xp <= 0:
        return false
    var awarded: Dictionary = profile.get("awards", {})
    if awarded.has(event_id):
        return false
    var original_level: int = int(level_progress()["level"])
    awarded[event_id] = true
    profile["awards"] = awarded
    profile["xp"] = mini(1000000000, int(profile.get("xp", 0)) + xp)
    var level: int = int(level_progress()["level"])
    if level > original_level:
        _append_inbox("Campus Office", "Level up! LV %d" % level,
            "Congratulations! You reached level %d.\nKeep exploring UTown to earn more XP." % level)
    if not _save_profile():
        push_warning("Could not save XP progress.")
        return false
    profile_changed.emit()
    if level > original_level:
        mailbox_changed.emit()
    return true


func _create_message(sender: String, recipient: String, subject: String, body: String) -> Dictionary:
    return {
        "id": Crypto.new().generate_random_bytes(16).hex_encode(),
        "from": sender, "to": recipient,
        "subject": subject, "body": body,
        "time": Time.get_datetime_string_from_system(),
        "read": false
    }


func _append_inbox(sender: String, subject: String, body: String) -> void:
    var inbox: Array = profile.get("inbox", [])
    inbox.push_front(_create_message(sender, active_username, subject, body))
    if inbox.size() > MAX_MAIL:
        inbox.resize(MAX_MAIL)
    profile["inbox"] = inbox


func _system_mail(subject: String, body: String) -> void:
    if is_logged_in():
        _append_inbox("Campus Office", subject, body)
        if _save_profile():
            mailbox_changed.emit()


func send_mail_to(recipient: String, subject: String, body: String) -> String:
    if not is_logged_in():
        return "Sign in to send a message."
    var target: String = _normalize(recipient)
    if not accounts.has(target):
        return "Recipient must be an account registered on this device."
    var clean_subject: String = subject.strip_edges()
    var clean_body: String = body.strip_edges()
    if clean_subject.is_empty() or clean_subject.length() > 80:
        return "Subject: 1-80 characters."
    if clean_body.is_empty() or clean_body.length() > 2000:
        return "Body: 1-2000 characters."
    var destination: Dictionary = profile if target == active_username else _load_profile(target)
    if destination.is_empty():
        return "Recipient mailbox unavailable."
    var message: Dictionary = _create_message(active_username, target, clean_subject, clean_body)
    var inbox: Array = destination.get("inbox", [])
    inbox.push_front(message)
    if inbox.size() > MAX_MAIL:
        inbox.resize(MAX_MAIL)
    destination["inbox"] = inbox
    if not _write_json(_profile_path(target), destination):
        return "Could not deliver message."
    if target == active_username:
        profile = destination
    var sent: Array = profile.get("sent", [])
    sent.push_front(message.duplicate(true))
    if sent.size() > MAX_MAIL:
        sent.resize(MAX_MAIL)
    profile["sent"] = sent
    if not _save_profile():
        push_warning("Delivered message, but sent folder could not be saved.")
    mailbox_changed.emit()
    return ""


func get_inbox() -> Array:
    var items: Array = profile.get("inbox", [])
    return items.duplicate(true)


func get_sent() -> Array:
    var items: Array = profile.get("sent", [])
    return items.duplicate(true)


func unread_count() -> int:
    var count: int = 0
    for message in get_inbox():
        if not bool(message.get("read", false)):
            count += 1
    return count


func mark_read(message_id: String) -> void:
    if not is_logged_in():
        return
    var inbox: Array = profile.get("inbox", [])
    for i in range(inbox.size()):
        var message: Dictionary = inbox[i]
        if str(message.get("id", "")) == message_id and not bool(message.get("read", false)):
            message["read"] = true
            inbox[i] = message
            profile["inbox"] = inbox
            if _save_profile():
                mailbox_changed.emit()
            return


func delete_message(message_id: String) -> void:
    if not is_logged_in():
        return
    var inbox: Array = profile.get("inbox", [])
    for i in range(inbox.size()):
        if str(inbox[i].get("id", "")) == message_id:
            inbox.remove_at(i)
            profile["inbox"] = inbox
            if _save_profile():
                mailbox_changed.emit()
            return


func save_tour_ids(ids: Array) -> void:
    if not is_logged_in():
        return
    profile["tour_ids"] = ids.duplicate()
    if not _save_profile():
        push_warning("Could not save local exploration progress.")
