extends Node

"""Can be used to control a Lander via Keyboard. Currently not in use.
"""

# reference to the Lander scene that this script takes control over
var controlled_lander
# track time in _physics_process, to call the sense() method in regular intervals
var time_since_last_physcall = 0
# only print the fitness after the lander has crashed once
var lander_has_crashed = false
# the fitness of the lander
var fitness = 0
# the actions each output maps to
enum MANEUVER {go_left, go_right, go_up}


func _init(lander_to_control, use_lander_cam = false) -> void:
    """lander_to_control: Lander scene instance
    """
    controlled_lander = lander_to_control
    controlled_lander.connect("death", self, "print_fitness")
    if use_lander_cam:
        controlled_lander.get_node("Camera2D").current = true

func _physics_process(delta):
    """Call the lander.sense() method in regular intervals.
    """
    time_since_last_physcall += delta
    if time_since_last_physcall > 0.5:
        controlled_lander.sense()
        time_since_last_physcall = 0

func _input(event) -> void:
    """By only applying one action per input event, The lander only thrusts once
    per keypress, holding a key does not cause the lander to fire continuously.
    This is intentional, as the AI can also only perform one thrust every time
    the ga.next_timestep() func gets called.
    """
    # default actions. If actions[i] > 0.5, this action will be performed
    var actions = [0, 0, 0]
    # configure the actions array based on player input
    actions[MANEUVER.go_left] = int(event.is_action_pressed("ui_left"))
    actions[MANEUVER.go_right] = int(event.is_action_pressed("ui_right"))
    actions[MANEUVER.go_up] = int(event.is_action_pressed("ui_up"))
    # pass the desired actions to the lander
    controlled_lander.act(actions)


func print_fitness() -> void:
    """Print the fitness points received after landing (or crashing)
    """
    if not lander_has_crashed:
        fitness = controlled_lander.get_fitness()
        lander_has_crashed = true
        print(fitness)
