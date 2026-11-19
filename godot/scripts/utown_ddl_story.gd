extends Node3D
class_name UTownDDLStory
## M3.7: fictional slapstick deadline episode. No real students, grades or NUS services.
## Self-contained so existing exploration tasks, campus NPCs and arcade inputs still work.

const SAVE_PATH: String = "user://nus3d_ddl_story.cfg"
const DEADLINE_SECONDS: float = 300.0
const INTERACT_RADIUS_M: float = 10.0
const FOCUS_RADIUS_M: float = 20.0
const ACTIONS = ["Read overdue email", "Retrieve jammed pages", "Drink emergency coffee", "Upload coursework"]
const ZH_ACTIONS: Array[String] = ["阅读逾期邮件", "取出卡住的纸张", "补充应急咖啡", "提交课程作业"]
const ZH_NAMES: Array[String] = ["厄运邮件", "闹鬼打印机", "咖啡仪式", "提交门户"]
const ZH_DIALOGUES: Array[String] = [
    "收件箱：惊喜！昨天就截止了。恭喜你，还有五分钟可以慌张。",
    "打印机：错误！找不到脑细胞。它却打印了三十七页参考文献。",
    "自动售货机：咖啡 +99，睡眠 -999。你的论文长了腿逃走了。",
    "上传门户：文件太大。使用橡皮鸡压缩……通过！成绩：恐慌大师。"
]
const EPISODES = [
    {
        "id": "GREEN", "name": "THE EMAIL OF DOOM",
        "hint": "Accept a mysterious 2 AM coursework email",
        "dialogue": "Inbox: Surprise! The deadline was yesterday. Congratulations, you have FIVE minutes to panic."
    },
    {
        "id": "ERC", "name": "THE CURSED PRINTER",
        "hint": "Recover 37 totally necessary pages of references",
        "dialogue": "Printer: ERROR 404 — Brain cells not found. Somehow it printed 37 pages of 'et al.'"
    },
    {
        "id": "SRC", "name": "THE CAFFEINE RITUAL",
        "hint": "Refill your entirely imaginary caffeine meter",
        "dialogue": "Vending machine: Coffee +99, sleep -999. Your dissertation has grown legs and run away."
    },
    {
        "id": "PLAZA", "name": "THE SUBMISSION PORTAL",
        "hint": "Defeat the upload error with the power of nonsense",
        "dialogue": "Portal: File too large. Compressing with rubber chicken... Accepted! Grade: MASTER OF PANIC."
    }
]
@onready var world: UTownWorld = $"../World"
@onready var player: UTownPlayer = $"../Player"
@onready var campus_life: UTownCampusLife = $"../CampusLife"
@onready var arcade: UTownArcade = $"../Arcade"
@onready var hud: CanvasLayer = $"../HUD"
@onready var language: NUS3DGameLanguage = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage

var save_path: String = SAVE_PATH
var stage: int = 0
var running: bool = false
var completed: bool = false
var rewarded: bool = false
var fail_count: int = 0
var deadline_left: float = DEADLINE_SECONDS
var best_seconds: float = -1.0
var latest_line: String = "The semester is peaceful. This is suspicious."
var stage_points: Array[Vector3] = []
var stage_roots: Array[Node3D] = []
var focus_accents: Array[MeshInstance3D] = []
var display_layer: CanvasLayer
var display_label: Label
var countdown_label: Label
var tracker_panel: PanelContainer
var near_prompt_panel: PanelContainer
var near_prompt_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var compass_control: UTownDDLCompass
var ping_remaining: float = 0.0
var toast_remaining: float = 0.0
var elapsed_since_refresh: float = 0.0
var marker_time: float = 0.0
var panic_notified: bool = false
var final_warning_notified: bool = false
var enabled: bool = true

func _ready() -> void:
    var indexed: Dictionary = {}
    for raw in world.layout.get("loop", []):
        var item: Dictionary = raw
        indexed[str(item.get("id", ""))] = world.lonlat_to_world(float(item.get("lon", 0.0)), float(item.get("lat", 0.0)))
    for episode in EPISODES:
        var point_id: String = str(episode["id"])
        if not indexed.has(point_id):
            enabled = false
            push_warning("DDL story disabled: missing approximate loop waypoint " + point_id)
            return
        stage_points.append(indexed[point_id])
    _build_markers()
    _build_ui()
    load_progress()
    if language != null:
        language.language_changed.connect(func(_code: String) -> void: _refresh())
    _refresh()


func _t(zh: String, en: String) -> String:
    return language.choose(zh, en) if language != null else en


func _story_name(index: int) -> String:
    return ZH_NAMES[index] if language != null and language.is_chinese()         else str(EPISODES[index]["name"])


func _story_action(index: int) -> String:
    return ZH_ACTIONS[index] if language != null and language.is_chinese()         else str(ACTIONS[index])


func _story_dialogue(index: int) -> String:
    return ZH_DIALOGUES[index] if language != null and language.is_chinese()         else str(EPISODES[index]["dialogue"])


func _build_markers() -> void:
    # The four big cartoon machines ARE the discoverable landmarks; no labels or beacons.
    for i in range(EPISODES.size()):
        var actor := Node3D.new()
        actor.name = "DDLInteractiveScene_%d" % i
        actor.position = stage_points[i] + Vector3(0.0, 0.62, 0.0)
        add_child(actor)
        _build_stage_prop(actor, i)
        stage_roots.append(actor)

func _prop_part(parent: Node3D, name_value: String, at: Vector3, dims: Vector3, color_hex: String, with_glow: bool = false) -> MeshInstance3D:
    # Bounded lightweight meshes: one comic silhouette per mission stage, no physics.
    var visual := MeshInstance3D.new()
    visual.name = name_value
    var mesh := BoxMesh.new()
    mesh.size = dims
    visual.mesh = mesh
    visual.position = at
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color.html(color_hex)
    mat.roughness = 0.72
    if with_glow:
        mat.emission_enabled = true
        mat.emission = mat.albedo_color
        mat.emission_energy_multiplier = 0.6
    visual.material_override = mat
    visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(visual)
    return visual

func _build_stage_prop(beacon: Node3D, i: int) -> void:
    # Move decorative props off the center of the walkway. They remain intangible.
    var prop := Node3D.new()
    prop.name = "ComicTaskProp_%d" % i
    prop.position = Vector3(3.0 if i % 2 == 0 else -3.0, -0.4, -1.1)
    beacon.add_child(prop)
    match i:
        0:
            _prop_part(prop, "MailEnvelope", Vector3(0, 1.65, 0), Vector3(2.5, 1.55, 0.25), "#fff4db")
            _prop_part(prop, "EnvelopeFold", Vector3(0, 1.50, -0.17), Vector3(2.10, 0.12, 0.04), "#fba0a5")
            _prop_part(prop, "EmergencyStamp", Vector3(0.8, 2.02, -0.18), Vector3(0.50, 0.42, 0.05), "#e97c80")
        1:
            _prop_part(prop, "PrinterHousing", Vector3(0, 1.02, 0), Vector3(2.25, 1.24, 1.05), "#91a8b8")
            _prop_part(prop, "PrinterFeed", Vector3(0, 1.74, 0.05), Vector3(1.58, 0.3, 0.84), "#e2e9df")
            _prop_part(prop, "StuckPages", Vector3(0, 2.22, -0.09), Vector3(1.27, 0.8, 0.07), "#fff9e9")
            _prop_part(prop, "RedErrorLight", Vector3(0.83, 1.2, -0.55), Vector3(0.25, 0.24, 0.06), "#ff666a", true)
        2:
            _prop_part(prop, "CoffeeGiantCup", Vector3(0, 1.37, 0), Vector3(1.65, 2.35, 1.45), "#f7c46d")
            _prop_part(prop, "CoffeeCupSleeve", Vector3(0, 1.55, -0.77), Vector3(1.45, 0.73, 0.09), "#e5eef4")
            _prop_part(prop, "CoffeeLid", Vector3(0, 2.62, 0), Vector3(1.89, 0.25, 1.70), "#ffffff")
            _prop_part(prop, "CartoonSteam", Vector3(0.22, 3.15, 0), Vector3(0.25, 0.72, 0.20), "#fff7c6")
        3:
            _prop_part(prop, "UploadComputer", Vector3(0, 1.56, 0), Vector3(2.25, 1.72, 0.40), "#3e566e")
            _prop_part(prop, "PortalScreen", Vector3(0, 1.61, -0.23), Vector3(1.94, 1.38, 0.06), "#a7ecd9", true)
            _prop_part(prop, "PortalFoot", Vector3(0, 0.53, 0), Vector3(0.30, 0.57, 0.26), "#8b9eab")
            _prop_part(prop, "PortalBase", Vector3(0, 0.20, 0), Vector3(1.14, 0.14, 0.71), "#566a78")
    # A tiny highlight appears only as the player approaches the ACTIVE stage.
    # The world is otherwise untouched; no billboard text, no checkpoint rings.
    var accent: MeshInstance3D = _prop_part(prop, "FocusGlint", Vector3(0.0, 0.43, -0.83), Vector3(1.18, 0.075, 0.07), "#ffe39b", true)
    accent.visible = false
    focus_accents.append(accent)

func _build_ui() -> void:
    display_layer = CanvasLayer.new()
    display_layer.name = "MinimalMissionHUD"
    display_layer.layer = 2
    add_child(display_layer)

    # Always-on tracker occupies a small area at top center, not a big bottom box.
    var tracker := PanelContainer.new()
    tracker.name = "SlimDeadlineTracker"
    tracker_panel = tracker
    tracker.anchor_left = 0.5
    tracker.anchor_right = 0.5
    tracker.offset_left = -205.0
    tracker.offset_right = 205.0
    tracker.offset_top = 120.0
    tracker.offset_bottom = 188.0
    tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style: StyleBoxFlat = NUS3DUISkin.glass(Color("#DAA66A"), 21, 10)
    tracker.add_theme_stylebox_override("panel", style)
    display_layer.add_child(tracker)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 3)
    tracker.add_child(column)
    countdown_label = Label.new()
    countdown_label.name = "Deadline"
    countdown_label.add_theme_font_size_override("font_size", 18)
    countdown_label.add_theme_color_override("font_color", Color("#976722"))
    column.add_child(countdown_label)
    display_label = Label.new()
    display_label.name = "Objective"
    display_label.add_theme_font_size_override("font_size", 13)
    display_label.add_theme_color_override("font_color", NUS3DUISkin.TEXT)
    display_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(display_label)

    # Optional three-second direction pulse is a compact 2D UI compass, not a world arrow.
    compass_control = UTownDDLCompass.new()
    compass_control.name = "MomentaryDirectionPulse"
    compass_control.anchor_left = 0.5
    compass_control.anchor_right = 0.5
    compass_control.offset_left = -65.0
    compass_control.offset_right = 65.0
    compass_control.offset_top = 192.0
    compass_control.offset_bottom = 288.0
    compass_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    display_layer.add_child(compass_control)
    compass_control.update_ping(0.0, 0.0, 0.0)

    # Interaction text is contextual. It never displays at a long distance.
    near_prompt_panel = PanelContainer.new()
    near_prompt_panel.name = "NearObjectPrompt"
    near_prompt_panel.anchor_left = 0.5
    near_prompt_panel.anchor_right = 0.5
    near_prompt_panel.anchor_top = 1.0
    near_prompt_panel.anchor_bottom = 1.0
    near_prompt_panel.offset_left = -155.0
    near_prompt_panel.offset_right = 155.0
    near_prompt_panel.offset_top = -112.0
    near_prompt_panel.offset_bottom = -75.0
    near_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var prompt_style: StyleBoxFlat = NUS3DUISkin.glass(Color("#81B8AF"), 20, 9)
    near_prompt_panel.add_theme_stylebox_override("panel", prompt_style)
    display_layer.add_child(near_prompt_panel)
    near_prompt_label = Label.new()
    near_prompt_label.name = "ContextAction"
    near_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    near_prompt_label.add_theme_font_size_override("font_size", 15)
    near_prompt_label.add_theme_color_override("font_color", NUS3DUISkin.TEXT)
    near_prompt_panel.add_child(near_prompt_label)
    near_prompt_panel.visible = false

    # Dialogues appear briefly as captions rather than permanent floating world text.
    toast_panel = PanelContainer.new()
    toast_panel.name = "NarrativeSubtitle"
    toast_panel.anchor_left = 0.5
    toast_panel.anchor_right = 0.5
    toast_panel.anchor_top = 1.0
    toast_panel.anchor_bottom = 1.0
    toast_panel.offset_left = -280.0
    toast_panel.offset_right = 280.0
    toast_panel.offset_top = -218.0
    toast_panel.offset_bottom = -126.0
    toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var toast_style: StyleBoxFlat = NUS3DUISkin.glass(Color("#A7B7C4"), 21, 14)
    toast_panel.add_theme_stylebox_override("panel", toast_style)
    display_layer.add_child(toast_panel)
    toast_label = Label.new()
    toast_label.name = "StorySubtitle"
    toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_label.add_theme_font_size_override("font_size", 14)
    toast_label.add_theme_color_override("font_color", NUS3DUISkin.TEXT)
    toast_panel.add_child(toast_label)
    toast_panel.visible = false

func _notify_story(words: String) -> void:
    latest_line = words
    toast_remaining = 5.0
    if toast_label != null:
        toast_label.text = words

func request_focus() -> bool:
    if not enabled or not hud.visible or campus_life.interior_active or campus_life.on_shuttle or player.movement_locked:
        return false
    ping_remaining = 3.0
    return true

func _distance_to(point: Vector3) -> float:
    var delta: Vector3 = point - player.global_position
    return Vector2(delta.x, delta.z).length()

func _current_goal_index() -> int:
    return 0 if completed else clampi(stage, 0, EPISODES.size() - 1)

func _update_direction_pulse() -> void:
    if compass_control == null or stage_points.is_empty():
        return
    var goal: Vector3 = stage_points[_current_goal_index()]
    var vec: Vector3 = goal - player.global_position
    var flattened := Vector2(vec.x, vec.z)
    var forward_3: Vector3 = -player.global_transform.basis.z
    var right_3: Vector3 = player.global_transform.basis.x
    var forward := Vector2(forward_3.x, forward_3.z).normalized()
    var right := Vector2(right_3.x, right_3.z).normalized()
    var target := flattened.normalized()
    var bearing: float = atan2(target.dot(right), target.dot(forward)) if flattened.length_squared() > 0.0001 else 0.0
    compass_control.update_ping(bearing, flattened.length(), minf(1.0, ping_remaining / 0.5))

func reset_episode() -> void:
    stage = 0
    running = false
    completed = false
    deadline_left = DEADLINE_SECONDS
    panic_notified = false
    final_warning_notified = false
    latest_line = _t("你收到一封新的课程邮件。", "You have new coursework mail.")
    toast_remaining = 0.0
    ping_remaining = 0.0
    _refresh()

func interact() -> bool:
    if not enabled or not hud.visible or player.movement_locked or campus_life.interior_active or campus_life.on_shuttle:
        return false
    if completed:
        if player.global_position.distance_to(stage_points[0]) > INTERACT_RADIUS_M:
            return false
        reset_episode() # Replay allowed, but completion XP is granted only once.
    if stage >= EPISODES.size() or player.global_position.distance_to(stage_points[stage]) > INTERACT_RADIUS_M:
        return false
    var event: Dictionary = EPISODES[stage]
    _notify_story(_story_dialogue(stage))
    if stage == 0:
        running = true
        deadline_left = DEADLINE_SECONDS
    stage += 1
    if stage >= EPISODES.size():
        running = false
        completed = true
        var result: float = DEADLINE_SECONDS - deadline_left
        if best_seconds < 0.0 or result < best_seconds:
            best_seconds = result
        if not rewarded:
            arcade._award_xp(80)
            rewarded = true
            _notify_story(latest_line + _t(" 首次提交奖励 +80 XP。", " +80 XP for first submission."))
        else:
            _notify_story(latest_line + _t(" 重玩完成。", " Replay complete."))
    ping_remaining = 2.5 if not completed else 0.0
    _save_progress()
    _refresh()
    return true

func _process(delta: float) -> void:
    if not enabled:
        return
    display_layer.visible = hud.visible
    marker_time += delta
    toast_remaining = maxf(0.0, toast_remaining - delta)
    ping_remaining = maxf(0.0, ping_remaining - delta)
    for i in range(stage_roots.size()):
        # Always keep recognizable fictional world objects visible, including F7 photo mode.
        var obj: Node3D = stage_roots[i]
        obj.visible = not campus_life.interior_active
        var accent: MeshInstance3D = focus_accents[i]
        var focused: bool = i == _current_goal_index() and not completed
        accent.visible = obj.visible and hud.visible and focused and _distance_to(stage_points[i]) <= FOCUS_RADIUS_M
        if accent.visible:
            accent.scale = Vector3.ONE * (0.88 + 0.12 * sin(marker_time * 2.8))
    _update_direction_pulse()
    if running:
        deadline_left = maxf(0.0, deadline_left - delta)
        if deadline_left < 150.0 and not panic_notified:
            _notify_story(_t("截止时间教授：有进展吗？键盘开始冒汗。",
                "Prof. Deadline: 'Any progress?' Your keyboard begins sweating."))
            panic_notified = true
        if deadline_left < 60.0 and not final_warning_notified:
            _notify_story(_t("只剩一分钟！文档变成了四百兆的土豆。",
                "ONE MINUTE! The PDF has become a 400 MB potato."))
            final_warning_notified = true
        if deadline_left <= 0.0:
            running = false
            fail_count += 1
            stage = 0
            _notify_story(_t("截止时间已过！上传页面变成彩纸。回中央草坪重试。",
                "DDL EXPIRED. The upload portal explodes into confetti. Retry at Town Green."))
            _save_progress()
    if toast_panel != null:
        toast_panel.visible = toast_remaining > 0.0 and hud.visible
    elapsed_since_refresh += delta
    if elapsed_since_refresh >= 0.2:
        elapsed_since_refresh = 0.0
        _refresh()

func _refresh() -> void:
    if display_label == null or countdown_label == null or stage_points.is_empty():
        return
    if tracker_panel != null:
        tracker_panel.visible = hud.visible and (
            running or (not completed and _distance_to(stage_points[_current_goal_index()]) < 24.0)
        )
    var total_seconds: int = maxi(0, ceili(deadline_left))
    var minutes: int = floori(float(total_seconds) / 60.0)
    var seconds: int = total_seconds % 60
    var clock: String = "%02d:%02d" % [minutes, seconds]
    countdown_label.text = _t("截止 %s", "DDL %s") % clock if running         else _t("已提交", "DDL SUBMITTED") if completed else _t("任务待领取", "DDL READY")
    var timer_color: Color = Color.html("#ffe5a3")
    if running and deadline_left <= 20.0:
        timer_color = Color.html("#ff6569") if int(marker_time * 3.0) % 2 == 0 else Color.html("#ffe5a3")
    elif running and deadline_left <= 60.0:
        timer_color = Color.html("#ffad78")
    countdown_label.add_theme_color_override("font_color", timer_color)
    var goal_index: int = _current_goal_index()
    var distance: float = _distance_to(stage_points[goal_index])
    if completed:
        display_label.text = _t("已提交 | %.0f 米后可重玩 | H 定位",
            "Submitted | %.0f m to replay | H focus") % distance
    else:
        display_label.text = _t("%s | %.0f 米 | H 定位",
            "%s | %.0f m | H focus") % [_story_name(goal_index), distance]
    near_prompt_panel.visible = (
        hud.visible and not campus_life.interior_active and not campus_life.on_shuttle
        and not player.movement_locked and distance <= INTERACT_RADIUS_M
    )
    if near_prompt_panel.visible:
        near_prompt_label.text = "H  %s" % (
            _t("重玩截止时间挑战", "Replay DDL") if completed else _story_action(goal_index))
    if toast_panel != null:
        toast_panel.visible = toast_remaining > 0.0 and hud.visible

func _save_progress() -> void:
    var config := ConfigFile.new()
    config.set_value("ddl", "schema", 1)
    config.set_value("ddl", "stage", stage)
    config.set_value("ddl", "running", running)
    config.set_value("ddl", "completed", completed)
    config.set_value("ddl", "rewarded", rewarded)
    config.set_value("ddl", "fail_count", fail_count)
    config.set_value("ddl", "deadline_left", deadline_left)
    config.set_value("ddl", "best_seconds", best_seconds)
    var error: Error = config.save(save_path)
    if error != OK:
        push_warning("Could not save independent DDL story: " + str(error))

func load_progress() -> void:
    rewarded = false
    fail_count = 0
    best_seconds = -1.0
    reset_episode()
    var config := ConfigFile.new()
    if config.load(save_path) != OK:
        return
    rewarded = bool(config.get_value("ddl", "rewarded", false))
    fail_count = maxi(0, int(config.get_value("ddl", "fail_count", 0)))
    best_seconds = float(config.get_value("ddl", "best_seconds", -1.0))
    completed = bool(config.get_value("ddl", "completed", false))
    if completed:
        stage = EPISODES.size()
        latest_line = "Submission survived. That was definitely a real deadline... in this fictional game."
    else:
        stage = clampi(int(config.get_value("ddl", "stage", 0)), 0, EPISODES.size() - 1)
        running = bool(config.get_value("ddl", "running", false))
        deadline_left = clampf(float(config.get_value("ddl", "deadline_left", DEADLINE_SECONDS)), 0, DEADLINE_SECONDS)
        if running and deadline_left <= 0.0:
            reset_episode()
    _refresh()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        # Shift+H belongs to the optional branching campaign journal.
        if event.keycode == KEY_H and not event.shift_pressed:
            if not interact():
                request_focus()
