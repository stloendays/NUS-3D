extends Node3D
class_name UTownShopVisuals
## Lightweight original low-poly merchandise. No collision or navigation changes.
@onready var world: UTownWorld = $"../World"
@onready var coins: UTownCoins = $"../Coins"
var stand: Node3D
var previews: Dictionary = {}
var spin_time: float = 0.0
var _material_cache: Dictionary = {}
var _box_cache: Dictionary = {}
var _cylinder_cache: Dictionary = {}

func _material(hex: String, metallic: float = 0.0) -> StandardMaterial3D:
    var key: String = hex + ":" + str(metallic)
    if _material_cache.has(key):
        return _material_cache[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = Color.html(hex)
    m.roughness = 0.67
    m.metallic = metallic
    _material_cache[key] = m
    return m

func _mesh(parent: Node3D, name: String, mesh: Mesh, pos: Vector3, color: String, metal: float = 0.0) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = name
    item.mesh = mesh
    item.position = pos
    item.material_override = _material(color, metal)
    item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(item)
    return item

func _cylinder(radius: float, height: float) -> CylinderMesh:
    var key: Vector2 = Vector2(radius, height)
    if _cylinder_cache.has(key):
        return _cylinder_cache[key]
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 12
    _cylinder_cache[key] = mesh
    return mesh

func _box(size: Vector3) -> BoxMesh:
    if _box_cache.has(size):
        return _box_cache[size]
    var mesh := BoxMesh.new()
    mesh.size = size
    _box_cache[size] = mesh
    return mesh

func _label(parent: Node3D, words: String, pos: Vector3, scale_value: float = 0.007) -> void:
    var text := Label3D.new()
    text.text = words
    text.font_size = 32
    text.pixel_size = scale_value
    text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    text.position = pos
    text.modulate = Color("#f6eee0")
    text.outline_size = 6
    parent.add_child(text)

func _ready() -> void:
    var plaza := world.get_node_or_null("TownPlaza_approximate") as Node3D
    if plaza == null:
        return
    stand = Node3D.new()
    stand.name = "CampusShopDisplay"
    add_child(stand)
    stand.global_position = plaza.global_position + Vector3(5.0, 0.0, 2.0)
    _mesh(stand, "Counter", _box(Vector3(4.8, 0.9, 1.4)), Vector3(0, 0.45, 0), "#817c76")
    _mesh(stand, "CounterTop", _box(Vector3(5.1, 0.12, 1.6)), Vector3(0, 0.95, 0), "#c4b9a5")
    _label(stand, "CAMPUS SHOP  |  [O] NEARBY", Vector3(0, 2.25, 0), 0.011)
    for i in range(3):
        var root := Node3D.new()
        root.name = ["CoffeeDisplay", "SnackDisplay", "UmbrellaDisplay"][i]
        root.position = Vector3(-1.5 + float(i) * 1.5, 1.09, 0)
        stand.add_child(root)
        var item: String = ["coffee", "snack", "umbrella"][i]
        previews[item] = root
        if item == "coffee":
            _coffee(root)
        elif item == "snack":
            _snack(root)
        else:
            _umbrella(root)
        _label(stand, ["COFFEE  12 C", "SNACK  8 C", "UMBRELLA  45 C"][i],
            Vector3(-1.5 + float(i) * 1.5, 1.65, 0), 0.006)

func _coffee(root: Node3D) -> void:
    var cup := _mesh(root, "PaperCup", _cylinder(0.22, 0.48), Vector3(0, 0.25, 0), "#f1e7d6")
    cup.scale = Vector3(1.0, 1.0, 1.0)
    _mesh(root, "Sleeve", _cylinder(0.232, 0.19), Vector3(0, 0.25, 0), "#a87955")
    _mesh(root, "Lid", _cylinder(0.26, 0.07), Vector3(0, 0.52, 0), "#393e42")
    _mesh(root, "SipOpening", _box(Vector3(0.15, 0.02, 0.06)), Vector3(0, 0.56, -0.09), "#161c20")

func _snack(root: Node3D) -> void:
    var wrapper := _mesh(root, "SnackWrapper", _box(Vector3(0.55, 0.75, 0.14)), Vector3(0, 0.38, 0), "#e3a34d")
    wrapper.rotation.z = -0.08
    _mesh(root, "BrandStripe", _box(Vector3(0.56, 0.15, 0.15)), Vector3(0, 0.47, 0), "#bd4d41")
    _mesh(root, "TopSeal", _box(Vector3(0.58, 0.07, 0.16)), Vector3(0, 0.76, 0), "#f6df9c")
    _label(root, "BITE", Vector3(0, 0.4, -0.10), 0.005)

func _umbrella(root: Node3D) -> void:
    _mesh(root, "HandleShaft", _cylinder(0.035, 0.8), Vector3(0, 0.44, 0), "#d2d7d7", 0.5)
    var canopy := CylinderMesh.new()
    canopy.top_radius = 0.0
    canopy.bottom_radius = 0.48
    canopy.height = 0.3
    canopy.radial_segments = 8
    _mesh(root, "Canopy", canopy, Vector3(0, 0.91, 0), "#487c83")
    _mesh(root, "TopCap", _cylinder(0.045, 0.12), Vector3(0, 1.1, 0), "#c8c8b6")
    _mesh(root, "Grip", _cylinder(0.06, 0.19), Vector3(0, 0.08, 0), "#35383b")

func _process(delta: float) -> void:
    if stand == null:
        return
    var near: bool = stand.global_position.distance_to(coins.player.global_position) < 65.0
    stand.visible = near and not coins.campus_life.interior_active
    if not stand.visible:
        return
    spin_time += delta
    for i in range(3):
        var root: Node3D = previews[["coffee", "snack", "umbrella"][i]]
        root.rotation.y = sin(spin_time * 0.7 + float(i)) * 0.16
