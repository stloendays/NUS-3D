extends Node
class_name NUS3DStoryCampaign
## Independent, per-account side quests and endings; existing world scripts are read-only.
## Player choices are fictional game narrative, never changes to real course records.

signal campaign_changed

const DATA_PATH: String = "res://data/story_campaign.json"
const MAX_ARCHIVE: int = 12

var account_store: NUS3DAccountStore
var game_world: Node3D
var catalogue: Dictionary = {}
var state: Dictionary = {}
var scan_timer: float = 0.0


func _ready() -> void:
    if not FileAccess.file_exists(DATA_PATH):
        push_error("NUS3D story campaign JSON missing")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("NUS3D story campaign JSON is invalid")
        return
    catalogue = parsed
    if int(catalogue.get("schema_version", 0)) != 1:
        push_error("Unsupported NUS3D campaign schema")
        catalogue.clear()


func _empty_state(history: Array = [], run_number: int = 1) -> Dictionary:
    return {
        "schema_version": 1,
        "run_number": run_number,
        "events": {},
        "selections": {},
        "stats": {"kindness": 0, "integrity": 0, "stress": 0},
        "history": history.duplicate(true),
        "ending": ""
    }


func _save_path() -> String:
    if account_store == null or not account_store.is_logged_in():
        return ""
    var account: Dictionary = account_store.accounts.get(account_store.get_username(), {})
    var account_id: String = str(account.get("id", ""))
    if account_id.is_empty():
        return ""
    return account_store.storage_root.path_join("campaign_" + account_id + ".json")


func _read_save() -> Dictionary:
    var path: String = _save_path()
    if path.is_empty() or not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    return parsed


func _save() -> bool:
    var path: String = _save_path()
    if path.is_empty():
        return false
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())) != OK:
        push_warning("Campaign save directory could not be made")
        return false
    var temp: String = path + ".tmp"
    var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
    if file == null:
        push_warning("Campaign save file could not be opened")
        return false
    file.store_string(JSON.stringify(state, "  ") + "\n")
    file.flush()
    file.close()
    var result: Error = DirAccess.rename_absolute(
        ProjectSettings.globalize_path(temp),
        ProjectSettings.globalize_path(path)
    )
    if result != OK:
        push_warning("Campaign save file could not be committed")
    return result == OK


func begin_for_account() -> void:
    if account_store == null or not account_store.is_logged_in():
        return
    # Conversations from another account must never satisfy this profile's quests.
    DialogueBank.reset_session()
    var saved: Dictionary = _read_save()
    if int(saved.get("schema_version", -1)) != 1 or \
        typeof(saved.get("events", null)) != TYPE_DICTIONARY or \
        typeof(saved.get("selections", null)) != TYPE_DICTIONARY or \
        typeof(saved.get("stats", null)) != TYPE_DICTIONARY or \
        typeof(saved.get("history", null)) != TYPE_ARRAY:
        state = _empty_state()
        _save()
    else:
        state = saved
    scan_timer = 0.0
    _scan_game_events()
    campaign_changed.emit()


func close_session() -> void:
    state.clear()
    scan_timer = 0.0
    DialogueBank.reset_session()
    campaign_changed.emit()


func is_active() -> bool:
    return account_store != null and account_store.is_logged_in() and not state.is_empty()


func quest_list() -> Array:
    return catalogue.get("quests", [])


func ending_list() -> Array:
    return catalogue.get("endings", [])


func quest_by_id(quest_id: String) -> Dictionary:
    for raw in quest_list():
        var quest: Dictionary = raw
        if str(quest.get("id", "")) == quest_id:
            return quest
    return {}


func ending_by_id(ending_id: String) -> Dictionary:
    for raw in ending_list():
        var ending: Dictionary = raw
        if str(ending.get("id", "")) == ending_id:
            return ending
    return {}


func get_stats() -> Dictionary:
    return (state.get("stats", {}) as Dictionary).duplicate()


func selected_option(quest_id: String) -> String:
    var choices: Dictionary = state.get("selections", {})
    return str(choices.get(quest_id, ""))


func completed_quests() -> int:
    var choices: Dictionary = state.get("selections", {})
    return choices.size()


func current_ending() -> String:
    return str(state.get("ending", ""))


func unlocked_endings() -> Array:
    var items: Array = state.get("history", [])
    return items.duplicate()


func _event_count(pattern: String) -> int:
    var events: Dictionary = state.get("events", {})
    var prefix: bool = pattern.ends_with(":")
    var count: int = 0
    for event_id in events.keys():
        var key: String = str(event_id)
        if (prefix and key.begins_with(pattern)) or (not prefix and key == pattern):
            count += 1
    return count


func objective_progress(quest_id: String) -> Array:
    var result: Array = []
    var quest: Dictionary = quest_by_id(quest_id)
    for raw in quest.get("objectives", []):
        var objective: Dictionary = raw
        var needed: int = maxi(1, int(objective.get("count", 1)))
        result.append({
            "title": objective.get("title", {}),
            "count": mini(needed, _event_count(str(objective.get("event", "")))),
            "needed": needed
        })
    return result


func quest_ready(quest_id: String) -> bool:
    if not is_active() or not selected_option(quest_id).is_empty():
        return false
    var quest: Dictionary = quest_by_id(quest_id)
    if quest.is_empty():
        return false
    for objective in objective_progress(quest_id):
        if int(objective["count"]) < int(objective["needed"]):
            return false
    return true


func _record_event(event_id: String) -> bool:
    if not is_active() or event_id.is_empty():
        return false
    var events: Dictionary = state.get("events", {})
    if events.has(event_id):
        return false
    events[event_id] = true
    state["events"] = events
    return true


func record_event(event_id: String) -> bool:
    if not _record_event(event_id):
        return false
    if not _save():
        push_warning("Event captured in memory but not saved: " + event_id)
    campaign_changed.emit()
    return true


func choose(quest_id: String, option_id: String) -> bool:
    if not quest_ready(quest_id) or not current_ending().is_empty():
        return false
    var quest: Dictionary = quest_by_id(quest_id)
    var selected: Dictionary = {}
    for raw in quest.get("choices", []):
        var option: Dictionary = raw
        if str(option.get("id", "")) == option_id:
            selected = option
            break
    if selected.is_empty():
        return false
    var previous: Dictionary = state.duplicate(true)
    var selections: Dictionary = state.get("selections", {})
    selections[quest_id] = option_id
    state["selections"] = selections
    var stats: Dictionary = state.get("stats", {})
    var effects: Dictionary = selected.get("effects", {})
    for attribute in ["kindness", "integrity", "stress"]:
        stats[attribute] = clampi(int(stats.get(attribute, 0)) + int(effects.get(attribute, 0)), -99, 99)
    state["stats"] = stats
    if not _save():
        state = previous
        return false
    # Reward once per account, not once per story replay or changed choice.
    account_store.award_once("story:quest:" + quest_id, int(catalogue.get("settings", {}).get("quest_xp", 70)))
    campaign_changed.emit()
    return true


func finale_available() -> bool:
    if not is_active() or not current_ending().is_empty():
        return false
    var required: int = int(catalogue.get("settings", {}).get("required_quests_for_finale", 3))
    return completed_quests() >= required


func _resolve_ending(final_choice: String) -> String:
    if final_choice == "quit":
        return "ddl_blackhole"
    var stats: Dictionary = get_stats()
    var integrity: int = int(stats.get("integrity", 0))
    var kindness: int = int(stats.get("kindness", 0))
    var stress: int = int(stats.get("stress", 0))
    if integrity <= -3:
        return "integrity_alarm"
    if stress >= 4 and kindness <= 1:
        return "burnout"
    if selected_option("clock_mystery") == "break_loop" and integrity >= 2 and kindness >= 2:
        return "loop_breaker"
    if kindness >= 4 and integrity >= 2:
        return "campus_hero"
    return "ddl_survivor"


func finish(final_choice: String) -> String:
    if not finale_available() or (final_choice != "submit" and final_choice != "quit"):
        return ""
    var ending_id: String = _resolve_ending(final_choice)
    if ending_by_id(ending_id).is_empty():
        return ""
    var previous: Dictionary = state.duplicate(true)
    state["ending"] = ending_id
    var history: Array = state.get("history", [])
    if not history.has(ending_id):
        history.append(ending_id)
    if history.size() > MAX_ARCHIVE:
        history = history.slice(history.size() - MAX_ARCHIVE)
    state["history"] = history
    if not _save():
        state = previous
        return ""
    account_store.award_once("story:ending:" + ending_id, int(catalogue.get("settings", {}).get("finale_xp", 150)))
    campaign_changed.emit()
    return ending_id


func replay_story() -> bool:
    if not is_active() or current_ending().is_empty():
        return false
    var old: Dictionary = state.duplicate(true)
    state = _empty_state(unlocked_endings(), int(state.get("run_number", 1)) + 1)
    if not _save():
        state = old
        return false
    # Previously collected Field Notes/tour stops are found by the next scan;
    # only narrative decisions reset, not physical game or account progress.
    _scan_game_events()
    campaign_changed.emit()
    return true


func _scan_game_events() -> void:
    if not is_active() or game_world == null or not current_ending().is_empty():
        return
    var changed: bool = false
    var tour: UTownTour = game_world.get_node_or_null("Tour") as UTownTour
    var challenge: UTownChallenge = game_world.get_node_or_null("Challenge") as UTownChallenge
    var life: UTownCampusLife = game_world.get_node_or_null("CampusLife") as UTownCampusLife
    var weather: UTownWeather = game_world.get_node_or_null("Weather") as UTownWeather
    if tour != null:
        for stop_id in tour.discovered_ids:
            if _record_event("tour:" + str(stop_id)):
                changed = true
    if challenge != null:
        for note_id in challenge.collected_ids:
            if _record_event("note:" + str(note_id)):
                changed = true
        if challenge.sprint_last_time >= 0.0:
            if _record_event("sprint:finish"):
                changed = true
            if challenge.sprint_medal == "GOLD" and _record_event("sprint:gold"):
                changed = true
    for key in DialogueBank.seen_counts.keys():
        var speaker: String = str(key)
        if speaker.begins_with("outdoor:") and int(DialogueBank.seen_counts[key]) > 0:
            if _record_event("talk:" + speaker.trim_prefix("outdoor:")):
                changed = true
    if life != null:
        if life.interior_active and _record_event("entered:" + life.active_interior):
            changed = true
        if life.on_shuttle and _record_event("ride:shuttle"):
            changed = true
    if weather != null and weather.mode >= 3 and _record_event("weather:rain"):
        changed = true
    if changed:
        if not _save():
            push_warning("Campaign event scan could not be saved")
        campaign_changed.emit()


func _process(delta: float) -> void:
    if not is_active() or get_tree().paused:
        return
    scan_timer += delta
    if scan_timer >= 0.20:
        scan_timer = 0.0
        _scan_game_events()
