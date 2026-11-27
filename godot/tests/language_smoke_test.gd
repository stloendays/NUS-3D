extends SceneTree
var language_service: NUS3DGameLanguage
var dialogue_service: NUS3DDialogueBank
## Godot 4.4+: godot --headless --path godot --script res://tests/language_smoke_test.gd

func _initialize() -> void:
    call_deferred("_run")


func _contains_han(value: String) -> bool:
    for i in range(value.length()):
        var cp: int = value.unicode_at(i)
        if (cp >= 0x3400 and cp <= 0x9fff) or (cp >= 0xf900 and cp <= 0xfaff):
            return true
    return false


func _fail(reason: String) -> void:
    paused = false
    push_error("NUS3D i18n test failed: " + reason)
    quit(1)


func _run() -> void:
    NUS3DServices.ensure_scene_services(self)
    language_service = root.get_node("GameLanguage") as NUS3DGameLanguage
    dialogue_service = root.get_node("DialogueBank") as NUS3DDialogueBank
    # Never modify the player's real language setting during a smoke test.
    language_service.save_path = "user://nus3d-locale-smoke-%d.cfg" % Time.get_ticks_usec()

    if language_service.catalog.is_empty() or dialogue_service.count() != 14:
        _fail("Missing bilingual catalogue or 14 fictional NPC entries")
        return
    if language_service.set_locale("fr") or language_service.locale == "fr":
        _fail("Unsupported locales must not be accepted")
        return
    if not language_service.set_locale("zh") or language_service.ui_text("Log out") != "退出登录":
        _fail("Chinese UI catalogue failed")
        return
    if not language_service.is_chinese():
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

    # Ambient chatter must not consume the fixed introduction on the first Q press.
    dialogue_service.reset_session()
    var ambient_line: String = dialogue_service.next_line("outdoor", "Maya", 0, true)
    if ambient_line.is_empty():
        _fail("Ambient chatter needs a usable random line")
        return
    var outdoor_intro: String = dialogue_service.next_line("outdoor", "Maya")
    if not outdoor_intro.contains("DDL"):
        _fail("First outdoor NPC introduction must be the fixed Chinese DDL joke")
        return
    var second_intro: String = dialogue_service.next_line("outdoor", "Maya")
    if second_intro == outdoor_intro:
        _fail("Fixed NPC introductions did not advance")
        return

    var random_one: String = dialogue_service.next_line("outdoor", "Maya", 0, true)
    for _i in range(8):
        var random_two: String = dialogue_service.next_line("outdoor", "Maya", 0, true)
        if random_two == random_one:
            _fail("Same NPC repeated an identical random line consecutively")
            return
        random_one = random_two

    if dialogue_service.role_for("outdoor", "Maya") != "DDL幸存者":
        _fail("Chinese NPC role missing")
        return
    if not dialogue_service.has_character("professor", "Prof. Deadline") \
        or not dialogue_service.has_character("indoor", "Daniel"):
        _fail("Indoor or fictional professor dialogue missing")
        return

    if not language_service.set_locale("en") or language_service.ui_text("Log out") != "Log out":
        _fail("Switching to English failed")
        return
    dialogue_service.reset_session()
    if not dialogue_service.next_line("outdoor", "Maya").contains("I'm Maya"):
        _fail("English fixed introduction missing")
        return
    if dialogue_service.role_for("outdoor", "Maya") != "Deadline survivor":
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
    if not language_service.is_chinese() or shell.login_title.text != "登录":
        _fail("Login language toggle did not update Chinese text")
        return
    if shell.tutorial.page_title_label.text != "01  开始游戏":
        _fail("Open tutorial did not change language live")
        return
    if not paused or profile_store.is_logged_in():
        _fail("Changing languages must not start play or sign anyone in")
        return

    var life: UTownCampusLife = shell.game.get_node("CampusLife") as UTownCampusLife
    var story_pedestrians: Array[Dictionary] = []
    if life != null:
        for state_value in life.pedestrians:
            var state: Dictionary = state_value
            if not bool(state.get("ambient", false)):
                story_pedestrians.append(state)
    if life == null or story_pedestrians.size() != 6:
        _fail("Six named NPCs disappeared after localization")
        return
    var npc: Node3D = story_pedestrians[0]["node"]
    var player: UTownPlayer = shell.game.get_node("Player") as UTownPlayer
    player.global_position = npc.global_position + Vector3(0.0, 0.18, 0.0)
    dialogue_service.reset_session()
    if not life.talk_to_nearest() or not life.message.contains("DDL"):
        _fail("Outdoor Q dialogue did not use Chinese fixed NPC text")
        return
    if not life.message.contains("Maya"):
        _fail("NPC name must remain stable across language switches")
        return
    language_service.set_locale("en")
    dialogue_service.reset_session()
    if not life.talk_to_nearest() or not life.message.contains("I'm Maya"):
        _fail("Outdoor Q dialogue did not switch to English")
        return

    # Check-in UI is proximity-gated; return to the GREEN waypoint for HUD assertions.
    player.global_position = shell.tour.stop_world_position(0) + Vector3(0.0, 0.18, 0.0)
    var hud: CanvasLayer = shell.game.get_node("HUD") as CanvasLayer
    var help: Label = hud.get_node("Help") as Label
    var weather: UTownWeather = shell.game.get_node("Weather") as UTownWeather
    language_service.set_locale("zh")
    hud.call("_process", 0.0)
    if not help.text.contains("移动") or not language_service.weather_card(weather).contains("天气"):
        _fail("HUD/help/weather did not switch to Chinese")
        return
    if not (hud.get_node("TourCard/Message") as Label).text.contains("打卡点"):
        _fail("Four-stop discovery UI did not switch to Chinese")
        return
    language_service.set_locale("en")
    hud.call("_process", 0.0)
    if not help.text.contains("WASD move") or not language_service.weather_card(weather).contains("WEATHER"):
        _fail("Switching back to English did not restore original HUD")
        return

    # M18: one selected language, not two variants in the same game screen.
    var coursework: UTownCoursework = shell.game.get_node("Coursework") as UTownCoursework
    var course_ui: UTownCourseworkUI = shell.game.get_node("CourseworkUI") as UTownCourseworkUI
    var leisure_ui: UTownLeisureUI = shell.game.get_node("LeisureUI") as UTownLeisureUI
    var intro: UTownIntro = shell.game.get_node("Intro") as UTownIntro
    var coursework_source: Dictionary = JSON.parse_string(
        FileAccess.get_file_as_string("res://data/coursework_quests.json"))
    var options: Array = coursework_source.get("faculty_options", [])
    if options.size() != 13:
        _fail("All 13 faculties must remain available for local-language selection")
        return
    for faculty in options:
        if str(faculty.get("flavor_en", "")).is_empty():
            _fail("Every faculty flavor requires an English variant")
            return
        for quest in faculty.get("quests", []):
            if str(quest.get("title_en", "")).is_empty() or str(quest.get("story_en", "")).is_empty():
                _fail("All 39 coursework chapters require English and Chinese narrative")
                return
    if not coursework.select_faculty("science"):
        _fail("Cannot choose the science faculty")
        return
    language_service.set_locale("en")
    course_ui._apply_language("en")
    if _contains_han(coursework.status_text()) or _contains_han(coursework.quest_story(coursework.current_quest())):
        _fail("English Coursework HUD or story contains Chinese")
        return
    if _contains_han(course_ui.faculty_picker.get_item_text(0)) or _contains_han(leisure_ui.tab_chess.text):
        _fail("English faculty and leisure controls must not show Chinese labels")
        return
    if _contains_han(intro.subtitle_label.text) or _contains_han(intro.skip_button.text):
        _fail("English introduction still contains Chinese overlays")
        return
    language_service.set_locale("zh")
    course_ui._apply_language("zh")
    if not coursework.status_text().contains("任务") or not coursework.quest_story(coursework.current_quest()).contains("紧急通知"):
        _fail("Chinese Coursework story or dynamic HUD failed to select Chinese data")
        return
    if not course_ui.faculty_picker.get_item_text(0).contains("理学院") or leisure_ui.tab_chess.text != "五子棋":
        _fail("Chinese controls must display only the selected Chinese faculty and game names")
        return
    if not intro.subtitle_label.text.contains("欢迎") or not intro.skip_button.text.contains("跳过"):
        _fail("Chinese intro failed to update captions after login selection")
        return
    if shell.language_game_button != null or not shell.language_login_button.text.begins_with("语言"):
        _fail("Language must be selected only at login, not in the player profile")
        return
    shell.tutorial.close_guide()
    if not paused or profile_store.is_logged_in():
        _fail("Tutorial and preview localization must not start a session")
        return
    # Exercise the REAL local-account registration button route.
    shell._toggle_register()
    shell.login_name.text = "locale_smoke"
    shell.login_password.text = "local-pass-8899"
    shell._submit_login()
    if not profile_store.is_logged_in() or not language_service.session_locked:
        _fail("Signing in did not freeze the chosen language for this session")
        return
    if profile_store.preferred_ui_locale() != "zh" or not profile_store.profile.has("ui_locale"):
        _fail("Login language choice was not stored with this offline profile")
        return
    if language_service.set_locale("en") or not language_service.is_chinese():
        _fail("Language could be changed after a successful login")
        return
    shell._toggle_language()
    if not language_service.is_chinese():
        _fail("The old in-game language shortcut still overrides login choice")
        return
    shell._logout()
    if language_service.session_locked or not paused or not shell.login_cover.visible:
        _fail("Logging out did not restore editable login language choice")
        return
    if not language_service.set_locale("en") or shell.login_title.text != "SIGN IN":
        _fail("A new login session cannot choose English independently")
        return
    paused = false
    print("NUS3D_LANGUAGE_SMOKE_OK")
    quit(0)
