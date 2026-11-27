extends SceneTree
## Godot 4.4+: godot --headless --path godot --script res://tests/story_smoke_test.gd
## Distinct temporary user:// paths protect real players' account and story data.

func _initialize() -> void:
    call_deferred("_run")


func _fail(why: String) -> void:
    paused = false
    push_error("NUS3D story smoke failed: " + why)
    quit(1)


func _seed_for_all_quests(director: NUS3DStoryDirector) -> void:
    for name in ["Maya", "Ethan", "Mei", "Aisha", "Daniel"]:
        director.record_event("talk:" + name)
    for stop in ["GREEN", "ERC", "SRC", "PLAZA"]:
        director.record_event("tour:" + stop)
    for i in range(6):
        director.record_event("note:fixture_%d" % i)
    for event_id in ["ride:shuttle", "entered:ERC", "sprint:finish", "sprint:gold", "weather:rain"]:
        director.record_event(event_id)


func _case(director: NUS3DStoryDirector, choices: Dictionary, expected: String, finale_choice: String = "submit") -> bool:
    if not director.ending_id.is_empty():
        if not director.restart_story():
            _fail("Could not replay after a completed ending")
            return false
    _seed_for_all_quests(director)
    for quest_id in choices.keys():
        if not director.choose_quest(str(quest_id), str(choices[quest_id])):
            _fail("Cannot choose valid quest choice for " + str(quest_id))
            return false
    if not director.final_available():
        _fail("Three finished side quests should unlock the finale")
        return false
    if director.resolve_ending("invalid") != "":
        _fail("Invalid ending choice must not finish a run")
        return false
    var actual: String = director.resolve_ending(finale_choice)
    if actual != expected:
        _fail("Expected ending %s but got %s" % [expected, actual])
        return false
    if not director.archive.has(expected):
        _fail("Finished ending must appear in the permanent gallery")
        return false
    if director.resolve_ending("submit") != "":
        _fail("Finished run must not resolve an ending twice")
        return false
    return true


func _run() -> void:
    NUS3DServices.ensure_scene_services(self)
    var language: NUS3DGameLanguage = root.get_node("GameLanguage") as NUS3DGameLanguage
    var dialogue: NUS3DDialogueBank = root.get_node("DialogueBank") as NUS3DDialogueBank
    language.save_path = "user://nus3d-story-language-%d.cfg" % Time.get_ticks_usec()
    language.set_locale("zh")
    var scene: PackedScene = load("res://scenes/game_shell.tscn") as PackedScene
    if scene == null:
        _fail("Could not load login shell")
        return
    var shell: NUS3DGameShell = scene.instantiate() as NUS3DGameShell
    var accounts: NUS3DAccountStore = shell.get_node("Accounts") as NUS3DAccountStore
    accounts.storage_root = "user://nus3d-story-smoke-%d" % Time.get_ticks_usec()
    root.add_child(shell)
    await process_frame
    if shell.story_director == null or shell.story_director.get_parent() != shell:
        _fail("Story director must be independent of the original 3D scene")
        return
    var director: NUS3DStoryDirector = shell.story_director
    if director.story.get("quests", []).size() != 6 or director.story.get("endings", []).size() != 6:
        _fail("Need six authored quests and six authored endings")
        return
    if director.active or not paused:
        _fail("Campaign must stay inactive before sign-in")
        return
    if accounts.register("story_a", "private-test-123") != "":
        _fail("Could not register first test account")
        return
    shell._enter_game()
    if not director.active or director.completed_count() != 0 or director.unlocked_endings() != 0:
        _fail("First local profile should have empty story progress")
        return
    if director.save_path == accounts.challenge_save_path():
        _fail("Story save must be independent of existing challenge save")
        return
    var alice_story_save: String = director.save_path
    if director.choose_quest("group_assignment", "help"):
        _fail("Must finish quest objectives before choosing")
        return
    if director.final_available() or director.resolve_ending("submit") != "":
        _fail("Finale cannot unlock on a new account")
        return

    # Real NPC interaction emits a dedicated Q-talk event, not an ambient line.
    var npc: Node3D = (shell.game.get_node("CampusLife") as UTownCampusLife).pedestrians[0]["node"]
    var player: UTownPlayer = shell.game.get_node("Player") as UTownPlayer
    player.global_position = npc.global_position + Vector3(0.0, 0.18, 0.0)
    if not (shell.game.get_node("CampusLife") as UTownCampusLife).talk_to_nearest():
        _fail("Could not talk to the first NPC")
        return
    if not director.events.has("talk:Maya"):
        _fail("Explicit Q talk did not record campaign progress")
        return
    if director.record_event("talk:Maya"):
        _fail("Repeated NPC event must not duplicate progress")
        return

    director.open_journal()
    if not director.cover.visible or not paused or director.listing.item_count != 7:
        _fail("Shift+H journal needs a paused, independent six-quest list and finale")
        return
    director.close_journal()
    if director.cover.visible or paused:
        _fail("Closing the journal must resume original gameplay")
        return

    var cases: Array[Dictionary] = [
        {"choices": {"group_assignment":"help", "shuttle_rescue":"share", "lost_lab_notes":"return"}, "ending":"campus_hero"},
        {"choices": {"group_assignment":"ghost", "lost_lab_notes":"copy", "ddl_marathon":"fake"}, "ending":"integrity_alarm"},
        {"choices": {"coffee_protocol":"espresso", "group_assignment":"ghost", "lost_lab_notes":"return", "ddl_marathon":"truth", "clock_mystery":"hoard_time"}, "ending":"burnout"},
        {"choices": {"coffee_protocol":"sleep", "group_assignment":"ghost", "shuttle_rescue":"share"}, "ending":"ddl_survivor"},
        {"choices": {"group_assignment":"help", "lost_lab_notes":"return", "clock_mystery":"break_loop"}, "ending":"loop_breaker"},
        {"choices": {"coffee_protocol":"sleep", "group_assignment":"help", "shuttle_rescue":"share"}, "ending":"ddl_blackhole", "final_choice":"quit"}
    ]
    for fixture in cases:
        if not _case(director, fixture["choices"], str(fixture["ending"]),
                str(fixture.get("final_choice", "submit"))):
            return
    if director.unlocked_endings() != 6 or director.completed_count() < 3:
        _fail("All six endings must be reachable and archived")
        return
    var archive_copy: Dictionary = director.archive.duplicate(true)
    var xp_before: int = int(accounts.level_progress()["total"])
    if not director.restart_story():
        _fail("Cannot restart final completed story")
        return
    _seed_for_all_quests(director)
    if not director.choose_quest("coffee_protocol", "sleep"):
        _fail("Replay choice unavailable")
        return
    if int(accounts.level_progress()["total"]) != xp_before:
        _fail("Repeated sidequest choice must not farm account XP")
        return
    if director.unlocked_endings() != 6:
        _fail("Restart erased ending archive")
        return

    shell._logout()
    if not paused or director.active or not shell.login_cover.visible:
        _fail("Story must lock and release state on logout")
        return
    if accounts.register("story_b", "second-test-123") != "":
        _fail("Could not register second test account")
        return
    shell._enter_game()
    if director.save_path == alice_story_save or director.unlocked_endings() != 0 \
        or director.completed_count() != 0:
        _fail("Different accounts must never share story progress or endings")
        return
    shell._logout()
    if accounts.sign_in("story_a", "private-test-123") != "":
        _fail("Cannot restore original test account")
        return
    shell._enter_game()
    if director.save_path != alice_story_save or director.archive != archive_copy \
        or director.decisions.get("coffee_protocol", "") != "sleep":
        _fail("Endings and choices did not persist across account switching")
        return
    if not FileAccess.file_exists(alice_story_save):
        _fail("Independent story save is missing")
        return
    if accounts.profile.get("awards", {}).size() < 5:
        _fail("Story XP was not integrated into account progression")
        return
    if language.set_locale("en") or language.locale != "zh":
        _fail("Login-selected Chinese story cannot switch language during the session")
        return
    shell._logout()
    if not language.set_locale("en") or accounts.sign_in("story_a", "private-test-123") != "":
        _fail("English login was unavailable after logging out")
        return
    shell._enter_game()
    director.open_journal()
    if not director.heading.text.contains("QUEST JOURNAL") or director.quest_tab.text != "Quests":
        _fail("Story journal did not load the newly selected English login language")
        return
    director.close_journal()
    if director.archive != archive_copy or director.save_path != alice_story_save:
        _fail("Switching login language changed story endings or save mapping")
        return
    shell._logout()
    paused = false
    shell.queue_free()
    await process_frame
    print("NUS3D_STORY_SMOKE_OK")
    quit(0)
