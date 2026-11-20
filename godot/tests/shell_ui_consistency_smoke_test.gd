extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var source: String = FileAccess.get_file_as_string("res://scripts/game_shell.gd")
    for token in ["func _build_login()", "func _build_mail()", "func _build_profile_card()", "NUS3DUISkin.glass(Color(\"#E8EEEC\")", "login_title = _label(\"SIGN IN\", 20)"]:
        if not source.contains(token):
            push_error("Missing unified shell UI token: " + token)
            quit(1)
            return
    print("PASS: login, profile and mailbox UI style hooks")
    quit(0)
