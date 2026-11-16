extends Node
## Explicitly opt-in runtime smoke test for the exported Windows executable.
## This code runs in the actual exported PCK, not in a Godot editor-only script.
## Usage: NUS3D-UTown.exe --headless -- --nus3d-self-test --nus3d-self-test-report=C:/path/report.json

const TEST_FLAG: String = "--nus3d-self-test"
const REPORT_PREFIX: String = "--nus3d-self-test-report="
const REQUIRED_SOURCE_FILES: Array[String] = [
    "res://data/utown_core.json",
    "res://data/m2_profiles.json",
    "res://data/viewpoints.json",
    "res://data/osm_p0_reference.json",
    "res://data/osm_fit_baseline.json",
]

func _ready() -> void:
    if OS.get_cmdline_user_args().has(TEST_FLAG):
        call_deferred("_run_export_test")

func collect_issues() -> Array[String]:
    var issues: Array[String] = []
    var site: UTownWorld = get_parent().get_node_or_null("World") as UTownWorld
    var player: CharacterBody3D = get_parent().get_node_or_null("Player") as CharacterBody3D
    var review: UTownViewReview = get_parent().get_node_or_null("ViewReview") as UTownViewReview
    var hud: CanvasLayer = get_parent().get_node_or_null("HUD") as CanvasLayer

    for source_file in REQUIRED_SOURCE_FILES:
        if not FileAccess.file_exists(source_file):
            issues.append("Missing packaged JSON: " + source_file)
    if site == null:
        issues.append("World node missing")
    else:
        if site.layout.is_empty():
            issues.append("UTown JSON did not load")
        var buildings: Array = site.layout.get("buildings", [])
        if site.generated_building_count < 9 or site.generated_building_count != buildings.size():
            issues.append("Expected procedural building massing was not generated")
        if site.generated_tree_count != 64 or site.generated_tree_positions.size() != 64:
            issues.append("Tree batches or source positions are incomplete")
        if site.generated_facade_count != 2 or site.m2_detail_nodes.size() != 2:
            issues.append("ERC/SRC facade study layers not generated")
        if site.generated_path_count < 8 or site.route_points.size() != 4:
            issues.append("Conceptual walkway geometry is incomplete")
        if site.generated_lamp_count < 2:
            issues.append("Illustrative night lamps were not built")
        var osm_features: Array = site.osm_reference_data.get("features", [])
        if osm_features.size() != 2 or site.osm_reference_layer == null:
            issues.append("Frozen OSM compare-only outlines failed to load")
        var reference: Dictionary = site.layout.get("spatial_reference", {})
        if str(reference.get("precision", "")).find("NOT survey") < 0:
            issues.append("Provisional spatial-data disclaimer missing")
    if player == null:
        issues.append("First-person player missing")
    if hud == null or get_parent().get_node_or_null("HUD/GISCard/Summary") == null:
        issues.append("Source comparison HUD not present")
    if review == null or review.viewpoint_count() != 4:
        issues.append("Evidence-linked camera registry did not load")
    return issues

func _run_export_test() -> void:
    var issues: Array[String] = collect_issues()
    var report_path: String = "user://nus3d-export-smoke.json"
    for option in OS.get_cmdline_user_args():
        if option.begins_with(REPORT_PREFIX):
            report_path = option.substr(REPORT_PREFIX.length())
    var world: UTownWorld = get_parent().get_node_or_null("World") as UTownWorld
    var results: Dictionary = {
        "schema_version": 1,
        "result": "pass" if issues.is_empty() else "fail",
        "test_target": "exported-game-runtime",
        "provisional_not_surveyed": true,
        "buildings": world.generated_building_count if world != null else 0,
        "facades": world.generated_facade_count if world != null else 0,
        "trees": world.generated_tree_count if world != null else 0,
        "route_waypoints": world.route_points.size() if world != null else 0,
        "osm_features": world.osm_reference_layer.feature_count if world != null and world.osm_reference_layer != null else 0,
        "issues": issues,
    }
    var out: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
    if out == null:
        push_error("Failed to write packaged runtime test report: " + report_path)
        get_tree().quit(3)
        return
    out.store_string(JSON.stringify(results, "  ") + "\n")
    out.close()
    if issues.is_empty():
        print("NUS3D_EXPORT_SMOKE_OK")
        get_tree().quit(0)
    else:
        for issue in issues:
            push_error("Export smoke: " + issue)
        get_tree().quit(2)
