extends SceneTree
## Test the new look without changing local accounts, game saves, or 3D gameplay.

func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("Cartoon-shell regression: " + reason)
    paused = false
    quit(1)


func _run() -> void:
    var scene: PackedScene = load("res://scenes/game_shell.tscn") as PackedScene
    if scene == null:
        _fail("game shell did not load")
        return
    var shell: NUS3DGameShell = scene.instantiate() as NUS3DGameShell
    root.add_child(shell)
    await process_frame
    if shell.game == null or shell.game.process_mode != Node.PROCESS_MODE_PAUSABLE:
        _fail("existing 3D world or pause contract changed")
        return
    if not paused or shell.login_cover == null or not shell.login_cover.visible:
        _fail("startup must open on the paused login UI")
        return
    var illustration: NUS3DCampusLoginArt = shell.login_cover.get_node_or_null("CampusCartoon") as NUS3DCampusLoginArt
    if illustration == null or illustration.mouse_filter != Control.MOUSE_FILTER_IGNORE:
        _fail("static hand-drawn campus illustration is absent or intercepting input")
        return
    if shell.login_name == null or shell.login_password == null or shell.login_submit == null:
        _fail("username/password/submit controls were removed")
        return
    if shell.login_password.secret != true:
        _fail("password must remain masked")
        return
    if shell.tutorial == null or shell.language_login_button == null or shell.login_sound_button == null:
        _fail("tutorial, language toggle, or sound controls were lost")
        return
    var style: StyleBoxFlat = shell.login_submit.get_theme_stylebox("normal") as StyleBoxFlat
    if style == null or style.bg_color != NUS3DCartoonSkin.YELLOW:
        _fail("login CTA must use the flat yellow visual language")
        return
    if shell.mail_cover == null or shell.mail_cover.visible or shell.mail_list == null or shell.compose_to == null:
        _fail("local mailbox functionality or default visibility changed")
        return
    if shell.profile_card == null or shell.profile_card.visible:
        _fail("account status must stay hidden before signing in")
        return
    if shell.accounts.is_logged_in():
        _fail("visual smoke accidentally created or logged into an account")
        return
    shell.queue_free()
    paused = false
    await process_frame
    print("NUS3D_CARTOON_SHELL_SMOKE_OK")
    quit(0)
