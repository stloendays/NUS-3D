extends SceneTree
## Godot 4.4+: godot --headless --path godot --script res://tests/language_smoke_test.gd

func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    paused = false
    push_error("NUS3D i18n test failed: " + reason)
    quit(1)


func _run() -> void:
    # Never modify the player's real language setting during a smoke test.
    GameLanguage.save_path = "user://nus3d-locale-smoke-%d.cfg" % Time.get_ticks_usec()

    if GameLanguage.catalog.is_empty() or DialogueBank.count() != 14:
        _fail("Missing bilingual catalogue or 14 fictional NPC entries")
        return
    if GameLanguage.set_locale("fr") or GameLanguage.locale == "fr":
        _fail("Unsupported locales must not be accepted")
        return
    if not GameLanguage.set_locale("zh") or GameLanguage.ui_text("Log out") != "退出登录":
        _fail("Chinese UI catalogue failed")
        return
    if not GameLanguage.is_chinese():
        _fail("Chinese selection was not applied")
        return

    var tutorial_source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/startup_tutorial.json"))
    var pages: Array = tutorial_source.get("pages", [])
    if pages.size() != 6:
        _fail("Tutorial requires six bilingual chapters")
        return
    for page in pages:
        if str(page.get("title_en", "")).is_empty() or str(page.get("title", "")).is_empty():
            _fail("A tutorial chapter is missing its translation")
            return
        for section in page.get("sections", []):
            if str(section.get("body", "")).is_empty() or str(section.get("body_en", "")).is_empty():
                _fail("A tutorial paragraph is missing Chinese or English")
                return

    var outdoor_intro: String = DialogueBank.next_line("outdoor", "Maya")
    if not outdoor_intro.contains("DDL"):
        _fail("First outdoor NPC introduction must be the fixed Chinese DDL joke")
        return
    var second_intro: String = DialogueBank.next_line("outdoor", "Maya")
    if second_intro == outdoor_intro:
        _fail("Fixed NPC introductions did not advance")
        return

    var random_one: String = DialogueBank.next_line("outdoor", "Maya", 0, true)
    for _i in range(8):
        var random_two: String = DialogueBank.next_line("outdoor", "Maya", 0, true)
        if random_two == random_one:
            _fail("Same NPC repeated an identical random line consecutively")
            return
        random_one = random_two

    if DialogueBank.role_for("outdoor", "Maya") != "DDL幸存者":
        _fail("Chinese NPC role missing")
        return
    if not DialogueBank.has_character("professor", "Prof. Deadline") \
        or not DialogueBank.has_character("indoor", "Daniel"):
        _fail("Indoor or fictional professor dialogue missing")
        return

    if not GameLanguage.set_locale("en") or GameLanguage.ui_text("Log out") != "Log out":
        _fail("Switching to English failed")
        return
    DialogueBank.reset_session()
    if not DialogueBank.next_line("outdoor", "Maya").contains("I'm Maya"):
        _fail("English fixed introduction missing")
        return
    if DialogueBank.role_for("outdoor", "Maya") != "Deadline survivor":
        _fail("English NPC role missing")
        return

    var packed: PackedScene = load("res://scenes/game_shell.tscn") as PackedScene
    if packed == null:
        _fail("Localized startup scene cannot load")
        return
    var shell: NUS3DGameShell = packed.instantiate() as NUS3DGameShell
    var profile_store: NUS3DAccountStore = shell.get_node("Accounts") as NUS3DAccountStore
    profile_store.storage_root = "user://nus3d-lang-profiles-%d" % Time.get_ticks_usec()
    root.add_child(shell)
    await process_frame

    if not paused or not shell.login_cover.visible or shell.tutorial == null:
        _fail("Language scene must boot into a paused login")
        return
    if shell.login_title.text != "SIGN IN":
        _fail("English login heading missing")
        return

    shell._open_tutorial()
    if shell.tutorial.page_title_label.text != "01  Getting Started":
        _fail("English tutorial page missing")
        return
    shell._toggle_language()
    if not GameLanguage.is_chinese() or shell.login_title.text != "登录":
        _fail("Login language toggle did not update Chinese text")
        return
    if shell.tutorial.page_title_label.text != "01  开始游戏":
        _fail("Open tutorial did not change language live")
        return
    if not paused or profile_store.is_logged_in():
        _fail("Changing languages must not start play or sign anyone in")
        return

    var life: UTownCampusLife = shell.game.get_node("CampusLife") as UTownCampusLife
    if life == null or life.pedestrians.size() != 6:
        _fail("Existing six NPCs disappeared after localization")
        return
    var npc: Node3D = life.pedestrians[0]["node"]
    var player: UTownPlayer = shell.game.get_node("Player") as UTownPlayer
    player.global_position = npc.global_position + Vector3(0.0, 0.18, 0.0)
    DialogueBank.reset_session()
    if not life.talk_to_nearest() or not life.message.contains("DDL"):
        _fail("Outdoor Q dialogue did not use Chinese fixed NPC text")
        return
    if not life.message.contains("Maya"):
        _fail("NPC name must remain stable across language switches")
        return
    GameLanguage.set_locale("en")
    DialogueBank.reset_session()
    if not life.talk_to_nearest() or not life.message.contains("I'm Maya"):
        _fail("Outdoor Q dialogue did not switch to English")
        return

    var hud: CanvasLayer = shell.game.get_node("HUD") as CanvasLayer
    var help: Label = hud.get_node("Help") as Label
    var weather: UTownWeather = shell.game.get_node("Weather") as UTownWeather
    GameLanguage.set_locale("zh")
    hud.call("_process", 0.0)
    if not help.text.contains("移动") or not GameLanguage.weather_card(weather).contains("天气"):
        _fail("HUD/help/weather did not switch to Chinese")
        return
    if not (hud.get_node("TourCard/Message") as Label).text.contains("打卡点"):
        _fail("Four-stop discovery UI did not switch to Chinese")
        return
    GameLanguage.set_locale("en")
    hud.call("_process", 0.0)
    if not help.text.contains("WASD move") or not GameLanguage.weather_card(weather).contains("WEATHER"):
        _fail("Switching back to English did not restore original HUD")
        return

    shell.tutorial.close_guide()
    if not paused or profile_store.is_logged_in():
        _fail("Bilingual guide must not alter pause/account state")
        return
    paused = false
    print("NUS3D_LANGUAGE_SMOKE_OK")
    quit(0)
