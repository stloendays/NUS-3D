extends RefCounted
class_name UTownInteriorDetails
## Original, illustrative UTown room finishing kit; not NUS architectural plans.
## All geometry uses primitive meshes and low-cost lights so Windows OpenGL works.

static func _mat(hex: String, rough: float = 0.86, emission: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color.html(hex)
    material.roughness = rough
    if emission > 0.0:
        material.emission_enabled = true
        material.emission = Color.html(hex)
        material.emission_energy_multiplier = emission
    return material

static func _box(parent: Node3D, name: String, point: Vector3, size: Vector3, material: Material, solid: bool = false) -> Node3D:
    var root := Node3D.new()
    root.name = name
    root.position = point
    parent.add_child(root)
    var mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.material_override = material
    root.add_child(mesh)
    if solid:
        var physics := StaticBody3D.new()
        root.add_child(physics)
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        physics.add_child(collision)
    return root

static func _sign(parent: Node3D, label_text: String, at: Vector3, size: int = 25) -> void:
    var sign := Label3D.new()
    sign.text = label_text
    sign.position = at
    sign.font_size = size
    sign.pixel_size = 0.013
    sign.outline_size = 5
    sign.modulate = Color.html("#eaf4ef")
    parent.add_child(sign)

static func _lamp(parent: Node3D, at: Vector3, warm: bool) -> void:
    var diffuser := _mat("#f4dcb2" if warm else "#d5e9f1", 0.45, 0.45)
    _box(parent, "RecessedLight", at, Vector3(2.15, 0.065, 0.48), diffuser)
    var light := OmniLight3D.new()
    light.name = "InteriorSoftLight"
    light.position = at + Vector3(0, -0.22, 0)
    light.light_color = Color.html("#ffdfb4" if warm else "#dbe9ff")
    light.light_energy = 0.34
    light.omni_range = 10.0
    light.shadow_enabled = false
    parent.add_child(light)

static func _planter(parent: Node3D, at: Vector3) -> void:
    var pot := _mat("#9f785d")
    var foliage := _mat("#467a60")
    var foliage_tip := _mat("#71a185")
    var pot_mesh := MeshInstance3D.new()
    pot_mesh.name = "PlantPot"
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.36
    cylinder.bottom_radius = 0.27
    cylinder.height = 0.54
    pot_mesh.mesh = cylinder
    pot_mesh.material_override = pot
    pot_mesh.position = at + Vector3(0, 0.27, 0)
    parent.add_child(pot_mesh)
    for i in range(5):
        var leaf := MeshInstance3D.new()
        var leaf_mesh := SphereMesh.new()
        leaf_mesh.radius = 0.42
        leaf_mesh.height = 0.84
        leaf.mesh = leaf_mesh
        leaf.position = at + Vector3(
            cos(float(i) * TAU / 5.0) * 0.22,
            0.94 + float(i % 2) * 0.17,
            sin(float(i) * TAU / 5.0) * 0.22
        )
        leaf.scale = Vector3(0.68, 1.45, 0.68)
        leaf.material_override = foliage_tip if i % 2 == 0 else foliage
        parent.add_child(leaf)

static func _soft_chair(parent: Node3D, name: String, at: Vector3, fabric: Material) -> void:
    var legs := _mat("#394b53")
    _box(parent, name + "_Seat", at + Vector3(0, 0.43, 0), Vector3(0.9, 0.2, 0.92), fabric, true)
    _box(parent, name + "_Back", at + Vector3(0, 0.84, -0.38), Vector3(0.9, 0.8, 0.19), fabric)
    for side in [-0.35, 0.35]:
        _box(parent, name + "_Leg", at + Vector3(side, 0.2, 0), Vector3(0.065, 0.4, 0.065), legs)

static func decorate(room: Node3D, id: String) -> Array[Dictionary]:
    var finish := Node3D.new()
    finish.name = "InteriorFinishM34"
    room.add_child(finish)
    var trim := _mat("#415861")
    var ceiling := _mat("#617884")
    var soffit := _mat("#aabbb9")
    var glazing := _mat("#84b6c0", 0.25)
    var accent := _mat("#caac80")
    var carpet := _mat("#607c82", 0.96)

    # An opaque roof fixes the earlier blown-out, directly sunlit room renders.
    # Warm artificial skylight panels create readable contrast without PBR/HDR assets.
    _box(finish, "OpaqueRoofShadow", Vector3(0, 6.7, 0), Vector3(24.2, 0.24, 18.2), ceiling, true)
    _box(finish, "RoofCentralSoffit", Vector3(0, 6.47, 0), Vector3(22.5, 0.08, 6.8), soffit)
    for z in [-4.7, 0.0, 4.7]:
        _box(finish, "SkylightDiffuser", Vector3(0, 6.40, z), Vector3(10.2, 0.055, 1.1), _mat("#b4d3d7", 0.3, 0.16))
    for x in [-7.5, 0.0, 7.5]:
        for z in [-2.5, 3.0]:
            _lamp(finish, Vector3(x, 6.27, z), id == "ERC")

    # A distinct central aisle, non-blocking floor graphics and softer color
    # zones make both rooms readable from the first-person entrance.
    _box(finish, "MainCirculationStrip", Vector3(0, 0.014, 1.8), Vector3(2.55, 0.024, 12.5), carpet)
    for z in [-3.4, 0.9, 5.1]:
        _box(finish, "AisleInlay", Vector3(0, 0.031, z), Vector3(2.55, 0.018, 0.05), accent)
    for x in [-10.25, 10.25]:
        for z in [-2.4, 3.6]:
            _planter(finish, Vector3(x, 0.0, z))
    # Faux glazed display panels are labelled interior concepts; there is no
    # claim that the exterior pocket is a surveyed campus building.
    for x in [-5.6, 5.6]:
        _box(finish, "WindowFrame", Vector3(x, 4.28, -8.68), Vector3(4.7, 2.2, 0.12), trim)
        _box(finish, "WindowPane", Vector3(x, 4.28, -8.55), Vector3(4.45, 1.95, 0.07), glazing)

    _sign(finish, "GROUND LEVEL    |    MEZZANINE ABOVE", Vector3(0, 5.85, 8.65), 22)
    _sign(finish, "STAIRS", Vector3(9.2, 2.45, 4.7), 20)
    var activities: Array[Dictionary] = []
    if id == "ERC":
        var wood := _mat("#a37c59")
        var teal := _mat("#587d82")
        var upholstery := _mat("#668b84")
        # Coffee and welcome counter: kept off the central corridor.
        _box(finish, "ERC_CafeCounter", Vector3(-8.15, 0.79, 5.45), Vector3(3.0, 1.05, 1.15), wood, true)
        _box(finish, "ERC_CafeTop", Vector3(-8.15, 1.36, 5.45), Vector3(3.4, 0.12, 1.38), accent)
        _box(finish, "ERC_MenuDisplay", Vector3(-8.25, 2.65, 8.65), Vector3(3.4, 1.2, 0.12), teal)
        _sign(finish, "CAFE + WATER", Vector3(-8.25, 2.68, 8.53), 22)
        for x in [-9.0, -7.75, -6.5]:
            var cup := MeshInstance3D.new()
            var cup_mesh := CylinderMesh.new()
            cup_mesh.top_radius = 0.13
            cup_mesh.bottom_radius = 0.09
            cup_mesh.height = 0.22
            cup.mesh = cup_mesh
            cup.position = Vector3(x, 1.51, 5.45)
            cup.material_override = _mat("#e2e7dc")
            finish.add_child(cup)
        # Quiet reading nook and lounge: separate from the interactive cafe.
        _box(finish, "ERC_LoungeRug", Vector3(7.5, 0.02, 5.6), Vector3(4.4, 0.035, 3.4), _mat("#6f8d84"))
        _soft_chair(finish, "ERC_LoungeChairA", Vector3(6.2, 0.0, 5.7), upholstery)
        _soft_chair(finish, "ERC_LoungeChairB", Vector3(8.65, 0.0, 5.7), upholstery)
        _box(finish, "ERC_LoungeCoffeeTable", Vector3(7.45, 0.48, 4.2), Vector3(1.4, 0.12, 0.68), wood, true)
        _box(finish, "ERC_QuietNotice", Vector3(8.9, 2.0, -8.65), Vector3(3.7, 1.65, 0.12), teal)
        _sign(finish, "QUIET ZONE", Vector3(8.9, 2.2, -8.52), 24)
        # Upstairs study niches that deliberately avoid the lift landing.
        for x in [-6.7, -3.4, 3.4, 6.7]:
            _box(finish, "ERC_MezzanineTaskLamp", Vector3(x, 4.62, -6.15), Vector3(0.85, 0.06, 0.18), _mat("#f3d7ad", 0.4, 0.55))
        activities = [
            {"id":"cafe", "name":"Cafe corner", "position":Vector3(-6.0, 0.18, 5.5), "text":"A short coffee break. This is a fictional UTown cafe concept."},
            {"id":"reading", "name":"Reading nook", "position":Vector3(6.0, 0.18, 5.4), "text":"Take a quiet reading break in the original study-lounge concept."},
            {"id":"mezzanine", "name":"Mezzanine study", "position":Vector3(1.8, 3.55, -6.5), "text":"You found the elevated quiet study area."}
        ]
    else:
        var court := _mat("#467781")
        var timber := _mat("#b68c60")
        var blue := _mat("#668ca7")
        _box(finish, "SRC_ActivityStripe", Vector3(0, 0.042, -1.35), Vector3(9.6, 0.028, 0.14), court)
        # Indoor sports equipment wall; independent from gameplay physics.
        _box(finish, "SRC_EquipmentWall", Vector3(-9.4, 1.55, -5.8), Vector3(2.9, 2.5, 0.3), court)
        for i in range(4):
            var ball := MeshInstance3D.new()
            var sphere := SphereMesh.new()
            sphere.radius = 0.24
            ball.mesh = sphere
            ball.material_override = blue if i % 2 == 0 else timber
            ball.position = Vector3(-9.4 + float(i % 2) * 0.92 - 0.46, 1.0 + float(i / 2) * 0.78, -5.53)
            finish.add_child(ball)
        _box(finish, "SRC_WaterStation", Vector3(-9.1, 0.93, 5.3), Vector3(2.1, 1.65, 0.7), blue, true)
        _box(finish, "SRC_WaterCounter", Vector3(-9.1, 1.8, 5.3), Vector3(2.35, 0.13, 0.92), timber)
        _sign(finish, "REFILL STATION", Vector3(-9.1, 2.85, 5.38), 18)
        _box(finish, "SRC_SpectatorRug", Vector3(7.6, 0.022, 5.0), Vector3(4.2, 0.035, 3.3), court)
        _soft_chair(finish, "SRC_SpectatorSeatA", Vector3(6.5, 0.0, 5.2), blue)
        _soft_chair(finish, "SRC_SpectatorSeatB", Vector3(8.6, 0.0, 5.2), blue)
        _box(finish, "SRC_MezzanineBanner", Vector3(0, 4.7, -8.64), Vector3(5.6, 0.8, 0.1), court)
        _sign(finish, "VIEWING GALLERY", Vector3(0, 4.72, -8.48), 24)
        activities = [
            {"id":"refill", "name":"Water refill", "position":Vector3(-7.0, 0.18, 5.3), "text":"Water refill completed. The station is an illustrative game prop."},
            {"id":"warmup", "name":"Warm-up area", "position":Vector3(0.0, 0.18, -1.6), "text":"Warm-up stop recorded in the original SRC recreation concept."},
            {"id":"viewing", "name":"Viewing gallery", "position":Vector3(1.8, 3.55, -6.5), "text":"You reached the second-floor gallery overlooking the hall."}
        ]
    for activity in activities:
        var marker := Marker3D.new()
        marker.name = "Activity_" + str(activity["id"])
        marker.position = activity["position"]
        finish.add_child(marker)
    return activities
