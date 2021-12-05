extends Node2D

"""A simple racing 'game' that pits the player against previously saved neural network
configurations.
Demonstrates using the standalone_neuralnet script (see CarAgent class).
"""

# chosen track. Tracks are numbered, however the splashscreen refers to them by difficulty
var curr_track_num: int
# stores the opponent CarAgents (car and a network that controls it)
var opponents = []
# the player is an instance of PlayerCar
var player
# laps to finish the race
var laps_to_complete = 2
# pauses updating the agents
var paused = true
# time since the last agent update
var time = 0
# time between physics steps until agents are updated again
var time_step = 0.2 #Same time as in the training mode
# is displayed either when the player car crashes, or the first car drives laps_to_complete
onready var GameOverSplash = preload("res://demos/cars/race_mode/GameOverSplash.tscn")


func setup_race(track_num: int, opponent_names: Array) -> void:
    """Loads the selected track, places the player into the scene, generates some
    CarAgents (see internal class below), sets up a camera and starts the race.
    """
    curr_track_num = track_num
    # load the selected track, tracks are numbered 1, 2 and 3
    var track_path = "res://demos/cars/tracks/track_%s/Track_%s.tscn" % [track_num, track_num]
    add_child(load(track_path).instance())
    # make a player car instance and adds it to the start
    player = load("res://demos/cars/car/PlayerCar.tscn").instance()
    $Track/PlayerStart.add_child(player)
    # connect a signal to open the game over screen when the player crashes
    player.connect("player_crashed", self, "race_over")
    # generate CarAgents and add them to the track
    add_opponents_to_track(opponent_names)
    # set up a birds-eye-view camera of the track
    var cam = load("res://NEAT_usability/camera/ZoomPanCam.tscn").instance()
    add_child(cam)
    cam.position = $Track/Center.position
    cam.zoom *= 1.3
    cam.make_current()
    # start the race
    paused = false


func add_opponents_to_track(opponent_names: Array) -> void:
    """Generates the car agents based on the network configuration names given in
    opponent_names. The configurations are saved in user//network_configs.
    """
    # reset the opponents array if this is a restarted race
    opponents.clear()
    # generate opponents and add them to the track
    for opponent_name in opponent_names:
        var new_opponent = CarAgent.new(opponent_name)
        opponents.append(new_opponent)
        $Track/Start.add_child(new_opponent.car)


func _physics_process(delta) -> void:
    """Car agents update their networks every time_step seconds, and then drive
    according to the networks output.
    """
    if not paused:
        time += delta
        # update the agents
        if time > time_step:
            # first check if the player has completed the race
            if player.num_completed_laps == laps_to_complete:
                race_over("The player", false)
            # update the agents if they haven't crashed
            for opponent in opponents:
                if not opponent.is_dead:
                    opponent.update()
                    # check if one of the agents has completed the race
                    if opponent.car.num_completed_laps == laps_to_complete:
                        race_over(opponent.car.name, false)
            #Time here must be reset
            time = 0

func race_over(racer_name: String, player_crashed = true) -> void:
    """Open a 'game over' screen and connect a method that restarts the race.
    """
    paused = true
    var game_over_splash = GameOverSplash.instance()
    game_over_splash.initialize(racer_name, laps_to_complete, player_crashed)
    game_over_splash.connect("restart_race", self, "start_new_race")
    add_child(game_over_splash)


func start_new_race() -> void:
    """Instantly remove all child nodes, and call setup_race() with the same args.
    """
    # first store all the opponent names again, so a new race can be set up
    var opponent_names = []
    for opponent in opponents:
        opponent_names.append(opponent.car.name)
    # if the race is restarted, delete all previous children nodes
    for child in get_children():
        #Instead of "==" used "in" cause the instance as different value @tag
        if "GameOverSplash" in child.name:
            child.queue_free()
        else:
            child.free()
    # start a new race
    setup_race(curr_track_num, opponent_names)


class CarAgent:
    """Tiny internal class that allows a neural network to control a car.
    """
    var car: RigidBody2D
    var network
    var laps_to_finish_race: int
    var is_dead = false

    func _init(opponent_name: String) -> void:
        # generate a new car scene and a standalone network
        car = load("res://demos/cars/car/Car.tscn").instance()
        car.name = opponent_name
        car.connect("death", self, "_on_agent_crash")
        network = load("res://NEAT_usability/standalone_scripts/standalone_neuralnet.gd").new()
        network.load_config(opponent_name)

    func update() -> void:
        # get sensory info from the car, feed it to the nn, use the output to steer the car
        var output = network.update(car.sense())
        car.act(output)
    
    func _on_agent_crash() -> void:
        # is kill
        is_dead = true
