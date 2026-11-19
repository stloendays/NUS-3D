extends Node3D
class_name UTownHorrorMode
## Opt-in, fictional "Midnight Deadline" chase. Completely dormant in normal play.
## Two reusable non-lethal phantom NPCs; toy projectiles from the existing Arcade.
## This is not a real NUS scenario, actual violence or an online multiplayer mode.

const RUN_SECONDS: float = 300.0
const START_LIVES: int = 3
const GHOST_COUNT: int = 2
const GHOST_HP: int = 3
const DETECTION_M: float = 27.0
const LOSE_M: float = 48.0
const CATCH_M: float = 2.0
const PICKUP_M: float = 3.7
const EXIT_M: float = 7.0
const AUDIO_RATE: int = 11025

@onready var world: UTownWorld = $"../World"
@onready var player: UTownPlayer = $"../Player"
@onready var life: UTownCampusLife = $"../CampusLife"
@onready var arcade: UTownArcade = $"../Arcade"
@onready var weather: UTownWeather = $"../Weather"
@onready var hud: CanvasLayer = $"../HUD"
@onready var coins: UTownCoins = $"../Coins"

var accounts: NUS3DAccountStore
var save_path: String = ""
var active: bool = false
var armed: bool = false
var lives: int = START_LIVES
var seconds_left: float = RUN_SECONDS
var elapsed: float = 0.0
var pages_found: int = 0
var banished: int = 0
var wins: int = 0
var best_seconds: float = -1.0
var previous_weather: int = 0
var previous_lighting: int = 0
var previous_weapon: int = 0
var catch_immunity: float = 0.0
var flash_seconds: float = 0.0
var ui_refresh: float = 0.0
var threat_distance: float = 99.0
var hint: String = ""
var banner_time: float = 0.0
var menu_owns_pause: bool = false
var message_duration: float = 0.0

var phantoms: Array[Dictionary] = []
var document_nodes: Array[Node3D] = []
var documents_taken: Array[bool] = []
var pickup_node: Node3D
var exit_node: Node3D
var held_weapon: Node3D
var hud_layer: CanvasLayer
var tint: ColorRect
var status_panel: PanelContainer
var status_label: Label
var message_label: Label
var confirmation: ConfirmationDialog
var end_timer: Timer
var soundtrack: AudioStreamPlayer
var material_cache: Dictionary = {}
var box_cache: Dictionary = {}


func _ready() -> void:
    _make_scenery()
    _make_hud()
    _build_ambient_sound()
    set_process(false)
    set_physics_process(false)


func attach_profile(store: NUS3DAccountStore) -> void:
    if active:
        finish_run(false, "switch_account")
    accounts = store if store != null and store.is_logged_in() else null
    save_path = accounts.feature_save_path("horror") if accounts != null else ""
    wins = 0
    best_seconds = -1.0
    if not save_path.is_empty():
        var save := ConfigFile.new()
        if save.load(save_path) == OK:
            wins = clampi(int(save.get_value("night_shift", "wins", 0)), 0, 1000000)
            best_seconds = clampf(float(save.get_value("night_shift", "best_seconds", -1.0)), -1.0, RUN_SECONDS)


func detach_profile() -> void:
    if menu_owns_pause:
        _close_menu()
    if active:
        finish_run(false, "switch_account")
    accounts = null
    save_path = ""
    wins = 0
    best_seconds = -1.0


func _save_score() -> void:
    if accounts == null or not accounts.is_logged_in() or save_path.is_empty():
        return
    var save := ConfigFile.new()
    save.set_value("night_shift", "wins", wins)
    save.set_value("night_shift", "best_seconds", best_seconds)
    if save.save(save_path) != OK:
        push_warning("Could not save the local Midnight Deadline score.")


func _is_zh() -> bool:
    var lang: NUS3DGameLanguage = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage
    return lang != null and lang.is_chinese()


func _tr(zh: String, en: String) -> String:
    return zh if _is_zh() else en


func _mat(color: String, glow: bool = false) -> StandardMaterial3D:
    var key: String = color + ("-glow" if glow else "")
    if not material_cache.has(key):
        var result := StandardMaterial3D.new()
        result.albedo_color = Color.html(color)
        result.roughness = 0.8
        result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if glow else BaseMaterial3D.SHADING_MODE_PER_PIXEL
        if glow:
            result.emission_enabled = true
            result.emission = Color.html(color)
            result.emission_energy_multiplier = 0.8
        material_cache[key] = result
    return material_cache[key]


func _box_mesh(size: Vector3) -> BoxMesh:
    var key: String = str(size)
    if not box_cache.has(key):
        var mesh := BoxMesh.new()
        mesh.size = size
        box_cache[key] = mesh
    return box_cache[key]


func _box(parent_node: Node3D, label: String, local: Vector3, size: Vector3, color: String, glow: bool = false) -> void:
    var mesh := MeshInstance3D.new()
    mesh.name = label
    mesh.mesh = _box_mesh(size)
    mesh.material_override = _mat(color, glow)
    mesh.position = local
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent_node.add_child(mesh)


func _make_marker(label_text: String, point: Vector3, color: String) -> Node3D:
    var marker := Node3D.new()
    marker.name = label_text.replace(" ", "") + "Marker"
    marker.position = point + Vector3(0.0, 0.48, 0.0)
    add_child(marker)
    _box(marker, "FloatingBeacon", Vector3(0, 0.28, 0), Vector3(0.56, 0.9, 0.56), color, true)
    _box(marker, "Base", Vector3(0, -0.27, 0), Vector3(1.15, 0.05, 1.15), "#2f3f59", true)
    var plate := Label3D.new()
    plate.text = label_text
    plate.font_size = 24
    plate.pixel_size = 0.009
    plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    plate.modulate = Color("#e8f1ff")
    plate.outline_size = 5
    plate.position = Vector3(0, 1.1, 0)
    marker.add_child(plate)
    marker.hide()
    return marker


func _make_scenery() -> void:
    if world.route_points.size() < 4:
        push_warning("Midnight Deadline requires four existing UTown checkpoints.")
        return
    pickup_node = _make_marker("PULSE BLASTER", world.route_points[0] + Vector3(5.0, 0, 2.0), "#88e8ed")
    for i in [1, 2, 3]:
        document_nodes.append(_make_marker("CURSED FILE %d" % i, world.route_points[i] + Vector3(3.0, 0, 3.0), "#bca8ff"))
        documents_taken.append(false)
    exit_node = _make_marker("SAFE EXIT", world.route_points[0], "#b8f9cb")
    held_weapon = Node3D.new()
    held_weapon.name = "SpectralPulseBlaster"
    held_weapon.position = Vector3(0.52, -0.37, -0.72)
    player.camera.add_child(held_weapon)
    _box(held_weapon, "Casing", Vector3.ZERO, Vector3(0.24, 0.24, 0.62), "#344a60")
    _box(held_weapon, "GlowingCore", Vector3(0, 0.0, -0.32), Vector3(0.12, 0.12, 0.24), "#9bf2ec", true)
    _box(held_weapon, "Grip", Vector3(0, -0.21, 0.17), Vector3(0.13, 0.35, 0.13), "#58627b")
    held_weapon.hide()
    for i in range(GHOST_COUNT):
        var root := Node3D.new()
        root.name = "PhantomExaminer_%d" % i
        var spawn: Vector3 = world.route_points[1 if i == 0 else 3] + Vector3(-5 if i == 0 else 5, 0, -4)
        root.position = spawn
        add_child(root)
        _box(root, "DarkRobe", Vector3(0, 1.0, 0), Vector3(0.66, 1.45, 0.46), "#202137")
        _box(root, "SilhouetteHead", Vector3(0, 1.86, 0), Vector3(0.52, 0.52, 0.50), "#30304e")
        _box(root, "PaleFace", Vector3(0, 1.88, -0.27), Vector3(0.35, 0.3, 0.04), "#b1add3")
        _box(root, "EyeLeft", Vector3(-0.12, 1.9, -0.31), Vector3(0.085, 0.085, 0.035), "#f064bb", true)
        _box(root, "EyeRight", Vector3(0.12, 1.9, -0.31), Vector3(0.085, 0.085, 0.035), "#f064bb", true)
        _box(root, "DeadlineFile", Vector3(0.49, 1.05, -0.1), Vector3(0.34, 0.44, 0.10), "#9d79e8", true)
        var nameplate := Label3D.new()
        nameplate.text = "THE DEADLINE EXAMINER"
        nameplate.font_size = 18
        nameplate.pixel_size = 0.01
        nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        nameplate.position = Vector3(0, 2.52, 0)
        nameplate.modulate = Color("#f0b5e8")
        root.add_child(nameplate)
        root.hide()
        phantoms.append({
            "node": root, "spawn": spawn, "hp": GHOST_HP, "state": "patrol",
            "last_seen": spawn, "search_time": 0.0, "stun": 0.0, "phase": float(i) * 2.4
        })


func _make_hud() -> void:
    hud_layer = CanvasLayer.new()
    hud_layer.layer = 17
    hud_layer.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(hud_layer)
    tint = ColorRect.new()
    tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    tint.color = Color(0.10, 0.025, 0.16, 0.20)
    tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_layer.add_child(tint)
    tint.hide()
    status_panel = PanelContainer.new()
    status_panel.anchor_left = 1.0
    status_panel.anchor_right = 1.0
    status_panel.offset_left = -404
    status_panel.offset_right = -18
    status_panel.offset_top = 415
    status_panel.offset_bottom = 625
    status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.07, 0.13, 0.93)
    style.border_color = Color("#a978c3")
    style.set_border_width_all(2)
    style.set_corner_radius_all(12)
    style.set_content_margin_all(12)
    status_panel.add_theme_stylebox_override("panel", style)
    hud_layer.add_child(status_panel)
    status_label = Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.add_theme_font_size_override("font_size", 15)
    status_label.add_theme_color_override("font_color", Color("#f1dcf5"))
    status_panel.add_child(status_label)
    status_panel.hide()
    message_label = Label.new()
    message_label.anchor_left = 0.24
    message_label.anchor_right = 0.76
    message_label.anchor_top = 0.16
    message_label.anchor_bottom = 0.16
    message_label.offset_bottom = 90
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.add_theme_font_size_override("font_size", 23)
    message_label.add_theme_color_override("font_color", Color("#f6e7ff"))
    message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_layer.add_child(message_label)
    message_label.hide()
    confirmation = ConfirmationDialog.new()
    confirmation.title = _tr("午夜 DDL · 恐怖追逐模式", "MIDNIGHT DEADLINE · HORROR MODE")
    confirmation.confirmed.connect(_confirm_menu)
    confirmation.canceled.connect(_close_menu)
    confirmation.close_requested.connect(_close_menu)
    hud_layer.add_child(confirmation)
    end_timer = Timer.new()
    end_timer.one_shot = true
    end_timer.timeout.connect(func() -> void: message_label.hide())
    hud_layer.add_child(end_timer)


func _build_ambient_sound() -> void:
    # Original short looping drone, ~28 KiB. No downloaded assets or heavy mixer.
    var samples: int = 12000
    var payload := PackedByteArray()
    payload.resize(samples * 2)
    for i in range(samples):
        var t: float = float(i) / float(AUDIO_RATE)
        var envelope: float = sin(PI * float(i) / float(samples))
        var rumble: float = sin(TAU * 65.0 * t) * 0.65 + sin(TAU * 98.0 * t) * 0.25
        var shiver: float = sin(TAU * 2.4 * t) * 0.08
        payload.encode_s16(i * 2, int(clampf((rumble + shiver) * envelope * 0.30, -1.0, 1.0) * 32767.0))
    var audio := AudioStreamWAV.new()
    audio.mix_rate = AUDIO_RATE
    audio.format = AudioStreamWAV.FORMAT_16_BITS
    audio.stereo = false
    audio.data = payload
    audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
    audio.loop_end = samples
    soundtrack = AudioStreamPlayer.new()
    soundtrack.name = "OriginalNightmareDrone"
    soundtrack.stream = audio
    soundtrack.volume_db = -25.0
    add_child(soundtrack)


func can_start() -> bool:
    if active or accounts == null or not accounts.is_logged_in() or world.route_points.size() < 4:
        return false
    if get_tree().paused or life.interior_active or life.on_shuttle or player.bicycle_mode or player.movement_locked:
        return false
    if hud == null or not hud.visible:
        return false
    var shell: Node = get_parent()
    var network_overlay: NUS3DSessionOverlay = shell.get_node_or_null("MultiplayerAndGraphics") as NUS3DSessionOverlay
    if network_overlay != null and (network_overlay.is_open or network_overlay.network.state != NUS3DNetworkSession.State.OFFLINE):
        return false
    return true


func request_mode_menu() -> bool:
    if menu_owns_pause or (not active and not can_start()) or (active and get_tree().paused):
        return false
    if active:
        confirmation.dialog_text = _tr(
            "确定退出午夜 DDL？本局任务进度不保存；原始天气与昼夜会恢复。",
            "Leave Midnight Deadline? This run is discarded and the previous weather/time return."
        )
        confirmation.ok_button_text = _tr("退出挑战", "Abandon run")
    else:
        confirmation.dialog_text = _tr(
            "仅在本模式出现两名虚构追捕者。\n先捡灵异驱散器，找齐3份异常文件，击退2名追捕者，最后返回安全区。\n[鼠标左键] 发射。被追上3次或倒计时结束则失败。是否开始？",
            "Two fictional phantoms appear ONLY in this mode.\nCollect a Pulse Blaster, 3 cursed files, banish 2 pursuers with LMB, then return to safety.\nThree catches or a time-out end the run. Begin?"
        )
        confirmation.ok_button_text = _tr("开始夜班", "Start Night Shift")
    confirmation.title = _tr("午夜 DDL · 恐怖追逐模式", "MIDNIGHT DEADLINE · HORROR MODE")
    get_tree().paused = true
    menu_owns_pause = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    confirmation.popup_centered()
    return true


func _close_menu() -> void:
    if not menu_owns_pause:
        return
    menu_owns_pause = false
    confirmation.hide()
    get_tree().paused = false
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _confirm_menu() -> void:
    var abandon: bool = active
    _close_menu()
    if abandon:
        finish_run(false, "abandoned")
    else:
        start_run()


func start_run() -> bool:
    if not can_start():
        return false
    previous_weather = weather.mode
    previous_lighting = world.lighting_mode
    previous_weapon = arcade.weapon_index
    weather.set_mode(4)
    world.set_lighting_mode(3)
    arcade.weapon_index = 0
    arcade.pending_shot = false
    active = true
    armed = false
    lives = START_LIVES
    seconds_left = RUN_SECONDS
    elapsed = 0.0
    pages_found = 0
    banished = 0
    catch_immunity = 3.0
    flash_seconds = 0.0
    threat_distance = 99.0
    for i in range(document_nodes.size()):
        documents_taken[i] = false
        document_nodes[i].show()
    pickup_node.show()
    exit_node.hide()
    held_weapon.hide()
    if arcade.held_toy != null:
        arcade.held_toy.hide()
    for i in range(phantoms.size()):
        var phantom: Dictionary = phantoms[i]
        var actor: Node3D = phantom["node"]
        actor.position = phantom["spawn"]
        phantom["hp"] = GHOST_HP
        phantom["state"] = "patrol"
        phantom["last_seen"] = actor.position
        phantom["search_time"] = 0.0
        phantom["stun"] = 0.0
        actor.show()
    tint.show()
    status_panel.show()
    message_label.hide()
    end_timer.stop()
    if DisplayServer.get_name() != "headless":
        soundtrack.play()
    hint = _tr("附近有武器闪光，先捡起它！", "Find the glowing blaster near Town Green!")
    banner_time = 4.0
    set_process(true)
    set_physics_process(true)
    _refresh_status()
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    return true


func _distance_xz(a: Vector3, b: Vector3) -> float:
    return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _collect_nearby() -> void:
    if not armed and _distance_xz(player.global_position, pickup_node.global_position) < PICKUP_M:
        armed = true
        pickup_node.hide()
        held_weapon.show()
        _notify(_tr("拿到灵异驱散器！对准追捕者，按左键发射。", "Pulse Blaster acquired! Aim at pursuers and fire with LMB."), 3.5)
    for i in range(document_nodes.size()):
        if documents_taken[i]:
            continue
        if _distance_xz(player.global_position, document_nodes[i].global_position) < PICKUP_M:
            documents_taken[i] = true
            document_nodes[i].hide()
            pages_found += 1
            _notify(_tr("异常文件 %d/3 找到！" % pages_found, "Cursed file %d/3 recovered!" % pages_found), 2.7)
    if armed and pages_found == document_nodes.size() and banished == phantoms.size():
        exit_node.show()
        if _distance_xz(player.global_position, exit_node.global_position) < EXIT_M:
            finish_run(true, "escaped")


func hit_phantom(index: int, damage: int) -> bool:
    # This mutates only fictional entities; the Arcade owns the real LMB shot.
    if not active or not armed or damage <= 0 or index < 0 or index >= phantoms.size():
        return false
    var phantom: Dictionary = phantoms[index]
    if int(phantom["hp"]) <= 0:
        return false
    phantom["hp"] = maxi(0, int(phantom["hp"]) - mini(damage, 3))
    phantom["stun"] = 1.2
    if int(phantom["hp"]) == 0:
        phantom["state"] = "banished"
        (phantom["node"] as Node3D).hide()
        banished += 1
        _notify(_tr("追捕者已被驱散：%d/2！" % banished, "Phantom banished: %d/2!" % banished), 2.5)
    else:
        _notify(_tr("灵异驱散器命中！追捕者暂时眩晕。", "Pulse hit! Examiner stunned briefly."), 1.5)
    return true


func receive_arcade_shot(origin: Vector3, direction: Vector3, max_range: float) -> Vector3:
    # Weapon must have been picked up. Ray is intentionally generous for a toy.
    var last_point: Vector3 = origin + direction * max_range
    if not active or not armed:
        return last_point
    var best_index: int = -1
    var best_depth: float = max_range
    for i in range(phantoms.size()):
        if int(phantoms[i]["hp"]) <= 0:
            continue
        var enemy: Node3D = phantoms[i]["node"]
        var center: Vector3 = enemy.global_position + Vector3(0.0, 1.4, 0.0)
        var offset: Vector3 = center - origin
        var depth: float = offset.dot(direction)
        if depth <= 0.5 or depth >= best_depth:
            continue
        if (offset - direction * depth).length() > 0.84 + depth * 0.016:
            continue
        best_depth = depth
        best_index = i
        last_point = center
    if best_index >= 0:
        hit_phantom(best_index, 1)
    return last_point


func _move_phantoms(delta: float) -> void:
    threat_distance = 99.0
    for i in range(phantoms.size()):
        var phantom: Dictionary = phantoms[i]
        if int(phantom["hp"]) <= 0:
            continue
        var actor: Node3D = phantom["node"]
        var distance: float = _distance_xz(actor.global_position, player.global_position)
        threat_distance = minf(threat_distance, distance)
        phantom["phase"] = float(phantom["phase"]) + delta * 2.8
        var eye_distance: float = distance
        var seek: Vector3
        if eye_distance < DETECTION_M:
            phantom["state"] = "chasing"
            phantom["last_seen"] = player.global_position
            phantom["search_time"] = 5.0
        elif phantom["state"] == "chasing" and eye_distance < LOSE_M:
            phantom["last_seen"] = player.global_position
        elif phantom["state"] == "chasing":
            phantom["state"] = "searching"
        elif phantom["state"] == "searching":
            phantom["search_time"] = maxf(0.0, float(phantom["search_time"]) - delta)
            if float(phantom["search_time"]) <= 0.0:
                phantom["state"] = "patrol"
        if float(phantom["stun"]) > 0.0:
            phantom["stun"] = maxf(0.0, float(phantom["stun"]) - delta)
            continue
        match str(phantom["state"]):
            "chasing":
                seek = player.global_position
            "searching":
                seek = phantom["last_seen"]
            _:
                var next_route: Vector3 = world.route_points[(i + int(elapsed / 18.0) + 1) % world.route_points.size()]
                seek = next_route
        var flat: Vector3 = Vector3(seek.x - actor.position.x, 0.0, seek.z - actor.position.z)
        var stride: float = 5.45 if phantom["state"] == "chasing" else 2.3
        if flat.length() > 0.13:
            actor.position += flat.normalized() * minf(flat.length(), stride * delta)
            actor.rotation.y = lerp_angle(actor.rotation.y, atan2(-flat.x, -flat.z), minf(1.0, delta * 8.0))
        actor.position.y = lerpf(actor.position.y, player.global_position.y + 0.12, minf(1.0, delta * 0.5))
        # No colliders: ghosts are stylized phantoms and may phase through scenery.
        if distance < CATCH_M and catch_immunity <= 0.0:
            _caught()
            break


func _caught() -> void:
    lives -= 1
    catch_immunity = 5.0
    flash_seconds = 0.42
    for phantom in phantoms:
        if int(phantom["hp"]) > 0:
            (phantom["node"] as Node3D).position = phantom["spawn"]
            phantom["state"] = "searching"
            phantom["search_time"] = 2.0
    var ui_sound: NUS3DUISound = get_node_or_null("/root/UISound") as NUS3DUISound
    if ui_sound != null:
        ui_sound.play_ui("error")
    if lives <= 0:
        finish_run(false, "caught")
    else:
        _notify(_tr("被发现了！剩余机会：%d" % lives, "CAUGHT! Chances remaining: %d" % lives), 2.5)


func _physics_process(delta: float) -> void:
    if active:
        _move_phantoms(delta)


func _process(delta: float) -> void:
    if not active:
        return
    var shell: Node = get_parent()
    var session: NUS3DSessionOverlay = shell.get_node_or_null("MultiplayerAndGraphics") as NUS3DSessionOverlay
    if (session != null and session.network.state != NUS3DNetworkSession.State.OFFLINE) or life.on_shuttle or life.interior_active:
        finish_run(false, "left_zone")
        return
    seconds_left -= delta
    elapsed += delta
    catch_immunity = maxf(0.0, catch_immunity - delta)
    flash_seconds = maxf(0.0, flash_seconds - delta)
    banner_time = maxf(0.0, banner_time - delta)
    if seconds_left <= 0.0:
        finish_run(false, "timeout")
        return
    _collect_nearby()
    if not active:
        return
    tint.color = Color(0.18, 0.015, 0.04, 0.30) if flash_seconds > 0 else Color(0.10, 0.025, 0.16, 0.13 + 0.17 * (1.0 - clampf(threat_distance / DETECTION_M, 0.0, 1.0)))
    held_weapon.visible = armed and hud.visible
    ui_refresh += delta
    if ui_refresh > 0.18:
        ui_refresh = 0.0
        _refresh_status()


func _notify(text_value: String, duration: float) -> void:
    hint = text_value
    banner_time = duration
    _refresh_status()


func _refresh_status() -> void:
    if status_label == null or not active:
        return
    var objective: String = _tr("先找到灵异驱散器", "Find the Pulse Blaster") if not armed else _tr("找文件、击退追捕者", "Recover files and banish pursuers")
    if armed and pages_found == document_nodes.size() and banished == phantoms.size():
        objective = _tr("返回 Town Green 安全区", "Return to Town Green safe exit")
    var lines := PackedStringArray()
    lines.append(_tr("午夜 DDL · 恐怖追逐", "MIDNIGHT DEADLINE · HORROR CHASE"))
    lines.append(_tr("倒计时 %d秒  |  机会 %d/3" % [ceili(seconds_left), lives],
        "%ds left  |  Chances %d/3" % [ceili(seconds_left), lives]))
    lines.append(_tr("武器 %s  |  异常文件 %d/3" % ["✓" if armed else "×", pages_found],
        "Weapon %s  |  Files %d/3" % ["READY" if armed else "MISSING", pages_found]))
    lines.append(_tr("驱散追捕者 %d/2" % banished, "Examiners banished %d/2" % banished))
    lines.append(objective)
    lines.append(_tr("靠近光点拾取 · 左键发射", "Approach glowing objects · LMB fire"))
    if banner_time > 0.0:
        lines.append(hint)
    status_label.text = "\n".join(lines)


func finish_run(success: bool, reason: String) -> void:
    if not active:
        return
    active = false
    set_process(false)
    set_physics_process(false)
    weather.set_mode(previous_weather)
    world.set_lighting_mode(previous_lighting)
    arcade.weapon_index = previous_weapon
    arcade.pending_shot = false
    if arcade.held_toy != null:
        arcade.held_toy.visible = hud.visible
    for phantom in phantoms:
        (phantom["node"] as Node3D).hide()
    for marker in document_nodes:
        marker.hide()
    pickup_node.hide()
    exit_node.hide()
    held_weapon.hide()
    tint.hide()
    status_panel.hide()
    soundtrack.stop()
    var message_value: String
    if success:
        wins += 1
        var completion_time: float = RUN_SECONDS - maxf(0.0, seconds_left)
        if best_seconds < 0.0 or completion_time < best_seconds:
            best_seconds = completion_time
        _save_score()
        if accounts != null and accounts.is_logged_in():
            accounts.award_once("horror:midnight_deadline_first_clear", 160)
            coins.reward_once("horror:midnight_deadline_first_clear", 100, "Midnight Deadline completion")
        message_value = _tr("午夜任务完成！+160 XP 和 100 金币（首次通关）", "NIGHT SHIFT CLEARED! First clear: +160 XP and 100 coins.")
    else:
        message_value = _tr("夜班结束：%s。正常校园已恢复。" % reason, "Night Shift ended: %s. Normal campus restored." % reason)
    message_label.text = message_value
    message_label.show()
    end_timer.start(5.0)


func _exit_tree() -> void:
    if active and weather != null and world != null:
        weather.set_mode(previous_weather)
        world.set_lighting_mode(previous_lighting)
