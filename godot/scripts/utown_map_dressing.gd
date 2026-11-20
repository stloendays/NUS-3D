extends Node3D
class_name NUS3DMapDressing
## Decorative, collision-free art-direction layer; all positions are derived from
## the same schematic campus records. Deliberately avoids new geometry claims.
## Static, seeded, low-poly, shared mesh/material, bounded instances.
const MAX_BUSHES: int = 128
const MAX_BENCHES: int = 13
const MAX_TRASH_BINS: int = 8
const MAX_DISTRICT_TREES: int = 84
const MAX_PLAZA_PLANTERS: int = 4
const CAMPUS_SCATTERED_PROPS = preload("res://scripts/campus_scattered_props.gd")

@onready var world: UTownWorld = $"../World"
@onready var expansion: NUSKentRidgeWorld = $"../KentRidgeExpansion"

var path_edge_count: int = 0
var meadow_patch_count: int = 0
var bush_count: int = 0
var bench_count: int = 0
var trash_bin_count: int = 0
var bench_anchors: Array[Dictionary] = []
var district_tree_count: int = 0
var plaza_planter_count: int = 0
var grove_positions: Array[Vector3] = []
var bush_positions: Array[Vector3] = []
var _meshes: Dictionary = {}
var _materials: Dictionary = {}

func _ready() -> void:
    if world.layout.is_empty():
        return
    _build_path_edges()
    _build_meadow_islands()
    _build_verge_shrubs()
    _build_path_benches()
    _build_utown_trash_bins()
    _build_plaza_planters()
    _build_district_groves()
    var scatter_stats: Dictionary = CAMPUS_SCATTERED_PROPS.decorate(self, expansion, grove_positions)
    print("NUS3D_M25_SCATTER: %d clusters, %d props, %d batches, %d Kent Ridge benches, %d Kent Ridge bins, %d UTown bins" % [scatter_stats.get("cluster_count", 0), scatter_stats.get("item_count", 0), scatter_stats.get("batch_count", 0), scatter_stats.get("bench_count", 0), scatter_stats.get("trash_bin_count", 0), trash_bin_count])

func _material(tint: String, use_vertex_colors: bool = false) -> StandardMaterial3D:
    var key: String = tint + (":vertex" if use_vertex_colors else ":flat")
    if not _materials.has(key):
        var result: StandardMaterial3D = StandardMaterial3D.new()
        result.albedo_color = Color.html(tint)
        result.roughness = 0.92
        result.vertex_color_use_as_albedo = use_vertex_colors
        _materials[key] = result
    return _materials[key]

func _box_mesh(size_m: Vector3) -> BoxMesh:
    var key: String = str(size_m.snapped(Vector3.ONE * 0.001))
    if not _meshes.has(key):
        var mesh: BoxMesh = BoxMesh.new()
        mesh.size = size_m
        _meshes[key] = mesh
    return _meshes[key]

func _box(parent: Node3D, title: String, at: Vector3, size_m: Vector3, material: Material) -> MeshInstance3D:
    var node: MeshInstance3D = MeshInstance3D.new()
    node.name = title
    node.mesh = _box_mesh(size_m)
    node.material_override = material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    node.position = at
    parent.add_child(node)
    return node

func _batch(name_value: String, mesh: Mesh, material: Material,
        transforms: Array[Transform3D], colors: Array[Color]) -> void:
    if transforms.is_empty():
        return
    var multi: MultiMesh = MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.mesh = mesh
    multi.instance_count = transforms.size()
    var root: MultiMeshInstance3D = MultiMeshInstance3D.new()
    root.name = name_value
    root.multimesh = multi
    root.material_override = material
    root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(root)
    for i in range(transforms.size()):
        multi.set_instance_transform(i, transforms[i])
        multi.set_instance_color(i, colors[i])

func _outside_walkways_and_buildings(point: Vector2, room_m: float = 4.0) -> bool:
    if not world.is_tree_position_clear(point, room_m):
        return false
    for tree in world.generated_tree_positions:
        if Vector2(tree.x, tree.z).distance_to(point) < 4.0:
            return false
    return true

func _build_path_edges() -> void:
    # The warm-colour path border is slightly below existing walking geometry:
    # it is a visible visual curb, not a duplicate solid walkway collider.
    var root: Node3D = Node3D.new()
    root.name = "CreamWalkwayEdgeInsets_NoCollision"
    add_child(root)
    var edge: Material = _material("#9DB3A6")
    for way in world.layout.get("walkways", []):
        var points: Array = way.get("lonlat", [])
        var width_m: float = float(way.get("width_m", 3.5))
        for i in range(points.size() - 1):
            var a: Vector3 = world.lonlat_to_world(float(points[i][0]), float(points[i][1]))
            var b: Vector3 = world.lonlat_to_world(float(points[i + 1][0]), float(points[i + 1][1]))
            var delta: Vector3 = b - a
            if delta.length() < 0.25:
                continue
            var strip: MeshInstance3D = _box(root, "PathEdge_%02d" % path_edge_count,
                (a + b) * 0.5 + Vector3(0.0, 0.020, 0.0),
                Vector3(width_m + 0.95, 0.038, delta.length() + 0.25), edge)
            strip.rotation.y = atan2(delta.x, delta.z)
            path_edge_count += 1

func _build_meadow_islands() -> void:
    # Breaks up empty turf: subtle irregular low-poly tree-base ground patches
    # are GPU-instanced and stay under the existing vegetation anchors.
    var disk: CylinderMesh = CylinderMesh.new()
    disk.top_radius = 1.0
    disk.bottom_radius = 1.0
    disk.height = 0.018
    disk.radial_segments = 9
    var seed: RandomNumberGenerator = RandomNumberGenerator.new()
    seed.seed = 2026111951
    var matrices: Array[Transform3D] = []
    var tints: Array[Color] = []
    var palette: PackedStringArray = ["#9AC28D", "#8FB684", "#A5C69A", "#94BD8F"]
    for position_value in world.generated_tree_positions:
        var radius: float = seed.randf_range(2.4, 3.9)
        var foundation: Vector3 = Vector3(position_value.x, 0.038, position_value.z)
        matrices.append(Transform3D(
            Basis(Vector3.UP, seed.randf_range(0, TAU)).scaled(Vector3(radius, 1.0, radius)),
            foundation))
        tints.append(Color.html(palette[seed.randi_range(0, palette.size() - 1)]))
    meadow_patch_count = matrices.size()
    _batch("MeadowIslands_OneDrawCall", disk, _material("#FFFFFF", true), matrices, tints)

func _build_verge_shrubs() -> void:
    var blob: SphereMesh = SphereMesh.new()
    blob.radius = 0.80
    blob.height = 1.30
    blob.radial_segments = 7
    blob.rings = 4
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 2026111952
    var matrix: Array[Transform3D] = []
    var colors: Array[Color] = []
    var palette: PackedStringArray = ["#54896C", "#76A577", "#82AC78", "#668C67", "#97AD74"]
    for way in world.layout.get("walkways", []):
        if matrix.size() >= MAX_BUSHES:
            break
        var points: Array = way.get("lonlat", [])
        var half_width: float = float(way.get("width_m", 3.5)) * 0.5
        for segment_index in range(points.size() - 1):
            var a: Vector3 = world.lonlat_to_world(float(points[segment_index][0]), float(points[segment_index][1]))
            var b: Vector3 = world.lonlat_to_world(float(points[segment_index + 1][0]), float(points[segment_index + 1][1]))
            var delta: Vector2 = Vector2(b.x - a.x, b.z - a.z)
            var length_m: float = delta.length()
            if length_m < 12.0:
                continue
            var normal: Vector2 = Vector2(-delta.y, delta.x) / length_m
            var travel: float = 7.0
            while travel < length_m - 5.0 and matrix.size() < MAX_BUSHES:
                var side: float = -1.0 if rng.randf() < 0.5 else 1.0
                var origin: Vector2 = Vector2(a.x, a.z) + delta * (travel / length_m)
                var candidate: Vector2 = origin + normal * side * (half_width + rng.randf_range(4.3, 6.7))
                travel += rng.randf_range(8.0, 15.0)
                if not _outside_walkways_and_buildings(candidate, 4.5):
                    continue
                var too_close: bool = false
                for last in bush_positions:
                    if Vector2(last.x, last.z).distance_to(candidate) < 2.0:
                        too_close = true
                        break
                if too_close:
                    continue
                var factor: float = rng.randf_range(0.75, 1.55)
                var at: Vector3 = Vector3(candidate.x, 0.62 * factor, candidate.y)
                bush_positions.append(at)
                matrix.append(Transform3D(Basis().scaled(Vector3(factor, factor, factor)), at))
                colors.append(Color.html(palette[rng.randi_range(0, palette.size() - 1)]))
    bush_count = matrix.size()
    _batch("CampusShrubs_BatchedLowPoly", blob, _material("#FFFFFF", true), matrix, colors)

func _build_path_benches() -> void:
    # Lived-in but unobtrusive seating; no solid collider or giant wayfinding
    # sign. These retain the exact footpath geometry and free movement.
    var seats: Node3D = Node3D.new()
    seats.name = "CampusBenches_NoCollision"
    add_child(seats)
    var timber: Material = _material("#AE8267")
    var dark_wood: Material = _material("#76594E")
    var legs: Material = _material("#4A6665")
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 2026111953
    var locations: Array[Vector2] = []
    for way in world.layout.get("walkways", []):
        if bench_count >= MAX_BENCHES:
            break
        var pts: Array = way.get("lonlat", [])
        var width: float = float(way.get("width_m", 3.5))
        for i in range(pts.size() - 1):
            if bench_count >= MAX_BENCHES:
                break
            var a: Vector3 = world.lonlat_to_world(float(pts[i][0]), float(pts[i][1]))
            var b: Vector3 = world.lonlat_to_world(float(pts[i + 1][0]), float(pts[i + 1][1]))
            var d: Vector2 = Vector2(b.x - a.x, b.z - a.z)
            if d.length() < 22.0:
                continue
            var normal: Vector2 = Vector2(-d.y, d.x).normalized()
            var mid: Vector2 = Vector2((a.x + b.x) * 0.5, (a.z + b.z) * 0.5)
            var side: float = -1.0 if rng.randf() > 0.5 else 1.0
            var at: Vector2 = mid + normal * side * (width * 0.5 + 5.2)
            if not _outside_walkways_and_buildings(at, 4.5):
                continue
            var conflict: bool = false
            for previous in locations:
                if previous.distance_to(at) < 18.0:
                    conflict = true
                    break
            if conflict:
                continue
            locations.append(at)
            bench_anchors.append({"position": at, "direction": d.normalized()})
            var bench: Node3D = Node3D.new()
            bench.name = "CurvedStudyBench_%02d" % bench_count
            bench.position = Vector3(at.x, 0.0, at.y)
            bench.rotation.y = atan2(d.x, d.y)
            seats.add_child(bench)
            _box(bench, "Seat", Vector3(0, 0.62, 0), Vector3(2.65, 0.17, 0.68), timber)
            _box(bench, "Back", Vector3(0, 1.05, -0.30), Vector3(2.65, 0.68, 0.14), timber)
            _box(bench, "BackTop", Vector3(0, 1.38, -0.30), Vector3(2.74, 0.06, 0.21), dark_wood)
            for x in [-1.10, 1.10]:
                _box(bench, "Frame", Vector3(x, 0.31, 0), Vector3(0.13, 0.62, 0.61), legs)
            bench_count += 1

func _build_utown_trash_bins() -> void:
    if bench_anchors.is_empty():
        return
    var body: CylinderMesh = CylinderMesh.new()
    body.top_radius = 0.34
    body.bottom_radius = 0.39
    body.height = 0.78
    body.radial_segments = 8
    var lid: CylinderMesh = CylinderMesh.new()
    lid.top_radius = 0.41
    lid.bottom_radius = 0.41
    lid.height = 0.07
    lid.radial_segments = 8

    var body_transforms: Array[Transform3D] = []
    var lid_transforms: Array[Transform3D] = []
    var body_colors: Array[Color] = []
    var lid_colors: Array[Color] = []
    var locations: Array[Vector2] = []
    var body_palette: PackedStringArray = ["#71877F", "#788D91", "#879B82"]
    var lid_palette: PackedStringArray = ["#D3B66F", "#6C9B86", "#779AA5"]
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 2026112051

    for index in range(bench_anchors.size()):
        if trash_bin_count >= MAX_TRASH_BINS:
            break
        var anchor: Dictionary = bench_anchors[index]
        var direction: Vector2 = anchor.get("direction", Vector2.RIGHT)
        var anchor_position: Vector2 = anchor.get("position", Vector2.ZERO)
        # Try either end of the bench before skipping it; the adjacent tree/building
        # layout differs along each walkway segment.
        var offsets: Array[Vector2] = [
            direction * 1.9, -direction * 1.9,
            direction * 2.35, -direction * 2.35
        ]
        for offset in offsets:
            if trash_bin_count >= MAX_TRASH_BINS:
                break
            var at: Vector2 = anchor_position + offset
            if not _outside_walkways_and_buildings(at, 3.0):
                continue
            var conflict: bool = false
            for previous in locations:
                if previous.distance_to(at) < 8.0:
                    conflict = true
                    break
            if conflict:
                continue

            var scale: float = rng.randf_range(0.92, 1.08)
            var yaw: float = rng.randf_range(0.0, TAU)
            var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
            body_transforms.append(Transform3D(basis, Vector3(at.x, 0.39 * scale, at.y)))
            lid_transforms.append(Transform3D(basis, Vector3(at.x, 0.80 * scale, at.y)))
            body_colors.append(Color.html(body_palette[trash_bin_count % body_palette.size()]))
            lid_colors.append(Color.html(lid_palette[trash_bin_count % lid_palette.size()]))
            locations.append(at)
            trash_bin_count += 1
            break

    if not body_transforms.is_empty():
        _batch("UTownTrashBins_Body_OneBatch", body, _material("#FFFFFF", true), body_transforms, body_colors)
        _batch("UTownTrashBins_Lid_OneBatch", lid, _material("#FFFFFF", true), lid_transforms, lid_colors)


func _build_plaza_planters() -> void:
    var plaza: Dictionary = world.layout.get("plaza", {})
    if plaza.is_empty():
        return
    var w: float = float(plaza.get("width_m", 44.0))
    var d: float = float(plaza.get("depth_m", 30.0))
    var planter_group: Node3D = Node3D.new()
    planter_group.name = "PlazaPocketGardens"
    planter_group.position = world.lonlat_to_world(float(plaza.get("lon", world.origin_lon)), float(plaza.get("lat", world.origin_lat)))
    planter_group.rotation.y = deg_to_rad(float(plaza.get("rotation_deg", 0.0)))
    add_child(planter_group)
    var pottery: Material = _material("#D1B49A")
    var greenery: Material = _material("#6E9979")
    var highlight: Material = _material("#E6C382")
    for xsign in [-1.0, 1.0]:
        for zsign in [-1.0, 1.0]:
            if plaza_planter_count >= MAX_PLAZA_PLANTERS:
                break
            var bush: Node3D = Node3D.new()
            bush.name = "PocketGarden_%d" % plaza_planter_count
            bush.position = Vector3(xsign * w * 0.39, 0.135, zsign * d * 0.35)
            planter_group.add_child(bush)
            _box(bush, "PlanterRim", Vector3(0, 0.21, 0), Vector3(2.2, 0.42, 1.75), pottery)
            _box(bush, "Soil", Vector3(0, 0.44, 0), Vector3(1.95, 0.06, 1.50), darken_soil())
            _box(bush, "GreenLeaves", Vector3(0, 0.75, 0), Vector3(1.58, 0.53, 1.10), greenery)
            _box(bush, "FlowerAccent", Vector3(0.43, 1.09, 0.18), Vector3(0.28, 0.17, 0.27), highlight)
            plaza_planter_count += 1

func darken_soil() -> StandardMaterial3D:
    return _material("#75685B")

func _canopy_mesh() -> SphereMesh:
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = 1.0
    mesh.height = 2.0
    mesh.radial_segments = 7
    mesh.rings = 4
    return mesh

func _build_district_groves() -> void:
    if expansion == null or expansion.districts.is_empty():
        return
    var stem: CylinderMesh = CylinderMesh.new()
    stem.top_radius = 0.22
    stem.bottom_radius = 0.36
    stem.height = 3.2
    stem.radial_segments = 7
    var crown: SphereMesh = _canopy_mesh()
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 2026111954
    var stems: Array[Transform3D] = []
    var stem_colors: Array[Color] = []
    var canopies: Array[Transform3D] = []
    var greens: Array[Color] = []
    var shades: PackedStringArray = ["#66986C", "#7AA97C", "#4E8368", "#83A576", "#97B989"]
    for district in expansion.districts:
        var center: Vector3 = district["position"]
        var size_arr: Array = district.get("size", [150, 140])
        var half_x: float = float(size_arr[0]) * 0.5
        var half_z: float = float(size_arr[1]) * 0.5
        var sites: Array[Vector2] = [
            Vector2(-0.78, -0.72), Vector2(0.78, -0.72),
            Vector2(-0.79, 0.72), Vector2(0.79, 0.72),
            Vector2(-0.72, -0.14), Vector2(0.73, 0.18),
            Vector2(-0.28, 0.76), Vector2(0.32, -0.76)
        ]
        for loc in sites:
            if stems.size() >= MAX_DISTRICT_TREES:
                break
            var local_point: Vector2 = Vector2(loc.x * half_x, loc.y * half_z)
            var overlaps: bool = false
            for landmark in district.get("landmarks", []):
                var offset: Array = landmark.get("offset", [0, 0])
                var dims: Array = landmark.get("size", [30, 25, 14])
                if absf(local_point.x - float(offset[0])) < float(dims[0]) * 0.5 + 6.0 and absf(local_point.y + float(offset[1])) < float(dims[1]) * 0.5 + 6.0:
                    overlaps = true
                    break
            var p: Vector3 = center + Vector3(local_point.x, 0.0, local_point.y)
            for stop in expansion.stops:
                var at: Vector3 = stop["position"]
                if Vector2(at.x, at.z).distance_to(Vector2(p.x, p.z)) < 15.0:
                    overlaps = true
                    break
            if overlaps:
                continue
            var size_factor: float = rng.randf_range(0.85, 1.24)
            var stem_at: Vector3 = p + Vector3(0, 1.6 * size_factor, 0)
            var top_at: Vector3 = p + Vector3(0, 4.0 * size_factor, 0)
            stems.append(Transform3D(Basis().scaled(Vector3(size_factor, size_factor, size_factor)), stem_at))
            canopies.append(Transform3D(
                Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(2.8, 2.2, 2.7) * size_factor),
                top_at))
            stem_colors.append(Color.html("#726653"))
            greens.append(Color.html(shades[rng.randi_range(0, shades.size() - 1)]))
            grove_positions.append(p)
    district_tree_count = stems.size()
    _batch("RidgeTrees_TrunksBatched", stem, _material("#FFFFFF", true), stems, stem_colors)
    _batch("RidgeTrees_CrownsBatched", crown, _material("#FFFFFF", true), canopies, greens)
