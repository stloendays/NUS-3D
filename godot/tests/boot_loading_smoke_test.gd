extends SceneTree
## Headless startup check: genuine threaded PackedScene loading, tip carousel,
## complete handoff to the unchanged login shell; no fake timer or account writes.

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("Loading screen smoke: " + message)
    quit(1)

func _run() -> void:
    NUS3DServices.ensure_scene_services(self)
    var settings: String = ProjectSettings.get_setting("application/run/main_scene", "")
    if settings != "res://scenes/boot.tscn":
        _fail("project must launch the lightweight loading scene")
        return
    var packed: PackedScene = load("res://scenes/boot.tscn") as PackedScene
    if packed == null:
        _fail("boot scene not packaged")
        return
    var boot: NUS3DBootLoading = packed.instantiate() as NUS3DBootLoading
    boot.auto_start = false
    root.add_child(boot)
    await process_frame
    if boot.stage != boot.STAGE_IDLE or boot.latest_progress != 0.0:
        _fail("new boot controller should remain idle in manual test mode")
        return
    if boot.tips.size() != 11 or boot.tip_title == null or boot.progress_bar == null or boot.percentage == null:
        _fail("expected 11 gameplay tips and actual progress UI")
        return
    if boot.root_control == null or boot.layer <= 30:
        _fail("boot overlay must cover the existing login UI during init")
        return
    if boot.stage_progress(boot.STAGE_WORLD, 1.0) < 0.8 or boot.stage_progress(boot.STAGE_SHELL, 1.0) >= 1.0:
        _fail("preloaded resources must not appear as 100% ready")
        return
    if boot.stage_progress(boot.STAGE_DONE, 1.0) != 1.0:
        _fail("ready-state percentage must be 100%")
        return
    boot._show_tip(3)
    if boot.tip_counter.text != "04 / 11" or boot.tip_keys.text.is_empty():
        _fail("the tip carousel does not display a keybind and position")
        return
    boot._show_tip(0)
    var selected_locale: bool = boot._is_zh()
    if boot.tip_title.text != str(boot.tips[0]["zh_title" if selected_locale else "en_title"]):
        _fail("gameplay tips do not respect the saved user locale")
        return
    boot.start_loading()
    if boot.stage != boot.STAGE_WORLD:
        _fail("game world threaded request did not start")
        return

    var prev_progress: float = 0.0
    var saw_world_load: bool = false
    var saw_shell_load: bool = false
    var saw_finished: bool = false
    var began_ms: int = Time.get_ticks_msec()
    for i in range(6000):
        await process_frame
        if not is_instance_valid(boot):
            break
        if boot.stage == boot.STAGE_ERROR:
            _fail("threaded startup failed: " + boot.error_message)
            return
        if boot.latest_progress + 0.0001 < prev_progress:
            _fail("displayed loading percentage moved backwards")
            return
        prev_progress = boot.latest_progress
        saw_world_load = saw_world_load or boot.stage == boot.STAGE_WORLD
        saw_shell_load = saw_shell_load or boot.stage >= boot.STAGE_SHELL
        saw_finished = saw_finished or boot.stage == boot.STAGE_DONE
        if Time.get_ticks_msec() - began_ms > 45000:
            _fail("loading did not complete in 45 seconds")
            return

    var shell: NUS3DGameShell = root.get_node_or_null("GameShell") as NUS3DGameShell
    if shell == null or not saw_world_load or not saw_shell_load or not saw_finished:
        _fail("threaded loading did not hand over to GameShell")
        return
    if current_scene != shell or shell.game == null or shell.login_cover == null:
        _fail("boot did not preserve SceneTree current_scene, world or login")
        return
    if not shell.login_cover.visible or not paused or shell.accounts.is_logged_in():
        _fail("startup must land at the original paused sign-in screen")
        return
    if shell.tutorial == null or shell.tutorial.pages.size() != 6:
        _fail("pre-existing beginner tutorial was lost in startup transition")
        return
    if shell.game.get_node_or_null("Coursework") == null or shell.game.get_node_or_null("Coins") == null:
        _fail("existing coursework/economy controllers were not retained")
        return
    print("PASS: 11 bilingual tips, actual 2-stage threaded loading, monotonic progress, complete login handoff and tutorial.")
    paused = false
    shell.queue_free()
    quit(0)
