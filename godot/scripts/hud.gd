extends CanvasLayer
## Minimal status panel with a conceptual walking loop, labels and a toggleable map.

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

func _ready() -> void:
    var panel: PanelContainer = $Info
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.12, 0.15, 0.86)
    style.set_corner_radius_all(9)
    style.content_margin_left = 15.0
    style.content_margin_right = 15.0
    style.content_margin_top = 12.0
    style.content_margin_bottom = 12.0
    panel.add_theme_stylebox_override("panel", style)
    for item in [title_label, hint_label, target_label, nearest_label, perf_label]:
        item.add_theme_color_override("font_color", Color.html("#f0f2ed"))
    title_label.add_theme_font_size_override("font_size", 20)
    hint_label.add_theme_font_size_override("font_size", 12)
    target_label.add_theme_font_size_override("font_size", 17)
    nearest_label.add_theme_font_size_override("font_size", 14)
    perf_label.add_theme_font_size_override("font_size", 13)
    help_label.add_theme_color_override("font_color", Color.html("#283b43"))
    var gis_style: StyleBoxFlat = StyleBoxFlat.new()
    gis_style.bg_color = Color(0.09, 0.16, 0.21, 0.92)
    gis_style.set_corner_radius_all(10)
    gis_style.content_margin_left = 13.0
    gis_style.content_margin_top = 12.0
    gis_style.content_margin_right = 13.0
    gis_style.content_margin_bottom = 12.0
    gis_card.add_theme_stylebox_override("panel", gis_style)
    var tour_style: StyleBoxFlat = StyleBoxFlat.new()
    tour_style.bg_color = Color(0.08, 0.16, 0.18, 0.93)
    tour_style.set_corner_radius_all(10)
    tour_style.content_margin_left = 16.0
    tour_style.content_margin_right = 16.0
    tour_style.content_margin_top = 13.0
    tour_style.content_margin_bottom = 13.0
    tour_card.add_theme_stylebox_override("panel", tour_style)
    tour_message.add_theme_color_override("font_color", Color.html("#f3f1e8"))
    var challenge_style: StyleBoxFlat = StyleBoxFlat.new()
    challenge_style.bg_color = Color(0.12, 0.12, 0.19, 0.94)
    challenge_style.set_corner_radius_all(10)
    challenge_style.content_margin_left = 14.0
    challenge_style.content_margin_right = 14.0
    challenge_style.content_margin_top = 11.0
    challenge_style.content_margin_bottom = 11.0
    challenge_card.add_theme_stylebox_override("panel", challenge_style)
    challenge_message.add_theme_color_override("font_color", Color.html("#eeeaf7"))
    challenge_message.add_theme_font_size_override("font_size", 14)
    var campus_style: StyleBoxFlat = StyleBoxFlat.new()
    campus_style.bg_color = Color(0.08, 0.14, 0.18, 0.92)
    campus_style.set_corner_radius_all(10)
    campus_style.content_margin_left = 13.0
    campus_style.content_margin_right = 13.0
    campus_style.content_margin_top = 10.0
    campus_style.content_margin_bottom = 10.0
    campus_card.add_theme_stylebox_override("panel", campus_style)
    campus_message.add_theme_color_override("font_color", Color.html("#edf3ef"))
    campus_message.add_theme_font_size_override("font_size", 13)
    _load_osm_fit_summary()
    GameLanguage.language_changed.connect(_apply_language)
    _apply_language(GameLanguage.locale)


func _apply_language(_locale: String) -> void:
    GameLanguage.apply_static_ui(title_label)
    GameLanguage.apply_static_ui(help_label)
    _load_osm_fit_summary()
    if GameLanguage.is_chinese():
        gis_summary.text = GameLanguage.game_text(gis_summary.text)
    _process(0.0)

func _load_osm_fit_summary() -> void:
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

func _process(_delta: float) -> void:
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
    challenge_message.text = challenge.status_text()
    challenge_card.visible = not challenge_message.text.is_empty()
    campus_message.text = weather.status_text() + "\n" + campus_life.status_text()
    campus_card.visible = true
    if GameLanguage.is_chinese():
        hint_label.text = GameLanguage.hud_hint(world)
        target_label.text = GameLanguage.hud_target(tour)
        nearest_label.text = GameLanguage.game_text(nearest_label.text)
        perf_label.text = GameLanguage.game_text(perf_label.text)
        tour_message.text = GameLanguage.tour_card(tour)
        challenge_message.text = GameLanguage.challenge_card(challenge)
        campus_message.text = GameLanguage.weather_card(weather) + "\n" + GameLanguage.game_text(campus_life.status_text())

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_M:
            map_control.visible = not map_control.visible
        elif event.keycode == KEY_F1:
            show_full_help = not show_full_help
            help_label.visible = show_full_help
        elif event.keycode == KEY_F7:
            visible = not visible
            world.set_navigation_markers_visible(visible)
            challenge.set_markers_visible(visible)
