extends Node

"""The SpeciesList is a Simple window that shows a list of every currently active
species along with some basic information about the population.
When clicking on a species, a list of all it's members is loaded, along with further
information about the species. Clicking on a member of the species opens a new
GenomeDetail window.
"""

# various child nodes this scene uses
var content_path = "WindowLayout/SpeciesListContent/ContentSeperator/"
@onready var generation_label = get_node("WindowLayout/InfoContainer/GenInfo")
@onready var visibility_menu = get_node("WindowLayout/InfoContainer/VisMenu")
@onready var member_list = get_node(content_path + "SpeciesDetail/ScrollContainer/MemberList")
@onready var species_info = get_node(content_path + "SpeciesDetail/SpeciesInfo")
@onready var species_list = get_node(content_path + "SpeciesOverview/ScrollContainer/SpeciesList")
@onready var population_info = get_node(content_path + "SpeciesOverview/PopulationInfo")

# the ga node provides the information the species list needs
@onready var ga = get_node("../..")

# variables for displaying text
var default_label_text = "Displaying Generation: "
var selected_gen: int
var default_pop_info = ("[b]Population: %s genomes[/b]\n" +
                        "Current species count: %s\n" +
                        "Fittest species: %s")
var default_spc_info = ("[b]Species %s info[/b]:\n" +
                        "Mutation rate: %s\n" +
                        "Members: %s\n" +
                        "Avg fitness: %s")

# store the species that is currently inspected
var s_species: Species
# save all members of the alive species to a dictionary
var s_species_members: Dictionary
# turn ga.curr_species array into a dictionary
var curr_species_dict: Dictionary

# gets emitted if a genome is selected. Is received by the NeatGUI Node that
# subsequently opens a new GenomeDetail Window.
signal on_load_genome


func _ready() -> void:
    """Generates a new SpeciesList that immediately updates to show current species.
    """
    generation_label.text = default_label_text + str(ga.curr_generation) + " (current)"
    # call loading functions when clicking on species or genome
    species_list.connect("item_selected", Callable(self, "load_species"))
    member_list.connect("item_selected", Callable(self, "load_genome"))
    # add the current visibility options to the visibility_menu popup and connect
    # to ga.change_visibility() method and method that updates text on menu
    for option in Params.visibility_options:
        visibility_menu.get_popup().add_item(option)
    visibility_menu.get_popup().connect("index_pressed", Callable(ga, "update_visibility"))
    visibility_menu.get_popup().connect("index_pressed", Callable(self, "update_vis_menu_text"))
    update_vis_menu_text(ga.curr_visibility)
    # show all current species
    update_species_list()
    

func update_species_list() -> void:
    """Gets called when the made_new_gen new gen signal is emitted by the GA node.
    Updates the list of currently alive species.
    """
    # update the info text about the population.
    var info_text = default_pop_info % [Params.population_size,
                                        ga.curr_species.size(),
                                        ga.best_species.species_id]
    population_info.parse_bbcode(info_text)
    generation_label.text = default_label_text + str(ga.curr_generation)
    # clear the item list, and clear the dictionary of species
    species_list.clear()
    curr_species_dict.clear()
    var species_index = 0
    for species in ga.curr_species:
        if not species.obliterate:
            curr_species_dict[species_index] = species
            species_list.add_item("species_" + species.species_id)
            species_index += 1
    # also bring the member list of the selected species up to date
    if s_species != null:
        update_member_list()


func load_species(species_list_index: int) -> void:
    """Is activated when a species list item is clicked. This method updates the
    selected species variable and calls update_member_list() to show the member
    list of the selected species.
    """
    s_species = curr_species_dict[species_list_index]
    var info_text = default_spc_info % [s_species.species_id,
                                        Params.MUTATION_RATE.keys()[s_species.curr_mutation_rate],
                                        s_species.alive_members.size(),
                                        s_species.avg_fitness]
    species_info.parse_bbcode(info_text)
    update_member_list()


func update_member_list() -> void:
    """This method updates the items of the members list of a species.
    """
    # prevent updating a species that doesn't exist anymore
    if s_species == null:
        return
    # clear the item list and clear the members dictionary
    member_list.clear()
    s_species_members.clear()
    var member_index = 0
    for member in s_species.alive_members:
        s_species_members[member_index] = member
        member_list.add_item("genome_" + str(member.id))
        member_index += 1


func load_genome(member_list_index: int) -> void:
    """Called when a species member is clicked. Emits load genome signal, causing
    the NeatGUI node to open a new genome detail.
    """
    var selected_genome = s_species_members[member_list_index]
    emit_signal("on_load_genome", selected_genome)


func update_vis_menu_text(index: int) -> void:
    """Updates the current visibility text if a different visibility option is chosen.
    """
    visibility_menu.text = "curr visibility: " + Params.visibility_options[index]
