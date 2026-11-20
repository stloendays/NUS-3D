extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var source: String = FileAccess.get_file_as_string("res://scripts/game_shell.gd")
    for marker in ["get_viewport().size_changed.connect(responsive)", "NUS3DUISkin.glass(Color(\"#E8EEEC\")", "NUS3DUISkin.DIM", "CAMPUS POST"]:
        if not source.contains(marker):
            push_error("Missing account UI polish marker: " + marker)
            quit(1)
            return
    print("PASS: account, login and mailbox UI style hooks")
    quit(0)
