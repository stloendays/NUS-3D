extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var code: String = FileAccess.get_file_as_string("res://scripts/kent_ridge_world.gd")
    for token in ["PATH_SAMPLE_STEP", "PATH_MAX_SEGMENTS", "_terrain_following_strip", "point.y = _surface_elevation(point) + clearance", "Footpath_segment_", "CycleLane_segment_"]:
        if not code.contains(token):
            push_error("Missing terrain-following path component: " + token)
            quit(1)
            return
    print("PASS: terrain-following route source markers")
    quit(0)
