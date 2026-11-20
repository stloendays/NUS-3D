extends RefCounted
class_name UTownInteriorLifeProps
## Static, low-cost details for existing ERC study and SRC recreation interiors.
## These are fictional set dressing, not replicas of real NUS rooms.

static func _mat(color: String) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color.html(color)
    m.roughness = 0.85
    return m

static func _box(parent: Node3D, name: String, p: Vector3, size: Vector3, material: Material) -> void:
    var mesh := MeshInstance3D.new()
    mesh.name = name
    var shape := BoxMesh.new()
    shape.size = size
    mesh.mesh = shape
    mesh.position = p
    mesh.material_override = material
    parent.add_child(mesh)

static func _ball(parent: Node3D, name: String, p: Vector3, radius: float, material: Material) -> void:
    var mesh := MeshInstance3D.new()
    mesh.name = name
    var shape := SphereMesh.new()
    shape.radius = radius
    shape.height = radius * 2.0
    shape.radial_segments = 10
    shape.rings = 5
    mesh.mesh = shape
    mesh.position = p
    mesh.material_override = material
    parent.add_child(mesh)

static func _label(parent: Node3D, value: String, p: Vector3) -> void:
    var label := Label3D.new()
    label.text = value
    label.position = p
    label.font_size = 21
    label.pixel_size = 0.007
    label.outline_size = 3
    parent.add_child(label)

static func decorate_study(room: Node3D) -> void:
    var root := Node3D.new()
    root.name = "StudyLifePropsM17"
    room.add_child(root)
    var paper := _mat("#e7ddc6")
    var cover := _mat("#6c8990")
    var accent := _mat("#d6aa66")
    var dark := _mat("#4a5a62")
    # Books on existing shelving: left-wall shelf surfaces face the room.
    for bay in range(4):
        for level in range(3):
            for book in range(5):
                _box(root, "ShelfBook_%d_%d_%d" % [bay, level, book],
                    Vector3(-9.59, 0.66 + level * 0.70, -5.5 + bay * 3.5 - 0.8 + book * 0.32),
                    Vector3(0.16, 0.38 + 0.05 * float(book % 3), 0.23),
                    cover if book % 3 == 0 else paper if book % 3 == 1 else accent)
    # Upper level: a couple of abandoned revision piles, without adding physics.
    for i in range(3):
        var x: float = [-5.0, 0.0, 5.0][i]
        for sheet in range(3):
            _box(root, "RevisionSheet_%d_%d" % [i, sheet],
                Vector3(x - 0.45 + sheet * 0.06, 4.035 + sheet * 0.014, -6.55),
                Vector3(0.44, 0.012, 0.32), paper)
        _box(root, "UpperPencilCase_%d" % i, Vector3(x + 0.45, 4.07, -6.4),
            Vector3(0.35, 0.10, 0.18), dark)
    _label(root, "QUIET ZONE / DDL SURVIVAL", Vector3(-7.7, 2.2, -8.26))

static func decorate_recreation(room: Node3D) -> void:
    var root := Node3D.new()
    root.name = "RecreationLifePropsM17"
    room.add_child(root)
    var metal := _mat("#566971")
    var bright := _mat("#d1aa65")
    var blue := _mat("#6e9aa9")
    var red := _mat("#bf766b")
    var paper := _mat("#e4dfd2")
    # Sports equipment stored along side walls, clear of the central court.
    for i in range(5):
        _ball(root, "SportsBall_%02d" % i, Vector3(-10.4, 0.24, -5.4 + i * 0.75),
            0.23, bright if i % 2 == 0 else blue)
    _box(root, "SportsBallRack", Vector3(-10.4, 0.15, -3.9), Vector3(0.72, 0.24, 4.6), metal)
    for i in range(4):
        _box(root, "TrainingCone_%02d" % i, Vector3(10.45, 0.22, -5.2 + i * 0.72),
            Vector3(0.26, 0.43, 0.26), red)
    # Tabletop games tucked into the side seating area.
    _box(root, "ChessBoard", Vector3(8.2, 0.93, 4.2), Vector3(0.66, 0.028, 0.66), bright)
    for i in range(8):
        _box(root, "ChessPiece_%02d" % i,
            Vector3(7.97 + float(i % 4) * 0.15, 0.98, 3.98 + float(i / 4) * 0.39),
            Vector3(0.065, 0.08, 0.065), metal if i < 4 else paper)
    _box(root, "CardsBox", Vector3(9.4, 0.93, 4.3), Vector3(0.25, 0.07, 0.37), red)
    # Wall notice, not a new HUD overlay.
    _box(root, "ClubPoster", Vector3(0, 2.5, -8.77), Vector3(2.1, 1.2, 0.04), blue)
    _label(root, "SRC CLUB NIGHT", Vector3(0, 2.5, -8.72))
