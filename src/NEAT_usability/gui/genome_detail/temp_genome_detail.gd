extends MarginContainer

var inspected_genome

# indicates that a line-edit is currently shown, to prevent adding another
# references to the various child nodes used
var content_path = "WindowLayout/GenomeDetailContent/ContentSeperator"
onready var details = get_node(content_path + "/Details")
onready var highlight_toggle = get_node(content_path + "/HBoxContainer/HighlightToggle")
onready var save_button = get_node(content_path + "/HBoxContainer/SaveNetwork")

# the script that is actually responsible for drawing the network.
onready var network_drawer = get_node(content_path + "/NetworkDrawer")

var StandaloneNetwork = load("res://NEAT_usability/standalone_scripts/standalone_neuralnet.gd")

func _ready() -> void:
    inspected_genome = StandaloneNetwork.new()
    inspected_genome.load_config("test_xor")
    load_inspected_genome(inspected_genome)


func load_inspected_genome(genome_to_inspect: Genome) -> void:
    inspected_genome = genome_to_inspect
    # indicate whether the genome is dead, update the decorator to show the genome's name
    $WindowLayout/Decorator.set_window_name("inspecting saved network 'best xor'")
    # connect a signal to the body of the genome, to indicate when it dies in the decorator
    details.text = "Depth: " + str(inspected_genome.agent.network.depth)
    network_drawer.update()
