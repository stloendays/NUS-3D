extends SceneTree
## Run: godot --headless --path godot --script res://tests/account_smoke_test.gd

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    NUS3DServices.ensure_scene_services(self)
    var language_service: NUS3DGameLanguage = root.get_node("GameLanguage") as NUS3DGameLanguage
    var account: NUS3DAccountStore = NUS3DAccountStore.new()
    account.storage_root = "user://nus3d-account-smoke-%d" % Time.get_ticks_usec()
    root.add_child(account)
    if account.register("alice_3d", "correct-pass-123") != "":
        _fail("Alice registration failed")
        return
    var alice_path: String = account.challenge_save_path()
    var alice_horror_path: String = account.feature_save_path("horror")
    if alice_horror_path.is_empty():
        _fail("Account-scoped horror save path is missing")
        return
    if not account.is_logged_in() or account.get_username() != "alice_3d":
        _fail("Register must open its own profile")
        return
    if account.level_progress()["level"] != 1 or account.get_inbox().size() != 1:
        _fail("New players must be level one and receive the welcome message")
        return
    if not account.award_once("tour:GREEN", 60) or account.award_once("tour:GREEN", 60):
        _fail("Quest XP rewards must be unique")
        return
    account.save_tour_ids(["GREEN"])
    if account.level_progress()["total"] != 60:
        _fail("First tour reward was not persisted")
        return
    account.sign_out()
    if account.sign_in("alice_3d", "wrong-password") == "":
        _fail("Incorrect password was accepted")
        return
    if account.is_logged_in():
        _fail("Failed authentication must never create a session")
        return

    if account.register("bob_3d", "another-pass-456") != "":
        _fail("Bob registration failed")
        return
    var bob_horror_path: String = account.feature_save_path("horror")
    if bob_horror_path.is_empty() or bob_horror_path == alice_horror_path:
        _fail("Horror saves must be enabled and isolated per account")
        return
    if account.challenge_save_path() == alice_path or account.level_progress()["total"] != 0:
        _fail("Separate accounts must not share challenge saves or XP")
        return
    if account.send_mail_to("alice_3d", "Hello Alice", "This is a local mailbox test.") != "":
        _fail("Cross-profile offline delivery failed")
        return
    if account.get_sent().size() != 1:
        _fail("Sent mail not recorded")
        return
    account.sign_out()
    if account.sign_in("alice_3d", "correct-pass-123") != "":
        _fail("Correct password did not restore Alice")
        return
    if account.challenge_save_path() != alice_path or account.level_progress()["total"] != 60:
        _fail("XP or account save mapping did not survive sign-out")
        return
    if account.profile.get("tour_ids", []) != ["GREEN"]:
        _fail("Tour discovery did not survive sign-out")
        return
    if account.unread_count() != 2:
        _fail("Inbox mail did not survive switching users")
        return
    var inbox: Array = account.get_inbox()
    if str(inbox[0].get("subject", "")) != "Hello Alice":
        _fail("Wrong local mail delivered")
        return
    var mail_id: String = str(inbox[0].get("id", ""))
    account.mark_read(mail_id)
    if account.unread_count() != 1:
        _fail("Read state did not update")
        return
    account.delete_message(mail_id)
    if account.get_inbox().size() != 1:
        _fail("Deleting inbox message did not persist")
        return
    account.sign_out()
    if account.sign_in("alice_3d", "correct-pass-123") != "":
        _fail("Reload after mail deletion failed")
        return
    if account.get_inbox().size() != 1 or account.award_once("tour:GREEN", 60):
        _fail("Inbox deletion or XP deduplication not persisted")
        return

    var startup_scene: PackedScene = load("res://scenes/game_shell.tscn") as PackedScene
    if startup_scene == null:
        _fail("Login shell scene cannot load")
        return
    var shell: NUS3DGameShell = startup_scene.instantiate() as NUS3DGameShell
    var shell_accounts: NUS3DAccountStore = shell.get_node("Accounts") as NUS3DAccountStore
    shell_accounts.storage_root = "user://nus3d-shell-smoke-%d" % Time.get_ticks_usec()
    root.add_child(shell)
    await process_frame
    if not bool(shell.login_cover.visible) or not paused:
        _fail("Startup must show login and pause gameplay")
        return
    if shell.game == null or shell.game.process_mode != Node.PROCESS_MODE_PAUSABLE:
        _fail("Existing UTown game must remain a separate pausable scene")
        return
    # Tutorial is bundled, accessible before login and keeps the world paused.
    var tutorial: NUS3DTutorial = shell.tutorial
    if tutorial == null or tutorial.get_parent() != shell.ui or tutorial.pages.size() != 6:
        _fail("Startup tutorial file or guide viewer missing")
        return
    if not FileAccess.file_exists("res://data/startup_tutorial.json"):
        _fail("Packaged beginner tutorial data missing")
        return
    shell._open_tutorial()
    if not tutorial.visible or not shell.login_cover.visible or not paused or shell_accounts.is_logged_in():
        _fail("Guide must open before login without resuming or authenticating")
        return
    if tutorial.current_page != 0 or tutorial.page_title_label.text.is_empty():
        _fail("Guide did not display its opening page")
        return
    tutorial.previous_page()
    if tutorial.current_page != 0:
        _fail("Previous button must not cross first page")
        return
    tutorial.next_page()
    if tutorial.current_page != 1 or tutorial.page_counter_label.text != "2 / 6":
        _fail("Guide next-page navigation failed")
        return
    tutorial.previous_page()
    if tutorial.current_page != 0:
        _fail("Guide previous-page navigation failed")
        return
    for _index in range(tutorial.pages.size() - 1):
        tutorial.next_page()
    var finish_label: String = "返回" if language_service.is_chinese() else "Back"
    if tutorial.current_page != tutorial.pages.size() - 1 or tutorial.next_button.text.find(finish_label) == -1:
        _fail("Guide final page or finish button missing")
        return
    tutorial.next_page()
    if tutorial.visible or not shell.login_cover.visible or not paused:
        _fail("Finishing guide must return to paused login")
        return
    shell._open_tutorial()
    var exit_key: InputEventKey = InputEventKey.new()
    exit_key.keycode = KEY_ESCAPE
    exit_key.pressed = true
    tutorial._input(exit_key)
    if tutorial.visible or not paused or shell_accounts.is_logged_in():
        _fail("Esc must close guide without altering login/game state")
        return
    shell._open_tutorial()
    tutorial.close_guide()
    if tutorial.visible or not paused or shell_accounts.is_logged_in():
        _fail("Close button action must return to login safely")
        return
    if shell_accounts.register("shell_tester", "game-test-123") != "":
        _fail("UI scene local account could not register")
        return
    shell._enter_game()
    if paused or shell.login_cover.visible or not shell.profile_card.visible:
        _fail("Signing in must resume original gameplay")
        return
    if not shell.tour.try_check_in():
        _fail("First tour checkpoint unavailable after login")
        return
    shell._scan_rewards()
    if int(shell_accounts.level_progress()["total"]) != 60:
        _fail("Tour gameplay event did not award 60 XP")
        return
    shell._scan_rewards()
    if int(shell_accounts.level_progress()["total"]) != 60:
        _fail("Repeated reward scan farmed XP")
        return
    shell._open_mail()
    if not paused or not shell.mail_cover.visible:
        _fail("Reading local mail must pause the world")
        return
    shell._close_mail()
    if paused or shell.mail_cover.visible:
        _fail("Closing mailbox must resume play")
        return
    shell._logout()
    if not paused or not shell.login_cover.visible or shell_accounts.is_logged_in():
        _fail("Logout must return to a locked login screen")
        return
    if shell_accounts.sign_in("shell_tester", "game-test-123") != "":
        _fail("Second login did not restore account")
        return
    shell._enter_game()
    if shell.tour.current_index != 1 or int(shell_accounts.level_progress()["total"]) != 60:
        _fail("Logged-in gameplay must restore tour progress and XP")
        return
    shell._logout()
    paused = false
    print("NUS3D_ACCOUNT_SMOKE_OK")
    quit(0)


func _fail(reason: String) -> void:
    push_error("NUS3D account smoke failed: " + reason)
    paused = false
    quit(1)
