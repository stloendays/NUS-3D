extends Node
class_name UTownIntro
## M3.7 opening cinematic, generated completely within the Godot world.
## No external video, trademarked NUS assets, survey coordinates or paid textures.
## A camera flyover builds from the already-existing four schematic waypoints.

const DURATION_S: float = 12.0
const BEAT_COUNT: int = 4
const TAGLINES: Array[String] = [
    "欢迎来到 UTown  /  WELCOME TO CAMPUS",
    "COURSEWORK  /  组员说他马上到",
    "DDL WARNING  /  23:59 正在逼近",
    "选择学院，开始这场荒诞的校园冒险"
]
const SUBTITLES: Array[String] = [
    "阳光，草坪，食堂……一切看起来都很平静。",
    "最后编辑时间：3天前。队友状态：仍在路上。",
    "提交网站：ERROR 502。教授：『记得按时交。』",
    "跑步、骑车、做作业，当然也可以……先摸鱼。"
]
const BADGES: Array[String] = [
    "01 / ARRIVAL",
    "02 / GROUP PROJECT",
    "03 / APOCALYPSE",
    "04 / NEW SEMESTER"
]

@onready var world: UTownWorld = $"../World"
@onready var player: UTownPlayer = $"../Player"
@onready var campus_life: UTownCampusLife = $"../CampusLife"
@onready var coursework: UTownCoursework = $"../Coursework"
@onready var coursework_ui: UTownCourseworkUI = $"../CourseworkUI"
@onready var hud: CanvasLayer = $"../HUD"

var playing: bool = false
var elapsed: float = 0.0
var preview_frozen: bool = false
var current_beat: int = 0
var cinematic_camera: Camera3D
var overlay: CanvasLayer
var shade: ColorRect
var top_band: ColorRect
var bottom_band: ColorRect
var title_label: Label
var eyebrow_label: Label
var badge_label: Label
var subtitle_label: Label
var alert_label: Label
var progress: ProgressBar
var skip_button: Button
var key_frames: Array[Dictionary] = []
var hud_was_visible: bool = true
var previous_camera: Camera3D
var opening_completed: bool = false

func _ready() -> void:
    _build_camera()
    _build_overlay()
    # The packaged Windows self-test only verifies scene integrity and never
    # needs a cinematic. Dedicated Godot smoke tests exercise it explicitly.
    if OS.get_cmdline_user_args().has("--nus3d-self-test"):
        playing = false
        overlay.visible = false
        return
    start_intro()

func _build_camera() -> void:
    cinematic_camera = Camera3D.new()
    cinematic_camera.name = "IntroFlyoverCamera"
    cinematic_camera.fov = 68.0
    cinematic_camera.near = 0.08
    cinematic_camera.far = 800.0
    add_child(cinematic_camera)
    var route: Array[Vector3] = world.route_points
    if route.size() < 4:
        push_warning("Opening flyover: missing schematic waypoint route; using nearby fallbacks")
        var home: Vector3 = player.global_position
        route = [
            home,
            home + Vector3(-25.0, 0.0, -30.0),
            home + Vector3(-50.0, 0.0, 20.0),
            home + Vector3(30.0, 0.0, 30.0)
        ]
    var green: Vector3 = route[0]
    var erc: Vector3 = route[1]
    var src: Vector3 = route[2]
    var plaza: Vector3 = route[3]
    # All tracking offsets are artistic camera framing, not mapped locations.
    key_frames = [
        {"position":green + Vector3(42.0, 30.0, 41.0), "look":green + Vector3(0.0, 2.0, 0.0), "fov":68.0},
        {"position":green + Vector3(12.0, 19.0, 18.0), "look":erc + Vector3(0.0, 5.0, 0.0), "fov":62.0},
        {"position":erc + Vector3(19.0, 17.0, 28.0), "look":erc + Vector3(0.0, 5.0, -5.0), "fov":60.0},
        {"position":src + Vector3(22.0, 20.0, -23.0), "look":src + Vector3(0.0, 4.0, 0.0), "fov":63.0},
        {"position":plaza + Vector3(23.0, 19.0, 22.0), "look":plaza + Vector3(0.0, 1.5, 0.0), "fov":60.0},
        {"position":green + Vector3(9.0, 7.0, 13.0), "look":green + Vector3(0.0, 1.4, 0.0), "fov":78.0}
    ]

func _style_label(node: Label, size: int, tint: String) -> void:
    node.add_theme_font_size_override("font_size", size)
    node.add_theme_color_override("font_color", Color.html(tint))
    node.add_theme_color_override("font_outline_color", Color(0.015, 0.032, 0.047, 0.93))
    node.add_theme_constant_override("outline_size", 5)
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_overlay() -> void:
    overlay = CanvasLayer.new()
    overlay.name = "OpeningCinematicOverlay"
    overlay.layer = 30
    add_child(overlay)
    var root_control := Control.new()
    root_control.name = "CinematicScreen"
    root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(root_control)

    var wash := ColorRect.new()
    wash.name = "CinematicContrastWash"
    wash.color = Color(0.018, 0.028, 0.047, 0.17)
    wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root_control.add_child(wash)

    top_band = ColorRect.new()
    top_band.name = "LetterboxTop"
    top_band.color = Color(0.02, 0.035, 0.047, 0.91)
    top_band.anchor_right = 1.0
    top_band.offset_bottom = 83.0
    top_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root_control.add_child(top_band)

    bottom_band = ColorRect.new()
    bottom_band.name = "LetterboxBottom"
    bottom_band.color = Color(0.02, 0.035, 0.047, 0.92)
    bottom_band.anchor_top = 1.0
    bottom_band.anchor_right = 1.0
    bottom_band.anchor_bottom = 1.0
    bottom_band.offset_top = -116.0
    bottom_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root_control.add_child(bottom_band)

    eyebrow_label = Label.new()
    eyebrow_label.name = "UnofficialEyebrow"
    eyebrow_label.text = "FAN-MADE UTOWN  /  AN UNOFFICIAL CAMPUS ADVENTURE"
    eyebrow_label.anchor_left = 0.05
    eyebrow_label.anchor_top = 0.0
    eyebrow_label.anchor_right = 0.72
    eyebrow_label.offset_top = 23.0
    eyebrow_label.offset_bottom = 57.0
    _style_label(eyebrow_label, 16, "#afc7ce")
    root_control.add_child(eyebrow_label)

    title_label = Label.new()
    title_label.name = "OpeningTitle"
    title_label.text = "NUS-3D"
    title_label.anchor_left = 0.08
    title_label.anchor_top = 0.17
    title_label.anchor_right = 0.88
    title_label.anchor_bottom = 0.17
    title_label.offset_bottom = 118.0
    _style_label(title_label, 76, "#f5ede2")
    root_control.add_child(title_label)

    badge_label = Label.new()
    badge_label.name = "CinematicBeat"
    badge_label.text = BADGES[0]
    badge_label.anchor_left = 0.08
    badge_label.anchor_top = 0.355
    badge_label.anchor_right = 0.73
    badge_label.offset_bottom = 32.0
    _style_label(badge_label, 16, "#ffc46c")
    root_control.add_child(badge_label)

    subtitle_label = Label.new()
    subtitle_label.name = "OpeningSubtitle"
    subtitle_label.text = TAGLINES[0]
    subtitle_label.anchor_left = 0.08
    subtitle_label.anchor_top = 0.405
    subtitle_label.anchor_right = 0.90
    subtitle_label.offset_bottom = 68.0
    subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _style_label(subtitle_label, 28, "#f5f4e7")
    root_control.add_child(subtitle_label)

    alert_label = Label.new()
    alert_label.name = "CourseworkComedyCaption"
    alert_label.text = SUBTITLES[0]
    alert_label.anchor_left = 0.065
    alert_label.anchor_top = 1.0
    alert_label.anchor_right = 0.75
    alert_label.anchor_bottom = 1.0
    alert_label.offset_top = -104.0
    alert_label.offset_bottom = -56.0
    alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _style_label(alert_label, 20, "#e4e4dc")
    root_control.add_child(alert_label)

    progress = ProgressBar.new()
    progress.name = "CinematicProgress"
    progress.min_value = 0.0
    progress.max_value = DURATION_S
    progress.value = 0.0
    progress.show_percentage = false
    progress.anchor_left = 0.06
    progress.anchor_top = 1.0
    progress.anchor_right = 0.94
    progress.anchor_bottom = 1.0
    progress.offset_top = -28.0
    progress.offset_bottom = -20.0
    progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.20, 0.30, 0.34, 0.85)
    bg.set_corner_radius_all(4)
    progress.add_theme_stylebox_override("background", bg)
    var fg := StyleBoxFlat.new()
    fg.bg_color = Color.html("#ffc46c")
    fg.set_corner_radius_all(4)
    progress.add_theme_stylebox_override("fill", fg)
    root_control.add_child(progress)

    skip_button = Button.new()
    skip_button.name = "SkipIntro"
    skip_button.text = "跳过 / SPACE · ESC"
    skip_button.anchor_left = 1.0
    skip_button.anchor_right = 1.0
    skip_button.offset_left = -225.0
    skip_button.offset_right = -25.0
    skip_button.offset_top = 20.0
    skip_button.offset_bottom = 60.0
    skip_button.focus_mode = Control.FOCUS_NONE
    skip_button.pressed.connect(skip_intro)
    root_control.add_child(skip_button)

    shade = ColorRect.new()
    shade.name = "IntroFade"
    shade.color = Color(0.005, 0.013, 0.024, 1.0)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root_control.add_child(shade)

func start_intro() -> void:
    if playing:
        return
    if cinematic_camera == null or key_frames.size() < 2:
        return
    previous_camera = get_viewport().get_camera_3d()
    hud_was_visible = hud.visible
    hud.visible = false
    coursework_ui.begin_intro()
    coursework.modal_open = true
    player.movement_locked = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    elapsed = 0.0
    current_beat = 0
    preview_frozen = false
    opening_completed = false
    overlay.visible = true
    playing = true
    cinematic_camera.make_current()
    _update_cinematic_visuals()

func _update_cinematic_visuals() -> void:
    if cinematic_camera == null or key_frames.size() < 2:
        return
    var progress_fraction: float = clampf(elapsed / DURATION_S, 0.0, 1.0)
    var scaled: float = progress_fraction * float(key_frames.size() - 1)
    var frame_index: int = clampi(int(floor(scaled)), 0, key_frames.size() - 2)
    var fraction: float = clampf(scaled - float(frame_index), 0.0, 1.0)
    fraction = fraction * fraction * (3.0 - 2.0 * fraction)
    var previous: Dictionary = key_frames[frame_index]
    var upcoming: Dictionary = key_frames[frame_index + 1]
    cinematic_camera.global_position = (previous["position"] as Vector3).lerp(upcoming["position"], fraction)
    cinematic_camera.fov = lerpf(float(previous["fov"]), float(upcoming["fov"]), fraction)
    var focus: Vector3 = (previous["look"] as Vector3).lerp(upcoming["look"], fraction)
    if cinematic_camera.global_position.distance_to(focus) > 0.25:
        cinematic_camera.look_at(focus, Vector3.UP)
    var upcoming_beat: int = mini(BEAT_COUNT - 1, int(elapsed / (DURATION_S / float(BEAT_COUNT))))
    if upcoming_beat != current_beat:
        current_beat = upcoming_beat
        badge_label.text = BADGES[current_beat]
        badge_label.add_theme_color_override("font_color", Color.html("#ff7971" if current_beat == 2 else "#ffc46c"))
        subtitle_label.text = TAGLINES[current_beat]
        alert_label.text = SUBTITLES[current_beat]
    alert_label.text = SUBTITLES[current_beat]
    progress.value = elapsed
    # Soft cinematic fade-in/out, with no disorienting instant camera cuts.
    var intro_alpha: float = 1.0 - clampf(elapsed / 1.0, 0.0, 1.0)
    var outro_alpha: float = clampf((elapsed - (DURATION_S - 0.6)) / 0.6, 0.0, 1.0)
    var shade_color: Color = shade.color
    shade_color.a = maxf(intro_alpha, outro_alpha)
    shade.color = shade_color
    var beat_elapsed: float = fposmod(elapsed, DURATION_S / float(BEAT_COUNT))
    var sub_alpha: float = clampf(beat_elapsed * 3.0, 0.0, 1.0)
    subtitle_label.modulate.a = sub_alpha
    alert_label.modulate.a = clampf((beat_elapsed - 0.2) * 2.1, 0.0, 1.0)
    title_label.modulate.a = clampf(elapsed * 1.65, 0.0, 1.0)
    # A restrained scale ease makes the original title feel like an entrance,
    # not a static text overlay.
    var title_zoom: float = 1.0 + 0.10 * pow(1.0 - clampf(elapsed / 2.0, 0.0, 1.0), 2.0)
    title_label.scale = Vector2.ONE * title_zoom

func _process(delta: float) -> void:
    if not playing or preview_frozen:
        return
    elapsed = minf(elapsed + delta, DURATION_S)
    _update_cinematic_visuals()
    if elapsed >= DURATION_S:
        finish_intro()

func seek_preview(seconds: float) -> void:
    # Deterministic screenshot capture; never starts/stops the user's missions.
    if not playing:
        return
    preview_frozen = true
    elapsed = clampf(seconds, 0.0, DURATION_S - 0.05)
    _update_cinematic_visuals()

func resume_preview() -> void:
    preview_frozen = false

func skip_intro() -> void:
    finish_intro()

func finish_intro() -> void:
    if not playing:
        return
    playing = false
    opening_completed = true
    preview_frozen = false
    overlay.visible = false
    if previous_camera != null and is_instance_valid(previous_camera):
        previous_camera.make_current()
    else:
        player.camera.make_current()
    hud.visible = hud_was_visible
    coursework_ui.end_intro()

func _input(event: InputEvent) -> void:
    if not playing:
        return
    # Block all gameplay actions while the opening film owns the camera,
    # including mouse-look. Skip remains available through three keys or UI.
    if event is InputEventKey:
        var key: InputEventKey = event as InputEventKey
        if key.pressed and not key.echo and key.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
            skip_intro()
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton:
        # A click anywhere can skip; crucially it must not steal the cursor
        # into player mouse-look before a user can reach the skip button.
        var click: InputEventMouseButton = event as InputEventMouseButton
        if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
            skip_intro()
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion:
        get_viewport().set_input_as_handled()
