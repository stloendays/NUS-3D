extends SceneTree
## M3.10 source-aware architecture visual regression. No collisions or routes changed.
## Run: godot --headless --path godot --script res://tests/building_accuracy_smoke_test.gd

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("M3.10 architecture check: " + reason)
    quit(1)

func _record(world: UTownWorld, identifier: String) -> Dictionary:
    for row in world.layout.get("buildings", []):
        if str(row.get("id", "")) == identifier:
            return row
    return {}

func _has_physics(node: Node) -> bool:
    var stack: Array[Node] = [node]
    while not stack.is_empty():
        var current: Node = stack.pop_back()
        if current is CollisionObject3D or current is CollisionShape3D:
            return true
        for child in current.get_children():
            stack.append(child)
    return false

func _run() -> void:
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("cannot load main scene")
        return
    var instance: Node3D = packed.instantiate() as Node3D
    root.add_child(instance)
    await process_frame
    var world: UTownWorld = instance.get_node_or_null("World") as UTownWorld
    var accuracy: UTownBuildingAccuracy = instance.get_node_or_null("BuildingAccuracy") as UTownBuildingAccuracy
    if world == null or accuracy == null:
        _fail("new architecture controller or existing map is missing")
        return
    if world.generated_building_count != 9 or world.generated_facade_count != 2:
        _fail("existing ERC/SRC and residence building registry changed")
        return
    if accuracy.p0_studies.size() != 2 or accuracy.osm_edge_count < 70:
        _fail("ERC and SRC source-aligned upper envelope meshes not built")
        return
    if accuracy.tower_studies.size() != 3 or accuracy.total_windows < 1700:
        _fail("batched 16-storey and 25-level tower facades not built")
        return
    for id in ["ERC", "SRC"]:
        var study: Dictionary = accuracy.p0_studies[id]
        var target: Node3D = world.get_node("BuildingMassing_Estimated/" + id) as Node3D
        var source_layer: Node3D = target.get_node_or_null("ArchitecturalStudy_NotSurveyed") as Node3D
        var new_layer: Node3D = study["node"]
        if new_layer.get_parent() != source_layer or not bool(study["upper_floors_only"]):
            _fail(id + " envelope must be attached to F2 study, not a ground-level solid building")
            return
        if _has_physics(new_layer):
            _fail(id + " envelope introduced collision into the conceptual route")
            return
        if int(study["edge_count"]) < 25 or str(study["source"]).find("openstreetmap.org/way/") < 0:
            _fail(id + " outline reference or edge count is missing")
            return
        var glass: MeshInstance3D = new_layer.get_node_or_null("OSMUpperGlazing_Batched") as MeshInstance3D
        var fascia: MeshInstance3D = new_layer.get_node_or_null("UpperFloorSlabsAndRoofEdge_Batched") as MeshInstance3D
        var fins: MeshInstance3D = new_layer.get_node_or_null("VerticalMullions_Batched") as MeshInstance3D
        if glass == null or fascia == null or fins == null or glass.mesh == null or glass.mesh.get_surface_count() != 1:
            _fail(id + " missing one-batch visual perimeter glazing/fascia/fins")
            return
        if glass.get_aabb().size.y < 5.0:
            _fail(id + " outline does not show multiple upper storeys")
            return
    # The original SRC forum disc and ERC curved glazing still exist for M2 comparison.
    if world.get_node_or_null("BuildingMassing_Estimated/SRC/ArchitecturalStudy_NotSurveyed/SRC_ForumDisc_Study/ElevatedMetalDisc_Estimated") == null:
        _fail("SRC forum disc was lost")
        return
    if world.get_node_or_null("BuildingMassing_Estimated/ERC/ArchitecturalStudy_NotSurveyed/StudyWing_00/ERC_CurvedGlazing_Study") == null:
        _fail("ERC curved glass original reference was lost")
        return
    for id in ["CREATE_TOWER", "UTR_N", "UTR_S"]:
        var study: Dictionary = accuracy.tower_studies[id]
        var record: Dictionary = _record(world, id)
        var floors: int = int(record["confirmed_storeys"])
        var pitch: float = float(record["estimated_floor_pitch_m"])
        var height_m: float = float(record["parts"][0]["h"])
        if floors != (16 if id == "CREATE_TOWER" else 25):
            _fail("expected 16 CREATE or 25 UTown Residence levels, got " + id)
            return
        if not is_equal_approx(height_m, float(floors) * pitch):
            _fail("storeys and estimated height differ for " + id)
            return
        if int(study["floors"]) != floors or not is_equal_approx(float(study["height_m_estimated"]), height_m):
            _fail("high-rise facade level count or height does not match canonical data")
            return
        var facade: MultiMeshInstance3D = study["batch"]
        if facade.multimesh == null or facade.multimesh.instance_count != int(study["windows"]):
            _fail("high-rise does not use a fixed one-batch window facade")
            return
        if facade.multimesh.instance_count > accuracy.MAX_WINDOWS_PER_TOWER:
            _fail("per-building facade exceeded window memory budget")
            return
        if _has_physics(study["node"]):
            _fail("a new high-rise layer introduced collider(s)")
            return
        if str(record.get("height_provenance", "")).find("not surveyed") < 0:
            _fail("estimated high-rise height not correctly labeled in data")
            return
    if _record(world, "ERC")["confirmed_storeys"] != 4:
        _fail("ERC four-storey correction did not persist")
        return
    if world.weather_reactive_grass.size() != 2 or world.weather_reactive_materials.size() != 2:
        _fail("building correction altered existing weather materials")
        return
    if instance.get_node_or_null("Arcade") == null or instance.get_node_or_null("GreenDining") == null or instance.get_node_or_null("Coins") == null:
        _fail("existing NPC, dining or coins functionality was not preserved")
        return
    world.set_m2_details_visible(false)
    for id in ["ERC", "SRC"]:
        var new_layer: Node3D = accuracy.p0_studies[id]["node"]
        if new_layer.is_visible_in_tree():
            _fail(id + " architecture comparison F2 does not hide source-aligned envelope")
            return
    world.set_m2_details_visible(true)
    for id in ["ERC", "SRC"]:
        var new_layer: Node3D = accuracy.p0_studies[id]["node"]
        if not new_layer.is_visible_in_tree():
            _fail(id + " architecture comparison F2 did not restore source-aligned envelope")
            return
    print("PASS: M3.10 verified storey counts, two source-derived elevated envelopes, one-batch tower windows, zero added colliders, F2 and existing gameplay.")
    instance.queue_free()
    quit(0)
