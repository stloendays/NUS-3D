extends CanvasLayer
var language_service: NUS3DGameLanguage
const UI_FONT_KIT = preload("res://scripts/utown_ui_font.gd")
## Beveled campus HUD with tactile key hints and lightweight milestone notifications.

@onready var world: UTownWorld = $"../World"
@onready var player: CharacterBody3D = $"../Player"
@onready var review: UTownViewReview = $"../ViewReview"
@onready var tour: UTownTour = $"../Tour"
@onready var challenge: UTownChallenge = $"../Challenge"
@onready var weather: UTownWeather = $"../Weather"
@onready var campus_life: UTownCampusLife = $"../CampusLife"
@onready var title_label: Label = $Info/VBox/Title
@onready var hint_label: Label = $Info/VBox/Hint
@onready var target_label: Label = $Info/VBox/Target
@onready var nearest_label: Label = $Info/VBox/Nearby
@onready var perf_label: Label = $Info/VBox/Perf
@onready var map_control: Control = $Minimap
@onready var help_label: Label = $Help
@onready var gis_card: PanelContainer = $GISCard
@onready var gis_summary: Label = $GISCard/Summary
@onready var tour_card: PanelContainer = $TourCard
@onready var tour_message: Label = $TourCard/Message
@onready var challenge_card: PanelContainer = $ChallengeCard
@onready var challenge_message: Label = $ChallengeCard/Message
@onready var campus_card: PanelContainer = $CampusCard
@onready var campus_message: Label = $CampusCard/Message

var show_full_help: bool = true
var gis_metric_count: int = 0
const FIT_BASELINE_PATH: String = "res://data/osm_fit_baseline.json"
var key_rail: NUS3DKeyRail
var help_backdrop: PanelContainer
var toast_card: PanelContainer
var toast_label: Label
var toast_remaining: float = 0.0
var _toast_tween: Tween
var _seen_tour_stops: int = 0
var _seen_notes: int = 0
var _seen_activities: int = 0
var _seen_sprint_time: float = -1.0

func _ready() -> void:
    NUS3DServices.ensure_scene_services(get_tree())
    language_service = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage
    var font_theme: Theme = UI_FONT_KIT.make_theme()
    for root_control in [$Info, $GISCard, $TourCard, $ChallengeCard, $CampusCard, $Help]:
        root_control.theme = font_theme
    _skin_card($Info, NUS3DUISkin.SURFACE, NUS3DUISkin.ACCENT, 21, 15)
    _skin_card(gis_card, NUS3DUISkin.SURFACE, NUS3DUISkin.ACCENT, 19, 13)
    _skin_card(tour_card, NUS3DUISkin.SURFACE, NUS3DUISkin.ACCENT, 21, 14)
    _skin_card(challenge_card, NUS3DUISkin.SURFACE, NUS3DUISkin.ACCENT, 19, 13)
    _skin_card(campus_card, NUS3DUISkin.SURFACE, NUS3DUISkin.ACCENT, 19, 13)
    for item in [title_label, hint_label, target_label, nearest_label, perf_label]:
        item.add_theme_color_override("font_color", NUS3DUISkin.TEXT)
    title_label.add_theme_font_size_override("font_size", 17)
    title_label.add_theme_color_override("font_color", NUS3DUISkin.TEXT)
    hint_label.add_theme_font_size_override("font_size", 12)
    hint_label.add_theme_color_override("font_color", NUS3DUISkin.DIM)
    target_label.add_theme_font_size_override("font_size", 14)
    target_label.add_theme_color_override("font_color", NUS3DUISkin.TEXT)
    nearest_label.add_theme_font_size_override("font_size", 12)
    perf_label.add_theme_font_size_override("font_size", 13)
    for label in [gis_summary, tour_message, challenge_message, campus_message]:
        label.add_theme_color_override("font_color", NUS3DUISkin.TEXT)
    challenge_message.add_theme_font_size_override("font_size", 14)
    campus_message.add_theme_font_size_override("font_size", 12)
    _make_help_overlay()
    hint_label.visible = false
    perf_label.visible = false
    _make_key_rail()
    _make_toast()
    _load_osm_fit_summary()
    sync_feedback_state()
    language_service.language_changed.connect(_apply_language)
    _apply_language(language_service.locale)


func _help_text() -> String:
    if language_service.is_chinese():
        return "WASD 移动  Shift 冲刺  Space 跳跃  B 骑车  X 校车  I 进出室内  L 楼层  Q 对话\n[P] 作业手册  [Shift+P] 学院  [K] 接/交任务  [U] 老师  [LMB] 扔玩具\n[O] 商店  [Z] 金币  [N] 食堂外送  [H] DDL  [Shift+H] 多结局  [Tab] 课后社团  [J] 邮箱  [F8] 专业考试  [F11] 联机/画质  [F12] 管理员  [Ctrl+F6] 午夜追逐\n[M] 地图  [Y] 天气  [T] 时段  [F7] 拍照  [F9] 声音  [F1] 帮助"
    return "WASD move  Shift sprint  Space jump  B bike  X shuttle  I indoors  L floor  Q talk\n[P] coursework  [Shift+P] faculty  [K] task  [U] professor  [LMB] throw toy\n[O] shop  [Z] coins  [N] food delivery  [H] DDL  [Shift+H] endings  [Tab] club  [J] mailbox  [F8] major exams  [F11] LAN/graphics  [F12] admin  [Ctrl+F6] Night Shift\n[M] map  [Y] weather  [T] time  [F7] photo  [F9] sound  [F1] help"


func _apply_language(_locale: String) -> void:
    language_service.apply_static_ui(title_label)
    help_label.text = _help_text()
    _load_osm_fit_summary()
    if language_service.is_chinese():
        gis_summary.text = language_service.game_text(gis_summary.text)
    _process(0.0)


func sync_feedback_state() -> void:
    # Account/profile restores are not new player actions and should not trigger reward toasts.
    _seen_tour_stops = tour.discovered_ids.size()
    _seen_notes = challenge.collected_ids.size()
    _seen_activities = campus_life.visited_activities.size()
    _seen_sprint_time = challenge.sprint_last_time
    toast_remaining = 0.0
    if toast_card != null:
        toast_card.hide()


func _skin_card(card: PanelContainer, background: Color, accent: Color, radius: int, padding: int) -> void:
    # All HUD cards share the lighter glass surface even when legacy callers
    # still provide old dark-color arguments.
    card.add_theme_stylebox_override("panel", NUS3DUISkin.glass(accent, maxi(radius, 19), padding))


func _make_help_overlay() -> void:
    # Keep the original HUD/Help path for existing scenes and tests.
    help_backdrop = PanelContainer.new()
    help_backdrop.name = "HelpBackdrop"
    help_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    help_backdrop.anchor_left = 0.16
    help_backdrop.anchor_right = 0.84
    help_backdrop.anchor_top = 1.0
    help_backdrop.anchor_bottom = 1.0
    help_backdrop.offset_top = -257.0
    help_backdrop.offset_bottom = -64.0
    help_backdrop.add_theme_stylebox_override("panel", NUS3DUISkin.glass(Color("#67AABC"), 24, 16, true))
    add_child(help_backdrop)
    move_child(help_backdrop, help_label.get_index())
    help_label.anchor_left = 0.18
    help_label.anchor_right = 0.82
    help_label.anchor_top = 1.0
    help_label.anchor_bottom = 1.0
    help_label.offset_left = 0.0
    help_label.offset_top = -245.0
    help_label.offset_right = 0.0
    help_label.offset_bottom = -76.0
    help_label.text = _help_text()
    help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    help_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    help_label.add_theme_color_override("font_color", NUS3DUISkin.TEXT)
    help_label.add_theme_font_size_override("font_size", 15)
    show_full_help = false
    help_label.visible = false
    help_backdrop.visible = false


func _make_key_rail() -> void:
    key_rail = NUS3DKeyRail.new()
    add_child(key_rail)


func _make_toast() -> void:
    toast_card = PanelContainer.new()
    toast_card.name = "FeedbackToast"
    toast_card.anchor_left = 0.5
    toast_card.anchor_right = 0.5
    toast_card.offset_left = -265.0
    toast_card.offset_right = 265.0
    toast_card.offset_top = 306.0
    toast_card.offset_bottom = 358.0
    toast_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    toast_card.add_theme_stylebox_override("panel", NUS3DUISkin.glass(Color("#54AFA0"), 20, 11, true))
    add_child(toast_card)
    toast_label = Label.new()
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    toast_label.add_theme_font_size_override("font_size", 17)
    toast_label.add_theme_color_override("font_color", NUS3DUISkin.TEXT)
    toast_card.add_child(toast_label)
    toast_card.hide()


func _play_ui_sound(effect: String) -> void:
    var service: NUS3DUISound = get_node_or_null("/root/UISound") as NUS3DUISound
    if service != null:
        service.play_ui(effect)


func _show_toast(message: String, effect: String = "confirm") -> void:
    toast_label.text = message
    toast_remaining = 2.7
    if _toast_tween != null and _toast_tween.is_running():
        _toast_tween.kill()
    toast_card.show()
    toast_card.modulate.a = 0.0
    toast_card.scale = Vector2(0.96, 0.96)
    toast_card.pivot_offset = toast_card.size * 0.5
    _toast_tween = create_tween()
    _toast_tween.set_parallel(true)
    _toast_tween.tween_property(toast_card, "modulate:a", 1.0, 0.14)
    _toast_tween.tween_property(toast_card, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _play_ui_sound(effect)


func _update_notices(delta: float) -> void:
    if toast_remaining > 0.0:
        toast_remaining -= delta
        if toast_remaining <= 0.0:
            toast_card.hide()
    var stops: int = tour.discovered_ids.size()
    if stops > _seen_tour_stops:
        _show_toast("Waypoint discovered  |  %d / %d" % [stops, tour.stops.size()])
    _seen_tour_stops = stops
    var notes: int = challenge.collected_ids.size()
    if notes > _seen_notes:
        _show_toast("Field note collected  |  %d / %d" % [notes, challenge.items.size()], "reward")
    _seen_notes = notes
    var activities: int = campus_life.visited_activities.size()
    if activities > _seen_activities:
        _show_toast("Campus activity completed", "confirm")
    _seen_activities = activities
    if challenge.sprint_last_time >= 0.0 and challenge.sprint_last_time != _seen_sprint_time:
        _show_toast("Campus Sprint finished  |  " + challenge.sprint_medal, "reward")
    _seen_sprint_time = challenge.sprint_last_time


func _load_osm_fit_summary() -> void:
    gis_metric_count = 0
    if not FileAccess.file_exists(FIT_BASELINE_PATH):
        push_warning("GIS diagnostic card is missing its source-derived metric snapshot")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIT_BASELINE_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("GIS diagnostic card JSON is invalid")
        return
    var source: Dictionary = parsed
    if str(source.get("status", "")) != "M2.3-static-review-snapshot-not-surveyed":
        push_warning("GIS metric source lacks explicit provisional status")
        return
    var lines: PackedStringArray = PackedStringArray()
    lines.append("OSM  /  ESTIMATED 3D MODEL")
    for row in source.get("metrics", []):
        if typeof(row) != TYPE_DICTIONARY:
            continue
        var name: String = str(row.get("id", ""))
        if name != "ERC" and name != "SRC":
            continue
        lines.append("%s   IoU %.1f%%  |  OSM cover %.1f%%" % [
            name, 100.0 * float(row.get("intersection_over_union", 0.0)),
            float(row.get("osm_area_covered_pct", 0.0))])
        gis_metric_count += 1
    lines.append("2D data comparison; NOT real accuracy")
    lines.append("OpenStreetMap contributors  |  ODbL")
    gis_summary.text = "\n".join(lines)

func _process(delta: float) -> void:
    gis_card.visible = world.osm_reference_visible and gis_metric_count == 2
    hint_label.text = "M2 %s [F2] | %s [T] | OSM %s [F6] | Notes [C] | Sprint [V]" % ["ON" if world.m2_details_visible else "OFF", world.lighting_name(), "ON" if world.osm_reference_visible else "OFF"]
    if tour.completed:
        target_label.text = "Tour complete  |  %d/%d stops  [G replay]" % [tour.discovered_ids.size(), tour.stops.size()]
    elif not tour.current_stop().is_empty():
        var destination: Dictionary = tour.current_stop()
        target_label.text = "Tour %d/%d  |  %s  %.0f m" % [tour.discovered_ids.size(), tour.stops.size(), str(destination["id"]), tour.current_distance_m()]
    else:
        target_label.text = "Tour unavailable"
    var nearby: Dictionary = world.nearest_landmark(player.global_position)
    nearest_label.text = "Near: %s  (%.0f m)" % [nearby["name"], float(nearby["distance"])]
    perf_label.text = "FPS %d  |  X %+.0f / N %+.0f m" % [Engine.get_frames_per_second(), player.global_position.x, -player.global_position.z]
    var message: String = tour.card_text()
    tour_card.visible = not message.is_empty()
    tour_message.text = message
    var localized: bool = language_service.is_chinese()
    if localized:
        hint_label.text = language_service.hud_hint(world)
        target_label.text = language_service.hud_target(tour)
        nearest_label.text = language_service.game_text(nearest_label.text)
        perf_label.text = language_service.game_text(perf_label.text)
        tour_message.text = language_service.tour_card(tour)
    var nearby_note: bool = false
    for index in range(challenge.items.size()):
        var note_id: String = challenge.item_id(index)
        if challenge.is_item_collected(note_id):
            continue
        if player.global_position.distance_to(challenge.item_world_position(index)) < 12.0:
            nearby_note = true
            break
    # A compact contextual game HUD instead of always-on developer dashboards.
    challenge_card.visible = show_full_help or challenge.sprint_active or challenge.feedback_remaining > 0.0 or nearby_note
    var challenge_text: String = language_service.challenge_card(challenge) if localized else challenge.status_text()
    if show_full_help:
        challenge_message.text = challenge_text
    elif nearby_note:
        challenge_message.text = ("附近有校园笔记 [C] 收集" if localized else "FIELD NOTE nearby  [C] collect")
    elif challenge.sprint_active:
        challenge_message.text = challenge_text.get_slice("\n", 0)
    else:
        challenge_message.text = challenge.feedback_message
    var weather_info: String = language_service.weather_card(weather) if localized else weather.status_text()
    campus_message.text = weather_info.get_slice("\n", 0)
    if show_full_help or (campus_life.message_time > 0.0 and not campus_life.message.is_empty()):
        var life_info: String = language_service.game_text(campus_life.status_text()) if localized else campus_life.status_text()
        campus_message.text += "\n" + life_info
    campus_card.visible = true
    _update_notices(delta)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_M:
            map_control.visible = not map_control.visible
        elif event.keycode == KEY_F1:
            show_full_help = not show_full_help
            help_label.visible = show_full_help
            help_backdrop.visible = show_full_help
            hint_label.visible = show_full_help
            perf_label.visible = show_full_help
        elif event.keycode == KEY_F7:
            visible = not visible
            world.set_navigation_markers_visible(visible)
            challenge.set_markers_visible(visible)
            var coursework: UTownCoursework = get_parent().get_node_or_null("Coursework") as UTownCoursework
            if coursework != null:
                coursework.set_markers_visible(visible)
            var coursework_ui: UTownCourseworkUI = get_parent().get_node_or_null("CourseworkUI") as UTownCourseworkUI
            if coursework_ui != null:
                coursework_ui.set_hud_enabled(visible)
