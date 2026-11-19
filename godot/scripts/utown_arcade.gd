extends Node3D
class_name UTownArcade
## Fictional, non-lethal campus slapstick. Reuses M3.3 student walkers.
## Static teacher meshes, shared resources and a bounded projectile pool keep memory predictable.

const SAVE_PATH: String = "user://nus3d_arcade_progress.cfg"
const STUDENT_FOCUS: int = 3
const BREAK_DURATION: float = 16.0
const PROJECTILE_CAPACITY: int = 8
const WEAPONS = [
    {"name": "Paper Plane", "damage": 1, "range": 28.0, "cooldown": 0.33, "level": 1, "color": "#e7efff"},
    {"name": "Chalk Popper", "damage": 2, "range": 22.0, "cooldown": 0.62, "level": 2, "color": "#b5f2db"},
    {"name": "Rubber Chicken", "damage": 3, "range": 7.0, "cooldown": 0.85, "level": 3, "color": "#ffe17d"}
]

@onready var player: UTownPlayer = $"../Player"
@onready var campus_life: UTownCampusLife = $"../CampusLife"
@onready var hud: CanvasLayer = $"../HUD"

var save_path: String = SAVE_PATH
var students: Array[Dictionary] = []
var professors: Array[Dictionary] = []
var level: int = 1
var xp: int = 0
var lifetime_xp: int = 0
var student_wins: int = 0
var met_professors: PackedStringArray = PackedStringArray()
var weapon_index: int = 0
var shot_cooldown: float = 0.0
var pending_shot: bool = false
var message: String = ""
var message_time: float = 0.0

var projectiles: Array[Dictionary] = []
var next_projectile: int = 0
var mesh_cache: Dictionary = {}
var material_cache: Dictionary = {}
var status_layer: CanvasLayer
var status_label: Label
var held_toy: Node3D
var held_toy_body: MeshInstance3D
var photo_visible: bool = true
var hud_update_elapsed: float = 0.0

func _ready() -> void:
    _register_students()
    _spawn_professors()
    _build_status_panel()
    _build_held_toy()
    _build_projectile_pool()
    load_progress()
    _refresh_status()

func _shared_material(color: String) -> StandardMaterial3D:
    if not material_cache.has(color):
        var material := StandardMaterial3D.new()
        material.albedo_color = Color.html(color)
        material.roughness = 0.72
        material_cache[color] = material
    return material_cache[color]

func _shared_box_mesh(size: Vector3) -> BoxMesh:
    var key: String = str(size)
    if not mesh_cache.has(key):
        var box := BoxMesh.new()
        box.size = size
        mesh_cache[key] = box
    return mesh_cache[key]

func _box_part(parent_node: Node3D, part_name: String, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = part_name
    part.mesh = _shared_box_mesh(size)
    part.position = at
    part.material_override = _shared_material(color)
    parent_node.add_child(part)
    return part

func _nameplate(value: String, color: Color) -> Label3D:
    var label := Label3D.new()
    label.text = value
    label.font_size = 22
    label.pixel_size = 0.012
    label.outline_size = 5
    label.modulate = color
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    return label

func _register_students() -> void:
    for i in range(campus_life.pedestrians.size()):
        var pedestrian: Dictionary = campus_life.pedestrians[i]
        var actor: Node3D = pedestrian["node"]
        var label := _nameplate(str(pedestrian["name"]), Color.html("#e7f7ff"))
        label.name = "ArcadeNameplate"
        label.position = Vector3(0.0, 2.30, 0.0)
        actor.add_child(label)
        students.append({
            "node": actor, "name": str(pedestrian["name"]), "label": label,
            "focus": STUDENT_FOCUS, "break_seconds": 0.0
        })
        _refresh_student_label(i)

func _spawn_professors() -> void:
    var names: PackedStringArray = PackedStringArray(["Prof. Deadline", "Dr. Plot Twist"])
    var jokes: PackedStringArray = PackedStringArray([
        "Your homework was due yesterday. +20 XP!",
        "Open-book exam! The book is in another dimension. +20 XP!"
    ])
    for i in range(names.size()):
        var source_index: int = 1 if i == 0 else 4
        if source_index >= campus_life.pedestrians.size():
            continue
        var route: Array[Vector3] = campus_life.pedestrians[source_index]["route"]
        if route.size() < 2:
            continue
        var forward: Vector3 = (route[1] - route[0]).normalized()
        var teacher := Node3D.new()
        teacher.name = "FictionalProfessor_%d" % i
        teacher.position = route[0].lerp(route[1], 0.5) + forward.cross(Vector3.UP) * 2.0
        add_child(teacher)
        _box_part(teacher, "Robe", Vector3(0.0, 1.04, 0.0), Vector3(0.68, 1.28, 0.38), "#364265")
        _box_part(teacher, "Tie", Vector3(0.0, 1.40, -0.215), Vector3(0.11, 0.40, 0.045), "#f4b86b")
        _box_part(teacher, "Head", Vector3(0.0, 1.83, 0.0), Vector3(0.46, 0.46, 0.42), "#d9b698")
        _box_part(teacher, "Mortarboard", Vector3(0.0, 2.14, 0.0), Vector3(0.74, 0.09, 0.70), "#253048")
        _box_part(teacher, "LeftGlasses", Vector3(-0.13, 1.86, -0.23), Vector3(0.22, 0.12, 0.045), "#a6eced")
        _box_part(teacher, "RightGlasses", Vector3(0.13, 1.86, -0.23), Vector3(0.22, 0.12, 0.045), "#a6eced")
        _box_part(teacher, "LectureNotes", Vector3(0.38, 1.18, -0.24), Vector3(0.32, 0.49, 0.065), "#fff0c6")
        var plate := _nameplate(names[i] + "\n[U] ABSURD HOMEWORK", Color.html("#ffe0a1"))
        plate.position = Vector3(0.0, 2.65, 0.0)
        teacher.add_child(plate)
        professors.append({"node": teacher, "name": names[i], "line": jokes[i], "label": plate})

func _build_status_panel() -> void:
    status_layer = CanvasLayer.new()
    status_layer.name = "ArcadeOverlay"
    status_layer.layer = 2
    add_child(status_layer)
    var card := PanelContainer.new()
    card.name = "ArcadeCard"
    # Keep combat stats below the weather card, above the tour card. Never
    # cover the account strip, mission tracker or top-right campus map.
    card.anchor_left = 0.0
    card.anchor_right = 0.0
    card.offset_left = 18.0
    card.offset_right = 430.0
    card.offset_top = 352.0
    card.offset_bottom = 453.0
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.18, 0.14, 0.25, 0.92)
    style.set_corner_radius_all(10)
    style.content_margin_left = 14.0
    style.content_margin_right = 14.0
    style.content_margin_top = 10.0
    style.content_margin_bottom = 10.0
    card.add_theme_stylebox_override("panel", style)
    status_layer.add_child(card)
    status_label = Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    status_label.add_theme_font_size_override("font_size", 13)
    status_label.add_theme_color_override("font_color", Color.html("#fffaef"))
    card.add_child(status_label)

func _build_held_toy() -> void:
    held_toy = Node3D.new()
    held_toy.name = "HeldCartoonToy"
    held_toy.position = Vector3(0.37, -0.29, -0.70)
    player.camera.add_child(held_toy)
    _box_part(held_toy, "Handle", Vector3(0, -0.10, 0.11), Vector3(0.12, 0.35, 0.16), "#4e5563")
    held_toy_body = _box_part(held_toy, "ToyBody", Vector3(0, 0.07, -0.13), Vector3(0.24, 0.19, 0.65), "#e7efff")
    _box_part(held_toy, "FoamTip", Vector3(0, 0.07, -0.48), Vector3(0.30, 0.24, 0.12), "#ffe17d")

func _build_projectile_pool() -> void:
    var sphere := SphereMesh.new()
    sphere.radius = 0.12
    sphere.height = 0.24
    for i in range(PROJECTILE_CAPACITY):
        var projectile := MeshInstance3D.new()
        projectile.name = "PooledFoam_%02d" % i
        projectile.mesh = sphere
        projectile.material_override = _shared_material(str(WEAPONS[0]["color"]))
        projectile.visible = false
        add_child(projectile)
        projectiles.append({
            "node": projectile, "active": false,
            "from": Vector3.ZERO, "to": Vector3.ZERO,
            "time": 0.0, "duration": 0.2
        })

func xp_required() -> int:
    return 80 + (level - 1) * 45

func _award_xp(amount: int) -> void:
    xp += amount
    lifetime_xp += amount
    var upgraded: bool = false
    while xp >= xp_required() and level < 99:
        xp -= xp_required()
        level += 1
        upgraded = true
    _save_progress()
    if upgraded:
        _announce("LEVEL %d! New silly gear available." % level, 4.0)

func load_progress() -> void:
    level = 1
    xp = 0
    lifetime_xp = 0
    student_wins = 0
    met_professors.clear()
    var config := ConfigFile.new()
    if config.load(save_path) != OK:
        return
    level = clampi(int(config.get_value("arcade", "level", 1)), 1, 99)
    xp = clampi(int(config.get_value("arcade", "xp", 0)), 0, xp_required() - 1)
    lifetime_xp = maxi(0, int(config.get_value("arcade", "lifetime_xp", 0)))
    student_wins = maxi(0, int(config.get_value("arcade", "student_wins", 0)))
    var previous: Variant = config.get_value("arcade", "met_professors", PackedStringArray())
    if typeof(previous) == TYPE_ARRAY or typeof(previous) == TYPE_PACKED_STRING_ARRAY:
        for candidate in previous:
            var name: String = str(candidate)
            if (name == "Prof. Deadline" or name == "Dr. Plot Twist") and not met_professors.has(name):
                met_professors.append(name)

func _save_progress() -> void:
    var config := ConfigFile.new()
    config.set_value("arcade", "schema_version", 1)
    config.set_value("arcade", "level", level)
    config.set_value("arcade", "xp", xp)
    config.set_value("arcade", "lifetime_xp", lifetime_xp)
    config.set_value("arcade", "student_wins", student_wins)
    config.set_value("arcade", "met_professors", met_professors)
    var error: Error = config.save(save_path)
    if error != OK:
        push_warning("Campus Arcade could not save its independent progression file: " + str(error))

func choose_weapon(index: int) -> bool:
    if index < 0 or index >= WEAPONS.size():
        return false
    var chosen: Dictionary = WEAPONS[index]
    if level < int(chosen["level"]):
        _announce("%s unlocks at level %d." % [str(chosen["name"]), int(chosen["level"])], 2.5)
        return false
    weapon_index = index
    held_toy_body.material_override = _shared_material(str(chosen["color"]))
    _announce("Equipped %s - a cartoon-only toy." % str(chosen["name"]), 2.8)
    return true

func _refresh_student_label(index: int) -> void:
    var state: Dictionary = students[index]
    var label: Label3D = state["label"]
    var seconds: int = ceili(float(state["break_seconds"]))
    if seconds > 0:
        label.text = "%s | SNACK BREAK %ds" % [str(state["name"]), seconds]
    else:
        label.text = "%s | FOCUS %d/%d" % [str(state["name"]), int(state["focus"]), STUDENT_FOCUS]

func hit_student(index: int, amount: int = 1) -> bool:
    if index < 0 or index >= students.size() or amount <= 0:
        return false
    var state: Dictionary = students[index]
    if float(state["break_seconds"]) > 0.0:
        return false
    state["focus"] = maxi(0, int(state["focus"]) - amount)
    if int(state["focus"]) > 0:
        _refresh_student_label(index)
        _announce("%s: My study notes! Focus %d/%d" % [str(state["name"]), int(state["focus"]), STUDENT_FOCUS], 2.0)
        return true
    state["break_seconds"] = BREAK_DURATION
    var actor: Node3D = state["node"]
    actor.scale = Vector3.ONE * 0.86
    campus_life.pedestrians[index]["talk_remaining"] = BREAK_DURATION
    student_wins += 1
    _award_xp(30)
    _refresh_student_label(index)
    _announce("%s takes a snack break! +30 XP" % str(state["name"]), 3.8)
    return true

func talk_to_professor() -> bool:
    if campus_life.interior_active or campus_life.on_shuttle or player.bicycle_mode:
        return false
    var best_index: int = -1
    var best_distance: float = 4.5
    for i in range(professors.size()):
        var teacher: Node3D = professors[i]["node"]
        var distance: float = Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(teacher.global_position.x, teacher.global_position.z))
        if distance < best_distance:
            best_index = i
            best_distance = distance
    if best_index == -1:
        _announce("Find a fictional professor to request bizarre homework.", 2.8)
        return false
    var info: Dictionary = professors[best_index]
    var name: String = str(info["name"])
    if met_professors.has(name):
        _announce("%s: Did you check the submission deadline?" % name, 3.4)
        return true
    met_professors.append(name)
    _award_xp(20)
    _announce("%s: %s" % [name, str(info["line"])], 4.6)
    return true

func _can_fire() -> bool:
    return hud.visible and not campus_life.interior_active and not campus_life.on_shuttle and not player.bicycle_mode and not player.movement_locked

func try_fire() -> bool:
    if not _can_fire() or shot_cooldown > 0.0 or pending_shot:
        return false
    var chosen: Dictionary = WEAPONS[weapon_index]
    shot_cooldown = float(chosen["cooldown"])
    pending_shot = true
    return true

func _physics_process(_delta: float) -> void:
    if pending_shot:
        pending_shot = false
        _resolve_shot()

func _resolve_shot() -> void:
    if not _can_fire():
        return
    var chosen: Dictionary = WEAPONS[weapon_index]
    var origin: Vector3 = player.camera.global_position
    var forward: Vector3 = -player.camera.global_transform.basis.z.normalized()
    var reach: float = float(chosen["range"]) + minf(6.0, float(level - 1) * 0.8)
    var best_index: int = -1
    var best_kind: int = 0
    var best_depth: float = reach
    var best_position: Vector3 = origin + forward * reach
    # Only eight actors; select by ray distance without allocating candidate arrays.
    for i in range(students.size() + professors.size()):
        var actor: Node3D
        var focus_target: Vector3
        if i < students.size():
            if float(students[i]["break_seconds"]) > 0.0:
                continue
            actor = students[i]["node"]
            focus_target = actor.global_position + Vector3(0.0, 1.15, 0.0)
        else:
            actor = professors[i - students.size()]["node"]
            focus_target = actor.global_position + Vector3(0.0, 1.35, 0.0)
        var offset: Vector3 = focus_target - origin
        var projection: float = offset.dot(forward)
        if projection <= 0.4 or projection >= best_depth:
            continue
        if (offset - forward * projection).length() > 0.58 + projection * 0.015:
            continue
        best_depth = projection
        best_index = i
        best_kind = 1 if i < students.size() else 2
        best_position = focus_target
    if best_index >= 0:
        var ray := PhysicsRayQueryParameters3D.create(origin, best_position)
        ray.exclude = [player.get_rid()]
        var collision: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
        if collision.is_empty() or origin.distance_to(collision["position"]) + 0.2 >= origin.distance_to(best_position):
            if best_kind == 1:
                hit_student(best_index, int(chosen["damage"]))
            else:
                _announce("Professors have a deadline shield. Press K nearby!", 3.0)
        else:
            best_position = collision["position"]
    _show_pooled_projectile(origin + forward * 0.55, best_position, str(chosen["color"]))

func _show_pooled_projectile(start: Vector3, finish: Vector3, color: String) -> void:
    var state: Dictionary = projectiles[next_projectile]
    next_projectile = (next_projectile + 1) % PROJECTILE_CAPACITY
    var actor: MeshInstance3D = state["node"]
    state["active"] = true
    state["from"] = start
    state["to"] = finish
    state["time"] = 0.0
    state["duration"] = clampf(start.distance_to(finish) / 55.0, 0.09, 0.42)
    actor.material_override = _shared_material(color)
    actor.global_position = start
    actor.visible = true

func _announce(value: String, duration: float) -> void:
    message = value
    message_time = duration
    _refresh_status()

func _refresh_status() -> void:
    if status_label == null:
        return
    var chosen: Dictionary = WEAPONS[weapon_index]
    var lines := PackedStringArray()
    lines.append("CAMPUS ARCADE | LV %d | XP %d/%d" % [level, xp, xp_required()])
    lines.append("Student wins: %d | %s" % [student_wins, str(chosen["name"])])
    lines.append("[1/2/3] toys  [LMB] play  [U] teacher")
    lines.append(message if message_time > 0.0 else "Pure cartoon: nobody gets hurt.")
    status_label.text = "\n".join(lines)

func _process(delta: float) -> void:
    shot_cooldown = maxf(0.0, shot_cooldown - delta)
    message_time = maxf(0.0, message_time - delta)
    for i in range(students.size()):
        var state: Dictionary = students[i]
        var remaining: float = float(state["break_seconds"])
        if remaining <= 0.0:
            continue
        var previous_sec: int = ceili(remaining)
        remaining = maxf(0.0, remaining - delta)
        state["break_seconds"] = remaining
        if remaining <= 0.0:
            state["focus"] = STUDENT_FOCUS
            var actor: Node3D = state["node"]
            actor.scale = Vector3.ONE
        elif float(campus_life.pedestrians[i]["talk_remaining"]) < remaining:
            campus_life.pedestrians[i]["talk_remaining"] = remaining
        if ceili(remaining) != previous_sec:
            _refresh_student_label(i)
    for state in projectiles:
        if not bool(state["active"]):
            continue
        var elapsed: float = float(state["time"]) + delta
        state["time"] = elapsed
        var fraction: float = minf(1.0, elapsed / float(state["duration"]))
        var actor: MeshInstance3D = state["node"]
        actor.global_position = (state["from"] as Vector3).lerp(state["to"], fraction)
        if fraction >= 1.0:
            actor.visible = false
            state["active"] = false
    if photo_visible != hud.visible:
        photo_visible = hud.visible
        status_layer.visible = photo_visible
        held_toy.visible = photo_visible
        for student in students:
            var student_label: Label3D = student["label"]
            student_label.visible = photo_visible
        for professor in professors:
            var professor_label: Label3D = professor["label"]
            professor_label.visible = photo_visible
    hud_update_elapsed += delta
    if hud_update_elapsed >= 0.25:
        hud_update_elapsed = 0.0
        _refresh_status()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_1:
                choose_weapon(0)
            KEY_2:
                choose_weapon(1)
            KEY_3:
                choose_weapon(2)
            KEY_U:
                talk_to_professor()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        try_fire()
