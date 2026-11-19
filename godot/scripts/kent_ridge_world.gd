extends Node3D
class_name NUSKentRidgeWorld
## Campus-scale schematic expansion. Anchors are approximate WGS84 POIs,
## but buildings, walkways and vehicle paths are original fictional geometry.
## Does not mutate existing UTown layouts, physics, vehicles or missions.

const DATA_PATH: String = "res://data/kent_ridge_expansion.json"
const BUS_SPEED: float = 20.0
const BUS_DWELL: float = 2.0

@onready var utown: UTownWorld = $"../World"

var districts: Array[Dictionary] = []
var stops: Array[Dictionary] = []
var routes: Dictionary = {}
var walk_connections: Array = []
var district_root: Node3D
var roads_root: Node3D
var stops_root: Node3D
var bus_root: Node3D
var bus_states: Array[Dictionary] = []
var building_count: int = 0
var shelter_count: int = 0
var _stops_by_id: Dictionary = {}
var _materials: Dictionary = {}
var _bus_mesh: BoxMesh

func _ready() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Kent Ridge campus expansion JSON is unavailable")
        return
    var data: Dictionary = parsed
    routes = data.get("routes", {})
    walk_connections = data.get("walk_connections", [])
    for item in data.get("districts", []):
        var district: Dictionary = item.duplicate(true)
        district["position"] = utown.lonlat_to_world(float(item["lon"]), float(item["lat"]))
        districts.append(district)
    for item in data.get("stops", []):
        var stop: Dictionary = item.duplicate(true)
        stop["position"] = utown.lonlat_to_world(float(item["lon"]), float(item["lat"]))
        stops.append(stop)
        _stops_by_id[str(stop["id"])] = stop
    _build_extended_ground()
    district_root = Node3D.new()
    district_root.name = "KentRidgeDistricts_Schematic"
    add_child(district_root)
    roads_root = Node3D.new()
    roads_root.name = "CampusRoadLinks_Schematic"
    add_child(roads_root)
    stops_root = Node3D.new()
    stops_root.name = "CampusBusStops_Schematic"
    add_child(stops_root)
    bus_root = Node3D.new()
    bus_root.name = "CampusBuses_Cosmetic"
    add_child(bus_root)
    _build_road_links()
    _build_districts()
    _build_stations()
    _build_buses()


func _material(hex: String) -> StandardMaterial3D:
    if _materials.has(hex):
        return _materials[hex]
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color.html(hex)
    material.roughness = 0.88
    _materials[hex] = material
    return material


func _box(parent: Node3D, name_value: String, position_value: Vector3, size_value: Vector3, color_hex: String, solid: bool = false) -> MeshInstance3D:
    var mesh: MeshInstance3D = MeshInstance3D.new()
    mesh.name = name_value
    mesh.position = position_value
    var shape: BoxMesh = BoxMesh.new()
    shape.size = size_value
    mesh.mesh = shape
    mesh.material_override = _material(color_hex)
    parent.add_child(mesh)
    if solid:
        var static_body: StaticBody3D = StaticBody3D.new()
        static_body.name = "SchematicCollision"
        mesh.add_child(static_body)
        var collider: CollisionShape3D = CollisionShape3D.new()
        var collider_box: BoxShape3D = BoxShape3D.new()
        collider_box.size = size_value
        collider.shape = collider_box
        static_body.add_child(collider)
    return mesh


func _label(parent: Node3D, label_text: String, position_value: Vector3, color_hex: String, font_size_value: int = 28) -> Label3D:
    var label: Label3D = Label3D.new()
    label.text = label_text
    label.position = position_value
    label.font_size = font_size_value
    label.pixel_size = 0.011
    label.modulate = Color.html(color_hex)
    label.outline_size = 5
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    parent.add_child(label)
    return label


func _build_extended_ground() -> void:
    var min_x: float = -320.0
    var max_x: float = 320.0
    var min_z: float = -450.0
    var max_z: float = 450.0
    for stop in stops:
        var p: Vector3 = stop["position"]
        min_x = minf(min_x, p.x - 160.0)
        max_x = maxf(max_x, p.x + 160.0)
        min_z = minf(min_z, p.z - 160.0)
        max_z = maxf(max_z, p.z + 160.0)
    var land: Node3D = Node3D.new()
    land.name = "CampusBaseTerrain_Estimated"
    add_child(land)
    var center: Vector3 = Vector3((min_x + max_x) * 0.5, -0.33, (min_z + max_z) * 0.5)
    _box(land, "GroundBeyondUTown", center, Vector3(max_x - min_x, 0.64, max_z - min_z), "#759573", true)


func _build_road_links() -> void:
    # Schematic straight connections only: these are NOT real streets or bus routes.
    for connection in walk_connections:
        if connection.size() < 2:
            continue
        var left: Dictionary = _stops_by_id.get(str(connection[0]), {})
        var right: Dictionary = _stops_by_id.get(str(connection[1]), {})
        if left.is_empty() or right.is_empty():
            continue
        var start: Vector3 = left["position"]
        var finish: Vector3 = right["position"]
        var delta: Vector3 = finish - start
        if delta.length() < 0.1:
            continue
        var axis: Node3D = Node3D.new()
        axis.name = "WalkLink_" + str(connection[0]) + "_" + str(connection[1])
        axis.position = (start + finish) * 0.5
        axis.rotation.y = atan2(delta.x, delta.z)
        roads_root.add_child(axis)
        _box(axis, "SharedPath_Schematic", Vector3(0.0, 0.045, 0.0), Vector3(7.8, 0.065, delta.length()), "#91918a")
        _box(axis, "Footpath", Vector3(-5.0, 0.075, 0.0), Vector3(2.3, 0.09, delta.length()), "#c2c6b7")
        _box(axis, "CycleLane", Vector3(5.0, 0.067, 0.0), Vector3(2.0, 0.06, delta.length()), "#b3aa83")


func _build_districts() -> void:
    for district in districts:
        var root: Node3D = Node3D.new()
        root.name = str(district["id"])
        root.position = district["position"]
        district_root.add_child(root)
        var size_values: Array = district.get("size", [150, 140])
        var width_m: float = float(size_values[0])
        var depth_m: float = float(size_values[1])
        _box(root, "DistrictPlaza", Vector3(0, 0.022, 0), Vector3(width_m, 0.05, depth_m), "#8cac80")
        _box(root, "MainPromenade", Vector3(0, 0.07, 0), Vector3(width_m - 9.0, 0.10, 8), "#c4c5b8")
        _box(root, "NorthSouthPromenade", Vector3(0, 0.079, 0), Vector3(8.0, 0.10, depth_m - 9.0), "#c4c5b8")
        _label(root, str(district["name"]).to_upper(), Vector3(0, 5, 0), str(district["accent"]), 26)
        for info in district.get("landmarks", []):
            var local_offset: Array = info.get("offset", [0, 0])
            var dims: Array = info.get("size", [35, 25, 15])
            var width_value: float = float(dims[0])
            var depth_value: float = float(dims[1])
            var height_value: float = float(dims[2])
            var at: Vector3 = Vector3(float(local_offset[0]), height_value * 0.5 + 0.1, -float(local_offset[1]))
            var building: Node3D = Node3D.new()
            building.name = str(info["name"]).replace(" ", "_").replace("/", "_")
            building.position = Vector3(at.x, 0.0, at.z)
            root.add_child(building)
            _box(building, "OriginalMass", Vector3(0.0, height_value * 0.5, 0.0), Vector3(width_value, height_value, depth_value), str(district["accent"]), true)
            _box(building, "Roof", Vector3(0.0, height_value + 0.22, 0.0), Vector3(width_value + 1.4, 0.45, depth_value + 1.4), "#d4dad6")
            _box(building, "Entrance", Vector3(0.0, 2.4, depth_value * 0.5 + 0.07), Vector3(minf(width_value * 0.42, 14.0), 4.6, 0.16), "#466678")
            for level in range(mini(int(height_value / 4.6), 6)):
                _box(building, "Windows_%d" % level, Vector3(0.0, 3.9 + float(level) * 3.3, depth_value * 0.5 + 0.11), Vector3(width_value * 0.72, 1.2, 0.14), "#5b818b")
            _label(building, str(info["name"]), Vector3(0.0, height_value + 3.1, 0.0), "#f7f7df", 19)
            building_count += 1
        # Small placemaking accents, no more than six low-poly props per district.
        for i in range(3):
            var x: float = -width_m * 0.35 + float(i) * width_m * 0.35
            var z: float = depth_m * 0.31
            _box(root, "Planter_%d" % i, Vector3(x, 0.45, z), Vector3(2.0, 0.9, 2.0), "#957f68")
            var canopy: MeshInstance3D = MeshInstance3D.new()
            var treetop: SphereMesh = SphereMesh.new()
            treetop.radius = 2.1
            treetop.height = 4.2
            canopy.mesh = treetop
            canopy.position = Vector3(x, 3.0, z)
            canopy.material_override = _material("#5e966a")
            root.add_child(canopy)


func _build_stations() -> void:
    for stop in stops:
        var stand: Node3D = Node3D.new()
        stand.name = "BusStop_" + str(stop["id"])
        stand.position = stop["position"]
        stops_root.add_child(stand)
        _box(stand, "Platform", Vector3(0, 0.12, 0), Vector3(12, 0.22, 6), "#d0d0bf")
        _box(stand, "ShelterRoof", Vector3(0, 3.1, -2), Vector3(10.2, 0.24, 3.0), "#47737b")
        for x_offset in [-4.4, 4.4]:
            _box(stand, "ShelterPost", Vector3(x_offset, 1.62, -3), Vector3(0.18, 3.12, 0.18), "#283943")
        _box(stand, "RoutePanel", Vector3(5.3, 1.58, 0), Vector3(1.5, 2.5, 0.24), "#f2d387")
        _label(stand, str(stop["name"]), Vector3(0, 4.2, 0), "#e5f8f6", 19)
        _label(stand, "D1 / D2  •  GAME ROUTES", Vector3(5.3, 3.2, 0), "#ffd78d", 14)
        shelter_count += 1
    # Visible starting-area guide: the authentic UTown shuttle access is near
    # Town Plaza, not through residential-college lawns.
    var guide: Node3D = Node3D.new()
    guide.name = "TownGreen_ToPlazaBus_Wayfinding"
    guide.position = Vector3(0.0, 0.0, 0.0)
    stops_root.add_child(guide)
    _box(guide, "GuidePole", Vector3(0, 1.45, 0), Vector3(0.18, 2.9, 0.18), "#304953")
    _box(guide, "GuideBoard", Vector3(0, 2.95, 0), Vector3(4.7, 0.82, 0.16), "#37666d")
    _label(guide, "BUS  ↘  TOWN PLAZA", Vector3(0, 3.0, 0.23), "#f9e6b4", 18)


func _route_points(route_name: String) -> Array[Vector3]:
    var points: Array[Vector3] = []
    for stop_id in routes.get(route_name, []):
        if _stops_by_id.has(str(stop_id)):
            points.append(_stops_by_id[str(stop_id)]["position"])
    if points.size() > 2:
        for i in range(points.size() - 2, 0, -1):
            points.append(points[i])
    return points


func _build_buses() -> void:
    var route_colors: Dictionary = {"D1": "#58c8c6", "D2": "#f0bf6d"}
    for route_name in ["D1", "D2"]:
        var points: Array[Vector3] = _route_points(route_name)
        if points.size() < 2:
            continue
        var bus: Node3D = Node3D.new()
        bus.name = "MovingBus_" + route_name
        bus.position = points[0] + Vector3(0, 0.4, 0)
        bus_root.add_child(bus)
        _box(bus, "Body", Vector3(0, 1.0, 0), Vector3(2.45, 1.45, 5.4), str(route_colors[route_name]))
        _box(bus, "WindowBand", Vector3(0, 1.63, 0), Vector3(2.51, 0.56, 4.4), "#365b68")
        _box(bus, "Roof", Vector3(0, 2.02, 0), Vector3(2.5, 0.23, 5.1), "#eff2dd")
        for side in [-1.0, 1.0]:
            for z in [-1.6, 1.6]:
                _box(bus, "Wheel", Vector3(side * 1.15, 0.49, z), Vector3(0.26, 0.75, 0.72), "#27303c")
        _label(bus, "NUS GAME SHUTTLE  " + route_name, Vector3(0, 2.75, 0), "#fff9e6", 19)
        bus_states.append({"node": bus, "points": points, "index": 0, "wait": 0.5})


func stop_position(stop_id: String) -> Vector3:
    var item: Dictionary = _stops_by_id.get(stop_id, {})
    return item.get("position", Vector3.ZERO)


func stop_record(stop_id: String) -> Dictionary:
    return _stops_by_id.get(stop_id, {})


func nearest_stop(position_value: Vector3, radius_m: float = 18.0) -> Dictionary:
    var best: Dictionary = {}
    var best_dist: float = radius_m
    for stop in stops:
        var p: Vector3 = stop["position"]
        var distance_m: float = Vector2(position_value.x, position_value.z).distance_to(Vector2(p.x, p.z))
        if distance_m <= best_dist:
            best_dist = distance_m
            best = stop
    return best


func route_serves(route_id: String, stop_id: String) -> bool:
    return routes.has(route_id) and (routes[route_id] as Array).has(stop_id)


func _process(delta: float) -> void:
    for state in bus_states:
        var bus: Node3D = state["node"]
        var points: Array[Vector3] = state["points"]
        if points.size() < 2:
            continue
        if float(state["wait"]) > 0.0:
            state["wait"] = maxf(0.0, float(state["wait"]) - delta)
            continue
        var index: int = int(state["index"])
        var target: Vector3 = points[(index + 1) % points.size()] + Vector3(0, 0.4, 0)
        var direction: Vector3 = target - bus.position
        var distance_m: float = direction.length()
        if distance_m <= BUS_SPEED * delta:
            bus.position = target
            state["index"] = (index + 1) % points.size()
            state["wait"] = BUS_DWELL
        else:
            bus.position += direction / distance_m * BUS_SPEED * delta
            bus.rotation.y = atan2(direction.x, direction.z)
