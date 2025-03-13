class_name NeatGUI
extends CanvasLayer

"""This node provides the functionality to open window scenes like SpeciesList
and GenomeDetail. New windows are children to this node.
"""

# the two kinds of windows that can currently be displayed
var SpeciesList = preload("res://NEAT_usability/gui/species_list/SpeciesList.tscn")
var GenomeDetail = preload("res://NEAT_usability/gui/genome_detail/GenomeDetail.tscn")

# GUI node is always a child of the ga node
@onready var ga = get_parent()


func _ready() -> void:
    """Immediately opens a new SpeciesList.
    """
    set_name("gui")
    if ga == null:
        push_error("GeneticAlgorithm must be instanced before GUI"); breakpoint
    open_species_list()


func move_window_to_top(node) -> void:
    """Move emitting window to last child pos, therefore rendering it first.
    """
    move_child(node, get_child_count() - 1)


func open_species_list() -> void:
    """Create a new species list and connect ga's made_new_gen signal to it.
    """
    var new_species_list = SpeciesList.instantiate()
    new_species_list.connect("on_load_genome", Callable(self, "open_genome_detail"))
    ga.connect("made_new_gen", Callable(new_species_list, "update_species_list"))
    add_child(new_species_list)


func open_genome_detail(genome: Genome) -> void:
    """Create a new genome detail window (shows connections of the network).
    """
    var new_genome_detail = GenomeDetail.instantiate()
    new_genome_detail.inspected_genome = genome
    add_child(new_genome_detail)
