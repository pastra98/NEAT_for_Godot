extends Camera2D

"""A simple 2D camera that can pan on left click and zoom using mouse scroll.
"""

var dragging = false

func _unhandled_input(event):
    if event is InputEventMouseButton:
        if event.button_index == BUTTON_RIGHT:
            dragging = true
            if dragging and !event.pressed:
                dragging = false
        elif event.button_index == BUTTON_WHEEL_UP:
            # prevent setting zoom lower than 0.25
            if zoom.x > 0.25:
                zoom -= Vector2(0.25, 0.25)
        elif event.button_index == BUTTON_WHEEL_DOWN:
            zoom += Vector2(0.25, 0.25)
    if event is InputEventMouseMotion and dragging:
        position -= event.relative
