extends Node2D

"""This demo has landers dropped above a lunar landscape, where they have to navigate
to a suitable landing spot using their thrusters. They must slow down their descent
to perform a soft landing while not exhausting their fuel reserves.
"""

# 1.0 = one second. time gets reset every time_step, then all agents get updated
var time = 0
# total_time gets reset every time a new generation is started
var total_time = 0
# every time_step the landers network takes sensory information and decides how to act
@export var time_step = 0.1
# if a lander gets stuck stuck without crashing or landing, this ensures that a
# generation can only last for up to a minute
var max_generation_time = 60


# initialize the main node that handles the genetic algorithm with 6 inputs, 3 outputs,
# the path to the lander scene, enable the NEAT_Gui, and use the lander_params
# parameters, which are saved under user://param_configs
var agent_body_path = "res://demos/lunar_lander/Lander/Lander.tscn"
var ga = GeneticAlgorithm.new(6, 3, agent_body_path, true, "lander_params")

# if the current generation matches a key, the dropping location of the landers,
# along with the force which the landers receive as an initial impulse on the x axis
# get changed.
@onready var training_program = {
    1 : [$Moon/DropoffLocation1, 0],
    5 : [$Moon/DropoffLocation1, 45],
    15 : [$Moon/DropoffLocation1, 90],
    25 : [$Moon/DropoffLocation2, 90],
    35 : [$Moon/DropoffLocation2, 135],
    40 : [$Moon/DropoffLocation3, 135],
    50 : [$Moon/DropoffLocation3, 180]
}
# drop landers for the first 15 generations from Location 1 with no initial impulse
@onready var curr_training = training_program[1]

func _ready() -> void:
    """Add the GeneticAlgorithm Node as a child, obtain the lander instances generated
    by ga, and place them at the current dropoff location in the moon scene.
    """
    add_child(ga)
    place_bodies(ga.get_curr_bodies())


func _physics_process(delta):
    """Lander agents update their networks every time_step seconds, and then fire
    their thrusters according to the networks output. Once all landers have either
    crashed or landed, (or max_generation_time is reached) a new generation is started.
    """
    # update time since last update
    time += delta; total_time += delta
    # if enough time has passed for the next time_step, update all agents
    if time > time_step:
        time = 0
        ga.next_timestep()
    # if all landers have landed/crashed or too much time has passed, start a new gen
    if ga.all_agents_dead or total_time > max_generation_time:
        total_time = 0
        ga.evaluate_generation()
        ga.next_generation()
        # update the parameters for the lander placement
        if training_program.has(ga.curr_generation):
            curr_training = training_program[ga.curr_generation]
        # place the bodies in the moon scene
        place_bodies(ga.get_curr_bodies())


func place_bodies(new_bodies: Array) -> void:
    """Remove all Lander instances from the previous gen, place the new landers
    at the current dropoff point, and apply an impulse on the x axis.
    """
    var curr_dropoff_point = curr_training[0]
    # remove all old bodies
    for body in curr_dropoff_point.get_children():
        body.queue_free()
    # add the new bodies 
    for body in new_bodies:
        curr_dropoff_point.add_child(body)
        # give the landers a random impulse on the x axis
        var x_push = Utils.random_i_range(-curr_training[1], curr_training[1])
        var push_vec = Vector2(x_push, 0)
        body.apply_central_impulse(push_vec)
