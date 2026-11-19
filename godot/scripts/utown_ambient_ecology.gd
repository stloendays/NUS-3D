extends Node3D
class_name UTownAmbientEcology
## Decorative wildlife only; no navigation, collision, quests or controls.
const TICK: float = 0.12
@export_range(0, 2, 1) var detail_level: int = 1
@onready var world: UTownWorld = $"../World"
@onready var player: UTownPlayer = $"../Player"
@onready var weather: UTownWeather = $"../Weather"
@onready var life: UTownCampusLife = $"../CampusLife"
@onready var dining: UTownGreenDining = $"../GreenDining"
var birds: Array[Dictionary] = []
var butterflies: Array[Dictionary] = []
var cats: Array[Dictionary] = []
var chickens: Array[Dictionary] = []
var sound_clips: Dictionary = {}
var leaf_batch: MultiMeshInstance3D
var footstep_count: int = 0
var bird_startle_count: int = 0
var rng := RandomNumberGenerator.new()
var lawn: PackedVector2Array = PackedVector2Array()
var clock: float = 0.0
var tick: float = 0.0
var last_position := Vector3.ZERO
var stride_distance: float = 0.0
var cluck_wait: float = 3.0
var bird_wait: float = 4.0
var chicken_cluck_count: int = 0
var chicken_flee_count: int = 0
var step_player: AudioStreamPlayer
var bird_player: AudioStreamPlayer3D
var chicken_player: AudioStreamPlayer3D

func budgets() -> Dictionary:
    if detail_level == 0:
        return {"birds": 5, "butterflies": 6, "cats": 1, "leaves": 20, "chickens": 3}
    if detail_level == 2:
        return {"birds": 14, "butterflies": 18, "cats": 3, "leaves": 64, "chickens": 9}
    return {"birds": 10, "butterflies": 12, "cats": 2, "leaves": 40, "chickens": 6}

func _ready() -> void:
    rng.seed = 20261119
    for point in world.layout.get("green", {}).get("polygon_lonlat", []):
        var p: Vector3 = world.lonlat_to_world(float(point[0]), float(point[1]))
        lawn.append(Vector2(p.x, p.z))
    _make_audio()
    _make_animals()
    _make_leaves()
    last_position = player.global_position

func _mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.86
    return m

func _part(parent: Node3D, name: String, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
    var p := MeshInstance3D.new()
    p.name = name
    p.mesh = mesh
    p.position = at
    p.material_override = _mat(color)
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(p)
    return p

func _sphere(radius: float) -> SphereMesh:
    var m := SphereMesh.new()
    m.radius = radius
    m.height = radius * 2.0
    m.radial_segments = 8
    m.rings = 4
    return m

func _box(size: Vector3) -> BoxMesh:
    var m := BoxMesh.new()
    m.size = size
    return m

func _sample_lawn() -> Vector3:
    if lawn.size() < 3:
        return Vector3(5, 0, 5)
    var bounds := Rect2(lawn[0], Vector2.ZERO)
    for p in lawn:
        bounds = bounds.expand(p)
    for attempt in range(320):
        var p := Vector2(rng.randf_range(bounds.position.x, bounds.end.x),
            rng.randf_range(bounds.position.y, bounds.end.y))
        if not Geometry2D.is_point_in_polygon(p, lawn):
            continue
        if dining != null and not dining.is_clear_lawn_point(p, 2.0):
            continue
        return Vector3(p.x, 0, p.y)
    return Vector3(5, 0, 5)

func _make_animals() -> void:
    var root := Node3D.new()
    root.name = "IllustrativeCampusWildlife"
    add_child(root)
    for kind in ["birds", "butterflies", "cats", "chickens"]:
        var count: int = int(budgets()[kind])
        for i in range(count):
            var animal := Node3D.new()
            animal.name = "%s_%02d" % [kind, i]
            root.add_child(animal)
            var base := _sample_lawn()
            var phase := rng.randf_range(0, TAU)
            var state: Dictionary = {"node": animal, "base": base, "phase": phase,
                "flight": 0.0, "alert": 0.0, "heading": rng.randf_range(-PI, PI),
                "panic": i == 0, "peck": 0.0, "target": base,
                "walk_timer": rng.randf_range(1.5, 4.0), "flee_timer": 0.0,
                "cooldown": 0.0, "moving": false}
            animal.position = base
            if kind == "birds":
                var feather: Color = Color("#40484c") if i % 2 == 0 else Color("#5a514c")
                _part(animal, "Body", _sphere(0.17), Vector3(0, 0.22, 0), feather)
                _part(animal, "Chest", _sphere(0.125), Vector3(0, 0.22, -0.11), Color("#b4a99a"))
                _part(animal, "Head", _sphere(0.12), Vector3(0, 0.35, -0.14), Color("#30383c"))
                _part(animal, "Beak", _box(Vector3(0.11, 0.045, 0.16)), Vector3(0, 0.32, -0.29), Color("#e8ae4e"))
                _part(animal, "LeftWing", _box(Vector3(0.09, 0.05, 0.24)), Vector3(-0.16, 0.23, 0.04), feather)
                _part(animal, "RightWing", _box(Vector3(0.09, 0.05, 0.24)), Vector3(0.16, 0.23, 0.04), feather)
                _part(animal, "Tail", _box(Vector3(0.10, 0.035, 0.25)), Vector3(0, 0.19, 0.25), feather)
                for side in [-1.0, 1.0]:
                    _part(animal, "Eye", _sphere(0.022), Vector3(side * 0.105, 0.37, -0.205), Color("#e5c75e"))
                    _part(animal, "Leg", _box(Vector3(0.025, 0.16, 0.025)), Vector3(side * 0.07, 0.08, 0), Color("#c5a15b"))
                birds.append(state)
            elif kind == "butterflies":
                _part(animal, "Body", _sphere(0.045), Vector3.ZERO, Color("#5c4b41"))
                _part(animal, "LeftWing", _box(Vector3(0.18, 0.018, 0.25)), Vector3(-0.12, 0, 0), Color("#edbd6d"))
                _part(animal, "RightWing", _box(Vector3(0.18, 0.018, 0.25)), Vector3(0.12, 0, 0), Color("#edbd6d"))
                state["base"] = base + Vector3(0, 1.2, 0)
                butterflies.append(state)
            elif kind == "cats":
                var fur: Color = [Color("#d2ad80"), Color("#77777d"), Color("#d7d2c7")][i % 3]
                _part(animal, "Body", _sphere(0.33), Vector3(0, 0.36, 0.12), fur)
                _part(animal, "Chest", _sphere(0.20), Vector3(0, 0.36, -0.16), Color("#efe1c9"))
                _part(animal, "Head", _sphere(0.22), Vector3(0, 0.52, -0.24), fur)
                _part(animal, "Muzzle", _sphere(0.105), Vector3(0, 0.44, -0.43), Color("#f0e4d3"))
                _part(animal, "Nose", _sphere(0.036), Vector3(0, 0.48, -0.525), Color("#b77c7a"))
                _part(animal, "Tail", _box(Vector3(0.10, 0.47, 0.10)), Vector3(0, 0.55, 0.43), fur)
                for side in [-1.0, 1.0]:
                    var ear := _part(animal, "Ear", _box(Vector3(0.16, 0.19, 0.07)),
                        Vector3(side * 0.15, 0.73, -0.27), fur)
                    ear.rotation.z = side * -0.25
                    _part(animal, "Eye", _sphere(0.036), Vector3(side * 0.11, 0.55, -0.427), Color("#60856b"))
                    for leg_z in [-0.18, 0.27]:
                        _part(animal, "Paw", _sphere(0.09),
                            Vector3(side * 0.22, 0.1, leg_z), fur)
                cats.append(state)
            else:
                var plumage: Color = [Color("#c58b50"), Color("#eee5d3"), Color("#8e7564")][i % 3]
                _part(animal, "Body", _sphere(0.30), Vector3(0, 0.38, 0.05), plumage)
                _part(animal, "Breast", _sphere(0.23), Vector3(0, 0.41, -0.18), plumage.lightened(0.10))
                _part(animal, "Head", _sphere(0.17), Vector3(0, 0.68, -0.22), plumage)
                _part(animal, "Comb", _box(Vector3(0.13, 0.16, 0.08)), Vector3(0, 0.90, -0.2), Color("#cf403a"))
                _part(animal, "Beak", _box(Vector3(0.13, 0.06, 0.15)), Vector3(0, 0.64, -0.41), Color("#e9b43f"))
                _part(animal, "LeftWing", _box(Vector3(0.12, 0.24, 0.28)), Vector3(-0.29, 0.43, 0), plumage.darkened(0.17))
                _part(animal, "RightWing", _box(Vector3(0.12, 0.24, 0.28)), Vector3(0.29, 0.43, 0), plumage.darkened(0.17))
                for side in [-1.0, 1.0]:
                    _part(animal, "Eye", _sphere(0.028), Vector3(side * 0.145, 0.71, -0.29), Color("#282725"))
                    _part(animal, "Wattle", _sphere(0.065), Vector3(side * 0.06, 0.53, -0.39), Color("#c74a43"))
                    _part(animal, "Leg", _box(Vector3(0.055, 0.25, 0.065)), Vector3(side * 0.13, 0.12, 0), Color("#c69a42"))
                    for toe in [-1.0, 0.0, 1.0]:
                        _part(animal, "Toe", _box(Vector3(0.038, 0.045, 0.18)),
                            Vector3(side * 0.13 + toe * 0.055, 0.035, -0.10), Color("#c69a42"))
                for feather_index in range(3):
                    var tail := _part(animal, "TailFeather", _box(Vector3(0.085, 0.32, 0.085)),
                        Vector3((float(feather_index) - 1.0) * 0.10, 0.63, 0.31), plumage.darkened(0.24))
                    tail.rotation.x = -0.48
                chickens.append(state)

func _make_leaves() -> void:
    var mesh := QuadMesh.new()
    mesh.size = Vector2(0.13, 0.22)
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.mesh = mesh
    batch.instance_count = int(budgets()["leaves"])
    leaf_batch = MultiMeshInstance3D.new()
    leaf_batch.name = "LeafDrift_MultiMesh"
    leaf_batch.multimesh = batch
    leaf_batch.material_override = _mat(Color("#9cae66"))
    add_child(leaf_batch)
    for i in range(batch.instance_count):
        batch.set_instance_transform(i, Transform3D(Basis(),
            Vector3(rng.randf_range(-5, 5), rng.randf_range(0.3, 3.0), rng.randf_range(-5, 5))))
    leaf_batch.visible = false

func _wav(frequency: float, length: float, noise_mix: float) -> AudioStreamWAV:
    var count: int = int(length * 22050.0)
    var data := PackedByteArray()
    data.resize(count * 2)
    var sound_rng := RandomNumberGenerator.new()
    sound_rng.seed = int(frequency * 10)
    for i in range(count):
        var t: float = float(i) / 22050.0
        var decay: float = pow(1.0 - float(i) / float(count), 2.0)
        var noise: float = sound_rng.randf_range(-1, 1)
        var sample: float = (sin(TAU * frequency * t) * (1.0 - noise_mix) +
            noise * noise_mix) * decay * 0.22
        data.encode_s16(i * 2, int(clampf(sample, -1, 1) * 32767.0))
    var clip := AudioStreamWAV.new()
    clip.format = AudioStreamWAV.FORMAT_16_BITS
    clip.mix_rate = 22050
    clip.stereo = false
    clip.data = data
    return clip

func _make_audio() -> void:
    sound_clips = {
        "grass": _wav(95, 0.17, 0.8), "paving": _wav(140, 0.14, 0.65),
        "interior": _wav(170, 0.12, 0.4), "chirp": _wav(1780, 0.27, 0.03),
        "cluck": _wav(460, 0.23, 0.16), "panic_cluck": _wav(720, 0.31, 0.2)
    }
    step_player = AudioStreamPlayer.new()
    step_player.volume_db = -18
    add_child(step_player)
    bird_player = AudioStreamPlayer3D.new()
    bird_player.volume_db = -15
    bird_player.max_distance = 55
    bird_player.stream = sound_clips["chirp"]
    add_child(bird_player)
    chicken_player = AudioStreamPlayer3D.new()
    chicken_player.volume_db = -14
    chicken_player.max_distance = 45
    add_child(chicken_player)

func _sound_enabled() -> bool:
    var sound: NUS3DUISound = get_node_or_null("/root/UISound") as NUS3DUISound
    return sound == null or sound.enabled

func surface_at_player() -> String:
    if life.interior_active:
        return "interior"
    return "grass" if Geometry2D.is_point_in_polygon(
        Vector2(player.global_position.x, player.global_position.z), lawn) else "paving"

func _advance_footsteps() -> void:
    var current: Vector3 = player.global_position
    var moved: float = Vector2(current.x - last_position.x, current.z - last_position.z).length()
    last_position = current
    if moved > 1.7 or player.movement_locked or life.on_shuttle or player.bicycle_mode or not player.is_on_floor():
        stride_distance = 0
        return
    stride_distance += moved
    if stride_distance > 1.3:
        stride_distance -= 1.3
        footstep_count += 1
        if _sound_enabled() and DisplayServer.get_name() != "headless":
            step_player.stream = sound_clips[surface_at_player()]
            step_player.play()

func _process(delta: float) -> void:
    _advance_footsteps()
    clock += delta
    tick += delta
    if tick < TICK:
        return
    var elapsed: float = tick
    tick = 0.0
    var indoor: bool = life.interior_active or weather.indoor
    var rain: bool = weather.mode >= 3
    var night: bool = world.lighting_mode >= 2
    _update_animals(elapsed, indoor, rain, night)
    _update_leaves(indoor, rain)
    _tick_calls(elapsed, indoor, rain, night)

func _update_animals(delta: float, indoor: bool, rain: bool, night: bool) -> void:
    for kind in ["birds", "butterflies", "cats", "chickens"]:
        var collection: Array = get(kind)
        for i in range(collection.size()):
            var state: Dictionary = collection[i]
            var node: Node3D = state["node"]
            var base: Vector3 = state["base"]
            var distance: float = player.global_position.distance_to(base)
            node.visible = not indoor and distance < 85.0
            if kind == "butterflies":
                node.visible = node.visible and not rain and not night
                node.position = base + Vector3(sin(clock * 1.3 + float(state["phase"])) * 0.4,
                    sin(clock * 2.2 + float(state["phase"])) * 0.25, 0)
                node.get_node("LeftWing").rotation.z = sin(clock * 20) * 0.6
                node.get_node("RightWing").rotation.z = -sin(clock * 20) * 0.6
            elif kind == "birds":
                node.visible = node.visible and (not rain or i % 4 == 0) and (not night or i % 3 == 0)
                var timer: float = maxf(0, float(state["flight"]) - delta)
                if distance < 4.8 and timer == 0 and not rain:
                    timer = 2.0
                    bird_startle_count += 1
                state["flight"] = timer
                node.position = base + Vector3(0, sin((2.0 - timer) * 1.57) * 1.2 if timer > 0 else 0, 0)
            elif kind == "cats":
                node.visible = node.visible and (not rain or i == 0)
                node.position = base + Vector3(0, sin(clock * 1.5 + float(state["phase"])) * 0.012, 0)
            else:
                _tick_chicken(state, delta, indoor, rain, night)

func _safe_chicken_point(candidate: Vector3) -> bool:
    var p := Vector2(candidate.x, candidate.z)
    return Geometry2D.is_point_in_polygon(p, lawn) and (dining == null or dining.is_clear_lawn_point(p, 1.2))

func _tick_chicken(state: Dictionary, delta: float, indoor: bool, rain: bool, night: bool) -> void:
    var chicken: Node3D = state["node"]
    var pos: Vector3 = chicken.position
    var distance: float = Vector2(player.global_position.x - pos.x, player.global_position.z - pos.z).length()
    chicken.visible = not indoor and not rain and not night and distance < 75.0
    if not chicken.visible:
        return
    var cooldown: float = maxf(0.0, float(state["cooldown"]) - delta)
    var flee_timer: float = maxf(0.0, float(state["flee_timer"]) - delta)
    if distance < 3.8 and cooldown <= 0.0 and flee_timer <= 0.0:
        flee_timer = 2.2
        cooldown = 5.0
        chicken_flee_count += 1
        var away: Vector3 = pos - player.global_position
        away.y = 0.0
        if away.length_squared() < 0.01:
            away = Vector3.FORWARD
        var destination: Vector3 = pos + away.normalized() * (7.0 if bool(state["panic"]) else 4.5)
        if _safe_chicken_point(destination):
            state["target"] = destination
        else:
            state["target"] = state["base"]
        _play_chicken_call(pos, true)
    state["cooldown"] = cooldown
    state["flee_timer"] = flee_timer
    var walk_timer: float = float(state["walk_timer"]) - delta
    if walk_timer <= 0.0 and flee_timer <= 0.0:
        walk_timer = rng.randf_range(2.0, 5.0)
        var target: Vector3 = state["base"] + Vector3(
            rng.randf_range(-4.0, 4.0), 0.0, rng.randf_range(-4.0, 4.0))
        if _safe_chicken_point(target):
            state["target"] = target
    state["walk_timer"] = walk_timer
    var diff: Vector3 = state["target"] - pos
    diff.y = 0.0
    var speed: float = 4.4 if flee_timer > 0.0 else 0.55
    if diff.length() > 0.15:
        var step: Vector3 = diff.normalized() * minf(diff.length(), speed * delta)
        if _safe_chicken_point(pos + step):
            chicken.position += step
            chicken.rotation.y = lerp_angle(chicken.rotation.y, atan2(-diff.x, -diff.z), minf(1.0, delta * 7.0))
        state["moving"] = true
    else:
        state["moving"] = false
    var peck: float = maxf(0.0, sin(clock * 2.9 + float(state["phase"])))
    chicken.get_node("Head").rotation.x = peck * 0.34 if flee_timer <= 0.0 else 0.0
    var flap: float = sin(clock * 22.0 + float(state["phase"])) * 0.65 if flee_timer > 0.0 else 0.035
    chicken.get_node("LeftWing").rotation.z = flap
    chicken.get_node("RightWing").rotation.z = -flap
    chicken.position.y = absf(sin(clock * 13.0)) * 0.065 if flee_timer > 0.0 else 0.0

func _play_chicken_call(position: Vector3, panic: bool = false) -> void:
    chicken_cluck_count += 1
    if not _sound_enabled() or DisplayServer.get_name() == "headless":
        return
    chicken_player.global_position = position
    chicken_player.stream = sound_clips["panic_cluck" if panic else "cluck"]
    chicken_player.pitch_scale = rng.randf_range(0.9, 1.12)
    chicken_player.play()

func _tick_calls(delta: float, indoor: bool, rain: bool, night: bool) -> void:
    cluck_wait -= delta
    bird_wait -= delta
    if indoor or rain or night:
        return
    if cluck_wait <= 0.0:
        cluck_wait = rng.randf_range(5.0, 11.0)
        for state in chickens:
            var chicken: Node3D = state["node"]
            if chicken.visible and chicken.global_position.distance_to(player.global_position) < 35.0:
                _play_chicken_call(chicken.global_position)
                break
    if bird_wait <= 0.0:
        bird_wait = rng.randf_range(6.0, 12.0)
        for state in birds:
            var bird: Node3D = state["node"]
            if bird.visible and bird.global_position.distance_to(player.global_position) < 40.0:
                if _sound_enabled() and DisplayServer.get_name() != "headless":
                    bird_player.global_position = bird.global_position
                    bird_player.play()
                break

func _update_leaves(indoor: bool, rain: bool) -> void:
    leaf_batch.visible = not indoor and not rain and player.global_position.length() < 220
