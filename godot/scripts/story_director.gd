extends Node
class_name NUS3DStoryDirector
## Standalone, offline storyline. Never changes world physics, original quests or saves.
## The only gameplay inputs are observed achievements and deliberate journal choices.

signal campaign_changed
signal ending_unlocked(ending_id: String)

const STORY_FILE: String = "res://data/story_campaign.json"
const REQUIRED_SCHEMAVERSION: int = 1
const MAX_ARCHIVE_COUNT: int = 1000

var accounts: NUS3DAccountStore
var language_service: NUS3DGameLanguage
var game: Node3D
var tour: UTownTour
var challenge: UTownChallenge
var campus: UTownCampusLife
var weather: UTownWeather
var story: Dictionary = {}
var events: Dictionary = {}
var decisions: Dictionary = {}
var archive: Dictionary = {}
var ending_id: String = ""
var run_number: int = 1
var kindness: int = 0
var integrity: int = 0
var stress: int = 0
var save_path: String = ""
var active: bool = false

var layer: CanvasLayer
var cover: Control
var heading: Label
var overview: Label
var subtitle: Label
var listing: ItemList
var details: Label
var action_list: VBoxContainer
var restart_button: Button
var mode: String = "quests"
var selected_id: String = ""
var visible_ids: PackedStringArray = PackedStringArray()


func configure(store: NUS3DAccountStore, world_scene: Node3D) -> void:
    accounts = store
    game = world_scene
    tour = world_scene.get_node("Tour") as UTownTour
    challenge = world_scene.get_node("Challenge") as UTownChallenge
    campus = world_scene.get_node("CampusLife") as UTownCampusLife
    weather = world_scene.get_node("Weather") as UTownWeather


func _ready() -> void:
    language_service = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage
    process_mode = Node.PROCESS_MODE_ALWAYS
    _load_story()
    _build_ui()
    language_service.language_changed.connect(_on_language_changed)
    if campus != null:
        campus.talked_to.connect(_on_talked_to)
    hide_journal_silently()


func _load_story() -> void:
    if not FileAccess.file_exists(STORY_FILE):
        push_error("Missing campaign: " + STORY_FILE)
        return
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORY_FILE))
    if typeof(raw) != TYPE_DICTIONARY:
        push_error("Campaign must be a JSON object")
        return
    if int(raw.get("schema_version", 0)) != REQUIRED_SCHEMAVERSION:
        push_error("Unsupported campaign schema version")
        return
    story = raw


func _local(value: Variant) -> String:
    if typeof(value) == TYPE_DICTIONARY:
        var row: Dictionary = value
        return str(row.get(language_service.locale, row.get("en", "")))
    return str(value)


func _btn(caption: String, callback: Callable) -> Button:
    var button: Button = Button.new()
    button.text = caption
    button.custom_minimum_size.y = 36
    button.pressed.connect(callback)
    return button


func _label(caption: String, font_size: int, tint: Color = Color.WHITE) -> Label:
    var result: Label = Label.new()
    result.text = caption
    result.add_theme_color_override("font_color", tint)
    result.add_theme_font_size_override("font_size", font_size)
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return result


func _build_ui() -> void:
    layer = CanvasLayer.new()
    layer.name = "CampaignUI"
    layer.layer = 35
    layer.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(layer)
    cover = Control.new()
    cover.name = "StoryJournal"
    cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cover.mouse_filter = Control.MOUSE_FILTER_STOP
    layer.add_child(cover)
    var dim: ColorRect = ColorRect.new()
    dim.color = Color(0.015, 0.035, 0.065, 0.96)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cover.add_child(dim)
    var center: CenterContainer = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cover.add_child(center)
    var panel: PanelContainer = PanelContainer.new()
    panel.custom_minimum_size = Vector2(930, 540)
    var skin: StyleBoxFlat = StyleBoxFlat.new()
    skin.bg_color = Color.html("#102431")
    skin.border_color = Color.html("#538d98")
    skin.set_border_width_all(1)
    skin.set_corner_radius_all(16)
    skin.set_content_margin_all(18.0)
    panel.add_theme_stylebox_override("panel", skin)
    center.add_child(panel)
    var frame: VBoxContainer = VBoxContainer.new()
    frame.add_theme_constant_override("separation", 9)
    panel.add_child(frame)
    var top: HBoxContainer = HBoxContainer.new()
    frame.add_child(top)
    heading = _label("", 25, Color.html("#d8eff4"))
    top.add_child(heading)
    top.add_child(_btn("×", close_journal))
    overview = _label("", 13, Color.html("#b4d0d5"))
    frame.add_child(overview)
    frame.add_child(HSeparator.new())
    var tabs: HBoxContainer = HBoxContainer.new()
    frame.add_child(tabs)
    tabs.add_child(_btn(_local({"zh": "任务", "en": "Quests"}), func() -> void: _set_mode("quests")))
    tabs.add_child(_btn(_local({"zh": "结局图鉴", "en": "Endings"}), func() -> void: _set_mode("endings")))
    subtitle = _label("", 13, Color.html("#9bd6db"))
    subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    tabs.add_child(subtitle)
    var body: HBoxContainer = HBoxContainer.new()
    body.custom_minimum_size.y = 330
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 16)
    frame.add_child(body)
    listing = ItemList.new()
    listing.custom_minimum_size.x = 315
    listing.item_selected.connect(_on_item_selected)
    body.add_child(listing)
    var right: VBoxContainer = VBoxContainer.new()
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_child(right)
    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    right.add_child(scroll)
    var information: VBoxContainer = VBoxContainer.new()
    information.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(information)
    details = _label("", 16, Color.html("#e6eff1"))
    details.custom_minimum_size.x = 520
    information.add_child(details)
    action_list = VBoxContainer.new()
    action_list.add_theme_constant_override("separation", 8)
    information.add_child(action_list)
    restart_button = _btn("", restart_story)
    restart_button.hide()
    frame.add_child(restart_button)
    cover.hide()


func _on_language_changed(_new: String) -> void:
    if active and cover != null and cover.visible:
        _render()


func _reset_run() -> void:
    events = {}
    decisions = {}
    ending_id = ""
    kindness = 0
    integrity = 0
    stress = 0


func _read_state(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _persist() -> bool:
    if not active or save_path.is_empty():
        return false
    var data: Dictionary = {
        "schema_version": 1, "run_number": run_number,
        "events": events, "decisions": decisions,
        "archive": archive, "ending": ending_id,
        "kindness": kindness, "integrity": integrity, "stress": stress
    }
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path.get_base_dir())) != OK:
        push_error("Cannot create story save directory")
        return false
    var temp_path: String = save_path + ".tmp"
    var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        push_error("Cannot open story save file")
        return false
    file.store_string(JSON.stringify(data, "  ") + "\n")
    file.flush()
    file.close()
    var result: Error = DirAccess.rename_absolute(
        ProjectSettings.globalize_path(temp_path),
        ProjectSettings.globalize_path(save_path)
    )
    if result != OK:
        push_error("Cannot finalize story save")
        return false
    return true


func load_account() -> void:
    hide_journal_silently()
    active = accounts != null and accounts.is_logged_in()
    if not active:
        save_path = ""
        _reset_run()
        archive = {}
        return
    # The account's random save ID, not username, isolates the campaign.
    save_path = accounts.challenge_save_path().get_basename() + "_story.json"
    _reset_run()
    archive = {}
    var loaded: Dictionary = _read_state(save_path)
    if int(loaded.get("schema_version", 0)) == 1:
        events = loaded.get("events", {}) if typeof(loaded.get("events", {})) == TYPE_DICTIONARY else {}
        decisions = loaded.get("decisions", {}) if typeof(loaded.get("decisions", {})) == TYPE_DICTIONARY else {}
        # JSON.decode returns numeric counters as floats. Normalize to bounded
        # integers so the in-memory ending gallery survives round trips exactly.
        archive = {}
        var loaded_archive: Variant = loaded.get("archive", {})
        if typeof(loaded_archive) == TYPE_DICTIONARY:
            for raw_ending_id in loaded_archive.keys():
                var stored_id: String = str(raw_ending_id)
                var value: Variant = loaded_archive[raw_ending_id]
                if get_ending(stored_id).is_empty() or (typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT):
                    continue
                var restored_count: int = clampi(int(value), 0, MAX_ARCHIVE_COUNT)
                if restored_count > 0:
                    archive[stored_id] = restored_count
        ending_id = str(loaded.get("ending", ""))
        kindness = clampi(int(loaded.get("kindness", 0)), -15, 15)
        integrity = clampi(int(loaded.get("integrity", 0)), -15, 15)
        stress = clampi(int(loaded.get("stress", 0)), 0, 15)
        run_number = maxi(1, int(loaded.get("run_number", 1)))
    else:
        run_number = 1
        _persist()
    _scan_world_events()
    campaign_changed.emit()


func on_logout() -> void:
    hide_journal_silently()
    active = false
    save_path = ""
    _reset_run()
    archive = {}


func record_event(event_id: String) -> bool:
    if not active or not ending_id.is_empty() or event_id.is_empty() or events.has(event_id):
        return false
    events[event_id] = true
    if not _persist():
        events.erase(event_id)
        return false
    campaign_changed.emit()
    return true


func _on_talked_to(character_name: String) -> void:
    record_event("talk:" + character_name)


func _scan_world_events() -> void:
    if not active or not ending_id.is_empty():
        return
    if tour != null:
        for stop_id in tour.discovered_ids:
            record_event("tour:" + str(stop_id))
    if challenge != null:
        for note_id in challenge.collected_ids:
            record_event("note:" + str(note_id))
        if challenge.sprint_best_time >= 0.0 or challenge.sprint_last_time >= 0.0:
            record_event("sprint:finish")
        if challenge.sprint_last_time >= 0.0 and challenge.sprint_medal == "GOLD":
            record_event("sprint:gold")
    if campus != null:
        if campus.on_shuttle:
            record_event("ride:shuttle")
        if campus.interior_active:
            record_event("entered:" + campus.active_interior)
    if weather != null and weather.mode >= 3:
        record_event("weather:rain")


func _process(_delta: float) -> void:
    if active and not get_tree().paused:
        _scan_world_events()


func event_count(pattern: String) -> int:
    var matches: int = 0
    for item in events.keys():
        var name: String = str(item)
        if pattern.ends_with(":"):
            if name.begins_with(pattern):
                matches += 1
        elif name == pattern:
            matches += 1
    return matches


func _quests() -> Array:
    return story.get("quests", [])


func _endings() -> Array:
    return story.get("endings", [])


func get_quest(quest_id: String) -> Dictionary:
    for item in _quests():
        var quest: Dictionary = item
        if str(quest.get("id", "")) == quest_id:
            return quest
    return {}


func get_ending(candidate: String) -> Dictionary:
    for item in _endings():
        var ending: Dictionary = item
        if str(ending.get("id", "")) == candidate:
            return ending
    return {}


func objective_complete(quest: Dictionary) -> bool:
    for raw in quest.get("objectives", []):
        var objective: Dictionary = raw
        if event_count(str(objective.get("event", ""))) < int(objective.get("count", 1)):
            return false
    return true


func completed_count() -> int:
    return decisions.size()


func final_available() -> bool:
    var minimum: int = int(story.get("settings", {}).get("required_quests_for_finale", 3))
    return active and ending_id.is_empty() and completed_count() >= minimum


func choose_quest(quest_id: String, choice_id: String) -> bool:
    if not active or not ending_id.is_empty() or decisions.has(quest_id):
        return false
    var quest: Dictionary = get_quest(quest_id)
    if quest.is_empty() or not objective_complete(quest):
        return false
    var option: Dictionary = {}
    for candidate in quest.get("choices", []):
        if str(candidate.get("id", "")) == choice_id:
            option = candidate
            break
    if option.is_empty():
        return false
    decisions[quest_id] = choice_id
    var effects: Dictionary = option.get("effects", {})
    kindness = clampi(kindness + int(effects.get("kindness", 0)), -15, 15)
    integrity = clampi(integrity + int(effects.get("integrity", 0)), -15, 15)
    stress = clampi(stress + int(effects.get("stress", 0)), 0, 15)
    if not _persist():
        push_warning("Quest choice could not be saved")
    if accounts != null:
        accounts.award_once("story:quest:" + quest_id, int(story.get("settings", {}).get("quest_xp", 70)))
    campaign_changed.emit()
    if cover.visible:
        _render()
    return true


func resolve_ending(final_choice: String) -> String:
    if not final_available() or (final_choice != "submit" and final_choice != "quit"):
        return ""
    var result: String = "ddl_survivor"
    if final_choice == "quit":
        result = "ddl_blackhole"
    elif integrity <= -3:
        result = "integrity_alarm"
    elif stress >= 5 and kindness <= 1:
        result = "burnout"
    elif str(decisions.get("clock_mystery", "")) == "break_loop" and integrity >= 3 and kindness >= 3:
        result = "loop_breaker"
    elif kindness >= 5 and integrity >= 2:
        result = "campus_hero"
    if get_ending(result).is_empty():
        push_error("Campaign resolved to an unknown ending: " + result)
        return ""
    ending_id = result
    archive[result] = mini(MAX_ARCHIVE_COUNT, int(archive.get(result, 0)) + 1)
    if not _persist():
        push_warning("Ending gallery could not be persisted")
    if accounts != null:
        accounts.award_once("story:ending:" + result, int(story.get("settings", {}).get("finale_xp", 150)))
    ending_unlocked.emit(result)
    campaign_changed.emit()
    if cover.visible:
        selected_id = "ending:" + result
        mode = "endings"
        _render()
    return result


func restart_story() -> bool:
    if not active or ending_id.is_empty():
        return false
    _reset_run()
    run_number += 1
    if not _persist():
        push_warning("Story restart could not be saved")
    _scan_world_events()
    campaign_changed.emit()
    if cover.visible:
        mode = "quests"
        selected_id = ""
        _render()
    return true


func unlocked_endings() -> int:
    return archive.size()


func open_journal() -> void:
    if not active or cover.visible:
        return
    get_tree().paused = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    cover.show()
    _render()


func close_journal() -> void:
    if not cover.visible:
        return
    cover.hide()
    if active:
        get_tree().paused = false
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func hide_journal_silently() -> void:
    if cover != null:
        cover.hide()


func _set_mode(value: String) -> void:
    if value != "quests" and value != "endings":
        return
    mode = value
    selected_id = ""
    _render()


func _clear_actions() -> void:
    for old in action_list.get_children():
        action_list.remove_child(old)
        old.queue_free()


func _status(quest: Dictionary) -> String:
    var id: String = str(quest.get("id", ""))
    if decisions.has(id):
        return _local({"zh": "已完成", "en": "Done"})
    if objective_complete(quest):
        return _local({"zh": "可选择", "en": "Ready"})
    return _local({"zh": "进行中", "en": "In progress"})


func _render() -> void:
    if not active or cover == null:
        return
    heading.text = _local({"zh": "NUS-3D 任务手册 / 多结局", "en": "NUS-3D  QUEST JOURNAL / ENDINGS"})
    overview.text = _local({
        "zh": "第 %d 周目    支线 %d/%d    诚信 %+d    人缘 %+d    压力 %d    已发现结局 %d/%d",
        "en": "Run %d    Quests %d/%d    Integrity %+d    Kindness %+d    Stress %d    Endings %d/%d"
    }) % [run_number, completed_count(), _quests().size(), integrity, kindness, stress, unlocked_endings(), _endings().size()]
    subtitle.text = _local({"zh": "[P] 返回校园  ·  所有选择影响终章", "en": "[P] Back to campus · Your choices shape the finale"})
    restart_button.text = _local({"zh": "开启新周目（保留等级与结局图鉴）", "en": "New run (keep levels and ending gallery)"})
    restart_button.visible = not ending_id.is_empty()
    var previous: String = selected_id
    listing.clear()
    visible_ids.clear()
    if mode == "quests":
        for raw in _quests():
            var quest: Dictionary = raw
            var id: String = str(quest["id"])
            visible_ids.append(id)
            listing.add_item("%s  |  %s" % [_status(quest), _local(quest.get("title", {}))])
        if ending_id.is_empty():
            visible_ids.append("finale")
            listing.add_item(_local({"zh":"终章（已开放）" if final_available() else "终章（完成三条支线解锁）",
                "en":"Finale (ready)" if final_available() else "Finale (finish 3 side quests)"}))
    else:
        for raw in _endings():
            var ending: Dictionary = raw
            var id: String = str(ending.get("id", ""))
            visible_ids.append("ending:" + id)
            listing.add_item(_local(ending.get("title", {})) if archive.has(id) else _local({"zh":"???  尚未解锁", "en":"???  Locked"}))
    if not visible_ids.has(previous):
        previous = visible_ids[0] if not visible_ids.is_empty() else ""
    selected_id = previous
    var selected_index: int = visible_ids.find(selected_id)
    if selected_index >= 0:
        listing.select(selected_index)
    _render_details()


func _render_details() -> void:
    _clear_actions()
    if selected_id == "finale":
        var finale: Dictionary = story.get("finale", {})
        details.text = _local(finale.get("title", {})) + "\n\n" + _local(finale.get("intro", {}))
        if not ending_id.is_empty():
            details.text += "\n\n" + _local({"zh":"本周目已完结，请重开收集其他结局。","en":"This run is over. Start a new run to discover more endings."})
        elif final_available():
            for raw in finale.get("choices", []):
                var choice: Dictionary = raw
                var choice_id: String = str(choice.get("id", ""))
                action_list.add_child(_btn(_local(choice.get("title", {})),
                    func() -> void: resolve_ending(choice_id)))
        else:
            details.text += "\n\n" + _local({"zh":"先完成任意三条支线任务。","en":"Complete any three side quests first."})
        return
    if selected_id.begins_with("ending:"):
        var eid: String = selected_id.trim_prefix("ending:")
        var ending: Dictionary = get_ending(eid)
        if archive.has(eid):
            details.text = _local(ending.get("title", {})) + "\n\n" + _local(ending.get("story", {}))
            details.text += "\n\n" + _local({"zh":"结局已收入图鉴。","en":"Ending added to your gallery."})
        else:
            details.text = _local({"zh":"???  尚未解锁", "en":"???  Locked"}) + "\n\n" + _local(ending.get("hint", {}))
        return
    var quest: Dictionary = get_quest(selected_id)
    if quest.is_empty():
        details.text = ""
        return
    var lines: PackedStringArray = PackedStringArray()
    lines.append(_local(quest.get("title", {})))
    lines.append("")
    lines.append(_local(quest.get("intro", {})))
    lines.append("")
    for raw in quest.get("objectives", []):
        var objective: Dictionary = raw
        var expected: int = int(objective.get("count", 1))
        var found: int = mini(expected, event_count(str(objective.get("event", ""))))
        lines.append("[%d/%d] %s" % [found, expected, _local(objective.get("title", {}))])
    if decisions.has(selected_id):
        var id: String = str(decisions[selected_id])
        for raw in quest.get("choices", []):
            var chosen: Dictionary = raw
            if str(chosen.get("id", "")) == id:
                lines.append("")
                lines.append(_local(chosen.get("result", {})))
                break
        lines.append("")
        lines.append(_local({"zh":"此支线已结算；重开剧情后可改选。","en":"Quest settled. Try the other choice in a new run."}))
    elif not ending_id.is_empty():
        lines.append("")
        lines.append(_local({"zh":"本周目已完结。","en":"This run has ended."}))
    elif objective_complete(quest):
        lines.append("")
        lines.append(_local({"zh":"所有目标达成！做个决定吧：", "en":"Objectives complete! Choose your response:"}))
        for raw in quest.get("choices", []):
            var choice: Dictionary = raw
            var quest_id: String = selected_id
            var choice_id: String = str(choice.get("id", ""))
            action_list.add_child(_btn(_local(choice.get("title", {})),
                func() -> void: choose_quest(quest_id, choice_id)))
    details.text = "\n".join(lines)


func _on_item_selected(index: int) -> void:
    if index >= 0 and index < visible_ids.size():
        selected_id = visible_ids[index]
        _render_details()


func _input(event: InputEvent) -> void:
    if cover == null or not cover.visible:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if (event.keycode == KEY_H and event.shift_pressed) or event.keycode == KEY_ESCAPE:
            close_journal()
            get_viewport().set_input_as_handled()
