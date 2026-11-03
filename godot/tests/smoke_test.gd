extends SceneTree
## Run via: godot --headless --path godot --script res://tests/smoke_test.gd

func _initialize() -> void:
    call_deferred("_smoke")

func _smoke() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if scene == null:
        push_error("main scene failed to load")
        quit(1)
        return
    var instance: Node3D = scene.instantiate() as Node3D
    root.add_child(instance)
    await process_frame
    var world: UTownWorld = instance.get_node_or_null("World") as UTownWorld
    var player: CharacterBody3D = instance.get_node_or_null("Player") as CharacterBody3D
    if world == null or player == null:
        push_error("required scene nodes absent")
        quit(1)
        return
    if world.layout.is_empty():
        push_error("failed to parse site metadata")
        quit(1)
        return
    if world.generated_building_count < 8 or world.generated_tree_count < 20:
        push_error("missing procedural buildings or vegetation")
        quit(1)
        return
    if world.route_points.size() != 4 or world.generated_path_count < 8:
        push_error("the conceptual walkway loop was not constructed")
        quit(1)
        return
    var trunks: MultiMeshInstance3D = world.get_node_or_null("Vegetation_Procedural/TreeTrunks_MultiMesh") as MultiMeshInstance3D
    var canopies: MultiMeshInstance3D = world.get_node_or_null("Vegetation_Procedural/TreeCanopies_MultiMesh") as MultiMeshInstance3D
    if trunks == null or canopies == null or trunks.multimesh == null or canopies.multimesh == null:
        push_error("the two vegetation MultiMesh batches are missing")
        quit(1)
        return
    if trunks.multimesh.instance_count != world.generated_tree_count or canopies.multimesh.instance_count != world.generated_tree_count:
        push_error("vegetation batch instance counts do not match the generated tree count")
        quit(1)
        return
    if world.generated_tree_positions.size() != world.generated_tree_count:
        push_error("generated tree position registry is incomplete")
        quit(1)
        return
    for i in range(world.generated_tree_positions.size()):
        var expected: Vector3 = world.generated_tree_positions[i]
        if not world.is_tree_position_clear(Vector2(expected.x, expected.z)):
            push_error("generated tree %d failed clearance at x=%.2f z=%.2f" % [i, expected.x, expected.z])
            quit(1)
            return
    var erc: Vector3 = world.lonlat_to_world(103.77291, 1.30598)
    var src: Vector3 = world.lonlat_to_world(103.77252, 1.30462)
    if not (erc.x < 0.0 and erc.z < 0.0 and src.x < 0.0 and src.z > 0.0):
        push_error("east/north orientation is inconsistent")
        quit(1)
        return
    var data: Dictionary = world.layout.get("spatial_reference", {})
    if str(data.get("precision", "")).find("NOT survey") < 0:
        push_error("the provisional geography must remain clearly labelled")
        quit(1)
        return
    print("PASS: scene, %d building groups, %d trees in 2 MultiMesh batches, %d paths, four waypoints, axes and provenance." % [world.generated_building_count, world.generated_tree_count, world.generated_path_count])
    instance.queue_free()
    quit(0)
