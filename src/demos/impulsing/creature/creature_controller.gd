extends Node

onready var time = get_parent().time
onready var time_step = get_parent().time_step

var controlled_creature
var print_senses = false

var override_power = 150

func _init(creature_to_control) -> void:
    controlled_creature = creature_to_control
    controlled_creature = creature_to_control
    if override_power > 0:
        controlled_creature.impulse_power = override_power


func _physics_process(delta):
    time += delta
    # if I want to get curent fitness update and reset target
    if Input.is_action_just_pressed("ui_select"):
        # breakpoint
        print("update: %s" % controlled_creature.update_fitness())
        print("total: %s" % controlled_creature.fitness)
        controlled_creature.target.move_by_fraction(4)
    # because input is only checked every time_step, hold down keys to control creature
    if time > time_step:
        if print_senses:
            print(controlled_creature.sense())
        var action = [0, 0, 0, 0]
        action[0] = int(Input.is_action_pressed("ui_up"))
        action[1] = int(Input.is_action_pressed("ui_down"))
        action[2] = int(Input.is_action_pressed("ui_left"))
        action[3] = int(Input.is_action_pressed("ui_right"))
        controlled_creature.act(action)
        time = 0
