extends Control
class_name NUS3DCampusHub
## Optional, read-only external links and manually triggered local AI requests.
## No API keys, credentials, saves or automatic account data are read or sent.

signal close_requested

const LINKS_PATH: String = "res://data/campus_links.json"
const BRIDGE_URL: String = "http://127.0.0.1:8765"
const MAX_PROMPT_CHARS: int = 1200
const MAX_HISTORY_ITEMS: int = 8
const ALLOWED_HOSTS = [
    "chatgpt.com", "claude.ai", "gemini.google.com", "www.perplexity.ai",
    "developers.openai.com", "map.nus.edu.sg", "uci.nus.edu.sg",
    "nusmods.com", "www.nus.edu.sg", "github.com",
]

var language_service: NUS3DGameLanguage
var links: Array[Dictionary] = []
var chat_history: Array[Dictionary] = []
var pending_kind: String = ""
var pending_user_message: String = ""
var pending_provider: String = ""

var title_label: Label
var note_label: Label
var privacy_label: Label
var status_label: Label
var link_note_label: Label
var transcript: TextEdit
var prompt_input: TextEdit
var provider_picker: OptionButton
var links_list: ItemList
var send_button: Button
var status_button: Button
var weather_button: Button
var clear_button: Button
var open_link_button: Button
var close_button: Button
var web_request: HTTPRequest
var active_link_index: int = -1


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    language_service = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage
    _load_catalog()
    _build_ui()
    web_request = HTTPRequest.new()
    web_request.timeout = 20.0
    web_request.body_size_limit = 150000
    web_request.max_redirects = 0
    add_child(web_request)
    web_request.request_completed.connect(_on_request_completed)
    if language_service != null:
        language_service.language_changed.connect(_refresh_language)
    _refresh_language("")
    hide()


func _zh() -> bool:
    return language_service != null and language_service.is_chinese()


func _tr(zh: String, en: String) -> String:
    return zh if _zh() else en


static func is_allowlisted_url(url: String) -> bool:
    if not url.begins_with("https://"):
        return false
    var pieces: PackedStringArray = url.split("/")
    if pieces.size() < 3:
        return false
    var host: String = pieces[2].to_lower()
    return host in ALLOWED_HOSTS


func _load_catalog() -> void:
    links.clear()
    if not FileAccess.file_exists(LINKS_PATH):
        push_warning("Campus links registry is missing.")
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LINKS_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Campus links registry is invalid.")
        return
    for entry in parsed.get("links", []):
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var item: Dictionary = entry
        if is_allowlisted_url(str(item.get("url", ""))):
            links.append(item)


func _make_label(value: String, size: int = 15, color: Color = Color("#e8f0f3")) -> Label:
    var result: Label = Label.new()
    result.text = value
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result.add_theme_font_size_override("font_size", size)
    result.add_theme_color_override("font_color", color)
    return result


func _make_button(value: String, action: Callable) -> Button:
    var result: Button = Button.new()
    result.text = value
    result.custom_minimum_size.y = 37
    result.pressed.connect(action)
    return result


func _build_ui() -> void:
    var tint: ColorRect = ColorRect.new()
    tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    tint.color = Color(0.01, 0.03, 0.055, 0.88)
    tint.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(tint)

    var centered: CenterContainer = CenterContainer.new()
    centered.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(centered)

    var panel: PanelContainer = PanelContainer.new()
    panel.custom_minimum_size = Vector2(1040, 630)
    var skin: StyleBoxFlat = StyleBoxFlat.new()
    skin.bg_color = Color("#102630")
    skin.border_color = Color("#72bfc1")
    skin.set_border_width_all(1)
    skin.set_corner_radius_all(15)
    skin.content_margin_left = 20
    skin.content_margin_right = 20
    skin.content_margin_top = 15
    skin.content_margin_bottom = 17
    panel.add_theme_stylebox_override("panel", skin)
    centered.add_child(panel)

    var container: VBoxContainer = VBoxContainer.new()
    container.add_theme_constant_override("separation", 9)
    panel.add_child(container)

    var heading: HBoxContainer = HBoxContainer.new()
    container.add_child(heading)
    title_label = _make_label("CAMPUS AI", 25, Color("#d7fbf7"))
    title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.add_child(title_label)
    close_button = _make_button("Close  [F8]", func() -> void: close_requested.emit())
    heading.add_child(close_button)

    note_label = _make_label("", 12, Color("#b6d6d9"))
    container.add_child(note_label)

    var halves: HBoxContainer = HBoxContainer.new()
    halves.size_flags_vertical = Control.SIZE_EXPAND_FILL
    halves.add_theme_constant_override("separation", 20)
    container.add_child(halves)

    var chat_side: VBoxContainer = VBoxContainer.new()
    chat_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    chat_side.add_theme_constant_override("separation", 8)
    halves.add_child(chat_side)

    var provider_line: HBoxContainer = HBoxContainer.new()
    chat_side.add_child(provider_line)
    var provider_caption: Label = _make_label("AI", 15)
    provider_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    provider_line.add_child(provider_caption)
    provider_picker = OptionButton.new()
    provider_picker.custom_minimum_size.x = 160
    provider_picker.add_item("GPT / OpenAI")
    provider_picker.set_item_metadata(0, "openai")
    provider_picker.add_item("Gemini")
    provider_picker.set_item_metadata(1, "gemini")
    provider_picker.add_item("Claude")
    provider_picker.set_item_metadata(2, "claude")
    provider_line.add_child(provider_picker)

    transcript = TextEdit.new()
    transcript.editable = false
    transcript.selecting_enabled = true
    transcript.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    transcript.custom_minimum_size = Vector2(565, 228)
    transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
    chat_side.add_child(transcript)

    prompt_input = TextEdit.new()
    prompt_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    prompt_input.custom_minimum_size.y = 78
    chat_side.add_child(prompt_input)

    var actions: HBoxContainer = HBoxContainer.new()
    actions.add_theme_constant_override("separation", 8)
    chat_side.add_child(actions)
    send_button = _make_button("Send", _send_chat)
    actions.add_child(send_button)
    clear_button = _make_button("Clear", clear_session)
    actions.add_child(clear_button)
    status_button = _make_button("Connection", _check_connection)
    actions.add_child(status_button)
    weather_button = _make_button("Weather", _check_weather)
    actions.add_child(weather_button)

    privacy_label = _make_label("", 12, Color("#b2d0ce"))
    chat_side.add_child(privacy_label)
    status_label = _make_label("", 12, Color("#e8c99b"))
    chat_side.add_child(status_label)

    var link_side: VBoxContainer = VBoxContainer.new()
    link_side.custom_minimum_size.x = 340
    link_side.add_theme_constant_override("separation", 9)
    halves.add_child(link_side)

    var link_title: Label = _make_label("USEFUL LINKS", 18, Color("#d6f4ee"))
    link_side.add_child(link_title)
    links_list = ItemList.new()
    links_list.custom_minimum_size = Vector2(335, 295)
    links_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    links_list.item_selected.connect(_on_link_selected)
    link_side.add_child(links_list)
    link_note_label = _make_label("", 13, Color("#b4dbdc"))
    link_note_label.custom_minimum_size.y = 50
    link_side.add_child(link_note_label)
    open_link_button = _make_button("Open in browser", _open_selected_link)
    link_side.add_child(open_link_button)

    for item in links:
        links_list.add_item(str(item.get("label_en", "?")))
    if not links.is_empty():
        links_list.select(0)
        active_link_index = 0


func _refresh_language(_language: String) -> void:
    if title_label == null:
        return
    title_label.text = _tr("校园 AI · 联网与链接", "CAMPUS AI · ONLINE & LINKS")
    close_button.text = _tr("关闭 [F8]", "Close [F8]")
    note_label.text = _tr(
        "纯娱乐游戏。使用外部服务前请核实答案；网页在浏览器打开。",
        "Unofficial comedy game. Verify AI answers; links open in your browser."
    )
    prompt_input.placeholder_text = _tr("手动输入问题（最多 1200 字）", "Type a question (max 1200 characters)")
    send_button.text = _tr("发送", "Send")
    clear_button.text = _tr("清空", "Clear")
    status_button.text = _tr("连接", "Connection")
    weather_button.text = _tr("天气", "Weather")
    privacy_label.text = _tr(
        "仅点击发送才上传你输入的对话；需本地代理与自备 API Key，可能计费。不读取游戏账号/存档。",
        "Only submitted chat text goes to your provider. Local bridge + your own API key required; charges may apply. No game account/saves shared."
    )
    open_link_button.text = _tr("浏览器打开链接", "Open in browser")
    for index in range(links.size()):
        links_list.set_item_text(index, str(links[index].get("label_zh" if _zh() else "label_en", "?")))
    _on_link_selected(active_link_index)
    _show_transcript()


func open_hub() -> void:
    show()
    if status_label.text.is_empty():
        status_label.text = _tr(
            "AI 默认关闭；可先检查连接。也可只使用左/右侧网页链接。",
            "AI is off until you start the local bridge; links work independently."
        )


func close_hub() -> void:
    hide()


func clear_session() -> void:
    # Called also on logout: no previous player's transcript can leak to the next.
    if web_request != null and pending_kind != "":
        web_request.cancel_request()
    pending_kind = ""
    pending_user_message = ""
    pending_provider = ""
    chat_history.clear()
    if prompt_input != null:
        prompt_input.clear()
    if status_label != null:
        status_label.text = ""
    _show_transcript()
    _set_busy(false)


func _show_transcript() -> void:
    if transcript == null:
        return
    if chat_history.is_empty():
        transcript.text = _tr(
            "校园 AI 助手\n\n请先在本机启动可选代理，然后选择 GPT / Gemini / Claude 并提问。\n\n不会自动读取当前学院、邮箱、XP 或 NPC 资料。",
            "Campus AI Buddy\n\nStart the optional local bridge, choose GPT / Gemini / Claude and ask a question.\n\nNo automatic access to your faculty, mailbox, XP or NPC data."
        )
        return
    var lines: PackedStringArray = PackedStringArray()
    for entry in chat_history:
        var label: String = _tr("你", "YOU") if str(entry.get("role", "")) == "user" else "AI"
        lines.append(label + ": " + str(entry.get("content", "")))
    transcript.text = "\n\n".join(lines)
    transcript.scroll_vertical = transcript.get_line_count()


func _on_link_selected(index: int) -> void:
    active_link_index = index
    if link_note_label == null:
        return
    if index < 0 or index >= links.size():
        link_note_label.text = ""
        open_link_button.disabled = true
        return
    link_note_label.text = str(links[index].get("note_zh" if _zh() else "note_en", ""))
    open_link_button.disabled = false


func _open_selected_link() -> void:
    if active_link_index < 0 or active_link_index >= links.size():
        return
    var target: String = str(links[active_link_index].get("url", ""))
    if not is_allowlisted_url(target):
        status_label.text = _tr("这个网址不在允许列表中。", "This URL is not allowlisted.")
        return
    var result: Error = OS.shell_open(target)
    if result != OK:
        status_label.text = _tr("无法打开浏览器：", "Could not open browser: ") + str(result)


func _set_busy(busy: bool) -> void:
    for button in [send_button, clear_button, status_button, weather_button]:
        if button != null:
            button.disabled = busy


func _start_request(kind: String, path: String, body: String = "") -> void:
    if pending_kind != "" or web_request == null:
        return
    var headers: PackedStringArray = PackedStringArray()
    var method: HTTPClient.Method = HTTPClient.METHOD_GET
    if kind == "chat":
        method = HTTPClient.METHOD_POST
        headers.append("Content-Type: application/json")
    pending_kind = kind
    _set_busy(true)
    status_label.text = _tr("正在连接本地服务…", "Contacting local bridge…")
    var result: Error = web_request.request(BRIDGE_URL + path, headers, method, body)
    if result != OK:
        pending_kind = ""
        _set_busy(false)
        status_label.text = _tr(
            "本地服务未启动。请先运行 python tools/campus_ai_proxy.py",
            "Local bridge unavailable. Start: python tools/campus_ai_proxy.py"
        )


func _send_chat() -> void:
    if pending_kind != "":
        return
    var message: String = prompt_input.text.strip_edges()
    if message.is_empty() or message.length() > MAX_PROMPT_CHARS:
        status_label.text = _tr("请输入 1–1200 字。", "Enter 1–1200 characters.")
        return
    var provider: String = str(provider_picker.get_selected_metadata())
    if provider not in ["openai", "gemini", "claude"]:
        return
    pending_user_message = message
    pending_provider = provider
    var body: String = JSON.stringify({
        "provider": provider,
        "message": message,
        "history": chat_history.slice(maxi(0, chat_history.size() - MAX_HISTORY_ITEMS)),
    })
    _start_request("chat", "/v1/chat", body)


func _check_connection() -> void:
    _start_request("status", "/v1/status")


func _check_weather() -> void:
    _start_request("weather", "/v1/weather")


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    var kind: String = pending_kind
    pending_kind = ""
    _set_busy(false)
    if kind.is_empty():
        return
    if result != HTTPRequest.RESULT_SUCCESS:
        status_label.text = _tr(
            "连接失败：确认本地代理已启动，或稍后重试。",
            "Connection failed. Start the local bridge or retry."
        )
        return
    var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
    if typeof(parsed) != TYPE_DICTIONARY:
        status_label.text = _tr("服务返回了无效 JSON。", "Bridge returned invalid JSON.")
        return
    var payload: Dictionary = parsed
    if code != 200:
        status_label.text = str(payload.get("error", "HTTP " + str(code)))
        return
    if kind == "chat":
        var answer: String = str(payload.get("reply", "")).strip_edges()
        if answer.is_empty():
            status_label.text = _tr("AI 返回了空文本。", "AI returned an empty reply.")
            return
        chat_history.append({"role": "user", "content": pending_user_message})
        chat_history.append({"role": "assistant", "content": answer.left(5000)})
        while chat_history.size() > MAX_HISTORY_ITEMS:
            chat_history.pop_front()
        prompt_input.clear()
        _show_transcript()
        status_label.text = _tr("来自 ", "From ") + pending_provider + _tr("（仅当前游戏会话）", " (current session only)")
    elif kind == "status":
        var configured: Dictionary = payload.get("providers", {})
        var provider_names: PackedStringArray = PackedStringArray()
        for name in ["openai", "gemini", "claude"]:
            if bool(configured.get(name, false)):
                provider_names.append(name)
        if provider_names.is_empty():
            status_label.text = _tr("代理已连接，但尚未配置任何 AI Key。", "Local bridge online; no AI keys configured.")
        else:
            status_label.text = _tr("代理已连接：", "Bridge online: ") + ", ".join(provider_names)
    elif kind == "weather":
        status_label.text = _tr("NUS 附近实时参考天气：", "Weather near NUS (reference): ") + \
            str(payload.get("temperature_2m", "?")) + " °C  |  " + \
            str(payload.get("relative_humidity_2m", "?")) + "%  |  " + \
            str(payload.get("precipitation", "?")) + " mm"
