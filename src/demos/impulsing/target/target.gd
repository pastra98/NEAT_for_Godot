extends Sprite

var distance_to_spawn = 2000
var dragging = false


func _ready():
    global_position = Vector2(distance_to_spawn, 0)


func move_to_new_pos(flip_side: bool):
    if flip_side:
        global_position = global_position.rotated(PI)
    else:
        global_position = global_position.rotated(Utils.random_f_range(-PI/4, PI/4))


func _unhandled_input(event):
    if event is InputEventKey and event.scancode == KEY_SPACE:
        move_to_new_pos(true)
    elif event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
        dragging = true
        if dragging and !event.pressed:
            dragging = false
    if event is InputEventMouseMotion and dragging:
        position = get_global_mouse_position()
