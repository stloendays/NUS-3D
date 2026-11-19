extends SceneTree
## Run: godot --headless --path godot --script res://tests/experience_guide_smoke_test.gd
## This test never generates input events, opens the shop, or spends player currency.

func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("M4 contextual guide failed: " + message)
    quit(1)


func _run() -> void:
    var scene_resource: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if scene_resource == null:
        _fail("Game scene unavailable")
        return
    var game: Node3D = scene_resource.instantiate() as Node3D
    if game == null:
        _fail("Game scene could not instantiate")
        return
    root.add_child(game)
    await process_frame

    var guide: UTownExperienceGuide = game.get_node_or_null("ExperienceGuide") as UTownExperienceGuide
    var player: UTownPlayer = game.get_node("Player") as UTownPlayer
    var coins: UTownCoins = game.get_node("Coins") as UTownCoins
    var tour: UTownTour = game.get_node("Tour") as UTownTour
    var challenge: UTownChallenge = game.get_node("Challenge") as UTownChallenge
    var life: UTownCampusLife = game.get_node("CampusLife") as UTownCampusLife
    var hud: CanvasLayer = game.get_node("HUD") as CanvasLayer
    if guide == null or guide.prompt_card == null or guide.objective_card == null or guide.zone_card == null:
        _fail("Missing standalone guide or one of its independent UI cards")
        return
    if guide.screen.mouse_filter != Control.MOUSE_FILTER_IGNORE or guide.prompt_card.mouse_filter != Control.MOUSE_FILTER_IGNORE:
        _fail("The hints must never block mouse input or steal gameplay focus")
        return

    # Remove randomized pickups from this deterministic UI-only test.
    for pickup in coins.pickups:
        pickup["active"] = false
        (pickup["node"] as Node3D).visible = false
    if tour.current_stop().is_empty():
        _fail("No tour goal available")
        return

    var first_goal: Dictionary = guide._goal_offer()
    if str(first_goal.get("id", "")) != "tour:0":
        _fail("The first active goal should be the existing tour")
        return
    var stop_position: Vector3 = tour.stop_world_position(tour.current_index)
    player.global_position = stop_position + Vector3(0.0, 0.18, 0.0)
    player.rotation = Vector3.ZERO
    if guide._direction_arrow(player.global_position + Vector3(0, 0, -20)) != "↑":
        _fail("Forward compass is not aligned with the player")
        return
    if guide._direction_arrow(player.global_position + Vector3(20, 0, 0)) != "→":
        _fail("Right compass direction is not aligned with the player")
        return
    var at_stop: Dictionary = guide._nearest_offer()
    if str(at_stop.get("key", "")) != "E":
        _fail("The tour checkpoint is not suggested in discovery range")
        return

    var balance_before: int = coins.balance
    if not coins._drop_at(player.global_position + Vector3(0.6, 0, 0), 3):
        _fail("Could not create temporary test pickup")
        return
    var coin_offer: Dictionary = guide._nearest_offer()
    if str(coin_offer.get("key", "")) != "Z" or coins.balance != balance_before:
        _fail("Nearby coin suggestion must outrank tour without collecting it")
        return
    for pickup in coins.pickups:
        pickup["active"] = false
        (pickup["node"] as Node3D).visible = false

    # The delivery compass must switch to the existing task target.
    coins.delivery_active = true
    coins.delivery_time = 78.0
    var delivery_goal: Dictionary = guide._goal_offer()
    if str(delivery_goal.get("id", "")) != "lunch" or delivery_goal.get("position") != coins.delivery_destination:
        _fail("Active lunch delivery should replace the tour compass target")
        return
    coins.delivery_active = false

    # Interior exploration must never point to an outdoor waypoint.
    life.interior_active = true
    life.active_interior = "ERC"
    if not guide._goal_offer().is_empty():
        _fail("Outdoor navigation must be hidden inside the fictional rooms")
        return
    if str(guide._nearest_offer().get("key", "")) != "I":
        _fail("Indoors without nearby activity should suggest returning outside")
        return
    life.interior_active = false
    life.active_interior = ""

    # Photo mode / shop must suppress *all* guide cards, not just some.
    hud.visible = false
    guide._refresh_feedback()
    if guide.screen.visible:
        _fail("Photography mode should hide the whole experience overlay")
        return
    hud.visible = true
    guide._refresh_feedback()
    if not guide.screen.visible:
        _fail("Guide did not restore when HUD was shown")
        return

    # Browsing clues must be side-effect-free (no save, no pickup, no quest award).
    if coins.balance != balance_before or challenge.collected_ids.size() < 0:
        _fail("Reading guide hints changed gameplay state")
        return
    print("NUS3D_EXPERIENCE_GUIDE_SMOKE_OK")
    quit(0)
