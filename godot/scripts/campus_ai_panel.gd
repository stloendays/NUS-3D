extends CanvasLayer
class_name NUS3DCampusAI
## Optional online campus toolkit. All actions require a player click or F8.
## Never receives local usernames, passwords, XP, coursework saves or mailbox data.

const LINK_FILE: String = "res://data/campus_links.json"
const CHAT_URL: String = "http://127.0.0.1:8765/v1/chat"
const WEATHER_URL: String = "https://api.open-meteo.com/v1/forecast?latitude=1.3050&longitude=103.7732&current=temperature_2m,relative_humidity_2m,weather_code&timezone=Asia%2FSingapore"
const MAX_PROMPT: int = 900
const MAX_HISTORY: int = 6
const MAX_DISPLAY: int = 7200
const ALLOWED_HOSTS: Array[String] = [
    "chatgpt.com", "claude.ai", "gemini.google.com", "www.perplexity.ai",
    "developers.openai.com", "map.nus.edu.sg", "uci.nus.edu.sg",
    "nusmods.com", "www.nus.edu.sg", "github.com"
]

var language_service: NUS3DGameLanguage
var was_paused: bool = false
var request_active: bool = false
var links: Array[Dictionary] = []
var conversation: Array[Dictionary] = []

var panel_title: Label
var privacy_note: Label
var prompt_box: TextEdit
var chat_log: RichTextLabel
var chat_status: Label
var provider_box: OptionButton
var mode_box: OptionButton
var send_button: Button
var links_box: ItemList
var link_note: Label
var link_button: Button
var weather_button: Button
var weather_status: Label
var close_button: Button
var section_links: Label
var section_chat: Label
var section_weather: Label
var chat_request: HTTPRequest
var weather_request: HTTPRequest


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    layer = 45
    language_service = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage
    _load_links()
    _build_ui()
    chat_request = HTTPRequest.new()
    chat_request.timeout = 22.0
    chat_request.body_size_limit = 65536
    add_child(chat_request)
    chat_request.request_completed.connect(_on_chat_response)
    weather_request = HTTPRequest.new()
    weather_request.timeout = 12.0
    weather_request.body_size_limit = 16384
    add_child(weather_request)
    weather_request.request_completed.connect(_on_weather_response)
    if language_service != null:
        language_service.language_changed.connect(_on_language_changed)
    _on_language_changed("")
    hide()


func _t(zh: String, en: String) -> String:
    if language_service != null and language_service.is_chinese():
        return zh
    return en


func _button(text_value: String, callback: Callable) -> Button:
    var result: Button = Button.new()
    result.text = text_value
    result.custom_minimum_size.y = 35
    result.pressed.connect(callback)
    return result


func _label(value: String, font_size: int = 15) -> Label:
    var result: Label = Label.new()
    result.text = value
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result.add_theme_font_size_override("font_size", font_size)
    return result


func _build_ui() -> void:
    var cover: ColorRect = ColorRect.new()
    cover.name = "Backdrop"
    cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cover.color = Color(0.02, 0.06, 0.10, 0.94)
    cover.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(cover)

    var center: CenterContainer = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cover.add_child(center)

    var card: PanelContainer = PanelContainer.new()
    card.custom_minimum_size = Vector2(975, 605)
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color("#102633")
    style.border_color = Color("#4e8b98")
    style.set_border_width_all(2)
    style.set_corner_radius_all(17)
    style.set_content_margin_all(19)
    card.add_theme_stylebox_override("panel", style)
    center.add_child(card)

    var vertical: VBoxContainer = VBoxContainer.new()
    vertical.add_theme_constant_override("separation", 10)
    card.add_child(vertical)
    var head: HBoxContainer = HBoxContainer.new()
    vertical.add_child(head)
    panel_title = _label("CAMPUS AI  /  ONLINE TOOLS", 25)
    panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    head.add_child(panel_title)
    close_button = _button("Close [F8]", close_panel)
    head.add_child(close_button)
    privacy_note = _label("", 12)
    vertical.add_child(privacy_note)

    var columns: HBoxContainer = HBoxContainer.new()
    columns.add_theme_constant_override("separation", 18)
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vertical.add_child(columns)

    var left: VBoxContainer = VBoxContainer.new()
    left.custom_minimum_size.x = 333
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(left)
    section_links = _label("Web links", 19)
    left.add_child(section_links)
    links_box = ItemList.new()
    links_box.custom_minimum_size = Vector2(324, 283)
    links_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
    links_box.item_selected.connect(_on_link_selected)
    left.add_child(links_box)
    link_note = _label("", 12)
    link_note.custom_minimum_size.y = 53
    left.add_child(link_note)
    link_button = _button("Open selected website", _open_link)
    left.add_child(link_button)
    section_weather = _label("Singapore weather", 19)
    left.add_child(section_weather)
    weather_button = _button("Fetch current weather", _fetch_weather)
    left.add_child(weather_button)
    weather_status = _label("", 13)
    weather_status.custom_minimum_size.y = 55
    left.add_child(weather_status)

    var right: VBoxContainer = VBoxContainer.new()
    right.custom_minimum_size.x = 540
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    columns.add_child(right)
    section_chat = _label("Ask AI (optional)", 19)
    right.add_child(section_chat)
    var selectors: HBoxContainer = HBoxContainer.new()
    selectors.add_theme_constant_override("separation", 8)
    right.add_child(selectors)
    provider_box = OptionButton.new()
    provider_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for name in ["Offline demo", "OpenAI GPT", "Google Gemini", "Anthropic Claude"]:
        provider_box.add_item(name)
    selectors.add_child(provider_box)
    mode_box = OptionButton.new()
    mode_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    for name in ["Campus helper", "Study coach", "Funny NPC"]:
        mode_box.add_item(name)
    selectors.add_child(mode_box)
    chat_log = RichTextLabel.new()
    chat_log.bbcode_enabled = false
    chat_log.scroll_following = true
    chat_log.custom_minimum_size.y = 232
    chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right.add_child(chat_log)
    prompt_box = TextEdit.new()
    prompt_box.custom_minimum_size.y = 105
    prompt_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    right.add_child(prompt_box)
    var actions: HBoxContainer = HBoxContainer.new()
    right.add_child(actions)
    send_button = _button("Ask AI", _submit_chat)
    send_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    actions.add_child(send_button)
    actions.add_child(_button("Clear", _clear_chat))
    chat_status = _label("", 12)
    chat_status.custom_minimum_size.y = 36
    right.add_child(chat_status)

    _refresh_links()


func _load_links() -> void:
    links.clear()
    if not FileAccess.file_exists(LINK_FILE):
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LINK_FILE))
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var catalog: Dictionary = parsed
    for entry in catalog.get("links", []):
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var link: Dictionary = entry
        if _approved_link(str(link.get("url", ""))):
            links.append(link)


func _approved_link(url: String) -> bool:
    # External URLs are allowlisted; game data cannot silently create a file:// URL.
    for host in ALLOWED_HOSTS:
        var prefix: String = "https://" + host
        if url == prefix or url == prefix + "/" or url.begins_with(prefix + "/"):
            return true
    return false


func _refresh_links() -> void:
    if links_box == null:
        return
    var chosen: int = links_box.get_selected_items()[0] if not links_box.get_selected_items().is_empty() else 0
    links_box.clear()
    for item in links:
        var group: String = str(item.get("group", "dev")).to_upper()
        var name: String = str(item.get("label_zh", "")) if _t("zh", "en") == "zh" else str(item.get("label_en", ""))
        links_box.add_item("[%s] %s" % [group, name])
    if links.size() > 0:
        links_box.select(clampi(chosen, 0, links.size() - 1))
    _on_link_selected(links_box.get_selected_items()[0] if not links_box.get_selected_items().is_empty() else -1)


func _on_link_selected(index: int) -> void:
    link_button.disabled = index < 0 or index >= links.size()
    if link_button.disabled:
        link_note.text = _t("没有可用的外部链接。", "No external links available.")
        return
    var entry: Dictionary = links[index]
    link_note.text = str(entry.get("note_zh", "")) if _t("zh", "en") == "zh" else str(entry.get("note_en", ""))


func _open_link() -> void:
    var selected: PackedInt32Array = links_box.get_selected_items()
    if selected.is_empty() or selected[0] >= links.size():
        return
    var url: String = str(links[selected[0]].get("url", ""))
    if not _approved_link(url):
        chat_status.text = _t("拦截了未批准的链接。", "Blocked an unapproved URL.")
        return
    var err: Error = OS.shell_open(url)
    if err != OK:
        chat_status.text = _t("无法打开系统浏览器。", "Cannot open the default browser.")


func _provider() -> String:
    match provider_box.selected:
        1: return "openai"
        2: return "gemini"
        3: return "anthropic"
        _: return "demo"


func _mode() -> String:
    match mode_box.selected:
        1: return "coursework"
        2: return "comedy"
        _: return "general"


func _append_line(line: String) -> void:
    chat_log.text = (chat_log.text + line + "\n\n").right(MAX_DISPLAY)
    chat_log.scroll_to_line(chat_log.get_line_count())


func _clear_chat() -> void:
    if request_active:
        return
    conversation.clear()
    chat_log.clear()
    chat_status.text = _t("当前会话已清空，不涉及游戏存档。", "Session cleared; game saves unchanged.")


func _offline_reply(text_value: String) -> String:
    var short_text: String = text_value.substr(0, 80)
    if _mode() == "comedy":
        return _t("你的问题「%s」已经被小组队友标记为：下个学期再讨论。DDL 不批准。", "Your question '%s' has been assigned to the groupmate who vanished before the DDL.") % short_text
    if _mode() == "coursework":
        return _t("离线学习模式：先明确题目要求，再列出你已知的证据和下一步操作。要调用真实 AI，请先运行本地桥接服务。", "Offline study tip: identify the task, list known evidence and write the next step. Start the local bridge for real AI.")
    return _t("离线模式：目前只有固定回复。想调用 GPT、Gemini 或 Claude，请在电脑上运行本地 AI 桥接服务。", "Offline mode uses a fixed reply. Start the local AI bridge for GPT, Gemini or Claude.")


func _submit_chat() -> void:
    if request_active:
        return
    var prompt_text: String = prompt_box.text.strip_edges()
    if prompt_text.is_empty() or prompt_text.length() > MAX_PROMPT:
        chat_status.text = _t("请输入 1–900 个字符。", "Enter between 1 and 900 characters.")
        return
    if _provider() == "demo":
        _append_line(_t("你：", "You: ") + prompt_text)
        _append_line(_t("校园助手：", "Campus helper: ") + _offline_reply(prompt_text))
        prompt_box.clear()
        chat_status.text = _t("本地示例；没有网络请求。", "Offline demo; no network request.")
        return
    var history: Array = conversation.slice(maxi(0, conversation.size() - MAX_HISTORY))
    var payload: Dictionary = {
        "provider": _provider(),
        "mode": _mode(),
        "prompt": prompt_text,
        "history": history
    }
    var err: Error = chat_request.request(
        CHAT_URL, PackedStringArray(["Content-Type: application/json", "X-NUS3D-Game: 1"]),
        HTTPClient.METHOD_POST, JSON.stringify(payload))
    if err != OK:
        chat_status.text = _t("本地桥接服务不可用，请运行 Python 服务。", "Local AI bridge unavailable. Start the Python service.")
        return
    request_active = true
    send_button.disabled = true
    conversation.append({"role": "user", "content": prompt_text})
    _append_line(_t("你：", "You: ") + prompt_text)
    prompt_box.clear()
    chat_status.text = _t("正在请求本地 AI 桥接服务…", "Contacting the local AI bridge...")


func _on_chat_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    request_active = false
    send_button.disabled = false
    if result != HTTPRequest.RESULT_SUCCESS:
        chat_status.text = _t("无法连接 127.0.0.1:8765。检查桥接程序。", "Cannot reach 127.0.0.1:8765. Check the bridge.")
        return
    var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
    if typeof(parsed) != TYPE_DICTIONARY:
        chat_status.text = _t("AI 响应不是预期 JSON 格式。", "Invalid response from local bridge.")
        return
    var data: Dictionary = parsed
    if code != 200:
        chat_status.text = _t("AI 暂不可用：", "AI unavailable: ") + str(data.get("error", "HTTP " + str(code))).substr(0, 140)
        return
    var reply: String = str(data.get("reply", "")).substr(0, 2400)
    if reply.is_empty():
        chat_status.text = _t("AI 返回了空答案。", "AI returned an empty answer.")
        return
    conversation.append({"role": "assistant", "content": reply})
    if conversation.size() > MAX_HISTORY:
        conversation = conversation.slice(conversation.size() - MAX_HISTORY)
    _append_line(str(data.get("provider", "AI")).to_upper() + ": " + reply)
    chat_status.text = _t("回复已送达，仅保留本次打开游戏的会话。", "Reply received; chat is not saved to disk.")


func _fetch_weather() -> void:
    if weather_button.disabled:
        return
    weather_button.disabled = true
    weather_status.text = _t("正在查询 UTown 附近公开天气…", "Fetching public weather for UTown...")
    var err: Error = weather_request.request(WEATHER_URL, PackedStringArray(), HTTPClient.METHOD_GET)
    if err != OK:
        weather_button.disabled = false
        weather_status.text = _t("无法开始天气请求。", "Weather request could not start.")


func _on_weather_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    weather_button.disabled = false
    if result != HTTPRequest.RESULT_SUCCESS or code != 200:
        weather_status.text = _t("天气离线或暂不可用。", "Weather API is offline or unavailable.")
        return
    var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
    if typeof(parsed) != TYPE_DICTIONARY:
        weather_status.text = _t("天气数据格式异常。", "Unexpected weather response.")
        return
    var live: Dictionary = parsed.get("current", {})
    if not live.has("temperature_2m"):
        weather_status.text = _t("天气数据缺少当前温度。", "Weather report is missing temperature.")
        return
    var temp: float = float(live.get("temperature_2m", 0))
    var humidity: float = float(live.get("relative_humidity_2m", 0))
    weather_status.text = _t("UTown 附近约 %.1f°C，湿度 %.0f%%。真实天气，不修改游戏天气。", "Near UTown: %.1f°C, humidity %.0f%%. Live report; game weather unchanged.") % [temp, humidity]


func open_panel() -> void:
    if visible:
        return
    was_paused = get_tree().paused
    show()
    get_tree().paused = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_panel() -> void:
    if not visible:
        return
    hide()
    get_tree().paused = was_paused
    if not get_tree().paused:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func force_close() -> void:
    # Called before logout; never accidentally unpause a login screen.
    hide()
    get_tree().paused = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_language_changed(_locale: String) -> void:
    if panel_title == null:
        return
    panel_title.text = _t("CAMPUS AI  /  校园联网工具", "CAMPUS AI  /  ONLINE TOOLS")
    close_button.text = _t("关闭 [F8]", "Close [F8]")
    privacy_note.text = _t("需手动发起：不上传游戏账户、邮件、成绩或存档。AI 答复可能出错。", "Manual opt-in only. No game accounts, mail, grades or saves are uploaded. AI can be wrong.")
    section_links.text = _t("外部网站与校园信息", "Websites & campus links")
    section_weather.text = _t("新加坡实时天气（Open-Meteo）", "Singapore weather (Open-Meteo)")
    section_chat.text = _t("向 AI 提问（可选）", "Ask AI (optional)")
    send_button.text = _t("发送提问", "Ask AI")
    link_button.text = _t("在浏览器打开所选链接", "Open selected website")
    weather_button.text = _t("查询当前天气", "Fetch current weather")
    prompt_box.placeholder_text = _t("写一个校园问题、让 GPT 解释概念，或让 AI 创作 NPC 笑话…", "Ask a campus question, explain a concept, or invent an NPC joke...")
    provider_box.set_item_text(0, _t("离线演示", "Offline demo"))
    mode_box.set_item_text(0, _t("校园助手", "Campus helper"))
    mode_box.set_item_text(1, _t("学业辅导", "Study coach"))
    mode_box.set_item_text(2, _t("搞笑 NPC", "Funny NPC"))
    _refresh_links()
    if weather_status.text.is_empty():
        weather_status.text = _t("点按钮才会访问外部天气 API。", "The public API is called only when you click.")
    if chat_status.text.is_empty():
        chat_status.text = _t("GPT/Gemini/Claude 需在本机启动桥接程序并设置 API Key。", "GPT/Gemini/Claude require the local bridge and your API key.")
