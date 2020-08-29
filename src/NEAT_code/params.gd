extends Node

"""This singleton holds all parameters that are used by the NEAT algorithm.
Methods for storing and loading configurations are also included.
"""

# -------------------- GA PARAMETERS -------------------- 

# ----- init method
# numbers of inputs and outputs that every neural net will have
var num_inputs: int
var num_outputs: int
# A path to the agent_body - the scene that represents the player, providing the
# sense(), act() and get_fitness() functions. This parameter is set by the user
# when a new GeneticAlgorithm node gets instanced.
var agent_body_path: String

# ----- change visibility of agent bodies
# If rendering costs too much performance, or clutter is to be avoided, agent.body
# nodes can be hidden using ga.update_visibility()
var visibility_options = ["Show all", "Show Leaders", "Show none"]
# the default visibility is an index to the visibility options. 0 = show all
# this setting can be changed during runtime via a species list popup
var default_visibility = 0

# ----- new_generation method
# Number of genomes agents existing at the same time (= one generation)
var population_size = 300
# turn on/off printing info about past generation, when making a new generation
var print_new_generation = true

# ----- create initial population func
# Because starting minimally is a very important factor in NEAT, this parameter
# determines how many input links get a connection to an output link, when creating
# the first set of genomes. My personal experience thus far has shown that this
# is one of the most crucial parameters for good performance. It is important to
# keep this number low, but definitely not too low. 40%-50% of the num of inputs
# is a good target to start with. It should also approach the number of inputs that
# are assumed to be important.
var num_initial_links = 4



# -------------------- GUI PARAMETERS -------------------- 

# ----- general
# If set to true, ga will create a child node that will spawn all gui elements,
# and highlighter will be created for every agent
var use_gui: bool

# ----- highlighter parameters
# enable the highlighter. Highlighter objects are still created if disabled, however
# their toggle is disabled, and they will never be drawn
var is_highlighter_enabled = true
# if the highlighter should be slightly offset, change this here
var highlighter_offset = Vector2(0, 0)
# the radius of the highlighter circle
var highlighter_radius = 100
# the color of the highlighter circle
var highlighter_color = Color.green
# the thickness / width of the highlighter circle
var highlighter_width = 3



# -------------------- GENOME PARAMETERS --------------------

# Probability of skipping crossover generating new genomes
var asex_prob = 0.25
# probability of gene being inherited from the less fit parent. Lower number better.
# THIS IS NOT THE RATE OF SEX-REPRODUCTION. That would be 1 - asex_prob
var crossover_rate = 0.35
# All types of neurons
enum NEURON_TYPE{input, bias, hidden, output}
# default activation curve that neurons are initialized with. tanh default is 2.
# the other defaults can be found in the activation function definitions in the
# neuralnet class.
var default_curve = 2.0

# ----- probabilities of mutations
# probabilities of adding a neuron in mutation func
var prob_add_neuron = [0.05, 0.15]
# probabilities of adding a link between random neurons in mutation func
var prob_add_link = [0.1, 0.3]
# probabilities of adding a looping link (link that connects neuron to itself)
var prob_loop_link = [0.03, 0.1]
# probabilities of adding a direct link (link that directly connects input to output
# neurons). Useful when starting with few links, or when no good Innovations occur.
var prob_direct_link = [0, 0.2]
# probabilities of changing the weight of a link. This mutation is applied on every
# link, meaning about this num reflects the perc. of all links that will be changed
var prob_weight_mut = [0.3, 0.3]
# probabilities of changing the curve of the activation function. Same deal as with
# prob_weight_mut (Applied to every neuron).
var prob_activation_mut = [0.05, 0.05]

# ----- adding neurons
# maximum amount of neurons, for performance reasons. can be set arbitrarily
var max_neuron_amt = 100
# if prevent_chaining is true, only split links that connect to neurons having
# x values of either 0 or 1. This means that networks do not exceed a depth
# of one hidden layer until their amount of neurons exceeds this threshold.
var prevent_chaining = true
var chain_threshold = 3

# ----- adding links
# number of attempts to find a neuron if there is no guarantee one will be found
var num_tries_find_link = 10
# range in which new weights should be initialized
var w_range = 1.0

# ----- mutating link weights
# completely changes weight. This can only happen if the the probability of a
# weight mutation is met. Therefore the prob is prob_weight_mut * prob_weight_replaced 
# also depends on the current mutation rate
var prob_weight_replaced = [0.06, 0.15]
# weight gets increased/decreased by normal distribution. This is it's deviation.
var weight_shift_deviation = 0.4

# ----- mutating neuron activation func
# activation gets increased/decreased by normal distribution. This is it's deviation.
var activation_shift_deviation = 0.3



# -------------------- SPECIES PARAMETERS --------------------

# ----- species performance tracking
# if species start to become stale and don't improve for enough_gens_to_change_things 
# change MUTATION_STATE from normal to heightened. This will cause the second
# probability of the mutation options to be chosen when spawning new members.
var enough_gens_to_change_things = 4
# how many generations should be tolerated without improvement, after that, kill
# the species.
var allowed_gens_no_improvement = 8
# Every mutation has two probabilities associated. This enum just refers to these
# two states.
enum MUTATION_RATE{normal, heightened}

# ----- speciation and compatibility parameters
# coefficients for tweaking the compatibility score
var coeff_matched = 0.6
var coeff_disjoint = 1.2
var coeff_excess = 1.4
# minimum compatibility score for two genomes to be considered in the same species
var species_boundary = 1.3

# ----- fitness sharing parameters
# Params for rewarding/punishing species based on their age
var old_age = 7
var youth_bonus = 1.3
var old_penalty = 0.8

# ----- species update func
# should the species representative be updated, or stay the same for every gen
# If set to true, representative will determined by leader_is_rep,
# If set to false, representative will always be the founding genome
var update_species_rep = true
# If true, species leader is also it's representative. Else just a random member.
var leader_is_rep = false
# Determines what proportion of a species alive members should be considered when
# calling spawn. E.g. 10 members, spawn_cutoff: 0.5 --> pick among top 5 members.
var spawn_cutoff = 0.7
# Before a species reaches this num of members, the pool includes every member
# probably best to set this really high
var selection_threshold = 30
# when crossing over 2 individuals within the pool, pick random parents, or parents
# with similar fitness scores. keeping it false (=based on fitness) seems to yield
# the best results.
var random_mating = false



# -------------------- NEURAL_NET PARAMETERS -------------------- 

# Should the network ensure that all inputs have been fully flushed through
# the network (=snapshot), or should it give an output after every neuron has
# been activated once (= active)
var is_runtype_active = true
# Change the activation function used in the neural network. Curr_activation func
# must be a string that exactly matches one of the activation function definitions,
# since it is directly used as a parameter for creating a funcref in the NeuralNet
# class. Currently implemented activation functions are: "sigm_activate",
# "tanh_activate", "gauss_activate"
var curr_activation_func = "tanh_activate"
# if set to true, input neurons pass their inputs through the defined activation
# function.
var activate_inputs = false

# ----- Network drawing
# colors of neuron types, when displaying a network. Map to NEURON_TYPE enum
var neuron_colors = [Color.turquoise, Color.teal, Color.seashell, Color.tomato]
# When coloring weights, weights >= num are colored red, weights <= are blue, 
# and everything inbetween uses this num as reference.
var weight_max_color = 4



# -------------------- INNOVATION PARAMETERS -------------------- 

# enum referring to the array indices of the data returned by check_new_split()
enum SPLIT_MEMBERS{from_link, neuron_id, to_link}



# ---------------------------------------------------------------
# ------------------ SAVING AND LOADING PARAMS ------------------
# ---------------------------------------------------------------

func load_config(config_name: String) -> void:
    """Loads a config file and resets the properties of Params. Creates a Default
    config if it doesn't exist based on the settings in this file.
    """
    var file = File.new()
    var dir = Directory.new()
    # If no param configs have been saved yet, save the settings from this file as Default
    if dir.open("user://param_configs") == ERR_INVALID_PARAMETER:
        dir.make_dir("user://param_configs")
        save_config("Default")
    # If a non-default config should be loaded, do so now 
    if config_name != "Default":
        # try to open the specified file, break execution if it doesn't exist
        if file.open("user://param_configs/%s.json" % config_name, File.READ) != OK:
            push_error("file not found"); breakpoint
        var configs = parse_json(file.get_as_text())
        # Using str2var, set the saved properties 
        for var_name in configs.keys():
            set(var_name, str2var(configs[var_name]))

func save_config(config_name: String) -> void:
    """Saves the current properties in a dict, and saves the values using var2str
    to allow for saving non-json types like Vector2D and Color. 
    """
    var file = File.new()
    file.open("user://param_configs/%s.json" % config_name, File.WRITE)
    var Params_dict = {}
    for property in get_property_list():
        if get(property.name) != null:
            Params_dict[property.name] = var2str(get(property.name))
    file.store_string(JSON.print(Params_dict, "  "))
    file.close()
