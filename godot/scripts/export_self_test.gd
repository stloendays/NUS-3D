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
    "res://data/discovery_tour.json",
    "res://data/explorer_items.json",
    "res://data/coursework_quests.json",
    "res://data/campus_links.json",
]

func _ready() -> void:
    if OS.get_cmdline_user_args().has(TEST_FLAG):
        call_deferred("_run_export_test")

func collect_issues() -> Array[String]:
    var issues: Array[String] = []
    var site: UTownWorld = get_parent().get_node_or_null("World") as UTownWorld
    var player: CharacterBody3D = get_parent().get_node_or_null("Player") as CharacterBody3D
    var review: UTownViewReview = get_parent().get_node_or_null("ViewReview") as UTownViewReview
    var tour: UTownTour = get_parent().get_node_or_null("Tour") as UTownTour
    var challenge: UTownChallenge = get_parent().get_node_or_null("Challenge") as UTownChallenge
    var weather: UTownWeather = get_parent().get_node_or_null("Weather") as UTownWeather
    var campus_life: UTownCampusLife = get_parent().get_node_or_null("CampusLife") as UTownCampusLife
    var indoor_npcs: UTownIndoorNPCs = get_parent().get_node_or_null("IndoorNPCs") as UTownIndoorNPCs
    var polish: UTownVisualPolish = get_parent().get_node_or_null("VisualPolish") as UTownVisualPolish
    var coursework: UTownCoursework = get_parent().get_node_or_null("Coursework") as UTownCoursework
    var course_ui: UTownCourseworkUI = get_parent().get_node_or_null("CourseworkUI") as UTownCourseworkUI
    var intro: UTownIntro = get_parent().get_node_or_null("Intro") as UTownIntro
    var hud: CanvasLayer = get_parent().get_node_or_null("HUD") as CanvasLayer

    for source_file in REQUIRED_SOURCE_FILES:
        if not FileAccess.file_exists(source_file):
            issues.append("Missing packaged JSON: " + source_file)
    if site == null:
        issues.append("World node missing")
    else:
        if site.weather_reactive_materials.size() != 2:
            issues.append("Two original walkway/plaza materials are not registered for weather")
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
    if tour == null or tour.stops.size() != 4 or tour.check_in_radius_m <= 0.0:
        issues.append("Four-stop unofficial discovery activity did not load")
    if challenge == null or challenge.items.size() != 8 or challenge.item_markers.size() != 8:
        issues.append("Eight local Field Notes or their runtime markers did not load")
    if challenge != null and challenge.sprint_route.size() != 5:
        issues.append("Campus Sprint did not resolve the four-stop loop and return")
    if weather == null or weather.mode_count() != 5 or weather.rain == null or weather.puddle_nodes.size() < 4 or weather.rain_streaks == null or weather.rain_multimesh.instance_count != 220:
        issues.append("Five-mode weather controller, rain particles, rain streaks or puddles did not load")
    if campus_life == null or campus_life.pedestrians.size() != 6 or campus_life.interiors.size() != 2 or campus_life.shuttle == null:
        issues.append("Campus NPCs, two interior concepts or shuttle did not load")
    if campus_life != null and (campus_life.bicycle_wheels.size() != 2 or campus_life.shuttle_wheels.size() != 4 or campus_life.shuttle_passengers.size() != 3):
        issues.append("Bicycle or shuttle visual components are incomplete")
    if indoor_npcs == null or indoor_npcs.indoor_count != 6:
        issues.append("Six M3.5 fictional indoor occupants are missing")
    if coursework == null or coursework.faculty_options.size() != 13 or coursework.marker == null:
        issues.append("Coursework system requires thirteen faculty options and a waypoint marker")
    if coursework != null:
        var quest_count: int = 0
        for faculty in coursework.faculty_options:
            quest_count += faculty["quests"].size()
        if quest_count != 39:
            issues.append("All 39 original fictional coursework quests must load")
    if course_ui == null or course_ui.faculty_picker == null or course_ui.faculty_picker.item_count != 13:
        issues.append("Faculty selection modal and journal UI are missing")
    if intro == null or intro.cinematic_camera == null or intro.key_frames.size() != 6:
        issues.append("M3.7 camera flyover does not contain six scripted viewpoints")
    if intro != null and (intro.skip_button == null or intro.progress == null or not is_equal_approx(intro.DURATION_S, 12.0)):
        issues.append("M3.7 skippable cinematic UI or duration is missing")
    if polish == null or polish.facade_groups.size() != 2 or polish.facade_panes < 40:
        issues.append("Material-study facade layers missing")
    if polish != null and (polish.indoor_finish_groups.size() != 2 or polish.indoor_lamps.size() != 2 or polish.facade_lamps.size() != 2 or polish.material_panel_count < 100):
        issues.append("Interior cladding and adaptive light fixtures are incomplete")
    if campus_life != null:
        for id in ["ERC", "SRC"]:
            if not campus_life.interiors.has(id):
                continue
            var room: Node3D = campus_life.interiors[id]
            if room.get_node_or_null("InteriorFinishM34/OpaqueRoofShadow") == null:
                issues.append("No sheltered interior roof for " + id)
            if room.get_node_or_null("WalkableStairSlope") == null:
                issues.append("Walkable interior stairs missing for " + id)
            if not campus_life.activity_spots.has(id) or campus_life.activity_spots[id].size() != 3:
                issues.append("Activity zones incomplete for " + id)
    return issues

func _run_export_test() -> void:
    var issues: Array[String] = collect_issues()
    var report_path: String = "user://nus3d-export-smoke.json"
    for option in OS.get_cmdline_user_args():
        if option.begins_with(REPORT_PREFIX):
            report_path = option.substr(REPORT_PREFIX.length())
    var world: UTownWorld = get_parent().get_node_or_null("World") as UTownWorld
    var tour: UTownTour = get_parent().get_node_or_null("Tour") as UTownTour
    var challenge: UTownChallenge = get_parent().get_node_or_null("Challenge") as UTownChallenge
    var weather: UTownWeather = get_parent().get_node_or_null("Weather") as UTownWeather
    var campus_life: UTownCampusLife = get_parent().get_node_or_null("CampusLife") as UTownCampusLife
    var indoor_npcs: UTownIndoorNPCs = get_parent().get_node_or_null("IndoorNPCs") as UTownIndoorNPCs
    var polish: UTownVisualPolish = get_parent().get_node_or_null("VisualPolish") as UTownVisualPolish
    var coursework: UTownCoursework = get_parent().get_node_or_null("Coursework") as UTownCoursework
    var course_ui: UTownCourseworkUI = get_parent().get_node_or_null("CourseworkUI") as UTownCourseworkUI
    var intro: UTownIntro = get_parent().get_node_or_null("Intro") as UTownIntro
    var quests_total: int = 0
    if coursework != null:
        for faculty in coursework.faculty_options:
            quests_total += faculty["quests"].size()
    var results: Dictionary = {
        "schema_version": 1,
        "result": "pass" if issues.is_empty() else "fail",
        "test_target": "exported-game-runtime",
        "provisional_not_surveyed": true,
        "buildings": world.generated_building_count if world != null else 0,
        "facades": world.generated_facade_count if world != null else 0,
        "trees": world.generated_tree_count if world != null else 0,
        "route_waypoints": world.route_points.size() if world != null else 0,
        "tour_stops": tour.stops.size() if tour != null else 0,
        "field_notes": challenge.items.size() if challenge != null else 0,
        "sprint_waypoints": challenge.sprint_route.size() if challenge != null else 0,
        "weather_modes": weather.mode_count() if weather != null else 0,
        "npc_count": campus_life.pedestrians.size() if campus_life != null else 0,
        "interior_count": campus_life.interiors.size() if campus_life != null else 0,
        "shuttle_loaded": campus_life.shuttle != null if campus_life != null else false,
        "puddle_count": weather.puddle_nodes.size() if weather != null else 0,
        "wet_surface_count": world.weather_reactive_materials.size() if world != null else 0,
        "interior_activity_count": 6 if campus_life != null and campus_life.activity_spots.size() == 2 else 0,
        "rain_streak_count": weather.rain_multimesh.instance_count if weather != null and weather.rain_multimesh != null else 0,
        "bicycle_wheels": campus_life.bicycle_wheels.size() if campus_life != null else 0,
        "shuttle_passengers": campus_life.shuttle_passengers.size() if campus_life != null else 0,
        "indoor_npc_count": indoor_npcs.indoor_count if indoor_npcs != null else 0,
        "facade_detail_groups": polish.facade_groups.size() if polish != null else 0,
        "facade_panes": polish.facade_panes if polish != null else 0,
        "interior_material_groups": polish.indoor_finish_groups.size() if polish != null else 0,
        "interior_lighting_rooms": polish.indoor_lamps.size() if polish != null else 0,
        "faculty_options": coursework.faculty_options.size() if coursework != null else 0,
        "coursework_quests": quests_total,
        "faculty_picker_items": course_ui.faculty_picker.item_count if course_ui != null and course_ui.faculty_picker != null else 0,
        "coursework_marker_loaded": coursework.marker != null if coursework != null else false,
        "opening_cinematic_frames": intro.key_frames.size() if intro != null else 0,
        "opening_skip_loaded": intro.skip_button != null if intro != null else false,
        "opening_runtime_seconds": intro.DURATION_S if intro != null else 0.0,
        "shuttle_wheels": campus_life.shuttle_wheels.size() if campus_life != null else 0,
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
