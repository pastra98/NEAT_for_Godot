extends Control

"""A simple gui for loading the demos included with this repo.
NOT PART OF THE NEAT TOOLS, EXISTS TO MAKE RUNNING THE DEMOS A BETTER EXPERIENCE.
"""

# The parent node of the buttons that a correspond to loading a demo scene
onready var launchers = $MarginContainer/VBoxContainer/Launchers
# Directory object is used to copy the Params configs included in the repo to the
# user://param_configs/ folder. In a normal project this is not necessary, there
# should be a "Default.cfg" param config in the user://param_configs/ folder as soon
# as the project has been run once. this default config can then be changed and renamed.
onready var dir = Directory.new()


func _ready() -> void:
    """Connect the button signals to appropriate loading methods
    """ 
    launchers.get_node("CarLauncher").connect("pressed", self, "load_car_scene")
    launchers.get_node("LanderLauncher").connect("pressed", self, "load_lander_scene")
    launchers.get_node("XorLauncher").connect("pressed", self, "load_xor_scene")
    launchers.get_node("ImpulseLauncher").connect("pressed", self, "load_impulse_scene")


func load_car_scene() -> void:
    """Copy car params to user://param_configs/ and switch to car menu scene.
    """
    dir.copy("res://demos/cars/car_params.cfg",
             "user://param_configs/car_params.cfg")
    get_tree().change_scene("res://demos/cars/splash_screen/CarSplash.tscn")


func load_lander_scene() -> void:
    """Copy lander params to user://param_configs/ and switch to lander scene.
    """
    dir.copy("res://demos/lunar_lander/lander_params.cfg",
             "user://param_configs/lander_params.cfg")
    get_tree().change_scene("res://demos/lunar_lander/LanderMain.tscn")


func load_xor_scene() -> void:
    """Copy XOR params to user://param_configs/ and switch to XOR scene.
    """
    dir.copy("res://demos/xor/xor_params.cfg",
             "user://param_configs/xor_params.cfg")
    get_tree().change_scene("res://demos/xor/XorMain.tscn")


func load_impulse_scene() -> void:
    """Copy impulse params to user://param_configs/ and switch to impulse scene.
    """
    dir.copy("res://demos/impulsing/impulsing_params.cfg",
             "user://param_configs/impulsing_params.cfg")
    get_tree().change_scene("res://demos/impulsing/ImpulsingMain.tscn")
