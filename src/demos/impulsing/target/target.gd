extends Sprite

var distance_to_spawn = 500
var dragging = false


func _ready():
    global_position = Vector2(distance_to_spawn, 0)


func move_to_new_random_pos(flip_side: bool):
    if flip_side:
        global_position = global_position.rotated(PI)
    else:
        global_position = global_position.rotated(Utils.random_f_range(-PI/4, PI/4))


func move_by_fraction(fraction: int):
    global_position = global_position.rotated(TAU/fraction)
    


func _unhandled_input(event):
    # use r to move target to new random pos
    if event is InputEventKey and event.scancode == KEY_R:
        move_to_new_random_pos(true)
    # drag target with mouse
    elif event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
        # breakpoint
        dragging = true
        if dragging and !event.pressed:
            dragging = false
    if event is InputEventMouseMotion and dragging:
        position = get_global_mouse_position()
