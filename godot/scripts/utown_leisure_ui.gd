extends CanvasLayer
class_name UTownLeisureUI
## Accessible in-game, no-betting leisure menu unlocked after a full faculty arc.
## Adult social option is voluntary, age-acknowledged, no extra XP/rewards.

@onready var leisure: UTownLeisure = $"../Leisure"
@onready var coursework: UTownCoursework = $"../Coursework"
@onready var player: UTownPlayer = $"../Player"
@onready var life: UTownCampusLife = $"../CampusLife"
@onready var course_ui: UTownCourseworkUI = $"../CourseworkUI"
@onready var intro: UTownIntro = $"../Intro"
@onready var hud: CanvasLayer = $"../HUD"

var is_open: bool = false
var active_tab: String = "chess"
var backdrop: ColorRect
var status_chip: Label
var header_label: Label
var caption_label: Label
var chess_panel: VBoxContainer
var card_panel: VBoxContainer
var social_panel: VBoxContainer
var chess_board_grid: GridContainer
var cells: Array[Button] = []
var chess_score: Label
var chess_message: Label
var card_score: Label
var card_message: Label
var card_hand_row: HBoxContainer
var social_message: Label
var adult_confirm: CheckBox
var adult_button: Button
var tab_chess: Button
var tab_cards: Button
var tab_social: Button

func _ready() -> void:
    layer = 18
    _build()
    _refresh()

func _palette(hex_value: String) -> Color:
    return Color.html(hex_value)

func _label(content: String, size: int = 16, color_hex: String = "#e9ede7") -> Label:
    var label := Label.new()
    label.text = content
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", _palette(color_hex))
    return label

func _button(title: String, width: float = 150.0) -> Button:
    var result := Button.new()
    result.text = title
    result.custom_minimum_size = Vector2(width, 38.0)
    result.add_theme_font_size_override("font_size", 15)
    return result

func _style_panel(panel: PanelContainer, color_hex: String) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = _palette(color_hex)
    style.set_corner_radius_all(12)
    style.set_border_width_all(1)
    style.border_color = _palette("#52636c")
    style.content_margin_left = 18.0
    style.content_margin_right = 18.0
    style.content_margin_top = 13.0
    style.content_margin_bottom = 13.0
    panel.add_theme_stylebox_override("panel", style)

func _build() -> void:
    status_chip = _label("", 15, "#ffd591")
    status_chip.name = "PostCourseShortcut"
    status_chip.anchor_left = 0.0
    status_chip.anchor_right = 0.0
    status_chip.anchor_top = 1.0
    status_chip.anchor_bottom = 1.0
    status_chip.offset_left = 22.0
    status_chip.offset_right = 480.0
    status_chip.offset_top = -91.0
    status_chip.offset_bottom = -62.0
    status_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(status_chip)

    backdrop = ColorRect.new()
    backdrop.name = "LeisureOverlay"
    backdrop.color = Color(0.025, 0.04, 0.06, 0.92)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    backdrop.visible = false
    add_child(backdrop)

    var center := CenterContainer.new()
    center.name = "LeisureCenter"
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    backdrop.add_child(center)

    var panel := PanelContainer.new()
    panel.name = "PostCourseClubPanel"
    panel.custom_minimum_size = Vector2(728, 620)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _style_panel(panel, "#183039")
    center.add_child(panel)

    var column := VBoxContainer.new()
    column.name = "LeisureContent"
    column.add_theme_constant_override("separation", 9)
    panel.add_child(column)
    var heading := HBoxContainer.new()
    column.add_child(heading)
    header_label = _label("POST-COURSE CLUB  /  下课后才是真正的游戏", 23, "#ffcf86")
    header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_child(header_label)
    var close_btn := _button("×  关闭 [P]", 128.0)
    close_btn.pressed.connect(close_lounge)
    heading.add_child(close_btn)

    caption_label = _label("完成任意学院全部 3 章 Coursework 后永久开放。", 14, "#b3cbd0")
    column.add_child(caption_label)

    var tabs := HBoxContainer.new()
    tabs.alignment = BoxContainer.ALIGNMENT_CENTER
    tabs.add_theme_constant_override("separation", 12)
    column.add_child(tabs)
    tab_chess = _button("五子棋  GOMOKU", 190)
    tab_chess.pressed.connect(func() -> void: switch_tab("chess"))
    tabs.add_child(tab_chess)
    tab_cards = _button("打牌  CARDS", 190)
    tab_cards.pressed.connect(func() -> void: switch_tab("cards"))
    tabs.add_child(tab_cards)
    tab_social = _button("聚会  CHEERS", 190)
    tab_social.pressed.connect(func() -> void: switch_tab("social"))
    tabs.add_child(tab_social)

    chess_panel = VBoxContainer.new()
    chess_panel.name = "GomokuGame"
    chess_panel.add_theme_constant_override("separation", 6)
    column.add_child(chess_panel)
    chess_score = _label("", 15, "#cfebce")
    chess_panel.add_child(chess_score)
    var center_board := CenterContainer.new()
    chess_panel.add_child(center_board)
    chess_board_grid = GridContainer.new()
    chess_board_grid.name = "NineByNineChessBoard"
    chess_board_grid.columns = leisure.BOARD_SIZE
    chess_board_grid.add_theme_constant_override("h_separation", 1)
    chess_board_grid.add_theme_constant_override("v_separation", 1)
    center_board.add_child(chess_board_grid)
    var board_style := StyleBoxFlat.new()
    board_style.bg_color = _palette("#bba371")
    board_style.border_color = _palette("#8b724f")
    board_style.set_border_width_all(1)
    for y in range(leisure.BOARD_SIZE):
        for x in range(leisure.BOARD_SIZE):
            var cell := _button("·", 41.0)
            cell.custom_minimum_size.y = 38.0
            cell.focus_mode = Control.FOCUS_NONE
            cell.add_theme_font_size_override("font_size", 25)
            cell.add_theme_stylebox_override("normal", board_style)
            cell.add_theme_stylebox_override("hover", board_style)
            cell.pressed.connect(_on_chess_cell.bind(x, y))
            chess_board_grid.add_child(cell)
            cells.append(cell)
    chess_message = _label("", 15)
    chess_panel.add_child(chess_message)
    var new_chess := _button("重新开局 / REMATCH", 220)
    new_chess.pressed.connect(_reset_chess)
    chess_panel.add_child(new_chess)

    card_panel = VBoxContainer.new()
    card_panel.name = "FiveRoundCardDuel"
    card_panel.add_theme_constant_override("separation", 12)
    column.add_child(card_panel)
    card_panel.visible = false
    card_panel.add_child(_label("五轮纸牌比大小，不下注、不需要充值。选择手里的一张牌。", 17, "#ebddb2"))
    card_score = _label("", 19, "#e5f2eb")
    card_panel.add_child(card_score)
    card_panel.add_child(_label("你的手牌（点数 2 至 A，同点数平局）", 16))
    card_hand_row = HBoxContainer.new()
    card_hand_row.name = "CardHand"
    card_hand_row.add_theme_constant_override("separation", 10)
    card_panel.add_child(card_hand_row)
    card_message = _label("", 18, "#f4d9a1")
    card_message.custom_minimum_size.y = 112.0
    card_panel.add_child(card_message)
    var new_cards := _button("重新洗牌 / NEW MATCH", 220)
    new_cards.pressed.connect(_reset_cards)
    card_panel.add_child(new_cards)
    card_panel.add_child(_label("对手的牌是隐藏的；五轮后比总得分。赢牌只获得娱乐战绩，不赢取金币。", 14, "#aec0c5"))

    social_panel = VBoxContainer.new()
    social_panel.name = "FictionalAfterClassParty"
    social_panel.add_theme_constant_override("separation", 14)
    column.add_child(social_panel)
    social_panel.visible = false
    social_panel.add_child(_label("虚构的下课后社团聚会  /  ORIGINAL SOCIAL SCENE", 21, "#ffcf86"))
    social_panel.add_child(_label("同 NPC 庆祝完成课程：所有饮品都能触发一样的搞笑对话，没有酒精专属奖励。", 16))
    var drinks := HBoxContainer.new()
    drinks.add_theme_constant_override("separation", 11)
    social_panel.add_child(drinks)
    var mocktail := _button("无酒精特调", 160)
    mocktail.pressed.connect(_on_drink.bind("mocktail"))
    drinks.add_child(mocktail)
    var tea := _button("茶饮 / JUICE", 160)
    tea.pressed.connect(_on_drink.bind("tea"))
    drinks.add_child(tea)
    adult_button = _button("成年人小酌", 160)
    adult_button.pressed.connect(_on_drink.bind("adult"))
    drinks.add_child(adult_button)
    adult_confirm = CheckBox.new()
    adult_confirm.text = "我已达到所在地法定饮酒年龄（仅启用可选的虚构小酌情节）"
    adult_confirm.add_theme_font_size_override("font_size", 14)
    adult_confirm.toggled.connect(_on_age_confirm)
    social_panel.add_child(adult_confirm)
    social_message = _label("", 18, "#f6d7a4")
    social_message.custom_minimum_size.y = 124
    social_panel.add_child(social_message)
    social_panel.add_child(_label("喝酒不是任务条件。不提供饮酒奖励或现实行为建议；小酌情节后需等待才能骑车或乘车。", 14, "#a9c1c4"))
    _refresh()

func _on_age_confirm(enabled: bool) -> void:
    adult_button.disabled = not enabled

func open_lounge() -> bool:
    if is_open:
        return true
    if not leisure.unlocked():
        life.message = "完成任一学院全部 3 个 Coursework 任务后解锁棋牌与聚会。"
        life.message_time = 4.0
        return false
    var voice: Node = get_parent().get_node_or_null("VoicePresentation")
    if voice != null and voice.get("is_open") == true:
        return false
    if intro.playing or course_ui.modal_visible or course_ui.intro_blocked or coursework.current_faculty_id.is_empty():
        return false
    if life.on_shuttle or life.bicycle_enabled:
        life.message = "先下车或停好自行车，再去下课后社团活动。"
        life.message_time = 3.5
        return false
    is_open = true
    backdrop.visible = true
    coursework.modal_open = true
    player.movement_locked = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    adult_confirm.button_pressed = false
    switch_tab("chess")
    return true

func close_lounge() -> void:
    if not is_open:
        return
    is_open = false
    backdrop.visible = false
    # Do not change first-run modal lock or shuttle state.
    coursework.modal_open = course_ui.modal_visible or intro.playing
    player.movement_locked = coursework.modal_open or life.on_shuttle
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if coursework.modal_open else Input.MOUSE_MODE_CAPTURED

func switch_tab(key: String) -> void:
    if key not in ["chess", "cards", "social"]:
        return
    active_tab = key
    chess_panel.visible = key == "chess"
    card_panel.visible = key == "cards"
    social_panel.visible = key == "social"
    _refresh()

func _on_chess_cell(x: int, y: int) -> void:
    if leisure.play_chess(x, y):
        _refresh()

func _reset_chess() -> void:
    leisure.reset_chess()
    _refresh()

func _reset_cards() -> void:
    leisure.start_cards()
    _refresh()

func _on_play_card(index: int) -> void:
    if leisure.play_card(index):
        _refresh()

func _on_drink(kind: String) -> void:
    leisure.celebrate(kind, adult_confirm.button_pressed)
    _refresh()

func _refresh() -> void:
    if chess_score == null:
        return
    header_label.text = "POST-COURSE CLUB  /  下课后才是真正的游戏"
    var count: int = coursework.total_completed()
    caption_label.text = "本机累计 Coursework：%d/39   |   棋胜 %d/%d   牌胜 %d/%d   聚会 %d 次" % [
        count, leisure.chess_wins, leisure.chess_games, leisure.card_wins, leisure.card_games, leisure.social_visits
    ]
    if leisure.grand_master_unlocked():
        caption_label.text += "   |   全院系通关：校园休闲大师"
    chess_score.text = "你执黑 ●  |  NPC 执白 ○  |  连五获胜  |  棋盘 9 × 9"
    for y in range(leisure.BOARD_SIZE):
        for x in range(leisure.BOARD_SIZE):
            var index: int = y * leisure.BOARD_SIZE + x
            var value: int = leisure.stone_at(x, y)
            var cell: Button = cells[index]
            cell.text = "●" if value == 1 else "○" if value == 2 else "·"
            cell.add_theme_color_override("font_color", _palette("#202c30" if value == 1 else "#ffffff" if value == 2 else "#745b38"))
            cell.disabled = value != 0 or leisure.chess_over
    chess_message.text = leisure.chess_last_message
    card_score.text = "第 %d/%d 轮  |  玩家 %d : %d NPC" % [
        leisure.card_round, leisure.CARD_ROUNDS, leisure.card_player_points, leisure.card_npc_points
    ]
    card_message.text = leisure.card_message
    for child in card_hand_row.get_children():
        card_hand_row.remove_child(child)
        child.queue_free()
    if leisure.card_over:
        card_hand_row.add_child(_label("本局结束，可重新洗牌再玩。", 16))
    else:
        for i in range(leisure.card_hand.size()):
            var card: Dictionary = leisure.card_hand[i]
            var card_button := _button(leisure.card_label(card), 92.0)
            card_button.custom_minimum_size.y = 98
            card_button.add_theme_font_size_override("font_size", 27)
            card_button.pressed.connect(_on_play_card.bind(i))
            card_hand_row.add_child(card_button)
    adult_button.disabled = not adult_confirm.button_pressed
    social_message.text = leisure.social_message

func _process(_delta: float) -> void:
    if status_chip == null:
        return
    status_chip.visible = leisure.unlocked() and not is_open and hud.visible and not course_ui.modal_visible and not intro.playing
    if status_chip.visible:
        status_chip.text = "POST-COURSE CLUB  [Tab]  |  五子棋 · 纸牌 · 聚会" + ("  |  39/39 MASTER" if leisure.grand_master_unlocked() else "")

func _input(event: InputEvent) -> void:
    var voice: Node = get_parent().get_node_or_null("VoicePresentation")
    if voice != null and voice.get("is_open") == true:
        return
    var exams: Node = get_parent().get_node_or_null("EnglishExams")
    if exams != null and bool(exams.get("is_open")):
        return
    if not (event is InputEventKey):
        return
    var key: InputEventKey = event as InputEventKey
    if not key.pressed or key.echo:
        return
    if key.keycode == KEY_TAB:
        if is_open:
            close_lounge()
        else:
            open_lounge()
        get_viewport().set_input_as_handled()
    elif key.keycode == KEY_ESCAPE and is_open:
        close_lounge()
        get_viewport().set_input_as_handled()
    elif is_open:
        get_viewport().set_input_as_handled()
