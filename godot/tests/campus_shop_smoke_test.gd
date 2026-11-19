extends SceneTree
## M13 shop tests use the same scene as the existing coin economy.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("M13 shop: " + reason)
    quit(1)

func _run() -> void:
    var packed := load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("main scene missing")
        return
    var game := packed.instantiate()
    root.add_child(game)
    await process_frame
    var coins := game.get_node("Coins") as UTownCoins
    var clock := game.get_node("CampusClock") as UTownCampusClock
    var player := game.get_node("Player") as UTownPlayer
    var world := game.get_node("World") as UTownWorld
    if coins == null or clock == null or player == null:
        _fail("required nodes missing")
        return
    coins.save_path = "user://m13_shop_smoke_test.cfg"
    coins.balance = 200
    coins.coffee_count = 0
    coins.snack_count = 0
    coins.umbrella_owned = false
    coins.shop_stock = {"coffee": 5, "snack": 8, "umbrella": 1}
    var plaza := world.get_node("TownPlaza_approximate") as Node3D
    player.global_position = plaza.global_position + Vector3(0, 0.2, 0)
    coins.toggle_shop()
    if not coins.shop_open or not coins.purchase("coffee"):
        _fail("coffee purchase near Town Plaza should succeed")
        return
    if coins.balance != 188 or coins.coffee_count != 1:
        _fail("wallet debit or coffee inventory mismatch")
        return
    if not coins.drink_coffee() or coins.sprint_boost_seconds < 59.0:
        _fail("coffee boost not activated")
        return
    if not coins.purchase("umbrella") or not coins.umbrella_owned:
        _fail("permanent umbrella not purchased")
        return
    if coins.purchase("umbrella"):
        _fail("duplicate umbrella purchase allowed")
        return
    coins.toggle_shop()
    player.global_position = plaza.global_position + Vector3(100, 0, 100)
    if coins.purchase("snack"):
        _fail("remote purchase bypassed location gate")
        return
    clock.set_time(23, 59)
    coins.shop_last_minute = clock.minute_of_day
    clock.set_time(0, 1)
    coins._restock_if_new_day()
    if int(coins.shop_stock["coffee"]) != 5 or int(coins.shop_stock["umbrella"]) != 0:
        _fail("new-day restock or owned umbrella rule broken")
        return
    var dir := DirAccess.open("user://")
    if dir != null:
        dir.remove("m13_shop_smoke_test.cfg")
    print("PASS: M13 coins, inventory, consumable boost, location gate, permanent ownership, restock")
    game.queue_free()
    quit(0)
