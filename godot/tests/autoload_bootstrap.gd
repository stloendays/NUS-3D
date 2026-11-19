extends RefCounted
class_name NUS3DTestAutoloadBootstrap
## CLI --script mode can skip the project's autoload singleton boot.
## Match the normal Godot scene tree names without writing player data.

static func ensure(tree: SceneTree) -> void:
    var root_node: Window = tree.root
    if root_node.get_node_or_null("GameLanguage") == null:
        var language: NUS3DGameLanguage = NUS3DGameLanguage.new()
        language.name = "GameLanguage"
        language.save_path = "user://nus3d-test-locales-%d.cfg" % Time.get_ticks_usec()
        root_node.add_child(language)
    if root_node.get_node_or_null("DialogueBank") == null:
        var dialogue: NUS3DDialogueBank = NUS3DDialogueBank.new()
        dialogue.name = "DialogueBank"
        root_node.add_child(dialogue)
