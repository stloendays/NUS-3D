extends Node
class_name NUS3DDialogueBank
var language_service: NUS3DGameLanguage
## Bilingual authored comedy for fictional campus NPCs, independent of quest logic.
## Repeat suppression and fixed introductions are runtime-only; XP/saves untouched.

const DATA_PATH: String = "res://data/npc_dialogue.json"

var characters: Dictionary = {}
var seen_counts: Dictionary = {}
var last_english_line: Dictionary = {}


func _ready() -> void:
    language_service = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage
    _load()


func _load() -> void:
    if not FileAccess.file_exists(DATA_PATH):
        push_error("NUS3D NPC dialogue file missing")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("NPC dialogue is not valid JSON")
        return
    if int(parsed.get("schema_version", 0)) != 1 or parsed.get("unofficial_fictional", false) != true:
        push_error("NPC dialogue schema or fictional-content marker is missing")
        return
    var rows: Variant = parsed.get("characters", {})
    characters = rows if typeof(rows) == TYPE_DICTIONARY else {}


func count() -> int:
    var total: int = 0
    for category in characters.keys():
        var entries: Dictionary = characters[category]
        total += entries.size()
    return total


func has_character(scope: String, name: String) -> bool:
    var entries: Dictionary = characters.get(scope, {})
    return entries.has(name)


func role_for(scope: String, name: String) -> String:
    var entries: Dictionary = characters.get(scope, {})
    var info: Dictionary = entries.get(name, {})
    var roles: Dictionary = info.get("role", {})
    return str(roles.get(language_service.locale, roles.get("en", "")))


func _text(row: Dictionary) -> String:
    return str(row.get(language_service.locale, row.get("en", "")))


func next_line(scope: String, name: String, weather_mode: int = 0, force_random: bool = false) -> String:
    var entries: Dictionary = characters.get(scope, {})
    var character: Dictionary = entries.get(name, {})
    if character.is_empty():
        return language_service.localized_text(
            "这个 NPC 忙着赶 DDL，还没想好要说什么。", "This NPC is still thinking of a line before the deadline.")

    var id: String = scope + ":" + name
    var talked: int = int(seen_counts.get(id, 0))
    var fixed: Array = character.get("fixed", [])
    var random_lines: Array = character.get("random", [])
    var rain_lines: Array = character.get("weather", [])
    var pool: Array = []

    if not force_random and talked < fixed.size():
        pool = [fixed[talked]]
    elif weather_mode >= 3 and not rain_lines.is_empty() and randi_range(0, 3) == 0:
        pool = rain_lines
    elif not force_random and not fixed.is_empty() and randi_range(0, 4) == 0:
        pool = fixed
    else:
        pool = random_lines if not random_lines.is_empty() else fixed

    if pool.is_empty():
        return ""
    var previous: String = str(last_english_line.get(id, ""))
    var candidates: Array = []
    for raw in pool:
        if typeof(raw) != TYPE_DICTIONARY:
            continue
        var choice: Dictionary = raw
        if str(choice.get("en", "")) != previous or pool.size() == 1:
            candidates.append(choice)
    if candidates.is_empty():
        candidates = pool.duplicate()
    var picked: Dictionary = candidates[randi_range(0, candidates.size() - 1)]
    if not force_random:
        seen_counts[id] = talked + 1
    last_english_line[id] = str(picked.get("en", ""))
    return _text(picked)


func reset_session() -> void:
    seen_counts.clear()
    last_english_line.clear()
