extends SceneTree
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var erc := Node3D.new()
    var src := Node3D.new()
    root.add_child(erc)
    root.add_child(src)
    UTownInteriorLifeProps.decorate_study(erc)
    UTownInteriorLifeProps.decorate_recreation(src)
    var study: Node3D = erc.get_node_or_null("StudyLifePropsM17")
    var recreation: Node3D = src.get_node_or_null("RecreationLifePropsM17")
    if study == null or recreation == null:
        push_error("M17 interior prop groups missing")
        quit(1)
        return
    if study.get_child_count() < 65 or recreation.get_child_count() < 20:
        push_error("M17 interior prop count unexpectedly low")
        quit(1)
        return
    if recreation.get_node_or_null("ChessBoard") == null or study.get_node_or_null("ShelfBook_0_0_0") == null:
        push_error("M17 landmark props missing")
        quit(1)
        return
    print("PASS: M17 study and recreation prop kits")
    quit(0)
