extends SceneTree
## Run headlessly without activating an actual microphone.
## Synthetic RMS windows exercise the scoring logic, not Windows device permissions.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("M10 oral presentation regression: " + reason)
    quit(1)

func _run() -> void:
    var source: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if source == null:
        _fail("Main scene missing")
        return
    var game: Node3D = source.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    var voice: UTownVoicePresentation = game.get_node_or_null("VoicePresentation") as UTownVoicePresentation
    var coursework: UTownCoursework = game.get_node_or_null("Coursework") as UTownCoursework
    var course_ui: UTownCourseworkUI = game.get_node_or_null("CourseworkUI") as UTownCourseworkUI
    var exams: UTownEnglishExams = game.get_node_or_null("EnglishExams") as UTownEnglishExams
    var player: UTownPlayer = game.get_node_or_null("Player") as UTownPlayer
    var intro: UTownIntro = game.get_node_or_null("Intro") as UTownIntro
    var hud: CanvasLayer = game.get_node_or_null("HUD") as CanvasLayer
    if voice == null or coursework == null or course_ui == null or exams == null or player == null or intro == null or hud == null:
        _fail("Existing game systems or voice presentation controller missing")
        return
    if voice.briefs.size() != 32 or voice.by_faculty.size() != 13 or voice.topics_for_faculty("science").size() != 3:
        _fail("Expected 32 major topics across 13 faculties")
        return
    if not bool(ProjectSettings.get_setting("audio/driver/enable_input", false)):
        _fail("Godot project microphone input switch is disabled")
        return
    if voice.microphone_player != null or voice.capture != null or voice.mic_running:
        _fail("Microphone started without opt-in")
        return
    if course_ui.journal_box.get_node_or_null("OpenEnglishPresentations") == null:
        _fail("Coursework journal lacks the presentation menu entry")
        return
    coursework.save_path = "user://m10-coursework-%d.cfg" % Time.get_ticks_usec()
    voice.save_path = "user://m10-presentations-%d.cfg" % Time.get_ticks_usec()
    coursework._load_progress()
    voice.load_progress()
    if intro.playing:
        intro.finish_intro()
    if not coursework.select_faculty("science"):
        _fail("Could not choose the existing Science faculty")
        return
    if course_ui.modal_visible:
        course_ui.hide_modal()
    if not voice.open_library() or not voice.is_open:
        _fail("F9 presentation modal would not open")
        return
    if voice.major_selector.item_count != 3 or voice.phase != "library" or not player.movement_locked:
        _fail("Presentation library did not follow active faculty or block movement")
        return
    if exams.open_library():
        _fail("F8 exam can overlap a presentation modal")
        return
    if voice.start_topic("presentation_chemical_engineering", false):
        _fail("A cross-faculty presentation was accepted")
        return

    # Practice is permitted on devices with no microphone, with no rewards.
    if not voice.start_topic("presentation_chemistry", false):
        _fail("Practice topic failed to start")
        return
    if not voice.practice_mode or voice.mic_running:
        _fail("Practice should not open a microphone bus")
        return
    voice._credit_audio_window(0.1, 3.0, true)
    if voice.voiced_by_slide[0] > 0.0:
        _fail("Practice mode must never count mocked speech as verified")
        return
    for i in range(3):
        if not voice._advance_slide():
            _fail("Offline practice cannot advance through the three slide prompts")
            return
    voice.select_qa_answer(0)
    var practice: Dictionary = voice.finish_presentation(false)
    if bool(practice["passed"]) or bool(practice["rewarded"]) or coursework.total_xp != 0:
        _fail("Practice mode must not award Coursework XP or certification")
        return

    # Exercise core grading with synthetic samples. This deliberately bypasses
    # OS hardware only inside a headless regression; live gameplay requires
    # _start_microphone() and AudioEffectCapture to produce actual audio frames.
    voice._return_to_library()
    if not voice.start_topic("presentation_chemistry", false):
        _fail("Could not start the mock device scoring test")
        return
    voice.practice_mode = false
    voice.mic_running = true
    if voice._advance_slide():
        _fail("A mic-mode slide advanced without enough voice activity")
        return
    voice._credit_audio_window(0.0, 10.0, true)
    voice._credit_audio_window(0.001, 10.0, true)
    if voice.voiced_by_slide[0] > 0.0:
        _fail("Mic silence and near-noise must not earn speaking time")
        return
    for index in range(3):
        for frame in range(20):
            voice._credit_audio_window(0.08, 0.25, true)
        if voice.voiced_by_slide[index] < 4.999:
            _fail("RMS activity threshold did not count 5 seconds on slide %d" % index)
            return
        if not voice._advance_slide():
            _fail("A fully spoken slide did not advance")
            return
    if voice.phase != "qa" or voice.mic_running:
        _fail("Microphone must stop before audience Q&A")
        return
    var q: Dictionary = voice.briefs["presentation_chemistry"]["audience_question"]
    if not voice.select_qa_answer(int(q["correct_index"])):
        _fail("Valid audience answer was rejected")
        return
    var certified: Dictionary = voice.finish_presentation(false)
    if not bool(certified["passed"]) or not bool(certified["rewarded"]) or int(certified["score"]) != 100:
        _fail("Verified 3-slide talk and correct Q&A must score 100 with first-pass award")
        return
    if coursework.total_xp != 70 or coursework.credits != 20 or not voice.passed_ids.has("presentation_chemistry"):
        _fail("XP and credits did not bridge to Coursework exactly once")
        return
    voice._return_to_library()
    if not voice.start_topic("presentation_chemistry", false):
        _fail("A certified topic cannot be retaken")
        return
    voice.practice_mode = false
    voice.mic_running = true
    for index in range(3):
        for frame in range(20):
            voice._credit_audio_window(0.08, 0.25, true)
        if not voice._advance_slide():
            _fail("Retake slide failed")
            return
    var wrong: int = (int(q["correct_index"]) + 1) % 3
    voice.select_qa_answer(wrong)
    var retake: Dictionary = voice.finish_presentation(false)
    if bool(retake["rewarded"]) or coursework.total_xp != 70 or coursework.credits != 20:
        _fail("Repeated certified presentations must not re-award XP")
        return
    if not bool(retake["passed"]) or int(retake["score"]) != 80:
        _fail("Incorrect Q&A should reduce score, not invalidate spoken slides")
        return
    voice.close_presentation()
    if voice.is_open or player.movement_locked or coursework.modal_open:
        _fail("Game input was not restored after closing the modal")
        return
    if voice.capture != null or voice.microphone_player != null or not voice.mic_bus_name.is_empty():
        _fail("Mic capture/bus survived end of presentation")
        return

    coursework._load_progress()
    voice.load_progress()
    if coursework.total_xp != 70 or coursework.credits != 20 or not voice.passed_ids.has("presentation_chemistry"):
        _fail("Presentation and Coursework records were not saved")
        return
    voice._restore_missing_awards()
    if coursework.total_xp != 70 or coursework.credits != 20:
        _fail("Resume recovery duplicated the first-pass reward")
        return
    if not coursework.select_faculty("cde") or not voice.open_library():
        _fail("Changing faculty breaks the presentation library")
        return
    if voice.major_selector.item_count != 4:
        _fail("Engineering faculty must show four presentation topics")
        return
    if voice.start_topic("presentation_chemistry", false):
        _fail("Changing faculty did not restrict available presentation topics")
        return
    voice.close_presentation()
    print("PASS: 32 English talks, opt-in mic startup, silent/practice fallback, 3 RMS-gated slides, audience Q&A, repeat-safe XP, local save and input isolation.")
    game.queue_free()
    quit(0)
