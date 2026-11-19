extends SceneTree
## Run: godot --headless --path godot --script res://tests/ui_feedback_smoke_test.gd
## Tests the UI overlay in isolation and guards against gameplay/auth regressions.

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var sound: NUS3DUISound = root.get_node_or_null("UISound") as NUS3DUISound
    if sound == null or sound._clips.size() != 6:
        _fail("Procedural audio autoload or cached sound clips are missing")
        return
    for kind in ["press", "release", "open", "confirm", "reward", "error"]:
        var clip: AudioStreamWAV = sound._clips.get(kind) as AudioStreamWAV
        if clip == null or clip.data.size() < 100:
            _fail("Malformed procedural sound: " + kind)
            return

    var shell_scene: PackedScene = load("res://scenes/game_shell.tscn") as PackedScene
    if shell_scene == null:
        _fail("Game shell scene is unavailable")
        return
    var shell: NUS3DGameShell = shell_scene.instantiate() as NUS3DGameShell
    root.add_child(shell)
    await process_frame
    if shell.game == null or shell.ui == null or not paused or not shell.login_cover.visible:
        _fail("Login shell no longer pauses the world")
        return
    var hud: CanvasLayer = shell.game.get_node_or_null("HUD") as CanvasLayer
    var rail: NUS3DKeyRail = shell.game.get_node_or_null("HUD/ActionRail") as NUS3DKeyRail
    if hud == null or rail == null or rail.key_count() != 11:
        _fail("HUD key rail did not create its 11 tactile actions")
        return
    var info: PanelContainer = shell.game.get_node("HUD/Info") as PanelContainer
    var info_style: StyleBoxFlat = info.get_theme_stylebox("panel") as StyleBoxFlat
    if info_style == null or info_style.shadow_size < 5 or info_style.border_width_top < 2:
        _fail("Beveled HUD panel material is missing")
        return
    var button_style: StyleBoxFlat = shell.login_submit.get_theme_stylebox("normal") as StyleBoxFlat
    if button_style == null or button_style.shadow_size < 3:
        _fail("Tactile button styling was not applied to the account shell")
        return
    var tile: PanelContainer = rail._tiles["discover"] as PanelContainer
    var event: InputEventKey = InputEventKey.new()
    event.keycode = KEY_E
    event.pressed = true
    rail._input(event)
    if not bool(rail._held["discover"]):
        _fail("Key E did not depress its prompt")
        return
    var depressed: StyleBoxFlat = tile.get_theme_stylebox("panel") as StyleBoxFlat
    if depressed == null or depressed.shadow_offset.y > 2.0:
        _fail("Key did not use the depressed 3D style")
        return
    event.pressed = false
    rail._input(event)
    if bool(rail._held["discover"]):
        _fail("Key release did not restore the prompt")
        return
    var raised: StyleBoxFlat = tile.get_theme_stylebox("panel") as StyleBoxFlat
    if raised == null or raised.shadow_offset.y < 3.0:
        _fail("Key release did not restore the raised 3D style")
        return

    var help: Label = shell.game.get_node("HUD/Help") as Label
    if help.visible:
        _fail("Detailed help must start folded away")
        return
    event.keycode = KEY_F1
    event.pressed = true
    hud.call("_unhandled_input", event)
    var help_backdrop: PanelContainer = hud.get_node("HelpBackdrop") as PanelContainer
    if not help.visible or not help_backdrop.visible:
        _fail("F1 help overlay did not become visible")
        return
    hud.call("_unhandled_input", event)
    if help.visible:
        _fail("F1 help overlay did not close")
        return

    hud.call("_show_toast", "UI TEST")
    var toast_card: PanelContainer = hud.get_node("FeedbackToast") as PanelContainer
    var toast_label: Label = toast_card.get_child(0) as Label
    if not toast_card.visible or toast_label.text != "UI TEST":
        _fail("Milestone toast is not available")
        return
    hud.call("sync_feedback_state")
    if toast_card.visible:
        _fail("Restored account progress should not retain a toast")
        return

    var original_sound: bool = sound.enabled
    shell._toggle_ui_sound()
    if sound.enabled == original_sound:
        _fail("Sound preference toggle did not change state")
        return
    if shell.login_sound_button.text != ("UI sound: ON  [F9]" if sound.enabled else "UI sound: OFF  [F9]"):
        _fail("Login sound label is not synchronized")
        return
    shell._toggle_ui_sound()
    if sound.enabled != original_sound:
        _fail("Sound preference did not return to its initial state")
        return

    paused = false
    print("NUS3D_UI_FEEDBACK_SMOKE_OK")
    quit(0)


func _fail(reason: String) -> void:
    push_error("NUS3D UI feedback smoke failed: " + reason)
    paused = false
    quit(1)
