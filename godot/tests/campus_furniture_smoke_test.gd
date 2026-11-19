extends SceneTree
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var host := Node3D.new()
    root.add_child(host)
    UTownCampusProps.decorate(host, {
        "GREEN": Vector3.ZERO,
        "ERC": Vector3(30, 0, 0),
        "SRC": Vector3(60, 0, 0),
        "PLAZA": Vector3(90, 0, 0)
    })
    var kit: Node3D = host.get_node_or_null("CampusFurnitureM16")
    if kit == null or kit.get_child_count() != 4:
        push_error("Campus furniture landmarks missing")
        quit(1)
        return
    var expected: Array[String] = ["CampusBench", "WasteBin_RECYCLE", "WasteBin_WASTE", "WaterRefillStation"]
    for group in kit.get_children():
        for item in expected:
            if group.get_node_or_null(item) == null:
                # There are two benches with duplicate names, but one will retain this name.
                push_error("Missing furniture: " + item)
                quit(1)
                return
    print("PASS: four landmark furniture clusters generated")
    quit(0)
