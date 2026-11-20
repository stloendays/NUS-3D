extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var wardrobe: String = FileAccess.get_file_as_string("res://scripts/character_wardrobe.gd")
    var leisure: String = FileAccess.get_file_as_string("res://scripts/utown_leisure_ui.gd")
    for marker in ["NUS3DUISkin.glass", "NUS3DUISkin.button", "size_changed.connect(_update_wardrobe_layout)"]:
        if not wardrobe.contains(marker):
            push_error("Wardrobe theme/layout missing: " + marker)
            quit(1)
            return
    for marker in ["NUS3DUISkin.glass", "size_changed.connect(_update_lounge_layout)", "lounge_panel.custom_minimum_size"]:
        if not leisure.contains(marker):
            push_error("Leisure theme/layout missing: " + marker)
            quit(1)
            return
    print("PASS: wardrobe and leisure shared theme hooks")
    quit(0)
