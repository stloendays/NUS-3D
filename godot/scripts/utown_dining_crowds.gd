extends Node3D
class_name UTownDiningCrowds
## Soft crowd blocking: no physics bodies, no permanent route obstruction.
const MAX_PEOPLE: int = 28
const PERSONAL_RADIUS: float = 0.55
const SHOVE_RADIUS: float = 1.1
@onready var clock: UTownCampusClock = $"../CampusClock"
@onready var player: UTownPlayer = $"../Player"
@onready var life: UTownCampusLife = $"../CampusLife"
@onready var dining: UTownGreenDining = $"../GreenDining"
@onready var world: UTownWorld = $"../World"
var people: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var last_player_position: Vector3
var crowd_contacts: int = 0
var crowd_shoves: int = 0
var congestion: float = 0.0
var tick: float = 0.0
var hud: Label
var crowd_root: Node3D
var player_slowdown: float = 1.0
var camera: Camera3D

func _ready() -> void:
    rng.seed = 20261120
    last_player_position = player.global_position
    crowd_root = Node3D.new()
    crowd_root.name = "IllustrativeLunchCrowd"
    add_child(crowd_root)
    var body_mesh := CapsuleMesh.new()
    body_mesh.radius = 0.23
    body_mesh.height = 1.45
    body_mesh.radial_segments = 8
    body_mesh.rings = 2
    var colors := [Color("#d48a78"), Color("#86a4c2"), Color("#b7a0c9"), Color("#8bbaa5")]
    var shared_materials: Array[StandardMaterial3D] = []
    for color in colors:
        var shared := StandardMaterial3D.new()
        shared.albedo_color = color
        shared_materials.append(shared)
    for i in range(MAX_PEOPLE):
        var npc := Node3D.new()
        npc.name = "Diner_%02d" % i
        crowd_root.add_child(npc)
        var mesh := MeshInstance3D.new()
        mesh.name = "StylizedDiner"
        mesh.mesh = body_mesh
        mesh.material_override = shared_materials[i % shared_materials.size()]
        mesh.position.y = 0.78
        mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        npc.add_child(mesh)
        var lane: int = i % 2
        var slot: int = i / 2
        var local := Vector3(-10.0 + float(slot % 7) * 3.0,
            0.0, -3.4 + float(slot / 7) * 3.0 + float(lane) * 2.5)
        var plaza: Node3D = world.get_node_or_null("TownPlaza_approximate") as Node3D
        var base: Vector3 = plaza.to_global(local) if plaza != null else local
        npc.global_position = base
        npc.visible = false
        people.append({"node": npc, "base": base, "offset": Vector3.ZERO,
            "push": Vector3.ZERO, "phase": rng.randf_range(0, TAU)})
    hud = Label.new()
    hud.name = "CampusTimeAndDining"
    hud.position = Vector2(18, 112)
    hud.add_theme_font_size_override("font_size", 14)
    hud.add_theme_color_override("font_color", Color("#f7f0df"))
    hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var hud_root: CanvasLayer = get_node_or_null("../HUD") as CanvasLayer
    if hud_root != null:
        hud_root.add_child(hud)

func _process(delta: float) -> void:
    tick += delta
    if tick < 0.1:
        return
    var elapsed: float = tick
    tick = 0.0
    congestion = clock.dining_intensity()
    if not is_instance_valid(camera) or not camera.is_current():
        camera = get_viewport().get_camera_3d()
    var active_count: int = int(round(lerpf(4.0, float(MAX_PEOPLE), congestion)))
    if life.interior_active:
        active_count = 0
    var current: Vector3 = player.global_position
    var player_delta: Vector3 = current - last_player_position
    last_player_position = current
    player_delta.y = 0.0
    var speed: float = player_delta.length() / maxf(elapsed, 0.001)
    var blocked: bool = false
    for i in range(people.size()):
        var state: Dictionary = people[i]
        var npc: Node3D = state["node"]
        npc.visible = i < active_count and npc.global_position.distance_squared_to(current) < 9025.0
        if npc.visible and camera != null:
            npc.visible = camera.is_position_in_frustum(npc.global_position + Vector3.UP)
        if i >= active_count:
            continue
        # Nearby pedestrians still affect movement even when behind the camera.
        var near_player: bool = npc.global_position.distance_squared_to(current) < 9.0
        if not npc.visible and not near_player:
            continue
        var base: Vector3 = state["base"]
        var offset: Vector3 = state["offset"]
        var push: Vector3 = state["push"]
        var desired: Vector3 = base + Vector3(sin(clock.minute_of_day * 0.016 + float(state["phase"])) * 0.3,
            0, cos(clock.minute_of_day * 0.013 + float(state["phase"])) * 0.2)
        push = push.move_toward(Vector3.ZERO, elapsed * 1.6)
        offset = offset.lerp(desired - base, minf(1.0, elapsed * 1.8))
        var pos: Vector3 = base + offset + push
        var away: Vector3 = pos - current
        away.y = 0
        var distance: float = away.length()
        if (npc.visible or near_player) and distance < SHOVE_RADIUS and not player.movement_locked and not life.on_shuttle:
            var direction: Vector3 = away.normalized() if distance > 0.01 else Vector3.RIGHT
            var bike: bool = player.bicycle_mode
            var running: bool = speed > 5.5
            # NPCs yield to a fast-moving player. This is a soft comic shove,
            # never a rigid collision that traps the player or launches bodies.
            if running or bike:
                push += direction * (0.85 if bike else 0.55)
                crowd_shoves += 1
            elif distance < PERSONAL_RADIUS + 0.22:
                blocked = true
                crowd_contacts += 1
                push += direction * 0.12
        state["offset"] = offset
        state["push"] = push.limit_length(1.65)
        npc.global_position = base + offset + state["push"]
    # Controller reads this factor before its own movement integration.
    # Walking into a crowd feels slower; sprinting always clears the lane.
    player_slowdown = 0.55 if blocked and speed < 5.5 and not player.bicycle_mode else 1.0
    if hud != null:
        hud.text = "%s  |  %s" % [clock.formatted_time(),
            "LUNCH RUSH · PUSH THROUGH" if congestion > 0.7 else
            "DINNER RUSH" if clock.dinner_intensity() > 0.4 else "CAMPUS LIFE"]
