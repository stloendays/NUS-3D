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
    print("PASS: MD1 Science district landmark present")
    quit(0)
