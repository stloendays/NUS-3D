extends SceneTree
## Integration guard for independently developed NUS-3D systems and per-profile XP.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("NUS3D integration smoke: " + message)
    quit(1)

func _run() -> void:
    NUS3DServices.ensure_scene_services(self)
    var language_service: NUS3DGameLanguage = root.get_node("GameLanguage") as NUS3DGameLanguage
    var dialogue_service: NUS3DDialogueBank = root.get_node("DialogueBank") as NUS3DDialogueBank
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("Combined game scene failed to load")
        return
    var game: Node3D = packed.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    for node_name in ["World", "Player", "HUD", "Coursework", "CourseworkUI", "Intro",
            "Arcade", "Streetscape", "DDLStory", "GreenDining", "Coins", "ExperienceGuide"]:
        if game.get_node_or_null(node_name) == null:
            _fail("Integrated gameplay node missing: " + node_name)
            return
    var arcade: UTownArcade = game.get_node("Arcade") as UTownArcade
    var coins: UTownCoins = game.get_node("Coins") as UTownCoins
    var coursework: UTownCoursework = game.get_node("Coursework") as UTownCoursework
    var hud: CanvasLayer = game.get_node("HUD") as CanvasLayer
    var ui: UTownCourseworkUI = game.get_node("CourseworkUI") as UTownCourseworkUI
    if arcade.projectiles.size() != 8 or coins.pickups.size() != 12:
        _fail("Bounded combat or coin pool regressed")
        return
    if coursework.faculty_options.size() != 13 or not hud.has_node("ActionRail"):
        _fail("Faculty data or tactile action rail not integrated")
        return
    if ui.status_card == null or language_service.catalog.is_empty() or dialogue_service.count() != 14:
        _fail("Bilingual gameplay components did not initialize")
        return
    if language_service.is_chinese() and not (hud.get_node("Help") as Label).text.contains("移动"):
        _fail("Chinese help requires a supported locale")
        return
    var accounts: NUS3DAccountStore = NUS3DAccountStore.new()
    accounts.storage_root = "user://nus3d-integration-%d" % Time.get_ticks_usec()
    root.add_child(accounts)
    if accounts.register("alpha", "testpass-123") != "":
        _fail("Cannot create Alpha")
        return
    var alpha_path: String = accounts.feature_save_path("arcade")
    if accounts.sync_source_xp("arcade", 50) != 50 or accounts.sync_source_xp("arcade", 50) != 0:
        _fail("Arcade XP replay prevention failed")
        return
    if accounts.sync_source_xp("coursework", 100) != 100 or int(accounts.level_progress()["total"]) != 150:
        _fail("Coursework XP was not unified with account XP")
        return
    accounts.sign_out()
    if accounts.register("beta", "testpass-456") != "":
        _fail("Cannot create Beta")
        return
    if accounts.feature_save_path("arcade") == alpha_path or int(accounts.level_progress()["total"]) != 0:
        _fail("Game progress leaked across local accounts")
        return
    if accounts.sync_source_xp("arcade", 10) != 10:
        _fail("Second account could not earn independent XP")
        return
    accounts.sign_out()
    if accounts.sign_in("alpha", "testpass-123") != "" or accounts.sync_source_xp("arcade", 50) != 0:
        _fail("Reload did not persist XP source ledger")
        return
    if int(accounts.level_progress()["total"]) != 150:
        _fail("Avatar XP changed after switching back to Alpha")
        return
    print("PASS: NUS3D integrated world, bilingual tactile HUD, isolated feature saves and XP")
    accounts.queue_free()
    game.queue_free()
    quit(0)
