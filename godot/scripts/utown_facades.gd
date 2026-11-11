extends RefCounted
## M2 provisional, non-colliding architectural details for two P0 landmarks.
## Facts such as ERC curved glass and SRC's forum disc have public references;
## all numeric sizing and placements here remain artistic estimates.
## No photos, textures, meshes or university branding are imported.

static func _material(hex: String, roughness: float = 0.75, metalness: float = 0.0) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color.html(hex)
    material.roughness = roughness
    material.metallic = metalness
    return material

static func _box(parent: Node3D, title: String, location: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
    var item: MeshInstance3D = MeshInstance3D.new()
    item.name = title
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = dimensions
    item.mesh = mesh
    item.material_override = material
    item.position = location
    parent.add_child(item)
    return item

static func _disc(parent: Node3D, radius: float, elevation: float, material: Material) -> void:
    var top: MeshInstance3D = MeshInstance3D.new()
    top.name = "ElevatedMetalDisc_Estimated"
    var disc: CylinderMesh = CylinderMesh.new()
    disc.top_radius = radius
    disc.bottom_radius = radius + 0.4
    disc.height = 0.55
    disc.radial_segments = 48
    top.mesh = disc
    top.position = Vector3(0.0, elevation, 0.0)
    top.material_override = material
    parent.add_child(top)

static func _erc_wing(wing: Node3D, part: Dictionary, estimates: Dictionary, main_wing: bool) -> void:
    var w: float = float(part.get("w", 25.0))
    var d: float = float(part.get("d", 25.0))
    var h: float = float(part.get("h", 12.0))
    var pitch: float = float(estimates.get("storey_pitch", 3.45))
    var spacing: float = float(estimates.get("mullion_spacing", 3.2))
    var proj: float = float(estimates.get("canopy_projection", 2.0))

    var glass: Material = _material("#65919e", 0.23, 0.12)
    var white: Material = _material("#c9d1ce")
    var silver: Material = _material("#aab6b8", 0.38, 0.4)
    var inset: Material = _material("#344d58", 0.32)

    # Front glazing bands and deep horizontal white sunshades.
    for level in range(1, 4):
        var y: float = float(level) * pitch
        if y + 0.95 >= h:
            break
        _box(wing, "GlazedBand_Front", Vector3(0.0, y + 0.12, d * 0.5 + 0.11), Vector3(w - 1.5, 1.95, 0.17), glass)
        _box(wing, "GlazedBand_East", Vector3(w * 0.5 + 0.11, y + 0.12, 0.0), Vector3(0.17, 1.95, d - 1.5), glass)
        _box(wing, "WhiteSunshade_Front", Vector3(0.0, y + 1.20, d * 0.5 + proj * 0.32), Vector3(w + 0.8, 0.25, proj), white)
        _box(wing, "WhiteSunshade_East", Vector3(w * 0.5 + proj * 0.32, y + 1.20, 0.0), Vector3(proj, 0.25, d + 0.8), white)

    var panel_count: int = maxi(4, int(w / spacing))
    for i in range(1, panel_count):
        var x: float = -w * 0.5 + w * float(i) / float(panel_count)
        _box(wing, "VerticalMullion_Front", Vector3(x, h * 0.52, d * 0.5 + 0.24), Vector3(0.13, h * 0.71, 0.18), silver)

    # Raised canopy and visible vertical columns are illustrative, not surveyed.
    _box(wing, "EntranceCanopy", Vector3(0.0, 3.28, d * 0.5 + proj * 0.53), Vector3(minf(w * 0.55, 21.0), 0.27, proj * 2.0), white)
    for i in range(4):
        var bx: float = -w * 0.26 + w * 0.17 * float(i)
        _box(wing, "EntranceColumn", Vector3(bx, 1.58, d * 0.5 + proj * 1.3), Vector3(0.23, 3.05, 0.23), silver)

    if not main_wing:
        return
    var curved: Node3D = Node3D.new()
    curved.name = "ERC_CurvedGlazing_Study"
    wing.add_child(curved)
    var radius: float = float(estimates.get("arc_radius", 4.8))
    var center_x: float = w * 0.20
    var center_z: float = d * 0.5 - 1.45
    var segments: int = 12
    for step in range(segments):
        var angle: float = PI * (float(step) + 0.5) / float(segments)
        var panel: MeshInstance3D = _box(curved, "FacetedGlassPanel",
            Vector3(center_x + radius * cos(angle), minf(h * 0.52, 6.5), center_z + radius * sin(angle)),
            Vector3(2.0 * PI * radius / float(segments) * 0.97, minf(h * 0.58, 7.1), 0.16), inset)
        panel.rotation.y = angle - PI * 0.5
    _box(wing, "CurvedBayUpperCap", Vector3(center_x, h - 0.43, d * 0.5 + radius * 0.38),
         Vector3(radius * 2.7, 0.31, radius * 0.65), white)

static func _src_wing(wing: Node3D, part: Dictionary, estimates: Dictionary) -> void:
    var w: float = float(part.get("w", 25.0))
    var d: float = float(part.get("d", 25.0))
    var h: float = float(part.get("h", 12.0))
    var pitch: float = float(estimates.get("storey_pitch", 3.65))
    var spacing: float = float(estimates.get("mullion_spacing", 3.8))
    var glaze: Material = _material("#527d8b", 0.25, 0.08)
    var concrete: Material = _material("#c6ceca")
    var aluminium: Material = _material("#b9c4c8", 0.37, 0.32)

    # Continuous bands wrap toward the east-side forecourt.
    for level in range(1, 4):
        var y: float = float(level) * pitch
        if y + 1.0 >= h:
            break
        _box(wing, "SRC_Glass_East", Vector3(w * 0.5 + 0.10, y + 0.10, 0.0), Vector3(0.19, 1.95, d - 1.6), glaze)
        _box(wing, "SRC_Glass_South", Vector3(0.0, y + 0.10, d * 0.5 + 0.10), Vector3(w - 1.6, 1.95, 0.19), glaze)
        _box(wing, "SRC_Overhang_East", Vector3(w * 0.5 + 0.67, y + 1.15, 0.0), Vector3(1.45, 0.27, d + 1.0), concrete)
        _box(wing, "SRC_Overhang_South", Vector3(0.0, y + 1.15, d * 0.5 + 0.67), Vector3(w + 1.0, 0.27, 1.45), concrete)

    var count: int = maxi(3, int(d / spacing))
    for i in range(1, count):
        var z: float = -d * 0.5 + d * float(i) / float(count)
        _box(wing, "SRC_EastMullion", Vector3(w * 0.5 + 0.23, h * 0.52, z),
             Vector3(0.16, h * 0.65, 0.13), aluminium)

static func _src_forum(root: Node3D, parts: Array, estimates: Dictionary) -> void:
    var metallic: Material = _material("#aabbbf", 0.32, 0.45)
    var white: Material = _material("#cbd2ce")
    var radius: float = float(estimates.get("disc_radius", 10.5))
    var height: float = float(estimates.get("disc_elevation", 14.5))
    var forum: Node3D = Node3D.new()
    forum.name = "SRC_ForumDisc_Study"
    root.add_child(forum)
    _disc(forum, radius, height, metallic)
    for i in range(8):
        var theta: float = TAU * float(i) / 8.0
        _box(forum, "ForumColumn", Vector3(cos(theta) * radius * 0.72, height * 0.5 - 0.20,
             sin(theta) * radius * 0.72), Vector3(0.26, height - 0.65, 0.26), white)

    # An indicative upper-level connector between two masses; not a surveyed walking route.
    if parts.size() >= 2:
        var a: Dictionary = parts[0]
        var b: Dictionary = parts[1]
        var start: Vector3 = Vector3(float(a.get("dx", 0.0)), 7.65, -float(a.get("dn", 0.0)))
        var end: Vector3 = Vector3(float(b.get("dx", 0.0)), 7.65, -float(b.get("dn", 0.0)))
        var diff: Vector3 = end - start
        var bridge: MeshInstance3D = _box(root, "SRC_StackedLink_Study", (start + end) * 0.5,
            Vector3(float(estimates.get("linkway_width", 3.5)), 0.40, diff.length()), metallic)
        bridge.rotation.y = atan2(diff.x, diff.z)

static func build(parent: Node3D, record: Dictionary, profile: Dictionary) -> Node3D:
    var detail: Node3D = Node3D.new()
    detail.name = "ArchitecturalStudy_NotSurveyed"
    parent.add_child(detail)

    var estimates: Dictionary = profile.get("estimates_m", {})
    var parts: Array = record.get("parts", [])
    var kind: String = str(profile.get("style", ""))
    for i in range(parts.size()):
        var part: Dictionary = parts[i]
        var wing: Node3D = Node3D.new()
        wing.name = "StudyWing_%02d" % i
        wing.position = Vector3(float(part.get("dx", 0.0)), 0.0, -float(part.get("dn", 0.0)))
        detail.add_child(wing)
        if kind == "erc":
            _erc_wing(wing, part, estimates, i == 0)
        elif kind == "src":
            _src_wing(wing, part, estimates)

    if kind == "src":
        _src_forum(detail, parts, estimates)
    return detail
