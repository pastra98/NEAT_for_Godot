extends MarginContainer

"""The basic window script that is used by all window scenes. Allows for dragging
and closing windows. Is connected to the NeatGUI Node to allow focussing the current
window.
"""

signal focus_window

var drag_position = null

func _ready() -> void:
    """connect signal to parent of window (=gui node), to focus window when dragged
    """
    connect("focus_window", owner.get_parent(), "move_window_to_top")


func _on_Decorator_gui_input(event) -> void:
    """Drag the window if the Decorator is clicked.
    """
    if event is InputEventMouseButton and event.button_index == 1:
        if event.pressed:
            # start dragging
            drag_position = get_global_mouse_position() - rect_global_position
            emit_signal("focus_window", owner)
        else:
            # end dragging
            drag_position = null
    # now update the window pos accordingly
    if event is InputEventMouseMotion and drag_position:
        owner.rect_global_position = get_global_mouse_position() - drag_position


func _on_Close_button_down() -> void:
    owner.queue_free()


func set_window_name(name: String) -> void:
    $DecSeperator/WindowName.text = name
