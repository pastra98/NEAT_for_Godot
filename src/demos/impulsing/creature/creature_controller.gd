extends Node

onready var time = get_parent().time
onready var time_step = get_parent().time_step

var controlled_creature
var print_senses = true


func _init(creature_to_control) -> void:
    controlled_creature = creature_to_control


func _physics_process(delta):
    time += delta
    # because input is only checked every time_step, hold down keys to control creature
    if time > time_step:
        if print_senses:
            print(controlled_creature.sense())
        var action = [0, 0]
        action[0] = int(Input.is_action_pressed("ui_up")) - int(Input.is_action_pressed("ui_down")) 
        action[1] = int(Input.is_action_pressed("ui_left")) - int(Input.is_action_pressed("ui_right"))
        controlled_creature.act(action)
        time = 0
