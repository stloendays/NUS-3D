extends CanvasLayer
## Minimal status panel with a conceptual walking loop, labels and a toggleable map.

@onready var world: UTownWorld = $"../World"
@onready var player: CharacterBody3D = $"../Player"
@onready var title_label: Label = $Info/VBox/Title
@onready var hint_label: Label = $Info/VBox/Hint
@onready var target_label: Label = $Info/VBox/Target
@onready var nearest_label: Label = $Info/VBox/Nearby
@onready var perf_label: Label = $Info/VBox/Perf
@onready var map_control: Control = $Minimap
@onready var help_label: Label = $Help

var target_index: int = 0
var show_full_help: bool = true
var walked_loops: int = 0

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

func _process(_delta: float) -> void:
    if world.route_points.is_empty():
        return
    var destination: Vector3 = world.route_points[target_index]
    var separation_m: float = Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(destination.x, destination.z))
    if separation_m < 10.0:
        target_index = (target_index + 1) % world.route_points.size()
        if target_index == 0:
            walked_loops += 1
        destination = world.route_points[target_index]
        separation_m = Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(destination.x, destination.z))
    target_label.text = "Next: %s  |  %.0f m" % [world.route_names[target_index], separation_m]
    var nearby: Dictionary = world.nearest_landmark(player.global_position)
    nearest_label.text = "Near: %s  (%.0f m)" % [nearby["name"], float(nearby["distance"])]
    perf_label.text = "FPS %d  |  Loop %d  |  X %+.0f / N %+.0f m" % [Engine.get_frames_per_second(), walked_loops, player.global_position.x, -player.global_position.z]

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_M:
            map_control.visible = not map_control.visible
        elif event.keycode == KEY_F1:
            show_full_help = not show_full_help
            help_label.visible = show_full_help
