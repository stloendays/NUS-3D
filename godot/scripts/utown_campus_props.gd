extends RefCounted
class_name UTownCampusProps
## Lightweight original UTown-inspired street furniture. No imported meshes,
## physics, new lights, or gameplay state. Anchors are approximate campus data.

static func _mat(hex: String) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color.html(hex)
    m.roughness = 0.86
    return m

static func _box(parent: Node3D, label: String, p: Vector3, size: Vector3, mat: Material) -> void:
    var mesh := MeshInstance3D.new()
    mesh.name = label
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.position = p
    mesh.material_override = mat
    parent.add_child(mesh)

static func _cylinder(parent: Node3D, label: String, p: Vector3, top: float, bottom: float, height: float, mat: Material) -> void:
    var mesh := MeshInstance3D.new()
    mesh.name = label
    var shape := CylinderMesh.new()
    shape.top_radius = top
    shape.bottom_radius = bottom
    shape.height = height
    shape.radial_segments = 8
    mesh.mesh = shape
    mesh.position = p
    mesh.material_override = mat
    parent.add_child(mesh)

static func _label(parent: Node3D, value: String, p: Vector3) -> void:
    var text_node := Label3D.new()
    text_node.text = value
    text_node.position = p
    text_node.font_size = 24
    text_node.pixel_size = 0.006
    text_node.outline_size = 3
    text_node.modulate = Color("#edf1eb")
    parent.add_child(text_node)

static func _bench(parent: Node3D, p: Vector3, wood: Material, metal: Material) -> void:
    var group := Node3D.new()
    group.name = "CampusBench"
    group.position = p
    parent.add_child(group)
    _box(group, "Seat", Vector3(0, 0.52, 0), Vector3(1.8, 0.12, 0.52), wood)
    _box(group, "Backrest", Vector3(0, 0.96, 0.23), Vector3(1.8, 0.75, 0.12), wood)
    for x in [-0.7, 0.7]:
        _box(group, "Frame", Vector3(x, 0.25, 0), Vector3(0.08, 0.5, 0.45), metal)

static func _bin(parent: Node3D, p: Vector3, body: Material, lid: Material, symbol: String) -> void:
    var group := Node3D.new()
    group.name = "WasteBin_" + symbol
    group.position = p
    parent.add_child(group)
    _box(group, "BinBody", Vector3(0, 0.43, 0), Vector3(0.46, 0.82, 0.42), body)
    _box(group, "BinLid", Vector3(0, 0.86, 0), Vector3(0.51, 0.09, 0.47), lid)
    _label(group, symbol, Vector3(0, 0.54, -0.224))

static func _rack(parent: Node3D, p: Vector3, metal: Material) -> void:
    var group := Node3D.new()
    group.name = "BicycleRack"
    group.position = p
    parent.add_child(group)
    for i in range(4):
        var x: float = float(i) * 0.72 - 1.08
        _box(group, "RackLeg", Vector3(x - 0.25, 0.38, 0), Vector3(0.07, 0.76, 0.08), metal)
        _box(group, "RackLeg", Vector3(x + 0.25, 0.38, 0), Vector3(0.07, 0.76, 0.08), metal)
        _box(group, "RackTop", Vector3(x, 0.77, 0), Vector3(0.57, 0.07, 0.08), metal)

static func _water(parent: Node3D, p: Vector3, metal: Material, blue: Material) -> void:
    var group := Node3D.new()
    group.name = "WaterRefillStation"
    group.position = p
    parent.add_child(group)
    _box(group, "Cabinet", Vector3(0, 0.76, 0), Vector3(0.66, 1.5, 0.48), metal)
    _box(group, "Display", Vector3(0, 1.18, -0.255), Vector3(0.43, 0.32, 0.025), blue)
    _box(group, "Spout", Vector3(0, 0.75, -0.29), Vector3(0.13, 0.09, 0.16), blue)
    _box(group, "DripTray", Vector3(0, 0.53, -0.36), Vector3(0.37, 0.055, 0.26), metal)

static func _notice(parent: Node3D, p: Vector3, frame: Material, paper: Material) -> void:
    var group := Node3D.new()
    group.name = "CampusNoticeBoard"
    group.position = p
    parent.add_child(group)
    _box(group, "PostLeft", Vector3(-0.9, 0.9, 0), Vector3(0.08, 1.8, 0.09), frame)
    _box(group, "PostRight", Vector3(0.9, 0.9, 0), Vector3(0.08, 1.8, 0.09), frame)
    _box(group, "Board", Vector3(0, 1.46, 0), Vector3(2.05, 0.93, 0.11), frame)
    for i in range(3):
        _box(group, "Flyer", Vector3(-0.61 + float(i) * 0.61, 1.45, -0.064), Vector3(0.46, 0.65, 0.012), paper)
    _label(group, "EVENTS / DDL", Vector3(0, 1.74, -0.079))

static func _vending(parent: Node3D, p: Vector3, frame: Material, accent: Material) -> void:
    var group := Node3D.new()
    group.name = "CampusVendingMachine"
    group.position = p
    parent.add_child(group)
    _box(group, "Cabinet", Vector3(0, 1.0, 0), Vector3(1.0, 2.0, 0.65), frame)
    _box(group, "Display", Vector3(-0.16, 1.32, -0.34), Vector3(0.53, 0.79, 0.015), accent)
    for i in range(6):
        _box(group, "Drink", Vector3(-0.34 + float(i % 3) * 0.18, 1.12 + float(i / 3) * 0.29, -0.358), Vector3(0.10, 0.18, 0.016), frame)
    _box(group, "Dispenser", Vector3(0.02, 0.39, -0.34), Vector3(0.53, 0.22, 0.025), accent)

static func decorate(world: Node3D, anchors: Dictionary) -> void:
    var root := Node3D.new()
    root.name = "CampusFurnitureM16"
    world.add_child(root)
    var wood := _mat("#9d7958")
    var steel := _mat("#52636a")
    var blue := _mat("#6795a4")
    var green := _mat("#668d78")
    var cream := _mat("#e3d5ad")
    for id in ["GREEN", "ERC", "SRC", "PLAZA"]:
        if not anchors.has(id):
            continue
        var point: Vector3 = anchors[id]
        var group := Node3D.new()
        group.name = "Furniture_" + id
        group.position = point
        root.add_child(group)
        # Offset furniture from the waypoint itself, leaving the walking route clear.
        _bench(group, Vector3(6.0, 0, 5.0), wood, steel)
        _bench(group, Vector3(8.4, 0, 5.0), wood, steel)
        _bin(group, Vector3(5.5, 0, 7.1), green, steel, "RECYCLE")
        _bin(group, Vector3(6.2, 0, 7.1), steel, cream, "WASTE")
        _water(group, Vector3(8.0, 0, 7.1), steel, blue)
        if id == "GREEN" or id == "ERC":
            _rack(group, Vector3(11.0, 0, 5.5), steel)
        if id == "PLAZA" or id == "ERC":
            _notice(group, Vector3(11.0, 0, 8.0), steel, cream)
        if id == "SRC" or id == "PLAZA":
            _vending(group, Vector3(10.0, 0, 8.0), steel, blue)
