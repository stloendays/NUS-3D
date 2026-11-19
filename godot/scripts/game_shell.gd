extends Node
class_name NUS3DGameShell
var language_service: NUS3DGameLanguage
## Application shell: a separate login, profile and mailbox layer around main.tscn.
## The original 3D world and its hotkeys remain in their own scene.

@onready var accounts: NUS3DAccountStore = $Accounts

var game: Node3D
var tour: UTownTour
var challenge: UTownChallenge
var ui: CanvasLayer
var login_cover: Control
var mail_cover: Control
var profile_card: PanelContainer
var profile_label: Label
var login_title: Label
var login_name: LineEdit
var login_password: LineEdit
var login_message: Label
var login_submit: Button
var login_toggle: Button
var language_login_button: Button
var language_game_button: Button
var login_sound_button: Button
var profile_sound_button: Button
var mail_sound_button: Button
var _shown_level: int = 0
var login_error_source: String = ""
var mail_status_source: String = ""
var tutorial: NUS3DTutorial
var registering: bool = false
var mail_list: ItemList
var mail_heading: Label
var mail_body: TextEdit
var mail_delete: Button
var mail_status: Label
var mail_read_panel: HBoxContainer
var mail_compose_panel: VBoxContainer
var compose_to: LineEdit
var compose_subject: LineEdit
var compose_body: TextEdit
var mailbox_mode: String = "inbox"
var displayed_messages: Array = []
var selected_message_id: String = ""
var observed_tour_ids: PackedStringArray = PackedStringArray()
var observed_note_ids: PackedStringArray = PackedStringArray()
var observed_sprint_time: float = -1.0


func _ready() -> void:
    NUS3DServices.ensure_scene_services(get_tree())
    language_service = get_node_or_null("/root/GameLanguage") as NUS3DGameLanguage
    var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if scene == null:
        push_error("NUS-3D main world scene is unavailable.")
        return
    game = scene.instantiate() as Node3D
    game.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(game)
    tour = game.get_node("Tour") as UTownTour
    challenge = game.get_node("Challenge") as UTownChallenge

    # The exported EXE smoke test must run without prompting for an account.
    if OS.get_cmdline_user_args().has("--nus3d-self-test"):
        return

    ui = CanvasLayer.new()
    ui.name = "AccountInterface"
    ui.layer = 30
    ui.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(ui)
    _build_login()
    _build_profile_card()
    _build_mail()
    _build_tutorial()
    accounts.profile_changed.connect(_refresh_profile)
    accounts.mailbox_changed.connect(_on_mailbox_changed)
    language_service.language_changed.connect(_on_language_changed)
    _on_language_changed(language_service.locale)
    _show_login()


func _ui_sound_service() -> NUS3DUISound:
    return get_node_or_null("/root/UISound") as NUS3DUISound


func _play_ui_sound(effect: String) -> void:
    var sound: NUS3DUISound = _ui_sound_service()
    if sound != null:
        sound.play_ui(effect)


func _toggle_ui_sound() -> void:
    var sound: NUS3DUISound = _ui_sound_service()
    if sound != null:
        sound.toggle_enabled()
    _refresh_sound_buttons()


func _refresh_sound_buttons() -> void:
    var sound: NUS3DUISound = _ui_sound_service()
    var active: bool = sound != null and sound.enabled
    if login_sound_button != null:
        login_sound_button.text = "UI sound: ON  [F9]" if active else "UI sound: OFF  [F9]"
    if profile_sound_button != null:
        profile_sound_button.text = "Sound ON" if active else "Sound OFF"
    if mail_sound_button != null:
        mail_sound_button.text = "Sound ON" if active else "Sound OFF"


func _panel_style(background: Color) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = Color.html("#446878")
    style.set_border_width_all(1)
    style.set_corner_radius_all(15)
    style.content_margin_left = 23.0
    style.content_margin_right = 23.0
    style.content_margin_top = 22.0
    style.content_margin_bottom = 22.0
    style.shadow_color = Color(0.01, 0.035, 0.055, 0.72)
    style.shadow_size = 9
    style.shadow_offset = Vector2(0, 5)
    return style


func _label(value: String, font_size: int = 16, color: Color = Color.WHITE) -> Label:
    var label: Label = Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    return label


func _button(title: String, callback: Callable) -> Button:
    var result: Button = Button.new()
    result.text = title
    result.custom_minimum_size.y = 39.0
    NUS3DUISkin.button(result)
    result.pressed.connect(func() -> void: _play_ui_sound("press"))
    result.pressed.connect(callback)
    return result


func _cover(name: String) -> Control:
    var cover: Control = Control.new()
    cover.name = name
    cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cover.mouse_filter = Control.MOUSE_FILTER_STOP
    ui.add_child(cover)

    var backdrop: ColorRect = ColorRect.new()
    backdrop.color = Color(0.025, 0.067, 0.091, 0.91)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    cover.add_child(backdrop)
    return cover


func _center_panel(cover: Control, size: Vector2) -> VBoxContainer:
    var center: CenterContainer = CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    cover.add_child(center)
    var panel: PanelContainer = PanelContainer.new()
    panel.custom_minimum_size = size
    panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#10212c")))
    center.add_child(panel)
    var content: VBoxContainer = VBoxContainer.new()
    content.add_theme_constant_override("separation", 13)
    panel.add_child(content)
    return content


func _build_login() -> void:
    login_cover = _cover("Login")
    var box: VBoxContainer = _center_panel(login_cover, Vector2(480, 0))
    box.add_child(_label("NUS-3D", 42, Color.html("#e8f9ff")))
    box.add_child(_label("UTOWN EXPLORER  /  OFFLINE ALPHA", 14, Color.html("#75c8d6")))
    box.add_child(_label("Explore an original, unofficial campus world.", 15, Color.html("#cbdde0")))
    language_login_button = _button("中文 / English", _toggle_language)
    box.add_child(language_login_button)
    var spacer: Control = Control.new()
    spacer.custom_minimum_size.y = 20
    box.add_child(spacer)
    login_title = _label("SIGN IN", 24)
    box.add_child(login_title)
    login_name = LineEdit.new()
    login_name.placeholder_text = "Local username (3-20 characters)"
    login_name.max_length = 20
    box.add_child(login_name)
    NUS3DUISkin.field(login_name)
    login_password = LineEdit.new()
    login_password.placeholder_text = "Password (at least 8 characters)"
    login_password.secret = true
    login_password.max_length = 128
    login_password.text_submitted.connect(func(_value: String) -> void: _submit_login())
    box.add_child(login_password)
    NUS3DUISkin.field(login_password)
    login_submit = _button("Sign in and explore", _submit_login)
    box.add_child(login_submit)
    login_toggle = _button("Create a new local account", _toggle_register)
    box.add_child(login_toggle)
    box.add_child(_button("新手教程  /  HOW TO PLAY", _open_tutorial))
    login_sound_button = _button("UI sound: ON  [F9]", _toggle_ui_sound)
    box.add_child(login_sound_button)
    login_message = _label("", 13, Color.html("#efb8ad"))
    login_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(login_message)
    var foot: Label = _label(
        "Local-only profiles. No internet login, NUS account or cross-device sync.\nYour progress and mail remain on this computer.",
        12, Color.html("#a4c0c6"))
    foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(foot)


func _build_tutorial() -> void:
    tutorial = NUS3DTutorial.new()
    tutorial.name = "StartupTutorial"
    ui.add_child(tutorial)


func _open_tutorial() -> void:
    # Opening the guide never signs in, changes a save, or resumes gameplay.
    if tutorial != null and login_cover.visible:
        tutorial.open_guide()


func _build_profile_card() -> void:
    profile_card = PanelContainer.new()
    profile_card.name = "ProfileStatus"
    profile_card.anchor_left = 0.5
    profile_card.anchor_right = 0.5
    profile_card.offset_left = -410
    profile_card.offset_right = 410
    profile_card.offset_top = 10
    profile_card.offset_bottom = 61
    profile_card.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.14, 0.20, 0.88)))
    ui.add_child(profile_card)
    var row: HBoxContainer = HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    profile_card.add_child(row)
    profile_label = _label("LV 1", 13, Color.html("#e4f5f6"))
    profile_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(profile_label)
    language_game_button = _button("中文 / English", _toggle_language)
    row.add_child(language_game_button)
    profile_sound_button = _button("Sound ON", _toggle_ui_sound)
    row.add_child(profile_sound_button)
    row.add_child(_button("Mail [J]", _open_mail))
    row.add_child(_button("Log out", _logout))
    profile_card.hide()


func _build_mail() -> void:
    mail_cover = _cover("Mailbox")
    var layout: VBoxContainer = _center_panel(mail_cover, Vector2(960, 530))
    var header: HBoxContainer = HBoxContainer.new()
    layout.add_child(header)
    var title: Label = _label("CAMPUS POST  /  LOCAL MAILBOX", 23, Color.html("#cff5f2"))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    mail_sound_button = _button("Sound ON", _toggle_ui_sound)
    header.add_child(mail_sound_button)
    header.add_child(_button("Close [J]", _close_mail))
    layout.add_child(_label("Only accounts registered on this installation can exchange messages.",
        12, Color.html("#b0c8cc")))

    var options: HBoxContainer = HBoxContainer.new()
    layout.add_child(options)
    options.add_child(_button("Inbox", func() -> void: _show_mailbox("inbox")))
    options.add_child(_button("Sent", func() -> void: _show_mailbox("sent")))
    options.add_child(_button("Compose", _show_compose))

    mail_read_panel = HBoxContainer.new()
    mail_read_panel.custom_minimum_size.y = 355
    mail_read_panel.add_theme_constant_override("separation", 17)
    layout.add_child(mail_read_panel)
    mail_list = ItemList.new()
    mail_list.custom_minimum_size.x = 320
    mail_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    mail_list.item_selected.connect(_select_mail)
    mail_read_panel.add_child(mail_list)
    NUS3DUISkin.field(mail_list)
    var detail: VBoxContainer = VBoxContainer.new()
    detail.custom_minimum_size.x = 545
    detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    mail_read_panel.add_child(detail)
    mail_heading = _label("Select a message.", 18)
    mail_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail.add_child(mail_heading)
    mail_body = TextEdit.new()
    mail_body.editable = false
    mail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    mail_body.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
    detail.add_child(mail_body)
    NUS3DUISkin.field(mail_body)
    mail_delete = _button("Delete selected message", _delete_selected)
    detail.add_child(mail_delete)

    mail_compose_panel = VBoxContainer.new()
    mail_compose_panel.custom_minimum_size.y = 350
    mail_compose_panel.hide()
    layout.add_child(mail_compose_panel)
    mail_compose_panel.add_child(_label("New local message", 19))
    compose_to = LineEdit.new()
    compose_to.placeholder_text = "Recipient username on this computer"
    mail_compose_panel.add_child(compose_to)
    NUS3DUISkin.field(compose_to)
    compose_subject = LineEdit.new()
    compose_subject.placeholder_text = "Subject"
    compose_subject.max_length = 80
    mail_compose_panel.add_child(compose_subject)
    NUS3DUISkin.field(compose_subject)
    compose_body = TextEdit.new()
    compose_body.placeholder_text = "Write your message (up to 2,000 characters)"
    compose_body.custom_minimum_size.y = 170
    mail_compose_panel.add_child(compose_body)
    NUS3DUISkin.field(compose_body)
    mail_compose_panel.add_child(_button("Send local message", _send_mail))
    mail_status = _label("", 13, Color.html("#b8dbdf"))
    layout.add_child(mail_status)
    # User mail, dynamic notices and usernames are never passed through the static translator.
    for dynamic_control in [login_message, login_title, login_submit, login_toggle, profile_label, mail_heading, mail_body, mail_status]:
        dynamic_control.set_meta("i18n_dynamic", true)
    mail_cover.hide()


func _toggle_language() -> void:
    language_service.set_locale("en" if language_service.is_chinese() else "zh")


func _on_language_changed(_language: String) -> void:
    language_service.apply_static_ui(login_cover)
    language_service.apply_static_ui(mail_cover)
    language_service.apply_static_ui(profile_card)
    language_service.refresh_world_labels(game.get_node("World") as UTownWorld)
    _refresh_auth_text()
    var button_text: String = "English / 中文" if language_service.is_chinese() else "中文 / English"
    language_login_button.text = button_text
    language_game_button.text = button_text
    login_message.text = language_service.ui_text(login_error_source)
    mail_status.text = language_service.ui_text(mail_status_source)
    _refresh_profile()
    _refresh_sound_buttons()
    if mail_cover.visible and mailbox_mode != "compose":
        _show_mailbox(mailbox_mode)


func _refresh_auth_text() -> void:
    login_title.text = language_service.ui_text("CREATE ACCOUNT" if registering else "SIGN IN")
    login_submit.text = language_service.ui_text("Register and explore" if registering else "Sign in and explore")
    login_toggle.text = language_service.ui_text("Already have an account? Sign in" if registering else "Create a new local account")


func _show_login() -> void:
    get_tree().paused = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    login_cover.show()
    mail_cover.hide()
    profile_card.hide()
    _shown_level = 0
    _refresh_sound_buttons()
    if tutorial != null:
        tutorial.close_guide()
    login_password.clear()
    login_error_source = ""
    login_message.text = ""
    login_name.call_deferred("grab_focus")


func _toggle_register() -> void:
    registering = not registering
    _refresh_auth_text()
    login_error_source = ""
    login_message.text = ""


func _submit_login() -> void:
    var error: String = accounts.register(login_name.text, login_password.text) \
        if registering else accounts.sign_in(login_name.text, login_password.text)
    login_password.clear()
    if not error.is_empty():
        _play_ui_sound("error")
        login_error_source = error
        login_message.text = language_service.ui_text(error)
        return
    _enter_game()


func _enter_game() -> void:
    _restore_game_features()
    challenge.sprint_active = false
    challenge.sprint_elapsed = 0
    challenge.sprint_last_time = -1
    challenge.save_path = accounts.challenge_save_path()
    challenge.load_progress()

    tour.restart()
    var saved_tour: Array = accounts.profile.get("tour_ids", [])
    for entry in saved_tour:
        if tour.current_index >= tour.stops.size():
            break
        if str(entry) != str(tour.stops[tour.current_index].get("id", "")):
            break
        tour.discovered_ids.append(str(entry))
        tour.current_index += 1
    tour.completed = tour.current_index == tour.stops.size()

    observed_tour_ids.clear()
    observed_note_ids.clear()
    observed_sprint_time = -1
    _scan_rewards() # Backfill already completed exploration and existing Field Notes.
    _refresh_profile()
    login_cover.hide()
    mail_cover.hide()
    profile_card.show()
    game.get_node("Player").call("reset_player")
    _play_ui_sound("confirm")
    get_tree().paused = false
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _logout() -> void:
    if not accounts.is_logged_in():
        return
    challenge.sprint_active = false
    var coursework: UTownCoursework = game.get_node_or_null("Coursework") as UTownCoursework
    if coursework != null:
        coursework._save_progress()
    var coins: UTownCoins = game.get_node_or_null("Coins") as UTownCoins
    if coins != null:
        coins.save_progress()
    var leisure: UTownLeisure = game.get_node_or_null("Leisure") as UTownLeisure
    if leisure != null:
        leisure._save_stats()
    accounts.sign_out()
    _show_login()


func _refresh_profile() -> void:
    if not accounts.is_logged_in() or profile_label == null:
        return
    var progress: Dictionary = accounts.level_progress()
    var current_level: int = int(progress["level"])
    if _shown_level > 0 and current_level > _shown_level:
        _play_ui_sound("reward")
    _shown_level = current_level
    if language_service.is_chinese():
        profile_label.text = "%s   等级 %d   经验 %d/%d  |  未读 %d" % [
            accounts.get_username(), int(progress["level"]),
            int(progress["into"]), int(progress["required"]), accounts.unread_count()]
    else:
        profile_label.text = "%s   LV %d   XP %d/%d  |  Mail %d" % [
            accounts.get_username(), int(progress["level"]),
            int(progress["into"]), int(progress["required"]), accounts.unread_count()]


func _on_mailbox_changed() -> void:
    _refresh_profile()


func _open_mail() -> void:
    if not accounts.is_logged_in():
        return
    get_tree().paused = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    mail_cover.show()
    profile_card.hide()
    mail_status_source = ""
    mail_status.text = ""
    _show_mailbox("inbox")
    _play_ui_sound("open")


func _close_mail() -> void:
    mail_cover.hide()
    if accounts.is_logged_in():
        profile_card.show()
        get_tree().paused = false
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_mailbox(mode: String) -> void:
    mailbox_mode = mode
    mail_read_panel.show()
    mail_compose_panel.hide()
    displayed_messages = accounts.get_sent() if mode == "sent" else accounts.get_inbox()
    selected_message_id = ""
    mail_list.clear()
    for message in displayed_messages:
        var prefix: String = "" if bool(message.get("read", false)) or mode == "sent" else "* "
        var address: String = str(message.get("to", "")) if mode == "sent" else str(message.get("from", ""))
        var subject: String = str(message.get("subject", ""))
        if mode == "inbox" and str(message.get("from", "")) == "Campus Office":
            subject = str(language_service.system_mail(subject, str(message.get("body", ""))).get("subject", subject))
            address = language_service.ui_text(address)
        mail_list.add_item("%s%s  |  %s" % [prefix, address, subject])
    mail_heading.text = language_service.ui_text("Sent mail" if mode == "sent" else "Inbox")
    mail_body.text = language_service.localized_text("请从左侧选择一封邮件。", "Select a message on the left.")
    mail_delete.disabled = true


func _select_mail(index: int) -> void:
    if index < 0 or index >= displayed_messages.size():
        return
    var message: Dictionary = displayed_messages[index]
    selected_message_id = str(message.get("id", ""))
    var subject: String = str(message.get("subject", "(no subject)"))
    var body: String = str(message.get("body", ""))
    var from_name: String = str(message.get("from", ""))
    if mailbox_mode == "inbox" and from_name == "Campus Office":
        var system_text: Dictionary = language_service.system_mail(subject, body)
        subject = str(system_text.get("subject", subject))
        body = str(system_text.get("body", body))
        from_name = language_service.ui_text(from_name)
    mail_heading.text = subject
    var fields: String = "发件人 %s\n收件人 %s\n时间 %s" if language_service.is_chinese() else "FROM  %s\nTO  %s\nDATE  %s"
    mail_body.text = fields % [from_name, str(message.get("to", "")), str(message.get("time", ""))] + "\n\n" + body
    mail_delete.disabled = mailbox_mode != "inbox"
    if mailbox_mode == "inbox":
        accounts.mark_read(selected_message_id)
        # Do not rebuild the list while an open message is being read.


func _delete_selected() -> void:
    if mailbox_mode != "inbox" or selected_message_id.is_empty():
        return
    accounts.delete_message(selected_message_id)
    _show_mailbox("inbox")


func _show_compose() -> void:
    mailbox_mode = "compose"
    mail_read_panel.hide()
    mail_compose_panel.show()
    mail_status_source = ""
    mail_status.text = ""
    compose_to.grab_focus()


func _send_mail() -> void:
    var status: String = accounts.send_mail_to(compose_to.text, compose_subject.text, compose_body.text)
    if not status.is_empty():
        mail_status_source = status
        mail_status.text = language_service.ui_text(status)
        return
    compose_to.clear()
    compose_subject.clear()
    compose_body.clear()
    mail_status_source = "Message delivered to the recipient's local inbox."
    mail_status.text = language_service.ui_text(mail_status_source)
    _show_mailbox("sent")


func _restore_game_features() -> void:
    if not accounts.is_logged_in():
        return
    var coursework: UTownCoursework = game.get_node_or_null("Coursework") as UTownCoursework
    if coursework != null:
        coursework.save_path = accounts.feature_save_path("coursework")
        coursework._load_progress()
        coursework._refresh_marker()
    var ui_course: UTownCourseworkUI = game.get_node_or_null("CourseworkUI") as UTownCourseworkUI
    if ui_course != null:
        if coursework != null and coursework.current_faculty_id.is_empty():
            ui_course.show_selector()
        elif ui_course.modal_visible:
            ui_course.hide_modal()
    var arcade: UTownArcade = game.get_node_or_null("Arcade") as UTownArcade
    if arcade != null:
        arcade.save_path = accounts.feature_save_path("arcade")
        arcade.load_progress()
        arcade._refresh_status()
    var life: UTownCampusLife = game.get_node_or_null("CampusLife") as UTownCampusLife
    if life != null:
        life.activity_save_path = accounts.feature_save_path("activities")
        life._load_activities()
    var story: UTownDDLStory = game.get_node_or_null("DDLStory") as UTownDDLStory
    if story != null:
        story.save_path = accounts.feature_save_path("ddl_story")
        story.load_progress()
    var leisure: UTownLeisure = game.get_node_or_null("Leisure") as UTownLeisure
    if leisure != null:
        leisure.save_path = accounts.feature_save_path("leisure")
        leisure._load_stats()
    var coins: UTownCoins = game.get_node_or_null("Coins") as UTownCoins
    if coins != null:
        coins.save_path = accounts.feature_save_path("coins")
        coins.load_progress()
        coins.source_student_wins = arcade.student_wins if arcade != null else 0
        coins._poll_mission_rewards()


func _scan_source_rewards() -> void:
    var coursework: UTownCoursework = game.get_node_or_null("Coursework") as UTownCoursework
    if coursework != null:
        accounts.sync_source_xp("coursework", coursework.total_xp)
    var arcade: UTownArcade = game.get_node_or_null("Arcade") as UTownArcade
    if arcade != null:
        accounts.sync_source_xp("arcade", arcade.lifetime_xp)
    var coins: UTownCoins = game.get_node_or_null("Coins") as UTownCoins
    if coursework == null or coins == null:
        return
    for faculty_id in coursework.faculty_progress.keys():
        if not coursework.faculty_by_id.has(faculty_id):
            continue
        var state: Dictionary = coursework.faculty_progress[faculty_id]
        var grades: PackedStringArray = state.get("grades", PackedStringArray())
        var quests: Array = coursework.faculty_by_id[faculty_id]["quests"]
        for index in range(mini(grades.size(), quests.size())):
            var grade: String = str(grades[index])
            var payout: int = int(round(float(quests[index]["credits"]) * (0.55 if grade == "C (Late)" else 1.0)))
            coins.reward_once("coursework:" + str(faculty_id) + ":" + str(index), payout, "Coursework reward")


func _scan_rewards() -> void:
    if not accounts.is_logged_in():
        return
    _scan_source_rewards()
    if tour.discovered_ids != observed_tour_ids:
        var saved_ids: Array = []
        for stop_id in tour.discovered_ids:
            accounts.award_once("tour:" + stop_id, 60)
            saved_ids.append(stop_id)
        accounts.save_tour_ids(saved_ids)
        observed_tour_ids = tour.discovered_ids.duplicate()
    if challenge.collected_ids != observed_note_ids:
        for item_id in challenge.collected_ids:
            accounts.award_once("field_note:" + item_id, 40)
        observed_note_ids = challenge.collected_ids.duplicate()
    if challenge.sprint_last_time >= 0 and challenge.sprint_last_time != observed_sprint_time:
        accounts.award_once("sprint:completed", 120)
        if challenge.sprint_medal == "GOLD":
            accounts.award_once("sprint:gold", 80)
        observed_sprint_time = challenge.sprint_last_time


func _process(_delta: float) -> void:
    if accounts.is_logged_in() and not get_tree().paused:
        _scan_rewards()


func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key_event: InputEventKey = event as InputEventKey
    if not key_event.pressed or key_event.echo:
        return
    if key_event.keycode == KEY_F9 and (login_cover.visible or mail_cover.visible):
        _toggle_ui_sound()
        get_viewport().set_input_as_handled()
        return
    if key_event.keycode == KEY_F10:
        _toggle_language()
        get_viewport().set_input_as_handled()
        return
    if not accounts.is_logged_in():
        return
    var coursework_modal: UTownCourseworkUI = game.get_node_or_null("CourseworkUI") as UTownCourseworkUI
    if coursework_modal != null and coursework_modal.modal_visible:
        return
    if key_event.keycode == KEY_J:
        if mail_cover.visible:
            _close_mail()
        else:
            _open_mail()
        get_viewport().set_input_as_handled()
