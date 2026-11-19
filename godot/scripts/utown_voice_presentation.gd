extends CanvasLayer
class_name UTownVoicePresentation
## Optional, offline English-only oral presentation game.
## Audio samples are inspected in RAM to measure activity, never stored/transcribed.
## A muted and temporary audio bus avoids feedback; it is removed on every exit.

const DATA_PATH: String = "res://data/presentation_briefs.json"
const SAVE_PATH: String = "user://nus3d_presentations.cfg"
const SCHEMA: String = "nus3d-voice-presentations-v1"
const MIC_BUS_PREFIX: String = "NUS3DPresentation_"
const MIC_LEVEL_THRESHOLD: float = 0.015
const AUDIO_POLL_SECONDS: float = 0.10
const MAX_AUDIO_FRAMES_PER_POLL: int = 8192
const MIN_SLIDE_VOICE_SECONDS: float = 5.0
const REQUIRED_SLIDES: int = 3
const MAX_PRESENTATION_SECONDS: float = 150.0

@onready var coursework: UTownCoursework = $"../Coursework"
@onready var course_ui: UTownCourseworkUI = $"../CourseworkUI"
@onready var player: UTownPlayer = $"../Player"
@onready var campus: UTownCampusLife = $"../CampusLife"
@onready var intro: UTownIntro = $"../Intro"
@onready var leisure_ui: UTownLeisureUI = $"../LeisureUI"
@onready var exams: UTownEnglishExams = $"../EnglishExams"
@onready var hud: CanvasLayer = $"../HUD"

var save_path: String = SAVE_PATH
var briefs: Dictionary = {}
var by_faculty: Dictionary = {}
var attempts: Dictionary = {}
var best_scores: Dictionary = {}
var passed_ids: PackedStringArray = PackedStringArray()
var rewards_xp: int = 70
var rewards_credits: int = 20
var is_open: bool = false
var phase: String = "library"
var active_id: String = ""
var slide_index: int = 0
var voiced_by_slide: Array[float] = [0.0, 0.0, 0.0]
var time_left: float = MAX_PRESENTATION_SECONDS
var quiz_choice: int = -1
var latest_result: Dictionary = {}
var practice_mode: bool = true
var mic_running: bool = false
var verified_sample_frames: int = 0
var last_audio_level: float = 0.0
var last_audio_frame_seconds: float = 0.0
var mic_notice: String = "Microphone OFF"
var record_before_mouse: int = Input.MOUSE_MODE_CAPTURED
var record_before_movement: bool = false
var record_before_course_modal: bool = false

var microphone_player: AudioStreamPlayer
var capture: AudioEffectCapture
var mic_bus_name: String = ""
var mic_poll_clock: float = 0.0
var ui_clock: float = 0.0

var backdrop: ColorRect
var library_panel: VBoxContainer
var talk_panel: VBoxContainer
var question_panel: VBoxContainer
var result_panel: VBoxContainer
var major_selector: OptionButton
var library_details: Label
var title_label: Label
var instruction_label: Label
var progress_label: Label
var recording_label: Label
var rms_meter: ProgressBar
var clock_label: Label
var next_button: Button
var question_label: Label
var quiz_options: Array[CheckBox] = []
var submit_button: Button
var result_heading: Label
var result_details: Label
var result_review: Label

func _ready() -> void:
    layer = 28
    _read_briefs()
    _build_ui()
    load_progress()
    _restore_missing_awards()

func _read_briefs() -> void:
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if typeof(raw) != TYPE_DICTIONARY:
        push_error("Presentation briefs file missing or malformed")
        return
    var doc: Dictionary = raw
    if str(doc.get("schema", "")) != SCHEMA or str(doc.get("language", "")) != "en" or not bool(doc.get("unofficial", false)):
        push_error("Presentation papers must be English-only and fictional")
        return
    var scoring: Dictionary = doc.get("scoring", {})
    rewards_xp = clampi(int(scoring.get("first_pass_xp", 70)), 0, 200)
    rewards_credits = clampi(int(scoring.get("first_pass_credits", 20)), 0, 100)
    for raw_brief in doc.get("presentations", []):
        if typeof(raw_brief) != TYPE_DICTIONARY:
            continue
        var item: Dictionary = raw_brief
        var key: String = str(item.get("id", ""))
        var faculty: String = str(item.get("faculty_id", ""))
        var slides: Array = item.get("slides", [])
        var q: Dictionary = item.get("audience_question", {})
        if not key.is_valid_identifier() or briefs.has(key) or not coursework.faculty_by_id.has(faculty):
            continue
        if slides.size() != REQUIRED_SLIDES or q.get("options", []).size() != 3:
            continue
        if not exams.papers.has(str(item.get("exam_paper_id", ""))):
            continue
        briefs[key] = item
        if not by_faculty.has(faculty):
            by_faculty[faculty] = []
        by_faculty[faculty].append(item)

func topics_for_faculty(faculty: String) -> Array:
    return by_faculty.get(faculty, [])

func _save_progress() -> bool:
    var data := ConfigFile.new()
    data.set_value("presentations", "schema_version", 1)
    data.set_value("presentations", "attempts", attempts)
    data.set_value("presentations", "best_scores", best_scores)
    data.set_value("presentations", "passed_ids", passed_ids)
    var error: Error = data.save(save_path)
    if error != OK:
        push_warning("Presentation result could not be saved")
    return error == OK

func load_progress() -> void:
    attempts.clear()
    best_scores.clear()
    passed_ids.clear()
    var data := ConfigFile.new()
    if data.load(save_path) != OK:
        return
    var stored_attempts: Variant = data.get_value("presentations", "attempts", {})
    if typeof(stored_attempts) == TYPE_DICTIONARY:
        for id in stored_attempts:
            if briefs.has(str(id)):
                attempts[str(id)] = clampi(int(stored_attempts[id]), 0, 9999)
    var stored_best: Variant = data.get_value("presentations", "best_scores", {})
    if typeof(stored_best) == TYPE_DICTIONARY:
        for id in stored_best:
            if briefs.has(str(id)):
                best_scores[str(id)] = clampi(int(stored_best[id]), 0, 100)
    var stored_passed: Variant = data.get_value("presentations", "passed_ids", PackedStringArray())
    if typeof(stored_passed) == TYPE_ARRAY or typeof(stored_passed) == TYPE_PACKED_STRING_ARRAY:
        for id in stored_passed:
            var key: String = str(id)
            if briefs.has(key) and not passed_ids.has(key):
                passed_ids.append(key)

func _restore_missing_awards() -> void:
    for id in passed_ids:
        if briefs.has(id):
            coursework.claim_exam_reward_once(id, rewards_xp, rewards_credits)

func _text(value: String, font_points: int = 16, color: String = "#2c3a46") -> Label:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_points)
    label.add_theme_color_override("font_color", Color.html(color))
    return label

func _button(value: String, action: Callable) -> Button:
    var b := Button.new()
    b.text = value
    b.custom_minimum_size.y = 42
    b.pressed.connect(action)
    return b

func _build_ui() -> void:
    backdrop = ColorRect.new()
    backdrop.name = "PresentationModalBackdrop"
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.color = Color(0.018, 0.036, 0.060, 0.94)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    backdrop.visible = false
    add_child(backdrop)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    backdrop.add_child(center)
    var page := PanelContainer.new()
    page.name = "EnglishPresentationSheet"
    page.custom_minimum_size = Vector2(870, 620)
    page.mouse_filter = Control.MOUSE_FILTER_STOP
    var style := StyleBoxFlat.new()
    style.bg_color = Color.html("#f6f5f0")
    style.set_corner_radius_all(9)
    style.set_border_width_all(2)
    style.border_color = Color.html("#ced4d4")
    style.content_margin_left = 28
    style.content_margin_right = 28
    style.content_margin_top = 22
    style.content_margin_bottom = 22
    page.add_theme_stylebox_override("panel", style)
    center.add_child(page)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 13)
    page.add_child(content)
    content.add_child(_text("UTOWN PRESENTATION STUDIO   /   ORIGINAL ENGLISH GAME TASK", 13, "#5c6d78"))
    content.add_child(HSeparator.new())

    library_panel = VBoxContainer.new()
    library_panel.add_theme_constant_override("separation", 16)
    content.add_child(library_panel)
    library_panel.add_child(_text("ENGLISH ORAL PRESENTATION", 27, "#1a3449"))
    library_panel.add_child(_text("Select your major. Present three short slides and answer a question. A microphone is optional for practice, but required for certified rewards.", 17))
    major_selector = OptionButton.new()
    major_selector.name = "PresentationMajor"
    major_selector.custom_minimum_size.y = 45
    major_selector.item_selected.connect(_selected_major)
    library_panel.add_child(major_selector)
    library_details = _text("", 16)
    library_details.custom_minimum_size.y = 190
    library_panel.add_child(library_details)
    library_panel.add_child(_text("PRIVACY: Voice is inspected briefly in local memory for activity only. No audio or transcript is saved or sent anywhere.", 14, "#496c69"))
    library_panel.add_child(_button("ENABLE MICROPHONE & START  (explicit opt-in)", _start_mic_button))
    library_panel.add_child(_button("PRACTICE WITHOUT MICROPHONE  (no XP reward)", _start_practice_button))
    library_panel.add_child(_button("CLOSE", close_presentation))

    talk_panel = VBoxContainer.new()
    talk_panel.visible = false
    talk_panel.add_theme_constant_override("separation", 16)
    content.add_child(talk_panel)
    title_label = _text("", 24, "#183345")
    talk_panel.add_child(title_label)
    clock_label = _text("", 20, "#9c4234")
    talk_panel.add_child(clock_label)
    instruction_label = _text("", 19, "#324753")
    instruction_label.custom_minimum_size.y = 172
    talk_panel.add_child(instruction_label)
    recording_label = _text("", 16, "#546a72")
    talk_panel.add_child(recording_label)
    rms_meter = ProgressBar.new()
    rms_meter.name = "LocalAudioLevel"
    rms_meter.min_value = 0
    rms_meter.max_value = 1
    rms_meter.show_percentage = false
    rms_meter.custom_minimum_size.y = 15
    talk_panel.add_child(rms_meter)
    progress_label = _text("", 15, "#4c5961")
    talk_panel.add_child(progress_label)
    next_button = _button("NEXT SLIDE", _advance_slide)
    talk_panel.add_child(next_button)
    talk_panel.add_child(_button("STOP / RETURN TO LIBRARY", _return_to_library))

    question_panel = VBoxContainer.new()
    question_panel.visible = false
    question_panel.add_theme_constant_override("separation", 16)
    content.add_child(question_panel)
    question_panel.add_child(_text("AUDIENCE QUESTION  /  FINAL Q&A", 23, "#203b50"))
    question_label = _text("", 19)
    question_label.custom_minimum_size.y = 95
    question_panel.add_child(question_label)
    var group := ButtonGroup.new()
    for index in range(3):
        var choice := CheckBox.new()
        choice.name = "QandA_Option_%d" % index
        choice.button_group = group
        choice.custom_minimum_size.y = 55
        choice.add_theme_font_size_override("font_size", 17)
        choice.add_theme_color_override("font_color", Color.html("#233b48"))
        choice.toggled.connect(_on_quiz_select.bind(index))
        question_panel.add_child(choice)
        quiz_options.append(choice)
    submit_button = _button("SUBMIT PRESENTATION", _on_submit)
    question_panel.add_child(submit_button)
    question_panel.add_child(_button("LEAVE / DISCARD", _return_to_library))

    result_panel = VBoxContainer.new()
    result_panel.visible = false
    result_panel.add_theme_constant_override("separation", 16)
    content.add_child(result_panel)
    result_heading = _text("", 27, "#173145")
    result_panel.add_child(result_heading)
    result_details = _text("", 17)
    result_details.custom_minimum_size.y = 160
    result_panel.add_child(result_details)
    result_review = _text("", 16, "#2f4958")
    result_review.custom_minimum_size.y = 135
    result_panel.add_child(result_review)
    result_panel.add_child(_button("OTHER TOPICS / RETAKE", _return_to_library))
    result_panel.add_child(_button("RETURN TO CAMPUS", close_presentation))

func _can_open() -> bool:
    return not is_open and not coursework.current_faculty_id.is_empty() and hud.visible \
        and not intro.playing and not course_ui.intro_blocked and not course_ui.modal_visible \
        and not exams.is_open and not leisure_ui.is_open \
        and not campus.on_shuttle and not campus.interior_active \
        and not player.bicycle_mode and not player.movement_locked

func open_library() -> bool:
    if not _can_open():
        return false
    record_before_mouse = Input.mouse_mode
    record_before_movement = player.movement_locked
    record_before_course_modal = coursework.modal_open
    is_open = true
    coursework.modal_open = true
    player.movement_locked = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    backdrop.visible = true
    _return_to_library()
    return true

func close_presentation() -> void:
    _stop_microphone()
    if not is_open:
        return
    is_open = false
    backdrop.visible = false
    phase = "library"
    active_id = ""
    coursework.modal_open = record_before_course_modal
    player.movement_locked = record_before_movement or campus.on_shuttle
    Input.mouse_mode = record_before_mouse

func _return_to_library() -> void:
    _stop_microphone()
    phase = "library"
    active_id = ""
    library_panel.visible = true
    talk_panel.visible = false
    question_panel.visible = false
    result_panel.visible = false
    _refresh_library()

func _refresh_library() -> void:
    major_selector.clear()
    for topic in topics_for_faculty(coursework.current_faculty_id):
        var index: int = major_selector.item_count
        major_selector.add_item(str(topic["major"]))
        major_selector.set_item_metadata(index, str(topic["id"]))
    if major_selector.item_count > 0:
        major_selector.select(0)
    _selected_major(0)

func _selected_major(index: int) -> void:
    if index < 0 or index >= major_selector.item_count:
        library_details.text = "No presentation is available. Select a faculty first."
        return
    var id: String = str(major_selector.get_item_metadata(index))
    var topic: Dictionary = briefs[id]
    library_details.text = "MAJOR: %s\nTOPIC: %s\n\n3 speaking slides  |  %d s total  |  5 s of detected microphone activity per slide\nQ&A after slide 3  |  Successful first completion: +%d XP and +%d Coursework Credits\nBEST: %s  |  ATTEMPTS: %d  |  %s" % [
        str(topic["major"]), str(topic["title"]), int(topic["timer_seconds"]),
        rewards_xp, rewards_credits,
        ("%d%%" % int(best_scores[id])) if best_scores.has(id) else "Not attempted",
        int(attempts.get(id, 0)), "COMPLETED" if passed_ids.has(id) else "NOT YET COMPLETED"
    ]

func _start_mic_button() -> void:
    _begin_selected(true)

func _start_practice_button() -> void:
    _begin_selected(false)

func _begin_selected(microphone_requested: bool) -> void:
    if major_selector.selected < 0:
        return
    start_topic(str(major_selector.get_selected_metadata()), microphone_requested)

func start_topic(id: String, microphone_requested: bool) -> bool:
    if not is_open or not briefs.has(id) or str(briefs[id]["faculty_id"]) != coursework.current_faculty_id:
        return false
    _stop_microphone()
    active_id = id
    slide_index = 0
    voiced_by_slide = [0.0, 0.0, 0.0]
    time_left = minf(MAX_PRESENTATION_SECONDS, float(briefs[id]["timer_seconds"]))
    quiz_choice = -1
    last_audio_level = 0.0
    verified_sample_frames = 0
    latest_result.clear()
    practice_mode = true
    mic_notice = "Practice mode: microphone disabled."
    phase = "talk"
    if microphone_requested:
        practice_mode = not _start_microphone()
        if practice_mode:
            mic_notice = "Microphone unavailable or blocked. Practice mode (no rewards)."
    library_panel.visible = false
    talk_panel.visible = true
    question_panel.visible = false
    result_panel.visible = false
    _refresh_talk()
    return true

func _start_microphone() -> bool:
    # No input is created during startup, library browsing, or practice.
    if not bool(ProjectSettings.get_setting("audio/driver/enable_input", false)):
        return false
    if AudioServer.get_driver_name() == "Dummy" or AudioServer.get_input_device_list().is_empty():
        return false
    mic_bus_name = MIC_BUS_PREFIX + str(get_instance_id())
    if AudioServer.get_bus_index(mic_bus_name) >= 0:
        return false
    AudioServer.add_bus()
    var bus_index: int = AudioServer.get_bus_count() - 1
    AudioServer.set_bus_name(bus_index, mic_bus_name)
    capture = AudioEffectCapture.new()
    capture.buffer_length = 0.25
    AudioServer.add_bus_effect(bus_index, capture, 0)
    AudioServer.set_bus_mute(bus_index, true)
    microphone_player = AudioStreamPlayer.new()
    microphone_player.name = "TemporaryMutedMic"
    microphone_player.bus = mic_bus_name
    microphone_player.stream = AudioStreamMicrophone.new()
    add_child(microphone_player)
    microphone_player.play()
    mic_running = microphone_player.playing
    mic_poll_clock = 0.0
    if not mic_running:
        _stop_microphone()
        return false
    mic_notice = "Microphone ON. Only sound level and duration are measured."
    return true

func _stop_microphone() -> void:
    mic_running = false
    if microphone_player != null:
        microphone_player.stop()
        microphone_player.queue_free()
        microphone_player = null
    if not mic_bus_name.is_empty():
        var index: int = AudioServer.get_bus_index(mic_bus_name)
        if index >= 1:
            AudioServer.remove_bus(index)
    mic_bus_name = ""
    capture = null
    last_audio_level = 0.0
    mic_poll_clock = 0.0

func _exit_tree() -> void:
    _stop_microphone()

func _rms_of_samples(samples: PackedVector2Array) -> float:
    if samples.is_empty():
        return 0.0
    var total: float = 0.0
    for stereo in samples:
        var mono: float = (stereo.x + stereo.y) * 0.5
        total += mono * mono
    return sqrt(total / float(samples.size()))

func _credit_audio_window(rms: float, seconds: float, from_hardware: bool) -> void:
    # Only invoked by the real AudioEffectCapture path, except in mocked CI tests.
    # A silence-only or no-device session earns no speaking progress.
    if phase != "talk" or practice_mode or not mic_running or not from_hardware or seconds <= 0.0:
        return
    if rms <= 0.000001:
        return
    verified_sample_frames += 1
    last_audio_level = clampf(rms / 0.12, 0.0, 1.0)
    last_audio_frame_seconds = seconds
    if rms >= MIC_LEVEL_THRESHOLD:
        voiced_by_slide[slide_index] = minf(MIN_SLIDE_VOICE_SECONDS + 2.0,
            voiced_by_slide[slide_index] + minf(seconds, 0.25))

func _poll_microphone() -> void:
    if not mic_running or capture == null or phase != "talk":
        return
    var frames: int = mini(capture.get_frames_available(), MAX_AUDIO_FRAMES_PER_POLL)
    if frames <= 0:
        last_audio_level = 0.0
        return
    var samples: PackedVector2Array = capture.get_buffer(frames)
    if samples.is_empty():
        return
    var seconds: float = float(samples.size()) / maxf(1.0, float(AudioServer.get_mix_rate()))
    _credit_audio_window(_rms_of_samples(samples), seconds, true)

func _refresh_talk() -> void:
    if phase != "talk" or active_id.is_empty():
        return
    var topic: Dictionary = briefs[active_id]
    var slide: Dictionary = topic["slides"][slide_index]
    title_label.text = str(topic["title"]) + "\n" + str(slide["title"])
    instruction_label.text = str(slide["talk_prompt"])
    clock_label.text = "%d seconds left" % ceili(time_left)
    var needed: float = maxf(0.0, MIN_SLIDE_VOICE_SECONDS - voiced_by_slide[slide_index])
    var microphone_state: String = "PRACTICE  /  no microphone  /  no reward" if practice_mode else mic_notice
    recording_label.text = microphone_state
    rms_meter.value = last_audio_level if mic_running else 0.0
    progress_label.text = "MIC ACTIVITY on slide %d: %.1f / %.1f s  |  %s" % [
        slide_index + 1, voiced_by_slide[slide_index], MIN_SLIDE_VOICE_SECONDS,
        "Ready for next slide." if needed <= 0.0 else "Speak for %.1f s more." % needed
    ]
    next_button.text = "ANSWER AUDIENCE QUESTION" if slide_index == REQUIRED_SLIDES - 1 else "NEXT SLIDE"

func _advance_slide() -> bool:
    if not is_open or phase != "talk":
        return false
    if not practice_mode and voiced_by_slide[slide_index] < MIN_SLIDE_VOICE_SECONDS:
        mic_notice = "Please speak clearly for %.1f more seconds." % (MIN_SLIDE_VOICE_SECONDS - voiced_by_slide[slide_index])
        _refresh_talk()
        return false
    if slide_index < REQUIRED_SLIDES - 1:
        slide_index += 1
        _refresh_talk()
        return true
    _stop_microphone()
    phase = "qa"
    talk_panel.visible = false
    question_panel.visible = true
    var question: Dictionary = briefs[active_id]["audience_question"]
    question_label.text = str(question["prompt"])
    quiz_choice = -1
    for i in range(quiz_options.size()):
        quiz_options[i].text = "%s. %s" % ["ABC".substr(i, 1), str(question["options"][i])]
        quiz_options[i].set_pressed_no_signal(false)
    return true

func _on_quiz_select(enabled: bool, index: int) -> void:
    if enabled and phase == "qa":
        quiz_choice = index

func select_qa_answer(index: int) -> bool:
    if phase != "qa" or index < 0 or index >= 3:
        return false
    quiz_choice = index
    for i in range(quiz_options.size()):
        quiz_options[i].set_pressed_no_signal(i == index)
    return true

func _on_submit() -> void:
    finish_presentation(false)

func finish_presentation(timed_out: bool) -> Dictionary:
    if phase != "qa" and phase != "talk":
        return {}
    if active_id.is_empty():
        return {}
    _stop_microphone()
    var enough_voice: bool = true
    for seconds in voiced_by_slide:
        if seconds < MIN_SLIDE_VOICE_SECONDS:
            enough_voice = false
    var q: Dictionary = briefs[active_id]["audience_question"]
    var quiz_correct: bool = quiz_choice == int(q["correct_index"])
    var fully_spoken: bool = enough_voice and verified_sample_frames >= 3 and not practice_mode
    var completed: bool = fully_spoken and not timed_out and phase == "qa" and quiz_choice >= 0
    var score: int = 0
    if not practice_mode:
        for seconds in voiced_by_slide:
            score += 20 if seconds >= MIN_SLIDE_VOICE_SECONDS else 0
        score += 20 if quiz_correct else 0
        score += 20 if completed and time_left > 0.0 else 0
    attempts[active_id] = mini(9999, int(attempts.get(active_id, 0)) + 1)
    if not practice_mode:
        best_scores[active_id] = maxi(int(best_scores.get(active_id, 0)), score)
    var first_pass: bool = completed and not passed_ids.has(active_id)
    if first_pass:
        passed_ids.append(active_id)
    var saved: bool = _save_progress()
    if not saved and first_pass:
        passed_ids.erase(active_id)
    var rewarded: bool = false
    if saved and completed:
        rewarded = coursework.claim_exam_reward_once(active_id, rewards_xp, rewards_credits)
    latest_result = {
        "id": active_id, "score": score, "passed": completed,
        "first_pass": first_pass and saved, "rewarded": rewarded,
        "question_correct": quiz_correct, "practice": practice_mode,
        "voice_seconds": voiced_by_slide.duplicate(), "saved": saved,
        "timed_out": timed_out
    }
    phase = "result"
    talk_panel.visible = false
    question_panel.visible = false
    library_panel.visible = false
    result_panel.visible = true
    _refresh_result()
    return latest_result

func _refresh_result() -> void:
    var result: Dictionary = latest_result
    var question: Dictionary = briefs[str(result["id"])]["audience_question"]
    var passed: bool = bool(result["passed"])
    result_heading.text = "PRESENTATION COMPLETE" if passed else "PRESENTATION PRACTICE / INCOMPLETE"
    result_details.text = "SCORE: %d / 100  |  %s\nSlide speaking activity: %.1f / %.1f / %.1f seconds\nQ&A: %s\n%s" % [
        int(result["score"]), "CERTIFIED" if passed else "NO CERTIFICATION",
        float(voiced_by_slide[0]), float(voiced_by_slide[1]), float(voiced_by_slide[2]),
        "CORRECT" if bool(result["question_correct"]) else "NOT CORRECT",
        "Reward: +%d XP and +%d credits (first completion only)." % [rewards_xp, rewards_credits]
        if bool(result["rewarded"]) else
        "No award. Practice mode, incomplete slides, or an already-completed topic."
    ]
    result_review.text = "AUDIENCE ANSWER: %s\n\n%s\n\nNOTE: The microphone checks sound activity, not the accuracy, language, or meaning of your presentation." % [
        str(question["options"][int(question["correct_index"])]),
        str(question["explanation"])
    ]

func _process(delta: float) -> void:
    if not is_open:
        return
    if phase == "talk" or phase == "qa":
        time_left = maxf(0.0, time_left - delta)
        if phase == "talk" and mic_running:
            mic_poll_clock += delta
            if mic_poll_clock >= AUDIO_POLL_SECONDS:
                mic_poll_clock = 0.0
                _poll_microphone()
                if verified_sample_frames == 0 and time_left < MAX_PRESENTATION_SECONDS - 6.0:
                    mic_notice = "No usable audio detected: check the OS microphone permission and input device."
        if time_left <= 0.0:
            finish_presentation(true)
            return
    ui_clock += delta
    if ui_clock >= 0.20:
        ui_clock = 0.0
        _refresh_talk()

func _input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key: InputEventKey = event as InputEventKey
    if not key.pressed or key.echo:
        return
    if key.keycode == KEY_F9 and not is_open:
        if open_library():
            get_viewport().set_input_as_handled()
    elif is_open:
        if key.keycode == KEY_ESCAPE or key.keycode == KEY_F9:
            if phase == "library":
                close_presentation()
            else:
                _return_to_library()
        # Consume all active presentation keystrokes to isolate existing
        # gameplay keys (O, J, P, Q, B, etc.).
        get_viewport().set_input_as_handled()
