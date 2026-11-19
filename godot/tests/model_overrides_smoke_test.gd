extends SceneTree
## M15 asset fallback and manifest security regression.
func _initialize() -> void:
    call_deferred("_run")

func _fail(reason: String) -> void:
    push_error("M15 model overrides: " + reason)
    quit(1)

func _run() -> void:
    var packed := load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("main scene missing")
        return
    var game := packed.instantiate()
    root.add_child(game)
    await process_frame
    var overrides := game.get_node("AssetOverrides") as UTownAssetOverrides
    var shop := game.get_node("ShopVisuals") as UTownShopVisuals
    if overrides == null or shop == null:
        _fail("asset override scene nodes missing")
        return
    if shop.previews.size() != 3:
        _fail("procedural fallback models missing")
        return
    if overrides.entries.size() != 3:
        _fail("manifest entries missing")
        return
    var rejected_before: int = overrides.rejected_count
    overrides._apply({"target": "shop/coffee", "path": "res://scripts/player_controller.gd", "license": "CC0-1.0"})
    overrides._apply({"target": "shop/coffee", "path": "res://assets/models/coffee.glb", "license": "unknown"})
    if overrides.rejected_count != rejected_before + 2:
        _fail("invalid paths and licenses must be rejected")
        return
    if overrides.loaded_count == 0:
        for key in shop.previews.keys():
            var root: Node3D = shop.previews[key]
            var found_mesh: bool = false
            for child in root.get_children():
                if child is MeshInstance3D and child.visible:
                    found_mesh = true
            if not found_mesh:
                _fail("fallback hidden for missing asset " + str(key))
                return
    print("PASS: M15 manifest parsed, invalid assets rejected, procedural fallbacks retained")
    game.queue_free()
    quit(0)
