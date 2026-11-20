extends RefCounted
class_name UTownInteriorLifeProps
## Lightweight, collision-free everyday props for the existing ERC and SRC rooms.
## Original low-poly set dressing; not surveyed NUS interiors.

static func _mat(hex: String, roughness: float = 0.86) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.html(hex)
    material.roughness = roughness
    return material


static func _box(parent: Node3D, name: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    mesh.name = name
    var shape := BoxMesh.new()
    shape.size = size
    mesh.mesh = shape
    mesh.position = at
    mesh.material_override = material
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mesh)
    return mesh


static func _ball(parent: Node3D, name: String, at: Vector3, radius: float, material: Material) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    mesh.name = name
    var shape := SphereMesh.new()
    shape.radius = radius
    shape.height = radius * 2.0
    shape.radial_segments = 10
    shape.rings = 5
    mesh.mesh = shape
    mesh.position = at
    mesh.material_override = material
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mesh)
    return mesh


static func _cylinder(parent: Node3D, name: String, at: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    mesh.name = name
    var shape := CylinderMesh.new()
    shape.top_radius = radius * 0.9
    shape.bottom_radius = radius
    shape.height = height
    shape.radial_segments = 10
    mesh.mesh = shape
    mesh.position = at
    mesh.material_override = material
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mesh)
    return mesh


static func _rod(parent: Node3D, name: String, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
    var direction: Vector3 = b - a
    var mesh := MeshInstance3D.new()
    mesh.name = name
    var shape := CylinderMesh.new()
    shape.top_radius = radius
    shape.bottom_radius = radius
    shape.height = direction.length()
    shape.radial_segments = 8
    mesh.mesh = shape
    mesh.position = (a + b) * 0.5
    mesh.quaternion = Quaternion(Vector3.UP, direction.normalized())
    mesh.material_override = material
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mesh)
    return mesh


static func _label(parent: Node3D, name: String, value: String, at: Vector3, color: String = "#edf1e8") -> Label3D:
    var label := Label3D.new()
    label.name = name
    label.text = value
    label.position = at
    label.font_size = 22
    label.pixel_size = 0.008
    label.outline_size = 3
    label.modulate = Color.html(color)
    parent.add_child(label)
    return label


static func _desk_laptop(parent: Node3D, prefix: String, at: Vector3, dark: Material, screen: Material) -> void:
    _box(parent, prefix + "_LaptopBase", at, Vector3(0.58, 0.045, 0.38), dark)
    var display := _box(parent, prefix + "_LaptopScreen", at + Vector3(0, 0.19, -0.16), Vector3(0.58, 0.34, 0.045), dark)
    display.rotation.x = -0.12
    _box(parent, prefix + "_ScreenGlow", at + Vector3(0, 0.19, -0.132), Vector3(0.49, 0.25, 0.012), screen)


static func decorate_study(room: Node3D) -> void:
    if room.has_node("StudyLifePropsM24"):
        return
    var root := Node3D.new()
    root.name = "StudyLifePropsM24"
    room.add_child(root)

    var paper := _mat("#e8e0cf")
    var book_teal := _mat("#668b8d")
    var book_ochre := _mat("#c49b62")
    var book_rust := _mat("#b97668")
    var dark := _mat("#40515a")
    var screen := _mat("#6e9ba5", 0.42)
    var wood := _mat("#a7835f")
    var ceramic := _mat("#d9e2dc", 0.5)
    var plant_green := _mat("#62866d")

    # Existing wall shelving receives individually readable book spines.
    for bay in range(4):
        for level in range(3):
            for book in range(5):
                var book_color: Material = book_teal if book % 3 == 0 else paper if book % 3 == 1 else book_ochre
                _box(root, "ShelfBook_%d_%d_%d" % [bay, level, book],
                    Vector3(-9.59, 0.66 + level * 0.70, -5.5 + bay * 3.5 - 0.8 + book * 0.32),
                    Vector3(0.16, 0.38 + 0.05 * float(book % 3), 0.23), book_color)

    # Eight study desks get varied laptops, notes, books, pencil cases and cups.
    var desk_index: int = 0
    for x in [-7.0, -3.5, 3.5, 7.0]:
        for z in [-3.5, 0.9]:
            var center := Vector3(x, 1.025, z)
            if desk_index % 3 != 1:
                _desk_laptop(root, "Desk_%02d" % desk_index, center + Vector3(-0.38, 0.0, -0.08), dark, screen)
            for page in range(2 + desk_index % 2):
                var note := _box(root, "RevisionNote_%02d_%02d" % [desk_index, page],
                    center + Vector3(0.62 + float(page) * 0.035, 0.018 + float(page) * 0.012, 0.16),
                    Vector3(0.34, 0.012, 0.25), paper)
                note.rotation.y = float(page) * 0.08
            _box(root, "PencilCase_%02d" % desk_index,
                center + Vector3(0.70, 0.09, -0.34), Vector3(0.34, 0.12, 0.14), book_teal if desk_index % 2 == 0 else book_rust)
            if desk_index % 2 == 0:
                _cylinder(root, "WaterCup_%02d" % desk_index, center + Vector3(-0.92, 0.13, 0.36), 0.08, 0.20, ceramic)
            desk_index += 1

    # Mezzanine study desks: loose revision stacks and a task lamp on each bay.
    for i in range(3):
        var x: float = [-5.0, 0.0, 5.0][i]
        for sheet in range(3):
            _box(root, "UpperRevision_%d_%d" % [i, sheet],
                Vector3(x - 0.48 + float(sheet) * 0.055, 4.035 + float(sheet) * 0.014, -6.55),
                Vector3(0.44, 0.012, 0.32), paper)
        _box(root, "UpperPencilCase_%d" % i, Vector3(x + 0.45, 4.07, -6.4),
            Vector3(0.35, 0.10, 0.18), dark)
        _box(root, "UpperTaskLamp_%d" % i, Vector3(x + 0.82, 4.13, -6.45),
            Vector3(0.24, 0.08, 0.24), book_ochre)

    # Printer and return tray sit against the wall, away from the central aisle.
    _box(root, "PrintStationCabinet", Vector3(-10.1, 0.52, -7.25), Vector3(1.0, 1.0, 1.15), dark)
    _box(root, "PrinterBody", Vector3(-10.1, 1.12, -7.25), Vector3(0.9, 0.22, 0.82), paper)
    _box(root, "PrinterOutputTray", Vector3(-10.1, 1.25, -6.92), Vector3(0.64, 0.035, 0.32), book_teal)
    for i in range(3):
        _box(root, "PrinterPaper_%d" % i, Vector3(-10.1, 1.28 + i * 0.014, -7.28),
            Vector3(0.42, 0.012, 0.34), paper)

    # Small wall details add scale without turning the room into a prop maze.
    _box(root, "DeadlineBoardPinStrip", Vector3(0.0, 2.82, -8.46), Vector3(4.7, 0.08, 0.035), book_ochre)
    _label(root, "QuietZoneLabel", "FOCUS AREA  /  KEEP IT DOWN", Vector3(7.1, 2.75, -8.42), "#e9e4d6")
    _box(root, "StudyWasteBin", Vector3(10.25, 0.38, 7.0), Vector3(0.48, 0.72, 0.48), book_teal)
    _box(root, "StudyBinRim", Vector3(10.25, 0.76, 7.0), Vector3(0.52, 0.07, 0.52), dark)
    _cylinder(root, "StudyCornerPlantPot", Vector3(-10.35, 0.25, 7.1), 0.25, 0.5, book_rust)
    for leaf in range(4):
        _ball(root, "StudyCornerPlantLeaf_%d" % leaf,
            Vector3(-10.35 + cos(float(leaf) * TAU / 4.0) * 0.16, 0.75 + float(leaf % 2) * 0.12, 7.1 + sin(float(leaf) * TAU / 4.0) * 0.16),
            0.24, plant_green)


static func decorate_recreation(room: Node3D) -> void:
    if room.has_node("RecreationLifePropsM24"):
        return
    var root := Node3D.new()
    root.name = "RecreationLifePropsM24"
    room.add_child(root)

    var metal := _mat("#53646b")
    var bright := _mat("#d2aa68")
    var blue := _mat("#6e96a5")
    var red := _mat("#bc766b")
    var paper := _mat("#e7e0d1")
    var dark := _mat("#3d4b52")
    var green := _mat("#67866e")

    # Equipment storage remains along the side wall, outside the playing lane.
    _box(root, "SportsBallRackBase", Vector3(-10.25, 0.14, -3.9), Vector3(0.78, 0.24, 4.6), metal)
    for i in range(5):
        _ball(root, "SportsBall_%02d" % i, Vector3(-10.25, 0.42, -5.35 + float(i) * 0.72),
            0.22, bright if i % 2 == 0 else blue)
    _box(root, "SportsLocker", Vector3(-10.35, 1.25, 1.05), Vector3(0.95, 2.35, 1.55), dark)
    for level in [0.65, 1.3, 1.95]:
        _box(root, "LockerVent", Vector3(-9.85, level, 1.05), Vector3(0.035, 0.035, 0.75), metal)

    # Rackets and training cones are displayed beside the equipment locker.
    for i in range(2):
        var z: float = 0.25 + float(i) * 0.55
        _rod(root, "RacketHandle_%d" % i, Vector3(-9.75, 1.3, z), Vector3(-9.75, 1.72, z), 0.035, metal)
        var ring := _ball(root, "RacketHead_%d" % i, Vector3(-9.75, 1.9, z), 0.22, blue if i == 0 else red)
        ring.scale = Vector3(0.72, 1.0, 0.18)
    for i in range(3):
        _box(root, "TrainingCone_%02d" % i, Vector3(10.2, 0.2, -7.2 + float(i) * 0.58),
            Vector3(0.28, 0.4, 0.28), red)

    # A compact social table occupies the side bay; it does not touch the main court.
    _box(root, "ClubGameTable", Vector3(-8.0, 0.82, 2.0), Vector3(1.8, 0.14, 1.25), bright)
    for x_offset in [-0.72, 0.72]:
        for z_offset in [-0.42, 0.42]:
            _box(root, "ClubTableLeg", Vector3(-8.0 + x_offset, 0.4, 2.0 + z_offset),
                Vector3(0.08, 0.8, 0.08), metal)
    # Small checker pattern and pieces make the board readable at player scale.
    for x in range(4):
        for z in range(4):
            _box(root, "ChessTile_%d_%d" % [x, z],
                Vector3(-8.48 + float(x) * 0.24, 0.902, 1.76 + float(z) * 0.24),
                Vector3(0.24, 0.018, 0.24), paper if (x + z) % 2 == 0 else dark)
    for i in range(8):
        _ball(root, "ChessPiece_%02d" % i,
            Vector3(-8.35 + float(i % 4) * 0.24, 0.97, 1.87 + float(i / 4) * 0.24),
            0.055, metal if i < 4 else red)
    _box(root, "CardDeckBox", Vector3(-7.35, 0.94, 2.18), Vector3(0.24, 0.07, 0.32), red)
    for i in range(3):
        var card := _box(root, "LooseCard_%d" % i, Vector3(-7.55 + float(i) * 0.08, 0.91 + float(i) * 0.014, 1.72),
            Vector3(0.18, 0.012, 0.26), paper)
        card.rotation.y = float(i) * 0.14

    # Bottle and towel details on the existing spectator benches.
    for i in range(4):
        _cylinder(root, "SpectatorBottle_%d" % i,
            Vector3(6.9 + float(i % 2) * 1.15, 0.81, 4.0 + float(i / 2) * 0.42),
            0.075, 0.28, blue)
    _box(root, "FoldedSportsTowel", Vector3(-7.7, 0.72, 4.0), Vector3(0.62, 0.08, 0.34), paper)
    _box(root, "SRCClubPoster", Vector3(0.0, 2.65, -8.38), Vector3(3.0, 1.25, 0.05), blue)
    _label(root, "SRCClubPosterText", "CLUB NIGHT  /  PLAY FAIR", Vector3(0.0, 2.68, -8.33))
    _label(root, "SRCScoreLabel", "FRIENDLY MATCH  /  00 : 00", Vector3(0.0, 3.45, -8.32), "#f0e4c9")
    _box(root, "SportsNoticeStrip", Vector3(-7.0, 2.6, -8.35), Vector3(3.2, 1.1, 0.05), dark)
    _label(root, "SportsNoticeText", "RETURN EQUIPMENT\nAFTER USE", Vector3(-7.0, 2.65, -8.29), "#e7e0d1")
