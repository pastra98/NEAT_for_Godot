extends Control

"""Main menu for interacting with the cars demo. Opens either the CarMain scene
which runs the NEAT algorithm to generate successful drivers, or the CarRaceMain
scene in which it is possible to race against generated NeuralNetworks that have been
saved.
"""

# instance of the standalone_neuralnet used to obtain a list of saved network configurations.
onready var net = load("res://NEAT_usability/standalone_scripts/standalone_neuralnet.gd").new()
# path to the hbox node that contains the buttons used to launch the demos
var options_path = "MarginContainer/VBoxContainer/Options"
# the buttons that open the submenus for setting up Training or a Race
onready var training_button = get_node(options_path + "/TrainingMode")
onready var racing_button = get_node(options_path + "/RacingMode")
# vbox nodes that contain item lists for choosing the track and AI opponents
onready var tracks = get_node(options_path + "/Tracks")
onready var opponents = get_node(options_path + "/Opponents")
# the button that launches the selected demo
onready var start = get_node("MarginContainer/VBoxContainer/Start")
# selected mode is stored as an enum 
enum DEMO_MODE {training, race}
var selected_mode: int


func _ready() -> void:
    """Connect the buttons, populate the itemlists for track and
    opponent selection.
    """
    training_button.connect("pressed", self, "load_training_menu")
    racing_button.connect("pressed", self, "load_racing_menu")
    start.connect("pressed", self, "start_demo")
    # tracks are named 1,2 and 3, the menu refers to them by training difficulty
    for track in ["easy", "medium", "hard"]:
        tracks.get_node("TrackSelect").add_item(track)
    # use the standalone_neuralnet to get a list of all saved network configs
    for config in net.get_saved_networks():
        opponents.get_node("OpponentSelect").add_item(config)


func load_training_menu() -> void:
    """Show the GUI elements used for selecting a track and set the mode to training.
    """
    training_button.hide(); racing_button.hide()
    tracks.show(); start.show()
    selected_mode = DEMO_MODE.training


func load_racing_menu() -> void:
    """Show the GUI elements used for selecting a track and AI opponents, set the
    mode to race.
    """
    training_button.hide(); racing_button.hide()
    tracks.show(); opponents.show(); start.show()
    selected_mode = DEMO_MODE.race


func start_demo() -> void:
    """Load the training or racing scene, and pass the selected track and AI opponents
    to it.
    """
    var track_select = tracks.get_node("TrackSelect")
    # make sure (just one) track is selected
    if not track_select.is_anything_selected() or track_select.get_selected_items().size() > 1:
        start.text = "start - please select [one] track"
        return
    # track scene names are numbered 1,2 and 3. use itemlist index to load track.
    var track_num = track_select.get_selected_items()[0] + 1
    # set up and load the selected scene
    match selected_mode:
        DEMO_MODE.training:
            # scene needs to be instanced in order to pass parameters to it.
            var car_main = load("res://demos/cars/CarMain.tscn").instance()
            # pass the selected track to the instanced scene
            car_main.load_track(track_num)
            # switch to car_main scene instance
            switch_to_instanced_scene(car_main)
        DEMO_MODE.race:
            # instance a racing scene
            var car_race_main = load("res://demos/cars/race_mode/CarRaceMain.tscn").instance()
            # get the selected network configurations from the itemlist
            var opponent_names = []
            for i in opponents.get_node("OpponentSelect").get_selected_items():
                opponent_names.append(opponents.get_node("OpponentSelect").get_item_text(i))
            # pass the selected track and network configurations to the race scene instance
            car_race_main.setup_race(track_num, opponent_names)
            # switch to car_race_main scene instance
            switch_to_instanced_scene(car_race_main)


func switch_to_instanced_scene(scene) -> void:
    """Cannot use change_scene() or change_scene_to() methods because those methods instance
    the given scene themselves. This makes it impossible to pass arguments to them before
    switching. This method simply adds the scene instance as a child, sets it as the current
    scene, and then removes itself (the CarSplash scene) from the tree.
    """
    get_node("/root").add_child(scene)
    get_tree().current_scene = scene
    get_node("/root").remove_child(self)
