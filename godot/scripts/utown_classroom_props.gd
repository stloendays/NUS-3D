extends RefCounted
class_name UTownClassroomProps
## Low-poly study/classroom set dressing. No new lights, textures or physics.
## Keep the 2.5 m central aisle and entrance/upper landing unobstructed.

static func _mat(color: String) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.html(color)
    material.roughness = 0.82
    return material

static func _box(parent: Node3D, name: String, p: Vector3, size: Vector3, material: Material) -> void:
    var mesh := MeshInstance3D.new()
    mesh.name = name
    var shape := BoxMesh.new()
    shape.size = size
    mesh.mesh = shape
    mesh.position = p
    mesh.material_override = material
    parent.add_child(mesh)

static func _label(parent: Node3D, text_value: String, p: Vector3, size: int = 20) -> void:
    var label := Label3D.new()
    label.name = "ClassroomLabel"
    label.text = text_value
    label.position = p
    label.font_size = size
    label.pixel_size = 0.009
    label.outline_size = 3
    label.modulate = Color("#e9f0ef")
    parent.add_child(label)

static func decorate(room: Node3D) -> void:
    var props := Node3D.new()
    props.name = "ClassroomPropsM15"
    room.add_child(props)
    var paper := _mat("#e8e2d3")
    var notebook := _mat("#577e91")
    var laptop := _mat("#48545f")
    var screen := _mat("#a9c4c9")
    var pencil := _mat("#d7ae61")
    var cup := _mat("#c98d78")
    var whiteboard := _mat("#e2eae7")
    var board_frame := _mat("#475d66")
    var bag := _mat("#9b6d69")
    var green := _mat("#73918c")

    # Teacher-facing whiteboard and compact projector display on the back wall.
    _box(props, "WhiteboardFrame", Vector3(0.0, 2.55, -8.35), Vector3(5.9, 2.0, 0.12), board_frame)
    _box(props, "Whiteboard", Vector3(0.0, 2.55, -8.27), Vector3(5.65, 1.76, 0.045), whiteboard)
    _box(props, "BoardMarkerTray", Vector3(0.0, 1.55, -8.10), Vector3(3.0, 0.06, 0.18), board_frame)
    _label(props, "NEXT: PRESENTATION / QUIZ", Vector3(0.0, 2.72, -8.22), 23)
    _box(props, "ProjectorHousing", Vector3(0.0, 5.85, -3.7), Vector3(0.7, 0.22, 0.55), laptop)
    _box(props, "ProjectorLens", Vector3(0.0, 5.85, -4.01), Vector3(0.18, 0.12, 0.05), screen)

    # Eight desk clusters; no clutter in the center circulation aisle.
    for ix in range(4):
        var x: float = [-7.0, -3.5, 3.5, 7.0][ix]
        for iz in range(2):
            var z: float = [-3.5, 0.9][iz]
            var seed: int = ix * 2 + iz
            _box(props, "Notebook_%02d" % seed, Vector3(x - 0.50, 1.023, z - 0.12),
                Vector3(0.42, 0.026, 0.30), notebook if seed % 2 == 0 else paper)
            _box(props, "NotebookPages_%02d" % seed, Vector3(x - 0.50, 1.042, z - 0.12),
                Vector3(0.36, 0.012, 0.25), paper)
            _box(props, "Pen_%02d" % seed, Vector3(x - 0.17, 1.045, z - 0.12),
                Vector3(0.018, 0.02, 0.29), pencil)
            if seed % 2 == 0:
                _box(props, "LaptopBase_%02d" % seed, Vector3(x + 0.38, 1.025, z + 0.06),
                    Vector3(0.57, 0.035, 0.39), laptop)
                _box(props, "LaptopScreen_%02d" % seed, Vector3(x + 0.38, 1.30, z - 0.12),
                    Vector3(0.57, 0.51, 0.035), laptop)
                _box(props, "LaptopDisplay_%02d" % seed, Vector3(x + 0.38, 1.30, z - 0.095),
                    Vector3(0.49, 0.42, 0.012), screen)
            else:
                _box(props, "CoffeeCup_%02d" % seed, Vector3(x + 0.48, 1.11, z + 0.20),
                    Vector3(0.16, 0.18, 0.16), cup)
                _box(props, "CoffeeLid_%02d" % seed, Vector3(x + 0.48, 1.21, z + 0.20),
                    Vector3(0.18, 0.025, 0.18), paper)
            # Backpacks tucked beneath desks rather than blocking walking paths.
            if seed % 3 == 0:
                _box(props, "Backpack_%02d" % seed, Vector3(x + 0.65, 0.28, z + 0.17),
                    Vector3(0.37, 0.48, 0.30), bag)

    # Small notice-board stationery; avoid another expensive 3D light.
    _box(props, "NoticeStickyA", Vector3(-1.5, 2.05, -8.40), Vector3(0.38, 0.38, 0.04), pencil)
    _box(props, "NoticeStickyB", Vector3(1.55, 2.0, -8.40), Vector3(0.38, 0.38, 0.04), green)
    _label(props, "SUBMIT BEFORE 23:59", Vector3(0.0, 2.20, -8.20), 16)
