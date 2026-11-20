extends SceneTree
## Standalone navigation contract: routing, collision sweep, no mission/save changes.
func _initialize() -> void:
    call_deferred("_test")


func _fail(message: String) -> void:
    push_error("NPC_NAVIGATION_SMOKE: " + message)
    quit(1)


func _test() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
    if scene == null:
        _fail("main scene missing")
        return
    var game: Node3D = scene.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    var nav: NUS3DNPCNavigation = game.get_node_or_null("NPCNavigation") as NUS3DNPCNavigation
    var campus: UTownCampusLife = game.get_node_or_null("CampusLife") as UTownCampusLife
    if nav == null or campus == null or nav.grid == null:
        _fail("navigation service failed to initialize")
        return
    if campus.pedestrians.size() != 6:
        _fail("outdoor NPC roster changed")
        return
    var obstacles: int = 0
    for y in range(nav.grid.region.size.y):
        for x in range(nav.grid.region.size.x):
            if nav.grid.is_point_solid(Vector2i(x, y)):
                obstacles += 1
    if obstacles < 50:
        _fail("building obstacle map unexpectedly empty")
        return
    var start: Vector3 = Vector3(0, 0, 0)
    var target: Vector3 = Vector3(80, 0, 80)
    var waypoint: Vector3 = nav.next_target("test", start, target, 0.0)
    if nav.repath_count != 1 or not is_finite(waypoint.x):
        _fail("A* path query failed")
        return
    nav.next_target("test", start, target, 0.1)
    if nav.repath_count != 1:
        _fail("navigation path cache did not prevent frame-by-frame replanning")
        return
    nav.next_target("test", start, target, 1.0)
    if nav.repath_count != 2:
        _fail("navigation path did not refresh after cache timeout")
        return
    nav.report_movement("test", start, start, 2.0)
    nav.report_movement("test", start, start, 3.5)
    if float(nav.repath_at.get("test", 1.0)) != 0.0:
        _fail("stuck recovery did not request a new path")
        return
    var away: Vector3 = nav.separation_offset("test", start, [{"name": "test", "node": game.get_node("Player")}])
    if away.length_squared() > 0.0001:
        _fail("separation incorrectly includes the same NPC")
        return
    nav.clear_path("test")
    if nav.paths.has("test"):
        _fail("navigation path not released")
        return
    var before: int = campus.pedestrians.size()
    var current: Vector3 = Vector3(0, 0, 0)
    var next: Vector3 = nav.move_safe(current, Vector3(0.1, 0, 0), 0.016)
    if not is_finite(next.x) or campus.pedestrians.size() != before:
        _fail("collision sweep corrupted NPC state")
        return
    print("NUS3D_NPC_NAVIGATION_SMOKE_OK")
    quit(0)
