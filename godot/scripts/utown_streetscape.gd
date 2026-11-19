extends Node3D
class_name UTownStreetscape
## Original comic-style UTown micro-scenes. Geometry is decorative and collision-free.
## All four small authored textures are cached; repeated boxes share mesh/material.
const MAX_CLUSTERS: int = 56
const CLUSTER_SPACING: float = 12.0
const BACKDROP_CAPACITY: int = 12
const SCRAP_CAPACITY: int = 156
const MATERIAL_TEXTURES = {
    "brick": "res://assets/materials/comic_brick.svg",
    "paper": "res://assets/materials/comic_paper.svg",
    "poster": "res://assets/materials/comic_poster.svg",
    "tile": "res://assets/materials/comic_tile.svg"
}

@onready var world: UTownWorld = $"../World"
var mesh_cache: Dictionary = {}
var material_cache: Dictionary = {}
var texture_cache: Dictionary = {}
var cluster_count: int = 0
var backdrop_count: int = 0
var scrap_count: int = 0
var placard_count: int = 0

func _ready() -> void:
    if world.layout.is_empty():
        push_warning("M3.7 decorations skipped: world has no layout")
        return
    for key in MATERIAL_TEXTURES:
        texture_cache[key] = load(MATERIAL_TEXTURES[key]) as Texture2D
    _build_path_details()
    _build_story_signs()
    _build_distant_fictional_skyline()

func _mat(color_hex: String, texture_key: String = "") -> StandardMaterial3D:
    var key: String = color_hex + ":" + texture_key
    if material_cache.has(key):
        return material_cache[key]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color.html(color_hex)
    mat.roughness = 0.82
    if texture_cache.has(texture_key):
        mat.albedo_texture = texture_cache[texture_key]
    material_cache[key] = mat
    return mat

func _mesh(dims: Vector3) -> BoxMesh:
    var key: String = str(dims)
    if not mesh_cache.has(key):
        var mesh := BoxMesh.new()
        mesh.size = dims
        mesh_cache[key] = mesh
    return mesh_cache[key]

func _box(parent: Node3D, part_name: String, offset: Vector3, dims: Vector3, hex: String, texture_key: String = "") -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = part_name
    item.mesh = _mesh(dims)
    item.position = offset
    item.material_override = _mat(hex, texture_key)
    item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(item)
    return item

func _caption(parent: Node3D, text_value: String, at: Vector3, color_hex: String) -> void:
    var text_node := Label3D.new()
    text_node.text = text_value
    text_node.position = at
    text_node.font_size = 26
    text_node.pixel_size = 0.015
    text_node.outline_size = 6
    text_node.modulate = Color.html(color_hex)
    text_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    parent.add_child(text_node)

func _clear_position(candidate: Vector3) -> bool:
    if not world.is_tree_position_clear(Vector2(candidate.x, candidate.z), 1.5):
        return false
    for tree in world.generated_tree_positions:
        if Vector2(tree.x, tree.z).distance_to(Vector2(candidate.x, candidate.z)) < 3.8:
            return false
    return true

func _build_path_details() -> void:
    var root := Node3D.new()
    root.name = "StreetFurniture_OriginalComicArt"
    add_child(root)
    var paper_transforms: Array[Transform3D] = []
    var paper_colors: Array[Color] = []
    var serial: int = 0
    for raw_way in world.layout.get("walkways", []):
        var way: Dictionary = raw_way
        var points: Array = way.get("lonlat", [])
        for j in range(points.size() - 1):
            var start: Vector3 = world.lonlat_to_world(float(points[j][0]), float(points[j][1]))
            var finish: Vector3 = world.lonlat_to_world(float(points[j + 1][0]), float(points[j + 1][1]))
            var segment: Vector3 = finish - start
            var steps: int = int(segment.length() / CLUSTER_SPACING)
            if steps < 1:
                continue
            var forward: Vector3 = segment.normalized()
            var sideways: Vector3 = Vector3(-forward.z, 0.0, forward.x)
            var lateral_m: float = float(way.get("width_m", 3.5)) * 0.5 + 4.3
            for index in range(steps):
                if cluster_count >= MAX_CLUSTERS:
                    break
                serial += 1
                var centre: Vector3 = start.lerp(finish, (float(index) + 0.5) / float(steps))
                var side_sign: float = 1.0 if serial % 2 == 0 else -1.0
                var candidate: Vector3 = centre + sideways * lateral_m * side_sign
                if not _clear_position(candidate):
                    candidate = centre - sideways * lateral_m * side_sign
                if not _clear_position(candidate):
                    continue
                var display := Node3D.new()
                display.name = "ComicStreetScene_%02d" % cluster_count
                display.position = candidate
                display.rotation.y = atan2(forward.x, forward.z)
                root.add_child(display)
                _street_prop(display, serial % 5)
                cluster_count += 1
                for scrap in range(3):
                    if paper_transforms.size() >= SCRAP_CAPACITY:
                        break
                    var side_offset: float = float((serial * 13 + scrap * 9) % 13 - 6) * 0.31
                    var forward_offset: float = float((serial * 5 + scrap * 7) % 13 - 6) * 0.30
                    var scrap_at: Vector3 = centre + sideways * side_offset + forward * forward_offset + Vector3(0, 0.175, 0)
                    paper_transforms.append(Transform3D(Basis(Vector3.UP, float(serial % 19 + scrap) * 0.3), scrap_at))
                    paper_colors.append(Color.html(["#fdf4ce", "#a3d8ff", "#ffaeb0"][scrap]))
    _paper_scraps(root, paper_transforms, paper_colors)

func _street_prop(parent: Node3D, variant: int) -> void:
    match variant:
        0:
            _box(parent, "Bench", Vector3(0, 0.58, 0), Vector3(2.0, 0.16, 0.68), "#ffffff", "brick")
            _box(parent, "Back", Vector3(0, 1.06, 0.3), Vector3(2.0, 0.78, 0.14), "#c58d88", "brick")
            for x in [-0.73, 0.73]:
                _box(parent, "BenchLeg", Vector3(x, 0.28, 0), Vector3(0.12, 0.55, 0.47), "#425a6b")
            _box(parent, "Coffee", Vector3(0.44, 0.93, -0.05), Vector3(0.38, 0.55, 0.36), "#ffffff", "poster")
            _box(parent, "CoffeeLid", Vector3(0.44, 1.23, -0.05), Vector3(0.44, 0.07, 0.44), "#f9e9c6")
        1:
            _box(parent, "NoticePole", Vector3(0, 0.9, 0), Vector3(0.14, 1.8, 0.14), "#536274")
            _box(parent, "NoticeBoard", Vector3(0, 1.7, 0), Vector3(1.65, 1.13, 0.14), "#fff8e9", "poster")
            _box(parent, "Handout", Vector3(-0.26, 1.65, -0.09), Vector3(0.65, 0.86, 0.025), "#ffffff", "paper")
            _caption(parent, ["DUE YESTERDAY", "PANIC CLUB", "NO MORE SLEEP"][cluster_count % 3], Vector3(0, 2.56, 0), "#fff0b9")
        2:
            _box(parent, "SnackMachine", Vector3(0, 1.1, 0), Vector3(1.18, 2.2, 0.75), "#e6eef3", "tile")
            _box(parent, "SnackWindow", Vector3(-0.13, 1.4, -0.39), Vector3(0.70, 1.15, 0.04), "#fffaf5", "poster")
            _box(parent, "Button", Vector3(0.40, 1.08, -0.40), Vector3(0.13, 0.27, 0.025), "#f0d175")
            _caption(parent, "COFFEE +99", Vector3(0, 2.52, 0), "#ffde8d")
        3:
            _box(parent, "Planter", Vector3(0, 0.37, 0), Vector3(1.30, 0.74, 1.15), "#ffffff", "brick")
            for i in range(3):
                _box(parent, "TropicalSprout", Vector3(-0.33 + float(i) * 0.32, 1.08, 0.0), Vector3(0.27, 0.90, 0.32), "#459c6b")
            _box(parent, "DroppedEssay", Vector3(0.6, 0.10, -0.85), Vector3(0.77, 0.08, 0.54), "#ffffff", "paper")
        4:
            _box(parent, "RecyclingBin", Vector3(0, 0.68, 0), Vector3(0.77, 1.36, 0.77), "#dceaf4", "tile")
            _box(parent, "Rim", Vector3(0, 1.40, 0), Vector3(0.84, 0.11, 0.84), "#fbd88b")
            _box(parent, "LostPen", Vector3(0.65, 0.12, -0.25), Vector3(0.09, 0.08, 0.92), "#fa7884")
            _caption(parent, "RECYCLE EXCUSES", Vector3(0, 1.88, 0), "#fff6c9")

func _paper_scraps(root: Node3D, transforms: Array[Transform3D], tints: Array[Color]) -> void:
    var scrap_mesh := BoxMesh.new()
    scrap_mesh.size = Vector3(0.25, 0.018, 0.34)
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.use_colors = true
    batch.mesh = scrap_mesh
    batch.instance_count = transforms.size()
    var renderer := MultiMeshInstance3D.new()
    renderer.name = "ScatteredHandouts_OneBatch"
    renderer.multimesh = batch
    renderer.material_override = _mat("#ffffff")
    renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(renderer)
    for i in range(transforms.size()):
        batch.set_instance_transform(i, transforms[i])
        batch.set_instance_color(i, tints[i])
    scrap_count = transforms.size()

func _build_story_signs() -> void:
    var labels := PackedStringArray(["YOUR LAST BRAIN CELL", "ACADEMIC APOCALYPSE", "COFFEE EMERGENCY", "UPLOAD OR PERISH"])
    var points: Array = world.layout.get("loop", [])
    for i in range(mini(4, points.size())):
        var point: Dictionary = points[i]
        var root := Node3D.new()
        root.name = "ComicalBanner_%d" % i
        root.position = world.lonlat_to_world(float(point["lon"]), float(point["lat"])) + Vector3(7.0, 0, 7.0)
        add_child(root)
        _box(root, "LeftPole", Vector3(-2, 1.8, 0), Vector3(0.16, 3.6, 0.16), "#647184")
        _box(root, "RightPole", Vector3(2, 1.8, 0), Vector3(0.16, 3.6, 0.16), "#647184")
        _box(root, "Canvas", Vector3(0, 3.40, 0), Vector3(4.32, 1.02, 0.20), "#ffffff", "poster")
        _caption(root, labels[i], Vector3(0, 3.48, -0.18), "#313a53")
        placard_count += 1

func _build_distant_fictional_skyline() -> void:
    # Props are game fiction, NOT a representation of surrounding real NUS blocks.
    var backdrop := Node3D.new()
    backdrop.name = "ComicSkyline_Backdrop_NotRealCampus"
    add_child(backdrop)
    var slogans := PackedStringArray(["LIBRARY 404", "CAFFEINE LAB", "SLEEP MUSEUM", "PRINT & PRAY"])
    for i in range(BACKDROP_CAPACITY):
        var theta: float = TAU * float(i) / float(BACKDROP_CAPACITY)
        var radius: float = 205.0 + float(i % 3) * 11.0
        var width_m: float = 12.0 + float(i % 4) * 3.4
        var height_m: float = 15.0 + float(i * 7 % 5) * 4.3
        var building := Node3D.new()
        building.name = "ImaginaryBackdrop_%02d" % i
        building.position = Vector3(cos(theta) * radius, 0, sin(theta) * radius)
        building.rotation.y = -theta
        backdrop.add_child(building)
        _box(building, "TexturedWall", Vector3(0, height_m * 0.5, 0), Vector3(width_m, height_m, 8.5), "#ffffff", "brick")
        _box(building, "Roof", Vector3(0, height_m + 0.27, 0), Vector3(width_m + 0.8, 0.54, 9.0), "#647590")
        _box(building, "ComicNeon", Vector3(0, height_m - 2.0, -4.35), Vector3(width_m - 1.8, 0.36, 0.16), "#ffcf81")
        if i % 3 == 0:
            _caption(building, slogans[i / 3], Vector3(0, height_m + 1.9, -4.3), "#fff1b0")
        backdrop_count += 1
