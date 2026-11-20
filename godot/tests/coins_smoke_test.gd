extends SceneTree
## Isolated economy check for the full NUS-3D scene. Uses its own test-only save.

func _initialize() -> void:
    call_deferred("_run")

func _fail(error: String) -> void:
    push_error("M3.9 economy failed: " + error)
    quit(1)

func _run() -> void:
    var source: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if source == null:
        _fail("main scene failed to load")
        return
    var scene: Node3D = source.instantiate() as Node3D
    root.add_child(scene)
    await process_frame
    NUS3DServices.enter_test_playmode(scene)
    var coins: UTownCoins = scene.get_node_or_null("Coins") as UTownCoins
    var world: UTownWorld = scene.get_node_or_null("World") as UTownWorld
    var challenge: UTownChallenge = scene.get_node_or_null("Challenge") as UTownChallenge
    var tour: UTownTour = scene.get_node_or_null("Tour") as UTownTour
    var arcade: UTownArcade = scene.get_node_or_null("Arcade") as UTownArcade
    var campus: UTownCampusLife = scene.get_node_or_null("CampusLife") as UTownCampusLife
    var player: UTownPlayer = scene.get_node_or_null("Player") as UTownPlayer
    var hud: CanvasLayer = scene.get_node_or_null("HUD") as CanvasLayer
    if coins == null or world == null or challenge == null or tour == null or arcade == null or campus == null or player == null or hud == null:
        _fail("existing gameplay systems or independent currency node are missing")
        return
    if coins.pickups.size() != coins.MAX_PICKUPS or coins.spawn_segments.size() < 8:
        _fail("coin object pool or existing walkway spawn references are missing")
        return
    if coins.pickup_mesh == null or coins.pickup_material == null or coins.wallet_label == null:
        _fail("a shared 3D coin or the on-screen wallet/icon component is missing")
        return
    if coins.wallet_label.get_parent().get_child_count() < 2:
        _fail("wallet does not include a separate graphic coin icon")
        return
    for item in coins.pickups:
        var coin_root: Node3D = item["node"]
        var geometry: MeshInstance3D = coin_root.get_child(0) as MeshInstance3D
        if geometry.mesh != coins.pickup_mesh or geometry.material_override != coins.pickup_material:
            _fail("pool instances must share one mesh and one material")
            return

    # Avoid writing any real player coin/profile/mission save during testing.
    coins.save_path = "user://nus3d-coins-smoke-%d.cfg" % Time.get_ticks_usec()
    coins.load_progress()
    var plaza: Node3D = world.get_node("TownPlaza_approximate") as Node3D
    player.global_position = plaza.global_position + Vector3(0.0, 0.18, 0.0)
    coins.toggle_shop()
    if not coins.shop_open:
        _fail("Town Plaza shop did not open in test play mode")
        return
    if coins.balance != 0 or coins.claimed_rewards.size() != 0:
        _fail("new independent wallet should start empty")
        return
    if coins.credit(-10, "invalid") or coins.purchase("unknown") or coins.purchase("tip"):
        _fail("negative credits, unknown item or unaffordable purchase accepted")
        return
    if not coins.credit(100, "test starter") or not coins.purchase("lucky"):
        _fail("wallet deposit or Lucky Badge purchase failed")
        return
    if coins.balance != 65 or coins.lucky_pickups != 5 or coins.purchase("lucky"):
        _fail("Lucky Badge price, buff or stacking restriction is incorrect")
        return
    player.global_position = plaza.global_position + Vector3(0.0, 0.18, 0.0)
    if not coins.purchase("lunch") or coins.lunch_passes != 1 or coins.balance != 37:
        _fail("lunch pass purchase failed")
        return
    coins.toggle_shop()
    if coins.shop_open:
        _fail("shop should close before outdoor coin pickup and delivery")
        return
    if not coins.reward_once("test:only-once", 12, "demo mission"):
        _fail("unique quest reward was not paid")
        return
    var wallet_after_quest: int = coins.balance
    if coins.reward_once("test:only-once", 12, "demo mission") or coins.balance != wallet_after_quest:
        _fail("same mission can be redeemed twice")
        return

    # Spawn a coin beside the player well away from earlier random drops.
    player.global_position = Vector3(500.0, 0.18, 500.0)
    if not coins._drop_at(player.global_position + Vector3(1.0, 0.0, 0.0), 5):
        _fail("test coin could not spawn in the bounded object pool")
        return
    var previous_wallet: int = coins.balance
    if not coins.pickup_nearby() or coins.balance != previous_wallet + 10 or coins.lucky_pickups != 4:
        _fail("nearby coin was not picked up with a double-value Lucky Badge")
        return
    if coins.pickup_nearby():
        _fail("same dropped coin could be collected twice")
        return

    # Existing tasks pay exactly once, without modifying their original save data.
    tour.discovered_ids.append("GREEN")
    var mission_before: int = coins.balance
    coins._poll_mission_rewards()
    if coins.balance != mission_before + 12:
        _fail("existing Explorer checkpoint did not award its 12 coins")
        return
    coins._poll_mission_rewards()
    if coins.balance != mission_before + 12:
        _fail("Explorer checkpoint was paid twice")
        return
    var field_note_id: String = challenge.item_id(0)
    if not challenge.collected_ids.has(field_note_id):
        challenge.collected_ids.append(field_note_id)
    var notes_before: int = coins.balance
    coins._poll_mission_rewards()
    if coins.balance != notes_before + 14:
        _fail("Field Note reward was missing")
        return
    campus.visited_activities["ERC/cafe"] = true
    var activity_before: int = coins.balance
    coins._poll_mission_rewards()
    if coins.balance != activity_before + 17:
        _fail("indoor activity did not award its one-time reward")
        return
    var wins_before: int = coins.balance
    arcade.student_wins += 1
    coins._poll_mission_rewards()
    if coins.balance != wins_before + 6:
        _fail("new student duel should award 6 coins")
        return
    coins._poll_mission_rewards()
    if coins.balance != wins_before + 6:
        _fail("duel counter was rewarded more than once")
        return

    # Food-court mission uses existing Plaza and Town Green anchors.
    if coins.delivery_origin == Vector3.ZERO or coins.delivery_destination == Vector3.ZERO:
        _fail("lunch mission is not attached to existing campus landmarks")
        return
    player.global_position = coins.delivery_origin + Vector3(0.0, 0.18, 0.0)
    if not coins.delivery_interact() or not coins.delivery_active:
        _fail("Fine Food lunch delivery did not begin")
        return
    if coins.lunch_passes != 0 or not is_equal_approx(coins.delivery_time, coins.DELIVERY_SECONDS + 35.0):
        _fail("purchased Lunch Time Pass did not extend the timer")
        return
    player.global_position = coins.delivery_destination + Vector3(0.0, 0.18, 0.0)
    var delivery_before: int = coins.balance
    if not coins.delivery_interact() or coins.delivery_active or coins.balance != delivery_before + 53:
        _fail("Town Green delivery did not pay the expected fast-delivery bonus")
        return
    if coins.delivery_interact() or coins.delivery_count != 1:
        _fail("delivery completion was repeatable during cooldown")
        return
    player.global_position = plaza.global_position + Vector3(0.0, 0.18, 0.0)
    coins.toggle_shop()
    if not coins.shop_open or not coins.purchase("tip"):
        _fail("Golden Tip purchase failed at the Town Plaza counter")
        return
    coins.toggle_shop()
    if coins.shop_open:
        _fail("shop should close after Golden Tip purchase")
        return
    coins.delivery_cooldown = 0.0
    player.global_position = coins.delivery_origin + Vector3(0.0, 0.18, 0.0)
    if not coins.delivery_interact():
        _fail("repeatable lunch mission did not restart")
        return
    player.global_position = coins.delivery_destination + Vector3(0.0, 0.18, 0.0)
    var tip_before: int = coins.balance
    if not coins.delivery_interact() or coins.balance != tip_before + 106 or coins.double_tip_passes != 0:
        _fail("Golden Tip Pass did not double the next delivery reward once")
        return

    # Changing the shared HUD visibility hides both the icon and world pick-ups.
    hud.visible = false
    coins._process(0.31)
    if coins.interface.visible:
        _fail("F7 photo mode left coin interface visible")
        return
    for item in coins.pickups:
        if item["node"].visible:
            _fail("F7 photo mode left a coin on the scene")
            return
    hud.visible = true
    coins._process(0.31)
    if not coins.interface.visible:
        _fail("coin HUD did not return after photo mode")
        return

    # 40 random emissions may fill, but never expand, the fixed mesh pool.
    for item in coins.pickups:
        item["active"] = false
        item["node"].visible = false
    var successes: int = 0
    for i in range(40):
        if coins._drop_at(Vector3(float(i), 0, -2.0), 1):
            successes += 1
    if successes != coins.MAX_PICKUPS or coins.pickups.size() != coins.MAX_PICKUPS:
        _fail("random loot exceeded the fixed 12-node pool")
        return
    coins._process(coins.DROP_LIFETIME + 0.2)
    for item in coins.pickups:
        if bool(item["active"]):
            _fail("stale coins failed to expire and return to the pool")
            return
    coins.save_progress()
    var wallet_before_load: int = coins.balance
    coins.load_progress()
    if coins.balance != wallet_before_load or not coins.claimed_rewards.has("tour:GREEN") or coins.delivery_count != 2:
        _fail("coin wallet, mission ledger or delivery count did not persist")
        return
    if coins.reward_once("tour:GREEN", 12, "duplicate after load"):
        _fail("restarting the game would duplicate an old mission reward")
        return
    print("PASS: M3.9 coin icon, bounded 12-drop pool, unique mission payouts, NPC loot, Lucky Badge, Fine Food delivery, shop, F7 and independent save.")
    scene.queue_free()
    quit(0)
