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
    panel.custom_minimum_size = Vector2(800, 560)
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
    if pending_action in ["grant_xp", "grant_coins"]:
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
