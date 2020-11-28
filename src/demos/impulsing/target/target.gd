extends Sprite

var distance_to_spawn = 2000


func _ready():
    global_position = Vector2(distance_to_spawn, 0)


func move_to_new_pos():
    global_position = global_position.rotated(Utils.random_f_range(-PI/4, PI/4))


func _unhandled_key_input(event):
    if event.scancode == KEY_SPACE:
        move_to_new_pos()
