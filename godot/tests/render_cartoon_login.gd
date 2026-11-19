extends SceneTree
## Real Godot UI PNGs on Xvfb. No generated illustrations or uploaded screenshots.
## Preview account is confined to a unique, disposable user:// directory.

func _initialize() -> void:
    call_deferred("_capture")


func _shot(output: String, filename: String) -> bool:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty() or image.get_width() < 400:
        return false
    return image.save_png(output.path_join(filename)) == OK


func _capture() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("UI screenshot needs a graphical Xvfb display")
        quit(1)
        return
    var packed: PackedScene = load("res://scenes/game_shell.tscn") as PackedScene
    if packed == null:
        push_error("Game shell cannot load")
        quit(1)
        return
    var shell: NUS3DGameShell = packed.instantiate() as NUS3DGameShell
    var account: NUS3DAccountStore = shell.get_node("Accounts") as NUS3DAccountStore
    account.storage_root = "user://nus3d-ui-preview-%d" % Time.get_ticks_usec()
    root.add_child(shell)
    await process_frame
    if shell.login_cover == null or not shell.login_cover.visible:
        push_error("Login cover did not initialize")
        quit(1)
        return
    var directory: String = ProjectSettings.globalize_path("res://review_previews")
    if DirAccess.make_dir_recursive_absolute(directory) != OK:
        push_error("Unable to create preview directory")
        quit(1)
        return

    shell.language_service.set_locale("en")
    if not await _shot(directory, "M5_2_CARTOON_LOGIN_EN.png"):
        push_error("English login viewport screenshot failed")
        quit(1)
        return
    shell.language_service.set_locale("zh")
    if not await _shot(directory, "M5_2_CARTOON_LOGIN_ZH.png"):
        push_error("Chinese login viewport screenshot failed")
        quit(1)
        return

    var issue: String = account.register("demo_visitor", "OnlyForPreview_123")
    if not issue.is_empty():
        push_error("Preview account failed: " + issue)
        quit(1)
        return
    shell._enter_game()
    shell._open_mail()
    shell._select_mail(0)
    if not await _shot(directory, "M5_2_CARTOON_MAIL.png"):
        push_error("Mailbox viewport screenshot failed")
        quit(1)
        return

    print("PASS: captured 3 original Godot account UI PNG previews")
    shell.queue_free()
    paused = false
    quit(0)
