extends SceneTree
## Run offline; tests the owner boundary, persistence and bounded adjustments.
## godot --headless --path godot --script res://tests/admin_console_smoke_test.gd

const ENV_NAME: String = "NUS3D_ADMIN_BOOTSTRAP_PASSWORD"
const TEST_SECRET: String = "not-a-default-owner-secret-2026"

func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("NUS3D admin smoke: " + reason)
    quit(1)


func _run() -> void:
    NUS3DServices.ensure_scene_services(self)
    var scene: PackedScene = load("res://scenes/game_shell.tscn") as PackedScene
    if scene == null:
        _fail("Game shell scene unavailable")
        return
    var shell: NUS3DGameShell = scene.instantiate() as NUS3DGameShell
    var accounts: NUS3DAccountStore = shell.get_node("Accounts") as NUS3DAccountStore
    accounts.storage_root = "user://nus3d-admin-smoke-%d" % Time.get_ticks_usec()
    root.add_child(shell)
    await process_frame

    var admin: NUS3DAdminAuthority = shell.admin_authority
    var console: NUS3DAdminConsole = shell.admin_console
    if admin == null or console == null or console.visible or admin.is_unlocked():
        _fail("Admin console should be hidden and locked by default")
        return
    if admin.apply("grant_xp", 200).is_empty():
        _fail("Anonymous player was able to grant XP")
        return
    if accounts.register("owner_test", "user-login-password-2026") != "":
        _fail("Cannot create owner profile")
        return
    shell._enter_game()
    var modal: UTownCourseworkUI = shell.game.get_node_or_null("CourseworkUI") as UTownCourseworkUI
    if modal != null and modal.modal_visible:
        var first_faculty: UTownCoursework = shell.game.get_node("Coursework") as UTownCoursework
        if not first_faculty.select_faculty(str(first_faculty.faculty_options[0]["id"])):
            _fail("Mandatory first faculty selection failed")
            return
        modal.hide_modal()
    var old_env: String = OS.get_environment(ENV_NAME)
    OS.set_environment(ENV_NAME, "")
    if admin.bootstrap_owner(TEST_SECRET).is_empty():
        _fail("Owner enrollment succeeded without explicit launch secret")
        return
    OS.set_environment(ENV_NAME, TEST_SECRET)
    if admin.bootstrap_owner(TEST_SECRET) != "":
        _fail("Explicit owner enrollment did not succeed")
        return
    OS.set_environment(ENV_NAME, old_env)
    if not admin.is_current_owner() or not admin.is_unlocked():
        _fail("Owner permission was not established")
        return
    if admin.bootstrap_owner(TEST_SECRET).is_empty():
        _fail("Owner enrollment should be one-time only")
        return

    if admin.apply("grant_xp", -1).is_empty() or admin.apply("grant_coins", 5001).is_empty():
        _fail("Out-of-range rewards were accepted")
        return
    if admin.apply("unrestricted_script", 0).is_empty():
        _fail("Unlisted administrator action was accepted")
        return
    var before_xp: int = int(accounts.level_progress()["total"])
    if admin.apply("grant_xp", 220) != "" or int(accounts.level_progress()["total"]) != before_xp + 220:
        _fail("Owner XP grant was not persisted")
        return

    var coins: UTownCoins = shell.game.get_node("Coins") as UTownCoins
    var before_balance: int = coins.balance
    if admin.apply("grant_coins", 80) != "" or coins.balance != before_balance + 80:
        _fail("Owner coins grant did not update wallet")
        return
    if admin.apply("weather", 4) != "" or (shell.game.get_node("Weather") as UTownWeather).mode != 4:
        _fail("Owner weather update failed")
        return
    if admin.apply("lighting", 3) != "" or (shell.game.get_node("World") as UTownWorld).lighting_mode != 3:
        _fail("Owner day/night update failed")
        return
    if admin.apply("restore_atmosphere") != "":
        _fail("Cannot restore default atmosphere")
        return
    if admin.apply("teleport", 999).is_empty():
        _fail("Out-of-bounds teleport was accepted")
        return
    var audit_entries: Array = admin.recent_actions()
    if audit_entries.size() < 6:
        _fail("Not all administrator actions were logged")
        return

    # GPT-generated proposals are untrusted suggestions, never auto-executed.
    if not console.validate_ai_proposal('{"action":"execute_script","value":1,"reason":"danger"}').is_empty():
        _fail("Unsafe GPT proposal action accepted")
        return
    if not console.validate_ai_proposal('{"action":"grant_coins","value":999999,"reason":"too high"}').is_empty():
        _fail("Out-of-range GPT proposal accepted")
        return
    var light_now: int = (shell.game.get_node("World") as UTownWorld).lighting_mode
    if not console._prepare_ai_proposal('{"action":"lighting","value":2,"reason":"cinematic dusk"}'):
        _fail("Safe GPT proposal rejected")
        return
    if (shell.game.get_node("World") as UTownWorld).lighting_mode != light_now:
        _fail("GPT proposal changed lighting without owner confirmation")
        return
    if console.pending_action != "lighting" or console.pending_value != 2:
        _fail("GPT proposal was not stored for review")
        return
    console.confirm.hide()
    console._confirm_grant()
    if (shell.game.get_node("World") as UTownWorld).lighting_mode != 2:
        _fail("Approved GPT proposal did not execute through admin allowlist")
        return
    if console.pending_action != "" or console.pending_value != 0:
        _fail("Approved GPT proposal remains pending")
        return

    shell._open_admin_console()
    if not paused or not console.visible or shell.profile_card.visible:
        _fail("Admin console did not pause the game")
        return
    if admin.is_unlocked():
        _fail("Opening the console should require password reauthentication")
        return
    if admin.unlock(TEST_SECRET) != "":
        _fail("Owner password unlock failed")
        return
    shell._close_admin_console()
    if console.visible or admin.is_unlocked() or paused:
        _fail("Closing admin console did not clear privilege and resume game")
        return

    shell._logout()
    if admin.is_unlocked() or not paused:
        _fail("Logging out must revoke admin privilege")
        return
    if accounts.register("regular_test", "regular-password-2026") != "":
        _fail("Cannot create a regular player")
        return
    shell._enter_game()
    if admin.is_current_owner() or admin.unlock(TEST_SECRET).is_empty() or admin.apply("grant_xp", 40).is_empty():
        _fail("Admin privilege leaked to second account")
        return
    if int(accounts.level_progress()["total"]) != 0:
        _fail("Owner XP leaked to second profile")
        return

    print("PASS: explicit owner enrollment, F12 modal, bounded adjustments, audit, logout and isolation")
    shell.queue_free()
    quit(0)
