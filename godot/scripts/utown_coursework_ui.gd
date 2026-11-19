extends CanvasLayer
class_name UTownCourseworkUI
const UI_FONT_KIT = preload("res://scripts/utown_ui_font.gd")
## Game-only faculty picker, quest journal and compact coursework HUD.
## No login or student details: the choice is stored only on this device.

@onready var coursework: UTownCoursework = $"../Coursework"
@onready var player: UTownPlayer = $"../Player"
@onready var life: UTownCampusLife = $"../CampusLife"

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
    var font_theme: Theme = UI_FONT_KIT.make_theme()
    status_card.theme = font_theme
    shade.theme = font_theme
    if coursework.current_faculty_id.is_empty():
        show_selector()

func _style_panel(panel: PanelContainer, background: Color) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.set_corner_radius_all(12)
    style.content_margin_left = 15.0
    style.content_margin_right = 15.0
    style.content_margin_top = 11.0
    style.content_margin_bottom = 11.0
    panel.add_theme_stylebox_override("panel", style)

func _label(text_value: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text_value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
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
    status_title = _label("COURSEWORK // THE DDL APOCALYPSE", 14, Color.html("#f3c372"))
    column.add_child(status_title)
    status_body = _label("Choose your faculty. [O] Faculty  [J] Coursework", 12, Color.html("#edf2ed"))
    column.add_child(status_body)
    status_feedback = _label("", 12, Color.html("#a9e4b7"))
    column.add_child(status_feedback)

func _build_modal() -> void:
    shade = ColorRect.new()
    shade.name = "CourseworkModalShade"
    shade.color = Color(0.025, 0.055, 0.075, 0.83)
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
    selector_box.add_child(_label("NUS-3D  /  CHOOSE YOUR FACULTY", 25, Color.html("#f5c46a")))
    selector_box.add_child(_label("学院选择  |  你的作业，你的灾难。", 18, Color.html("#e8eee8")))
    selector_box.add_child(_label("Fictional game curriculum. Not an actual NUS module, transcript or deadline.", 12, Color.html("#aabdc4")))
    faculty_picker = OptionButton.new()
    faculty_picker.name = "FacultyPicker"
    faculty_picker.custom_minimum_size = Vector2(520, 42)
    selector_box.add_child(faculty_picker)
    for i in range(coursework.faculty_options.size()):
        var item: Dictionary = coursework.faculty_options[i]
        faculty_picker.add_item("%s  |  %s  /  %s" % [item["abbr"], item["zh"], item["name"]])
        faculty_picker.set_item_metadata(i, str(item["id"]))
    faculty_picker.item_selected.connect(_on_faculty_highlighted)
    faculty_description = _label("", 16, Color.html("#d7dfda"))
    faculty_description.custom_minimum_size.y = 105
    selector_box.add_child(faculty_description)
    var start := Button.new()
    start.name = "ConfirmFaculty"
    start.text = "进入学院 / START THE DDL CHAOS"
    start.custom_minimum_size.y = 43.0
    start.pressed.connect(_confirm_faculty)
    selector_box.add_child(start)
    selector_box.add_child(_label("学院可以以后更换。每个学院的课程进度分别保留；已有探索和奖励不会重置。", 12, Color.html("#aebebc")))

    journal_box = VBoxContainer.new()
    journal_box.name = "CourseworkJournal"
    journal_box.add_theme_constant_override("separation", 12)
    body.add_child(journal_box)
    journal_box.visible = false
    journal_box.add_child(_label("COURSEWORK JOURNAL  /  任务手册", 22, Color.html("#f5c46a")))
    journal_text = _label("", 15, Color.html("#e7ede9"))
    journal_text.custom_minimum_size = Vector2(520, 210)
    journal_box.add_child(journal_text)
    var switch_button := Button.new()
    switch_button.text = "切换学院 / CHANGE FACULTY"
    switch_button.custom_minimum_size.y = 37.0
    switch_button.pressed.connect(show_selector)
    journal_box.add_child(switch_button)
    journal_button = Button.new()
    journal_button.text = "返回游戏 / RESUME"
    journal_button.custom_minimum_size.y = 37.0
    journal_button.pressed.connect(hide_modal)
    journal_box.add_child(journal_button)

func _on_faculty_highlighted(index: int) -> void:
    if index < 0 or index >= coursework.faculty_options.size():
        return
    var faculty: Dictionary = coursework.faculty_options[index]
    var quests: Array = faculty["quests"]
    faculty_description.text = "学院剧情：%s\n本学院有 3 个原创 Coursework 任务。\n第一关：%s\n需要接通知、做室内活动、找队友、按时提交。\n" % [
        str(faculty["flavor"]), str(quests[0]["title"])
    ]

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
    var current: Dictionary = coursework.current_quest()
    var line: String = "选择学院：%s\n等级 Lv.%d  |  总经验 %d XP  |  学园积分 %d\n已完成课程：%d / 3（本学院）\n\n" % [
        coursework.faculty_name(), coursework.level(), coursework.total_xp,
        coursework.credits, coursework.active_quest_index
    ]
    if current.is_empty():
        line += "本学院 Coursework 全部完成！可继续探索或换学院。\n"
    else:
        line += "任务 %d/3：%s\n%s\n\nDDL：%s\n当前目标：%s\n" % [
            coursework.active_quest_index + 1, str(current["title"]),
            str(current["story"]), coursework.format_ddl(), coursework.objective_description()
        ]
    if not coursework.last_grade.is_empty():
        line += "\n最近评分：" + coursework.last_grade
    line += "\n\n[J] 返回  [O] 切换学院   |   进度已存于本地"
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
    if intro_blocked:
        return
    var club: UTownLeisureUI = get_parent().get_node_or_null("LeisureUI") as UTownLeisureUI
    if club != null and club.is_open:
        return  # Do not stack faculty/journal modal on top of the leisure menu.
    if not (event is InputEventKey):
        return
    var key: InputEventKey = event as InputEventKey
    if not key.pressed or key.echo:
        return
    if key.keycode == KEY_O:
        show_selector()
        get_viewport().set_input_as_handled()
    elif key.keycode == KEY_J:
        if modal_visible and not selection_visible:
            hide_modal()
        elif not modal_visible:
            show_journal()
        get_viewport().set_input_as_handled()
    elif key.keycode == KEY_ESCAPE and modal_visible:
        hide_modal()
        get_viewport().set_input_as_handled()
    elif modal_visible and key.keycode in [
        KEY_W, KEY_A, KEY_S, KEY_D, KEY_K, KEY_Q, KEY_B, KEY_X, KEY_I,
        KEY_F, KEY_L, KEY_Y, KEY_T, KEY_C, KEY_V, KEY_G, KEY_E, KEY_R,
        KEY_M, KEY_SPACE, KEY_SHIFT
    ]:
        get_viewport().set_input_as_handled()
