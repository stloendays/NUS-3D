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
    if skin.corner_radius_top_left < 18 or not skin.anti_aliasing:
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
    var normalized_panel: StyleBoxFlat = NUS3DUISkin.glass(NUS3DUISkin.ACCENT, 14, 12, true)
    if normalized_panel.corner_radius_top_left != NUS3DUISkin.PANEL_RADIUS_MIN:
        _fail("Shared glass surfaces do not enforce the common corner radius")
        return
    if NUS3DUISkin.ink_for(Color("#AEC0C5")) != NUS3DUISkin.DIM:
        _fail("Legacy pale secondary text is not mapped to readable secondary ink")
        return
    if NUS3DUISkin.ink_for(Color("#E8EEE8")) != NUS3DUISkin.TEXT:
        _fail("Legacy pale heading text is not mapped to primary ink")
        return
    if not _bright_panel(shell.profile_card, "ProfileStatus"):
        return
    var wardrobe: CanvasLayer = shell.game.get_node_or_null("Wardrobe") as CanvasLayer
    var wardrobe_panel: PanelContainer = wardrobe.get("panel") as PanelContainer if wardrobe != null else null
    if not _bright_panel(wardrobe_panel, "WardrobePanel"):
        return
    var leisure_ui: UTownLeisureUI = shell.game.get_node_or_null("LeisureUI") as UTownLeisureUI
    var lounge_panel: PanelContainer = leisure_ui.get("lounge_panel") as PanelContainer if leisure_ui != null else null
    if not _bright_panel(lounge_panel, "PostCourseClubPanel"):
        return
    var guide_prompt_detail: Label = guide.get("prompt_detail") as Label
    var lounge_caption: Label = leisure_ui.get("caption_label") as Label
    if guide_prompt_detail == null or guide_prompt_detail.get_theme_color("font_color") != NUS3DUISkin.DIM:
        _fail("Interaction hint still uses low-contrast legacy pastel ink")
        return
    if lounge_caption == null or lounge_caption.get_theme_color("font_color") != NUS3DUISkin.DIM:
        _fail("Leisure caption still uses low-contrast legacy pastel ink")
        return
    # The former arcade and area cards were stacked on the same pixels; a
    # translucent surface cannot make overlapping lines readable.
    var arcade: UTownArcade = shell.game.get_node_or_null("Arcade") as UTownArcade
    var guide: UTownExperienceGuide = shell.game.get_node_or_null("ExperienceGuide") as UTownExperienceGuide
    var arcade_card: PanelContainer = arcade.status_layer.get_node_or_null("ArcadeCard") as PanelContainer if arcade != null and arcade.status_layer != null else null
    if arcade_card == null or guide == null or guide.zone_card == null:
        _fail("Area or arcade card vanished")
        return
    var combat_rect: Rect2 = Rect2(arcade_card.offset_left, arcade_card.offset_top,
        arcade_card.offset_right - arcade_card.offset_left,
        arcade_card.offset_bottom - arcade_card.offset_top)
    var zone_rect: Rect2 = Rect2(guide.zone_card.offset_left, guide.zone_card.offset_top,
        guide.zone_card.offset_right - guide.zone_card.offset_left,
        guide.zone_card.offset_bottom - guide.zone_card.offset_top)
    if combat_rect.intersects(zone_rect):
        _fail("Zone postcard and arcade stats are again overlapping")
        return
    var ddl: UTownDDLStory = shell.game.get_node_or_null("DDLStory") as UTownDDLStory
    if ddl == null or ddl.countdown_label == null:
        _fail("DDL deadline status is absent")
        return
    ddl._refresh()
    var deadline_ink: Color = ddl.countdown_label.get_theme_color("font_color")
    if deadline_ink.get_luminance() > 0.43:
        _fail("DDL timer has pale text on an opaque white card")
        return
    # UI refresh is style-only: network, account data, input bindings and
    # gameplay quest state are not touched.
    print("PASS: bright iOS-inspired soft glass, readable labels, keycap actions, map and tutorial")
    shell.queue_free()
    quit(0)
