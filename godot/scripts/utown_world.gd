extends Node3D
class_name UTownWorld
## Procedural M1 greybox. Distances are metres; source lon/lat coordinates are approximate.
## All geometry is created by us: no third-party screenshots, 3D meshes or textures.

const DATA_PATH: String = "res://data/utown_core.json"
const METRES_PER_DEG_LAT: float = 110574.0
const METRES_PER_DEG_LON: float = 111320.0

var layout: Dictionary = {}
var origin_lat: float = 1.305075
var origin_lon: float = 103.77316
var route_points: Array[Vector3] = []
var route_names: PackedStringArray = []
var generated_building_count: int = 0
var generated_tree_count: int = 0
var generated_tree_positions: Array[Vector3] = []
var generated_path_count: int = 0

func _ready() -> void:
    if not FileAccess.file_exists(DATA_PATH):
        push_error("UTown layout JSON missing: " + DATA_PATH)
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("UTown layout JSON is invalid.")
        return
    layout = parsed
    var ref: Dictionary = layout.get("spatial_reference", {})
    origin_lat = float(ref.get("origin_lat", origin_lat))
    origin_lon = float(ref.get("origin_lon", origin_lon))
    _build_sky()
    _build_ground()
    _build_green()
    _build_plaza()
    _build_walkways()
    _build_buildings()
    _build_trees()
    _build_waypoints()

func lonlat_to_world(lon: float, lat: float) -> Vector3:
    var east: float = (lon - origin_lon) * METRES_PER_DEG_LON * cos(deg_to_rad(origin_lat))
    var north: float = (lat - origin_lat) * METRES_PER_DEG_LAT
    return Vector3(east, 0.0, -north)

func _mat(hex: String, rough: float = 0.9) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color.html(hex)
    material.roughness = rough
    return material

func _add_box(parent: Node3D, at: Vector3, size_m: Vector3, material: Material, solid: bool = false) -> Node3D:
    var part: Node3D = Node3D.new()
    part.position = at
    parent.add_child(part)
    var visible_mesh: MeshInstance3D = MeshInstance3D.new()
    var box: BoxMesh = BoxMesh.new()
    box.size = size_m
    visible_mesh.mesh = box
    visible_mesh.material_override = material
    part.add_child(visible_mesh)
    if solid:
        var body: StaticBody3D = StaticBody3D.new()
        part.add_child(body)
        var shape: CollisionShape3D = CollisionShape3D.new()
        var volume: BoxShape3D = BoxShape3D.new()
        volume.size = size_m
        shape.shape = volume
        body.add_child(shape)
    return part

func _build_sky() -> void:
    var env: Environment = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color.html("#c6d8df")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color.html("#e8edf0")
    env.ambient_light_energy = 0.78
    var environment_node: WorldEnvironment = WorldEnvironment.new()
    environment_node.environment = env
    add_child(environment_node)
    var sun: DirectionalLight3D = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-54.0, -38.0, 0.0)
    sun.light_energy = 1.0
    sun.shadow_enabled = true
    add_child(sun)

func _build_ground() -> void:
    var root: Node3D = Node3D.new()
    root.name = "Terrain"
    add_child(root)
    var extents: Array = layout.get("ground_size_m", [550, 720])
    _add_box(root, Vector3(0.0, -0.22, 0.0), Vector3(float(extents[0]), 0.44, float(extents[1])), _mat("#819e7a"), true)

func _build_green() -> void:
    var poly: PackedVector2Array = PackedVector2Array()
    var green: Dictionary = layout.get("green", {})
    for lonlat in green.get("polygon_lonlat", []):
        var p: Vector3 = lonlat_to_world(float(lonlat[0]), float(lonlat[1]))
        poly.append(Vector2(p.x, p.z))
    if poly.size() < 3:
        return
    var indices: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
    if indices.size() < 3:
        push_warning("Could not triangulate the Town Green polygon.")
        return
    var surface: SurfaceTool = SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in indices:
        surface.set_normal(Vector3.UP)
        surface.add_vertex(Vector3(poly[i].x, 0.025, poly[i].y))
    var grass: MeshInstance3D = MeshInstance3D.new()
    grass.name = "TownGreen_approximate"
    grass.mesh = surface.commit()
    var grass_mat: StandardMaterial3D = _mat("#8aba75")
    grass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    grass.material_override = grass_mat
    add_child(grass)

func _build_plaza() -> void:
    var plaza: Dictionary = layout.get("plaza", {})
    var at: Vector3 = lonlat_to_world(float(plaza.get("lon", origin_lon)), float(plaza.get("lat", origin_lat)))
    var root: Node3D = Node3D.new()
    root.name = "TownPlaza_approximate"
    root.position = at
    root.rotation.y = deg_to_rad(float(plaza.get("rotation_deg", 0.0)))
    add_child(root)
    _add_box(root, Vector3(0.0, 0.05, 0.0), Vector3(float(plaza.get("width_m", 44)), 0.09, float(plaza.get("depth_m", 30))), _mat("#b9bcb5"))
    for i in range(4):
        _add_box(root, Vector3(-16.0 + float(i) * 10.0, 2.4, -12.0), Vector3(0.8, 4.8, 0.8), _mat("#e8e8e3"))
    _add_box(root, Vector3(-1.0, 4.9, -12.0), Vector3(44.0, 0.45, 7.0), _mat("#b9c6cb"))

func _build_walkways() -> void:
    var root: Node3D = Node3D.new()
    root.name = "ConceptualFootpaths_NotSurveyed"
    add_child(root)
    var path_material: Material = _mat("#c8c7bd")
    for way in layout.get("walkways", []):
        var points: Array = way.get("lonlat", [])
        var width_m: float = float(way.get("width_m", 3.5))
        for i in range(points.size() - 1):
            var a: Vector3 = lonlat_to_world(float(points[i][0]), float(points[i][1]))
            var b: Vector3 = lonlat_to_world(float(points[i + 1][0]), float(points[i + 1][1]))
            var difference: Vector3 = b - a
            var length_m: float = difference.length()
            if length_m < 0.1:
                continue
            var segment: Node3D = _add_box(root, (a + b) * 0.5 + Vector3.UP * 0.058, Vector3(width_m, 0.11, length_m + 0.15), path_material)
            segment.rotation.y = atan2(difference.x, difference.z)
            generated_path_count += 1

func _building_color(role: String) -> StandardMaterial3D:
    match role:
        "academic":
            return _mat("#e3e5df")
        "civic":
            return _mat("#b3c4cc")
        "research":
            return _mat("#b9b5ac")
        "residence":
            return _mat("#d7c8ad")
    return _mat("#c8c8c8")

func _build_buildings() -> void:
    var root: Node3D = Node3D.new()
    root.name = "BuildingMassing_Estimated"
    add_child(root)
    var glass: Material = _mat("#688a9c", 0.34)
    var roof: Material = _mat("#dde0dc")
    var entrance: Material = _mat("#426675", 0.32)
    for record in layout.get("buildings", []):
        var group: Node3D = Node3D.new()
        group.name = str(record.get("id", "Building"))
        group.position = lonlat_to_world(float(record.get("lon", origin_lon)), float(record.get("lat", origin_lat)))
        group.rotation.y = deg_to_rad(float(record.get("rotation_deg", 0.0)))
        root.add_child(group)
        var wall: Material = _building_color(str(record.get("role", "")))
        var priority: String = str(record.get("priority", "P1"))
        var max_height: float = 0.0
        for piece in record.get("parts", []):
            var dx: float = float(piece.get("dx", 0.0))
            var north: float = float(piece.get("dn", 0.0))
            var w: float = float(piece.get("w", 24.0))
            var d: float = float(piece.get("d", 24.0))
            var h: float = float(piece.get("h", 15.0))
            max_height = maxf(max_height, h)
            var z: float = -north
            _add_box(group, Vector3(dx, h / 2.0, z), Vector3(w, h, d), wall, true)
            _add_box(group, Vector3(dx, h + 0.24, z), Vector3(w + 0.65, 0.48, d + 0.65), roof)
            var bands: int = mini(int(h / 3.6), 11)
            for floor_index in range(bands):
                var yf: float = 2.4 + 3.5 * float(floor_index)
                if yf + 0.7 >= h:
                    continue
                _add_box(group, Vector3(dx, yf, z + d * 0.5 + 0.053), Vector3(w * 0.88, 0.68, 0.11), glass)
            if priority == "P0":
                _add_box(group, Vector3(dx, 1.55, z + d * 0.5 + 0.095), Vector3(3.5, 3.1, 0.18), entrance)
        generated_building_count += 1
        _add_sign(group, str(record.get("name", group.name)), Vector3(0.0, max_height + 6.0, 0.0), "#fbfbf8")

func _add_sign(parent: Node3D, title: String, at: Vector3, color_hex: String) -> void:
    var sign: Label3D = Label3D.new()
    sign.text = title
    sign.font_size = 34
    sign.pixel_size = 0.025
    sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sign.no_depth_test = true
    sign.modulate = Color.html(color_hex)
    sign.outline_size = 5
    sign.position = at
    parent.add_child(sign)

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
    var segment: Vector2 = finish - start
    var length_squared: float = segment.length_squared()
    if length_squared < 0.0001:
        return point.distance_to(start)
    var t: float = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
    return point.distance_to(start + segment * t)

func is_tree_position_clear(position: Vector2, building_clearance_m: float = 8.0) -> bool:
    # Transform candidate into each building's local frame and test actual massing parts.
    for record in layout.get("buildings", []):
        var centre: Vector3 = lonlat_to_world(float(record["lon"]), float(record["lat"]))
        var relative: Vector2 = position - Vector2(centre.x, centre.z)
        var angle: float = deg_to_rad(float(record.get("rotation_deg", 0.0)))
        var c: float = cos(angle)
        var s: float = sin(angle)
        var local_position: Vector2 = Vector2(c * relative.x - s * relative.y, s * relative.x + c * relative.y)
        for piece in record.get("parts", []):
            var half_width: float = float(piece.get("w", 24.0)) * 0.5 + building_clearance_m
            var half_depth: float = float(piece.get("d", 24.0)) * 0.5 + building_clearance_m
            var part_x: float = float(piece.get("dx", 0.0))
            var part_z: float = -float(piece.get("dn", 0.0))
            if absf(local_position.x - part_x) <= half_width and absf(local_position.y - part_z) <= half_depth:
                return false

    # Keep generated trees outside the conceptual pedestrian corridor.
    for way in layout.get("walkways", []):
        var points: Array = way.get("lonlat", [])
        var path_clearance: float = float(way.get("width_m", 3.5)) * 0.5 + 2.0
        for i in range(points.size() - 1):
            var a: Vector3 = lonlat_to_world(float(points[i][0]), float(points[i][1]))
            var b: Vector3 = lonlat_to_world(float(points[i + 1][0]), float(points[i + 1][1]))
            if _distance_to_segment(position, Vector2(a.x, a.z), Vector2(b.x, b.z)) < path_clearance:
                return false
    return true

func _build_trees() -> void:
    var root: Node3D = Node3D.new()
    root.name = "Vegetation_Procedural"
    add_child(root)
    var woody: Material = _mat("#6e6455")
    var canopy: Material = _mat("#457c57")
    var trunk: CylinderMesh = CylinderMesh.new()
    trunk.top_radius = 0.28
    trunk.bottom_radius = 0.40
    trunk.height = 4.4
    var leaves: SphereMesh = SphereMesh.new()
    leaves.radius = 2.5
    leaves.height = 4.5
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 20261024
    var tree_positions: Array[Vector3] = []
    for _attempt in range(280):
        if tree_positions.size() >= 64:
            break
        var x: float = rng.randf_range(-190.0, 190.0)
        var z: float = rng.randf_range(-230.0, 230.0)
        if x * x + z * z < 900.0 or not is_tree_position_clear(Vector2(x, z)):
            continue
        tree_positions.append(Vector3(x, 0.0, z))

    # Two MultiMesh batches replace 128 individual MeshInstance3D nodes.
    var trunk_batch: MultiMesh = MultiMesh.new()
    trunk_batch.transform_format = MultiMesh.TRANSFORM_3D
    trunk_batch.mesh = trunk
    trunk_batch.instance_count = tree_positions.size()
    var canopy_batch: MultiMesh = MultiMesh.new()
    canopy_batch.transform_format = MultiMesh.TRANSFORM_3D
    canopy_batch.mesh = leaves
    canopy_batch.instance_count = tree_positions.size()
    generated_tree_positions = tree_positions.duplicate()

    var trunk_instances: MultiMeshInstance3D = MultiMeshInstance3D.new()
    trunk_instances.name = "TreeTrunks_MultiMesh"
    trunk_instances.multimesh = trunk_batch
    trunk_instances.material_override = woody
    root.add_child(trunk_instances)
    var canopy_instances: MultiMeshInstance3D = MultiMeshInstance3D.new()
    canopy_instances.name = "TreeCanopies_MultiMesh"
    canopy_instances.multimesh = canopy_batch
    canopy_instances.material_override = canopy
    root.add_child(canopy_instances)

    # Populate after the MultiMeshInstance3D nodes are attached to the scene tree.
    for i in range(tree_positions.size()):
        var base: Vector3 = tree_positions[i]
        trunk_instances.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, base + Vector3(0.0, 2.2, 0.0)))
        canopy_instances.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, base + Vector3(0.0, 6.2, 0.0)))
    generated_tree_count = tree_positions.size()

func _build_waypoints() -> void:
    var root: Node3D = Node3D.new()
    root.name = "RouteBeacons_Conceptual"
    add_child(root)
    var tint: Material = _mat("#e7ca75", 0.38)
    var ball: SphereMesh = SphereMesh.new()
    ball.radius = 0.7
    ball.height = 1.4
    for stop in layout.get("loop", []):
        var p: Vector3 = lonlat_to_world(float(stop["lon"]), float(stop["lat"]))
        route_points.append(p)
        route_names.append(str(stop["name"]))
        var marker: MeshInstance3D = MeshInstance3D.new()
        marker.mesh = ball
        marker.material_override = tint
        marker.position = p + Vector3(0.0, 0.9, 0.0)
        root.add_child(marker)
        _add_sign(root, str(stop["name"]), p + Vector3(0.0, 3.1, 0.0), "#fff4c4")

func nearest_landmark(position_m: Vector3) -> Dictionary:
    var answer: Dictionary = {"name": "Town Green", "distance": 0.0}
    var best: float = INF
    for record in layout.get("buildings", []):
        var p: Vector3 = lonlat_to_world(float(record["lon"]), float(record["lat"]))
        var distance_m: float = Vector2(position_m.x, position_m.z).distance_to(Vector2(p.x, p.z))
        if distance_m < best:
            best = distance_m
            answer = {"name": str(record["name"]), "distance": distance_m}
    if layout.has("green"):
        var g: Vector3 = lonlat_to_world(103.77312, 1.30504)
        var gd: float = Vector2(position_m.x, position_m.z).distance_to(Vector2(g.x, g.z))
        if gd < best:
            answer = {"name": "Town Green", "distance": gd}
    return answer
