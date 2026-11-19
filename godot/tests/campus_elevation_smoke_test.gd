extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/kent_ridge_expansion.json"))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Terrain data missing")
        quit(1)
        return
    var districts: Array = parsed.get("districts", [])
    var levels: Dictionary = {}
    for district in districts:
        var id: String = str(district.get("id", ""))
        var height_value: float = float(district.get("elevation_m", -1))
        if height_value < 0 or height_value > 60:
            push_error("Invalid terrace elevation: " + id)
            quit(1)
            return
        levels[id] = height_value
    if levels.size() < 8 or not levels.has("SCIENCE") or not levels.has("ENGINEERING"):
        push_error("Missing terrain district coverage")
        quit(1)
        return
    var world_script: String = FileAccess.get_file_as_string("res://scripts/kent_ridge_world.gd")
    for required in ["DistrictTerrace", "DistrictPedestrianRamp", "SlopedWalkSurface", "RampLanding"]:
        if not world_script.contains(required):
            push_error("Missing terrain element: " + required)
            quit(1)
            return
    print("PASS: district terrain elevation metadata and ramp components")
    quit(0)
