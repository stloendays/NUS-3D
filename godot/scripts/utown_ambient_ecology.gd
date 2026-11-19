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
                "panic": i == 0, "peck": 0.0}
            animal.position = base
            if kind == "birds":
                _part(animal, "Body", _sphere(0.16), Vector3(0, 0.19, 0), Color("#41464b"))
                _part(animal, "Head", _sphere(0.11), Vector3(0, 0.32, -0.13), Color("#30333a"))
                _part(animal, "Beak", _box(Vector3(0.11, 0.045, 0.12)), Vector3(0, 0.3, -0.25), Color("#e5b24f"))
                birds.append(state)
            elif kind == "butterflies":
                _part(animal, "Body", _sphere(0.045), Vector3.ZERO, Color("#5c4b41"))
                _part(animal, "LeftWing", _box(Vector3(0.18, 0.018, 0.25)), Vector3(-0.12, 0, 0), Color("#edbd6d"))
                _part(animal, "RightWing", _box(Vector3(0.18, 0.018, 0.25)), Vector3(0.12, 0, 0), Color("#edbd6d"))
                state["base"] = base + Vector3(0, 1.2, 0)
                butterflies.append(state)
            elif kind == "cats":
                _part(animal, "Body", _sphere(0.32), Vector3(0, 0.36, 0.13), Color("#d2ad80"))
                _part(animal, "Head", _sphere(0.20), Vector3(0, 0.48, -0.23), Color("#d2ad80"))
                _part(animal, "Tail", _box(Vector3(0.10, 0.47, 0.10)), Vector3(0, 0.55, 0.42), Color("#d2ad80"))
                cats.append(state)
            else:
                _part(animal, "Body", _sphere(0.28), Vector3(0, 0.35, 0.04), Color("#c58b50"))
                _part(animal, "Head", _sphere(0.16), Vector3(0, 0.62, -0.19), Color("#cf9d62"))
                _part(animal, "Comb", _box(Vector3(0.13, 0.16, 0.08)), Vector3(0, 0.83, -0.2), Color("#cf403a"))
                _part(animal, "Beak", _box(Vector3(0.13, 0.06, 0.15)), Vector3(0, 0.59, -0.36), Color("#e9b43f"))
                _part(animal, "LeftWing", _box(Vector3(0.12, 0.24, 0.28)), Vector3(-0.26, 0.4, 0), Color("#a76b43"))
                _part(animal, "RightWing", _box(Vector3(0.12, 0.24, 0.28)), Vector3(0.26, 0.4, 0), Color("#a76b43"))
                _part(animal, "LegL", _box(Vector3(0.06, 0.25, 0.07)), Vector3(-0.12, 0.12, 0), Color("#c69a42"))
                _part(animal, "LegR", _box(Vector3(0.06, 0.25, 0.07)), Vector3(0.12, 0.12, 0), Color("#c69a42"))
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
    if moved > 1.7 or player.movement_locked or life.on_shuttle or not player.is_on_floor():
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
                node.visible = node.visible and (not rain or i == 0)
                var alert: float = maxf(0, float(state["alert"]) - delta)
                if distance < 4.0 and alert == 0 and not rain:
                    alert = 3.0
                    state["heading"] = atan2(base.x - player.global_position.x,
                        base.z - player.global_position.z)
                    if _sound_enabled() and DisplayServer.get_name() != "headless":
                        chicken_player.global_position = base
                        chicken_player.stream = sound_clips["panic_cluck"]
                        chicken_player.play()
                state["alert"] = alert
                var pace: float = 3.4 if alert > 0 else 0.22
                var direction := Vector3(sin(float(state["heading"])), 0,
                    cos(float(state["heading"])))
                var roam: float = sin(clock * 0.5 + float(state["phase"])) * pace
                node.position = base + direction * roam
                node.rotation.y = float(state["heading"])
                node.get_node("Head").rotation.x = sin(clock * 3.0 + float(state["phase"])) * (0.2 if alert == 0 else 0.04)
                node.get_node("LeftWing").rotation.z = sin(clock * 16.0) * (0.6 if alert > 0 else 0.04)
                node.get_node("RightWing").rotation.z = -sin(clock * 16.0) * (0.6 if alert > 0 else 0.04)

func _update_leaves(indoor: bool, rain: bool) -> void:
    leaf_batch.visible = not indoor and not rain and player.global_position.length() < 220
