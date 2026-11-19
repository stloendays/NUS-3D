extends SceneTree
## No real network or paid API calls. Run with:
## godot --headless --path godot --script res://tests/campus_ai_smoke_test.gd

func _initialize() -> void:
    call_deferred("_run")


func _fail(what: String) -> void:
    push_error("NUS3D Campus AI smoke: " + what)
    quit(1)


func _run() -> void:
    NUS3DServices.ensure_scene_services(self)
    var packed: PackedScene = load("res://scenes/game_shell.tscn") as PackedScene
    if packed == null:
        _fail("Game shell scene missing")
        return
    var shell: NUS3DGameShell = packed.instantiate() as NUS3DGameShell
    shell.get_node("Accounts").storage_root = "user://nus3d-ai-smoke-%d" % Time.get_ticks_usec()
    root.add_child(shell)
    await process_frame

    var ai: NUS3DCampusHub = shell.campus_hub
    if ai == null or ai.visible or ai.links.size() < 10:
        _fail("Campus AI must start hidden and load the link catalog")
        return
    for entry in ai.links:
        if not ai._approved_link(str(entry.get("url", ""))):
            _fail("Allowlisted catalog contains unapproved URL")
            return
    if ai._approved_link("file:///etc/passwd") \
            or ai._approved_link("http://chatgpt.com/") \
            or ai._approved_link("https://map.nus.edu.sg.evil.example/"):
        _fail("Untrusted URL passed the safe-link filter")
        return

    var before: int = ai.conversation.size()
    ai.provider_box.select(0)  # offline demo; absolutely no HTTP calls
    ai.prompt_box.text = "Explain a funny deadline"
    ai._submit_chat()
    if ai.request_active or ai.conversation.size() != before \
            or ai.chat_log.text.find("deadline") < 0:
        _fail("Offline demo mutated history or tried to call a provider")
        return

    var account: NUS3DAccountStore = shell.get_node("Accounts") as NUS3DAccountStore
    if account.register("campus_ai_test", "test-pass-2026") != "":
        _fail("Smoke test account could not register")
        return
    shell._enter_game()
    var coursework: UTownCourseworkUI = shell.game.get_node_or_null("CourseworkUI") as UTownCourseworkUI
    if coursework != null and coursework.modal_visible:
        coursework.hide_modal()

    shell._open_campus_hub()
    if not ai.visible or not paused or shell.profile_card.visible:
        _fail("Campus AI should pause gameplay and hide the profile")
        return
    shell._close_campus_hub()
    if ai.visible or paused or not shell.profile_card.visible:
        _fail("Closing Campus AI should restore gameplay and profile")
        return

    ai.conversation.append({"role": "user", "content": "private local test"})
    shell._logout()
    if ai.visible or not paused or ai.conversation.size() != 0:
        _fail("Logout must erase ephemeral chat and keep login paused")
        return

    print("PASS: NUS3D Campus AI links, offline chat, pause, close and account isolation")
    shell.queue_free()
    quit(0)
