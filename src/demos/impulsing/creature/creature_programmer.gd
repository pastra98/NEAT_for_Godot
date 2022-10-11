extends Node

onready var time = get_parent().time
onready var time_step = get_parent().time_step

var print_stuff = true

var controlled_creature
var network


func _init(creature_to_control, network_instance) -> void:
    controlled_creature = creature_to_control
    network = network_instance


func _physics_process(delta):
    time += delta
    # because input is only checked every time_step, hold down keys to control creature
    if time > time_step:
        var senses = controlled_creature.sense()
        var action = network.update(senses)
        controlled_creature.act(action)
        if print_stuff:
            print(senses)
            print(action)
            print()
        time = 0
