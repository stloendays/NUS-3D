extends Node
class_name UTownIndoorNPCs
## Six fictional room occupants with lightweight routine animation.
## This is authored game content, not a representation of real NUS students.

const TALK_RADIUS: float = 4.6

@onready var life: UTownCampusLife = $"../CampusLife"
@onready var player: UTownPlayer = $"../Player"

var actors: Array[Dictionary] = []
var indoor_count: int = 0
var last_spoken: String = ""

func _ready() -> void:
    _spawn_occupants()

func _specifications() -> Array[Dictionary]:
    return [
        {"room":"ERC", "name":"Maya", "role":"Cafe attendant", "routine":"serve", "position":Vector3(-8.0, 0.0, 6.9), "heading":PI,
            "line":"Coffee and a study break? The cafe is a fictional campus-life feature."},
        {"room":"ERC", "name":"Ethan", "role":"Quiet reader", "routine":"read", "position":Vector3(7.3, 0.0, 5.55), "heading":PI,
            "line":"I am revising for tomorrow. The mezzanine is quieter upstairs."},
        {"room":"ERC", "name":"Mei", "role":"Study wanderer", "routine":"stairs", "position":Vector3(-2.2, 3.5, -6.2), "heading":PI * 0.5,
            "stair_path":[Vector3(-2.2, 3.5, -6.2), Vector3(6.4, 3.5, -6.2), Vector3(9.25, 3.35, -3.8), Vector3(9.25, 1.75, -0.2), Vector3(9.25, 0.18, 3.5), Vector3(7.5, 0.18, 6.2)],
            "line":"I found a free desk above the lounge. You can use L to visit the upper level."},
        {"room":"SRC", "name":"Lucas", "role":"Warm-up", "routine":"exercise", "position":Vector3(1.2, 0.0, -2.2), "heading":-PI * 0.25,
            "line":"Doing some stretches before a game. This is a conceptual sports hall."},
        {"room":"SRC", "name":"Aisha", "role":"Spectator", "routine":"read", "position":Vector3(7.3, 0.0, 5.25), "heading":PI,
            "line":"You can watch the hall from the upstairs viewing gallery."},
        {"room":"SRC", "name":"Daniel", "role":"Refill volunteer", "routine":"walk", "position":Vector3(-8.2, 0.0, 5.85), "heading":PI * 0.5,
            "line":"The refill station is a fictional prop. Press F near it to record a visit."}
    ]

func _mat(hex: String, roughness: float = 0.85) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.html(hex)
    material.roughness = roughness
    return material

func _prop(parent: Node3D, name: String, point: Vector3, size: Vector3, material: Material) -> Node3D:
    var result := Node3D.new()
    result.name = name
    result.position = point
    parent.add_child(result)
    var visual := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    visual.mesh = box
    visual.material_override = material
    result.add_child(visual)
    return result

func _spawn_occupants() -> void:
    var specs: Array[Dictionary] = _specifications()
    for i in range(specs.size()):
        var spec: Dictionary = specs[i]
        var room_id: String = str(spec["room"])
        if not life.interiors.has(room_id):
            continue
        var room: Node3D = life.interiors[room_id]
        # Reuse existing procedural pedestrian body/pivots. No external assets.
        var actor: Node3D = life._make_person(i)
        actor.name = "IndoorNPC_%s_%s" % [room_id, str(spec["name"])]
        actor.position = spec["position"]
        actor.rotation.y = float(spec["heading"])
        actor.visible = false
        room.add_child(actor)

        # Distinguishable head silhouettes, small faces and shoes keep the
        # fictional indoor cast readable from the new third-person screenshots.
        var hair_cap := MeshInstance3D.new()
        hair_cap.name = "HairCap"
        var hair_mesh := SphereMesh.new()
        hair_mesh.radius = 0.227
        hair_mesh.height = 0.454
        hair_cap.mesh = hair_mesh
        hair_cap.position = Vector3(0.0, 1.84, 0.0)
        hair_cap.scale = Vector3(1.03, 0.48, 1.03)
        var hair_palette: PackedStringArray = PackedStringArray([
            "#323b40", "#584534", "#292f36", "#4e3931", "#39434e", "#53463f"])
        hair_cap.material_override = _mat(hair_palette[i], 0.92)
        actor.add_child(hair_cap)
        var features := _mat("#2d3439")
        for eye_side in [-1.0, 1.0]:
            _prop(actor, "Eye", Vector3(eye_side * 0.076, 1.72, -0.207),
                Vector3(0.038, 0.038, 0.026), features)
            _prop(actor, "Shoe", Vector3(eye_side * 0.14, 0.10, -0.13),
                Vector3(0.21, 0.15, 0.30), _mat("#2d3c46"))

        var routine: String = str(spec["routine"])
        var label := Label3D.new()
        label.name = "NPCNameTag"
        label.text = "%s  /  %s" % [str(spec["name"]), str(spec["role"])]
        label.font_size = 18
        label.pixel_size = 0.009
        label.outline_size = 4
        label.modulate = Color.html("#e7efec")
        label.position = Vector3(0.0, 2.17, 0.0)
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        actor.add_child(label)

        var book := _mat("#d1c29d")
        var glass := _mat("#3b5864", 0.34)
        var ceramic := _mat("#dce6df", 0.45)
        if routine == "read":
            # Seated torso/legs and gently moving open book.
            actor.position.y -= 0.33
            _prop(actor, "OpenBook", Vector3(0.0, 0.74, -0.35), Vector3(0.52, 0.04, 0.35), book)
            label.position.y = 1.90
        elif routine == "serve":
            _prop(actor, "CafeOrderScreen", Vector3(0.05, 1.12, -0.36), Vector3(0.43, 0.27, 0.06), glass)
            _prop(actor, "CoffeeCup", Vector3(0.33, 0.95, -0.32), Vector3(0.15, 0.18, 0.15), ceramic)
        elif routine == "walk":
            _prop(actor, "CarrySatchel", Vector3(0.26, 0.83, 0.16), Vector3(0.44, 0.56, 0.23), glass)
        elif routine == "exercise":
            _prop(actor, "Wristband", Vector3(0.43, 0.84, 0.0), Vector3(0.20, 0.12, 0.20), ceramic)

        var offset: float = float(i) * 1.27
        actors.append({
            "id": room_id + "/" + str(spec["name"]),
            "room": room_id,
            "node": actor,
            "name": str(spec["name"]),
            "role": str(spec["role"]),
            "routine": routine,
            "dialogue": str(spec["line"]),
            "origin": actor.position,
            "heading": float(spec["heading"]),
            "phase": offset,
            "talk_left": 0.0,
            "stair_path": spec.get("stair_path", []),
            "stair_index": 1,
            "stair_direction": 1,
            "left_arm": actor.get_node("LeftArmPivot"),
            "right_arm": actor.get_node("RightArmPivot"),
            "left_leg": actor.get_node("LeftLegPivot"),
            "right_leg": actor.get_node("RightLegPivot")
        })
    indoor_count = actors.size()

func _process(delta: float) -> void:
    var active: String = life.active_interior if life.interior_active else ""
    var now: float = float(Time.get_ticks_msec()) * 0.001
    for actor in actors:
        var node: Node3D = actor["node"]
        var in_room: bool = str(actor["room"]) == active
        node.visible = in_room
        if not in_room:
            continue
        actor["talk_left"] = maxf(0.0, float(actor["talk_left"]) - delta)
        var routine: String = str(actor["routine"])
        var phase: float = now + float(actor["phase"])
        var left_arm: Node3D = actor["left_arm"]
        var right_arm: Node3D = actor["right_arm"]
        var left_leg: Node3D = actor["left_leg"]
        var right_leg: Node3D = actor["right_leg"]
        var origin: Vector3 = actor["origin"]
        if float(actor["talk_left"]) > 0.0:
            if routine != "stairs":
                node.position = node.position.lerp(origin, clampf(delta * 3.0, 0.0, 1.0))
            var direction: Vector3 = player.global_position - node.global_position
            direction.y = 0.0
            if direction.length_squared() > 0.02:
                node.look_at(node.global_position + direction, Vector3.UP)
            left_arm.rotation.x = -0.4 + sin(phase * 3.0) * 0.15
            right_arm.rotation.x = -0.35
            left_leg.rotation.x = 0.0
            right_leg.rotation.x = 0.0
        elif routine == "read":
            node.position = origin + Vector3(0.0, sin(phase * 1.5) * 0.015, 0.0)
            node.rotation.y = float(actor["heading"])
            left_arm.rotation.x = -0.9 + sin(phase * 1.4) * 0.06
            right_arm.rotation.x = -0.9 - sin(phase * 1.4) * 0.06
            left_leg.rotation.x = -0.9
            right_leg.rotation.x = -0.85
        elif routine == "serve":
            node.position = origin
            node.rotation.y = float(actor["heading"])
            left_arm.rotation.x = -0.85 + sin(phase * 2.0) * 0.24
            right_arm.rotation.x = -0.6
            left_leg.rotation.x = 0.0
            right_leg.rotation.x = 0.0
        elif routine == "stairs":
            _advance_stair(actor, delta, phase)
        elif routine == "exercise":
            node.position = origin + Vector3(0.0, absf(sin(phase * 2.1)) * 0.05, 0.0)
            node.rotation.y = float(actor["heading"])
            left_arm.rotation.z = -0.35 - sin(phase * 2.0) * 0.65
            right_arm.rotation.z = 0.35 + sin(phase * 2.0) * 0.65
            left_leg.rotation.x = sin(phase * 2.0) * 0.25
            right_leg.rotation.x = -sin(phase * 2.0) * 0.25
        else:
            # Short two-metre patrol within a room bay; does not cross the central aisle.
            var move: float = sin(phase * 0.55) * 0.8
            node.position = origin + Vector3(move, absf(sin(phase * 4.0)) * 0.025, 0.0)
            node.rotation.y = float(actor["heading"]) + (0.18 if cos(phase * 0.55) > 0.0 else -0.18)
            var stride: float = sin(phase * 4.0) * 0.35
            left_arm.rotation.x = stride
            right_arm.rotation.x = -stride
            left_leg.rotation.x = -stride
            right_leg.rotation.x = stride


func _advance_stair(actor: Dictionary, delta: float, phase: float) -> void:
    var path: Array = actor.get("stair_path", [])
    if path.size() < 2:
        return
    var node: Node3D = actor["node"]
    var index: int = clampi(int(actor.get("stair_index", 1)), 0, path.size() - 1)
    var target: Vector3 = path[index]
    var offset: Vector3 = target - node.position
    if offset.length() < 0.16:
        var direction: int = int(actor.get("stair_direction", 1))
        var next_index: int = index + direction
        if next_index >= path.size():
            direction = -1
            next_index = path.size() - 2
        elif next_index < 0:
            direction = 1
            next_index = 1
        actor["stair_direction"] = direction
        actor["stair_index"] = next_index
        target = path[next_index]
        offset = target - node.position
    if offset.length_squared() > 0.0001:
        var movement: Vector3 = offset.normalized() * minf(1.2 * delta, offset.length())
        node.position += movement
        var horizontal: Vector3 = Vector3(movement.x, 0.0, movement.z)
        if horizontal.length_squared() > 0.0001:
            node.look_at(node.global_position + horizontal, Vector3.UP)
    var stride: float = sin(phase * 7.0) * 0.42
    (actor["left_arm"] as Node3D).rotation.x = stride * 0.75
    (actor["right_arm"] as Node3D).rotation.x = -stride * 0.75
    (actor["left_leg"] as Node3D).rotation.x = -stride
    (actor["right_leg"] as Node3D).rotation.x = stride


func nearby_name() -> String:
    var found: Dictionary = _nearest_active()
    return str(found["name"]) if not found.is_empty() else ""

func _nearest_active() -> Dictionary:
    if not life.interior_active:
        return {}
    var result: Dictionary = {}
    var nearest: float = TALK_RADIUS
    for actor in actors:
        if str(actor["room"]) != life.active_interior:
            continue
        var npc: Node3D = actor["node"]
        var distance: float = player.global_position.distance_to(npc.global_position)
        if distance < nearest:
            result = actor
            nearest = distance
    return result

func talk_to_nearest() -> bool:
    var actor: Dictionary = _nearest_active()
    if actor.is_empty():
        life.message = "Move closer to an indoor character before pressing Q."
        life.message_time = 2.5
        return false
    actor["talk_left"] = 5.0
    last_spoken = str(actor["name"])
    var coursework: UTownCoursework = get_parent().get_node_or_null("Coursework") as UTownCoursework
    if coursework != null:
        coursework.notify_dialogue(str(actor["id"]))
    var speaker: String = str(actor["name"])
    var bank: NUS3DDialogueBank = get_node_or_null("/root/DialogueBank") as NUS3DDialogueBank
    var role: String = bank.role_for("indoor", speaker) if bank != null else str(actor["role"])
    var line: String = bank.next_line("indoor", speaker, 0) if bank != null else str(actor["dialogue"])
    life.message = "%s / %s\n%s" % [speaker, role, line]
    life.message_time = 5.0
    return true

func active_count() -> int:
    var count: int = 0
    for actor in actors:
        if str(actor["room"]) == life.active_interior and life.interior_active:
            count += 1
    return count
