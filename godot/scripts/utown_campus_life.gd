extends Node
class_name UTownCampusLife
## Offline campus-life prototype: fictional pedestrians, illustrative interiors,
## bicycle mode and a looping shuttle. Positions reuse schematic project data only.

var npc_names: PackedStringArray = PackedStringArray(["Maya", "Ethan", "Aisha", "Lucas", "Mei", "Daniel"])
var npc_lines: PackedStringArray = PackedStringArray([
    "I like taking a short break around Town Green.",
    "This little campus model is useful for exploring the ERC facade study.",
    "I am heading toward the next shuttle stop. The route is only a game-world proxy.",
    "The SRC interior is an original recreation-space concept, not a measured floor plan.",
    "Try bicycle mode if you want to cover the map faster.",
    "The weather presets are artistic effects, not a live Singapore forecast."
])
var npc_colors: PackedStringArray = PackedStringArray(["#d77f69", "#6d93bf", "#9b83bd", "#6eaa91", "#d4a65f", "#8a9da7"])
const TALK_RADIUS: float = 5.5
const ENTRY_RADIUS: float = 18.0
const BOARD_RADIUS: float = 7.0
const SHUTTLE_SPEED: float = 5.2

@onready var world: UTownWorld = $"../World"
@onready var player: UTownPlayer = $"../Player"
@onready var weather: UTownWeather = $"../Weather"

var pedestrians: Array[Dictionary] = []
var bicycle_wheels: Array[MeshInstance3D] = []
var bicycle_handlebar: Node3D
var bicycle_crank: Node3D
var shuttle_wheels: Array[MeshInstance3D] = []
var shuttle_passengers: Array[Node3D] = []
var shuttle_stop_names: PackedStringArray = PackedStringArray(["Town Green", "ERC", "SRC", "Town Plaza"])
var entry_positions: Dictionary = {}
var interiors: Dictionary = {}
var interior_anchors: Dictionary = {"ERC": Vector3(900.0, 0.0, 0.0), "SRC": Vector3(940.0, 0.0, 0.0)}
var interior_active: bool = false
var interior_floor: int = 0
var active_interior: String = ""
var return_position: Vector3 = Vector3.ZERO
var return_rotation: Vector3 = Vector3.ZERO
var return_head_rotation: Vector3 = Vector3.ZERO

var bicycle: Node3D
var bicycle_enabled: bool = false
var shuttle: Node3D
var shuttle_roof: MeshInstance3D
var shuttle_route: Array[Vector3] = []
var shuttle_segment: int = 0
var shuttle_dwell: float = 1.0
var on_shuttle: bool = false

var message: String = ""
var message_time: float = 0.0

func _ready() -> void:
    _load_waypoints()
    _build_pedestrians()
    _build_interiors()
    _build_bicycle()
    _build_shuttle()

func _load_waypoints() -> void:
    for raw in world.layout.get("loop", []):
        var item: Dictionary = raw
        var id: String = str(item.get("id", ""))
        var point: Vector3 = world.lonlat_to_world(float(item.get("lon", world.origin_lon)), float(item.get("lat", world.origin_lat)))
        entry_positions[id] = point
        if id in ["GREEN", "ERC", "SRC", "PLAZA"]:
            shuttle_route.append(point)

func _route_length(route: Array[Vector3]) -> float:
    var total: float = 0.0
    for i in range(route.size() - 1):
        total += route[i].distance_to(route[i + 1])
    return total

func _sample_route(route: Array[Vector3], distance: float) -> Dictionary:
    if route.size() < 2:
        return {"position": Vector3.ZERO, "direction": Vector3.FORWARD}
    var remaining: float = clampf(distance, 0.0, _route_length(route))
    for i in range(route.size() - 1):
        var segment: Vector3 = route[i + 1] - route[i]
        var length: float = segment.length()
        if length > 0.001:
            if remaining <= length:
                return {"position": route[i].lerp(route[i + 1], remaining / length), "direction": segment.normalized()}
            remaining -= length
    return {"position": route[route.size() - 1], "direction": (route[-1] - route[-2]).normalized()}

func _build_pedestrians() -> void:
    var walkways: Array = world.layout.get("walkways", [])
    for i in range(npc_names.size()):
        var path: Dictionary = walkways[i % walkways.size()]
        var route: Array[Vector3] = []
        for coords in path.get("lonlat", []):
            route.append(world.lonlat_to_world(float(coords[0]), float(coords[1])))
        if route.size() < 2:
            continue
        var total: float = _route_length(route)
        var distance: float = total * float((i % 3) + 1) / 4.0
        var npc: Node3D = _make_person(i)
        npc.position = _sample_route(route, distance)["position"]
        add_child(npc)
        pedestrians.append({
            "node": npc, "route": route, "distance": distance,
            "direction": 1.0 if i % 2 == 0 else -1.0,
            "speed": 0.72 + float(i % 3) * 0.16, "phase": float(i) * 1.13,
            "idle_remaining": 0.0, "talk_remaining": 0.0,
            "left_arm": npc.get_node("LeftArmPivot"), "right_arm": npc.get_node("RightArmPivot"),
            "left_leg": npc.get_node("LeftLegPivot"), "right_leg": npc.get_node("RightLegPivot"),
            "name": npc_names[i], "line": npc_lines[i]
        })

func _make_person(index: int) -> Node3D:
    var root := Node3D.new()
    root.name = "StudentNPC_%02d" % index
    var shirt := StandardMaterial3D.new()
    shirt.albedo_color = Color.html(str(npc_colors[index]))
    var skin := StandardMaterial3D.new()
    skin.albedo_color = Color.html("#d9ad8d")
    var trousers := StandardMaterial3D.new()
    trousers.albedo_color = Color.html("#354353")

    var torso := MeshInstance3D.new()
    var torso_mesh := CapsuleMesh.new()
    torso_mesh.radius = 0.27
    torso_mesh.height = 1.08
    torso.mesh = torso_mesh
    torso.position.y = 0.98
    torso.material_override = shirt
    root.add_child(torso)

    var head_mesh := MeshInstance3D.new()
    var head_sphere := SphereMesh.new()
    head_sphere.radius = 0.22
    head_mesh.mesh = head_sphere
    head_mesh.position.y = 1.72
    head_mesh.material_override = skin
    root.add_child(head_mesh)

    for side in [-1.0, 1.0]:
        var suffix: String = "Left" if side < 0.0 else "Right"
        var leg_pivot := Node3D.new()
        leg_pivot.name = suffix + "LegPivot"
        leg_pivot.position = Vector3(side * 0.14, 0.68, 0.0)
        root.add_child(leg_pivot)
        var leg := MeshInstance3D.new()
        var leg_mesh := CapsuleMesh.new()
        leg_mesh.radius = 0.12
        leg_mesh.height = 0.72
        leg.mesh = leg_mesh
        leg.position.y = -0.31
        leg.material_override = trousers
        leg_pivot.add_child(leg)

        var arm_pivot := Node3D.new()
        arm_pivot.name = suffix + "ArmPivot"
        arm_pivot.position = Vector3(side * 0.34, 1.29, 0.0)
        root.add_child(arm_pivot)
        var arm := MeshInstance3D.new()
        var arm_mesh := CapsuleMesh.new()
        arm_mesh.radius = 0.095
        arm_mesh.height = 0.7
        arm.mesh = arm_mesh
        arm.position.y = -0.31
        arm.material_override = skin
        arm_pivot.add_child(arm)
    return root

func _mat(hex: String, alpha: float = 1.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.html(hex)
    if alpha < 1.0:
        material.albedo_color.a = alpha
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.roughness = 0.84
    return material

func _box(parent: Node3D, name: String, at: Vector3, size: Vector3, material: Material, solid: bool = false) -> MeshInstance3D:
    var part := Node3D.new()
    part.name = name
    part.position = at
    parent.add_child(part)
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.material_override = material
    part.add_child(mesh)
    if solid:
        var body := StaticBody3D.new()
        part.add_child(body)
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        body.add_child(collision)
    return mesh

func _build_interiors() -> void:
    for id in ["ERC", "SRC"]:
        var room := Node3D.new()
        room.name = id + "_IllustrativeInterior"
        room.position = interior_anchors[id]
        add_child(room)
        _build_room_shell(room, id)
        _build_mezzanine(room, id)
        if id == "ERC":
            _build_study_room(room)
        else:
            _build_recreation_room(room)
        interiors[id] = room

func _build_room_shell(room: Node3D, id: String) -> void:
    var wall := _mat("#d9dedb" if id == "ERC" else "#c5cbc9")
    var floor := _mat("#a9b4b0" if id == "ERC" else "#747f82")
    var glass := _mat("#7da6b6", 0.34)
    var trim := _mat("#506d78")
    _box(room, "Floor", Vector3(0, -0.15, 0), Vector3(24, 0.3, 18), floor, true)
    _box(room, "WestWall", Vector3(-12, 3.25, 0), Vector3(0.3, 6.5, 18), wall, true)
    _box(room, "EastWall", Vector3(12, 3.25, 0), Vector3(0.3, 6.5, 18), wall, true)
    _box(room, "NorthWall", Vector3(0, 3.25, -9), Vector3(24, 6.5, 0.3), wall, true)
    _box(room, "EntryWest", Vector3(-8.25, 3.25, 9), Vector3(7.5, 6.5, 0.3), wall, true)
    _box(room, "EntryEast", Vector3(8.25, 3.25, 9), Vector3(7.5, 6.5, 0.3), wall, true)
    _box(room, "WindowBand", Vector3(0, 4.4, -8.78), Vector3(15, 2.0, 0.08), glass)
    for x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
        _box(room, "CeilingBeam", Vector3(x, 6.38, 0), Vector3(0.16, 0.22, 17.5), trim)
    var title := Label3D.new()
    title.text = "ERC / STUDY LOUNGE CONCEPT" if id == "ERC" else "SRC / RECREATION ATRIUM CONCEPT"
    title.font_size = 30
    title.pixel_size = 0.018
    title.modulate = Color.html("#f5f3e9")
    title.outline_size = 5
    title.position = Vector3(0, 5.55, -8.55)
    room.add_child(title)
    var light := OmniLight3D.new()
    light.position = Vector3(0, 5.2, 0)
    light.light_color = Color("#ffe2b5")
    light.light_energy = 1.35
    light.omni_range = 28
    light.shadow_enabled = false
    room.add_child(light)
    var lower_light := OmniLight3D.new()
    lower_light.position = Vector3(0, 2.6, 0)
    lower_light.light_color = Color("#e6f0ef")
    lower_light.light_energy = 0.65
    lower_light.omni_range = 24
    lower_light.shadow_enabled = false
    room.add_child(lower_light)
    var exit_label := Label3D.new()
    exit_label.text = "EXIT / PRESS I"
    exit_label.font_size = 24
    exit_label.pixel_size = 0.016
    exit_label.modulate = Color.html("#f1d18a")
    exit_label.position = Vector3(0, 2.7, 8.55)
    room.add_child(exit_label)

func _build_mezzanine(room: Node3D, id: String) -> void:
    var deck := _mat("#aeb9b4" if id == "ERC" else "#858f91")
    var rail := _mat("#82aab1", 0.5)
    var metal := _mat("#465b63")
    _box(room, "UpperMezzanineFloor", Vector3(0, 3.25, -6.5), Vector3(23.4, 0.3, 5.0), deck, true)
    _box(room, "MezzanineFrontRail", Vector3(0, 4.05, -4.0), Vector3(22.8, 0.12, 0.12), rail)
    for x in [-11.2, 11.2]:
        _box(room, "MezzanineSideRail", Vector3(x, 4.05, -6.5), Vector3(0.12, 0.12, 5.0), rail)
    for x in [-10.5, -7.0, -3.5, 0.0, 3.5, 7.0, 10.5]:
        _box(room, "BalconyPost", Vector3(x, 3.95, -4.0), Vector3(0.08, 0.9, 0.08), metal)
    # A clearly visible staircase study links the lower floor to the upper deck.
    for step in range(16):
        var rise: float = float(step + 1) * 0.205
        var z: float = 3.5 - float(step) * 0.49
        _box(room, "StairStep_%02d" % step, Vector3(9.25, rise, z), Vector3(1.8, 0.22, 0.5), deck, true)
    _box(room, "LiftCallPanel", Vector3(-9.2, 1.55, -6.45), Vector3(0.16, 1.0, 0.5), metal)
    var lift_label := Label3D.new()
    lift_label.text = "LIFT / PRESS L"
    lift_label.font_size = 20
    lift_label.pixel_size = 0.013
    lift_label.modulate = Color.html("#f3d58e")
    lift_label.outline_size = 4
    lift_label.position = Vector3(-8.8, 2.35, -5.8)
    room.add_child(lift_label)

func _build_study_room(room: Node3D) -> void:
    var table := _mat("#8b6f55")
    var dark := _mat("#46545a")
    var seat := _mat("#6e8f91")
    for x in [-5.0, 0.0, 5.0]:
        for z in [-3.5, 1.0]:
            _box(room, "StudyTable", Vector3(x, 0.92, z), Vector3(3, 0.16, 1.25), table)
            for side in [-1.0, 1.0]:
                _box(room, "TableLeg", Vector3(x + side * 1.25, 0.44, z), Vector3(0.12, 0.92, 0.12), dark)
                _box(room, "StudySeat", Vector3(x + side * 1.85, 0.55, z), Vector3(0.78, 0.12, 0.72), seat)
    for z in [-5.5, -2.0, 1.5, 5.0]:
        _box(room, "Bookcase", Vector3(-10.4, 1.35, z), Vector3(1.2, 2.7, 2.6), dark)
        for shelf in [0.55, 1.25, 1.95]:
            _box(room, "BookShelf", Vector3(-9.75, shelf, z), Vector3(0.12, 0.08, 2.45), table)
    _box(room, "NoticeBoard", Vector3(0, 1.8, -8.55), Vector3(5.5, 1.8, 0.12), dark)
    for x in [-5.0, 0.0, 5.0]:
        _box(room, "UpperStudyDesk", Vector3(x, 3.95, -6.5), Vector3(2.7, 0.14, 1.0), table)
        _box(room, "UpperStudySeat", Vector3(x, 3.68, -5.7), Vector3(0.7, 0.12, 0.65), seat)
    _box(room, "UpperQuietBooth", Vector3(9.5, 4.0, -6.5), Vector3(1.4, 0.9, 2.6), dark)

func _build_recreation_room(room: Node3D) -> void:
    var dark := _mat("#4e6269")
    var accent := _mat("#c49b61")
    var stripe := _mat("#d5d9d1")
    _box(room, "CourtStripe", Vector3(0, 0.02, 0), Vector3(0.12, 0.03, 15), stripe)
    _box(room, "CourtLine", Vector3(0, 0.025, 0), Vector3(19, 0.03, 0.12), stripe)
    for x in [-8.0, -4.0, 4.0, 8.0]:
        for z in [-4.0, 4.0]:
            _box(room, "Bench", Vector3(x, 0.55, z), Vector3(2.8, 0.18, 0.72), accent)
            _box(room, "BenchBase", Vector3(x, 0.27, z), Vector3(0.22, 0.55, 0.22), dark)
    _box(room, "DisplayPanel", Vector3(0, 2.2, -8.5), Vector3(6.5, 2.0, 0.16), dark)
    _box(room, "DisplayAccent", Vector3(0, 2.2, -8.38), Vector3(4.6, 0.16, 0.08), accent)
    for x in [-8.0, -4.0, 4.0, 8.0]:
        _box(room, "UpperViewingBench", Vector3(x, 3.78, -6.5), Vector3(2.6, 0.16, 0.7), accent)
    _box(room, "UpperDisplayConsole", Vector3(0, 3.95, -8.0), Vector3(4.5, 0.18, 0.8), dark)

func _add_rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
    var direction: Vector3 = b - a
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = direction.length()
    mesh.radial_segments = 8
    var rod := MeshInstance3D.new()
    rod.mesh = mesh
    rod.position = (a + b) * 0.5
    rod.quaternion = Quaternion(Vector3.UP, direction.normalized())
    rod.material_override = material
    parent.add_child(rod)

func _build_bicycle() -> void:
    bicycle = Node3D.new()
    bicycle.name = "FirstPersonBicycle"
    bicycle.position = Vector3(0, -0.05, -1.0)
    bicycle.visible = false
    player.add_child(bicycle)
    var rubber := _mat("#252d31")
    var frame := _mat("#d18b42")
    var metal := _mat("#b9c3c4")
    bicycle_wheels.clear()
    for z in [0.0, -1.6]:
        var wheel := MeshInstance3D.new()
        var torus := TorusMesh.new()
        torus.inner_radius = 0.29
        torus.outer_radius = 0.36
        wheel.mesh = torus
        wheel.rotation.y = PI * 0.5
        wheel.position = Vector3(0, 0.45, z)
        wheel.material_override = rubber
        bicycle.add_child(wheel)
        bicycle_wheels.append(wheel)
    var rear := Vector3(0, 0.45, 0)
    var front := Vector3(0, 0.45, -1.6)
    var seat := Vector3(0, 1.0, -0.52)
    var head := Vector3(0, 0.92, -1.25)
    var crank := Vector3(0, 0.55, -0.78)
    _add_rod(bicycle, rear, seat, 0.055, frame)
    _add_rod(bicycle, seat, crank, 0.055, frame)
    _add_rod(bicycle, crank, rear, 0.055, frame)
    _add_rod(bicycle, seat, head, 0.055, frame)
    _add_rod(bicycle, head, crank, 0.055, frame)
    _add_rod(bicycle, head, front, 0.055, frame)
    _add_rod(bicycle, seat, Vector3(0, 1.18, -0.48), 0.07, metal)
    _box(bicycle, "Seat", Vector3(0, 1.23, -0.5), Vector3(0.52, 0.12, 0.22), rubber)

    bicycle_handlebar = Node3D.new()
    bicycle_handlebar.name = "SteeringHandlebar"
    bicycle_handlebar.position = Vector3(0, 1.0, -1.28)
    bicycle.add_child(bicycle_handlebar)
    _add_rod(bicycle_handlebar, Vector3(-0.48, 0.0, 0.0), Vector3(0.48, 0.0, 0.0), 0.045, metal)
    _box(bicycle_handlebar, "LeftGrip", Vector3(-0.5, 0.0, 0.0), Vector3(0.22, 0.08, 0.08), rubber)
    _box(bicycle_handlebar, "RightGrip", Vector3(0.5, 0.0, 0.0), Vector3(0.22, 0.08, 0.08), rubber)

    bicycle_crank = Node3D.new()
    bicycle_crank.name = "PedalCrank"
    bicycle_crank.position = crank
    bicycle.add_child(bicycle_crank)
    _add_rod(bicycle_crank, Vector3(-0.36, 0.0, 0.0), Vector3(0.36, 0.0, 0.0), 0.045, metal)
    _add_rod(bicycle_crank, Vector3(-0.36, 0.0, 0.0), Vector3(-0.58, -0.05, 0.0), 0.04, frame)
    _add_rod(bicycle_crank, Vector3(0.36, 0.0, 0.0), Vector3(0.58, 0.05, 0.0), 0.04, frame)

func set_bicycle(value: bool) -> bool:
    if value and (interior_active or on_shuttle):
        return false
    bicycle_enabled = value
    bicycle.visible = value
    player.set_bicycle_mode(value)
    message = "Bicycle mode %s. Speed is increased." % ("ON" if value else "OFF")
    message_time = 2.5
    return true

func toggle_bicycle() -> void:
    set_bicycle(not bicycle_enabled)

func _build_shuttle() -> void:
    if shuttle_route.size() < 4:
        push_error("Campus shuttle requires the four existing conceptual waypoints")
        return
    shuttle = Node3D.new()
    shuttle.name = "UTownShuttle_Illustrative"
    shuttle.position = shuttle_route[0] + Vector3(0, 0.12, 0)
    add_child(shuttle)
    var body := _mat("#356b67")
    var dark := _mat("#263b43")
    var glass := _mat("#9ec5d1", 0.42)
    _box(shuttle, "BusBody", Vector3(0, 0.38, 0), Vector3(2.25, 0.52, 5.2), body)
    _box(shuttle, "LowerLeftPanel", Vector3(-1.13, 0.48, 0), Vector3(0.08, 0.48, 5.0), body)
    _box(shuttle, "LowerRightPanel", Vector3(1.13, 0.48, 0), Vector3(0.08, 0.48, 5.0), body)
    shuttle_roof = _box(shuttle, "BusRoof", Vector3(0, 1.76, 0), Vector3(2.2, 0.16, 5.0), dark)
    _box(shuttle, "LeftWindows", Vector3(-1.14, 1.15, 0), Vector3(0.06, 0.92, 4.3), glass)
    _box(shuttle, "RightWindows", Vector3(1.14, 1.15, 0), Vector3(0.06, 0.92, 4.3), glass)
    _box(shuttle, "FrontWindow", Vector3(0, 1.2, -2.62), Vector3(1.85, 0.9, 0.06), glass)
    _box(shuttle, "RearWindow", Vector3(0, 1.2, 2.62), Vector3(1.85, 0.9, 0.06), glass)
    shuttle_wheels.clear()
    for side in [-1.0, 1.0]:
        for z in [-1.75, 1.75]:
            var wheel := MeshInstance3D.new()
            var torus := TorusMesh.new()
            torus.inner_radius = 0.25
            torus.outer_radius = 0.34
            wheel.mesh = torus
            wheel.rotation.y = PI * 0.5
            wheel.position = Vector3(side * 1.12, 0.38, z)
            wheel.material_override = dark
            shuttle.add_child(wheel)
            shuttle_wheels.append(wheel)
    # Seats and fictional seated passengers are visible through the side windows.
    for passenger_index in range(3):
        var z: float = -1.35 + float(passenger_index) * 1.3
        _box(shuttle, "PassengerSeat_%d" % passenger_index, Vector3(0.45, 0.7, z), Vector3(0.72, 0.14, 0.62), dark)
        var passenger := Node3D.new()
        passenger.name = "Passenger_%d" % passenger_index
        passenger.position = Vector3(0.42, 0.76, z)
        var torso := MeshInstance3D.new()
        var torso_mesh := CapsuleMesh.new()
        torso_mesh.radius = 0.16
        torso_mesh.height = 0.62
        torso.mesh = torso_mesh
        torso.position.y = 0.28
        var passenger_material := _mat(["#d28c70", "#7d9eb4", "#c4a16b"][passenger_index])
        torso.material_override = passenger_material
        passenger.add_child(torso)
        var head_mesh := MeshInstance3D.new()
        var head_sphere := SphereMesh.new()
        head_sphere.radius = 0.14
        head_mesh.mesh = head_sphere
        head_mesh.position.y = 0.72
        head_mesh.material_override = _mat("#d9ad8d")
        passenger.add_child(head_mesh)
        shuttle.add_child(passenger)
        shuttle_passengers.append(passenger)
    var label := Label3D.new()
    label.text = "UTOWN SHUTTLE"
    label.font_size = 26
    label.pixel_size = 0.014
    label.modulate = Color.html("#f4f1e5")
    label.outline_size = 5
    label.position = Vector3(0, 2.2, 0)
    shuttle.add_child(label)
    var route_sign := Label3D.new()
    route_sign.text = "UTOWN LOOP"
    route_sign.font_size = 18
    route_sign.pixel_size = 0.012
    route_sign.modulate = Color.html("#fff0bf")
    route_sign.outline_size = 4
    route_sign.position = Vector3(0, 1.95, -2.68)
    shuttle.add_child(route_sign)
    shuttle.look_at(shuttle_route[1] + Vector3(0, 0.12, 0), Vector3.UP)
    for i in range(shuttle_route.size()):
        var stop := Node3D.new()
        stop.name = "ShuttleStop_%d" % i
        stop.position = shuttle_route[i] + Vector3(5, 0, 0)
        add_child(stop)
        var pole := MeshInstance3D.new()
        var pole_mesh := CylinderMesh.new()
        pole_mesh.top_radius = 0.045
        pole_mesh.bottom_radius = 0.055
        pole_mesh.height = 2.2
        pole.mesh = pole_mesh
        pole.position.y = 1.1
        pole.material_override = dark
        stop.add_child(pole)
        var sign := MeshInstance3D.new()
        var sign_mesh := BoxMesh.new()
        sign_mesh.size = Vector3(0.85, 0.55, 0.1)
        sign.mesh = sign_mesh
        sign.position.y = 2.25
        sign.material_override = body
        stop.add_child(sign)
        var stop_label := Label3D.new()
        stop_label.text = shuttle_stop_names[i]
        stop_label.font_size = 18
        stop_label.pixel_size = 0.012
        stop_label.position.y = 2.75
        stop.add_child(stop_label)
        var stop_number := Label3D.new()
        stop_number.text = "STOP %d" % (i + 1)
        stop_number.font_size = 14
        stop_number.pixel_size = 0.01
        stop_number.modulate = Color.html("#e7f1ed")
        stop_number.position = Vector3(0.0, 3.15, 0.0)
        stop.add_child(stop_number)

func _process(delta: float) -> void:
    message_time = maxf(0.0, message_time - delta)
    var now: float = float(Time.get_ticks_msec()) / 1000.0
    for state in pedestrians:
        var route: Array[Vector3] = state["route"]
        var total: float = _route_length(route)
        var talk_remaining: float = maxf(0.0, float(state["talk_remaining"]) - delta)
        state["talk_remaining"] = talk_remaining
        var idle_remaining: float = maxf(0.0, float(state["idle_remaining"]) - delta)
        if talk_remaining <= 0.0 and idle_remaining <= 0.0:
            var next_distance: float = float(state["distance"]) + float(state["direction"]) * float(state["speed"]) * delta
            if next_distance >= total:
                next_distance = total
                state["direction"] = -1.0
                state["idle_remaining"] = randf_range(0.7, 1.7)
            elif next_distance <= 0.0:
                next_distance = 0.0
                state["direction"] = 1.0
                state["idle_remaining"] = randf_range(0.7, 1.7)
            state["distance"] = next_distance
        var sample: Dictionary = _sample_route(route, float(state["distance"]))
        var npc: Node3D = state["node"]
        var walking: bool = talk_remaining <= 0.0 and idle_remaining <= 0.0
        var gait: float = sin(now * 6.2 + float(state["phase"])) if walking else sin(now * 1.8 + float(state["phase"])) * 0.08
        var bob: float = absf(sin(now * 6.2 + float(state["phase"]))) * 0.035 if walking else sin(now * 1.8 + float(state["phase"])) * 0.012
        npc.position = sample["position"] + Vector3(0.0, bob, 0.0)
        if talk_remaining > 0.0:
            var to_player: Vector3 = player.global_position - npc.global_position
            to_player.y = 0.0
            if to_player.length() > 0.05:
                npc.look_at(npc.global_position + to_player, Vector3.UP)
        else:
            var facing: Vector3 = sample["direction"] * float(state["direction"])
            if facing.length() > 0.01:
                npc.look_at(npc.global_position + facing, Vector3.UP)
        var left_arm: Node3D = state["left_arm"]
        var right_arm: Node3D = state["right_arm"]
        var left_leg: Node3D = state["left_leg"]
        var right_leg: Node3D = state["right_leg"]
        left_arm.rotation.x = gait * 0.48
        right_arm.rotation.x = -gait * 0.48
        left_leg.rotation.x = -gait * 0.62
        right_leg.rotation.x = gait * 0.62

    if bicycle_enabled:
        var bike_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
        var wheel_turn: float = bike_speed * delta / 0.36
        for wheel in bicycle_wheels:
            wheel.rotation.x += wheel_turn
        if bicycle_crank != null:
            bicycle_crank.rotation.x += wheel_turn * 0.55
        if bicycle_handlebar != null:
            var steer: float = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
            bicycle_handlebar.rotation.y = lerpf(bicycle_handlebar.rotation.y, steer * 0.28, clampf(delta * 8.0, 0.0, 1.0))

    if shuttle != null and not shuttle_route.is_empty():
        var moved_distance: float = 0.0
        if shuttle_dwell > 0.0:
            shuttle_dwell = maxf(0.0, shuttle_dwell - delta)
        else:
            var target_index: int = (shuttle_segment + 1) % shuttle_route.size()
            var target: Vector3 = shuttle_route[target_index] + Vector3(0, 0.12, 0)
            var diff: Vector3 = target - shuttle.global_position
            diff.y = 0.0
            var distance_to_stop: float = diff.length()
            if distance_to_stop <= SHUTTLE_SPEED * delta:
                moved_distance = distance_to_stop
                shuttle.global_position = target
                shuttle_segment = target_index
                shuttle_dwell = 3.0
            elif distance_to_stop > 0.001:
                var direction: Vector3 = diff.normalized()
                moved_distance = SHUTTLE_SPEED * delta
                shuttle.global_position += direction * moved_distance
                shuttle.look_at(shuttle.global_position + direction, Vector3.UP)
        for wheel in shuttle_wheels:
            wheel.rotation.x += moved_distance / 0.34
        if on_shuttle:
            player.global_position = shuttle.global_position + Vector3(0, 0.18, 0)
            player.rotation.y = shuttle.rotation.y

func _nearest_pedestrian() -> int:
    var best: int = -1
    var best_distance: float = TALK_RADIUS
    for i in range(pedestrians.size()):
        var npc: Node3D = pedestrians[i]["node"]
        var d: float = Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(npc.global_position.x, npc.global_position.z))
        if d <= best_distance:
            best = i
            best_distance = d
    return best

func talk_to_nearest() -> bool:
    var index: int = _nearest_pedestrian()
    if index < 0:
        message = "No campus character is close enough to talk."
        message_time = 2.5
        return false
    pedestrians[index]["talk_remaining"] = 6.0
    message = "%s  |  %s" % [str(pedestrians[index]["name"]), str(pedestrians[index]["line"])]
    message_time = 6.0
    return true

func enter_interior(id: String) -> bool:
    if interior_active or on_shuttle or not interior_anchors.has(id):
        return false
    return_position = player.global_position
    return_rotation = player.rotation
    return_head_rotation = player.head.rotation
    if bicycle_enabled:
        set_bicycle(false)
    active_interior = id
    interior_floor = 0
    interior_active = true
    player.velocity = Vector3.ZERO
    player.global_position = interior_anchors[id] + Vector3(0, 0.18, 6)
    player.rotation = Vector3.ZERO
    player.head.rotation = Vector3.ZERO
    weather.set_indoor(true)
    message = "Entered %s illustrative interior. Press I to return." % id
    message_time = 4.0
    return true

func toggle_interior_floor() -> bool:
    if not interior_active:
        return false
    interior_floor = 1 - interior_floor
    var floor_position: Vector3 = Vector3(0.0, 0.18, 6.0) if interior_floor == 0 else Vector3(0.0, 3.58, -6.5)
    player.global_position = interior_anchors[active_interior] + floor_position
    player.rotation.y = 0.0 if interior_floor == 0 else PI
    player.head.rotation = Vector3( -0.2, 0.0, 0.0) if interior_floor == 1 else Vector3.ZERO
    player.velocity = Vector3.ZERO
    message = "%s  |  %s floor" % [active_interior, "GROUND" if interior_floor == 0 else "MEZZANINE"]
    message_time = 3.5
    return true

func exit_interior() -> void:
    if not interior_active:
        return
    player.global_position = return_position
    player.rotation = return_rotation
    player.head.rotation = return_head_rotation
    player.velocity = Vector3.ZERO
    active_interior = ""
    interior_floor = 0
    interior_active = false
    weather.set_indoor(false)
    message = "Returned to the schematic outdoor scene."
    message_time = 3.0

func enter_nearest_interior() -> bool:
    if interior_active:
        exit_interior()
        return true
    var best_id: String = ""
    var best_distance: float = ENTRY_RADIUS
    for id in ["ERC", "SRC"]:
        if not entry_positions.has(id):
            continue
        var point: Vector3 = entry_positions[id]
        var d: float = Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(point.x, point.z))
        if d <= best_distance:
            best_id = id
            best_distance = d
    if best_id.is_empty():
        message = "Approach the ERC or SRC study entrance, then press I."
        message_time = 3.0
        return false
    return enter_interior(best_id)

func board_or_alight() -> bool:
    if on_shuttle:
        alight_shuttle()
        return true
    if interior_active or bicycle_enabled or shuttle == null:
        return false
    var d: float = Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(shuttle.global_position.x, shuttle.global_position.z))
    if d > BOARD_RADIUS:
        message = "Approach the moving UTown shuttle and press X to board."
        message_time = 3.0
        return false
    on_shuttle = true
    player.movement_locked = true
    player.head.position.y = 1.25
    shuttle_roof.visible = false
    player.global_position = shuttle.global_position + Vector3(0, 0.18, 0)
    player.rotation.y = shuttle.rotation.y
    message = "On board. Press X to alight."
    message_time = 3.5
    return true

func alight_shuttle() -> void:
    if not on_shuttle:
        return
    var side: Vector3 = shuttle.global_transform.basis.x * 3.2
    player.global_position = shuttle.global_position + side + Vector3(0, 0.18, 0)
    player.rotation.y = shuttle.rotation.y
    player.head.position.y = 1.66
    player.movement_locked = false
    shuttle_roof.visible = true
    on_shuttle = false
    message = "You have left the shuttle."
    message_time = 2.5

func status_text() -> String:
    var lines := PackedStringArray()
    lines.append("CAMPUS LIFE  |  %d pedestrians  |  [Q] talk" % pedestrians.size())
    if interior_active:
        lines.append("INDOORS: %s / %s floor  |  [L] lift  [I] exit" % [active_interior, "MEZZANINE" if interior_floor == 1 else "GROUND"])
    elif on_shuttle:
        lines.append("ON UTOWN SHUTTLE  |  [X] alight")
    else:
        var npc_index: int = _nearest_pedestrian()
        if npc_index >= 0:
            lines.append("Nearby: %s  |  [Q] talk" % str(pedestrians[npc_index]["name"]))
        else:
            lines.append("ERC / SRC interiors [I]  |  bicycle [B]")
        var bus_distance: float = Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(shuttle.global_position.x, shuttle.global_position.z)) if shuttle != null else -1.0
        lines.append("Bicycle %s [B]  |  shuttle %.0f m [X]" % ["ON" if bicycle_enabled else "OFF", bus_distance])
    if message_time > 0.0 and not message.is_empty():
        lines.append(message)
    return "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_I:
                enter_nearest_interior()
            KEY_L:
                toggle_interior_floor()
            KEY_Q:
                talk_to_nearest()
            KEY_B:
                toggle_bicycle()
            KEY_X:
                board_or_alight()
