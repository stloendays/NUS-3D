extends Node3D
class_name UTownGreenDining
## Approximate campus-landscape and dining visuals built ONLY from existing UTown anchors.
## No third-party photo/texture, new geocoordinates, colliders or streaming assets.

const TUFT_LIMIT: int = 2000
const TUFT_ATTEMPTS: int = 11000
const PICNIC_LIMIT: int = 4
const PICNIC_ATTEMPTS: int = 500
const LAWN_EDGE_MARGIN: float = 2.2
const PATH_CLEARANCE: float = 1.2

@onready var world: UTownWorld = $"../World"
@onready var weather: UTownWeather = $"../Weather"
@onready var hud: CanvasLayer = $"../HUD"

var lawn_polygon: PackedVector2Array = PackedVector2Array()
var path_corridors: Array[Dictionary] = []
var generated_tuft_count: int = 0
var picnic_count: int = 0
var dining_table_count: int = 0
var food_stall_count: int = 0
var dining_areas: Dictionary = {}
var signs: Array[Label3D] = []
var tuft_batch: MultiMeshInstance3D
var tuft_positions: PackedVector2Array = PackedVector2Array()
var mesh_cache: Dictionary = {}
var material_cache: Dictionary = {}
var label_visibility: bool = true
var visibility_check: float = 0.0

func _ready() -> void:
    _index_lawn_and_paths()
    _build_lawn_tufts()
    _build_picnic_spots()
    _build_fine_food()
    _build_flavours()
    _build_erc_cafe_label()

func _material(hex: String) -> StandardMaterial3D:
    if not material_cache.has(hex):
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color.html(hex)
        mat.roughness = 0.82
        material_cache[hex] = mat
    return material_cache[hex]

func _box_mesh(size: Vector3) -> BoxMesh:
    var key: String = str(size)
    if not mesh_cache.has(key):
        var mesh := BoxMesh.new()
        mesh.size = size
        mesh_cache[key] = mesh
    return mesh_cache[key]

func _box(parent_node: Node3D, label: String, at: Vector3, size: Vector3, hex: String) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = label
    part.mesh = _box_mesh(size)
    part.material_override = _material(hex)
    part.position = at
    part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent_node.add_child(part)
    return part

func _sign(parent_node: Node3D, message: String, at: Vector3, color: String, font_size: int = 26) -> Label3D:
    var label := Label3D.new()
    label.name = "AmenityLabel"
    label.text = message
    label.position = at
    label.font_size = font_size
    label.pixel_size = 0.012
    label.outline_size = 5
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.modulate = Color.html(color)
    parent_node.add_child(label)
    signs.append(label)
    return label

func _index_lawn_and_paths() -> void:
    for coords in world.layout.get("green", {}).get("polygon_lonlat", []):
        var at: Vector3 = world.lonlat_to_world(float(coords[0]), float(coords[1]))
        lawn_polygon.append(Vector2(at.x, at.z))
    for raw_path in world.layout.get("walkways", []):
        var raw_points: Array = raw_path.get("lonlat", [])
        var clearance: float = float(raw_path.get("width_m", 3.5)) * 0.5 + PATH_CLEARANCE
        for i in range(raw_points.size() - 1):
            var a: Vector3 = world.lonlat_to_world(float(raw_points[i][0]), float(raw_points[i][1]))
            var b: Vector3 = world.lonlat_to_world(float(raw_points[i + 1][0]), float(raw_points[i + 1][1]))
            path_corridors.append({
                "start": Vector2(a.x, a.z),
                "end": Vector2(b.x, b.z),
                "clearance": clearance
            })

func _distance_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
    var offset: Vector2 = finish - start
    if offset.length_squared() < 0.0001:
        return point.distance_to(start)
    var portion: float = clampf((point - start).dot(offset) / offset.length_squared(), 0.0, 1.0)
    return point.distance_to(start + offset * portion)

func is_clear_lawn_point(point: Vector2, extra_margin: float = 0.0) -> bool:
    if lawn_polygon.size() < 3 or not Geometry2D.is_point_in_polygon(point, lawn_polygon):
        return false
    for i in range(lawn_polygon.size()):
        if _distance_segment(point, lawn_polygon[i], lawn_polygon[(i + 1) % lawn_polygon.size()]) < LAWN_EDGE_MARGIN + extra_margin:
            return false
    for corridor in path_corridors:
        if _distance_segment(point, corridor["start"], corridor["end"]) < float(corridor["clearance"]) + extra_margin:
            return false
    return true

func _lawn_bounds() -> Rect2:
    var rect: Rect2 = Rect2(lawn_polygon[0], Vector2.ZERO)
    for point in lawn_polygon:
        rect = rect.expand(point)
    return rect

func _tuft_mesh() -> ArrayMesh:
    # Two crossed grass blades, six vertices total. The MultiMesh is one draw call.
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
        Vector3(-0.17, 0.00, 0.0), Vector3(0.17, 0.00, 0.0), Vector3(0.0, 0.24, 0.0),
        Vector3(0.0, 0.00, -0.17), Vector3(0.0, 0.00, 0.17), Vector3(0.0, 0.24, 0.0)
    ])
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

func _build_lawn_tufts() -> void:
    if lawn_polygon.size() < 3:
        push_warning("Town Green outline missing; skipped lawn turf")
        return
    var rng := RandomNumberGenerator.new()
    rng.seed = 20261119
    var bounds: Rect2 = _lawn_bounds()
    var positions: Array[Vector2] = []
    for _attempt in range(TUFT_ATTEMPTS):
        if positions.size() >= TUFT_LIMIT:
            break
        var candidate := Vector2(
            rng.randf_range(bounds.position.x, bounds.end.x),
            rng.randf_range(bounds.position.y, bounds.end.y)
        )
        # MultiMesh stores transforms in float32; use a conservative buffer so
        # quantization cannot move edge tufts onto paths or outside Town Green.
        if is_clear_lawn_point(candidate, 0.6):
            positions.append(candidate)
    generated_tuft_count = positions.size()
    tuft_positions.clear()
    for candidate in positions:
        tuft_positions.append(candidate)
    if generated_tuft_count == 0:
        return
    var blades := MultiMesh.new()
    blades.transform_format = MultiMesh.TRANSFORM_3D
    blades.use_colors = true
    blades.mesh = _tuft_mesh()
    blades.instance_count = generated_tuft_count
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color.html("#83b966")
    mat.vertex_color_use_as_albedo = true
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.roughness = 0.97
    # Weather was initialized earlier: register the new material without resetting
    # existing rain state or replacing any existing grass/shader material.
    # This decorative turf registers with Weather only: do not alter the two
    # canonical World grass materials relied on by existing scene contracts.
    weather.wet_materials.append({
        "material": mat, "color": mat.albedo_color, "roughness": mat.roughness,
        "metallic": mat.metallic, "kind": "vegetation"
    })
    tuft_batch = MultiMeshInstance3D.new()
    tuft_batch.name = "TownGreenTurf_OneBatch"
    tuft_batch.multimesh = blades
    tuft_batch.material_override = mat
    tuft_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(tuft_batch)
    for i in range(generated_tuft_count):
        var amount: float = rng.randf_range(0.65, 1.45)
        var yaw: float = rng.randf_range(0.0, TAU)
        var transform := Transform3D(
            Basis(Vector3.UP, yaw).scaled(Vector3(amount, rng.randf_range(0.80, 1.30), amount)),
            Vector3(positions[i].x, 0.033, positions[i].y)
        )
        blades.set_instance_transform(i, transform)
        var tint: float = rng.randf_range(0.85, 1.12)
        blades.set_instance_color(i, Color(tint, tint, tint, 1.0))

func _build_picnic_spots() -> void:
    if lawn_polygon.size() < 3:
        return
    var root := Node3D.new()
    root.name = "TownGreenPicnicPatches_NoCollisions"
    add_child(root)
    var bounds: Rect2 = _lawn_bounds()
    var rng := RandomNumberGenerator.new()
    rng.seed = 20261120
    var accepted: Array[Vector2] = []
    for _attempt in range(PICNIC_ATTEMPTS):
        if accepted.size() >= PICNIC_LIMIT:
            break
        var point := Vector2(
            rng.randf_range(bounds.position.x, bounds.end.x),
            rng.randf_range(bounds.position.y, bounds.end.y)
        )
        if not is_clear_lawn_point(point, 3.0):
            continue
        var isolated: bool = true
        for previous in accepted:
            if previous.distance_to(point) < 12.0:
                isolated = false
                break
        if not isolated:
            continue
        accepted.append(point)
        var patch := Node3D.new()
        patch.name = "Picnic_%d" % accepted.size()
        patch.position = Vector3(point.x, 0.06, point.y)
        patch.rotation.y = rng.randf_range(-0.6, 0.6)
        root.add_child(patch)
        _box(patch, "PicnicBlanket", Vector3.ZERO, Vector3(2.65, 0.04, 1.95),
            "#d8aa7d" if accepted.size() % 2 == 0 else "#9ab8c7")
        _box(patch, "StudentNotebook", Vector3(-0.63, 0.055, -0.20), Vector3(0.38, 0.06, 0.48), "#f4edd5")
        _box(patch, "StudyBottle", Vector3(0.75, 0.16, 0.34), Vector3(0.13, 0.31, 0.13), "#66a8a3")
        _box(patch, "Frisbee", Vector3(0.15, 0.06, -0.40), Vector3(0.34, 0.03, 0.34), "#d8c86e")
        picnic_count += 1

func _box_batch(parent_node: Node3D, label: String, points: Array[Vector3], size: Vector3, color: String) -> void:
    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = _box_mesh(size)
    multimesh.instance_count = points.size()
    var instance := MultiMeshInstance3D.new()
    instance.name = label
    instance.multimesh = multimesh
    instance.material_override = _material(color)
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent_node.add_child(instance)
    for i in range(points.size()):
        multimesh.set_instance_transform(i, Transform3D(Basis(), points[i]))

func _build_fine_food() -> void:
    var plaza: Node3D = world.get_node_or_null("TownPlaza_approximate") as Node3D
    if plaza == null:
        return
    var entrance := Node3D.new()
    entrance.name = "FineFood_IllustrativePlazaFrontage"
    plaza.add_child(entrance)
    dining_areas["fine_food"] = {"anchor": plaza, "root": entrance, "source": "Town Plaza"}
    # Existing 44 x 31 m plaza and roof are retained; food furniture has no collisions.
    _box(entrance, "FoodcourtBanner", Vector3(-1.0, 4.55, -8.0), Vector3(21.0, 1.22, 0.20), "#466c61")
    _sign(entrance, "FINE FOOD  |  TOWN PLAZA", Vector3(-1.0, 4.61, -7.85), "#fff2cf", 32)
    var stalls: PackedStringArray = PackedStringArray(["RICE + NOODLES", "LOCAL BITES", "DRINKS + DESSERT"])
    for i in range(stalls.size()):
        var x: float = -11.0 + float(i) * 10.0
        _box(entrance, "StallCounter_%d" % i, Vector3(x, 0.81, -11.2),
            Vector3(6.6, 1.42, 1.35), "#b28e6a")
        _box(entrance, "StallCounterTop_%d" % i, Vector3(x, 1.57, -11.2),
            Vector3(6.85, 0.13, 1.53), "#d5bca0")
        _box(entrance, "StallMenu_%d" % i, Vector3(x, 2.43, -11.75),
            Vector3(6.8, 0.63, 0.10), "#445d5e")
        _sign(entrance, stalls[i], Vector3(x, 2.45, -10.90), "#fff2ca", 16)
        food_stall_count += 1
    var tabletops: Array[Vector3] = []
    var legs: Array[Vector3] = []
    var stools: Array[Vector3] = []
    for x in [-14.0, -7.0, 9.0, 16.0]:
        for z in [-1.8, 5.1]:
            tabletops.append(Vector3(x, 0.91, z))
            legs.append(Vector3(x, 0.46, z))
            stools.append(Vector3(x - 1.08, 0.48, z))
            stools.append(Vector3(x + 1.08, 0.48, z))
            dining_table_count += 1
    _box_batch(entrance, "DiningTables_OneBatch", tabletops, Vector3(1.45, 0.12, 1.05), "#e3d8bc")
    _box_batch(entrance, "DiningTableLegs_OneBatch", legs, Vector3(0.16, 0.82, 0.16), "#52636b")
    _box_batch(entrance, "DiningStools_OneBatch", stools, Vector3(0.53, 0.14, 0.53), "#b9caad")
    _sign(entrance, "SEATS  |  LUNCH BREAK", Vector3(-12.0, 2.07, 8.3), "#f7e3af", 19)

func _find_building_record(identifier: String) -> Dictionary:
    for record in world.layout.get("buildings", []):
        if str(record.get("id", "")) == identifier:
            return record
    return {}

func _build_flavours() -> void:
    var src: Node3D = world.get_node_or_null("BuildingMassing_Estimated/SRC") as Node3D
    var record: Dictionary = _find_building_record("SRC")
    if src == null or record.is_empty():
        return
    var pieces: Array = record.get("parts", [])
    if pieces.size() < 3:
        return
    var part: Dictionary = pieces[2]
    var facade_x: float = float(part.get("dx", 0.0)) + float(part.get("w", 0.0)) * 0.5
    var middle_z: float = -float(part.get("dn", 0.0))
    var frontage := Node3D.new()
    frontage.name = "Flavours_IllustrativeSRCFacade"
    src.add_child(frontage)
    dining_areas["flavours"] = {"anchor": src, "root": frontage, "source": "Stephen Riady Centre"}
    # Tied to a wall of the existing SRC massing, NOT a fake building on the lawn.
    _box(frontage, "SRCFoodcourtWallSign",
        Vector3(facade_x + 0.28, 3.57, middle_z), Vector3(0.20, 1.32, 10.4), "#3f6d58")
    _sign(frontage, "FLAVOURS @ UTOWN\nFOOD COURT INSIDE SRC",
        Vector3(facade_x + 1.42, 3.79, middle_z), "#f1ffda", 25)
    _box(frontage, "FoodCourtAwning",
        Vector3(facade_x + 1.5, 3.03, middle_z), Vector3(3.2, 0.16, 11.3), "#d4c5a2")
    for i in range(3):
        var spot_z: float = middle_z - 4.0 + float(i) * 4.0
        _box(frontage, "MenuDisplay_%d" % i, Vector3(facade_x + 0.43, 1.75, spot_z),
            Vector3(0.18, 1.35, 2.3), "#345362")
    _sign(frontage, "FOOD + DRINKS", Vector3(facade_x + 2.0, 2.23, middle_z + 6.4), "#ffe9aa", 18)

func _build_erc_cafe_label() -> void:
    var erc: Node3D = world.get_node_or_null("BuildingMassing_Estimated/ERC") as Node3D
    var record: Dictionary = _find_building_record("ERC")
    if erc == null or record.is_empty():
        return
    var pieces: Array = record.get("parts", [])
    if pieces.size() < 2:
        return
    var part: Dictionary = pieces[1]
    var x: float = float(part.get("dx", 0.0))
    var south_face: float = -float(part.get("dn", 0.0)) + float(part.get("d", 0.0)) * 0.5
    var sign_root := Node3D.new()
    sign_root.name = "ERCLearningCafe_IllustrativeSignage"
    erc.add_child(sign_root)
    _box(sign_root, "LearningCafeSign",
        Vector3(x, 3.22, south_face + 0.21), Vector3(11.2, 1.03, 0.18), "#506c66")
    _sign(sign_root, "ERC LEARNING CAFE", Vector3(x, 3.28, south_face + 0.49), "#f1ebd7", 23)

func _process(delta: float) -> void:
    visibility_check += delta
    if visibility_check < 0.24:
        return
    visibility_check = 0.0
    if label_visibility != hud.visible:
        label_visibility = hud.visible
        for label in signs:
            label.visible = label_visibility
