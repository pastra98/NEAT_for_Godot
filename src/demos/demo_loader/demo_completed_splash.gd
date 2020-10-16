extends Control

"""A simple splash screen that obtains some info about the fittest network from the
GeneticAlgorithm node and displays it. Gives the user the options to either return
back to the DemoLoader scene, or set a new fitness threshold.
NOT PART OF THE NEAT TOOLS, EXISTS TO MAKE RUNNING THE DEMOS A BETTER EXPERIENCE.
"""

# The text that is displayed on the splash screen
var info_text = """Fitness of {best_fit}
was reached after {gen} generations.
The evolved solution uses {neurons} neurons,
connected by {links} links.
There were {num_spec} species in the last generation,
with an average population fitness of {avg_fit}.
"""

# is set when initialize is called. Prevents user from entering fitness threshold
# that is lower than the already reached one.
var old_fitness_threshold: float
# obtained from the line edit that is shown when the user chooses to set new threshold
var new_threshold: float
# is emitted when a new valid threshold is entered and confirmed.
signal set_new_threshold


func _ready() -> void:
    """Checks if initialize() has been called and prints the InfoText
    """
    if old_fitness_threshold == null:
        push_error("must call initialize() before adding to tree"); breakpoint
    print($InfoText.text)


func initialize(ga: GeneticAlgorithm, old_threshold: float) -> void:
    """ga = the current GeneticAlgorithm instance, used to obtain info for InfoText.
    old_threshold = current fitness threshold, to make sure a higher one will be entered.
    """
    var splash_info_vars = {
        "best_fit" : ga.curr_best.fitness,
        "gen" : ga.curr_generation,
        "neurons" : ga.curr_best.neurons.size(),
        "links" : ga.curr_best.get_enabled_innovs().size(),
        "num_spec" : ga.curr_species.size(),
        "avg_fit" : ga.avg_population_fitness
    }
    $InfoText.text  = info_text.format(splash_info_vars)
    old_fitness_threshold = old_threshold


func _on_GoBack_pressed() -> void:
    """Return to demo chooser scene.
    """
    get_tree().change_scene("res://demos/demo_loader/DemoLoader.tscn")


func _on_Continue_pressed() -> void:
    """hide GoBack and Resume buttons, show ThresholdSetter and Confirm button
    """
    $GoBack.hide(); $Resume.hide()
    $Confirm.show(); $ThresholdSetter.show()


func _on_Confirm_pressed() -> void:
    """Ensure that the current LineEdit.text is a valid float that is higher than
    the previous fitness threshold. Emits signal if valid threshold is entered.
    """
    var set_threshold = $ThresholdSetter.text
    if set_threshold.is_valid_float():
        set_threshold = float(set_threshold)
        if set_threshold > old_fitness_threshold:
            new_threshold = set_threshold
            emit_signal("set_new_threshold", new_threshold)
            queue_free()
        else:
            $ThresholdSetter.text = "New Threshold must be > than %s" % old_fitness_threshold
    else:
        $ThresholdSetter.text = "Threshold must be a valid float"
