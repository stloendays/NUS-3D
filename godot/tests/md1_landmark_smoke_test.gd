extends SceneTree
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var path: String = "res://data/kent_ridge_expansion.json"
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Kent Ridge map JSON invalid")
        quit(1)
        return
    var found: int = 0
    for district in parsed.get("districts", []):
        if str(district.get("id", "")) != "SCIENCE":
            continue
        for landmark in district.get("landmarks", []):
            if str(landmark.get("name", "")) == "MD1 Tahir Foundation Building":
                found += 1
                if str(landmark.get("kind", "")) != "md1_research":
                    push_error("MD1 facade type missing")
                    quit(1)
                    return
                if landmark.get("size", []).size() != 3:
                    push_error("MD1 dimensions missing")
                    quit(1)
                    return
    if found != 1:
        push_error("MD1 landmark must appear once in Science district")
        quit(1)
        return
    var world_script: String = FileAccess.get_file_as_string("res://scripts/kent_ridge_world.gd")
    for required in ["MD1_PedestrianAccess_Schematic", "MD6_To_MD1_Walk", "NUH_To_MD6_Walk", "MD1_Entrance_Walk"]:
        if not world_script.contains(required):
            push_error("MD1 access component missing: " + required)
            quit(1)
            return
    print("PASS: MD1 landmark and schematic pedestrian access present")
    quit(0)
