extends Node
class_name NUS3DGraphicsSettings
## Device-local graphics settings. No account/profile or multiplayer state is stored here.
## Godot 4.4 GL Compatibility uses bilinear 3D scaling (not Forward+ FSR).
signal preset_changed(preset: String)

const SAVE_PATH: String = "user://nus3d_graphics.cfg"
const ORDER = ["low", "balanced", "high", "ultra"]
const PROFILES: Dictionary = {
    "low": {"fps": 30, "scale": 0.70, "minimum": 0.60, "far": 520.0,
        "rain": 180, "streaks": 65, "shadows": false, "details": false},
    "balanced": {"fps": 60, "scale": 0.85, "minimum": 0.70, "far": 850.0,
        "rain": 500, "streaks": 130, "shadows": true, "details": true},
    "high": {"fps": 60, "scale": 1.0, "minimum": 0.80, "far": 1100.0,
        "rain": 1100, "streaks": 220, "shadows": true, "details": true},
    "ultra": {"fps": 120, "scale": 1.0, "minimum": 0.85, "far": 1250.0,
        "rain": 1100, "streaks": 220, "shadows": true, "details": true}
}

var preset: String = "high"
var adaptive_resolution: bool = true
var render_scale: float = 1.0
var _game: Node3D
var _sampling_elapsed: float = 0.0
var _fast_samples: int = 0


func _enter_tree() -> void:
    var config: ConfigFile = ConfigFile.new()
    if config.load(SAVE_PATH) == OK:
        var requested: String = str(config.get_value("graphics", "preset", "high"))
        if PROFILES.has(requested):
            preset = requested
        adaptive_resolution = bool(config.get_value("graphics", "adaptive_resolution", true))
    if OS.get_cmdline_user_args().has("--nus3d-low-spec"):
        preset = "low"
    render_scale = float(PROFILES[preset]["scale"])


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _apply_display()


func is_low_spec() -> bool:
    return preset == "low"


func next_preset() -> String:
    return ORDER[(ORDER.find(preset) + 1) % ORDER.size()]


func set_preset(value: String) -> bool:
    if not PROFILES.has(value):
        return false
    preset = value
    render_scale = float(PROFILES[preset]["scale"])
    _sampling_elapsed = 0.0
    _fast_samples = 0
    _save()
    _apply_display()
    if is_instance_valid(_game):
        apply_to_game(_game)
    preset_changed.emit(preset)
    return true


func set_adaptive_resolution(value: bool) -> void:
    adaptive_resolution = value
    render_scale = float(PROFILES[preset]["scale"])
    _save()
    _apply_display()
    preset_changed.emit(preset)


func _save() -> void:
    var config: ConfigFile = ConfigFile.new()
    config.set_value("graphics", "preset", preset)
    config.set_value("graphics", "adaptive_resolution", adaptive_resolution)
    config.save(SAVE_PATH)


func _apply_display() -> void:
    # Never cap automated headless / fixed-FPS simulation.
    if DisplayServer.get_name() == "headless":
        Engine.max_fps = 0
        return
    var settings: Dictionary = PROFILES[preset]
    Engine.max_fps = int(settings["fps"])
    var viewport: Viewport = get_viewport()
    if viewport != null:
        viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
        viewport.scaling_3d_scale = clampf(render_scale, 0.5, 1.0)


func apply_to_game(target: Node3D) -> void:
    _game = target
    if not is_instance_valid(target):
        return
    var settings: Dictionary = PROFILES[preset]
    var camera: Camera3D = target.get_node_or_null("Player/Head/Camera3D") as Camera3D
    if camera != null:
        camera.far = float(settings["far"])
    var world: UTownWorld = target.get_node_or_null("World") as UTownWorld
    if world != null:
        world.set_m2_details_visible(bool(settings["details"]))
        if world.sunlight != null:
            world.sunlight.shadow_enabled = bool(settings["shadows"]) and world.lighting_mode <= 1
    var weather: UTownWeather = target.get_node_or_null("Weather") as UTownWeather
    if weather != null:
        if weather.rain != null:
            weather.rain.amount = int(settings["rain"])
        if weather.rain_multimesh != null:
            weather.rain_multimesh.visible_instance_count = int(settings["streaks"])
    var streetscape: Node3D = target.get_node_or_null("Streetscape") as Node3D
    if streetscape != null:
        streetscape.visible = bool(settings["details"])
    var polish: UTownVisualPolish = target.get_node_or_null("VisualPolish") as UTownVisualPolish
    if polish != null:
        polish.set_process(bool(settings["details"]))
        for group in polish.facade_groups:
            group.visible = bool(settings["details"])
        for room_id in polish.indoor_finish_groups:
            var group: Node3D = polish.indoor_finish_groups[room_id]
            group.visible = bool(settings["details"])


func _process(delta: float) -> void:
    if not adaptive_resolution or DisplayServer.get_name() == "headless" or get_tree().paused:
        return
    _sampling_elapsed += delta
    if _sampling_elapsed < 1.5:
        return
    _sampling_elapsed = 0.0
    var current_fps: float = Engine.get_frames_per_second()
    if current_fps < 5.0:
        return
    var settings: Dictionary = PROFILES[preset]
    var target_fps: float = float(settings["fps"])
    var base_scale: float = float(settings["scale"])
    var lower_limit: float = float(settings["minimum"])
    if current_fps < target_fps * 0.85 and render_scale > lower_limit + 0.001:
        render_scale = maxf(lower_limit, render_scale - 0.05)
        _fast_samples = 0
        _apply_display()
    elif current_fps >= target_fps * 0.98 and render_scale < base_scale - 0.001:
        _fast_samples += 1
        if _fast_samples >= 3:
            render_scale = minf(base_scale, render_scale + 0.05)
            _fast_samples = 0
            _apply_display()
    else:
        _fast_samples = 0


func status_text() -> String:
    return "%s  |  %d FPS cap  |  %.0f%% 3D" % [
        preset.capitalize(), int(PROFILES[preset]["fps"]), render_scale * 100.0]
