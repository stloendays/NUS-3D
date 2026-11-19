extends Control
class_name NUS3DAdminConsole
## Local owner tools: no arbitrary command runner, API access, RPC or shared save edits.

signal close_requested

var authority: NUS3DAdminAuthority
var language: NUS3DGameLanguage
var heading: Label
var hint: Label
var auth_message: Label
var password_field: LineEdit
var auth_button: Button
var login_box: VBoxContainer
var tools_box: VBoxContainer
var weather_picker: OptionButton
var light_picker: OptionButton
var checkpoint_picker: OptionButton
var xp_spin: SpinBox
var coin_spin: SpinBox
var message: Label
var activity: TextEdit
var confirm: ConfirmationDialog
var pending_action: String = ""
var pending_value: int = 0
var ai_request: HTTPRequest
var ai_input: LineEdit
var ai_button: Button
var ai_pending: bool = false


func setup(service: NUS3DAdminAuthority) -> void:
    authority = service
    _refresh_auth_state()


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    language = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage
    _build()
    if language != null:
        language.language_changed.connect(_language_changed)
    _language_changed("")
    hide()


func _t(zh: String, en: String) -> String:
    return zh if language != null and language.is_chinese() else en


func _label(value: String, font_size: int = 14) -> Label:
    var result: Label = Label.new()
    result.text = value
    result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result.add_theme_font_size_override("font_size", font_size)
    return result


func _button(value: String, action: Callable) -> Button:
    var result: Button = Button.new()
    result.text = value
    result.custom_minimum_size.y = 37
    result.pressed.connect(action)
    return result


func _build() -> void:
    var backdrop: ColorRect = ColorRect.new()
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.color = Color(0.018, 0.033, 0.05, 0.92)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(backdrop)

    var center: CenterContainer = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(center)
    var panel: PanelContainer = PanelContainer.new()
    panel.custom_minimum_size = Vector2(850, 620)
    var skin: StyleBoxFlat = StyleBoxFlat.new()
    skin.bg_color = Color("#16232c")
    skin.border_color = Color("#a5b4bf")
    skin.set_border_width_all(1)
    skin.set_corner_radius_all(14)
    skin.set_content_margin_all(22)
    panel.add_theme_stylebox_override("panel", skin)
    center.add_child(panel)

    var layout: VBoxContainer = VBoxContainer.new()
    layout.add_theme_constant_override("separation", 11)
    panel.add_child(layout)
    var top: HBoxContainer = HBoxContainer.new()
    layout.add_child(top)
    heading = _label("CAMPUS CONTROL", 25)
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top.add_child(heading)
    top.add_child(_button("Close [F12]", func() -> void: close_requested.emit()))
    hint = _label("", 12)
    layout.add_child(hint)

    login_box = VBoxContainer.new()
    login_box.add_theme_constant_override("separation", 9)
    layout.add_child(login_box)
    login_box.add_child(_label("OWNER AUTHORIZATION", 18))
    password_field = LineEdit.new()
    password_field.secret = true
    password_field.max_length = 128
    password_field.placeholder_text = "Local owner password (12+ characters)"
    password_field.text_submitted.connect(func(_text: String) -> void: _authenticate())
    login_box.add_child(password_field)
    auth_button = _button("Unlock", _authenticate)
    login_box.add_child(auth_button)
    auth_message = _label("", 13)
    login_box.add_child(auth_message)

    tools_box = VBoxContainer.new()
    tools_box.add_theme_constant_override("separation", 9)
    layout.add_child(tools_box)
    var controls: HBoxContainer = HBoxContainer.new()
    controls.add_theme_constant_override("separation", 14)
    tools_box.add_child(controls)

    var environment: VBoxContainer = VBoxContainer.new()
    environment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    controls.add_child(environment)
    environment.add_child(_label("WEATHER", 15))
    weather_picker = OptionButton.new()
    for name in ["Clear", "Cloudy", "Overcast", "Rain", "Storm"]:
        weather_picker.add_item(name)
    environment.add_child(weather_picker)
    environment.add_child(_button("Apply weather", func() -> void: _perform("weather", weather_picker.selected)))
    environment.add_child(_label("LIGHTING", 15))
    light_picker = OptionButton.new()
    for name in ["Daylight", "Golden hour", "Blue hour", "Evening"]:
        light_picker.add_item(name)
    environment.add_child(light_picker)
    environment.add_child(_button("Apply lighting", func() -> void: _perform("lighting", light_picker.selected)))
    environment.add_child(_button("Reset atmosphere", func() -> void: _perform("restore_atmosphere", 0)))

    var economy: VBoxContainer = VBoxContainer.new()
    economy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    controls.add_child(economy)
    economy.add_child(_label("CURRENT LOCAL PROFILE", 15))
    economy.add_child(_label("XP grant (1-5000)"))
    xp_spin = SpinBox.new()
    xp_spin.min_value = 1
    xp_spin.max_value = 5000
    xp_spin.step = 1
    xp_spin.value = 100
    economy.add_child(xp_spin)
    economy.add_child(_button("Grant XP", func() -> void: _request_grant("grant_xp", int(xp_spin.value))))
    economy.add_child(_label("Coin grant (1-5000)"))
    coin_spin = SpinBox.new()
    coin_spin.min_value = 1
    coin_spin.max_value = 5000
    coin_spin.step = 1
    coin_spin.value = 100
    economy.add_child(coin_spin)
    economy.add_child(_button("Grant coins", func() -> void: _request_grant("grant_coins", int(coin_spin.value))))

    var teleport: VBoxContainer = VBoxContainer.new()
    teleport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    controls.add_child(teleport)
    teleport.add_child(_label("SAFE CHECKPOINTS", 15))
    checkpoint_picker = OptionButton.new()
    for name in ["Town Green", "ERC", "SRC", "Town Plaza"]:
        checkpoint_picker.add_item(name)
    teleport.add_child(checkpoint_picker)
    teleport.add_child(_button("Teleport", func() -> void: _perform("teleport", checkpoint_picker.selected)))
    teleport.add_child(_label("Only predefined game checkpoints. No arbitrary coordinates.", 12))
    teleport.add_child(_button("Lock admin controls", _lock_now))

    tools_box.add_child(_label("OPTIONAL GPT PROPOSAL · REVIEW BEFORE APPLYING", 13))
    var ai_row: HBoxContainer = HBoxContainer.new()
    tools_box.add_child(ai_row)
    ai_input = LineEdit.new()
    ai_input.max_length = 300
    ai_input.placeholder_text = "e.g. Make it rainy, set dusk or add 300 coins"
    ai_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ai_row.add_child(ai_input)
    ai_button = _button("Suggest with GPT", _request_ai_proposal)
    ai_row.add_child(ai_button)

    message = _label("", 13)
    tools_box.add_child(message)
    tools_box.add_child(_label("RECENT LOCAL CHANGES", 14))
    activity = TextEdit.new()
    activity.editable = false
    activity.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    activity.custom_minimum_size.y = 108
    activity.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tools_box.add_child(activity)

    confirm = ConfirmationDialog.new()
    confirm.title = "Confirm local save adjustment"
    confirm.confirmed.connect(_confirm_grant)
    add_child(confirm)
    ai_request = HTTPRequest.new()
    ai_request.timeout = 22.0
    ai_request.body_size_limit = 32768
    ai_request.max_redirects = 0
    add_child(ai_request)
    ai_request.request_completed.connect(_on_ai_response)
    tools_box.hide()


func _language_changed(_locale: String) -> void:
    if heading == null:
        return
    heading.text = _t("校园管理员控制台  [F12]", "CAMPUS ADMIN CONSOLE  [F12]")
    hint.text = _t(
        "只管理本机当前账户与离线世界。没有默认管理员、网络远程权限或任意命令执行。",
        "Local profile and offline world only. No default admin, remote access or command execution."
    )
    password_field.placeholder_text = _t("输入本机管理员密码（至少12字符）", "Enter local owner password (12+ characters)")
    ai_input.placeholder_text = _t("例如：下雨、切到黄昏、给我增加300金币", "e.g. Make it rainy, set dusk or add 300 coins")
    ai_button.text = _t("让 GPT 提方案", "Suggest with GPT")
    _refresh_auth_state()


func open_console() -> void:
    if authority == null:
        return
    authority.lock()
    password_field.clear()
    auth_message.text = ""
    message.text = ""
    show()
    _refresh_auth_state()


func close_console() -> void:
    if ai_pending and ai_request != null:
        ai_request.cancel_request()
    ai_pending = false
    if ai_button != null:
        ai_button.disabled = false
    if ai_input != null:
        ai_input.clear()
    hide()
    if confirm != null:
        confirm.hide()
    if authority != null:
        authority.lock()
    password_field.clear()
    pending_action = ""
    pending_value = 0


func _refresh_auth_state() -> void:
    if authority == null or login_box == null:
        return
    var privileged: bool = authority.is_unlocked()
    login_box.visible = not privileged
    tools_box.visible = privileged
    password_field.editable = authority.is_current_owner() or not authority.has_owner()
    auth_button.disabled = not password_field.editable
    auth_button.text = _t("创建本机管理员", "Enroll local owner") if not authority.has_owner() else _t("解锁控制台", "Unlock console")
    if not authority.has_owner():
        auth_message.text = _t(
            "首次设置：先在启动游戏的终端中配置 NUS3D_ADMIN_BOOTSTRAP_PASSWORD，再用相同密码授权当前账户。",
            "First setup: set NUS3D_ADMIN_BOOTSTRAP_PASSWORD in the game launch terminal, then enter it here."
        )
    elif not authority.is_current_owner():
        auth_message.text = _t("当前账户不是本机管理员。", "This signed-in account is not the local owner.")
    if privileged:
        _refresh_logs()


func _authenticate() -> void:
    if authority == null:
        return
    var reason: String = authority.unlock(password_field.text) if authority.has_owner() else authority.bootstrap_owner(password_field.text)
    password_field.clear()
    if not reason.is_empty():
        auth_message.text = reason
        return
    _refresh_auth_state()
    message.text = _t("管理员权限已激活，仅限此控制台会话。", "Owner tools unlocked for this panel session.")



static func validate_ai_proposal(raw: String) -> Dictionary:
    # Untrusted LLM output. Fail closed on any unexpected action or value.
    if raw.length() > 1800:
        return {}
    var parsed: Variant = JSON.parse_string(raw.strip_edges())
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    var item: Dictionary = parsed
    var action: String = str(item.get("action", ""))
    var raw_value: Variant = item.get("value", -999)
    if typeof(raw_value) != TYPE_INT:
        return {}
    var value: int = int(raw_value)
    var limits: Dictionary = {
        "weather": [0, 4],
        "lighting": [0, 3],
        "teleport": [0, 3],
        "grant_xp": [1, 5000],
        "grant_coins": [1, 5000],
        "restore_atmosphere": [0, 0]
    }
    if not limits.has(action):
        return {}
    var bounds: Array = limits[action]
    if value < int(bounds[0]) or value > int(bounds[1]):
        return {}
    var reason: String = str(item.get("reason", "")).strip_edges().substr(0, 150)
    reason = reason.replace("\n", " ").replace("\r", " ")
    return {"action": action, "value": value, "reason": reason}


func _request_ai_proposal() -> void:
    if authority == null or not authority.is_unlocked() or ai_pending:
        return
    if not authority._offline_game():
        message.text = _t("联机状态不能使用游戏修改建议。", "Game changes are disabled in multiplayer.")
        return
    var prompt_text: String = ai_input.text.strip_edges()
    if prompt_text.length() < 1 or prompt_text.length() > 300:
        message.text = _t("请输入 1–300 个字符。", "Enter 1–300 characters.")
        return
    # Never submit account identity, passwords, saves or location.
    var request_json: String = JSON.stringify({
        "provider": "openai",
        "mode": "admin_plan",
        "prompt": prompt_text,
        "history": []
    })
    var err: Error = ai_request.request(
        "http://127.0.0.1:8765/v1/chat",
        PackedStringArray(["Content-Type: application/json", "X-NUS3D-Game: 1"]),
        HTTPClient.METHOD_POST,
        request_json
    )
    if err != OK:
        message.text = _t(
            "本地 AI 服务未运行。可继续使用手动控制。",
            "Local GPT bridge is not running. Manual controls remain available."
        )
        return
    ai_pending = true
    ai_button.disabled = true
    message.text = _t("GPT 正在生成建议；不会自动修改游戏。", "GPT is preparing a proposal; no game changes will run automatically.")


func _on_ai_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if not ai_pending:
        return
    ai_pending = false
    ai_button.disabled = false
    if not visible or authority == null or not authority.is_unlocked():
        return
    if result != HTTPRequest.RESULT_SUCCESS or code != 200:
        message.text = _t(
            "GPT 暂时不可用，请检查本地服务和 API Key。",
            "GPT unavailable; check local bridge and API key."
        )
        return
    var response: Variant = JSON.parse_string(body.get_string_from_utf8())
    if typeof(response) != TYPE_DICTIONARY:
        message.text = _t("GPT 响应格式无效。", "Invalid GPT response.")
        return
    var reply: String = str(response.get("reply", ""))
    if not _prepare_ai_proposal(reply):
        message.text = _t(
            "GPT 建议不在允许的操作范围内，已拒绝。不会执行修改。",
            "Unrecognized or unsafe GPT proposal rejected without applying changes."
        )


func _prepare_ai_proposal(raw_reply: String) -> bool:
    if authority == null or not authority.is_unlocked():
        return false
    var proposal: Dictionary = validate_ai_proposal(raw_reply)
    if proposal.is_empty():
        return false
    pending_action = str(proposal["action"])
    pending_value = int(proposal["value"])
    var reason: String = str(proposal["reason"])
    confirm.dialog_text = _t(
        "GPT 仅提出建议，尚未执行。\n操作：%s  参数：%d\n理由：%s\n确认后才修改游戏并写入审计记录。" % [pending_action, pending_value, reason],
        "GPT PROPOSAL ONLY — not executed.\nAction: %s  Value: %d\nReason: %s\nApply only after your explicit confirmation; the result is audited." % [pending_action, pending_value, reason]
    )
    confirm.popup_centered()
    return true

func _request_grant(action: String, amount: int) -> void:
    if authority == null or not authority.is_unlocked():
        return
    pending_action = action
    pending_value = amount
    confirm.dialog_text = _t(
        "确认为当前本地账户增加 %d %s？此操作会写入存档与审计记录，不能直接撤销。" % [amount, "经验" if action == "grant_xp" else "金币"],
        "Grant %d %s to the current local account? This changes the save and is audited; no automatic undo." % [amount, "XP" if action == "grant_xp" else "coins"]
    )
    confirm.popup_centered()


func _confirm_grant() -> void:
    if pending_action in ["grant_xp", "grant_coins", "weather", "lighting", "restore_atmosphere", "teleport"]:
        _perform(pending_action, pending_value)
    pending_action = ""
    pending_value = 0


func _perform(action: String, amount: int) -> void:
    if authority == null:
        return
    var reason: String = authority.apply(action, amount)
    if not reason.is_empty():
        message.text = reason
        return
    message.text = _t("修改成功，已记录。", "Change applied and added to the local audit.")
    _refresh_logs()


func _lock_now() -> void:
    if authority != null:
        authority.lock()
    _refresh_auth_state()


func _refresh_logs() -> void:
    if activity == null or authority == null:
        return
    var lines: PackedStringArray = PackedStringArray()
    var entries: Array = authority.recent_actions()
    for index in range(entries.size() - 1, maxi(-1, entries.size() - 13), -1):
        var row: Dictionary = entries[index]
        lines.append("%s  |  %s  |  %s -> %s" % [
            str(row.get("time_utc", "?")), str(row.get("action", "?")),
            str(row.get("before", "?")), str(row.get("after", "?"))
        ])
    activity.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
    if not visible or not (event is InputEventKey):
        return
    var key: InputEventKey = event as InputEventKey
    if key.pressed and not key.echo and key.keycode == KEY_ESCAPE and not confirm.visible:
        close_requested.emit()
        get_viewport().set_input_as_handled()
