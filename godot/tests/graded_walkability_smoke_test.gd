extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var script_text: String = FileAccess.get_file_as_string("res://scripts/kent_ridge_world.gd")
    for token in ["forward.cross(right)", "axis.basis = Basis(right, normal, forward)", "name_value.begins_with(\"Footpath_\")", "name_value.begins_with(\"CycleLane_\")", "color, solid_surface"]:
        if not script_text.contains(token):
            push_error("Missing slope collision/orientation feature: " + token)
            quit(1)
            return
    print("PASS: graded path collision and orientation source checks")
    quit(0)
