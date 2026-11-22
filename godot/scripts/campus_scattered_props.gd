extends RefCounted
class_name NUS3DCampusScatteredProps
## Seeded, collision-free everyday objects for the Kent Ridge campus extension.
## Primitive meshes and MultiMesh batches keep the detail budget predictable.

const GROUND_TOP_Y: float = 0.055
const BUILDING_CLEARANCE_M: float = 7.0
const WALKWAY_CLEARANCE_M: float = 7.0
const BUS_STOP_CLEARANCE_M: float = 13.0
const TREE_CLEARANCE_M: float = 6.0
const PLANTER_CLEARANCE_M: float = 6.0
const PROP_KINDS = ["paper", "notebook", "coffee", "bottle", "food", "bag", "ball", "shuttlecock", "bench", "trash_bin", "phone", "headphones", "folded_umbrella", "cardboard_box", "frisbee", "vending_machine", "vending_display", "vending_products", "vending_buttons", "picnic_table", "shade_umbrella", "umbrella_pole", "water_dispenser", "water_bottle", "water_tap", "water_tray"]

static func decorate(parent: Node3D, expansion: NUSKentRidgeWorld,
        tree_positions: Array[Vector3]) -> Dictionary:
    if parent == null or expansion == null or expansion.districts.is_empty():
        return {"cluster_count": 0, "item_count": 0, "batch_count": 0}

    var root: Node3D = Node3D.new()
    root.name = "KentRidgeScatteredEverydayProps_M25"
    parent.add_child(root)

    var transforms_by_kind: Dictionary = {}
    var colors_by_kind: Dictionary = {}
    for kind in PROP_KINDS:
        transforms_by_kind[kind] = []
        colors_by_kind[kind] = []

    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = 2026112001
    var cluster_count: int = 0
    var item_count: int = 0

    for district_value in expansion.districts:
        var district: Dictionary = district_value
        var district_id: String = str(district.get("id", ""))
        var theme: PackedStringArray = _theme_for(district_id)
        var sites: Array[Vector2] = _sites_for_district(district, expansion, tree_positions, rng)
        if theme.is_empty():
            continue

        for site_index in range(sites.size()):
            var item_total: int = 3 if site_index % 3 == 2 else 2
            var cluster_rotation: float = rng.randf_range(0.0, TAU)
            for item_index in range(item_total):
                var kind: String = theme[rng.randi_range(0, theme.size() - 1)]
                var offset: Vector2 = _item_offset(item_index).rotated(cluster_rotation)
                var local_position: Vector2 = sites[site_index] + offset
                if not _is_clear(local_position, district, expansion, tree_positions):
                    local_position = sites[site_index] + offset * 0.35
                if not _is_clear(local_position, district, expansion, tree_positions):
                    continue

                var scale: float = rng.randf_range(0.84, 1.12)
                var center: Vector3 = district.get("position", Vector3.ZERO)
                var world_position: Vector3 = Vector3(
                    center.x + local_position.x,
                    GROUND_TOP_Y + _half_height(kind) * scale,
                    center.z + local_position.y
                )
                var basis: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale)
                var instances: Array = transforms_by_kind[kind]
                instances.append(Transform3D(basis, world_position))
                var tints: Array = colors_by_kind[kind]
                tints.append(_random_tint(kind, rng))
                item_count += 1
            cluster_count += 1

        var occupied_positions: Array[Vector2] = []
        for site in sites:
            occupied_positions.append(site)
        item_count += _append_furniture(district, expansion, tree_positions, sites, transforms_by_kind, colors_by_kind, rng, occupied_positions)
        item_count += _append_amenities(district, expansion, tree_positions, transforms_by_kind, colors_by_kind, rng, occupied_positions)

    var shared_material: StandardMaterial3D = StandardMaterial3D.new()
    shared_material.albedo_color = Color.WHITE
    shared_material.vertex_color_use_as_albedo = true
    shared_material.roughness = 0.96

    var meshes: Dictionary = _make_meshes()
    for kind in PROP_KINDS:
        _create_batch(root, kind, meshes[kind], transforms_by_kind[kind], colors_by_kind[kind], shared_material)

    return {
        "cluster_count": cluster_count,
        "item_count": item_count,
        "batch_count": root.get_child_count(),
        "bench_count": transforms_by_kind["bench"].size(),
        "trash_bin_count": transforms_by_kind["trash_bin"].size(),
        "vending_machine_count": transforms_by_kind["vending_machine"].size(),
        "picnic_table_count": transforms_by_kind["picnic_table"].size(),
        "water_dispenser_count": transforms_by_kind["water_dispenser"].size()
    }


static func _sites_for_district(district: Dictionary, expansion: NUSKentRidgeWorld,
        tree_positions: Array[Vector3], rng: RandomNumberGenerator) -> Array[Vector2]:
    var sites: Array[Vector2] = []
    var district_id: String = str(district.get("id", ""))
    if district_id == "SPORTS":
        # Keep the track and playing surface open; place sports gear around the outer lawn.
        var sports_candidates: Array[Vector2] = [
            Vector2(-58, -56), Vector2(-58, 56),
            Vector2(-25, -56), Vector2(-25, 56),
            Vector2(25, -56), Vector2(25, 56),
            Vector2(58, -56), Vector2(58, 56)
        ]
        for candidate in sports_candidates:
            if _is_clear(candidate, district, expansion, tree_positions):
                sites.append(candidate)
        return sites

    var size_values: Array = district.get("size", [150, 140])
    var width_m: float = float(size_values[0])
    var depth_m: float = float(size_values[1])
    var quadrants: Array[Vector2] = [
        Vector2(-1, -1), Vector2(1, -1),
        Vector2(-1, 1), Vector2(1, 1)
    ]
    for quadrant in quadrants:
        var accepted: int = 0
        for attempt in range(128):
            var candidate: Vector2 = Vector2(
                quadrant.x * width_m * rng.randf_range(0.18, 0.44),
                quadrant.y * depth_m * rng.randf_range(0.18, 0.44)
            )
            if not _is_clear(candidate, district, expansion, tree_positions):
                continue
            var separated: bool = true
            for previous in sites:
                if previous.distance_to(candidate) < 11.0:
                    separated = false
                    break
            if not separated:
                continue
            sites.append(candidate)
            accepted += 1
            if accepted >= 3:
                break
    return sites


static func _is_clear(local: Vector2, district: Dictionary, expansion: NUSKentRidgeWorld,
        tree_positions: Array[Vector3], walkway_clearance: float = WALKWAY_CLEARANCE_M,
        bus_stop_clearance: float = BUS_STOP_CLEARANCE_M,
        tree_clearance: float = TREE_CLEARANCE_M,
        building_clearance: float = BUILDING_CLEARANCE_M) -> bool:
    # Preserve both crossing promenade corridors in each schematic district.
    if absf(local.x) < 8.5 or absf(local.y) < 8.5:
        return false

    var district_id: String = str(district.get("id", ""))
    if district_id == "SPORTS" and absf(local.x) < 75.0 and absf(local.y) < 52.0:
        return false

    var size_values: Array = district.get("size", [150, 140])
    var width_m: float = float(size_values[0])
    var depth_m: float = float(size_values[1])
    for landmark_value in district.get("landmarks", []):
        var landmark: Dictionary = landmark_value
        var offset_values: Array = landmark.get("offset", [0, 0])
        var dimensions: Array = landmark.get("size", [35, 25, 15])
        var half_width: float = float(dimensions[0]) * 0.5 + building_clearance
        var half_depth: float = float(dimensions[1]) * 0.5 + building_clearance
        if absf(local.x - float(offset_values[0])) < half_width \
                and absf(local.y + float(offset_values[1])) < half_depth:
            return false

    # Avoid the three existing district planters and their canopies.
    for planter_index in range(3):
        var planter_x: float = -width_m * 0.35 + float(planter_index) * width_m * 0.35
        if local.distance_to(Vector2(planter_x, depth_m * 0.31)) < PLANTER_CLEARANCE_M:
            return false

    var center: Vector3 = district.get("position", Vector3.ZERO)
    var world_xz: Vector2 = Vector2(center.x + local.x, center.z + local.y)
    for tree in tree_positions:
        if Vector2(tree.x, tree.z).distance_to(world_xz) < tree_clearance:
            return false

    for stop_value in expansion.stops:
        var stop: Dictionary = stop_value
        var stop_at: Vector3 = stop.get("position", Vector3.ZERO)
        if Vector2(stop_at.x, stop_at.z).distance_to(world_xz) < bus_stop_clearance:
            return false

    # Keep the schematic pedestrian/cycle links unobstructed as well.
    for connection_value in expansion.walk_connections:
        var connection: Array = connection_value
        if connection.size() < 2:
            continue
        var start: Vector3 = expansion.stop_position(str(connection[0]))
        var finish: Vector3 = expansion.stop_position(str(connection[1]))
        if start == Vector3.ZERO or finish == Vector3.ZERO:
            continue
        var distance_to_link: float = _distance_to_segment(
            world_xz, Vector2(start.x, start.z), Vector2(finish.x, finish.z))
        if distance_to_link < walkway_clearance:
            return false
    return true


static func _append_furniture(district: Dictionary, expansion: NUSKentRidgeWorld,
        tree_positions: Array[Vector3], sites: Array[Vector2],
        transforms_by_kind: Dictionary, colors_by_kind: Dictionary,
        rng: RandomNumberGenerator, occupied_positions: Array[Vector2]) -> int:
    var candidates: Array[Vector2] = []
    var kinds: Array[String] = []
    var district_id: String = str(district.get("id", ""))

    if district_id == "SPORTS":
        # Keep benches and bins outside the central playing surface and track.
        var sports_candidates: Array[Vector2] = [
            Vector2(-82, -29), Vector2(82, -29),
            Vector2(-82, 29), Vector2(82, 29)
        ]
        var sports_kinds: Array[String] = ["bench", "trash_bin", "bench", "trash_bin"]
        for index in range(sports_candidates.size()):
            var local: Vector2 = sports_candidates[index]
            if not _is_clear(local, district, expansion, tree_positions, 4.0, 10.0, 4.5):
                continue
            if _is_near_any(local, occupied_positions, 8.0) or _is_near_any(local, candidates, 12.0):
                continue
            candidates.append(local)
            kinds.append(sports_kinds[index])
            occupied_positions.append(local)
    else:
        var size_values: Array = district.get("size", [150, 140])
        var width_m: float = float(size_values[0])
        var depth_m: float = float(size_values[1])
        var quadrants: Array[Vector2] = [
            Vector2(-1, -1), Vector2(1, -1),
            Vector2(-1, 1), Vector2(1, 1)
        ]
        for quadrant_index in range(quadrants.size()):
            var kind: String = "bench" if quadrant_index % 2 == 0 else "trash_bin"
            var accepted: bool = false
            for attempt in range(128):
                var quadrant: Vector2 = quadrants[quadrant_index]
                var local: Vector2 = Vector2(
                    quadrant.x * width_m * rng.randf_range(0.35, 0.44),
                    quadrant.y * depth_m * rng.randf_range(0.35, 0.44)
                )
                if not _is_clear(local, district, expansion, tree_positions, 4.0, 10.0, 4.5):
                    continue
                if _is_near_any(local, occupied_positions, 8.0) or _is_near_any(local, candidates, 12.0):
                    continue
                candidates.append(local)
                kinds.append(kind)
                occupied_positions.append(local)
                accepted = true
                break
            if not accepted:
                continue

    for index in range(candidates.size()):
        var kind: String = kinds[index]
        var local: Vector2 = candidates[index]
        var center: Vector3 = district.get("position", Vector3.ZERO)
        var scale: float = rng.randf_range(0.94, 1.06)
        var world_position: Vector3 = Vector3(
            center.x + local.x,
            GROUND_TOP_Y + _half_height(kind) * scale,
            center.z + local.y
        )
        var basis: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale)
        var transforms: Array = transforms_by_kind[kind]
        transforms.append(Transform3D(basis, world_position))
        var tints: Array = colors_by_kind[kind]
        tints.append(_random_tint(kind, rng))
    return candidates.size()


static func _append_amenities(district: Dictionary, expansion: NUSKentRidgeWorld,
        tree_positions: Array[Vector3], transforms_by_kind: Dictionary,
        colors_by_kind: Dictionary, rng: RandomNumberGenerator,
        occupied_positions: Array[Vector2]) -> int:
    var district_id: String = str(district.get("id", ""))
    var center: Vector3 = district.get("position", Vector3.ZERO)
    var added: int = 0

    # Vending machines belong near busy teaching, residential and transit areas.
    var vending_districts: PackedStringArray = PackedStringArray([
        "SCIENCE", "ENGINEERING", "COM3", "YIH", "PGP", "KR_MRT", "UHC"
    ])
    if district_id in vending_districts:
        var vending_site: Dictionary = _find_amenity_site(
            district, expansion, tree_positions, occupied_positions, rng, 4.0, 12.0, 3.0)
        if bool(vending_site.get("found", false)):
            var local: Vector2 = vending_site["local"]
            var yaw: float = rng.randf_range(0.0, TAU)
            var basis: Basis = Basis(Vector3.UP, yaw)
            var base_position: Vector3 = Vector3(
                center.x + local.x, GROUND_TOP_Y + 1.025, center.z + local.y)
            var machine_transform: Transform3D = Transform3D(basis, base_position)
            _append_instance("vending_machine", base_position, basis,
                _random_tint("vending_machine", rng), transforms_by_kind, colors_by_kind)
            var display_position: Vector3 = machine_transform * Vector3(-0.08, 0.22, -0.38)
            _append_instance("vending_display", display_position, basis,
                Color.html("#8fbac0"), transforms_by_kind, colors_by_kind)
            # Six visible product packs and three selection buttons sit on the front panel.
            var product_palette: PackedStringArray = PackedStringArray([
                "#e7b96d", "#86b7a5", "#d58c7c", "#8ba9c2", "#d5c17f"
            ])
            for row in range(3):
                for column in range(2):
                    var product_position: Vector3 = machine_transform * Vector3(
                        -0.23 + float(column) * 0.20, 0.45 - float(row) * 0.25, -0.415)
                    _append_instance("vending_products", product_position, basis,
                        Color.html(product_palette[rng.randi_range(0, product_palette.size() - 1)]),
                        transforms_by_kind, colors_by_kind)
            for button_index in range(3):
                var button_position: Vector3 = machine_transform * Vector3(
                    0.33, 0.40 - float(button_index) * 0.18, -0.415)
                _append_instance("vending_buttons", button_position, basis,
                    Color.html("#e9d7a9"), transforms_by_kind, colors_by_kind)
            occupied_positions.append(local)
            added += 11

    # A few refill stations make the longer Science/Engineering walks feel plausible.
    var water_districts: PackedStringArray = PackedStringArray(["SCIENCE", "ENGINEERING", "CLB"])
    if district_id in water_districts:
        var water_site: Dictionary = _find_amenity_site(
            district, expansion, tree_positions, occupied_positions, rng, 4.5, 13.0, 3.5)
        if bool(water_site.get("found", false)):
            var local: Vector2 = water_site["local"]
            var yaw: float = rng.randf_range(0.0, TAU)
            var basis: Basis = Basis(Vector3.UP, yaw)
            var base_position: Vector3 = Vector3(
                center.x + local.x, GROUND_TOP_Y + 0.52, center.z + local.y)
            var dispenser_transform: Transform3D = Transform3D(basis, base_position)
            _append_instance("water_dispenser", base_position, basis,
                Color.html("#8caeae"), transforms_by_kind, colors_by_kind)
            var bottle_position: Vector3 = dispenser_transform * Vector3(0.0, 0.74, 0.0)
            _append_instance("water_bottle", bottle_position, basis,
                Color.html("#8fc1c3"), transforms_by_kind, colors_by_kind)
            var tap_position: Vector3 = dispenser_transform * Vector3(0.0, 0.12, -0.37)
            _append_instance("water_tap", tap_position, basis,
                Color.html("#d7e8e4"), transforms_by_kind, colors_by_kind)
            var tray_position: Vector3 = dispenser_transform * Vector3(0.0, -0.27, -0.40)
            _append_instance("water_tray", tray_position, basis,
                Color.html("#9db6b3"), transforms_by_kind, colors_by_kind)
            occupied_positions.append(local)
            added += 4

    # Small outdoor table clusters are concentrated in commons and library/civic districts.
    var picnic_districts: PackedStringArray = PackedStringArray([
        "YIH", "PGP", "BIZ2", "MUSEUM", "CLB"
    ])
    if district_id in picnic_districts:
        var picnic_site: Dictionary = _find_amenity_site(
            district, expansion, tree_positions, occupied_positions, rng, 5.0, 14.0, 4.0, false)
        if bool(picnic_site.get("found", false)):
            var local: Vector2 = picnic_site["local"]
            var yaw: float = rng.randf_range(0.0, TAU)
            var basis: Basis = Basis(Vector3.UP, yaw)
            var table_position: Vector3 = Vector3(
                center.x + local.x, GROUND_TOP_Y + 0.54, center.z + local.y)
            var table_transform: Transform3D = Transform3D(basis, table_position)
            _append_instance("picnic_table", table_position, basis,
                _random_tint("picnic_table", rng), transforms_by_kind, colors_by_kind)
            var pole_position: Vector3 = table_transform * Vector3(1.38, 0.54, 0.0)
            var canopy_position: Vector3 = table_transform * Vector3(1.38, 1.62, 0.0)
            _append_instance("umbrella_pole", pole_position, basis,
                Color.html("#6d7775"), transforms_by_kind, colors_by_kind)
            _append_instance("shade_umbrella", canopy_position, basis,
                _random_tint("shade_umbrella", rng), transforms_by_kind, colors_by_kind)
            occupied_positions.append(local)
            added += 3
    return added


static func _find_amenity_site(district: Dictionary, expansion: NUSKentRidgeWorld,
        tree_positions: Array[Vector3], occupied_positions: Array[Vector2],
        rng: RandomNumberGenerator, walkway_clearance: float,
        minimum_separation: float, building_clearance: float,
        prefer_facade: bool = true) -> Dictionary:
    # Vending/refill equipment prefers building edges; picnic sets prefer open lawns.
    if prefer_facade:
        for landmark_value in district.get("landmarks", []):
            var landmark: Dictionary = landmark_value
            var offset_values: Array = landmark.get("offset", [0, 0])
            var dimensions: Array = landmark.get("size", [35, 25, 15])
            var building_center: Vector2 = Vector2(float(offset_values[0]), -float(offset_values[1]))
            var half_width: float = float(dimensions[0]) * 0.5
            var half_depth: float = float(dimensions[1]) * 0.5
            var clearance: float = building_clearance + 1.6
            var facade_candidates: Array[Vector2] = [
                Vector2(building_center.x, building_center.y + half_depth + clearance),
                Vector2(building_center.x + half_width + clearance, building_center.y),
                Vector2(building_center.x - half_width - clearance, building_center.y),
                Vector2(building_center.x, building_center.y - half_depth - clearance)
            ]
            for facade_candidate in facade_candidates:
                if _amenity_candidate_is_clear(facade_candidate, district, expansion,
                        tree_positions, occupied_positions, walkway_clearance,
                        minimum_separation, building_clearance):
                    return {"found": true, "local": facade_candidate}
    # Fall back to seeded district quadrants if all facade edges are blocked.
    var size_values: Array = district.get("size", [150, 140])
    var width_m: float = float(size_values[0])
    var depth_m: float = float(size_values[1])
    var quadrants: Array[Vector2] = [
        Vector2(-1, -1), Vector2(1, -1),
        Vector2(-1, 1), Vector2(1, 1)
    ]
    for attempt in range(192):
        var quadrant: Vector2 = quadrants[attempt % quadrants.size()]
        var candidate: Vector2 = Vector2(
            quadrant.x * width_m * rng.randf_range(0.24, 0.42),
            quadrant.y * depth_m * rng.randf_range(0.24, 0.42)
        )
        if _amenity_candidate_is_clear(candidate, district, expansion,
                tree_positions, occupied_positions, walkway_clearance,
                minimum_separation, building_clearance):
            return {"found": true, "local": candidate}
    return {"found": false, "local": Vector2.ZERO}


static func _amenity_candidate_is_clear(candidate: Vector2, district: Dictionary,
        expansion: NUSKentRidgeWorld, tree_positions: Array[Vector3],
        occupied_positions: Array[Vector2], walkway_clearance: float,
        minimum_separation: float, building_clearance: float) -> bool:
    if not _is_clear(candidate, district, expansion, tree_positions,
            walkway_clearance, 10.0, 4.5, building_clearance):
        return false
    if not _outside_existing_amenity_zones(candidate, str(district.get("id", ""))):
        return false
    return not _is_near_any(candidate, occupied_positions, minimum_separation)


static func _outside_existing_amenity_zones(local: Vector2, district_id: String) -> bool:
    # Faculty amenities already occupy three 22 x 18 m pads centred at z = -26 m.
    if district_id != "SCIENCE":
        for zone_x in [-31.0, 0.0, 31.0]:
            if absf(local.x - zone_x) < 16.0 and absf(local.y + 26.0) < 15.0:
                return false
    # Frontier Canteen already has a covered terrace at this anchor.
    if district_id == "SCIENCE" and absf(local.x - 43.0) < 32.0 and absf(local.y + 66.0) < 24.0:
        return false
    return true


static func _append_instance(kind: String, position: Vector3, basis: Basis, tint: Color,
        transforms_by_kind: Dictionary, colors_by_kind: Dictionary) -> void:
    var instances: Array = transforms_by_kind[kind]
    instances.append(Transform3D(basis, position))
    var tints: Array = colors_by_kind[kind]
    tints.append(tint)


static func _is_near_any(candidate: Vector2, others: Array[Vector2], minimum_distance: float) -> bool:
    for other in others:
        if candidate.distance_to(other) < minimum_distance:
            return true
    return false


static func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
    var segment: Vector2 = finish - start
    var length_squared: float = segment.length_squared()
    if length_squared < 0.0001:
        return point.distance_to(start)
    var t: float = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
    return point.distance_to(start + segment * t)


static func _item_offset(index: int) -> Vector2:
    match index:
        0:
            return Vector2(-0.52, -0.16)
        1:
            return Vector2(0.50, 0.18)
        _:
            return Vector2(0.02, 0.72)


static func _theme_for(district_id: String) -> PackedStringArray:
    match district_id:
        "SPORTS":
            return PackedStringArray(["ball", "shuttlecock", "bottle", "bag", "frisbee", "folded_umbrella"])
        "ENGINEERING":
            return PackedStringArray(["notebook", "paper", "coffee", "bottle", "bag", "phone", "headphones", "cardboard_box"])
        "SCIENCE":
            return PackedStringArray(["notebook", "paper", "coffee", "bottle", "food", "phone", "headphones", "frisbee"])
        "CLB":
            return PackedStringArray(["notebook", "paper", "coffee", "bottle", "phone", "headphones", "cardboard_box"])
        "COM3":
            return PackedStringArray(["notebook", "paper", "coffee", "bag", "phone", "headphones", "cardboard_box"])
        "PGP":
            return PackedStringArray(["bag", "bottle", "coffee", "food", "phone", "folded_umbrella", "cardboard_box"])
        "KR_MRT":
            return PackedStringArray(["bottle", "coffee", "bag", "paper", "phone", "folded_umbrella"])
        "MUSEUM":
            return PackedStringArray(["paper", "notebook", "coffee", "bag", "phone", "cardboard_box", "frisbee"])
        "YIH":
            return PackedStringArray(["bag", "bottle", "coffee", "food", "phone", "headphones", "folded_umbrella"])
        "UHC":
            return PackedStringArray(["bottle", "paper", "bag", "coffee", "phone", "folded_umbrella"])
        _:
            return PackedStringArray(["paper", "notebook", "coffee", "bottle", "phone", "headphones", "cardboard_box", "frisbee"])


static func _make_meshes() -> Dictionary:
    var paper: BoxMesh = BoxMesh.new()
    paper.size = Vector3(0.42, 0.018, 0.30)

    var notebook: BoxMesh = BoxMesh.new()
    notebook.size = Vector3(0.54, 0.075, 0.40)

    var coffee: CylinderMesh = CylinderMesh.new()
    coffee.top_radius = 0.105
    coffee.bottom_radius = 0.14
    coffee.height = 0.24
    coffee.radial_segments = 8

    var bottle: CylinderMesh = CylinderMesh.new()
    bottle.top_radius = 0.055
    bottle.bottom_radius = 0.085
    bottle.height = 0.34
    bottle.radial_segments = 8

    var food: BoxMesh = BoxMesh.new()
    food.size = Vector3(0.40, 0.12, 0.30)

    var bag: BoxMesh = BoxMesh.new()
    bag.size = Vector3(0.36, 0.34, 0.18)

    var ball: SphereMesh = SphereMesh.new()
    ball.radius = 0.16
    ball.height = 0.32
    ball.radial_segments = 10
    ball.rings = 6

    var shuttlecock: CylinderMesh = CylinderMesh.new()
    shuttlecock.top_radius = 0.035
    shuttlecock.bottom_radius = 0.11
    shuttlecock.height = 0.22
    shuttlecock.radial_segments = 8

    var bench: ArrayMesh = _make_bench_mesh()

    var trash_bin: CylinderMesh = CylinderMesh.new()
    trash_bin.top_radius = 0.32
    trash_bin.bottom_radius = 0.38
    trash_bin.height = 0.82
    trash_bin.radial_segments = 8

    var phone: BoxMesh = BoxMesh.new()
    phone.size = Vector3(0.16, 0.025, 0.28)

    var headphones: TorusMesh = TorusMesh.new()
    headphones.inner_radius = 0.085
    headphones.outer_radius = 0.135
    headphones.rings = 12
    headphones.ring_segments = 6

    var folded_umbrella: CylinderMesh = CylinderMesh.new()
    folded_umbrella.top_radius = 0.035
    folded_umbrella.bottom_radius = 0.065
    folded_umbrella.height = 0.62
    folded_umbrella.radial_segments = 6

    var cardboard_box: BoxMesh = BoxMesh.new()
    cardboard_box.size = Vector3(0.42, 0.34, 0.36)

    var frisbee: CylinderMesh = CylinderMesh.new()
    frisbee.top_radius = 0.20
    frisbee.bottom_radius = 0.20
    frisbee.height = 0.035
    frisbee.radial_segments = 10

    var vending_machine: BoxMesh = BoxMesh.new()
    vending_machine.size = Vector3(0.92, 2.05, 0.72)

    var vending_display: BoxMesh = BoxMesh.new()
    vending_display.size = Vector3(0.54, 0.82, 0.035)

    var vending_products: BoxMesh = BoxMesh.new()
    vending_products.size = Vector3(0.10, 0.13, 0.04)

    var vending_buttons: BoxMesh = BoxMesh.new()
    vending_buttons.size = Vector3(0.055, 0.055, 0.035)

    var picnic_table: ArrayMesh = _make_picnic_table_mesh()

    var shade_umbrella: SphereMesh = SphereMesh.new()
    shade_umbrella.radius = 1.28
    shade_umbrella.height = 0.50
    shade_umbrella.radial_segments = 10
    shade_umbrella.rings = 5

    var umbrella_pole: CylinderMesh = CylinderMesh.new()
    umbrella_pole.top_radius = 0.04
    umbrella_pole.bottom_radius = 0.04
    umbrella_pole.height = 2.15
    umbrella_pole.radial_segments = 8

    var water_dispenser: BoxMesh = BoxMesh.new()
    water_dispenser.size = Vector3(0.88, 0.95, 0.72)

    var water_bottle: CylinderMesh = CylinderMesh.new()
    water_bottle.top_radius = 0.20
    water_bottle.bottom_radius = 0.26
    water_bottle.height = 0.55
    water_bottle.radial_segments = 8

    var water_tap: BoxMesh = BoxMesh.new()
    water_tap.size = Vector3(0.30, 0.10, 0.05)

    var water_tray: BoxMesh = BoxMesh.new()
    water_tray.size = Vector3(0.40, 0.05, 0.18)

    return {
        "paper": paper,
        "notebook": notebook,
        "coffee": coffee,
        "bottle": bottle,
        "food": food,
        "bag": bag,
        "ball": ball,
        "shuttlecock": shuttlecock,
        "bench": bench,
        "trash_bin": trash_bin,
        "phone": phone,
        "headphones": headphones,
        "folded_umbrella": folded_umbrella,
        "cardboard_box": cardboard_box,
        "frisbee": frisbee,
        "vending_machine": vending_machine,
        "vending_display": vending_display,
        "vending_products": vending_products,
        "vending_buttons": vending_buttons,
        "picnic_table": picnic_table,
        "shade_umbrella": shade_umbrella,
        "umbrella_pole": umbrella_pole,
        "water_dispenser": water_dispenser,
        "water_bottle": water_bottle,
        "water_tap": water_tap,
        "water_tray": water_tray
    }


static func _make_picnic_table_mesh() -> ArrayMesh:
    # One low-poly mesh combines tabletop, legs and two fixed benches.
    var tool: SurfaceTool = SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var top: BoxMesh = BoxMesh.new()
    top.size = Vector3(2.45, 0.14, 1.12)
    tool.append_from(top, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.30, 0.0)))
    var leg: BoxMesh = BoxMesh.new()
    leg.size = Vector3(0.14, 0.68, 0.14)
    for x in [-1.02, 1.02]:
        for z in [-0.40, 0.40]:
            tool.append_from(leg, 0, Transform3D(Basis.IDENTITY, Vector3(float(x), -0.05, float(z))))
    var seat: BoxMesh = BoxMesh.new()
    seat.size = Vector3(2.15, 0.12, 0.36)
    var seat_leg: BoxMesh = BoxMesh.new()
    seat_leg.size = Vector3(0.12, 0.38, 0.28)
    for side in [-1.0, 1.0]:
        tool.append_from(seat, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.17, side * 0.94)))
        for x in [-0.88, 0.88]:
            tool.append_from(seat_leg, 0, Transform3D(Basis.IDENTITY, Vector3(float(x), -0.34, side * 0.94)))
    return tool.commit()


static func _make_bench_mesh() -> ArrayMesh:
    # One combined low-poly mesh keeps each repeated bench to a single draw batch.
    var tool: SurfaceTool = SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    var seat: BoxMesh = BoxMesh.new()
    seat.size = Vector3(2.2, 0.16, 0.62)
    tool.append_from(seat, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, -0.02, 0.0)))
    var back: BoxMesh = BoxMesh.new()
    back.size = Vector3(2.2, 0.56, 0.14)
    tool.append_from(back, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.30, -0.24)))
    var support: BoxMesh = BoxMesh.new()
    support.size = Vector3(0.14, 0.54, 0.56)
    for x in [-0.92, 0.92]:
        tool.append_from(support, 0, Transform3D(Basis.IDENTITY, Vector3(float(x), -0.32, 0.0)))
    return tool.commit()


static func _half_height(kind: String) -> float:
    match kind:
        "paper":
            return 0.009
        "notebook":
            return 0.038
        "coffee":
            return 0.12
        "bottle":
            return 0.17
        "food":
            return 0.06
        "bag":
            return 0.17
        "ball":
            return 0.16
        "shuttlecock":
            return 0.11
        "bench":
            return 0.60
        "trash_bin":
            return 0.41
        "phone":
            return 0.013
        "headphones":
            return 0.015
        "folded_umbrella":
            return 0.31
        "cardboard_box":
            return 0.17
        "frisbee":
            return 0.018
        "vending_machine":
            return 1.025
        "picnic_table":
            return 0.54
        "shade_umbrella":
            return 2.1
        "umbrella_pole":
            return 1.075
        "water_dispenser":
            return 0.75
    return 0.05


static func _random_tint(kind: String, rng: RandomNumberGenerator) -> Color:
    var palette: PackedStringArray
    match kind:
        "paper":
            palette = PackedStringArray(["#f4efdf", "#e2edf0", "#f0d9d0", "#dce8d6"])
        "notebook":
            palette = PackedStringArray(["#648b96", "#c18b72", "#d1b06e", "#758b73"])
        "coffee":
            palette = PackedStringArray(["#eee3cf", "#e1d4c1", "#d7e5df"])
        "bottle":
            palette = PackedStringArray(["#82b4c2", "#9ac6b1", "#e6e0c9"])
        "food":
            palette = PackedStringArray(["#e4d5bd", "#d7b47e", "#b9c8aa"])
        "bag":
            palette = PackedStringArray(["#6e8990", "#c28d77", "#b7a77d", "#73866e"])
        "ball":
            palette = PackedStringArray(["#f1e8d6", "#e1a86d", "#7da8b5"])
        "bench":
            palette = PackedStringArray(["#ae8267", "#9b755e", "#c09a78"])
        "trash_bin":
            palette = PackedStringArray(["#71877f", "#788d91", "#879b82"])
        "phone":
            palette = PackedStringArray(["#3f4d56", "#667e89", "#b7b9ae"])
        "headphones":
            palette = PackedStringArray(["#445d68", "#a77d68", "#6d8778"])
        "folded_umbrella":
            palette = PackedStringArray(["#6d8792", "#bd8d76", "#9c9a70"])
        "cardboard_box":
            palette = PackedStringArray(["#b7956e", "#c4a47d", "#9d8265"])
        "frisbee":
            palette = PackedStringArray(["#d9bb68", "#78a7a0", "#d48d79"])
        "vending_machine":
            palette = PackedStringArray(["#647f82", "#718b86", "#8b806f"])
        "picnic_table":
            palette = PackedStringArray(["#a77c55", "#b18a62", "#92704f"])
        "shade_umbrella":
            palette = PackedStringArray(["#d8b76f", "#7da6a0", "#c68f79"])
        _:
            palette = PackedStringArray(["#f4efdf", "#d9e4d9", "#e6c18a"])
    return Color.html(palette[rng.randi_range(0, palette.size() - 1)])


static func _create_batch(root: Node3D, kind: String, mesh: Mesh,
        transforms: Array, colors: Array, material: StandardMaterial3D) -> void:
    if transforms.is_empty():
        return
    var multi: MultiMesh = MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.mesh = mesh
    multi.instance_count = transforms.size()
    for index in range(transforms.size()):
        var instance_transform: Transform3D = transforms[index]
        var instance_color: Color = colors[index]
        multi.set_instance_transform(index, instance_transform)
        multi.set_instance_color(index, instance_color)

    var renderer: MultiMeshInstance3D = MultiMeshInstance3D.new()
    renderer.name = "Scattered_" + kind + "_MultiMesh"
    renderer.multimesh = multi
    renderer.material_override = material
    renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(renderer)
