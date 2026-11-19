extends SceneTree
## Isolated smoke: no router/UPnP access and no live socket required.
func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("M10 multiplayer/graphics: " + message)
    quit(1)


func _run() -> void:
    var network: NUS3DNetworkSession = NUS3DNetworkSession.new()
    root.add_child(network)
    if network.state != NUS3DNetworkSession.State.OFFLINE or network.player_count() != 0:
        _fail("offline default broken")
        return
    if network._clean_name(" \n[Alice]\t") != "Alice":
        _fail("network name sanitizer failed")
        return
    if network._valid_pose(Vector3(INF, 0, 0), 0.0) or network._valid_pose(Vector3(3000, 0, 0), 0.0):
        _fail("invalid positions accepted")
        return
    if not network._accept_pose(7, Vector3(0, 0, 0), 0.0):
        _fail("valid pose rejected")
        return
    if network._accept_pose(7, Vector3(1000, 0, 0), 0.0):
        _fail("implausible teleport accepted")
        return
    var remote: NUS3DRemotePlayers = NUS3DRemotePlayers.new()
    root.add_child(remote)
    remote.add_player(7, "Alice")
    remote.update_pose(7, Vector3(5, 0, 6), 0.2)
    if remote.avatars.size() != 1 or not remote.targets.has(7):
        _fail("remote avatar state missing")
        return
    remote.remove_player(7)
    if remote.avatars.size() != 0:
        _fail("remote avatar not removed")
        return
    var graphics: NUS3DGraphicsSettings = NUS3DGraphicsSettings.new()
    graphics.set_script(load("res://scripts/performance_profiles.gd"))
    graphics.set("preset", "high")
    root.add_child(graphics)
    for preset in NUS3DGraphicsSettings.ORDER:
        if not graphics.set_preset(preset):
            _fail("quality preset failed: " + preset)
            return
        var settings: Dictionary = NUS3DGraphicsSettings.PROFILES[preset]
        if float(settings["minimum"]) > float(settings["scale"]):
            _fail("resolution limits inverted")
            return
    if graphics.set_preset("invalid"):
        _fail("invalid graphics preset accepted")
        return
    network.leave_room()
    print("PASS: M10 offline safety, pose validation, remote avatars, graphics presets")
    quit(0)
