extends CanvasLayer
class_name NUS3DBootLoading
## Lightweight standalone launcher. Loads actual PackedScenes in Godot's
## threaded ResourceLoader and keeps a visible overlay through world init.
## Self-test executables bypass the UI to preserve the prior runtime contract.

const WORLD_PATH: String = "res://scenes/main.tscn"
const SHELL_PATH: String = "res://scenes/game_shell.tscn"
const TIP_PATH: String = "res://data/loading_tips.json"
const STAGE_IDLE: int = 0
const STAGE_WORLD: int = 1
const STAGE_SHELL: int = 2
const STAGE_INITIALIZING: int = 3
const STAGE_DONE: int = 4
const STAGE_ERROR: int = 5
const WORLD_WEIGHT: float = 0.83
const SHELL_WEIGHT: float = 0.12
const TIP_ROTATION_SECONDS: float = 4.2

@export var auto_start: bool = true

var stage: int = STAGE_IDLE
var latest_progress: float = 0.0
var error_message: String = ""
var world_resource: PackedScene
var shell_resource: PackedScene
var loaded_shell: NUS3DGameShell
var tips: Array[Dictionary] = []
var tip_index: int = 0
var tip_clock: float = 0.0
var ui_refresh_clock: float = 0.0
var self_test_bypassed: bool = false

var progress_bar: ProgressBar
var percentage: Label
var stage_label: Label
var tip_title: Label
var tip_keys: Label
var tip_description: Label
var tip_counter: Label
var retry_button: Button
var card: PanelContainer
var root_control: Control
var language_service: NUS3DGameLanguage

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 90
    _read_tips()
    language_service = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage
    _build_ui()
    _show_tip(0)
    get_viewport().size_changed.connect(_resize_card)
    _resize_card()
    if not auto_start:
        return
    # Preserve exported --nus3d-self-test behavior: it needs the original
    # game_shell.tscn and its export runtime checks, not a loading modal.
    if OS.get_cmdline_user_args().has("--nus3d-self-test"):
        self_test_bypassed = true
        call_deferred("_bypass_self_test")
        return
    start_loading()

func _read_tips() -> void:
    tips.clear()
    if FileAccess.file_exists(TIP_PATH):
        var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TIP_PATH))
        if typeof(data) == TYPE_DICTIONARY and int(data.get("schema_version", 0)) == 1:
            var entries: Variant = data.get("tips", [])
            if typeof(entries) == TYPE_ARRAY:
                for entry in entries:
                    if typeof(entry) != TYPE_DICTIONARY:
                        continue
                    if str(entry.get("en_title", "")).is_empty() or str(entry.get("zh_title", "")).is_empty():
                        continue
                    tips.append(entry)
    if tips.is_empty():
        tips.append({
            "en_title": "Explore the campus",
            "en_body": "Use WASD to move. Press F1 to see more controls.",
            "zh_title": "探索校园",
            "zh_body": "按 WASD 移动，按 F1 查看更多按键。",
            "keys": "WASD  /  F1"
        })

func _is_zh() -> bool:
    return language_service != null and language_service.is_chinese()

func _localized(chinese: String, english: String) -> String:
    return chinese if _is_zh() else english

func _label(value: String, size: int, color: String) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", Color.html(color))
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

func _build_ui() -> void:
    # CanvasLayer 90 stays above GameShell's layer 30 login while the
    # scene is synchronously instantiated (no login-screen flash).
    root_control = Control.new()
    root_control.name = "LoadingSurface"
    root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_control.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root_control)
    # No images or shaders: this intro renders even on the lowest-spec profile.
    var background := ColorRect.new()
    background.name = "FlatCampusBackdrop"
    background.color = Color.html("#172a31")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_STOP
    root_control.add_child(background)

    var canopy := ColorRect.new()
    canopy.name = "AbstractSkyBand"
    canopy.color = Color.html("#2e4b4e")
    canopy.anchor_right = 1.0
    canopy.anchor_bottom = 0.44
    canopy.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.add_child(canopy)
    var earth := ColorRect.new()
    earth.name = "CampusGroundBand"
    earth.color = Color.html("#294236")
    earth.anchor_top = 0.80
    earth.anchor_bottom = 1.0
    earth.anchor_right = 1.0
    earth.mouse_filter = Control.MOUSE_FILTER_IGNORE
    background.add_child(earth)

    var centered := CenterContainer.new()
    centered.name = "LoadingLayout"
    centered.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    centered.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root_control.add_child(centered)
    card = PanelContainer.new()
    card.name = "LoadingCard"
    card.mouse_filter = Control.MOUSE_FILTER_STOP
    var style := StyleBoxFlat.new()
    style.bg_color = Color.html("#192a32")
    style.border_color = Color.html("#56716c")
    style.set_border_width_all(1)
    style.set_corner_radius_all(14)
    style.content_margin_left = 27.0
    style.content_margin_right = 27.0
    style.content_margin_top = 23.0
    style.content_margin_bottom = 23.0
    card.add_theme_stylebox_override("panel", style)
    centered.add_child(card)

    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 11)
    card.add_child(content)

    var eyebrow := _label("UNOFFICIAL CAMPUS ARCADE   /   UTOWN", 12, "#a9bfba")
    content.add_child(eyebrow)
    var brand := _label("NUS-3D", 44, "#f5f3e8")
    content.add_child(brand)
    var tagline := _label("DDL APOCALYPSE  ·  CAMPUS LIFE  ·  BAD DECISIONS", 14, "#e2bb79")
    content.add_child(tagline)
    content.add_child(HSeparator.new())
    stage_label = _label("", 15, "#bcd4d2")
    content.add_child(stage_label)
    var progress_row := HBoxContainer.new()
    progress_row.add_theme_constant_override("separation", 14)
    content.add_child(progress_row)
    progress_bar = ProgressBar.new()
    progress_bar.name = "RealLoadingProgress"
    progress_bar.min_value = 0.0
    progress_bar.max_value = 100.0
    progress_bar.value = 0.0
    progress_bar.show_percentage = false
    progress_bar.custom_minimum_size.y = 13.0
    progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var track := StyleBoxFlat.new()
    track.bg_color = Color.html("#43595b")
    track.set_corner_radius_all(5)
    progress_bar.add_theme_stylebox_override("background", track)
    var fill := StyleBoxFlat.new()
    fill.bg_color = Color.html("#f5c46a")
    fill.set_corner_radius_all(5)
    progress_bar.add_theme_stylebox_override("fill", fill)
    progress_row.add_child(progress_bar)
    percentage = _label("0%", 15, "#f6da9a")
    percentage.custom_minimum_size.x = 55.0
    percentage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    progress_row.add_child(percentage)
    content.add_child(HSeparator.new())

    var tip_header := HBoxContainer.new()
    tip_header.add_theme_constant_override("separation", 10)
    content.add_child(tip_header)
    var tip_badge := _label("GAMEPLAY TIP", 12, "#e5b46d")
    tip_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tip_header.add_child(tip_badge)
    tip_counter = _label("", 12, "#9eb7b2")
    tip_header.add_child(tip_counter)
    tip_title = _label("", 22, "#ecf2e9")
    content.add_child(tip_title)
    tip_description = _label("", 16, "#c7d5d2")
    tip_description.custom_minimum_size.y = 72.0
    content.add_child(tip_description)
    tip_keys = _label("", 14, "#f5c46a")
    content.add_child(tip_keys)
    retry_button = Button.new()
    retry_button.text = "RETRY"
    retry_button.name = "LoadingRetry"
    retry_button.custom_minimum_size.y = 40
    retry_button.visible = false
    retry_button.pressed.connect(start_loading)
    content.add_child(retry_button)

func _resize_card() -> void:
    if card == null:
        return
    var viewport_width: float = get_viewport().get_visible_rect().size.x
    card.custom_minimum_size.x = clampf(viewport_width - 32.0, 280.0, 710.0)

func _show_tip(index: int) -> void:
    if tips.is_empty() or tip_title == null:
        return
    tip_index = posmod(index, tips.size())
    var item: Dictionary = tips[tip_index]
    tip_title.text = str(item.get("zh_title" if _is_zh() else "en_title", ""))
    tip_description.text = str(item.get("zh_body" if _is_zh() else "en_body", ""))
    tip_keys.text = str(item.get("keys", ""))
    tip_counter.text = "%02d / %02d" % [tip_index + 1, tips.size()]

func _present_progress(value: float, status: String) -> void:
    latest_progress = clampf(maxf(latest_progress, value), 0.0, 1.0)
    progress_bar.value = latest_progress * 100.0
    percentage.text = "%d%%" % int(round(latest_progress * 100.0))
    stage_label.text = status

func stage_progress(loading_stage: int, raw_fraction: float) -> float:
    var amount: float = clampf(raw_fraction, 0.0, 1.0)
    match loading_stage:
        STAGE_WORLD:
            return WORLD_WEIGHT * amount
        STAGE_SHELL:
            return WORLD_WEIGHT + SHELL_WEIGHT * amount
        STAGE_INITIALIZING:
            return WORLD_WEIGHT + SHELL_WEIGHT
        STAGE_DONE:
            return 1.0
        _:
            return 0.0

func _stage_status() -> String:
    match stage:
        STAGE_WORLD:
            return _localized("加载校园地图与建筑...", "Loading campus map and buildings...")
        STAGE_SHELL:
            return _localized("准备账号界面与游戏系统...", "Preparing login and game systems...")
        STAGE_INITIALIZING:
            return _localized("生成校园世界与人物...", "Initializing campus world and characters...")
        STAGE_DONE:
            return _localized("准备就绪，欢迎入学！", "Ready. Welcome to campus!")
        STAGE_ERROR:
            return _localized("资源加载失败。请重试。", "Asset loading failed. Please retry.")
        _:
            return _localized("正在启动...", "Starting up...")

func _bypass_self_test() -> void:
    get_tree().change_scene_to_file(SHELL_PATH)

func start_loading() -> void:
    if stage == STAGE_WORLD or stage == STAGE_SHELL or stage == STAGE_INITIALIZING:
        return
    stage = STAGE_IDLE
    world_resource = null
    shell_resource = null
    loaded_shell = null
    error_message = ""
    latest_progress = 0.0
    tip_clock = 0.0
    if retry_button != null:
        retry_button.visible = false
    _present_progress(0.0, _stage_status())
    if ResourceLoader.load_threaded_request(WORLD_PATH) != OK:
        _fail_load("Could not request campus world.")
        return
    stage = STAGE_WORLD
    _present_progress(0.0, _stage_status())

func _fail_load(reason: String) -> void:
    error_message = reason
    stage = STAGE_ERROR
    stage_label.text = _stage_status() + "  " + reason
    retry_button.visible = true
    push_warning("NUS-3D loading: " + reason)

func _process(delta: float) -> void:
    tip_clock += delta
    if tip_clock >= TIP_ROTATION_SECONDS:
        tip_clock = fposmod(tip_clock, TIP_ROTATION_SECONDS)
        _show_tip(tip_index + 1)
    if stage != STAGE_WORLD and stage != STAGE_SHELL:
        return
    ui_refresh_clock += delta
    if ui_refresh_clock < 0.06:
        return
    ui_refresh_clock = 0.0
    var path: String = WORLD_PATH if stage == STAGE_WORLD else SHELL_PATH
    var fractions: Array = []
    var status: int = ResourceLoader.load_threaded_get_status(path, fractions)
    if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
        _fail_load("Unable to read " + path.get_file())
        return
    if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
        if not fractions.is_empty():
            _present_progress(stage_progress(stage, float(fractions[0])), _stage_status())
        return
    if status != ResourceLoader.THREAD_LOAD_LOADED:
        return
    if stage == STAGE_WORLD:
        world_resource = ResourceLoader.load_threaded_get(WORLD_PATH) as PackedScene
        if world_resource == null:
            _fail_load("Campus scene is invalid.")
            return
        _present_progress(stage_progress(STAGE_WORLD, 1.0), _stage_status())
        if ResourceLoader.load_threaded_request(SHELL_PATH) != OK:
            _fail_load("Could not request login shell.")
            return
        stage = STAGE_SHELL
    else:
        shell_resource = ResourceLoader.load_threaded_get(SHELL_PATH) as PackedScene
        if shell_resource == null:
            _fail_load("Login shell is invalid.")
            return
        stage = STAGE_INITIALIZING
        _present_progress(stage_progress(stage, 0.0), _stage_status())
        call_deferred("_enter_loaded_shell")

func _enter_loaded_shell() -> void:
    if stage != STAGE_INITIALIZING or shell_resource == null:
        return
    # Render the 95% state *before* the potentially expensive first world init.
    await get_tree().process_frame
    if stage != STAGE_INITIALIZING:
        return
    var shell: Node = shell_resource.instantiate()
    if not (shell is NUS3DGameShell):
        if shell != null:
            shell.queue_free()
        _fail_load("Invalid startup scene.")
        return
    loaded_shell = shell as NUS3DGameShell
    get_tree().root.add_child(loaded_shell)
    world_resource = null
    shell_resource = null
    # GameShell._ready() builds its real world and login UI synchronously.
    if loaded_shell.game == null or loaded_shell.login_cover == null:
        _fail_load("World or login did not initialize.")
        loaded_shell.queue_free()
        loaded_shell = null
        return
    stage = STAGE_DONE
    _present_progress(stage_progress(STAGE_DONE, 1.0), _stage_status())
    await get_tree().process_frame
    if not is_instance_valid(loaded_shell):
        _fail_load("Startup scene was removed.")
        return
    get_tree().current_scene = loaded_shell
    queue_free()
