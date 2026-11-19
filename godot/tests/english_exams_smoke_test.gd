extends SceneTree
## Run: godot --headless --path godot --script res://tests/english_exams_smoke_test.gd -- --nus3d-self-test

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("M9 English exam regression: " + reason)
    quit(1)

func _run() -> void:
    NUS3DServices.ensure_scene_services(self)
    var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if scene == null:
        _fail("Main game scene did not load")
        return
    var game: Node3D = scene.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    var exams: UTownEnglishExams = game.get_node_or_null("EnglishExams") as UTownEnglishExams
    var coursework: UTownCoursework = game.get_node_or_null("Coursework") as UTownCoursework
    var coursework_ui: UTownCourseworkUI = game.get_node_or_null("CourseworkUI") as UTownCourseworkUI
    var leisure: UTownLeisureUI = game.get_node_or_null("LeisureUI") as UTownLeisureUI
    var player: UTownPlayer = game.get_node_or_null("Player") as UTownPlayer
    var intro: UTownIntro = game.get_node_or_null("Intro") as UTownIntro
    if exams == null or coursework == null or coursework_ui == null or leisure == null or player == null or intro == null:
        _fail("Exam, existing coursework UI or player scene nodes are missing")
        return
    if exams.paper_count != 32 or exams.question_count != 160 or coursework.faculty_options.size() != 13:
        _fail("Expected 32 five-question English papers covering 13 faculties")
        return
    for faculty in coursework.faculty_options:
        if exams.get_papers_for_faculty(str(faculty["id"])).size() < 2:
            _fail("A faculty lacks multiple major-specific English papers")
            return
    if exams.papers["chemistry"]["faculty_id"] != "science" or exams.papers["chemical_engineering"]["faculty_id"] != "cde":
        _fail("Chemistry or Chemical Engineering are mapped to the wrong faculty")
        return
    if exams.paper_by_id("nonexistent").size() != 0 or exams.score_paper("nonexistent", {}).size() != 0:
        _fail("Unknown papers are not handled safely")
        return
    var paper: Dictionary = exams.paper_by_id("chemistry")
    var selected_answers: Dictionary = {}
    for question in paper["questions"]:
        selected_answers[str(question["id"])] = int(question["correct_index"])
    var correct: Dictionary = exams.score_paper("chemistry", selected_answers)
    if int(correct["score"]) != 100 or str(correct["grade"]) != "A+" or not bool(correct["passed"]):
        _fail("Correct answers must yield an A+ and 100%")
        return
    var blank: Dictionary = exams.score_paper("chemistry", {})
    if int(blank["score"]) != 0 or int(blank["unanswered"]) != 5 or bool(blank["passed"]):
        _fail("Blank answers must score zero")
        return
    var borderline: Dictionary = selected_answers.duplicate()
    for i in [0, 1]:
        var question: Dictionary = paper["questions"][i]
        borderline[str(question["id"])] = (int(question["correct_index"]) + 1) % 4
    var minimum_pass: Dictionary = exams.score_paper("chemistry", borderline)
    if int(minimum_pass["score"]) != 60 or not bool(minimum_pass["passed"]):
        _fail("Exactly three correct answers must pass at 60%")
        return
    borderline[str(paper["questions"][2]["id"])] = -1
    var failed: Dictionary = exams.score_paper("chemistry", borderline)
    if int(failed["score"]) != 40 or bool(failed["passed"]):
        _fail("Two correct answers must fail at 40%")
        return

    # Test isolation: use temporary local paths, not any real player progress.
    coursework.save_path = "user://nus3d-exam-coursework-smoke-%d.cfg" % Time.get_ticks_usec()
    exams.save_path = "user://nus3d-english-exams-smoke-%d.cfg" % Time.get_ticks_usec()
    coursework._load_progress()
    exams.load_progress()
    if not coursework.select_faculty("science"):
        _fail("Could not select the existing Science faculty")
        return
    if intro.playing:
        intro.finish_intro()
    if coursework_ui.modal_visible:
        coursework_ui.hide_modal()
    if coursework_ui.intro_blocked:
        coursework_ui.end_intro()
    if not exams.open_library() or not exams.is_open or exams.page != "library":
        _fail("F8 exam library could not open after faculty selection")
        return
    if not coursework.modal_open or not player.movement_locked:
        _fail("Opening an exam must block movement and other coursework actions")
        return
    if coursework_ui.journal_box.get_node_or_null("OpenEnglishMajorExams") == null:
        _fail("The existing Coursework Journal needs an English exam entry")
        return
    if exams.paper_selector.item_count != 3:
        _fail("Science should display its three major papers only")
        return
    if exams.begin_exam("chemical_engineering"):
        _fail("A player should not take another faculty's paper without switching")
        return
    if not exams.begin_exam("chemistry"):
        _fail("Could not start the selected Chemistry paper")
        return
    if not exams.set_answer(str(paper["questions"][0]["id"]), int(paper["questions"][0]["correct_index"])):
        _fail("Answer selection failed")
        return
    if exams.set_answer("nonexistent_question", 0) or exams.set_answer(str(paper["questions"][0]["id"]), 4):
        _fail("Invalid question references or answer choices were accepted")
        return
    exams._process(1.0)
    if exams.remaining_seconds < 178.9 or exams.remaining_seconds > 179.1:
        _fail("The exam timer does not count down")
        return
    var first_attempt: Dictionary = exams.submit_exam()
    if int(first_attempt.get("score", -1)) != 20 or bool(first_attempt.get("passed", true)):
        _fail("An incomplete first attempt must fail without a bonus")
        return
    if coursework.total_xp != 0 or coursework.credits != 0 or exams.passed_ids.has("chemistry"):
        _fail("A failed paper must not pay XP, credits or a certification")
        return
    if not exams.begin_exam("chemistry"):
        _fail("Retake after failure should be available")
        return
    for question in paper["questions"]:
        if not exams.set_answer(str(question["id"]), int(question["correct_index"])):
            _fail("Unable to answer full retake")
            return
    var passed_result: Dictionary = exams.submit_exam()
    if int(passed_result.get("score", -1)) != 100 or not bool(passed_result.get("rewarded", false)):
        _fail("First successful completion should grant the one-time reward")
        return
    if coursework.total_xp != exams.first_pass_xp or coursework.credits != exams.first_pass_credits:
        _fail("First pass must grant Coursework XP and credits exactly once")
        return
    if not exams.passed_ids.has("chemistry") or exams.attempts["chemistry"] != 2:
        _fail("Exam results and attempts were not recorded")
        return
    if exams.result_review.text.find("EXPECTED:") < 0 or exams.result_review.text.find("RESULT:") < 0:
        _fail("The English answer review is missing")
        return
    if not exams.begin_exam("chemistry"):
        _fail("An already-passed paper must remain playable for practice")
        return
    for question in paper["questions"]:
        exams.set_answer(str(question["id"]), int(question["correct_index"]))
    var repeat: Dictionary = exams.submit_exam()
    if bool(repeat["rewarded"]) or coursework.total_xp != exams.first_pass_xp or coursework.credits != exams.first_pass_credits:
        _fail("Repeated passes must not duplicate XP or credits")
        return
    exams.close_exam()
    if exams.is_open or coursework.modal_open or player.movement_locked:
        _fail("Closing an exam must restore existing game input state")
        return
    if not coursework.select_faculty("cde") or not exams.open_library():
        _fail("Faculty switch broke major selection")
        return
    if exams.paper_selector.item_count != 4 or not exams.begin_exam("chemical_engineering"):
        _fail("Engineering faculty must expose its four engineering/architecture papers")
        return
    # Timer submission must never pay rewards for unanswered papers.
    exams._process(181.0)
    if exams.page != "result" or exams.latest_result["score"] != 0:
        _fail("Time-expired paper was not submitted as an unanswered result")
        return
    exams.close_exam()
    coursework._load_progress()
    exams.load_progress()
    if coursework.total_xp != exams.first_pass_xp or coursework.credits != exams.first_pass_credits:
        _fail("Coursework progression was not persisted")
        return
    if int(exams.best_scores.get("chemistry", 0)) != 100 or not exams.passed_ids.has("chemistry"):
        _fail("Exam best score and passed paper were not saved independently")
        return
    exams._restore_missing_awards()
    if coursework.total_xp != exams.first_pass_xp or coursework.credits != exams.first_pass_credits:
        _fail("Restoring an existing certification duplicated the one-time reward")
        return
    # No 3D meshes are needed for exam paperwork: it is UI/data only.
    print("PASS: 13 faculties, 32 majors, 160 English questions, 60% grading, timer, review, faculty gating, one-time XP, isolated save and UI locking.")
    game.queue_free()
    quit(0)
