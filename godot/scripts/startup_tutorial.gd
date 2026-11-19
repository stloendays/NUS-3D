extends Control
class_name NUS3DTutorial
var language_service: NUS3DGameLanguage
## Standalone, data-driven startup guide. This panel works while SceneTree is paused.
## Content is maintained in res://data/startup_tutorial.json, not in gameplay scripts.

signal closed

const DATA_PATH: String = "res://data/startup_tutorial.json"

var pages: Array[Dictionary] = []
var current_page: int = 0
var heading_label: Label
var subtitle_label: Label
var page_title_label: Label
var page_tag_label: Label
var page_counter_label: Label
var page_content: VBoxContainer
var page_scroll: ScrollContainer
var previous_button: Button
var next_button: Button
var close_button: Button
var instruction_label: Label


func _ready() -> void:
    NUS3DServices.ensure_scene_services(get_tree())
    language_service = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _load_tutorial()
    _build_view()
    language_service.language_changed.connect(_on_language_changed)
    _on_language_changed(language_service.locale)
    hide()


func _load_tutorial() -> void:
    pages.clear()
    if not FileAccess.file_exists(DATA_PATH):
        push_error("Missing packaged tutorial: " + DATA_PATH)
        return
    var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if typeof(source) != TYPE_DICTIONARY:
        push_error("Startup tutorial JSON is not an object")
        return
    if int(source.get("schema_version", 0)) != 1:
        push_error("Unsupported startup tutorial schema")
        return
    var entries: Variant = source.get("pages", [])
    if typeof(entries) != TYPE_ARRAY:
        push_error("Startup tutorial pages must be an array")
        return
    for entry in entries:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        if str(entry.get("title", "")).is_empty():
            continue
        var sections: Variant = entry.get("sections", [])
        if typeof(sections) != TYPE_ARRAY or sections.is_empty():
            continue
        pages.append(entry)
    if pages.is_empty():
        push_error("Startup tutorial has no valid content")


func _make_label(text_value: String, font_size: int, color: Color) -> Label:
    var element: Label = Label.new()
    element.text = text_value
    element.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    element.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    element.add_theme_font_size_override("font_size", font_size)
    element.add_theme_color_override("font_color", color)
    return element


func _make_button(text_value: String, action: Callable) -> Button:
    var element: Button = Button.new()
    element.text = text_value
    element.custom_minimum_size = Vector2(135, 42)
    element.pressed.connect(action)
    return element


func _build_view() -> void:
    var dimmer: ColorRect = ColorRect.new()
    dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dimmer.color = Color(0.016, 0.038, 0.055, 0.96)
    dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dimmer)

    var center: CenterContainer = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    var card: PanelContainer = PanelContainer.new()
    card.custom_minimum_size = Vector2(860, 580)
    var card_style: StyleBoxFlat = StyleBoxFlat.new()
    card_style.bg_color = Color.html("#10222f")
    card_style.border_color = Color.html("#537785")
    card_style.set_border_width_all(1)
    card_style.set_corner_radius_all(17)
    card_style.content_margin_left = 30
    card_style.content_margin_right = 30
    card_style.content_margin_top = 24
    card_style.content_margin_bottom = 24
    card.add_theme_stylebox_override("panel", card_style)
    center.add_child(card)

    var main: VBoxContainer = VBoxContainer.new()
    main.add_theme_constant_override("separation", 12)
    card.add_child(main)

    var header: HBoxContainer = HBoxContainer.new()
    main.add_child(header)
    heading_label = _make_label("NUS-3D  /  新手教程", 27, Color.html("#e6f8fc"))
    header.add_child(heading_label)
    close_button = _make_button("关闭教程  ×", close_guide)
    header.add_child(close_button)

    subtitle_label = _make_label(
        "离线非官方玩法说明。打开教程不需要注册或登录账号。",
        13, Color.html("#aac5cc"))
    main.add_child(subtitle_label)
    main.add_child(HSeparator.new())

    var topic_row: HBoxContainer = HBoxContainer.new()
    main.add_child(topic_row)
    page_title_label = _make_label("", 23, Color.html("#e9f5f3"))
    topic_row.add_child(page_title_label)
    page_counter_label = _make_label("", 15, Color.html("#a7d5da"))
    page_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    topic_row.add_child(page_counter_label)

    page_tag_label = _make_label("", 14, Color.html("#69c3d3"))
    main.add_child(page_tag_label)

    page_scroll = ScrollContainer.new()
    page_scroll.custom_minimum_size = Vector2(0, 355)
    page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    main.add_child(page_scroll)

    page_content = VBoxContainer.new()
    page_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    page_content.add_theme_constant_override("separation", 15)
    page_scroll.add_child(page_content)

    main.add_child(HSeparator.new())
    var footer: HBoxContainer = HBoxContainer.new()
    footer.add_theme_constant_override("separation", 14)
    main.add_child(footer)
    previous_button = _make_button("上一页", previous_page)
    footer.add_child(previous_button)
    instruction_label = _make_label("阅读完毕后关闭，返回登录界面。", 12, Color.html("#adc0c5"))
    instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    footer.add_child(instruction_label)
    next_button = _make_button("下一页", next_page)
    footer.add_child(next_button)


func _on_language_changed(_locale: String) -> void:
    heading_label.text = language_service.localized_text("NUS-3D / 新手教程", "NUS-3D / BEGINNER GUIDE")
    subtitle_label.text = language_service.localized_text(
        "离线非官方玩法说明。打开教程不需要注册或登录账号。",
        "Unofficial offline guide. You can read it before creating an account.")
    close_button.text = language_service.localized_text("关闭教程 ×", "Close guide ×")
    previous_button.text = language_service.localized_text("上一页", "Previous")
    instruction_label.text = language_service.localized_text(
        "读完后返回登录界面。", "Close the guide to return to the sign-in screen.")
    if not pages.is_empty():
        _render_page()


func open_guide() -> void:
    if pages.is_empty():
        push_warning("Cannot open startup guide; content is missing")
        return
    current_page = 0
    _render_page()
    show()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_guide() -> void:
    hide()
    closed.emit()


func previous_page() -> void:
    if current_page > 0:
        current_page -= 1
        _render_page()


func next_page() -> void:
    if current_page >= pages.size() - 1:
        close_guide()
    else:
        current_page += 1
        _render_page()


func _render_page() -> void:
    if current_page < 0 or current_page >= pages.size():
        return
    var item: Dictionary = pages[current_page]
    page_title_label.text = str(item.get("title", "")) if language_service.is_chinese() else str(item.get("title_en", item.get("title", "")))
    page_tag_label.text = str(item.get("tag", "")) if language_service.is_chinese() else str(item.get("tag_en", item.get("tag", "")))
    page_counter_label.text = "%d / %d" % [current_page + 1, pages.size()]
    previous_button.disabled = current_page == 0
    next_button.text = language_service.localized_text("完成 · 返回", "Finish · Back") if current_page == pages.size() - 1 else language_service.localized_text("下一页", "Next")

    for old_child in page_content.get_children():
        page_content.remove_child(old_child)
        old_child.queue_free()

    var sections: Array = item.get("sections", [])
    for raw_section in sections:
        if typeof(raw_section) != TYPE_DICTIONARY:
            continue
        var section: Dictionary = raw_section
        var heading: String = str(section.get("heading", "")) if language_service.is_chinese() else str(section.get("heading_en", section.get("heading", "")))
        var topic: Label = _make_label(heading, 18, Color.html("#e3f0ef"))
        page_content.add_child(topic)
        var body: String = str(section.get("body", "")) if language_service.is_chinese() else str(section.get("body_en", section.get("body", "")))
        var explanation: Label = _make_label(body, 15, Color.html("#c3d4d9"))
        explanation.custom_minimum_size.y = 52
        page_content.add_child(explanation)
    page_scroll.scroll_vertical = 0


func _input(event: InputEvent) -> void:
    if not visible:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            close_guide()
            get_viewport().set_input_as_handled()
