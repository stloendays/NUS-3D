extends Node3D
class_name UTownAssetOverrides
## Non-destructive replacements for procedural props; missing files retain fallback meshes.
## Only curated locally imported assets may be loaded. No runtime HTTP.
const CATALOG_PATH := "res://data/model_overrides.json"
@onready var shop: UTownShopVisuals = $"../ShopVisuals"
@onready var world: UTownWorld = $"../World"
var loaded_count: int = 0
var missing_count: int = 0
var rejected_count: int = 0
var entries: Array[Dictionary] = []

func _ready() -> void:
    if not FileAccess.file_exists(CATALOG_PATH):
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("Model override catalog must be a JSON object")
        return
    for raw in parsed.get("models", []):
        if typeof(raw) != TYPE_DICTIONARY:
            continue
        var entry: Dictionary = raw
        entries.append(entry)
        _apply(entry)

func _apply(entry: Dictionary) -> void:
    var asset_path: String = str(entry.get("path", ""))
    var target_id: String = str(entry.get("target", ""))
    var allowed_targets := ["shop/coffee", "shop/snack", "shop/umbrella"]
    if not target_id in allowed_targets or not asset_path.begins_with("res://assets/models/") or (
        not asset_path.ends_with(".glb") and not asset_path.ends_with(".gltf") and not asset_path.ends_with(".tscn")):
        rejected_count += 1
        return
    if str(entry.get("license", "")) != "CC0-1.0":
        rejected_count += 1
        return
    if not ResourceLoader.exists(asset_path):
        missing_count += 1
        return
    var packed: PackedScene = load(asset_path) as PackedScene
    if packed == null:
        missing_count += 1
        return
    var parts: PackedStringArray = target_id.split("/")
    var root: Node3D = shop.previews.get(parts[1]) as Node3D
    if root == null:
        missing_count += 1
        return
    var instance: Node = packed.instantiate()
    if not instance is Node3D:
        instance.free()
        rejected_count += 1
        return
    var model: Node3D = instance as Node3D
    model.name = "Imported_CC0_" + parts[1]
    model.scale = Vector3.ONE * clampf(float(entry.get("scale", 1.0)), 0.01, 8.0)
    model.position = Vector3(0, float(entry.get("offset_y", 0.0)), 0)
    _strip_collisions(model)
    root.add_child(model)
    # Keep the procedural fallback in scene tree but hide its meshes.
    for child in root.get_children():
        if child != model and child is GeometryInstance3D:
            (child as GeometryInstance3D).visible = false
    loaded_count += 1

func _strip_collisions(node: Node) -> void:
    for child in node.get_children():
        if child is CollisionObject3D:
            child.queue_free()
        else:
            _strip_collisions(child)

func summary() -> Dictionary:
    return {"loaded": loaded_count, "missing": missing_count, "rejected": rejected_count}
