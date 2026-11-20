extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var code_text: String = FileAccess.get_file_as_string("res://scripts/hud.gd")
    for marker in ["size_changed.connect(_update_compact_layout)", "viewport_size.x < 1100.0", "help_label.add_theme_font_size_override", "campus_card.visible = show_full_help or"]:
        if not code_text.contains(marker):
            push_error("Missing responsive HUD behavior: " + marker)
            quit(1)
            return
    print("PASS: compact HUD layout and contextual status hooks")
    quit(0)
