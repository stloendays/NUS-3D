extends RefCounted
## Compact illustrative rooms for existing UTown buildings.
## Coordinates are derived from the same building data as exterior massing.
## These are game interpretations, NOT measured NUS floor plans.

static func _mat(hex: String) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color.html(hex)
    m.roughness = 0.88
    return m


static func _box(parent: Node3D, label: String, pos: Vector3, size: Vector3, mat: Material, solid: bool = false) -> void:
    var instance := MeshInstance3D.new()
    instance.name = label
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.position = pos
    instance.material_override = mat
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(instance)
    if solid:
        var body := StaticBody3D.new()
        instance.add_child(body)
        var shape := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = size
        shape.shape = box
        body.add_child(shape)


static func _label(parent: Node3D, text: String, pos: Vector3) -> void:
    var label := Label3D.new()
    label.text = text
    label.position = pos
    label.font_size = 34
    label.pixel_size = 0.004
    label.modulate = Color.html("#263e47")
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    parent.add_child(label)


static func decorate(room: Node3D, kind: String) -> void:
    var wood := _mat("#c4a88a")
    var ink := _mat("#405360")
    var soft := _mat("#7aa8a0")
    var paper := _mat("#e7e5dc")
    var highlight := _mat("#e6b67b")
    var glass := _mat("#a6c7ca")
    _box(room, "Ceiling", Vector3(0, 6.45, 0), Vector3(24, 0.2, 18), paper)
    for x in [-7.0, 0.0, 7.0]:
        _box(room, "CeilingLight", Vector3(x, 6.25, 0), Vector3(2.0, 0.07, 0.4), highlight)
    match kind:
        "CREATE_TOWER":
            _label(room, "CREATE  |  RESEARCH LAB", Vector3(0, 2.7, -8.4))
            for x in [-7.0, -2.0, 3.0, 8.0]:
                for z in [-4.0, 1.0]:
                    _box(room, "LabBench", Vector3(x, 0.9, z), Vector3(3.0, 0.15, 1.25), wood, true)
                    _box(room, "BenchSupport", Vector3(x, 0.44, z), Vector3(0.18, 0.9, 1.0), ink)
                    _box(room, "Instrument", Vector3(x - 0.6, 1.18, z), Vector3(0.6, 0.4, 0.5), glass)
            _box(room, "Whiteboard", Vector3(0, 2.1, -8.65), Vector3(4.6, 1.7, 0.1), paper)
            _label(room, "LAB SAFETY FIRST", Vector3(-8.0, 2.3, 8.5))
        "UTR_N", "UTR_S":
            _label(room, "UTOWN RESIDENCE  |  COMMON ROOM", Vector3(0, 2.7, -8.4))
            for x in [-7.0, 0.0, 7.0]:
                _box(room, "SofaSeat", Vector3(x, 0.45, -2.0), Vector3(3.1, 0.8, 1.2), soft, true)
                _box(room, "SofaBack", Vector3(x, 0.92, -2.55), Vector3(3.1, 0.8, 0.25), soft)
                _box(room, "CoffeeTable", Vector3(x, 0.46, 0.4), Vector3(2.1, 0.16, 1.0), wood, true)
            for x in [-7.5, -2.5, 2.5, 7.5]:
                _box(room, "StudyDesk", Vector3(x, 0.78, -6.5), Vector3(2.4, 0.13, 0.8), wood, true)
                _box(room, "Laptop", Vector3(x, 0.94, -6.5), Vector3(0.65, 0.1, 0.45), ink)
            _label(room, "QUIET HOURS AFTER 11 PM", Vector3(0, 2.2, 8.5))
        "TEMBUSU", "CAPT":
            _label(room, "RESIDENTIAL COLLEGE  |  STUDY LOUNGE", Vector3(0, 2.7, -8.4))
            for x in [-7.0, 0.0, 7.0]:
                for z in [-4.0, 1.0]:
                    _box(room, "SeminarTable", Vector3(x, 0.86, z), Vector3(3.4, 0.15, 1.4), wood, true)
                    for side in [-1.0, 1.0]:
                        _box(room, "Chair", Vector3(x, 0.45, z + side * 1.1), Vector3(0.65, 0.7, 0.65), soft)
            _box(room, "PresentationScreen", Vector3(0, 2.5, -8.6), Vector3(4.4, 2.0, 0.1), paper)
            _label(room, "GROUP PROJECT: DUE TOMORROW", Vector3(0, 2.1, 8.5))
