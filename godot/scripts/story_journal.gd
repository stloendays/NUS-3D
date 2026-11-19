extends Control
class_name NUS3DStoryJournal
## Paused-world quest journal: zero permanent modifications to 3D scene/HUD.
## Fully localized from story_campaign.json. Works without paid or cloud services.

signal close_requested

var campaign: NUS3DStoryCampaign
var selected_index: int = 0
var heading_label: Label
var status_label: Label
var close_button: Button
var sidebar: ItemList
var details: VBoxContainer
var detail_scroll: ScrollContainer
var footer_label: Label


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build_ui()
    if campaign != null:
        campaign.campaign_changed.connect(_refresh)
    GameLanguage.language_changed.connect(_on_language_changed)
    hide()


func _tr(chinese: String, english: String) -> String:
    return GameLanguage.localized_text(chinese, english)


func _l(value: Variant) -> String:
    if typeof(value) == TYPE_DICTIONARY:
        var pair: Dictionary = value
        return str(pair.get(GameLanguage.locale, pair.get("en", pair.get("zh", ""))))
    return str(value)


func _label(value: String, size: int = 15, color: Color = Color.WHITE) -> Label:
    var element: Label = Label.new()
    element.text = value
    element.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    element.add_theme_font_size_override("font_size", size)
    element.add_theme_color_override("font_color", color)
    element.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return element


func _button(value: String) -> Button:
    var element: Button = Button.new()
    element.text = value
    element.custom_minimum_size.y = 39.0
    return element


func _panel_style() -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color.html("#11222f")
    style.border_color = Color.html("#527c89")
    style.set_border_width_all(1)
    style.set_corner_radius_all(16)
    style.content_margin_left = 22
    style.content_margin_top = 20
    style.content_margin_right = 22
    style.content_margin_bottom = 20
    return style


func _build_ui() -> void:
    var backdrop: ColorRect = ColorRect.new()
    backdrop.color = Color(0.018, 0.043, 0.059, 0.96)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(backdrop)

    var center: CenterContainer = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var panel: PanelContainer = PanelContainer.new()
    panel.custom_minimum_size = Vector2(1020, 596)
    panel.add_theme_stylebox_override("panel", _panel_style())
    center.add_child(panel)
    var main: VBoxContainer = VBoxContainer.new()
    main.add_theme_constant_override("separation", 10)
    panel.add_child(main)

    var header: HBoxContainer = HBoxContainer.new()
    main.add_child(header)
    heading_label = _label("", 26, Color.html("#e5f7f4"))
    header.add_child(heading_label)
    close_button = _button("")
    close_button.pressed.connect(request_close)
    header.add_child(close_button)

    status_label = _label("", 14, Color.html("#b9d9df"))
    main.add_child(status_label)
    main.add_child(HSeparator.new())

    var content: HBoxContainer = HBoxContainer.new()
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 18)
    main.add_child(content)

    sidebar = ItemList.new()
    sidebar.custom_minimum_size = Vector2(290, 390)
    sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
    sidebar.item_selected.connect(_select)
    content.add_child(sidebar)

    detail_scroll = ScrollContainer.new()
    detail_scroll.custom_minimum_size = Vector2(660, 390)
    detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    content.add_child(detail_scroll)

    details = VBoxContainer.new()
    details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    details.add_theme_constant_override("separation", 11)
    detail_scroll.add_child(details)

    main.add_child(HSeparator.new())
    footer_label = _label("", 12, Color.html("#b0c4c9"))
    main.add_child(footer_label)


func open_journal() -> void:
    _refresh()
    show()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func request_close() -> void:
    hide()
    close_requested.emit()


func _on_language_changed(_locale: String) -> void:
    _refresh()


func _select(index: int) -> void:
    selected_index = index
    _render_details()


func _refresh() -> void:
    if sidebar == null or campaign == null or not campaign.is_active():
        return
    heading_label.text = _tr("UTOWN 异闻录 / 支线任务", "UTOWN CHRONICLES / SIDE QUESTS")
    close_button.text = _tr("返回校园 [P]", "Back to campus [P]")
    footer_label.text = _tr("完成任务并做选择将影响结局；本界面打开时游戏暂停，按 P 关闭。",
        "Choices change your ending. The game pauses here; press P to return.")
    var stats: Dictionary = campaign.get_stats()
    status_label.text = _tr(
        "已完成 %d/%d | 善意 %d  诚信 %d  压力 %d | 结局 %d/%d" %
            [campaign.completed_quests(), campaign.quest_list().size(), int(stats.get("kindness", 0)),
            int(stats.get("integrity", 0)), int(stats.get("stress", 0)),
            campaign.unlocked_endings().size(), campaign.ending_list().size()],
        "Completed %d/%d | Kindness %d  Integrity %d  Stress %d | Endings %d/%d" %
            [campaign.completed_quests(), campaign.quest_list().size(), int(stats.get("kindness", 0)),
            int(stats.get("integrity", 0)), int(stats.get("stress", 0)),
            campaign.unlocked_endings().size(), campaign.ending_list().size()]
    )

    sidebar.clear()
    for raw in campaign.quest_list():
        var quest: Dictionary = raw
        var quest_id: String = str(quest.get("id", ""))
        var marker: String = "[✓] " if not campaign.selected_option(quest_id).is_empty() \
            else "[!] " if campaign.quest_ready(quest_id) else "[ ] "
        sidebar.add_item(marker + _l(quest.get("title", {})))
    sidebar.add_item(_tr("终章 · 最后一秒的 DDL", "FINALE · Last Second to Deadline"))
    sidebar.add_item(_tr("结局图鉴", "Ending Gallery"))
    selected_index = clampi(selected_index, 0, sidebar.item_count - 1)
    sidebar.select(selected_index)
    _render_details()


func _clear_details() -> void:
    for item in details.get_children():
        details.remove_child(item)
        item.queue_free()


func _line(value: String, size: int = 15, color: Color = Color.WHITE) -> void:
    details.add_child(_label(value, size, color))


func _render_details() -> void:
    if campaign == null or not campaign.is_active() or details == null:
        return
    _clear_details()
    var quest_count: int = campaign.quest_list().size()
    if selected_index < quest_count:
        _render_quest(campaign.quest_list()[selected_index])
    elif selected_index == quest_count:
        _render_finale()
    else:
        _render_gallery()
    detail_scroll.scroll_vertical = 0


func _render_quest(quest: Dictionary) -> void:
    var quest_id: String = str(quest.get("id", ""))
    _line(_l(quest.get("title", {})), 22, Color.html("#e7f7f0"))
    _line(_l(quest.get("intro", {})), 15, Color.html("#c8d9db"))
    _line(_tr("任务目标", "OBJECTIVES"), 17, Color.html("#79cbd5"))
    var complete: bool = true
    for objective in campaign.objective_progress(quest_id):
        var current: int = int(objective.get("count", 0))
        var needed: int = int(objective.get("needed", 1))
        var prefix: String = "[✓]" if current >= needed else "[ ]"
        _line("%s %s  (%d/%d)" % [prefix, _l(objective.get("title", {})), current, needed], 15)
        if current < needed:
            complete = false
    _line(_tr("事件奖励：70 XP（每账号首次完成有效）",
        "Quest reward: 70 XP (first completion per account)"), 12, Color.html("#aac8d0"))

    var selected: String = campaign.selected_option(quest_id)
    if not selected.is_empty():
        for option_raw in quest.get("choices", []):
            var option: Dictionary = option_raw
            if str(option.get("id", "")) == selected:
                _line(_tr("已做出的选择", "YOUR CHOICE"), 17, Color.html("#79cbd5"))
                _line(_l(option.get("title", {})), 16)
                _line(_l(option.get("result", {})), 15, Color.html("#d5e4d5"))
                return
    if not campaign.current_ending().is_empty():
        _line(_tr("本轮剧情已结束，重开剧情后可以继续选择。",
            "This run has ended. Replay the story to make new choices."), 14)
        return
    if not complete:
        _line(_tr("继续探索校园来解锁剧情选择。", "Keep exploring to unlock your choices."), 14)
        return
    _line(_tr("下一步由你决定：", "What will you do?"), 17, Color.html("#79cbd5"))
    for raw in quest.get("choices", []):
        var option: Dictionary = raw
        var choice_id: String = str(option.get("id", ""))
        var button: Button = _button(_l(option.get("title", {})))
        button.pressed.connect(Callable(self, "_choose").bind(quest_id, choice_id))
        details.add_child(button)


func _choose(quest_id: String, choice_id: String) -> void:
    campaign.choose(quest_id, choice_id)


func _render_finale() -> void:
    var finale: Dictionary = campaign.catalogue.get("finale", {})
    _line(_l(finale.get("title", {})), 22, Color.html("#e8f5f0"))
    if not campaign.current_ending().is_empty():
        var ending: Dictionary = campaign.ending_by_id(campaign.current_ending())
        _line(_l(ending.get("title", {})), 19, Color.html("#79cbd5"))
        _line(_l(ending.get("story", {})), 17)
        _line(_tr("重新开始剧情：支线选择和结局判定重置，账号经验、已收集物品、地图和结局图鉴全部保留。",
            "Replay: reset story choices, but keep XP, collected items, exploration and the ending gallery."), 13)
        var replay: Button = _button(_tr("再玩一轮剧情", "Replay story"))
        replay.pressed.connect(_replay)
        details.add_child(replay)
        return
    _line(_l(finale.get("intro", {})), 16, Color.html("#c8d9db"))
    var required: int = int(campaign.catalogue.get("settings", {}).get("required_quests_for_finale", 3))
    _line(_tr("开启终章需要完成 %d 条支线。当前 %d/%d。" % [required, campaign.completed_quests(), required],
        "Complete %d side quests to unlock the finale. Progress %d/%d." % [required, campaign.completed_quests(), required]), 15)
    if not campaign.finale_available():
        _line(_tr("还没到结局，继续探索、交谈并完成支线吧。",
            "The story continues. Talk to students and complete more quests."), 15)
        return
    _line(_tr("最终决定将锁定本轮结局。", "Your final choice locks this run's ending."), 15, Color.html("#79cbd5"))
    for raw in finale.get("choices", []):
        var option: Dictionary = raw
        var button: Button = _button(_l(option.get("title", {})))
        button.pressed.connect(Callable(self, "_finish").bind(str(option.get("id", ""))))
        details.add_child(button)


func _finish(choice_id: String) -> void:
    campaign.finish(choice_id)


func _replay() -> void:
    campaign.replay_story()


func _render_gallery() -> void:
    _line(_tr("结局图鉴", "ENDING GALLERY"), 22, Color.html("#e7f7f0"))
    _line(_tr("不同支线选择将导向不同结局，已解锁的结局会永久保留在此账号。",
        "Different choices lead to different endings. Discovered endings remain in this account."), 15)
    var unlocked: Array = campaign.unlocked_endings()
    var number: int = 0
    for raw in campaign.ending_list():
        var ending: Dictionary = raw
        var id: String = str(ending.get("id", ""))
        number += 1
        if unlocked.has(id):
            _line("%d. %s" % [number, _l(ending.get("title", {}))], 17, Color.html("#78d6b7"))
            _line(_l(ending.get("story", {})), 14, Color.html("#c8d8d3"))
        else:
            var kind: String = str(ending.get("type", ""))
            var category: String = _tr("隐藏", "Secret") if kind == "secret" else _tr(
                "好结局", "Good") if kind == "good" else _tr("坏结局", "Bad")
            _line("%d. %s · ???" % [number, category], 16, Color.html("#b0c2c9"))
            if kind != "secret":
                _line(_l(ending.get("hint", {})), 13, Color.html("#a1b4bd"))


func _input(event: InputEvent) -> void:
    if not visible or not (event is InputEventKey):
        return
    var key: InputEventKey = event as InputEventKey
    if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
        request_close()
        get_viewport().set_input_as_handled()
