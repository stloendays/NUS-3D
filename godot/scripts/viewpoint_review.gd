extends Node
class_name UTownViewReview
## Source-photo inspection views. GPS, heading, height and geometry require verification.

const VIEWPOINTS_PATH: String = "res://data/viewpoints.json"
const DEFAULT_FOV: float = 78.0

@onready var world: UTownWorld = $"../World"
@onready var player: CharacterBody3D = $"../Player"
@onready var head: Node3D = $"../Player/Head"
@onready var camera: Camera3D = $"../Player/Head/Camera3D"

var viewpoints: Array[Dictionary] = []
var current_index: int = -1

func _ready() -> void:
    if not FileAccess.file_exists(VIEWPOINTS_PATH):
        push_error("Missing source photo camera registry")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(VIEWPOINTS_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Camera registry is not JSON object")
        return
    var data: Dictionary = parsed
    for item in data.get("viewpoints", []):
        if typeof(item) == TYPE_DICTIONARY:
            viewpoints.append(item)
    if viewpoints.is_empty():
        push_error("No review viewpoints found")

func viewpoint_count() -> int:
    return viewpoints.size()

func current_name() -> String:
    if current_index < 0 or current_index >= viewpoints.size():
        return "free roam"
    return str(viewpoints[current_index].get("label", "reference"))

func select_view(index: int) -> bool:
    if index < 0 or index >= viewpoints.size() or world.layout.is_empty():
        return false
    var view: Dictionary = viewpoints[index]
    player.global_position = world.lonlat_to_world(float(view["lon"]), float(view["lat"])) + Vector3(0.0, 0.18, 0.0)
    player.velocity = Vector3.ZERO
    # Engine -Z is north. Positive real-world compass heading needs NEGATIVE yaw.
    # Magnetic / unspecified EXIF headings remain uncorrected, so only approximate.
    player.rotation = Vector3(0.0, -deg_to_rad(float(view["heading_deg"])), 0.0)
    head.rotation = Vector3(deg_to_rad(float(view.get("pitch_deg", 0.0))), 0.0, 0.0)
    camera.fov = float(view.get("fov_deg", DEFAULT_FOV))
    current_index = index
    return true

func cycle_view() -> void:
    if current_index + 1 >= viewpoints.size():
        current_index = -1
        player.call("reset_player")
        camera.fov = DEFAULT_FOV
        return
    select_view(current_index + 1)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F3:
            cycle_view()
        elif event.keycode == KEY_F4:
            capture_review()

func capture_review() -> void:
    if DisplayServer.get_name() == "headless":
        push_warning("F4 screenshot requires a graphical renderer")
        return
    var directory: String = "user://review_captures"
    var created: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
    if created != OK:
        push_error("Failed to create visual-review directory")
        return
    await RenderingServer.frame_post_draw
    var bitmap: Image = get_viewport().get_texture().get_image()
    if bitmap == null or bitmap.is_empty():
        push_error("No rendered image available for visual-review capture")
        return
    var view_id: String = "FREE_ROAM" if current_index < 0 else str(viewpoints[current_index]["id"])
    var basename: String = "%s_%d_%d" % [view_id, int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
    var png_file: String = directory.path_join(basename + ".png")
    if bitmap.save_png(png_file) != OK:
        push_error("Could not save preview PNG")
        return
    var sidecar: Dictionary = {
        "status": "schematic-render-not-survey-verified",
        "image_file": basename + ".png",
        "viewpoint_id": view_id,
        "captured_at_utc": Time.get_datetime_string_from_system(true, true),
        "m2_visible": world.m2_details_visible,
        "provisional_eye_height_m": 1.84,
        "camera_world_xyz_m": [camera.global_position.x, camera.global_position.y, camera.global_position.z],
        "source_viewpoint": {} if current_index < 0 else viewpoints[current_index]
    }
    var report: FileAccess = FileAccess.open(directory.path_join(basename + ".json"), FileAccess.WRITE)
    if report != null:
        report.store_string(JSON.stringify(sidecar, "  ") + "\n")
        report.close()
    print("Saved original Godot review PNG: " + ProjectSettings.globalize_path(png_file))
