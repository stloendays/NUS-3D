extends Node3D
class_name NUSKentRidgeWorld
## Campus-scale schematic expansion. Anchors are approximate WGS84 POIs,
## but buildings, walkways and vehicle paths are original fictional geometry.
## Does not mutate existing UTown layouts, physics, vehicles or missions.

const DATA_PATH: String = "res://data/kent_ridge_expansion.json"
const TERRAIN_MESH = preload("res://scripts/kent_ridge_terrain_mesh.gd")
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
        var stop_position: Vector3 = stop["position"]
        stop_position.y = _surface_elevation(stop_position)
        stop["position"] = stop_position
        stops.append(stop)
        _stops_by_id[str(stop["id"])] = stop
    _build_extended_ground()
    add_child(TERRAIN_MESH.create(districts))
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


func _surface_elevation(point: Vector3) -> float:
    # Single authoritative sampler for terrain and bus stop positions.
    return TERRAIN_MESH.height_at(Vector2(point.x, point.z), districts)


func _graded_strip(parent: Node3D, name_value: String, start: Vector3, finish: Vector3, width_value: float, color: String) -> void:
    var delta: Vector3 = finish - start
    var length_value: float = delta.length()
    if length_value < 0.1:
        return
    var axis := Node3D.new()
    axis.name = name_value
    axis.position = (start + finish) * 0.5
    # Build an orthonormal slope basis; Euler yaw/pitch produced inverted
    # grades for some route directions.
    var forward: Vector3 = delta.normalized()
    var right: Vector3 = Vector3(forward.z, 0.0, -forward.x).normalized()
    if right.length_squared() < 0.01:
        return
    var normal: Vector3 = forward.cross(right).normalized()
    axis.basis = Basis(right, normal, forward)
    parent.add_child(axis)
    # The walk and cycle strips are now physical walking surfaces.
    # Keep the wider shared bus strip cosmetic to avoid duplicate collisions.
    var solid_surface: bool = name_value.begins_with("Footpath_") or name_value.begins_with("CycleLane_")
    _box(axis, "GradedSurface", Vector3.ZERO, Vector3(width_value, 0.11, length_value), color, solid_surface)


const PATH_SAMPLE_STEP: float = 18.0
const PATH_MAX_SEGMENTS: int = 64

func _terrain_following_strip(parent: Node3D, name_value: String, start: Vector3, finish: Vector3, lateral_offset: float, width_value: float, color: String, clearance: float) -> void:
    var flat_delta: Vector3 = Vector3(finish.x - start.x, 0.0, finish.z - start.z)
    var distance_m: float = flat_delta.length()
    if distance_m < 0.2:
        return
    var right: Vector3 = Vector3(flat_delta.z, 0.0, -flat_delta.x).normalized()
    var segments: int = clampi(ceili(distance_m / PATH_SAMPLE_STEP), 1, PATH_MAX_SEGMENTS)
    var group := Node3D.new()
    group.name = name_value
    parent.add_child(group)
    var previous: Vector3 = Vector3.ZERO
    for i in range(segments + 1):
        var t: float = float(i) / float(segments)
        var point: Vector3 = start.lerp(finish, t) + right * lateral_offset
        point.y = _surface_elevation(point) + clearance
        if i > 0:
            _graded_strip(group, "Footpath_segment_%02d" % (i - 1) if name_value.begins_with("Footpath_") else ("CycleLane_segment_%02d" % (i - 1) if name_value.begins_with("CycleLane_") else "Road_segment_%02d" % (i - 1)), previous, point, width_value, color)
        previous = point


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
        var link_name: String = str(connection[0]) + "_" + str(connection[1])
        _terrain_following_strip(roads_root, "WalkLink_" + link_name,
            start, finish, 0.0, 7.8, "#91918a", 0.08)
        _terrain_following_strip(roads_root, "Footpath_" + link_name,
            start, finish, -5.0, 2.3, "#c2c6b7", 0.16)
        _terrain_following_strip(roads_root, "CycleLane_" + link_name,
            start, finish, 5.0, 2.0, "#b3aa83", 0.12)


func _build_districts() -> void:
    for district in districts:
        var root: Node3D = Node3D.new()
        root.name = str(district["id"])
        var terrace_height: float = float(district.get("elevation_m", 0.0))
        root.position = district["position"] + Vector3(0.0, terrace_height, 0.0)
        district_root.add_child(root)
        var size_values: Array = district.get("size", [150, 140])
        var width_m: float = float(size_values[0])
        var depth_m: float = float(size_values[1])
        _box(root, "DistrictTerrace", Vector3(0, -terrace_height * 0.5, 0), Vector3(width_m, maxf(terrace_height, 0.1), depth_m), "#728b70", true)
        _box(root, "DistrictPlaza", Vector3(0, 0.022, 0), Vector3(width_m, 0.05, depth_m), "#8cac80", true)
        _build_district_ramp(root, terrace_height, depth_m)
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


func _build_district_ramp(district: Node3D, elevation: float, depth_m: float) -> void:
    if elevation <= 0.1:
        return
    # Accessible schematic approach from ground level on the positive-z edge.
    # The ramp is placed outside the terrace footprint to avoid buried geometry.
    var run_length: float = maxf(30.0, elevation * 10.0)
    var ramp: Node3D = Node3D.new()
    ramp.name = "DistrictPedestrianRamp"
    ramp.position = Vector3(0.0, -elevation * 0.5 + 0.12, depth_m * 0.5 + run_length * 0.5)
    ramp.rotation.x = atan2(elevation, run_length)
    district.add_child(ramp)
    _box(ramp, "SlopedWalkSurface", Vector3.ZERO,
        Vector3(4.2, 0.28, sqrt(run_length * run_length + elevation * elevation)),
        "#bfc4b4", true)
    # Connection between the terrace promenade and the top of the ramp.
    _box(district, "RampLanding", Vector3(0.0, 0.11, depth_m * 0.5 + 1.5),
        Vector3(4.6, 0.2, 3.0), "#bfc4b4", true)


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
