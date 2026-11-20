extends SceneTree
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var source: String = FileAccess.get_file_as_string("res://scripts/utown_coins.gd")
    for marker in [
        "size_changed.connect(_update_coin_ui_layout)",
        "func _update_coin_ui_layout()",
        "NUS3DUISkin.glass(Color(\"#E8EEEC\")",
        "NUS3DUISkin.button(button)",
        "BALANCE %d C\\nOWNED:",
        "wallet_card.visible = not world.osm_reference_visible"
    ]:
        if not source.contains(marker):
            push_error("Missing coin shop UI marker: " + marker)
            quit(1)
            return
    print("PASS: coin wallet and shop responsive theme hooks")
    quit(0)
