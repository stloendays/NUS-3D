extends Node3D
class_name UTownWorld
## Source-driven UTown M1 massing + provisional M2 architecture study. All GIS is approximate.
## All geometry is created by us: no third-party screenshots, 3D meshes or textures.

const DATA_PATH: String = "res://data/utown_core.json"
const M2_DATA_PATH: String = "res://data/m2_profiles.json"
const OSM_DATA_PATH: String = "res://data/osm_utown_snapshot.json"
const OSM_SHELL_PROFILE_PATH: String = "res://data/osm_shell_profiles.json"
const CAMPUS_LIFE_PATH: String = "res://data/campus_life.json"
const FACADE_KIT = preload("res://scripts/utown_facades.gd")
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
var m2_profiles: Dictionary = {}
var osm_shell_profiles: Dictionary = {}
var campus_life_data: Dictionary = {}
var building_massing_root: Node3D
var osm_shell_root: Node3D
var osm_shell_count: int = 0
var osm_shell_way_ids: Array[int] = []
var osm_shells_visible: bool = false
var m2_detail_nodes: Array[Node3D] = []
var generated_facade_count: int = 0
var m2_details_visible: bool = true
var environment_data: Environment
var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var window_material: StandardMaterial3D
var lamp_lights: Array[OmniLight3D] = []
var night_mode: bool = false
var generated_bench_count: int = 0
var generated_lamp_count: int = 0
var generated_guide_count: int = 0
var campus_furniture_positions: Array[Vector3] = []
var discovered_landmarks: Array[String] = []
var discovery_feedback: String = ""
var discovery_feedback_time: float = 0.0

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
    if FileAccess.file_exists(OSM_SHELL_PROFILE_PATH):
        var shell_profile_json: Variant = JSON.parse_string(FileAccess.get_file_as_string(OSM_SHELL_PROFILE_PATH))
        if typeof(shell_profile_json) == TYPE_DICTIONARY:
            var shell_profile_document: Dictionary = shell_profile_json
            osm_shell_profiles = shell_profile_document.get("buildings", {})
        else:
            push_warning("OSM shell profiles are invalid; estimated massing remains active.")
    if FileAccess.file_exists(CAMPUS_LIFE_PATH):
        var campus_life_json: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMPUS_LIFE_PATH))
        if typeof(campus_life_json) == TYPE_DICTIONARY:
            campus_life_data = campus_life_json
        else:
            push_warning("Campus-life data is invalid; furniture and discovery content remain disabled.")
    _build_sky()
    _build_ground()
    _build_green()
    _build_plaza()
    _build_walkways()
    _build_buildings()
    _build_osm_shells()
    _build_trees()
    _build_campus_furniture()
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
    environment_data = Environment.new()
    environment_data.background_mode = Environment.BG_COLOR
    environment_data.background_color = Color.html("#c6d8df")
    environment_data.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment_data.ambient_light_color = Color.html("#e8edf0")
    environment_data.ambient_light_energy = 0.54
    environment_data.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world_environment = WorldEnvironment.new()
    world_environment.environment = environment_data
    add_child(world_environment)
    sun_light = DirectionalLight3D.new()
    sun_light.name = "Sun_Daylight"
    sun_light.rotation_degrees = Vector3(-54.0, -38.0, 0.0)
    sun_light.light_color = Color.html("#fff0d5")
    sun_light.light_energy = 0.68
    sun_light.shadow_enabled = true
    add_child(sun_light)

func set_night_mode(enabled: bool) -> void:
    night_mode = enabled
    if environment_data != null:
        environment_data.background_color = Color.html("#101a2c") if enabled else Color.html("#c6d8df")
        environment_data.ambient_light_color = Color.html("#7187a8") if enabled else Color.html("#e8edf0")
        environment_data.ambient_light_energy = 0.30 if enabled else 0.54
    if sun_light != null:
        sun_light.visible = not enabled
    if window_material != null:
        window_material.emission_enabled = true
        window_material.emission = Color.html("#f5c982") if enabled else Color.html("#78919a")
        window_material.emission_energy_multiplier = 0.62 if enabled else 0.02
    for lamp in lamp_lights:
        lamp.visible = enabled

func _build_ground() -> void:
    var root: Node3D = Node3D.new()
    root.name = "Terrain"
    add_child(root)
    var extents: Array = layout.get("ground_size_m", [550, 720])
    var ground_material: StandardMaterial3D = _mat("#ffffff", 1.0)
    ground_material.albedo_texture = _make_grass_texture()
    ground_material.uv1_scale = Vector3(56.0, 1.0, 80.0)
    _add_box(root, Vector3(0.0, -0.22, 0.0), Vector3(float(extents[0]), 0.44, float(extents[1])), ground_material, true)

func _make_grass_texture() -> ImageTexture:
    var image: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 20261111
    for y in range(128):
        for x in range(128):
            var noise: float = rng.randf_range(-0.035, 0.035)
            var blade: float = 0.02 if rng.randf() > 0.985 else 0.0
            image.set_pixel(x, y, Color(
                clampf(0.25 + noise + blade, 0.0, 1.0),
                clampf(0.34 + noise * 1.1 + blade, 0.0, 1.0),
                clampf(0.20 + noise * 0.7, 0.0, 1.0),
                1.0
            ))
    return ImageTexture.create_from_image(image)

func _make_paver_texture() -> ImageTexture:
    var image: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 20261112
    for y in range(128):
        for x in range(128):
            var row: int = int(y / 32)
            var staggered_x: int = (x + (16 if row % 2 == 1 else 0)) % 32
            var grout: bool = (y % 32 < 2) or (staggered_x < 2)
            var noise: float = rng.randf_range(-0.035, 0.035)
            var base: float = 0.25 if grout else 0.48 + noise
            image.set_pixel(x, y, Color(base, base * 0.99, base * 0.94, 1.0))
    return ImageTexture.create_from_image(image)

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
        surface.set_uv(Vector2(poly[i].x * 0.055, poly[i].y * 0.055))
        surface.add_vertex(Vector3(poly[i].x, 0.025, poly[i].y))
    var grass: MeshInstance3D = MeshInstance3D.new()
    grass.name = "TownGreen_approximate"
    grass.mesh = surface.commit()
    var grass_mat: StandardMaterial3D = _mat("#ffffff", 1.0)
    grass_mat.albedo_texture = _make_grass_texture()
    grass_mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
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
    var path_material: StandardMaterial3D = _mat("#ffffff", 0.92)
    path_material.albedo_texture = _make_paver_texture()
    path_material.uv1_scale = Vector3(5.0, 1.0, 8.0)
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
    building_massing_root = Node3D.new()
    building_massing_root.name = "BuildingMassing_Estimated"
    add_child(building_massing_root)
    var root: Node3D = building_massing_root
    window_material = _mat("#688a9c", 0.34)
    window_material.emission_enabled = true
    window_material.emission = Color.html("#78919a")
    window_material.emission_energy_multiplier = 0.035
    var glass: Material = window_material
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
        if priority == "P0" and m2_profiles.has(str(record.get("id", ""))):
            var profile: Dictionary = m2_profiles[str(record.get("id"))]
            var detail: Node3D = FACADE_KIT.build(group, record, profile)
            m2_detail_nodes.append(detail)
            generated_facade_count += 1
        generated_building_count += 1
        _add_sign(group, str(record.get("name", group.name)), Vector3(0.0, max_height + 6.0, 0.0), "#fbfbf8")

func _extrude_footprint(points: PackedVector2Array, height_m: float, side_material: Material, roof_material: Material) -> ArrayMesh:
    if points.size() < 3 or height_m <= 0.0:
        return null
    var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(points)
    if triangles.size() < 3:
        return null

    var signed_area: float = 0.0
    for index in range(points.size()):
        var a: Vector2 = points[index]
        var b: Vector2 = points[(index + 1) % points.size()]
        signed_area += a.x * b.y - b.x * a.y
    if absf(signed_area) < 0.01:
        return null
    var winding: float = 1.0 if signed_area > 0.0 else -1.0

    var mesh: ArrayMesh = ArrayMesh.new()
    var walls: SurfaceTool = SurfaceTool.new()
    walls.begin(Mesh.PRIMITIVE_TRIANGLES)
    walls.set_material(side_material)
    for index in range(points.size()):
        var a: Vector2 = points[index]
        var b: Vector2 = points[(index + 1) % points.size()]
        var edge: Vector2 = b - a
        if edge.length_squared() < 0.000001:
            continue
        var normal: Vector3 = Vector3(edge.y * winding, 0.0, -edge.x * winding).normalized()
        walls.set_normal(normal)
        walls.add_vertex(Vector3(a.x, 0.0, a.y))
        walls.set_normal(normal)
        walls.add_vertex(Vector3(b.x, 0.0, b.y))
        walls.set_normal(normal)
        walls.add_vertex(Vector3(b.x, height_m, b.y))
        walls.set_normal(normal)
        walls.add_vertex(Vector3(a.x, 0.0, a.y))
        walls.set_normal(normal)
        walls.add_vertex(Vector3(b.x, height_m, b.y))
        walls.set_normal(normal)
        walls.add_vertex(Vector3(a.x, height_m, a.y))
    walls.commit(mesh)

    var roof: SurfaceTool = SurfaceTool.new()
    roof.begin(Mesh.PRIMITIVE_TRIANGLES)
    roof.set_material(roof_material)
    for index in range(0, triangles.size(), 3):
        for vertex_index in [triangles[index], triangles[index + 1], triangles[index + 2]]:
            var point: Vector2 = points[vertex_index]
            roof.set_normal(Vector3.UP)
            roof.add_vertex(Vector3(point.x, height_m, point.y))
    roof.commit(mesh)
    return mesh

func _build_osm_shells() -> void:
    if osm_shell_profiles.is_empty():
        push_warning("No OSM shell profiles; estimated building massing remains active.")
        return
    if not FileAccess.file_exists(OSM_DATA_PATH):
        push_warning("OSM footprint snapshot missing; estimated building massing remains active.")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OSM_DATA_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("OSM footprint snapshot is invalid; estimated building massing remains active.")
        return

    var osm_document: Dictionary = parsed
    var feature_by_id: Dictionary = {}
    for feature in osm_document.get("features", []):
        if typeof(feature) == TYPE_DICTIONARY:
            feature_by_id[int(feature.get("osm_id", -1))] = feature

    osm_shell_root = Node3D.new()
    osm_shell_root.name = "OSMBuildingShells_Estimated"
    osm_shell_root.visible = false
    add_child(osm_shell_root)

    for building_id in ["ERC", "SRC"]:
        var profile: Dictionary = osm_shell_profiles.get(building_id, {})
        if profile.is_empty():
            push_warning("OSM shell profile missing for " + building_id)
            continue
        var way_id: int = int(profile.get("osm_way_id", -1))
        var feature: Dictionary = feature_by_id.get(way_id, {})
        if feature.is_empty() or str(feature.get("geometry_status", "")) != "complete":
            push_warning("Complete OSM footprint missing for %s (way %d)" % [building_id, way_id])
            continue
        if str(feature.get("geometry_type", "")) != "Polygon":
            push_warning("OSM shell source is not a Polygon for " + building_id)
            continue

        var coordinates: Array = feature.get("coordinates", [])
        var point_count: int = coordinates.size()
        if point_count >= 4:
            var first_pair: Array = coordinates[0]
            var last_pair: Array = coordinates[point_count - 1]
            if absf(float(first_pair[0]) - float(last_pair[0])) < 0.0000001 and absf(float(first_pair[1]) - float(last_pair[1])) < 0.0000001:
                point_count -= 1
        if point_count < 3:
            push_warning("OSM footprint has too few unique vertices for " + building_id)
            continue

        var site_points: PackedVector2Array = PackedVector2Array()
        var centre: Vector2 = Vector2.ZERO
        for index in range(point_count):
            var pair: Array = coordinates[index]
            var site: Vector3 = lonlat_to_world(float(pair[0]), float(pair[1]))
            var point: Vector2 = Vector2(site.x, site.z)
            site_points.append(point)
            centre += point
        centre /= float(site_points.size())

        var local_points: PackedVector2Array = PackedVector2Array()
        for point in site_points:
            local_points.append(point - centre)

        var height_m: float = float(profile.get("height_m", 0.0))
        var side_material: StandardMaterial3D = _mat(str(profile.get("side_color", "#78949d")), 0.72)
        side_material.cull_mode = BaseMaterial3D.CULL_DISABLED
        var roof_material: StandardMaterial3D = _mat(str(profile.get("roof_color", "#d7dfdc")), 0.86)
        roof_material.cull_mode = BaseMaterial3D.CULL_DISABLED
        var mesh: ArrayMesh = _extrude_footprint(local_points, height_m, side_material, roof_material)
        if mesh == null or mesh.get_surface_count() != 2:
            push_warning("OSM footprint triangulation failed for " + building_id)
            continue

        var shell: MeshInstance3D = MeshInstance3D.new()
        shell.name = building_id + "_OSMFootprintShell_NotSurveyed"
        shell.mesh = mesh
        shell.position = Vector3(centre.x, 0.0, centre.y)
        shell.set_meta("osm_way_id", way_id)
        shell.set_meta("osm_timestamp", str(feature.get("timestamp", "")))
        shell.set_meta("osm_levels", int(profile.get("osm_levels", 0)))
        shell.set_meta("estimated_height_m", height_m)
        shell.set_meta("height_confidence", str(profile.get("height_confidence", "estimated")))
        shell.set_meta("osm_layer_tag", str(profile.get("osm_layer_tag", "")))
        osm_shell_root.add_child(shell)
        osm_shell_way_ids.append(way_id)
        osm_shell_count += 1

func set_osm_shells_visible(enabled: bool) -> void:
    osm_shells_visible = enabled
    if osm_shell_root != null:
        osm_shell_root.visible = enabled
    if building_massing_root != null:
        building_massing_root.visible = not enabled
    for detail in m2_detail_nodes:
        detail.visible = m2_details_visible and not enabled

func set_m2_details_visible(enabled: bool) -> void:
    m2_details_visible = enabled
    for detail in m2_detail_nodes:
        detail.visible = enabled and not osm_shells_visible

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
        set_m2_details_visible(not m2_details_visible)

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
    leaves.radial_segments = 12
    leaves.rings = 8
    trunk.radial_segments = 9
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
        var scale: float = rng.randf_range(0.78, 1.24)
        var rotation: float = rng.randf_range(0.0, TAU)
        var trunk_basis: Basis = Basis(Vector3.UP, rotation).scaled(Vector3(scale * 0.9, scale, scale * 0.9))
        var canopy_basis: Basis = Basis(Vector3.UP, rotation).scaled(Vector3(scale, scale, scale))
        var trunk_transform: Transform3D = Transform3D(trunk_basis, base + Vector3(0.0, 2.2 * scale, 0.0))
        var canopy_transform: Transform3D = Transform3D(canopy_basis, base + Vector3(0.0, 6.2 * scale, 0.0))
        trunk_batch.set_instance_transform(i, trunk_transform)
        canopy_batch.set_instance_transform(i, canopy_transform)

    generated_tree_count = tree_positions.size()

func _green_polygon_world() -> PackedVector2Array:
    var polygon: PackedVector2Array = PackedVector2Array()
    var green: Dictionary = layout.get("green", {})
    for lonlat in green.get("polygon_lonlat", []):
        var point: Vector3 = lonlat_to_world(float(lonlat[0]), float(lonlat[1]))
        polygon.append(Vector2(point.x, point.z))
    return polygon

func _is_valid_campus_prop_position(position: Vector3) -> bool:
    var polygon: PackedVector2Array = _green_polygon_world()
    if polygon.size() < 3 or not Geometry2D.is_point_in_polygon(Vector2(position.x, position.z), polygon):
        return false
    return is_tree_position_clear(Vector2(position.x, position.z), 2.5)

func _add_cylinder(parent: Node3D, title: String, at: Vector3, radius: float, height: float, material: Material, sides: int = 12) -> MeshInstance3D:
    var instance: MeshInstance3D = MeshInstance3D.new()
    instance.name = title
    var cylinder: CylinderMesh = CylinderMesh.new()
    cylinder.top_radius = radius
    cylinder.bottom_radius = radius
    cylinder.height = height
    cylinder.radial_segments = sides
    instance.mesh = cylinder
    instance.material_override = material
    instance.position = at
    parent.add_child(instance)
    return instance

func _build_bench(parent: Node3D, at: Vector3, yaw_deg: float, title: String) -> void:
    var bench: Node3D = Node3D.new()
    bench.name = title
    bench.position = at
    bench.rotation.y = deg_to_rad(yaw_deg)
    parent.add_child(bench)
    var timber: Material = _mat("#96704d", 0.82)
    var metal: StandardMaterial3D = _mat("#394b4e", 0.62)
    metal.metallic = 0.35
    for slat in range(4):
        _add_box(bench, Vector3(0.0, 0.49, -0.23 + float(slat) * 0.15),
            Vector3(2.15, 0.075, 0.12), timber)
    for slat in range(3):
        _add_box(bench, Vector3(0.0, 0.72 + float(slat) * 0.16, -0.30),
            Vector3(2.15, 0.12, 0.075), timber)
    for side in [-1.0, 1.0]:
        _add_box(bench, Vector3(side * 0.82, 0.25, -0.02), Vector3(0.09, 0.48, 0.09), metal)
        _add_box(bench, Vector3(side * 0.82, 0.69, -0.29), Vector3(0.09, 0.88, 0.09), metal)
        _add_box(bench, Vector3(side * 0.82, 0.91, -0.02), Vector3(0.09, 0.08, 0.60), metal)
    generated_bench_count += 1

func _build_lamp(parent: Node3D, at: Vector3, title: String) -> void:
    var lamp: Node3D = Node3D.new()
    lamp.name = title
    lamp.position = at
    parent.add_child(lamp)
    var metal: StandardMaterial3D = _mat("#4a5553", 0.48)
    metal.metallic = 0.55
    var diffuser: StandardMaterial3D = _mat("#f5dca9", 0.34)
    diffuser.emission_enabled = true
    diffuser.emission = Color.html("#f5dca9")
    diffuser.emission_energy_multiplier = 1.4
    _add_cylinder(lamp, "Pole", Vector3(0.0, 2.05, 0.0), 0.075, 4.1, metal, 10)
    _add_cylinder(lamp, "LightHead", Vector3(0.0, 4.12, 0.0), 0.22, 0.18, diffuser, 12)
    var light: OmniLight3D = OmniLight3D.new()
    light.name = "WarmLamp"
    light.position = Vector3(0.0, 4.0, 0.0)
    light.light_color = Color.html("#ffdca8")
    light.light_energy = 1.8
    light.omni_range = 16.0
    light.shadow_enabled = false
    light.visible = night_mode
    lamp.add_child(light)
    lamp_lights.append(light)
    generated_lamp_count += 1

func _build_guide(parent: Node3D, at: Vector3, yaw_deg: float, title: String) -> void:
    var guide: Node3D = Node3D.new()
    guide.name = title
    guide.position = at
    guide.rotation.y = deg_to_rad(yaw_deg)
    parent.add_child(guide)
    var dark_metal: StandardMaterial3D = _mat("#43575b", 0.48)
    dark_metal.metallic = 0.42
    var panel: Material = _mat("#e7e5d8", 0.82)
    _add_box(guide, Vector3(0.0, 1.0, 0.0), Vector3(0.12, 2.0, 0.12), dark_metal)
    _add_box(guide, Vector3(0.0, 2.02, 0.0), Vector3(1.45, 1.12, 0.14), panel)
    var sign_lines: Array[Dictionary] = [
        {"text": "UTOWN", "font_size": 30, "y": 2.31},
        {"text": "CAMPUS GUIDE", "font_size": 20, "y": 2.02},
        {"text": "ERC  ·  SRC  ·  GREEN", "font_size": 14, "y": 1.75}
    ]
    for index in range(sign_lines.size()):
        var line: Dictionary = sign_lines[index]
        var label: Label3D = Label3D.new()
        label.name = "CampusGuideText_%02d" % index
        label.text = str(line["text"])
        label.font_size = int(line["font_size"])
        label.pixel_size = 0.007
        label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.modulate = Color.html("#263b40")
        label.outline_size = 3
        label.rotation.y = PI
        label.position = Vector3(0.0, float(line["y"]), 0.076)
        guide.add_child(label)
    generated_guide_count += 1

func _build_campus_furniture() -> void:
    if campus_life_data.is_empty():
        return
    var root: Node3D = Node3D.new()
    root.name = "CampusFurniture_Illustrative"
    add_child(root)
    for item in campus_life_data.get("furniture", []):
        var position: Vector3 = lonlat_to_world(float(item.get("lon", origin_lon)), float(item.get("lat", origin_lat)))
        if not _is_valid_campus_prop_position(position):
            push_warning("Skipping campus prop outside the safe Town Green placement area: " + str(item.get("id", "")))
            continue
        campus_furniture_positions.append(position)
        var item_id: String = str(item.get("id", "CampusProp"))
        match str(item.get("type", "")):
            "bench":
                _build_bench(root, position, float(item.get("yaw_deg", 0.0)), item_id)
            "lamp":
                _build_lamp(root, position, item_id)
            "guide":
                _build_guide(root, position, float(item.get("yaw_deg", 0.0)), item_id)
    set_night_mode(night_mode)

func _process(delta: float) -> void:
    if discovery_feedback_time > 0.0:
        discovery_feedback_time = maxf(0.0, discovery_feedback_time - delta)

func nearby_discovery(position_m: Vector3, max_distance_m: float = 7.0) -> Dictionary:
    var closest: Dictionary = {}
    var best_distance: float = max_distance_m
    for item in campus_life_data.get("discoveries", []):
        var target: Vector3 = lonlat_to_world(float(item.get("lon", origin_lon)), float(item.get("lat", origin_lat)))
        var distance_m: float = Vector2(position_m.x, position_m.z).distance_to(Vector2(target.x, target.z))
        if distance_m <= best_distance:
            best_distance = distance_m
            closest = item.duplicate(true)
            closest["distance_m"] = distance_m
            closest["discovered"] = discovered_landmarks.has(str(item.get("id", "")))
    return closest

func discover_nearby_landmark(position_m: Vector3, max_distance_m: float = 7.0) -> Dictionary:
    var item: Dictionary = nearby_discovery(position_m, max_distance_m)
    if item.is_empty():
        discovery_feedback = "Move closer to a campus landmark to explore it."
        discovery_feedback_time = 3.0
        return {"ok": false, "message": discovery_feedback}
    var discovery_id: String = str(item.get("id", ""))
    var already_discovered: bool = discovered_landmarks.has(discovery_id)
    if not already_discovered:
        discovered_landmarks.append(discovery_id)
    var message: String = str(item.get("title", item.get("name", "Campus landmark"))) + "\n" + str(item.get("description", ""))
    if already_discovered:
        message = "Already explored\n" + message
    elif discovered_landmarks.size() == campus_life_data.get("discoveries", []).size():
        message += "\n\nCampus passport complete — all four UTown places explored."
    else:
        message += "\n\nCampus passport: %d / %d places explored." % [
            discovered_landmarks.size(), campus_life_data.get("discoveries", []).size()
        ]
    discovery_feedback = message
    discovery_feedback_time = 8.0
    return {"ok": true, "already_discovered": already_discovered, "id": discovery_id, "message": message}

func _build_waypoints() -> void:
    var root: Node3D = Node3D.new()
    root.name = "RouteBeacons_Conceptual"
    add_child(root)
    var tint: Material = _mat("#e7ca75", 0.38)
    var ball: SphereMesh = SphereMesh.new()
    ball.radius = 0.36
    ball.height = 0.72
    for stop in layout.get("loop", []):
        var p: Vector3 = lonlat_to_world(float(stop["lon"]), float(stop["lat"]))
        route_points.append(p)
        route_names.append(str(stop["name"]))
        var marker: MeshInstance3D = MeshInstance3D.new()
        marker.mesh = ball
        marker.material_override = tint
        marker.position = p + Vector3(0.0, 0.42, 0.0)
        root.add_child(marker)
        _add_sign(root, str(stop["name"]), p + Vector3(0.0, 3.1, 0.0), "#fff4c4")

func nearest_landmark(position_m: Vector3) -> Dictionary:
    var answer: Dictionary = {"id": "TOWN_GREEN", "name": "Town Green", "role": "open_space", "distance": INF}
    var best: float = INF
    for record in layout.get("buildings", []):
        var p: Vector3 = lonlat_to_world(float(record["lon"]), float(record["lat"]))
        var distance_m: float = Vector2(position_m.x, position_m.z).distance_to(Vector2(p.x, p.z))
        if distance_m < best:
            best = distance_m
            answer = {"id": str(record.get("id", "")), "name": str(record.get("name", record.get("id", "Building"))), "role": str(record.get("role", "campus")), "priority": str(record.get("priority", "P1")), "distance": distance_m}
    if layout.has("green"):
        var g: Vector3 = lonlat_to_world(103.77312, 1.30504)
        var gd: float = Vector2(position_m.x, position_m.z).distance_to(Vector2(g.x, g.z))
        if gd < best:
            best = gd
            answer = {"id": "TOWN_GREEN", "name": "Town Green", "role": "open_space", "distance": gd}
    if layout.has("plaza"):
        var plaza: Dictionary = layout["plaza"]
        var p: Vector3 = lonlat_to_world(float(plaza.get("lon", origin_lon)), float(plaza.get("lat", origin_lat)))
        var pd: float = Vector2(position_m.x, position_m.z).distance_to(Vector2(p.x, p.z))
        if pd < best:
            answer = {"id": str(plaza.get("id", "TOWN_PLAZA")), "name": str(plaza.get("name", "Town Plaza")), "role": "public_space", "priority": "P0", "distance": pd}
    return answer
