extends CanvasLayer
class_name UTownEnglishExams
## Offline, entirely fictional English-only exam papers for 13 faculty tracks.
## Does not reuse real NUS module codes, credentials or official assessment data.

const DATA_PATH: String = "res://data/english_exam_papers.json"
const DEFAULT_SAVE_PATH: String = "user://nus3d_english_exams.cfg"
const DATA_SCHEMA: String = "nus3d-english-exams-v1"

@onready var coursework: UTownCoursework = $"../Coursework"
@onready var course_ui: UTownCourseworkUI = $"../CourseworkUI"
@onready var player: UTownPlayer = $"../Player"
@onready var life: UTownCampusLife = $"../CampusLife"
@onready var intro: UTownIntro = $"../Intro"
@onready var leisure_ui: UTownLeisureUI = $"../LeisureUI"
@onready var hud: CanvasLayer = $"../HUD"

var save_path: String = DEFAULT_SAVE_PATH
var papers: Dictionary = {}
var papers_by_faculty: Dictionary = {}
var paper_count: int = 0
var question_count: int = 0
var first_pass_xp: int = 90
var first_pass_credits: int = 25

var attempts: Dictionary = {}
var best_scores: Dictionary = {}
var last_scores: Dictionary = {}
var passed_ids: PackedStringArray = PackedStringArray()

var is_open: bool = false
var page: String = "library"
var active_paper_id: String = ""
var question_number: int = 0
var answers: Dictionary = {}
var remaining_seconds: float = 0.0
var latest_result: Dictionary = {}
var previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var previous_movement_lock: bool = false
var previous_coursework_modal: bool = false
var previous_second: int = -1

var shade: ColorRect
var paper_selector: OptionButton
var library_box: VBoxContainer
var exam_box: VBoxContainer
var result_box: VBoxContainer
var summary_label: Label
var library_footer: Label
var paper_title: Label
var question_counter: Label
var question_text: Label
var choices: Array[CheckBox] = []
var progress_bar: ProgressBar
var timer_label: Label
var previous_button: Button
var next_button: Button
var submit_button: Button
var result_title: Label
var result_summary: Label
var result_review: Label

func _ready() -> void:
    layer = 27
    _load_papers()
    _build_ui()
    load_progress()
    _restore_missing_awards()

func _load_papers() -> void:
    if not FileAccess.file_exists(DATA_PATH):
        push_error("Missing English exam paper catalog")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Exam paper catalog must be a JSON object")
        return
    var data: Dictionary = parsed
    if str(data.get("schema", "")) != DATA_SCHEMA or str(data.get("language", "")) != "en" or data.get("unofficial", false) != true:
        push_error("Exam catalog must declare English-only, fictional assessment data")
        return
    var scoring: Dictionary = data.get("scoring", {})
    first_pass_xp = clampi(int(scoring.get("first_pass_xp", 90)), 0, 300)
    first_pass_credits = clampi(int(scoring.get("first_pass_credits", 25)), 0, 100)
    for item in data.get("papers", []):
        if typeof(item) != TYPE_DICTIONARY:
            continue
        var paper: Dictionary = item
        var identifier: String = str(paper.get("id", ""))
        var faculty_id: String = str(paper.get("faculty_id", ""))
        var questions: Array = paper.get("questions", [])
        if not identifier.is_valid_identifier() or papers.has(identifier):
            continue
        if not coursework.faculty_by_id.has(faculty_id) or questions.size() != 5:
            continue
        if str(paper.get("major", "")).is_empty():
            continue
        var valid: bool = true
        var unique_questions: Dictionary = {}
        for question in questions:
            if typeof(question) != TYPE_DICTIONARY:
                valid = false
                break
            var question_id: String = str(question.get("id", ""))
            var options: Array = question.get("options", [])
            var answer: int = int(question.get("correct_index", -1))
            if not question_id.is_valid_identifier() or unique_questions.has(question_id) or options.size() != 4 or answer < 0 or answer >= 4:
                valid = false
                break
            unique_questions[question_id] = true
        if not valid:
            continue
        papers[identifier] = paper
        if not papers_by_faculty.has(faculty_id):
            papers_by_faculty[faculty_id] = []
        papers_by_faculty[faculty_id].append(paper)
        paper_count += 1
        question_count += questions.size()

func get_papers_for_faculty(faculty_id: String) -> Array:
    return papers_by_faculty.get(faculty_id, [])

func paper_by_id(paper_id: String) -> Dictionary:
    return papers.get(paper_id, {})

func score_paper(paper_id: String, submitted: Dictionary) -> Dictionary:
    var paper: Dictionary = paper_by_id(paper_id)
    if paper.is_empty():
        return {}
    var questions: Array = paper["questions"]
    var correct: int = 0
    var invalid: int = 0
    for question in questions:
        var question_id: String = str(question["id"])
        var answer: int = int(submitted.get(question_id, -1))
        if answer < 0 or answer > 3:
            invalid += 1
        elif answer == int(question["correct_index"]):
            correct += 1
    var score: int = int(round(float(correct) * 100.0 / float(questions.size())))
    var passed: bool = score >= int(paper.get("pass_mark", 60))
    var grade: String = "A+" if score == 100 else "A" if score >= 80 else "B" if passed else "F"
    return {
        "paper_id": paper_id, "score": score, "correct": correct,
        "total": questions.size(), "unanswered": invalid,
        "passed": passed, "grade": grade
    }

func _restore_missing_awards() -> void:
    # Crash-safe bridge: if the exam record is saved before coursework is updated,
    # a later scene load can grant the one-time award without granting it twice.
    for id in passed_ids:
        if papers.has(id):
            coursework.claim_exam_reward_once(id, first_pass_xp, first_pass_credits)

func load_progress() -> void:
    attempts.clear()
    best_scores.clear()
    last_scores.clear()
    passed_ids.clear()
    var storage := ConfigFile.new()
    if storage.load(save_path) != OK:
        return
    var raw_attempts: Variant = storage.get_value("exams", "attempts", {})
    var raw_best: Variant = storage.get_value("exams", "best_scores", {})
    var raw_last: Variant = storage.get_value("exams", "last_scores", {})
    if typeof(raw_attempts) == TYPE_DICTIONARY:
        for id in raw_attempts:
            if papers.has(str(id)):
                attempts[str(id)] = clampi(int(raw_attempts[id]), 0, 9999)
    if typeof(raw_best) == TYPE_DICTIONARY:
        for id in raw_best:
            if papers.has(str(id)):
                best_scores[str(id)] = clampi(int(raw_best[id]), 0, 100)
    if typeof(raw_last) == TYPE_DICTIONARY:
        for id in raw_last:
            if papers.has(str(id)):
                last_scores[str(id)] = clampi(int(raw_last[id]), 0, 100)
    var raw_passed: Variant = storage.get_value("exams", "passed_ids", PackedStringArray())
    if typeof(raw_passed) == TYPE_ARRAY or typeof(raw_passed) == TYPE_PACKED_STRING_ARRAY:
        for id in raw_passed:
            var key: String = str(id)
            if papers.has(key) and not passed_ids.has(key):
                passed_ids.append(key)

func _save_progress() -> bool:
    var storage := ConfigFile.new()
    storage.set_value("exams", "schema_version", 1)
    storage.set_value("exams", "attempts", attempts)
    storage.set_value("exams", "best_scores", best_scores)
    storage.set_value("exams", "last_scores", last_scores)
    storage.set_value("exams", "passed_ids", passed_ids)
    var error: Error = storage.save(save_path)
    if error != OK:
        push_warning("Could not write the standalone English exam record")
    return error == OK

func _font_label(text_value: String, points: int, color: String) -> Label:
    var label := Label.new()
    label.text = text_value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", points)
    label.add_theme_color_override("font_color", Color.html(color))
    return label

func _build_ui() -> void:
    shade = ColorRect.new()
    shade.name = "EnglishExamBackdrop"
    shade.color = Color(0.025, 0.037, 0.057, 0.95)
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    shade.visible = false
    add_child(shade)
    var middle := CenterContainer.new()
    middle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shade.add_child(middle)
    var sheet := PanelContainer.new()
    sheet.name = "PrintedExamPaper"
    sheet.custom_minimum_size = Vector2(880.0, 625.0)
    sheet.mouse_filter = Control.MOUSE_FILTER_STOP
    var paper_style := StyleBoxFlat.new()
    paper_style.bg_color = Color.html("#f8f6ef")
    paper_style.set_corner_radius_all(8)
    paper_style.border_color = Color.html("#c3bdab")
    paper_style.set_border_width_all(2)
    paper_style.content_margin_left = 30
    paper_style.content_margin_right = 30
    paper_style.content_margin_top = 22
    paper_style.content_margin_bottom = 22
    sheet.add_theme_stylebox_override("panel", paper_style)
    middle.add_child(sheet)
    var frame := VBoxContainer.new()
    frame.add_theme_constant_override("separation", 13)
    sheet.add_child(frame)
    var eyebrow := _font_label("UTOWN EXAMINATION OFFICE  /  FICTIONAL GAME ASSESSMENT", 12, "#647180")
    frame.add_child(eyebrow)
    var separator := HSeparator.new()
    frame.add_child(separator)

    library_box = VBoxContainer.new()
    library_box.name = "MajorPaperLibrary"
    library_box.add_theme_constant_override("separation", 15)
    frame.add_child(library_box)
    library_box.add_child(_font_label("ENGLISH MAJOR EXAM PAPERS", 28, "#152b39"))
    library_box.add_child(_font_label("Choose a major within your selected faculty. Five questions, three minutes, 60% to pass. Retakes are allowed; each major pays its XP bonus only once.", 16, "#495862"))
    paper_selector = OptionButton.new()
    paper_selector.name = "EnglishMajorSelector"
    paper_selector.custom_minimum_size = Vector2(750.0, 44.0)
    paper_selector.item_selected.connect(_on_paper_choice)
    library_box.add_child(paper_selector)
    summary_label = _font_label("", 17, "#25394a")
    summary_label.custom_minimum_size.y = 160
    library_box.add_child(summary_label)
    library_footer = _font_label("All questions and answers are in English. These are original game papers, not official NUS assessments.", 14, "#6c747d")
    library_box.add_child(library_footer)
    var library_buttons := HBoxContainer.new()
    library_buttons.add_theme_constant_override("separation", 16)
    library_box.add_child(library_buttons)
    var begin_button := Button.new()
    begin_button.text = "START EXAM"
    begin_button.custom_minimum_size = Vector2(260, 44)
    begin_button.pressed.connect(_begin_selected_exam)
    library_buttons.add_child(begin_button)
    var leave_library := Button.new()
    leave_library.text = "RETURN TO CAMPUS"
    leave_library.custom_minimum_size = Vector2(200, 44)
    leave_library.pressed.connect(close_exam)
    library_buttons.add_child(leave_library)

    exam_box = VBoxContainer.new()
    exam_box.name = "ExamInProgress"
    exam_box.visible = false
    exam_box.add_theme_constant_override("separation", 10)
    frame.add_child(exam_box)
    var heading := HBoxContainer.new()
    exam_box.add_child(heading)
    paper_title = _font_label("", 21, "#162b36")
    paper_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_child(paper_title)
    timer_label = _font_label("", 19, "#9f3c2a")
    heading.add_child(timer_label)
    question_counter = _font_label("", 15, "#4d5d66")
    exam_box.add_child(question_counter)
    progress_bar = ProgressBar.new()
    progress_bar.min_value = 0
    progress_bar.max_value = 5
    progress_bar.show_percentage = false
    progress_bar.custom_minimum_size.y = 8
    exam_box.add_child(progress_bar)
    question_text = _font_label("", 20, "#102733")
    question_text.custom_minimum_size.y = 96
    exam_box.add_child(question_text)
    var options := VBoxContainer.new()
    options.add_theme_constant_override("separation", 8)
    exam_box.add_child(options)
    var group := ButtonGroup.new()
    for index in range(4):
        var choice := CheckBox.new()
        choice.name = "Answer_%d" % index
        choice.button_group = group
        choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        choice.custom_minimum_size = Vector2(770, 54)
        choice.add_theme_font_size_override("font_size", 16)
        choice.add_theme_color_override("font_color", Color.html("#253c44"))
        choice.toggled.connect(_on_answer_changed.bind(index))
        options.add_child(choice)
        choices.append(choice)
    var nav := HBoxContainer.new()
    nav.add_theme_constant_override("separation", 14)
    exam_box.add_child(nav)
    previous_button = Button.new()
    previous_button.text = "PREVIOUS"
    previous_button.custom_minimum_size = Vector2(155, 42)
    previous_button.pressed.connect(_previous_question)
    nav.add_child(previous_button)
    next_button = Button.new()
    next_button.text = "NEXT QUESTION"
    next_button.custom_minimum_size = Vector2(180, 42)
    next_button.pressed.connect(_next_question)
    nav.add_child(next_button)
    submit_button = Button.new()
    submit_button.text = "SUBMIT PAPER"
    submit_button.custom_minimum_size = Vector2(180, 42)
    submit_button.pressed.connect(_submit_clicked)
    nav.add_child(submit_button)
    var abandon := Button.new()
    abandon.text = "LEAVE (DISCARD)"
    abandon.custom_minimum_size = Vector2(155, 42)
    abandon.pressed.connect(_return_to_library)
    nav.add_child(abandon)

    result_box = VBoxContainer.new()
    result_box.name = "ExamScoreAndReview"
    result_box.visible = false
    result_box.add_theme_constant_override("separation", 12)
    frame.add_child(result_box)
    result_title = _font_label("", 26, "#1c3545")
    result_box.add_child(result_title)
    result_summary = _font_label("", 16, "#425662")
    result_box.add_child(result_summary)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(790, 400)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    result_box.add_child(scroll)
    result_review = _font_label("", 15, "#213742")
    result_review.custom_minimum_size.x = 765.0
    scroll.add_child(result_review)
    var close_buttons := HBoxContainer.new()
    close_buttons.add_theme_constant_override("separation", 15)
    result_box.add_child(close_buttons)
    var more := Button.new()
    more.text = "OTHER MAJORS / RETAKE"
    more.custom_minimum_size = Vector2(255, 43)
    more.pressed.connect(_return_to_library)
    close_buttons.add_child(more)
    var done := Button.new()
    done.text = "RETURN TO CAMPUS"
    done.custom_minimum_size = Vector2(205, 43)
    done.pressed.connect(close_exam)
    close_buttons.add_child(done)

func _can_open() -> bool:
    var voice: Node = get_parent().get_node_or_null("VoicePresentation")
    if voice != null and bool(voice.get("is_open")):
        return false
    return not is_open and not coursework.current_faculty_id.is_empty() and hud.visible \
        and not intro.playing and not course_ui.intro_blocked and not course_ui.modal_visible \
        and not leisure_ui.is_open and not life.on_shuttle and not player.bicycle_mode \
        and not player.movement_locked

func open_library() -> bool:
    if not _can_open():
        return false
    previous_mouse_mode = Input.mouse_mode
    previous_movement_lock = player.movement_locked
    previous_coursework_modal = coursework.modal_open
    is_open = true
    coursework.modal_open = true
    player.movement_locked = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    shade.visible = true
    _return_to_library()
    return true

func close_exam() -> void:
    if not is_open:
        return
    is_open = false
    shade.visible = false
    active_paper_id = ""
    answers.clear()
    coursework.modal_open = previous_coursework_modal
    player.movement_locked = previous_movement_lock or life.on_shuttle
    Input.mouse_mode = previous_mouse_mode

func _return_to_library() -> void:
    page = "library"
    active_paper_id = ""
    answers.clear()
    library_box.visible = true
    exam_box.visible = false
    result_box.visible = false
    _refresh_library()

func _refresh_library() -> void:
    paper_selector.clear()
    for paper in get_papers_for_faculty(coursework.current_faculty_id):
        var index: int = paper_selector.item_count
        paper_selector.add_item(str(paper["major"]))
        paper_selector.set_item_metadata(index, str(paper["id"]))
    if paper_selector.item_count > 0:
        paper_selector.select(0)
    _on_paper_choice(0)

func _on_paper_choice(index: int) -> void:
    if index < 0 or index >= paper_selector.item_count:
        summary_label.text = "No exam papers are available for this faculty."
        return
    var paper_id: String = str(paper_selector.get_item_metadata(index))
    var paper: Dictionary = papers[paper_id]
    var best: String = "%d%%" % int(best_scores[paper_id]) if best_scores.has(paper_id) else "Not attempted"
    var certified: String = "PASSED" if passed_ids.has(paper_id) else "NOT YET PASSED"
    summary_label.text = "FACULTY: %s\nMAJOR: %s\nPAPER: %s\n\nBEST SCORE: %s   |   ATTEMPTS: %d\nCERTIFICATION: %s\n\nFirst passing attempt: +%d XP and +%d coursework credits." % [
        str(coursework.faculty_by_id[coursework.current_faculty_id]["name"]),
        str(paper["major"]), str(paper["title"]),
        best, int(attempts.get(paper_id, 0)), certified,
        first_pass_xp, first_pass_credits
    ]

func _begin_selected_exam() -> void:
    if paper_selector.selected < 0:
        return
    begin_exam(str(paper_selector.get_selected_metadata()))

func begin_exam(paper_id: String) -> bool:
    if not is_open or not papers.has(paper_id):
        return false
    var paper: Dictionary = papers[paper_id]
    if str(paper["faculty_id"]) != coursework.current_faculty_id:
        return false
    page = "question"
    active_paper_id = paper_id
    question_number = 0
    answers.clear()
    latest_result.clear()
    remaining_seconds = float(paper.get("duration_seconds", 180))
    previous_second = -1
    library_box.visible = false
    exam_box.visible = true
    result_box.visible = false
    _refresh_question()
    _refresh_timer()
    return true

func set_answer(question_id: String, choice_index: int) -> bool:
    if page != "question" or active_paper_id.is_empty() or choice_index < 0 or choice_index > 3:
        return false
    var questions: Array = papers[active_paper_id]["questions"]
    for question in questions:
        if str(question["id"]) == question_id:
            answers[question_id] = choice_index
            _refresh_question_counter()
            return true
    return false

func _on_answer_changed(pressed: bool, index: int) -> void:
    if not pressed or page != "question":
        return
    var question: Dictionary = papers[active_paper_id]["questions"][question_number]
    set_answer(str(question["id"]), index)

func _refresh_timer() -> void:
    var whole_seconds: int = ceili(remaining_seconds)
    if whole_seconds == previous_second:
        return
    previous_second = whole_seconds
    timer_label.text = "%02d:%02d LEFT" % [whole_seconds / 60, whole_seconds % 60]

func _refresh_question_counter() -> void:
    if page != "question" or active_paper_id.is_empty():
        return
    var total: int = papers[active_paper_id]["questions"].size()
    question_counter.text = "QUESTION %d OF %d   |   ANSWERED %d / %d   |   PASS: 60%%" % [
        question_number + 1, total, answers.size(), total
    ]
    progress_bar.max_value = total
    progress_bar.value = answers.size()

func _refresh_question() -> void:
    if page != "question":
        return
    var paper: Dictionary = papers[active_paper_id]
    var question: Dictionary = paper["questions"][question_number]
    paper_title.text = "%s" % str(paper["title"])
    question_text.text = str(question["prompt"])
    _refresh_question_counter()
    for index in range(choices.size()):
        var choice: CheckBox = choices[index]
        choice.text = "%s.  %s" % ["ABCD".substr(index, 1), str(question["options"][index])]
        choice.set_pressed_no_signal(int(answers.get(str(question["id"]), -1)) == index)
    previous_button.disabled = question_number == 0
    next_button.disabled = question_number >= int(paper["questions"].size()) - 1

func _next_question() -> void:
    if page == "question" and question_number < papers[active_paper_id]["questions"].size() - 1:
        question_number += 1
        _refresh_question()

func _previous_question() -> void:
    if page == "question" and question_number > 0:
        question_number -= 1
        _refresh_question()

func _submit_clicked() -> void:
    submit_exam()

func submit_exam() -> Dictionary:
    if page != "question" or active_paper_id.is_empty():
        return {}
    var id: String = active_paper_id
    var result: Dictionary = score_paper(id, answers)
    if result.is_empty():
        return {}
    var paper: Dictionary = papers[id]
    attempts[id] = mini(9999, int(attempts.get(id, 0)) + 1)
    last_scores[id] = int(result["score"])
    best_scores[id] = maxi(int(best_scores.get(id, 0)), int(result["score"]))
    var first_pass: bool = bool(result["passed"]) and not passed_ids.has(id)
    if first_pass:
        passed_ids.append(id)
    var saved: bool = _save_progress()
    var rewarded: bool = false
    if saved and bool(result["passed"]):
        rewarded = coursework.claim_exam_reward_once(id, first_pass_xp, first_pass_credits)
    result["rewarded"] = rewarded
    result["first_pass"] = first_pass
    result["record_saved"] = saved
    latest_result = result
    page = "result"
    library_box.visible = false
    exam_box.visible = false
    result_box.visible = true
    _refresh_result(paper, result)
    return result

func _refresh_result(paper: Dictionary, result: Dictionary) -> void:
    var grade: String = str(result["grade"])
    var passed: bool = bool(result["passed"])
    result_title.text = "GRADE %s  |  %d%%  |  %s" % [
        grade, int(result["score"]), "PASSED" if passed else "RETAKE ADVISED"
    ]
    result_summary.text = "%s\n%d correct out of %d questions  |  %d unanswered\n%s" % [
        str(paper["major"]), int(result["correct"]), int(result["total"]), int(result["unanswered"]),
        "First-pass reward: +%d XP, +%d credits." % [first_pass_xp, first_pass_credits] if bool(result["rewarded"])
        else "No additional XP this attempt. Passing rewards are available once per major."
    ]
    var lines := PackedStringArray()
    lines.append("ANSWER REVIEW   /   MODEL ANSWERS")
    for index in range(paper["questions"].size()):
        var q: Dictionary = paper["questions"][index]
        var id: String = str(q["id"])
        var choice: int = int(answers.get(id, -1))
        var correct: int = int(q["correct_index"])
        var mark: String = "CORRECT" if choice == correct else "NOT CORRECT"
        lines.append("\n%d. %s" % [index + 1, str(q["prompt"])])
        lines.append("YOUR ANSWER: " + (str(q["options"][choice]) if choice >= 0 and choice < 4 else "No answer"))
        lines.append("EXPECTED: " + str(q["options"][correct]))
        lines.append("RESULT: %s   |   %s" % [mark, str(q["explanation"])])
    result_review.text = "\n".join(lines)

func _process(delta: float) -> void:
    if is_open and page == "question":
        remaining_seconds = maxf(0.0, remaining_seconds - delta)
        _refresh_timer()
        if remaining_seconds <= 0.0:
            submit_exam()

func _input(event: InputEvent) -> void:
    var voice: Node = get_parent().get_node_or_null("VoicePresentation")
    if voice != null and bool(voice.get("is_open")):
        return
    if not (event is InputEventKey):
        return
    var key: InputEventKey = event as InputEventKey
    if not key.pressed or key.echo:
        return
    if key.keycode == KEY_F8 and not is_open:
        if open_library():
            get_viewport().set_input_as_handled()
    elif is_open:
        if key.keycode == KEY_ESCAPE:
            if page == "library":
                close_exam()
            else:
                _return_to_library()
        elif key.keycode == KEY_F8:
            close_exam()
        # Prevent gameplay keys (including O/J/P/Q) from reaching physics
        # and other _unhandled_input listeners during an exam.
        get_viewport().set_input_as_handled()
