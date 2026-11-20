extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var files: Array[String] = ["res://scripts/session_overlay.gd", "res://scripts/utown_coursework_ui.gd"]
    for path in files:
        var source: String = FileAccess.get_file_as_string(path)
        if not source.contains("size_changed.connect") or not source.contains("viewport_size"):
            push_error("Missing responsive UI behavior: " + path)
            quit(1)
            return
    print("PASS: session and coursework responsive layout hooks")
    quit(0)
