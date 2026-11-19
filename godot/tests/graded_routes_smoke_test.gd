extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var code: String = FileAccess.get_file_as_string("res://scripts/kent_ridge_world.gd")
    for token in ["_surface_elevation", "_graded_strip", "Footpath_", "CycleLane_", "stop_position.y"]:
        if not code.contains(token):
            push_error("Missing graded route feature: " + token)
            quit(1)
            return
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/kent_ridge_expansion.json"))
    if typeof(data) != TYPE_DICTIONARY:
        push_error("Invalid campus elevation JSON")
        quit(1)
        return
    if data.get("districts", []).size() < 8 or data.get("stops", []).size() < 3:
        push_error("Insufficient districts or bus stops")
        quit(1)
        return
    print("PASS: graded route integration markers and elevation dataset")
    quit(0)
