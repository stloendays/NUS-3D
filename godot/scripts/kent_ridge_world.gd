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
var _box_meshes: Dictionary = {}
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
    _build_faculty_amenities()
    _build_sports_ground()
    _build_campus_edge()
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
    var mesh_key: Vector3 = size_value
    if not _box_meshes.has(mesh_key):
        var shape: BoxMesh = BoxMesh.new()
        shape.size = size_value
        _box_meshes[mesh_key] = shape
    mesh.mesh = _box_meshes[mesh_key]
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
    for district in districts:
        var dp: Vector3 = district["position"]
        min_x = minf(min_x, dp.x - 220.0)
        max_x = maxf(max_x, dp.x + 220.0)
        min_z = minf(min_z, dp.z - 220.0)
        max_z = maxf(max_z, dp.z + 220.0)
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
            _box(building, "OriginalMass", Vector3(0.0, height_value * 0.5, 0.0), Vector3(width_value, height_value, depth_value), str(info.get("facade", district["accent"])), true)
            _box(building, "Roof", Vector3(0.0, height_value + 0.22, 0.0), Vector3(width_value + 1.4, 0.45, depth_value + 1.4), "#d4dad6")
            _box(building, "Entrance", Vector3(0.0, 2.4, depth_value * 0.5 + 0.07), Vector3(minf(width_value * 0.42, 14.0), 4.6, 0.16), "#466678")
            for level in range(mini(int(height_value / 4.6), 6)):
                _box(building, "Windows_%d" % level, Vector3(0.0, 3.9 + float(level) * 3.3, depth_value * 0.5 + 0.11), Vector3(width_value * 0.72, 1.2, 0.14), "#5b818b")
            _label(building, str(info["name"]), Vector3(0.0, height_value + 3.1, 0.0), "#f7f7df", 19)
            _decorate_building(building, info, width_value, depth_value, height_value)
            building_count += 1
        if str(district["id"]) == "SCIENCE":
            _build_md1_access(root)
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



func _md1_footpath(parent: Node3D, name_value: String, start: Vector3, finish: Vector3) -> void:
    var delta: Vector3 = finish - start
    var length_value: float = Vector2(delta.x, delta.z).length()
    if length_value < 0.1:
        return
    var path: Node3D = Node3D.new()
    path.name = name_value
    path.position = (start + finish) * 0.5
    path.rotation.y = atan2(delta.x, delta.z)
    parent.add_child(path)
    _box(path, "PedestrianOnly", Vector3.ZERO, Vector3(2.6, 0.12, length_value), "#d1d0c2")


func _build_md1_access(science_root: Node3D) -> void:
    # Schematic pedestrian route, not a surveyed staircase or road geometry.
    # MD1 front facade is at x=68, z=59. Keep all footpath segments
    # outside the building's collision box (x=53.5..82.5, z=27..59).
    var access: Node3D = Node3D.new()
    access.name = "MD1_PedestrianAccess_Schematic"
    science_root.add_child(access)
    var md1_entry: Vector3 = Vector3(68.0, 0.17, 61.8)
    var md6_approach: Vector3 = Vector3(91.0, 0.17, 70.0)
    var nuh_approach: Vector3 = Vector3(91.0, 0.17, 82.0)
    _md1_footpath(access, "MD6_To_MD1_Walk", md6_approach, Vector3(68.0, 0.17, 70.0))
    _md1_footpath(access, "MD1_Entrance_Walk", Vector3(68.0, 0.17, 70.0), md1_entry)
    _md1_footpath(access, "NUH_To_MD6_Walk", nuh_approach, md6_approach)
    _label(access, "MD1  |  PEDESTRIAN ENTRY", Vector3(68.0, 3.1, 64.0), "#e5f1ee", 17)
    # Science Drive 4 vehicle access is intentionally not represented by a
    # driveable link here; do not route buses across these footpaths.

func _build_stations() -> void:
    for stop in stops:
        if bool(stop.get("walk_only", false)):
            continue
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
        var available_lines: PackedStringArray = PackedStringArray()
        for line_id in ["D1", "D2"]:
            if route_serves(line_id, str(stop["id"])):
                available_lines.append(line_id)
        _label(stand, " / ".join(available_lines) + "  •  GAME LINE", Vector3(5.3, 3.2, 0), "#ffd78d", 14)
        shelter_count += 1
    # Visible starting-area guide: the authentic UTown shuttle access is near
    # Town Plaza, not through residential-college lawns.
    var guide: Node3D = Node3D.new()
    guide.name = "TownGreen_ToPlazaBus_Wayfinding"
    # Keep the sign off the initial spawn/camera path.
    guide.position = Vector3(12.0, 0.0, 9.0)
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
        _box(bus, "WindowBand", Vector3(0, 1.63, 0), Vector3(2.51, 0.56, 4.4), "#5c8492")
        _box(bus, "Roof", Vector3(0, 2.02, 0), Vector3(2.5, 0.23, 5.1), "#eff2dd")
        _box(bus, "Windshield", Vector3(0, 1.58, -2.72), Vector3(2.12, 0.72, 0.10), "#7bb7c3")
        _box(bus, "RearWindow", Vector3(0, 1.58, 2.72), Vector3(2.08, 0.65, 0.10), "#7bb7c3")
        _box(bus, "FrontBumper", Vector3(0, 0.59, -2.78), Vector3(2.28, 0.27, 0.18), "#e9e8dc")
        _box(bus, "RearBumper", Vector3(0, 0.59, 2.78), Vector3(2.28, 0.27, 0.18), "#e9e8dc")
        _box(bus, "DoorPanel", Vector3(1.26, 1.04, -0.8), Vector3(0.08, 1.42, 1.05), "#e5e7d9")
        for side in [-1.0, 1.0]:
            for z in [-1.65, 1.65]:
                var wheel: MeshInstance3D = MeshInstance3D.new()
                wheel.name = "Wheel_%d_%d" % [int(side), int(z * 10.0)]
                var tire: CylinderMesh = CylinderMesh.new()
                tire.top_radius = 0.43
                tire.bottom_radius = 0.43
                tire.height = 0.24
                tire.radial_segments = 10
                wheel.mesh = tire
                wheel.rotation.z = PI * 0.5
                wheel.position = Vector3(side * 1.27, 0.48, z)
                wheel.material_override = _material("#343b41")
                bus.add_child(wheel)
                _box(bus, "WheelHub", Vector3(side * 1.41, 0.48, z), Vector3(0.06, 0.25, 0.25), "#c7d1d0")
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
        if bool(stop.get("walk_only", false)):
            continue
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


func _decorate_building(parent: Node3D, info: Dictionary, width_m: float, depth_m: float, height_m: float) -> void:
    # Facade grammar is procedural and original; no Google 3D meshes or tiles.
    var kind: String = str(info.get("kind", "academic"))
    var facade: String = str(info.get("facade", "#d7d1c3"))
    var floor_count: int = maxi(1, int(info.get("floors", 4)))
    var floor_height: float = height_m / float(floor_count)
    var glass: String = "#59899a" if kind == "glass_tower" else "#72929a"
    var frame: String = "#e7e2d6"
    if kind == "residence":
        frame = "#ddcbb0"
    elif kind == "clinic":
        frame = "#f0f0e8"
    elif kind == "station":
        frame = "#9bb8bc"
    # Vertical columns create rhythm and a recognizable campus building silhouette.
    var bays: int = clampi(int(width_m / 6.0), 3, 10)
    for bay in range(bays + 1):
        var x: float = -width_m * 0.5 + width_m * float(bay) / float(bays)
        _box(parent, "FacadeColumn_%02d" % bay, Vector3(x, height_m * 0.5, depth_m * 0.5 + 0.22), Vector3(0.40, height_m, 0.42), frame)
    for floor_index in range(1, floor_count):
        var y: float = float(floor_index) * floor_height
        _box(parent, "FloorSlab_%02d" % floor_index, Vector3(0, y, depth_m * 0.5 + 0.28), Vector3(width_m + 0.8, 0.40, 0.50), facade)
    # Side windows make buildings legible from both roads and the bus.
    for floor_index in range(floor_count):
        var y: float = (float(floor_index) + 0.5) * floor_height
        for side in [-1.0, 1.0]:
            _box(parent, "SideGlass_%d_%d" % [floor_index, int(side)], Vector3(side * (width_m * 0.5 + 0.09), y, 0), Vector3(0.18, minf(2.2, floor_height * 0.58), depth_m * 0.62), glass)
    if kind == "glass_tower":
        _box(parent, "CurtainWall", Vector3(0, height_m * 0.52, depth_m * 0.5 + 0.13), Vector3(width_m * 0.86, height_m * 0.80, 0.20), "#5a9cae")
        for bay in range(1, bays):
            var x: float = -width_m * 0.43 + width_m * 0.86 * float(bay) / float(bays)
            _box(parent, "CurtainMullion_%02d" % bay, Vector3(x, height_m * 0.52, depth_m * 0.5 + 0.27), Vector3(0.12, height_m * 0.82, 0.12), "#d9e4df")
    elif kind == "md1_research":
        # Stylized MD1 massing: podium, vertical glazed bays, shaded entrance.
        # Dimensions and orientation are provisional, not surveyed geometry.
        _box(parent, "MD1_Podium", Vector3(0, 3.0, depth_m * 0.5 + 0.7), Vector3(width_m * 0.96, 6.0, 1.7), "#d2d3cf")
        _box(parent, "MD1_GlazedFacade", Vector3(0, height_m * 0.54, depth_m * 0.5 + 0.36), Vector3(width_m * 0.78, height_m * 0.73, 0.15), "#719da7")
        for bay in range(1, 7):
            var x: float = -width_m * 0.39 + width_m * 0.78 * float(bay) / 7.0
            _box(parent, "MD1_Fin_%02d" % bay, Vector3(x, height_m * 0.55, depth_m * 0.5 + 0.57), Vector3(0.22, height_m * 0.76, 0.42), "#e4e5e0")
        _box(parent, "MD1_EntranceCanopy", Vector3(0, 5.0, depth_m * 0.5 + 2.7), Vector3(width_m * 0.62, 0.44, 4.8), "#a6b6b8")
        _box(parent, "MD1_EntranceGlazing", Vector3(0, 2.1, depth_m * 0.5 + 1.6), Vector3(width_m * 0.44, 3.8, 0.12), "#467987")
    elif kind == "library":
        _box(parent, "LibrarySunshade", Vector3(0, height_m * 0.58, depth_m * 0.5 + 1.5), Vector3(width_m * 0.88, 0.55, 3.0), "#b7a58b")
    elif kind == "residence":
        for bay in range(1, bays):
            var x: float = -width_m * 0.5 + width_m * float(bay) / float(bays)
            _box(parent, "Balcony_%02d" % bay, Vector3(x, height_m * 0.55, depth_m * 0.5 + 1.1), Vector3(width_m / float(bays) * 0.85, 0.22, 2.1), "#e0d8c8")
    elif kind == "auditorium":
        _box(parent, "AuditoriumEntranceCanopy", Vector3(0, 5.2, depth_m * 0.5 + 3.2), Vector3(width_m * 0.74, 0.58, 6.5), "#e9e3d8")
    elif kind == "station":
        _box(parent, "TransitRoof", Vector3(0, height_m + 1.1, 0), Vector3(width_m + 7, 0.6, depth_m + 5), "#8cb5b8")
    elif kind == "canteen":
        _box(parent, "OpenAirCanopy", Vector3(0, 5.4, depth_m * 0.5 + 3.0), Vector3(width_m * 0.9, 0.35, 6.0), "#e3ddc7")
    elif kind == "courtyard":
        _box(parent, "CourtyardPergola", Vector3(0, height_m + 0.5, depth_m * 0.3), Vector3(width_m * 0.65, 0.20, depth_m * 0.38), "#c4b28e")
    if bool(info.get("canopy", false)):
        _box(parent, "CoveredCampusWalk", Vector3(0, 3.4, depth_m * 0.5 + 5.5), Vector3(minf(width_m * 0.76, 26.0), 0.36, 8.5), "#d3d4c6")
        for x in [-8.0, 8.0]:
            _box(parent, "WalkColumn", Vector3(x, 1.7, depth_m * 0.5 + 8.4), Vector3(0.35, 3.3, 0.35), "#c7c9c0")


func _build_sports_ground() -> void:
    var sports: Dictionary = {}
    for district in districts:
        if str(district["id"]) == "SPORTS":
            sports = district
            break
    if sports.is_empty():
        return
    var root_node: Node3D = Node3D.new()
    root_node.name = "ScienceSportsGround"
    root_node.position = sports["position"]
    add_child(root_node)
    _box(root_node, "TrackBed", Vector3(0, 0.16, 0), Vector3(142, 0.12, 96), "#a95d51")
    _box(root_node, "InnerTrack", Vector3(0, 0.24, 0), Vector3(117, 0.10, 75), "#c17a63")
    _box(root_node, "FootballGrass", Vector3(0, 0.32, 0), Vector3(104, 0.10, 64), "#468c59")
    for x in [-51.0, 51.0]:
        _box(root_node, "GoalLine", Vector3(x, 0.40, 0), Vector3(0.25, 0.03, 64), "#f2eee0")
        _box(root_node, "GoalCrossbar", Vector3(x, 2.4, 0), Vector3(0.22, 0.22, 7.4), "#e9eae6")
        for z in [-3.7, 3.7]:
            _box(root_node, "GoalPost", Vector3(x, 1.2, z), Vector3(0.22, 2.4, 0.22), "#e9eae6")
    for z in [-31.0, 31.0]:
        _box(root_node, "Sideline", Vector3(0, 0.40, z), Vector3(104, 0.03, 0.24), "#f2eee0")
    _box(root_node, "HalfwayLine", Vector3(0, 0.41, 0), Vector3(0.20, 0.03, 64), "#f2eee0")
    for lane in range(4):
        var z: float = 37.7 + float(lane) * 2.3
        for sign in [-1.0, 1.0]:
            _box(root_node, "RunningLane", Vector3(0, 0.32, z * sign), Vector3(132, 0.03, 0.15), "#f2d9cb")
    for side in [-1.0, 1.0]:
        for tier in range(3):
            _box(root_node, "Bleacher", Vector3(side * 76.0, 0.55 + tier * 0.48, 0), Vector3(4.0, 0.42, 65.0 - tier * 3.0), "#c7c6b8")
        for z in [-46.0, 46.0]:
            _box(root_node, "FloodlightPole", Vector3(side * 83.0, 7.0, z), Vector3(0.42, 14.0, 0.42), "#a6b3b2")
            _box(root_node, "Floodlight", Vector3(side * 83.0, 14.2, z), Vector3(3.6, 1.1, 0.65), "#e8e6cf")
    _label(root_node, "CAMPUS SPORTS FIELD", Vector3(0, 5.2, -51), "#fff3db", 25)
    var ball: MeshInstance3D = MeshInstance3D.new()
    ball.name = "PracticeBall"
    var ball_mesh: SphereMesh = SphereMesh.new()
    ball_mesh.radius = 0.36
    ball_mesh.height = 0.72
    ball.mesh = ball_mesh
    ball.position = Vector3(-6.0, 0.9, 0.0)
    ball.material_override = _material("#f1eee0")
    root_node.add_child(ball)
    _build_sports_npcs(root_node)
    _build_canteen_terrace()


func _build_campus_edge() -> void:
    # Low-poly tree belt + natural ridge, rather than invisible map-edge walls.
    # Keep a margin beyond the actual terrain and make the edge visibly scenic.
    var land: Node3D = get_node_or_null("CampusBaseTerrain_Estimated")
    if land == null:
        return
    var ground: MeshInstance3D = land.get_node_or_null("GroundBeyondUTown") as MeshInstance3D
    if ground == null:
        return
    var shape: BoxMesh = ground.mesh as BoxMesh
    var center: Vector3 = ground.position
    var half_x: float = shape.size.x * 0.5
    var half_z: float = shape.size.z * 0.5
    var edge: Node3D = Node3D.new()
    edge.name = "WoodedCampusBoundary"
    add_child(edge)
    var segments: int = 18
    for side in range(4):
        for i in range(segments + 1):
            var t: float = float(i) / float(segments)
            var x: float = center.x + lerpf(-half_x, half_x, t)
            var z: float = center.z + lerpf(-half_z, half_z, t)
            if side == 0:
                z = center.z - half_z + 7.0
            elif side == 1:
                z = center.z + half_z - 7.0
            elif side == 2:
                x = center.x - half_x + 7.0
            else:
                x = center.x + half_x - 7.0
            var trunk_height: float = 7.0 + float((i * 7 + side * 11) % 5)
            _box(edge, "TreeTrunk", Vector3(x, trunk_height * 0.5, z), Vector3(1.0, trunk_height, 1.0), "#6b6048")
            var canopy: MeshInstance3D = MeshInstance3D.new()
            canopy.name = "BoundaryCanopy"
            var sphere: SphereMesh = SphereMesh.new()
            sphere.radius = 4.8
            sphere.height = 9.6
            canopy.mesh = sphere
            canopy.position = Vector3(x, trunk_height + 3.5, z)
            canopy.material_override = _material("#4a7557" if i % 2 == 0 else "#638a5d")
            edge.add_child(canopy)
    for side in [-1.0, 1.0]:
        _box(edge, "FarRidge", Vector3(center.x + side * (half_x + 35.0), 4.5, center.z), Vector3(65.0, 9.0, shape.size.z + 180.0), "#668467")
    for side in [-1.0, 1.0]:
        _box(edge, "FarRidge", Vector3(center.x, 4.5, center.z + side * (half_z + 35.0)), Vector3(shape.size.x + 180.0, 9.0, 65.0), "#668467")


func _build_canteen_terrace() -> void:
    var science: Dictionary = {}
    for district in districts:
        if str(district["id"]) == "SCIENCE":
            science = district
            break
    if science.is_empty():
        return
    var terrace: Node3D = Node3D.new()
    terrace.name = "FrontierCanteenTerrace"
    terrace.position = science["position"] + Vector3(43.0, 0.0, -66.0)
    add_child(terrace)
    _box(terrace, "TerracePaving", Vector3(0, 0.09, 0), Vector3(55, 0.18, 42), "#c6c1ad")
    _box(terrace, "Awning", Vector3(0, 4.2, 0), Vector3(48, 0.48, 27), "#e0d4bb")
    for x in [-21.0, 21.0]:
        for z in [-11.0, 11.0]:
            _box(terrace, "AwningPost", Vector3(x, 2.1, z), Vector3(0.35, 4.2, 0.35), "#c8c2b4")
    for row in range(3):
        for col in range(4):
            var x: float = -17.0 + float(col) * 11.0
            var z: float = -7.0 + float(row) * 8.0
            _box(terrace, "DiningTable", Vector3(x, 1.1, z), Vector3(4.0, 0.18, 2.5), "#a77c55")
            for side in [-1.0, 1.0]:
                _box(terrace, "DiningBench", Vector3(x, 0.55, z + side * 2.2), Vector3(3.7, 0.42, 0.55), "#6b776d")
    for x in [-25.0, 25.0]:
        _box(terrace, "Planter", Vector3(x, 0.45, 17.0), Vector3(3.2, 0.9, 3.2), "#9d8c70")
        var plant: MeshInstance3D = MeshInstance3D.new()
        var foliage: SphereMesh = SphereMesh.new()
        foliage.radius = 1.8
        foliage.height = 3.6
        plant.mesh = foliage
        plant.position = Vector3(x, 2.5, 17.0)
        plant.material_override = _material("#5f936a")
        terrace.add_child(plant)
    _label(terrace, "FRONTIER CANTEEN", Vector3(0, 5.6, -15.0), "#fff0c8", 23)
    for i in range(3):
        var npc: Node3D = _make_campus_npc("CanteenStudent_%d" % i, Vector3(-12.0 + float(i) * 12.0, 0.0, 15.0), ["#d58a6d", "#7999b8", "#b7a074"][i])
        terrace.add_child(npc)


func _make_campus_npc(npc_name: String, at: Vector3, shirt: String) -> Node3D:
    var person: Node3D = Node3D.new()
    person.name = npc_name
    person.position = at
    var torso: MeshInstance3D = MeshInstance3D.new()
    var capsule: CapsuleMesh = CapsuleMesh.new()
    capsule.radius = 0.34
    capsule.height = 1.0
    torso.mesh = capsule
    torso.position.y = 0.98
    torso.material_override = _material(shirt)
    person.add_child(torso)
    var head: MeshInstance3D = MeshInstance3D.new()
    var sphere: SphereMesh = SphereMesh.new()
    sphere.radius = 0.25
    head.mesh = sphere
    head.position.y = 1.68
    head.material_override = _material("#d7ad8d")
    person.add_child(head)
    var bag: MeshInstance3D = MeshInstance3D.new()
    var bag_mesh: BoxMesh = BoxMesh.new()
    bag_mesh.size = Vector3(0.5, 0.7, 0.22)
    bag.mesh = bag_mesh
    bag.position = Vector3(0.38, 1.0, 0.15)
    bag.material_override = _material("#394c56")
    person.add_child(bag)
    return person


func _build_sports_npcs(parent: Node3D) -> void:
    for i in range(4):
        var x: float = -26.0 + float(i) * 17.0
        var z: float = -38.0 if i % 2 == 0 else 38.0
        var npc: Node3D = _make_campus_npc("SportsStudent_%d" % i, Vector3(x, 0.0, z), ["#d58a6d", "#7999b8", "#b7a074", "#7da88c"][i])
        parent.add_child(npc)
    for x in [-57.0, 57.0]:
        _box(parent, "WaterStation", Vector3(x, 1.1, 0.0), Vector3(1.8, 2.2, 1.5), "#77a8aa")
        _box(parent, "Bench", Vector3(x, 0.55, 12.0), Vector3(4.5, 0.5, 1.2), "#9b8668")

# Campus amenities are original, low-poly interpretations, not surveyed interiors.
# Each district has its own reason to visit instead of repeating generic benches.
func _build_faculty_amenities() -> void:
    var specs: Dictionary = {
        "ENGINEERING": ["MAKER", "DINING", "WORKSHOP"],
        "CLB": ["READING", "STUDY", "PRINT"],
        "COM3": ["COMPUTER", "PROJECT", "LOUNGE"],
        "BIZ2": ["DISCUSSION", "PRESENT", "COFFEE"],
        "MUSEUM": ["EXHIBIT", "ART", "SEATING"],
        "YIH": ["COMMONS", "NOTICE", "SEATING"],
        "UHC": ["WAITING", "WATER", "SEATING"],
        "PGP": ["LAUNDRY", "COMMONS", "SEATING"],
        "KR_MRT": ["WAITING", "WATER", "SEATING"]
    }
    for district in districts:
        var district_id: String = str(district["id"])
        if not specs.has(district_id):
            continue
        var root_node: Node3D = district_root.get_node_or_null(district_id) as Node3D
        if root_node == null:
            continue
        var amenities: Node3D = Node3D.new()
        amenities.name = "FacultyAmenities"
        amenities.position = Vector3(0, 0, -26)
        root_node.add_child(amenities)
        var activities: Array = specs[district_id]
        for index in range(activities.size()):
            var kind: String = str(activities[index])
            var zone: Node3D = Node3D.new()
            zone.name = kind + "_Zone"
            zone.position = Vector3(-31.0 + float(index) * 31.0, 0, 0)
            amenities.add_child(zone)
            _build_amenity_zone(zone, kind)


func _build_amenity_zone(zone: Node3D, kind: String) -> void:
    _box(zone, "Paving", Vector3(0, 0.12, 0), Vector3(22, 0.18, 18), "#d9d3c5")
    if kind in ["MAKER", "WORKSHOP", "PROJECT", "COMPUTER"]:
        for i in range(3):
            var x: float = -7.0 + float(i) * 7.0
            _box(zone, "WorkBench_%d" % i, Vector3(x, 0.9, 0), Vector3(4.4, 0.24, 2.2), "#b99b79")
            _box(zone, "Monitor_%d" % i, Vector3(x, 1.6, -0.5), Vector3(1.6, 1.1, 0.2), "#5c8190")
            _box(zone, "Keyboard_%d" % i, Vector3(x, 1.08, 0.5), Vector3(1.4, 0.08, 0.45), "#d7dbd5")
    elif kind in ["READING", "STUDY", "DISCUSSION", "PRESENT"]:
        for i in range(3):
            var x: float = -7.0 + float(i) * 7.0
            _box(zone, "StudyDesk_%d" % i, Vector3(x, 1.0, 0), Vector3(4.0, 0.2, 2.5), "#c0a27e")
            _box(zone, "Chair_%d" % i, Vector3(x, 0.55, 2.3), Vector3(1.2, 0.65, 1.2), "#738c91")
        if kind == "PRESENT":
            _box(zone, "PresentationScreen", Vector3(0, 2.5, -7.8), Vector3(10.0, 4.2, 0.3), "#e8ece8")
    elif kind in ["DINING", "COFFEE", "COMMONS", "LOUNGE", "SEATING", "WAITING"]:
        for i in range(3):
            var x: float = -7.0 + float(i) * 7.0
            _box(zone, "CafeTable_%d" % i, Vector3(x, 0.95, 0), Vector3(2.8, 0.18, 2.2), "#b69a78")
            _box(zone, "CafeSeat_%d" % i, Vector3(x, 0.48, 2.0), Vector3(2.6, 0.35, 0.7), "#7b9788")
        if kind in ["DINING", "COFFEE"]:
            _box(zone, "FoodCounter", Vector3(0, 1.25, -7), Vector3(15, 2.5, 1.5), "#d6b68d")
    elif kind in ["EXHIBIT", "ART"]:
        for i in range(3):
            var x: float = -7.0 + float(i) * 7.0
            _box(zone, "ExhibitPlinth_%d" % i, Vector3(x, 0.85, 0), Vector3(2.5, 1.7, 2.5), "#d6d1c6")
            _box(zone, "Sculpture_%d" % i, Vector3(x, 2.3, 0), Vector3(1.1, 1.5 + float(i), 1.1), "#a7b7ad")
    elif kind == "PRINT":
        for i in range(3):
            _box(zone, "Printer_%d" % i, Vector3(-6 + i * 6, 1.05, 0), Vector3(2.8, 2.1, 2.3), "#d8dfdc")
    elif kind == "LAUNDRY":
        for i in range(4):
            _box(zone, "Washer_%d" % i, Vector3(-7.5 + i * 5, 1.1, 0), Vector3(3.1, 2.2, 2.9), "#b9cbd0")
    elif kind in ["WATER", "NOTICE"]:
        _box(zone, "CampusFixture", Vector3(0, 1.25, 0), Vector3(3.0, 2.5, 1.4), "#80aaa9")
    _refine_amenity_models(zone, kind)
    _label(zone, kind.replace("_", " "), Vector3(0, 3.6, -7), "#f8f2e4", 17)


# Second-pass geometry: readable silhouettes, actual functional parts and softer materials.
# This adds a small bounded number of meshes per zone, without importing assets.
func _refine_amenity_models(zone: Node3D, kind: String) -> void:
    if kind in ["MAKER", "WORKSHOP", "PROJECT", "COMPUTER"]:
        for i in range(3):
            var x: float = -7.0 + float(i) * 7.0
            _box(zone, "MonitorStand_%d" % i, Vector3(x, 1.12, -0.5), Vector3(0.15, 0.45, 0.16), "#aeb9b7")
            _box(zone, "MonitorBezel_%d" % i, Vector3(x, 1.6, -0.38), Vector3(1.85, 1.28, 0.09), "#344f5a")
            _box(zone, "Screen_%d" % i, Vector3(x, 1.6, -0.31), Vector3(1.57, 1.02, 0.04), "#8bbbc0")
            for side in [-1.0, 1.0]:
                _box(zone, "BenchLeg_%d_%d" % [i, int(side)], Vector3(x + side * 1.8, 0.45, 0), Vector3(0.22, 0.9, 1.75), "#777d76")
        if kind in ["MAKER", "WORKSHOP"]:
            _box(zone, "ToolRack", Vector3(0, 2.3, -7.5), Vector3(14.0, 3.5, 0.45), "#b7b6aa")
            for i in range(5):
                _box(zone, "RackTool_%d" % i, Vector3(-5.5 + float(i) * 2.6, 2.2, -7.15), Vector3(0.35, 1.45, 0.18), "#667f84")
    elif kind in ["READING", "STUDY", "DISCUSSION", "PRESENT"]:
        for i in range(3):
            var x: float = -7.0 + float(i) * 7.0
            _box(zone, "ChairBack_%d" % i, Vector3(x, 1.0, 2.65), Vector3(1.25, 1.1, 0.18), "#738c91")
            _box(zone, "DeskLamp_%d" % i, Vector3(x - 1.1, 1.35, -0.6), Vector3(0.15, 0.55, 0.15), "#7e9995")
            _box(zone, "LampShade_%d" % i, Vector3(x - 1.1, 1.65, -0.6), Vector3(0.75, 0.15, 0.6), "#e7d6b5")
        if kind in ["READING", "STUDY"]:
            for i in range(2):
                _box(zone, "Bookshelf_%d" % i, Vector3(-5.0 + float(i) * 10.0, 1.6, -7.2), Vector3(5.5, 3.2, 0.85), "#b59b7d")
                for shelf in range(3):
                    _box(zone, "BookRow_%d_%d" % [i, shelf], Vector3(-5.0 + float(i) * 10.0, 0.65 + float(shelf) * 0.9, -6.65), Vector3(4.8, 0.55, 0.4), "#7f9d98" if shelf % 2 == 0 else "#d7b999")
    elif kind in ["DINING", "COFFEE", "COMMONS", "LOUNGE", "SEATING", "WAITING"]:
        for i in range(3):
            var x: float = -7.0 + float(i) * 7.0
            _box(zone, "SeatBack_%d" % i, Vector3(x, 1.05, 2.3), Vector3(2.65, 1.1, 0.22), "#7b9788")
            _box(zone, "TablePedestal_%d" % i, Vector3(x, 0.47, 0), Vector3(0.25, 0.85, 0.25), "#8b9290")
        if kind in ["DINING", "COFFEE"]:
            _box(zone, "CounterTop", Vector3(0, 2.57, -7), Vector3(15.6, 0.15, 1.8), "#efe3d1")
            for i in range(3):
                _box(zone, "MenuPanel_%d" % i, Vector3(-5 + i * 5, 3.6, -7.2), Vector3(3.9, 1.25, 0.12), "#5d7f7b")
    elif kind in ["EXHIBIT", "ART"]:
        for i in range(3):
            var x: float = -7.0 + float(i) * 7.0
            var sculpture: MeshInstance3D = MeshInstance3D.new()
            sculpture.name = "CurvedSculpture_%d" % i
            var capsule: CapsuleMesh = CapsuleMesh.new()
            capsule.radius = 0.43 + float(i) * 0.12
            capsule.height = 1.8 + float(i) * 0.4
            sculpture.mesh = capsule
            sculpture.position = Vector3(x, 2.6, 0)
            sculpture.rotation.z = 0.25 + float(i) * 0.24
            sculpture.material_override = _material("#b1bdb0" if i % 2 == 0 else "#d8b9a0")
            zone.add_child(sculpture)
    elif kind == "PRINT":
        for i in range(3):
            var x: float = -6.0 + float(i) * 6.0
            _box(zone, "PrinterControl_%d" % i, Vector3(x, 1.75, 1.2), Vector3(1.2, 0.25, 0.1), "#527a8a")
            _box(zone, "PaperTray_%d" % i, Vector3(x, 0.7, 1.35), Vector3(1.7, 0.2, 0.7), "#e9ece7")
    elif kind == "LAUNDRY":
        for i in range(4):
            var x: float = -7.5 + float(i) * 5.0
            var door: MeshInstance3D = MeshInstance3D.new()
            door.name = "WasherDoor_%d" % i
            var cylinder: CylinderMesh = CylinderMesh.new()
            cylinder.top_radius = 0.85
            cylinder.bottom_radius = 0.85
            cylinder.height = 0.14
            door.mesh = cylinder
            door.rotation.x = PI * 0.5
            door.position = Vector3(x, 1.25, 1.52)
            door.material_override = _material("#577f89")
            zone.add_child(door)
            _box(zone, "WasherControls_%d" % i, Vector3(x, 1.95, 1.55), Vector3(1.65, 0.18, 0.10), "#e8e9e2")
    elif kind == "WATER":
        _box(zone, "WaterTap", Vector3(0, 1.7, 0.85), Vector3(0.65, 0.25, 0.45), "#dce7e4")
        _box(zone, "WaterTray", Vector3(0, 1.25, 0.9), Vector3(1.3, 0.15, 0.65), "#a7c5c5")
    elif kind == "NOTICE":
        _box(zone, "NoticeBoard", Vector3(0, 1.9, 0.85), Vector3(7.0, 3.3, 0.22), "#c8ad8b")
        for i in range(3):
            _box(zone, "Poster_%d" % i, Vector3(-2.2 + float(i) * 2.2, 1.95, 1.0), Vector3(1.65, 2.2, 0.05), "#e7dfcb" if i % 2 == 0 else "#9ab8b3")

