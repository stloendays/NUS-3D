extends SceneTree
## M15 isolated Midnight Deadline mode regression. No network or downloaded assets.
## Run: godot --headless --path godot --script res://tests/midnight_horror_smoke_test.gd

func _initialize() -> void:
    call_deferred("_check")


func _fail(reason: String) -> void:
    push_error("M15 horror regression: " + reason)
    quit(1)


func _check() -> void:
    NUS3DServices.ensure_scene_services(self)
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("Main world scene did not import")
        return
    var world: Node3D = packed.instantiate() as Node3D
    root.add_child(world)
    await process_frame
    NUS3DServices.enter_test_playmode(world)
    var horror: UTownHorrorMode = world.get_node_or_null("MidnightHorror") as UTownHorrorMode
    var arcade: UTownArcade = world.get_node("Arcade") as UTownArcade
    var player: UTownPlayer = world.get_node("Player") as UTownPlayer
    var weather: UTownWeather = world.get_node("Weather") as UTownWeather
    var campus_world: UTownWorld = world.get_node("World") as UTownWorld
    var coins: UTownCoins = world.get_node("Coins") as UTownCoins
    if horror == null or horror.active or horror.phantoms.size() != 2 or horror.document_nodes.size() != 3:
        _fail("Horror mode must be dormant by default, with two pooled pursuers and three clues")
        return
    for phantom in horror.phantoms:
        if (phantom["node"] as Node3D).visible:
            _fail("A pursuer was visible outside the mode")
            return
    if horror.start_run() or horror.hit_phantom(0, 3):
        _fail("Unauthenticated world must not start the challenge or banish ghosts")
        return

    var accounts: NUS3DAccountStore = NUS3DAccountStore.new()
    accounts.storage_root = "user://nus3d-horror-smoke-%d" % Time.get_ticks_usec()
    root.add_child(accounts)
    if accounts.register("midnight_a", "fictional-test-pass-2026") != "":
        _fail("Could not register the local horror test player")
        return
    coins.save_path = accounts.feature_save_path("coins")
    coins.load_progress()
    horror.attach_profile(accounts)
    player.movement_locked = false
    var previous_weather: int = weather.mode
    var previous_light: int = campus_world.lighting_mode
    var previous_toy: int = arcade.weapon_index
    if not horror.start_run():
        _fail("Logged-in offline player could not enter opt-in mode")
        return
    if weather.mode != 4 or campus_world.lighting_mode != 3 or not horror.active:
        _fail("Atmosphere was not switched on mode entry")
        return
    if arcade.try_fire() or horror.hit_phantom(0, 1):
        _fail("Ghost combat worked without first finding the Pulse Blaster")
        return
    if horror.pickup_node == null or not horror.pickup_node.visible:
        _fail("Pulse Blaster pickup was not visible")
        return

    player.global_position = horror.pickup_node.global_position
    horror._collect_nearby()
    if not horror.armed or not horror.held_weapon.visible:
        _fail("Player did not acquire and equip required weapon")
        return
    if not arcade.try_fire():
        _fail("Projectile pool did not accept armed horror-mode fire")
        return
    arcade._physics_process(0.016)
    if arcade.projectiles.size() != arcade.PROJECTILE_CAPACITY:
        _fail("Horror mode changed the existing bounded projectile pool")
        return
    for index in range(horror.phantoms.size()):
        for _hit in range(horror.GHOST_HP):
            if not horror.hit_phantom(index, 1):
                _fail("A phantom could not be banished with the acquired weapon")
                return
        if horror.hit_phantom(index, 1):
            _fail("Banished phantom remained damageable")
            return
    if horror.banished != 2:
        _fail("Two phantoms were not counted as defeated")
        return

    for i in range(horror.document_nodes.size()):
        player.global_position = horror.document_nodes[i].global_position
        horror._collect_nearby()
    if horror.pages_found != 3 or not horror.exit_node.visible:
        _fail("Three cursed files did not unlock the safe exit")
        return
    player.global_position = horror.exit_node.global_position
    horror._collect_nearby()
    if horror.active or horror.wins != 1 or horror.best_seconds < 0.0:
        _fail("The completed mission did not produce a persistent win")
        return
    if weather.mode != previous_weather or campus_world.lighting_mode != previous_light or arcade.weapon_index != previous_toy:
        _fail("Weather, lighting or normal arcade weapon was not restored")
        return
    if accounts.level_progress()["total"] != 160 or coins.balance != 100:
        _fail("First clear reward was not granted correctly")
        return
    var old_xp: int = int(accounts.level_progress()["total"])
    var old_coins: int = coins.balance
    if not horror.start_run():
        _fail("Could not replay challenge")
        return
    # Replaying the same success must not generate new XP or currency.
    horror.finish_run(true, "retest")
    if int(accounts.level_progress()["total"]) != old_xp or coins.balance != old_coins:
        _fail("Replay generated duplicate one-time rewards")
        return
    if horror.wins != 2:
        _fail("Win counter failed to track replay")
        return
    horror.attach_profile(accounts)
    if horror.wins != 2:
        _fail("Saved win count was not reloaded for the same player")
        return
    accounts.sign_out()
    horror.detach_profile()
    if accounts.register("midnight_b", "fictional-second-pass") != "":
        _fail("Could not create second account")
        return
    horror.attach_profile(accounts)
    if horror.wins != 0 or horror.best_seconds >= 0.0:
        _fail("Horror score was leaked across accounts")
        return
    if not horror.start_run():
        _fail("Second player could not start with fresh mode state")
        return
    horror.finish_run(false, "abandoned")
    if horror.active or horror.wins != 0 or horror.armed:
        _fail("Failed/abandoned mode retained progress or active state")
        return
    world.queue_free()
    accounts.queue_free()
    await process_frame

    # The standalone world has no LAN node; verify the nested GameShell path too.
    var shell_scene: PackedScene = load("res://scenes/game_shell.tscn") as PackedScene
    var shell: NUS3DGameShell = shell_scene.instantiate() as NUS3DGameShell
    var shell_accounts: NUS3DAccountStore = shell.get_node("Accounts") as NUS3DAccountStore
    shell_accounts.storage_root = "user://nus3d-horror-lan-smoke-%d" % Time.get_ticks_usec()
    root.add_child(shell)
    await process_frame
    if shell_accounts.register("night_host", "local-test-owner-2026") != "":
        _fail("Could not set up account for LAN restriction test")
        return
    shell._enter_game()
    NUS3DServices.enter_test_playmode(shell.game)
    (shell.game.get_node("Player") as UTownPlayer).movement_locked = false
    var host_horror: UTownHorrorMode = shell.horror_mode
    if not host_horror.can_start():
        _fail("Local offline game unexpectedly blocked the opt-in mode")
        return
    shell.session_overlay.network.state = NUS3DNetworkSession.State.CONNECTING
    if host_horror.can_start():
        _fail("LAN connection state allowed horror mode to begin")
        return
    shell.session_overlay.network.state = NUS3DNetworkSession.State.OFFLINE
    if not host_horror.start_run():
        _fail("Horror mode could not start after LAN returned offline")
        return
    shell.session_overlay.network.state = NUS3DNetworkSession.State.CLIENT
    host_horror._process(0.1)
    if host_horror.active:
        _fail("Horror mode did not stop when a multiplayer client became active")
        return
    shell.session_overlay.network.state = NUS3DNetworkSession.State.OFFLINE
    shell.queue_free()
    print("PASS: M15 opt-in world, weapon-first combat, two chasing NPCs, three clues, exit, replay guards, per-account saves, LAN isolation and atmosphere restoration")
    quit(0)
