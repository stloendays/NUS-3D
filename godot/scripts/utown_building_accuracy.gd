extends Node3D
class_name UTownBuildingAccuracy
## Building-accuracy study: source-derived OSM perimeter silhouettes for ERC/SRC,
## plus visibly correct storey counts for CREATE and UTown Residence towers.
## Geometry is illustrative and NON-COLLIDING; the original walkable game
## collision proxies, official-map disclaimer and F2 comparison remain intact.
## OSM source: res://data/osm_p0_reference.json (© OSM contributors, ODbL 1.0).

const P0_BUILDINGS: PackedStringArray = PackedStringArray(["ERC", "SRC"])
const HIGHRISE_BUILDINGS: PackedStringArray = PackedStringArray(["CREATE_TOWER", "UTR_N", "UTR_S"])
const MAX_PERIMETER_EDGES: int = 150
const MAX_WINDOWS_PER_TOWER: int = 1200

@onready var world: UTownWorld = $"../World"

var p0_studies: Dictionary = {}
var tower_studies: Dictionary = {}
var shared_box_meshes: Dictionary = {}
var shared_materials: Dictionary = {}
var osm_edge_count: int = 0
var total_windows: int = 0

func _ready() -> void:
    for identifier in P0_BUILDINGS:
        _build_osm_derived_envelope(identifier)
    for identifier in HIGHRISE_BUILDINGS:
        _build_highrise_details(identifier)

func _find_record(identifier: String) -> Dictionary:
    for record in world.layout.get("buildings", []):
        if str(record.get("id", "")) == identifier:
            return record
    return {}

func _find_osm(identifier: String) -> Dictionary:
    for feature in world.osm_reference_data.get("features", []):
        if str(feature.get("id", "")) == identifier:
            return feature
    return {}

func _material(key: String, hex_color: String, metallic: float = 0.0) -> StandardMaterial3D:
    if not shared_materials.has(key):
        var material := StandardMaterial3D.new()
        material.albedo_color = Color.html(hex_color)
        material.roughness = 0.35 if metallic > 0.0 else 0.55
        material.metallic = metallic
        material.cull_mode = BaseMaterial3D.CULL_DISABLED
        shared_materials[key] = material
    return shared_materials[key]

func _box_mesh(size: Vector3) -> BoxMesh:
    var key: String = str(size)
    if not shared_box_meshes.has(key):
        var mesh := BoxMesh.new()
        mesh.size = size
        shared_box_meshes[key] = mesh
    return shared_box_meshes[key]

func _box(parent: Node3D, title: String, position: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = title
    item.mesh = _box_mesh(size)
    item.position = position
    item.material_override = mat
    item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(item)
    return item

func _append_vertical_quad(tool: SurfaceTool, a: Vector3, b: Vector3, lower: float, upper: float) -> void:
    if upper <= lower:
        return
    var tangent: Vector3 = b - a
    if tangent.length_squared() < 0.04:
        return
    var normal := Vector3(tangent.z, 0.0, -tangent.x).normalized()
    var low_a := Vector3(a.x, lower, a.z)
    var low_b := Vector3(b.x, lower, b.z)
    var high_a := Vector3(a.x, upper, a.z)
    var high_b := Vector3(b.x, upper, b.z)
    for vertex in [low_a, low_b, high_b, low_a, high_b, high_a]:
        tool.set_normal(normal)
        tool.add_vertex(vertex)

func _finish_surface(parent: Node3D, title: String, tool: SurfaceTool, mat: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = title
    node.mesh = tool.commit()
    node.material_override = mat
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(node)
    return node

func _build_osm_derived_envelope(identifier: String) -> void:
    var osm: Dictionary = _find_osm(identifier)
    var record: Dictionary = _find_record(identifier)
    var building: Node3D = world.get_node_or_null("BuildingMassing_Estimated/" + identifier) as Node3D
    if building == null or osm.is_empty() or record.is_empty():
        push_warning("No reference envelope for " + identifier)
        return
    var m2_layer: Node3D = building.get_node_or_null("ArchitecturalStudy_NotSurveyed") as Node3D
    if m2_layer == null:
        return
    var raw: Array = osm.get("coordinates_lonlat", [])
    var outline: PackedVector3Array = PackedVector3Array()
    for pair in raw:
        if pair.size() < 2:
            continue
        var converted: Vector3 = building.to_local(world.lonlat_to_world(float(pair[0]), float(pair[1])))
        if outline.is_empty() or converted.distance_squared_to(outline[outline.size() - 1]) > 0.0025:
            outline.append(converted)
    if outline.size() > 1 and outline[0].distance_squared_to(outline[outline.size() - 1]) < 0.0025:
        outline.remove_at(outline.size() - 1)
    if outline.size() < 8 or outline.size() > MAX_PERIMETER_EDGES:
        push_warning("Unexpected OSM ring length for " + identifier)
        return
    var layer := Node3D.new()
    layer.name = "SourceAlignedUpperEnvelope_NotSurveyed"
    m2_layer.add_child(layer)
    # An OSM outer ring can cover courtyards, sheltered walkways and different
    # storeys; NEVER extrude it into solid ground-floor walls, floors or colliders.
    # Only upper-storey ribbons / mullions are represented.
    var glazing := SurfaceTool.new()
    var fascia := SurfaceTool.new()
    var mullions := SurfaceTool.new()
    glazing.begin(Mesh.PRIMITIVE_TRIANGLES)
    fascia.begin(Mesh.PRIMITIVE_TRIANGLES)
    mullions.begin(Mesh.PRIMITIVE_TRIANGLES)
    var levels: int = 4 if identifier == "ERC" else 3
    var pitch: float = 3.8 if identifier == "ERC" else 3.75
    var top: float = 15.2 if identifier == "ERC" else 12.6
    var count: int = 0
    for i in range(outline.size()):
        var a: Vector3 = outline[i]
        var b: Vector3 = outline[(i + 1) % outline.size()]
        var segment_length: float = a.distance_to(b)
        if segment_length < 0.8:
            continue
        count += 1
        for upper_floor in range(1, levels):
            var bottom_y: float = float(upper_floor) * pitch + 0.45
            var top_y: float = minf(bottom_y + 1.74, top - 0.86)
            _append_vertical_quad(glazing, a, b, bottom_y, top_y)
            _append_vertical_quad(fascia, a, b, top_y, top_y + 0.17)
        _append_vertical_quad(fascia, a, b, top - 0.48, top)
        var mullion_count: int = mini(15, int(segment_length / 6.8))
        for j in range(1, mullion_count):
            var mid: Vector3 = a.lerp(b, float(j) / float(mullion_count))
            var direction: Vector3 = (b - a).normalized()
            var width: float = 0.14
            _append_vertical_quad(mullions, mid - direction * width, mid + direction * width, 4.10, top - 0.48)
    if count == 0:
        layer.queue_free()
        return
    var is_erc: bool = identifier == "ERC"
    _finish_surface(layer, "OSMUpperGlazing_Batched", glazing,
        _material(identifier + ":glass", "#6c9ba3" if is_erc else "#5d8697", 0.08))
    _finish_surface(layer, "UpperFloorSlabsAndRoofEdge_Batched", fascia,
        _material(identifier + ":fascia", "#e2e5e1" if is_erc else "#c5cdce", 0.05))
    _finish_surface(layer, "VerticalMullions_Batched", mullions,
        _material(identifier + ":mullions", "#657b82", 0.28))
    osm_edge_count += count
    p0_studies[identifier] = {
        "node": layer, "source": str(osm.get("source_url", "")),
        "edge_count": count, "floor_count": levels,
        "upper_floors_only": true, "collidable": false
    }

func _tower_window_color(floor_index: int, column: int, side: int) -> Color:
    if (floor_index * 7 + column * 5 + side * 3) % 23 == 0:
        return Color.html("#b8c4b5")
    if (floor_index + column + side) % 6 == 0:
        return Color.html("#b7cbd1")
    return Color.html("#6b8c98")

func _set_window(multi: MultiMesh, index: int, location: Vector3, yaw: float,
                 floor_index: int, column: int, side: int) -> void:
    multi.set_instance_transform(index, Transform3D(Basis(Vector3.UP, yaw), location))
    multi.set_instance_color(index, _tower_window_color(floor_index, column, side))

func _build_highrise_details(identifier: String) -> void:
    var record: Dictionary = _find_record(identifier)
    var tower: Node3D = world.get_node_or_null("BuildingMassing_Estimated/" + identifier) as Node3D
    if tower == null or record.is_empty():
        return
    var floors: int = int(record.get("confirmed_storeys", 0))
    var pitch: float = float(record.get("estimated_floor_pitch_m", 0.0))
    var parts: Array = record.get("parts", [])
    if floors < 5 or floors > 30 or pitch <= 2.0 or parts.is_empty():
        return
    var part: Dictionary = parts[0]
    var w: float = float(part.get("w", 24.0))
    var d: float = float(part.get("d", 24.0))
    var h: float = float(part.get("h", 0.0))
    if absf(h - float(floors) * pitch) > 0.3:
        push_warning("Tower height/storey pitch mismatch: " + identifier)
        return
    var x0: float = float(part.get("dx", 0.0))
    var z0: float = -float(part.get("dn", 0.0))
    var across_x: int = clampi(int(w / 3.7), 4, 13)
    var across_z: int = clampi(int(d / 3.7), 4, 13)
    var windows_per_floor: int = (across_x + across_z) * 2
    var count: int = windows_per_floor * floors
    if count <= 0 or count > MAX_WINDOWS_PER_TOWER:
        return
    var layer := Node3D.new()
    layer.name = "ConfirmedStoreys_EstimatedFacade"
    tower.add_child(layer)
    var mesh := _box_mesh(Vector3(1.68, 1.46, 0.16))
    var instances := MultiMesh.new()
    instances.transform_format = MultiMesh.TRANSFORM_3D
    instances.use_colors = true
    instances.mesh = mesh
    instances.instance_count = count
    var used: int = 0
    for floor_index in range(floors):
        var yy: float = float(floor_index) * pitch + 1.42
        for col in range(across_x):
            var xx: float = x0 - w * 0.5 + (float(col) + 0.5) * w / float(across_x)
            _set_window(instances, used, Vector3(xx, yy, z0 + d * 0.5 + 0.19), 0.0, floor_index, col, 0)
            used += 1
            _set_window(instances, used, Vector3(xx, yy, z0 - d * 0.5 - 0.19), PI, floor_index, col, 1)
            used += 1
        for col in range(across_z):
            var zz: float = z0 - d * 0.5 + (float(col) + 0.5) * d / float(across_z)
            _set_window(instances, used, Vector3(x0 + w * 0.5 + 0.19, yy, zz), PI * 0.5, floor_index, col, 2)
            used += 1
            _set_window(instances, used, Vector3(x0 - w * 0.5 - 0.19, yy, zz), -PI * 0.5, floor_index, col, 3)
            used += 1
    var facade := MultiMeshInstance3D.new()
    facade.name = "FloorByFloorCurtainWall_OneBatch"
    facade.multimesh = instances
    facade.material_override = _material("tower:glass", "#ffffff", 0.07)
    facade.material_override.vertex_color_use_as_albedo = true
    facade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    layer.add_child(facade)
    var trim: Material = _material("tower:trim", "#d5d9d5", 0.10)
    var roof: Material = _material("tower:roof", "#a6b9be", 0.22)
    _box(layer, "RoofParapet", Vector3(x0, h + 0.26, z0),
        Vector3(w + 0.9, 0.54, d + 0.9), roof)
    for floor_index in range(4, floors, 5):
        var level_y: float = float(floor_index) * pitch
        _box(layer, "ContinuousFacadeBand_%02d" % floor_index, Vector3(x0, level_y, z0 + d * 0.5 + 0.27),
            Vector3(w + 0.55, 0.24, 0.65), trim)
    total_windows += used
    tower_studies[identifier] = {
        "node": layer, "windows": used, "floors": floors,
        "height_m_estimated": h, "batch": facade
    }
