extends RefCounted
class_name NUS3DServices
## The exported game uses project autoloads; standalone SceneTree smoke runners use this
## idempotent bootstrap so Godot --script can resolve the same offline services.
static func ensure_scene_services(tree: SceneTree) -> void:
    var root: Window = tree.root
    if root.get_node_or_null("GameLanguage") == null:
        var language: NUS3DGameLanguage = NUS3DGameLanguage.new()
        language.name = "GameLanguage"
        root.add_child(language)
    if root.get_node_or_null("DialogueBank") == null:
        var dialogue: NUS3DDialogueBank = NUS3DDialogueBank.new()
        dialogue.name = "DialogueBank"
        root.add_child(dialogue)
    if root.get_node_or_null("UISound") == null:
        var sound: NUS3DUISound = NUS3DUISound.new()
        sound.name = "UISound"
        root.add_child(sound)

## Dedicated helper for feature smokes: the normal player must watch or skip
## the opening film and choose a faculty. No production game path calls this.
static func enter_test_playmode(game: Node3D) -> void:
    var intro: Node = game.get_node_or_null("Intro")
    if intro != null and intro.has_method("skip_intro"):
        intro.call("skip_intro")
    var coursework: Node = game.get_node_or_null("Coursework")
    if coursework != null:
        coursework.set("save_path", "user://nus3d-qa-coursework-%d.cfg" % Time.get_ticks_usec())
        coursework.call("_load_progress")
        coursework.call("select_faculty", "science")
    var picker: Node = game.get_node_or_null("CourseworkUI")
    if picker != null and picker.has_method("hide_modal"):
        picker.call("hide_modal")
