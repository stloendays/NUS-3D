extends Node3D
class_name UTownDDLStory
## M3.7: fictional slapstick deadline episode. No real students, grades or NUS services.
## Self-contained so existing exploration tasks, campus NPCs and arcade inputs still work.

const SAVE_PATH: String = "user://nus3d_ddl_story.cfg"
const DEADLINE_SECONDS: float = 300.0
const INTERACT_RADIUS_M: float = 10.0
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
var display_layer: CanvasLayer
var display_label: Label
var elapsed_since_refresh: float = 0.0
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
    _refresh()

func _build_markers() -> void:
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.62
    mesh.bottom_radius = 0.82
    mesh.height = 0.20
    for i in range(EPISODES.size()):
        var beacon := Node3D.new()
        beacon.name = "DDLComicCheckpoint_%d" % i
        beacon.position = stage_points[i] + Vector3(0, 0.62, 0)
        add_child(beacon)
        var base := MeshInstance3D.new()
        base.name = "NeonCheckpointBase"
        base.mesh = mesh
        var material := StandardMaterial3D.new()
        material.albedo_color = Color.html(["#ffe28b", "#ff978b", "#91d4ee", "#bb98e8"][i])
        material.emission_enabled = true
        material.emission = material.albedo_color
        material.emission_energy_multiplier = 0.42
        base.material_override = material
        base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        beacon.add_child(base)
        var marker := Label3D.new()
        marker.name = "FloatingQuestLabel"
        marker.position = Vector3(0, 2.62, 0)
        marker.text = "%d / %s\n[H] INTERACT" % [i + 1, EPISODES[i]["name"]]
        marker.pixel_size = 0.018
        marker.font_size = 26
        marker.outline_size = 7
        marker.modulate = Color.html("#fff6c8")
        marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        beacon.add_child(marker)
        stage_roots.append(beacon)

func _build_ui() -> void:
    display_layer = CanvasLayer.new()
    display_layer.name = "DDLQuestOverlay"
    display_layer.layer = 2
    add_child(display_layer)
    var panel := PanelContainer.new()
    panel.name = "PanicCard"
    panel.anchor_left = 0.5
    panel.anchor_right = 0.5
    panel.anchor_top = 1.0
    panel.anchor_bottom = 1.0
    panel.offset_left = -203.0
    panel.offset_right = 203.0
    panel.offset_top = -183.0
    panel.offset_bottom = -55.0
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.24, 0.10, 0.20, 0.94)
    style.border_color = Color.html("#ffd57c")
    style.set_border_width_all(2)
    style.set_corner_radius_all(10)
    style.content_margin_left = 11.0
    style.content_margin_right = 11.0
    style.content_margin_top = 10.0
    style.content_margin_bottom = 10.0
    panel.add_theme_stylebox_override("panel", style)
    display_layer.add_child(panel)
    display_label = Label.new()
    display_label.name = "EpisodeAndCountdown"
    display_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    display_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    display_label.add_theme_font_size_override("font_size", 12)
    display_label.add_theme_color_override("font_color", Color.html("#fff3d9"))
    panel.add_child(display_label)

func reset_episode() -> void:
    stage = 0
    running = false
    completed = false
    deadline_left = DEADLINE_SECONDS
    panic_notified = false
    final_warning_notified = false
    latest_line = "A suspicious assignment email is waiting. [H] at Town Green."
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
    latest_line = str(event["dialogue"])
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
        latest_line += " +80 XP (first successful submission only)."
    _save_progress()
    _refresh()
    return true

func _process(delta: float) -> void:
    if not enabled:
        return
    display_layer.visible = hud.visible
    for i in range(stage_roots.size()):
        stage_roots[i].visible = hud.visible and not campus_life.interior_active and not completed and stage == i
    if running:
        deadline_left = maxf(0.0, deadline_left - delta)
        if deadline_left < 150.0 and not panic_notified:
            latest_line = "Ding! Prof. Deadline has emailed: 'Any progress?' Your keyboard begins sweating."
            panic_notified = true
        if deadline_left < 60.0 and not final_warning_notified:
            latest_line = "ONE MINUTE! The PDF has turned into a 400 MB potato."
            final_warning_notified = true
        if deadline_left <= 0.0:
            running = false
            fail_count += 1
            stage = 0
            latest_line = "DDL EXPIRED. The portal exploded into confetti. Return to Town Green for a retry."
            _save_progress()
    elapsed_since_refresh += delta
    if elapsed_since_refresh >= 0.2:
        elapsed_since_refresh = 0.0
        _refresh()

func _refresh() -> void:
    if display_label == null:
        return
    var minutes: int = int(ceil(deadline_left)) / 60
    var seconds: int = int(ceil(deadline_left)) % 60
    var timer_label: String = "%02d:%02d" % [minutes, seconds]
    var lines := PackedStringArray()
    lines.append("DDL DOOM  |  %s  |  RETRIES %d" % [timer_label, fail_count])
    if completed:
        lines.append("SUBMITTED! Best: %.1f s | [H] at Green to replay" % best_seconds)
    else:
        lines.append("ACT %d/4  %s" % [stage + 1, EPISODES[stage]["name"]])
        lines.append("%s  |  [H] at marker" % EPISODES[stage]["hint"])
    lines.append(latest_line)
    display_label.text = "\n".join(lines)

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
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
        interact()
