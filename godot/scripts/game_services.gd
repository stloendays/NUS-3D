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
