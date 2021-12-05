extends MarginContainer

"""A simple window that shows a graphical representation of the network (using the
NetworkDrawer script). It also provides the ability to save a network.
"""

# reference to the genome that is to be drawn. MUST BE SET BEFORE THIS NODE IS
# INSERTED INTO THE TREE
var inspected_genome: Genome
# indicates that a line-edit is currently shown, to prevent adding another
var save_dialogue_shown = false
# line edit to set the name of a saved network. Added when save network is clicked
var name_chooser: LineEdit

# references to the various child nodes used
var content_path = "WindowLayout/GenomeDetailContent/ContentSeperator"
onready var details = get_node(content_path + "/Details")
onready var highlight_toggle = get_node(content_path + "/HBoxContainer/HighlightToggle")
onready var save_button = get_node(content_path + "/HBoxContainer/SaveNetwork")

# the script that is actually responsible for drawing the network.
onready var network_drawer = get_node(content_path + "/NetworkDrawer")


func _ready() -> void:
    """If the inspected_genome property is set, the scene is instanced, causing
    the network_drawer to be updated, and therefore drawing the network.
    """
    if inspected_genome == null:
        push_error("set inspected_genome property before adding to tree"); breakpoint
    # turn on the highlighter by default
    if Params.is_highlighter_enabled:
        _on_HighlightToggle_toggled(true)
    # disable the highlighter if this is saved in the Params
    else:
        highlight_toggle.pressed = false
        highlight_toggle.disabled = true
    # indicate whether the genome is dead, update the decorator to show the genome's name
    var dead = "[dead] " if inspected_genome.agent.is_dead else ""
    $WindowLayout/Decorator.set_window_name("inspecting genome nr. " + dead +
                                            str(inspected_genome.id))
    # connect a signal to the body of the genome, to indicate when it dies in the decorator
    inspected_genome.agent.body.connect("death", self, "mark_agent_dead")
    # lastly show the depth of the network and draw it
    details.text = "Depth: " + str(inspected_genome.agent.network.depth)
    network_drawer.update()


func update_inspected_genome(new_genome: Genome) -> void:
    """Show a new genome in the same detail window.
    """
    inspected_genome = new_genome
    # indicate whether the genome is dead, update the decorator to show the genome's name
    var dead = "[dead] " if inspected_genome.agent.is_dead else ""
    $WindowLayout/Decorator.set_window_name("inspecting genome nr. " + dead +
                                            str(inspected_genome.id))
    # lastly show the depth of the network and draw it
    details.text = "Depth: " + str(inspected_genome.agent.network.depth)
    network_drawer.update()


func mark_agent_dead() -> void:
    """updates the window title if the agent has died
    """
    $WindowLayout/Decorator.set_window_name("inspecting genome nr. [dead] " +
                                            str(inspected_genome.id))
    _on_HighlightToggle_toggled(false)


func _on_SaveNetwork_button_down() -> void:
    """Expands the window to show a line edit where the user can enter a name to
    save the network. When clicked a second time, the network gets saved under the
    specified name, and the line edit disappears.
    """
    if not save_dialogue_shown:
        save_dialogue_shown = true
        # make a new line edit
        name_chooser = LineEdit.new()
        # The default name for a saved genome consists of the current time +
        # the genome id to avoid duplicates
        var time = OS.get_time()
        var time_str = "%0*d"%[2, time["hour"]]+"_"+"%0*d"%[2, time["minute"]]+"__"
        name_chooser.text = time_str + str(inspected_genome.id)
        # change the save button text to show that pressing again will confirm save
        save_button.text = "Confirm Save"
        # add the new line edit as a child
        get_node(content_path).add_child(name_chooser)
    else:
        save_dialogue_shown = false
        # save the network under the chosen name
        inspected_genome.agent.network.save_to_json(name_chooser.text)
        # reset the save button text and remove the line edit again
        save_button.text = "Save Network"
        get_node(content_path).get_child(get_child_count() + 1).queue_free()


func _on_HighlightToggle_toggled(enabled) -> void:
    """Calls the agent.enable_highlight func with the current value of the toggle
    """
    inspected_genome.agent.enable_highlight(enabled)


func _exit_tree() -> void:
    """Disable the highlighter if the window gets closed.
    """
	if !inspected_genome.agent.is_dead:
		inspected_genome.agent.enable_highlight(false)
	else:
		inspected_genome = null
