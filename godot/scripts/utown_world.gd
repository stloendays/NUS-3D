extends Node3D
class_name UTownWorld
## Source-driven UTown M1 massing + provisional M2 architecture study. All GIS is approximate.
## All geometry is created by us: no third-party screenshots, 3D meshes or textures.

const DATA_PATH: String = "res://data/utown_core.json"
const M2_DATA_PATH: String = "res://data/m2_profiles.json"
const FACADE_KIT = preload("res://scripts/utown_facades.gd")
const OSM_KIT = preload("res://scripts/osm_reference.gd")
const COMIC_LAWN_PATH: String = "res://assets/materials/comic_lawn.svg"
const COMIC_PAVERS_PATH: String = "res://assets/materials/comic_pavers.svg"
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
var weather_reactive_materials: Array[StandardMaterial3D] = []
var weather_reactive_grass: Array[StandardMaterial3D] = []
var m2_profiles: Dictionary = {}
var m2_detail_nodes: Array[Node3D] = []
var generated_facade_count: int = 0
var m2_details_visible: bool = true
var osm_reference_layer: UTownOSMReference
var osm_reference_data: Dictionary = {}
var osm_reference_visible: bool = false
const LIGHTING_NAMES = ["Daylight", "Golden hour", "Blue hour", "Evening"]
var lighting_mode: int = 0
var sky_environment: Environment
var sunlight: DirectionalLight3D
var lamp_lights: Array[OmniLight3D] = []
var lamp_locations: Array[Vector2] = []
var generated_lamp_count: int = 0
var navigation_labels: Array[Label3D] = []
var route_marker_root: Node3D

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
    if FileAccess.file_exists(M2_DATA_PATH):
        var profile_json: Variant = JSON.parse_string(FileAccess.get_file_as_string(M2_DATA_PATH))
        if typeof(profile_json) == TYPE_DICTIONARY:
            var profile_document: Dictionary = profile_json
            m2_profiles = profile_document.get("profiles", {})
        else:
            push_warning("M2 architecture profiles are invalid; plain massing will remain.")
    _build_sky()
    _build_ground()
    _build_green()
    _build_plaza()
    _build_walkways()
    _build_buildings()
    _build_lamps()
    _build_trees()
    _build_waypoints()
    _build_osm_reference()
    set_lighting_mode(lighting_mode)

func lonlat_to_world(lon: float, lat: float) -> Vector3:
    var east: float = (lon - origin_lon) * METRES_PER_DEG_LON * cos(deg_to_rad(origin_lat))
    var north: float = (lat - origin_lat) * METRES_PER_DEG_LAT
    return Vector3(east, 0.0, -north)

func _mat(hex: String, rough: float = 0.9) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color.html(hex)
    material.roughness = rough
    return material

func _repeat_texture(material: StandardMaterial3D, texture_path: String, metres_per_tile: float) -> void:
    # World-space tiling on the rectangular terrain / path meshes, no stretched atlas.
    var texture: Texture2D = load(texture_path) as Texture2D
    if texture == null:
        push_warning("M3.7 tiling texture missing: " + texture_path)
        return
    material.albedo_texture = texture
    material.uv1_triplanar = true
    material.uv1_world_triplanar = true
    var repeats_per_metre: float = 1.0 / maxf(metres_per_tile, 0.5)
    material.uv1_scale = Vector3.ONE * repeats_per_metre

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
    sky_environment = env
    var sun: DirectionalLight3D = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-54.0, -38.0, 0.0)
    sun.light_energy = 1.0
    sun.shadow_enabled = true
    add_child(sun)
    sunlight = sun

func _build_ground() -> void:
    var root: Node3D = Node3D.new()
    root.name = "Terrain"
    add_child(root)
    var extents: Array = layout.get("ground_size_m", [550, 720])
    var terrain_material: StandardMaterial3D = _mat("#ecf7e8")
    _repeat_texture(terrain_material, COMIC_LAWN_PATH, 5.5)
    weather_reactive_grass.append(terrain_material)
    _add_box(root, Vector3(0.0, -0.22, 0.0), Vector3(float(extents[0]), 0.44, float(extents[1])), terrain_material, true)

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
        surface.set_uv(Vector2(poly[i].x / 5.5, poly[i].y / 5.5))
        surface.add_vertex(Vector3(poly[i].x, 0.025, poly[i].y))
    var grass: MeshInstance3D = MeshInstance3D.new()
    grass.name = "TownGreen_approximate"
    grass.mesh = surface.commit()
    var grass_mat: StandardMaterial3D = _mat("#effbea")
    grass_mat.albedo_texture = load(COMIC_LAWN_PATH) as Texture2D
    weather_reactive_grass.append(grass_mat)
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
    var plaza_surface: StandardMaterial3D = _mat("#eef3ec")
    _repeat_texture(plaza_surface, COMIC_PAVERS_PATH, 3.2)
    weather_reactive_materials.append(plaza_surface)
    _add_box(root, Vector3(0.0, 0.05, 0.0), Vector3(float(plaza.get("width_m", 44)), 0.09, float(plaza.get("depth_m", 30))), plaza_surface)
    for i in range(4):
        _add_box(root, Vector3(-16.0 + float(i) * 10.0, 2.4, -12.0), Vector3(0.8, 4.8, 0.8), _mat("#e8e8e3"))
    _add_box(root, Vector3(-1.0, 4.9, -12.0), Vector3(44.0, 0.45, 7.0), _mat("#b9c6cb"))

func _build_walkways() -> void:
    var root: Node3D = Node3D.new()
    root.name = "ConceptualFootpaths_NotSurveyed"
    add_child(root)
    var path_material: StandardMaterial3D = _mat("#eff5ed")
    _repeat_texture(path_material, COMIC_PAVERS_PATH, 3.0)
    weather_reactive_materials.append(path_material)
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
            return _mat("#c8d0cb")
        "civic":
            return _mat("#aabec2")
        "research":
            return _mat("#a9aaa0")
        "residence":
            return _mat("#c4b7a1")
    return _mat("#c8c8c8")

func _build_buildings() -> void:
    var root: Node3D = Node3D.new()
    root.name = "BuildingMassing_Estimated"
    add_child(root)
    var glass: Material = _mat("#688a9c", 0.34)
    var roof: Material = _mat("#bac6c5", 0.82)
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
        if priority == "P0" and m2_profiles.has(str(record.get("id", ""))):
            var profile: Dictionary = m2_profiles[str(record.get("id"))]
            var detail: Node3D = FACADE_KIT.build(group, record, profile)
            m2_detail_nodes.append(detail)
            generated_facade_count += 1
        generated_building_count += 1
        # Building identities belong in the minimap, not floating above roofs.

func _build_osm_reference() -> void:
    var overlay: UTownOSMReference = OSM_KIT.new()
    overlay.name = "OSMFootprints_ReferenceOnly"
    add_child(overlay)
    osm_reference_layer = overlay
    osm_reference_data = overlay.source_document

func set_osm_reference_visible(enabled: bool) -> void:
    osm_reference_visible = enabled
    if osm_reference_layer != null:
        osm_reference_layer.visible = enabled

func set_m2_details_visible(enabled: bool) -> void:
    m2_details_visible = enabled
    for detail in m2_detail_nodes:
        detail.visible = enabled

func set_navigation_markers_visible(_enabled: bool) -> void:
    # Keep the F7-compatible callable API but never reactivate removed overhead signs.
    if route_marker_root != null:
        route_marker_root.visible = false

func lighting_name() -> String:
    return str(LIGHTING_NAMES[lighting_mode])

func set_lighting_mode(index: int) -> bool:
    if index < 0 or index >= LIGHTING_NAMES.size() or sky_environment == null or sunlight == null:
        return false
    lighting_mode = index
    match lighting_mode:
        0: # Midday: reproduce the previous fixed lighting.
            sky_environment.background_color = Color.html("#c6d8df")
            sky_environment.ambient_light_color = Color.html("#e8edf0")
            sky_environment.ambient_light_energy = 0.78
            sunlight.rotation_degrees = Vector3(-54.0, -38.0, 0.0)
            sunlight.light_color = Color.WHITE
            sunlight.light_energy = 1.0
        1: # Warm late afternoon; not a simulated Singapore solar ephemeris.
            sky_environment.background_color = Color.html("#e5c4a9")
            sky_environment.ambient_light_color = Color.html("#ffddb3")
            sky_environment.ambient_light_energy = 0.74
            sunlight.rotation_degrees = Vector3(-22.0, -85.0, 0.0)
            sunlight.light_color = Color.html("#ffc286")
            sunlight.light_energy = 0.76
        2: # Blue hour, with a limited number of unshadowed decorative lamps.
            sky_environment.background_color = Color.html("#607e9c")
            sky_environment.ambient_light_color = Color.html("#a3b9d0")
            sky_environment.ambient_light_energy = 0.56
            sunlight.rotation_degrees = Vector3(-9.0, -138.0, 0.0)
            sunlight.light_color = Color.html("#e9bf9f")
            sunlight.light_energy = 0.32
        3: # Evening remains bright enough to navigate schematic flat ground.
            sky_environment.background_color = Color.html("#243951")
            sky_environment.ambient_light_color = Color.html("#96afce")
            sky_environment.ambient_light_energy = 0.43
            sunlight.rotation_degrees = Vector3(-5.0, -175.0, 0.0)
            sunlight.light_color = Color.html("#a0b6db")
            sunlight.light_energy = 0.14
    sunlight.shadow_enabled = lighting_mode <= 1
    for lamp in lamp_lights:
        lamp.visible = lighting_mode >= 2
        lamp.light_energy = 0.7 if lighting_mode == 2 else 1.1 if lighting_mode == 3 else 0.0
    return true

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F2:
            set_m2_details_visible(not m2_details_visible)
        elif event.keycode == KEY_F6:
            set_osm_reference_visible(not osm_reference_visible)
        elif event.keycode == KEY_T:
            set_lighting_mode((lighting_mode + 1) % LIGHTING_NAMES.size())

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
    # Keep procedurally placed tree canopies and lamp posts from occupying one point.
    for lamp in lamp_locations:
        if lamp.distance_to(position) < 6.0:
            return false
    return true

func _build_lamps() -> void:
    # Schematic low-cost decorative wayfinding lamps, not surveyed fixture positions.
    var root: Node3D = Node3D.new()
    root.name = "PathLanterns_Artistic_NotSurveyed"
    add_child(root)
    var pole_material: Material = _mat("#435760", 0.58)
    var fixture_material: StandardMaterial3D = _mat("#e7dac0", 0.24)
    fixture_material.emission_enabled = true
    fixture_material.emission = Color.html("#dcae66")
    fixture_material.emission_energy_multiplier = 1.2
    for walkway in layout.get("walkways", []):
        var points: Array = walkway.get("lonlat", [])
        for segment_index in range(points.size() - 1):
            if generated_lamp_count >= 10:
                break
            var a: Vector3 = lonlat_to_world(float(points[segment_index][0]), float(points[segment_index][1]))
            var b: Vector3 = lonlat_to_world(float(points[segment_index + 1][0]), float(points[segment_index + 1][1]))
            var direction: Vector2 = Vector2(b.x - a.x, b.z - a.z)
            if direction.length_squared() < 16.0:
                continue
            var sideways: Vector2 = Vector2(-direction.y, direction.x).normalized()
            var centre: Vector2 = Vector2((a.x + b.x) * 0.5, (a.z + b.z) * 0.5)
            var offset: float = float(walkway.get("width_m", 3.5)) * 0.5 + 5.0
            var candidate: Vector2 = centre + sideways * offset
            if not is_tree_position_clear(candidate, 4.0):
                continue
            _add_box(root, Vector3(candidate.x, 2.2, candidate.y), Vector3(0.16, 4.4, 0.16), pole_material)
            _add_box(root, Vector3(candidate.x, 4.45, candidate.y), Vector3(0.88, 0.28, 0.88), fixture_material)
            var light: OmniLight3D = OmniLight3D.new()
            light.name = "SoftLamp_%02d" % generated_lamp_count
            light.position = Vector3(candidate.x, 4.36, candidate.y)
            light.omni_range = 17.0
            light.light_color = Color.html("#ffe0a6")
            light.light_energy = 0.0
            light.shadow_enabled = false
            light.visible = false
            root.add_child(light)
            lamp_lights.append(light)
            lamp_locations.append(candidate)
            generated_lamp_count += 1

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
        var trunk_transform: Transform3D = Transform3D(Basis(), base + Vector3(0.0, 2.2, 0.0))
        var canopy_transform: Transform3D = Transform3D(Basis(), base + Vector3(0.0, 6.2, 0.0))
        trunk_batch.set_instance_transform(i, trunk_transform)
        canopy_batch.set_instance_transform(i, canopy_transform)

    generated_tree_count = tree_positions.size()

func _build_waypoints() -> void:
    var root: Node3D = Node3D.new()
    root.name = "RouteBeacons_Conceptual"
    add_child(root)
    route_marker_root = root
    # Keep all four logical waypoints for the map, tour, shuttle and gameplay.
    # Do not add world-space spheres, labels or signposts.
    for stop in layout.get("loop", []):
        var p: Vector3 = lonlat_to_world(float(stop["lon"]), float(stop["lat"]))
        route_points.append(p)
        route_names.append(str(stop["name"]))
    root.visible = false

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
