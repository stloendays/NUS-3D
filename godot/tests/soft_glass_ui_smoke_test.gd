extends SceneTree
## Soft-light skin must remain readable and cheap in software/headless rendering.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("NUS3D soft glass UI regression: " + reason)
    quit(1)

func _bright_panel(panel: PanelContainer, name_value: String) -> bool:
    if panel == null:
        _fail(name_value + " is absent")
        return false
    var skin: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
    if skin == null:
        _fail(name_value + " lost its StyleBoxFlat")
        return false
    if skin.bg_color.get_luminance() < 0.70 or skin.bg_color.a < 0.76:
        _fail(name_value + " reverted to an overly dark or unreadable panel")
        return false
    if skin.corner_radius_top_left < 17 or not skin.anti_aliasing:
        _fail(name_value + " lost rounded antialiased edges")
        return false
    if skin.shadow_size < 4 or skin.shadow_size > 18 or skin.shadow_color.a > 0.25:
        _fail(name_value + " uses overly harsh or excessively expensive shadow")
        return false
    return true

func _run() -> void:
    NUS3DServices.ensure_scene_services(self)
    var packed: PackedScene = load("res://scenes/game_shell.tscn") as PackedScene
    if packed == null:
        _fail("Game entry scene failed to load")
        return
    var shell: NUS3DGameShell = packed.instantiate() as NUS3DGameShell
    root.add_child(shell)
    await process_frame
    if shell.game == null or shell.login_cover == null or not shell.login_cover.visible:
        _fail("Login and game world must still start in the original state")
        return
    var hud: CanvasLayer = shell.game.get_node_or_null("HUD") as CanvasLayer
    if hud == null:
        _fail("HUD was removed")
        return
    if not _bright_panel(hud.get_node("Info") as PanelContainer, "Info"):
        return
    if not _bright_panel(hud.get_node("CampusCard") as PanelContainer, "CampusCard"):
        return
    if not _bright_panel(hud.get_node("HelpBackdrop") as PanelContainer, "HelpBackdrop"):
        return
    var map: Control = hud.get_node_or_null("Minimap") as Control
    var minimap_material: StyleBoxFlat = map.get("_map_glass") as StyleBoxFlat if map != null else null
    if minimap_material == null or minimap_material.bg_color.get_luminance() < 0.70:
        _fail("The 222px minimap did not switch to soft light")
        return
    var rail: NUS3DKeyRail = hud.get_node_or_null("ActionRail") as NUS3DKeyRail
    if rail == null or rail.key_count() != 11:
        _fail("Tactile controls changed")
        return
    var key: StyleBoxFlat = (rail._tiles["discover"] as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
    if key == null or key.bg_color.get_luminance() < 0.62:
        _fail("Action rail returned to dark opaque tiles")
        return
    var account_buttons: StyleBoxFlat = shell.login_submit.get_theme_stylebox("normal") as StyleBoxFlat
    if account_buttons == null or account_buttons.bg_color.get_luminance() < 0.70:
        _fail("Login button did not inherit the shared skin")
        return
    var coursework: UTownCourseworkUI = shell.game.get_node("CourseworkUI") as UTownCourseworkUI
    if not _bright_panel(coursework.status_card, "CourseworkStatus"):
        return
    if not _bright_panel(coursework.modal_panel, "CourseworkModal"):
        return
    var tutorial: NUS3DTutorial = shell.tutorial
    if tutorial == null or tutorial.pages.is_empty():
        _fail("The six-page user guide failed to build")
        return
    if NUS3DUISkin.TEXT.get_luminance() > 0.30:
        _fail("Text ink is too pale for the bright cards")
        return
    # UI refresh is style-only: network, account data, input bindings and
    # gameplay quest state are not touched.
    print("PASS: bright iOS-inspired soft glass, readable labels, keycap actions, map and tutorial")
    shell.queue_free()
    quit(0)
