extends SceneTree
## Dedicated regression for Post-Course Club, with isolated local saves.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("NUS3D leisure integration: " + reason)
    quit(1)

func _run() -> void:
    NUS3DServices.ensure_scene_services(self)
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("world cannot load")
        return
    var game: Node3D = packed.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    NUS3DServices.enter_test_playmode(game)
    var leisure: UTownLeisure = game.get_node_or_null("Leisure") as UTownLeisure
    var menu: UTownLeisureUI = game.get_node_or_null("LeisureUI") as UTownLeisureUI
    var course: UTownCoursework = game.get_node_or_null("Coursework") as UTownCoursework
    var life: UTownCampusLife = game.get_node_or_null("CampusLife") as UTownCampusLife
    if leisure == null or menu == null or course == null or life == null:
        _fail("club scenes not wired")
        return
    if leisure.chess_board.size() != 81 or menu.cells.size() != 81 or leisure.CARD_ROUNDS != 5:
        _fail("Gomoku board, AI or five-round cards are missing")
        return
    leisure.save_path = "user://leisure-integration-%d.cfg" % Time.get_ticks_usec()
    leisure._load_stats()
    if leisure.unlocked() or menu.open_lounge():
        _fail("club opened before Coursework completion")
        return
    # Select a real faculty first: _store_active_state intentionally ignores
    # progress until current_faculty_id has been established.
    course.save_path = "user://leisure-coursework-%d.cfg" % Time.get_ticks_usec()
    course._load_progress()
    if course.faculty_options.is_empty():
        _fail("coursework faculty catalogue is empty")
        return
    var faculty_id: String = str(course.faculty_options[0].get("id", ""))
    if not course.select_faculty(faculty_id):
        _fail("could not select a faculty for the club unlock test")
        return
    var chapter_count: int = course.faculty_by_id[faculty_id]["quests"].size()
    if chapter_count != 3:
        _fail("the selected faculty must contain exactly three coursework chapters")
        return
    course.active_quest_index = chapter_count
    course._store_active_state()
    if not course._save_progress():
        _fail("coursework completion state did not persist to the isolated test save")
        return
    if not leisure.unlocked() or not menu.open_lounge():
        _fail("club did not unlock after three chapters")
        return
    if not menu.is_open or not course.modal_open or not game.get_node("Player").movement_locked:
        _fail("minigame overlay did not lock game input")
        return
    menu.close_lounge()
    if menu.is_open or course.modal_open or game.get_node("Player").movement_locked:
        _fail("game input lock did not release after club")
        return
    leisure.reset_chess()
    for col in range(4):
        leisure.chess_board[col] = 1
        leisure.chess_moves += 1
    if not leisure.play_chess(4, 0) or leisure.chess_wins < 1:
        _fail("Gomoku straight-line win failed")
        return
    leisure.start_cards()
    for round_index in range(5):
        if not leisure.play_card(0):
            _fail("card hand failed at round %d" % round_index)
            return
    if not leisure.card_over or leisure.card_games < 1:
        _fail("card game did not finish at five rounds")
        return
    if leisure.celebrate("adult") or not leisure.celebrate("mocktail") or not leisure.safe_to_ride():
        _fail("optional adult mode gate changed mocktail behavior")
        return
    if not leisure.celebrate("adult", true) or leisure.safe_to_ride():
        _fail("no-travel cooldown missing after optional adult social action")
        return
    leisure._process(leisure.SOCIAL_COOLDOWN + 0.1)
    if not leisure.safe_to_ride():
        _fail("social cooldown did not expire")
        return
    leisure.chess_wins = 0
    leisure.card_games = 0
    leisure._load_stats()
    if leisure.chess_wins < 1 or leisure.card_games < 1:
        _fail("club progress did not persist")
        return
    print("PASS: Post-Course Club isolation, Gomoku, cards, social actions, travel guard and save")
    game.queue_free()
    await process_frame
    quit(0)
