extends "res://scripts/campus_ai_panel.gd"
class_name NUS3DCampusHub
## Adapter for the existing integration branch's game-shell modal contract.
## GameShell owns pause/resume, account gating and F8. This component owns UI
## and networking only; no gameplay, account, NPC or save-file mutations.

signal close_requested


func open_hub() -> void:
    show()


func close_hub() -> void:
    hide()


func clear_session() -> void:
    # Never allow a response started by one local account to show for another.
    if request_active and chat_request != null:
        chat_request.cancel_request()
    request_active = false
    if send_button != null:
        send_button.disabled = false
    conversation.clear()
    if chat_log != null:
        chat_log.clear()
    if prompt_box != null:
        prompt_box.clear()
    if chat_status != null:
        chat_status.text = ""


func _request_close() -> void:
    close_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
    if not visible or not (event is InputEventKey):
        return
    var key: InputEventKey = event as InputEventKey
    if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
        close_requested.emit()
        get_viewport().set_input_as_handled()
