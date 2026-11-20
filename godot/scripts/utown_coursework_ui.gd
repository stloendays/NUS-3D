extends CanvasLayer
class_name UTownCourseworkUI
const UI_FONT_KIT = preload("res://scripts/utown_ui_font.gd")
## Game-only faculty picker, quest journal and compact coursework HUD.
## No login or student details: the choice is stored only on this device.

@onready var coursework: UTownCoursework = $"../Coursework"
@onready var player: UTownPlayer = $"../Player"
@onready var life: UTownCampusLife = $"../CampusLife"
@onready var language: NUS3DGameLanguage = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage

var hud_enabled: bool = true
var status_card: PanelContainer
var status_title: Label
var status_body: Label
var status_feedback: Label
var shade: ColorRect
var modal_panel: PanelContainer
var selector_box: VBoxContainer
var journal_box: VBoxContainer
var faculty_picker: OptionButton
var faculty_description: Label
var journal_text: Label
var journal_button: Button
var modal_visible: bool = false
var selection_visible: bool = false
var intro_blocked: bool = false

func _ready() -> void:
    _build_status()
    _build_modal()
    get_viewport().size_changed.connect(_update_modal_layout)
    _update_modal_layout()
    var font_theme: Theme = UI_FONT_KIT.make_theme()
    status_card.theme = font_theme
    shade.theme = font_theme
    if language != null:
        language.language_changed.connect(_apply_language)
        _apply_language(language.locale)
    if coursework.current_faculty_id.is_empty():
        show_selector()


func _t(zh: String, en: String) -> String:
    return language.choose(zh, en) if language != null else en


func _dual_label(zh: String, en: String, size: int, color: Color) -> Label:
    var label := _label(_t(zh, en), size, color)
    label.set_meta("locale_zh", zh)
    label.set_meta("locale_en", en)
    return label


func _dual_button(button: Button, zh: String, en: String) -> void:
    button.set_meta("locale_zh", zh)
    button.set_meta("locale_en", en)
    button.text = _t(zh, en)
    NUS3DUISkin.button(button)


func _apply_language(_code: String) -> void:
    _refresh_dual_nodes(self)
    for i in range(coursework.faculty_options.size()):
        var item: Dictionary = coursework.faculty_options[i]
        var name: String = str(item.get("zh", "")) if language != null and language.is_chinese()             else str(item.get("name", ""))
        faculty_picker.set_item_text(i, "%s | %s" % [str(item.get("abbr", "")), name])
    if faculty_picker.selected >= 0:
        _on_faculty_highlighted(faculty_picker.selected)
    _refresh_journal()


func _refresh_dual_nodes(node: Node) -> void:
    if node.has_meta("locale_zh") and node.has_meta("locale_en"):
        var translated: String = _t(str(node.get_meta("locale_zh")), str(node.get_meta("locale_en")))
        if node is Label:
            (node as Label).text = translated
        elif node is Button:
            (node as Button).text = translated
    for child in node.get_children():
        _refresh_dual_nodes(child)


func _style_panel(panel: PanelContainer, _legacy_background: Color) -> void:
    panel.add_theme_stylebox_override("panel",
        NUS3DUISkin.glass(Color("#E8EEEC"), 18, 14, true))

func _label(text_value: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text_value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color",
        NUS3DUISkin.TEXT if color.get_luminance() > 0.58 else color)
    return label

func _build_status() -> void:
    status_card = PanelContainer.new()
    status_card.name = "CourseworkStatus"
    status_card.anchor_left = 1.0
    status_card.anchor_right = 1.0
    status_card.offset_left = -425.0
    status_card.offset_right = -18.0
    status_card.offset_top = 408.0
    status_card.offset_bottom = 515.0
    status_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _style_panel(status_card, Color(0.095, 0.14, 0.19, 0.91))
    add_child(status_card)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 4)
    status_card.add_child(column)
    status_title = _dual_label("课程任务 · 截止时间危机", "COURSEWORK · DEADLINE APOCALYPSE", 14, Color.html("#f3c372"))
    column.add_child(status_title)
    status_body = _dual_label("选择学院 [Shift+P] · 手册 [P]",
        "Choose faculty [Shift+P] · Journal [P]", 12, Color.html("#edf2ed"))
    column.add_child(status_body)
    status_feedback = _label("", 12, Color.html("#a9e4b7"))
    column.add_child(status_feedback)

func _update_modal_layout() -> void:
    if modal_panel == null:
        return
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    modal_panel.custom_minimum_size = Vector2(
        minf(570.0, maxf(280.0, viewport_size.x - 32.0)),
        minf(350.0, maxf(240.0, viewport_size.y - 32.0)))


func _build_modal() -> void:
    shade = ColorRect.new()
    shade.name = "CourseworkModalShade"
    shade.color = NUS3DUISkin.BACKDROP
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    shade.visible = false
    add_child(shade)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shade.add_child(center)
    modal_panel = PanelContainer.new()
    modal_panel.custom_minimum_size = Vector2(570, 350)
    modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _style_panel(modal_panel, Color.html("#172731"))
    center.add_child(modal_panel)
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 13)
    modal_panel.add_child(body)

    selector_box = VBoxContainer.new()
    selector_box.name = "FacultySelector"
    selector_box.add_theme_constant_override("separation", 12)
    body.add_child(selector_box)
    selector_box.add_child(_dual_label("NUS-3D · 选择学院", "NUS-3D · CHOOSE FACULTY", 25, Color.html("#f5c46a")))
    selector_box.add_child(_dual_label("你的学院，你的截止时间危机。", "Your faculty. Your deadline crisis.", 18, Color.html("#e8eee8")))
    selector_box.add_child(_dual_label("游戏虚构任务，不代表真实课程、成绩或截止日期。", "Fictional game quests, not real courses, grades or deadlines.", 12, Color.html("#aabdc4")))
    faculty_picker = OptionButton.new()
    faculty_picker.name = "FacultyPicker"
    faculty_picker.custom_minimum_size = Vector2(520, 42)
    selector_box.add_child(faculty_picker)
    NUS3DUISkin.button(faculty_picker)
    for i in range(coursework.faculty_options.size()):
        var item: Dictionary = coursework.faculty_options[i]
        faculty_picker.add_item("%s | %s" % [item["abbr"],
            str(item["zh"]) if language != null and language.is_chinese() else str(item["name"])])
        faculty_picker.set_item_metadata(i, str(item["id"]))
    faculty_picker.item_selected.connect(_on_faculty_highlighted)
    faculty_description = _label("", 16, Color.html("#d7dfda"))
    faculty_description.custom_minimum_size.y = 105
    selector_box.add_child(faculty_description)
    var start := Button.new()
    start.name = "ConfirmFaculty"
    _dual_button(start, "进入学院 · 开始挑战", "Enter Faculty · Start Adventure")
    start.custom_minimum_size.y = 43.0
    start.pressed.connect(_confirm_faculty)
    selector_box.add_child(start)
    selector_box.add_child(_dual_label("可随时切换学院，各学院进度分别保存，其他奖励不会重置。", "Switch faculties later; each questline is saved independently.", 12, Color.html("#aebebc")))

    journal_box = VBoxContainer.new()
    journal_box.name = "CourseworkJournal"
    journal_box.add_theme_constant_override("separation", 12)
    body.add_child(journal_box)
    journal_box.visible = false
    journal_box.add_child(_dual_label("课程任务手册", "COURSEWORK JOURNAL", 22, Color.html("#f5c46a")))
    journal_text = _label("", 15, Color.html("#e7ede9"))
    journal_text.custom_minimum_size = Vector2(520, 210)
    journal_box.add_child(journal_text)
    var exam_button := Button.new()
    exam_button.name = "OpenEnglishMajorExams"
    _dual_button(exam_button, "专业模拟考试 [F8]", "Major Practice Exams [F8]")
    exam_button.custom_minimum_size.y = 43.0
    exam_button.pressed.connect(_open_major_exams)
    journal_box.add_child(exam_button)
    var presentation_button := Button.new()
    presentation_button.name = "OpenEnglishPresentations"
    _dual_button(presentation_button, "英语口头报告 [F9]", "ENGLISH ORAL PRESENTATION [F9]")
    presentation_button.custom_minimum_size.y = 43.0
    presentation_button.pressed.connect(_open_oral_presentations)
    journal_box.add_child(presentation_button)
    var switch_button := Button.new()
    _dual_button(switch_button, "切换学院", "Change Faculty")
    switch_button.custom_minimum_size.y = 37.0
    switch_button.pressed.connect(show_selector)
    journal_box.add_child(switch_button)
    journal_button = Button.new()
    _dual_button(journal_button, "返回游戏", "Resume Game")
    journal_button.custom_minimum_size.y = 37.0
    journal_button.pressed.connect(hide_modal)
    journal_box.add_child(journal_button)

func _on_faculty_highlighted(index: int) -> void:
    if index < 0 or index >= coursework.faculty_options.size():
        return
    var faculty: Dictionary = coursework.faculty_options[index]
    var quests: Array = faculty["quests"]
    faculty_description.text = _t(
        "学院剧情：%s\n本学院有 3 个原创课程任务。\n第一关：%s\n收集通知、完成活动、寻找队友并提交。",
        "Faculty story: %s\nThis faculty has three original coursework quests.\nFirst quest: %s\nCollect the brief, do an activity, find a teammate and submit."
    ) % [coursework.faculty_flavor(faculty), coursework.quest_title(quests[0])]

func _set_game_input_locked(locked: bool) -> void:
    coursework.modal_open = locked
    player.movement_locked = locked or life.on_shuttle
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if locked else Input.MOUSE_MODE_CAPTURED

func begin_intro() -> void:
    # The cinematic owns the screen before the first-run selector becomes
    # visible. This keeps the existing picker and its save logic intact.
    intro_blocked = true
    shade.visible = false
    status_card.visible = false
    _set_game_input_locked(true)

func end_intro() -> void:
    intro_blocked = false
    if coursework.current_faculty_id.is_empty():
        show_selector()
    elif modal_visible:
        shade.visible = true
        _set_game_input_locked(true)
    else:
        _set_game_input_locked(false)

func show_selector() -> void:
    modal_visible = true
    selection_visible = true
    shade.visible = true
    selector_box.visible = true
    journal_box.visible = false
    var chosen: int = 0
    for i in range(coursework.faculty_options.size()):
        if str(coursework.faculty_options[i]["id"]) == coursework.current_faculty_id:
            chosen = i
            break
    faculty_picker.select(chosen)
    _on_faculty_highlighted(chosen)
    _set_game_input_locked(true)

func _confirm_faculty() -> void:
    var index: int = faculty_picker.selected
    if index < 0 or index >= coursework.faculty_options.size():
        return
    var faculty_id: String = str(faculty_picker.get_item_metadata(index))
    if coursework.select_faculty(faculty_id):
        hide_modal()

func _open_major_exams() -> void:
    if coursework.current_faculty_id.is_empty():
        return
    hide_modal()
    var exams: Node = get_parent().get_node_or_null("EnglishExams")
    if exams != null:
        exams.call("open_library")


func _open_oral_presentations() -> void:
    if coursework.current_faculty_id.is_empty():
        return
    hide_modal()
    var voice: Node = get_parent().get_node_or_null("VoicePresentation")
    if voice != null:
        voice.call("open_library")

func show_journal() -> void:
    if coursework.current_faculty_id.is_empty():
        show_selector()
        return
    modal_visible = true
    selection_visible = false
    shade.visible = true
    selector_box.visible = false
    journal_box.visible = true
    _refresh_journal()
    _set_game_input_locked(true)

func hide_modal() -> void:
    if coursework.current_faculty_id.is_empty():
        return  # First-run choice is required before movement.
    modal_visible = false
    selection_visible = false
    shade.visible = false
    selector_box.visible = false
    journal_box.visible = false
    _set_game_input_locked(false)

func _refresh_journal() -> void:
    if journal_text == null:
        return
    var quest: Dictionary = coursework.current_quest()
    var line: String = _t(
        "学院：%s\n等级 %d | 经验 %d XP | 积分 %d\n本学院完成：%d / 3\n\n",
        "Faculty: %s\nLevel %d | Experience %d XP | Credits %d\nCompleted here: %d / 3\n\n"
    ) % [coursework.faculty_name(), coursework.level(), coursework.total_xp,
        coursework.credits, coursework.active_quest_index]
    if quest.is_empty():
        line += _t("本学院全部课程任务已完成。可以继续探索或切换学院。\n",
            "All faculty coursework completed. Explore the campus or change faculty.\n")
    else:
        line += _t("任务 %d/3：%s\n%s\n\n截止时间：%s\n当前目标：%s\n",
            "Quest %d/3: %s\n%s\n\nDeadline: %s\nCurrent objective: %s\n") % [
            coursework.active_quest_index + 1, coursework.quest_title(quest),
            coursework.quest_story(quest), coursework.format_ddl(), coursework.objective_description()]
    if not coursework.last_grade.is_empty():
        line += _t("\n最近评分：", "\nLatest grade: ") + coursework.last_grade
    line += _t("\n\n[P] 返回  [Shift+P] 切换学院 | 进度自动保存在本机",
        "\n\n[P] Back  [Shift+P] Change faculty | Saved locally")
    journal_text.text = line

func set_hud_enabled(enabled: bool) -> void:
    hud_enabled = enabled

func _process(_delta: float) -> void:
    if intro_blocked:
        shade.visible = false
        status_card.visible = false
        return
    status_card.visible = hud_enabled and not modal_visible
    status_body.text = coursework.status_text()
    status_feedback.text = coursework.feedback if coursework.feedback_left > 0.0 else ""
    if modal_visible and not selection_visible:
        _refresh_journal()

func _input(event: InputEvent) -> void:
    var coins: Node = get_parent().get_node_or_null("Coins")
    if coins != null and bool(coins.get("shop_open")):
        return
    var voice: Node = get_parent().get_node_or_null("VoicePresentation")
    if voice != null and voice.get("is_open") == true:
        return
    var exams: Node = get_parent().get_node_or_null("EnglishExams")
    if exams != null and bool(exams.get("is_open")):
        return
    if intro_blocked:
        return
    var leisure_ui: Node = get_parent().get_node_or_null("LeisureUI")
    if leisure_ui != null and bool(leisure_ui.get("is_open")):
        return
    if not (event is InputEventKey):
        return
    var key: InputEventKey = event as InputEventKey
    if not key.pressed or key.echo:
        return
    if modal_visible:
        if key.keycode == KEY_ESCAPE:
            hide_modal()
            get_viewport().set_input_as_handled()
        elif key.keycode == KEY_P:
            if key.shift_pressed:
                show_selector()
            else:
                hide_modal()
            get_viewport().set_input_as_handled()
        elif key.keycode in [
            KEY_W, KEY_A, KEY_S, KEY_D, KEY_K, KEY_Q, KEY_B, KEY_X, KEY_I,
            KEY_F, KEY_L, KEY_Y, KEY_T, KEY_C, KEY_V, KEY_G, KEY_E, KEY_R,
            KEY_M, KEY_SPACE, KEY_SHIFT, KEY_J, KEY_O, KEY_N, KEY_Z, KEY_U,
            KEY_H, KEY_TAB, KEY_1, KEY_2, KEY_3
        ]:
            get_viewport().set_input_as_handled()
    elif key.keycode == KEY_P:
        if key.shift_pressed:
            show_selector()
        else:
            show_journal()
        get_viewport().set_input_as_handled()
