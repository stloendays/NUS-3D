extends SceneTree
## M14: coin-shop modal exclusivity, avatar lock, and account boundary cleanup.
## Headless test uses disposable local user:// paths, never a real player's save.

func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("M14 gameplay integrity: " + reason)
    paused = false
    quit(1)

func _key(code: Key) -> InputEventKey:
    var input := InputEventKey.new()
    input.keycode = code
    input.pressed = true
    return input

func _run() -> void:
    NUS3DServices.ensure_scene_services(self)
    var packed: PackedScene = load("res://scenes/game_shell.tscn") as PackedScene
    if packed == null:
        _fail("existing login/account shell missing")
        return
    var shell: NUS3DGameShell = packed.instantiate() as NUS3DGameShell
    var account: NUS3DAccountStore = shell.get_node("Accounts") as NUS3DAccountStore
    account.storage_root = "user://m14-local-accounts-%d" % Time.get_ticks_usec()
    root.add_child(shell)
    await process_frame
    if not paused or not shell.login_cover.visible:
        _fail("login must retain its original world pause")
        return
    var world: Node3D = shell.game
    var coins: UTownCoins = world.get_node("Coins") as UTownCoins
    var arcade: UTownArcade = world.get_node("Arcade") as UTownArcade
    var coursework: UTownCoursework = world.get_node("Coursework") as UTownCoursework
    var course_ui: UTownCourseworkUI = world.get_node("CourseworkUI") as UTownCourseworkUI
    var leisure_ui: UTownLeisureUI = world.get_node("LeisureUI") as UTownLeisureUI
    var exams: UTownEnglishExams = world.get_node("EnglishExams") as UTownEnglishExams
    var player: UTownPlayer = world.get_node("Player") as UTownPlayer
    var intro: UTownIntro = world.get_node("Intro") as UTownIntro
    if coins == null or arcade == null or course_ui == null or player == null or intro == null or leisure_ui == null or exams == null:
        _fail("missing existing economy, player, exams or coursework")
        return
    if intro.playing:
        intro.finish_intro()
    if account.register("logic_alpha", "alpha-pass-123") != "":
        _fail("cannot create isolated account Alpha")
        return
    shell._enter_game()
    if not account.is_logged_in() or paused or not course_ui.modal_visible or not player.movement_locked or not coursework.modal_open:
        _fail("first-run faculty selection lost its lock after avatar reset")
        return
    coins.toggle_shop()
    if coins.shop_open:
        _fail("a player could open coin shop over mandatory faculty selection")
        return
    if not coursework.select_faculty("science"):
        _fail("could not select a faculty in isolated local profile")
        return
    course_ui.hide_modal()
    if player.movement_locked or coursework.modal_open:
        _fail("closing faculty modal did not resume movement")
        return

    # Shop must be a modal, not a pass-through menu.
    coins.toggle_shop()
    if not coins.shop_open or not coins.shop_panel.visible or not player.movement_locked or not coursework.modal_open:
        _fail("coin shop failed to acquire exclusive player input")
        return
    if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
        _fail("shop did not release mouse for clicking")
        return
    if exams.open_library() or leisure_ui.open_lounge():
        _fail("another gameplay menu opened while coin shop was active")
        return
    course_ui._input(_key(KEY_P))
    leisure_ui._input(_key(KEY_TAB))
    if course_ui.modal_visible or leisure_ui.is_open:
        _fail("P/Tab opened overlapping menus under the coin shop")
        return
    var click := InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    player._unhandled_input(click)
    if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
        _fail("left click recaptured cursor through a modal")
        return
    var reset_position: Vector3 = player.global_position + Vector3(33.0, 0.0, 21.0)
    player.global_position = reset_position
    player._unhandled_input(_key(KEY_R))
    if player.global_position != reset_position:
        _fail("locked modal allowed the R respawn shortcut")
        return
    coins._input(_key(KEY_ESCAPE))
    if coins.shop_open or player.movement_locked or coursework.modal_open:
        _fail("ESC did not restore normal controls")
        return

    # Save only account-scoped wallet/arcade stats; transient gameplay should
    # disappear on logout, not follow the next local player's account.
    if not coins.credit(100, "session test") or not coins.purchase("lunch"):
        _fail("account Alpha could not buy persistent lunch perks")
        return
    if not coins.reward_once("m14:unique", 12, "once-only game quest"):
        _fail("one-time coin reward was rejected")
        return
    var alpha_balance: int = coins.balance
    if coins.reward_once("m14:unique", 12, "duplicate reward"):
        _fail("repeatable reward claim was accepted")
        return
    arcade.student_wins = 4
    arcade._save_progress()
    coins.source_student_wins = arcade.student_wins
    if not coins._drop_at(Vector3(34, 0, 35), 4):
        _fail("could not reserve a session-only coin pickup")
        return
    coins.delivery_active = true
    coins.delivery_time = 27.0
    coins.delivery_cooldown = 14.0
    arcade.students[0]["focus"] = 1
    arcade.students[0]["break_seconds"] = 7.0
    arcade.projectiles[0]["active"] = true
    arcade.projectiles[0]["node"].visible = true
    coins.toggle_shop()
    if not coins.shop_open:
        _fail("shop cannot open after prior modal close")
        return

    shell._logout()
    if not paused or account.is_logged_in() or not shell.login_cover.visible:
        _fail("logout did not return to paused login")
        return
    if coins.shop_open or coins.delivery_active or coins.delivery_time != 0.0 or coins.delivery_cooldown != 0.0:
        _fail("logout leaked shop or incomplete lunch delivery")
        return
    for item in coins.pickups:
        if bool(item["active"]) or item["node"].visible:
            _fail("old account's random coin pickup survived logout")
            return
    for item in arcade.projectiles:
        if bool(item["active"]) or item["node"].visible:
            _fail("a previous player's thrown toy survived account switch")
            return
    for student in arcade.students:
        if int(student["focus"]) != arcade.STUDENT_FOCUS or float(student["break_seconds"]) != 0.0:
            _fail("NPC focus/cooldown leaked across accounts")
            return
    if account.register("logic_beta", "beta-pass-123") != "":
        _fail("cannot create Beta profile")
        return
    shell._enter_game()
    if not course_ui.modal_visible or not player.movement_locked:
        _fail("new account's mandatory faculty selector lost its lock")
        return
    if coins.balance != 0 or coins.lunch_passes != 0 or coins.claimed_rewards.has("m14:unique"):
        _fail("Beta inherited Alpha's wallet, purchases or quest ledger")
        return
    if arcade.student_wins != 0 or coins.delivery_active:
        _fail("Beta inherited old cartoon-duel victories or lunch task")
        return
    shell._logout()
    if account.sign_in("logic_alpha", "alpha-pass-123") != "":
        _fail("could not restore Alpha")
        return
    shell._enter_game()
    if coins.balance != alpha_balance or coins.lunch_passes != 1 or not coins.claimed_rewards.has("m14:unique"):
        _fail("Alpha's persistent wallet/perks/one-time ledger did not restore")
        return
    if arcade.student_wins != 4:
        _fail("Alpha's durable arcade progression did not restore")
        return
    if coins.reward_once("m14:unique", 12, "duplicate after re-login"):
        _fail("switching accounts reset the one-time reward ledger")
        return
    if coins.shop_open or coins.delivery_active or coins.delivery_cooldown != 0.0:
        _fail("Alpha restored stale temporary shop/delivery state")
        return
    if coins.pickups.size() != coins.MAX_PICKUPS or arcade.projectiles.size() != arcade.PROJECTILE_CAPACITY:
        _fail("session reset unexpectedly expanded or destroyed pooled geometry")
        return
    shell._logout()

    # A failed disk write must not spend money, lose a booster or mark a
    # one-time reward claimed. The missing subdirectory is never created.
    coins.save_path = "user://m14-absent-directory-%d/no-wallet.cfg" % Time.get_ticks_usec()
    coins.load_progress()
    coins.balance = 100
    if coins.credit(12, "cannot persist") or coins.balance != 100:
        _fail("unwritable wallet path accepted a credit or changed balance")
        return
    if coins.reward_once("m14:unwritten", 10, "cannot persist") or coins.claimed_rewards.has("m14:unwritten"):
        _fail("failed quest reward write consumed the once-only reward")
        return
    if coins.purchase("lunch") or coins.balance != 100 or coins.lunch_passes != 0:
        _fail("unsaved shop purchase spent coins or granted a pass")
        return
    coins.lucky_pickups = 2
    player.global_position = Vector3(500.0, 0.18, 500.0)
    if not coins._drop_at(player.global_position + Vector3(1.0, 0.0, 0.0), 2):
        _fail("cannot prepare unsaved Lucky Badge pickup")
        return
    if coins.pickup_nearby() or coins.balance != 100 or coins.lucky_pickups != 2:
        _fail("failed pickup save consumed a Lucky Badge or increased coins")
        return
    print("PASS: faculty lock, exclusive shop, account cleanup, private wallet/NPC progression, one-time rewards, failed-save rollback.")
    paused = false
    shell.queue_free()
    quit(0)
