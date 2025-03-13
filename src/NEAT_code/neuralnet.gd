class_name NeuralNet
extends RefCounted

"""This class builds a neural network with a very simple update() function which
takes in an array of inputs with a fixed size and returns outputs of a fixed size.
The usable activation functions are found below.
A method for saving the network configuration to json format is also provided,
making it possible to create a new standalone neural network object later on.
"""

# the number of hidden layers in the network.
var depth: int
# flush count is 1 if active run type, else it is the number of hidden layers.
var flush_count: int
# variables for the neurons in this network.
var all_neurons: Dictionary
var inputs = []
var hiddens = []
var outputs = []
# the output that will be returned by the network.
var output = []
# the currently used activation func, determined by the Params class.
var activation_func: Callable
# Contains all links in the genome. Only needed during save_to_json.
var enabled_links: Array


func _init(neurons: Dictionary, links: Dictionary) -> void:
    """When the network gets initialized, the neuron and link data from the genome
    class is used to build a neural network object by assigning neuron genes to
    variables that enable accessing them in update() function.
    Most importantly neuron genes get references to their connecting neurons via
    reading the link genes and using the connect_input() function to build the nested
    inputs array in the Neuron class.
    """
    all_neurons = neurons
    # assign neurons to arrays based on their type
    for neuron in all_neurons.values():
        # make sure neuron gene has no inputs from parent links (because it is a copy)
        neuron.input_connections.clear()
        # insert neurons into matching arrays based on type
        match neuron.neuron_type:
            Params.NEURON_TYPE.input:
                inputs.append(neuron)
            Params.NEURON_TYPE.bias:
                # bias always outputs 1.0
                neuron.output = 1.0
            Params.NEURON_TYPE.hidden:
                hiddens.append(neuron)
            Params.NEURON_TYPE.output:
                outputs.append(neuron)
    # connect all neurons using the information stored in the link genes
    enabled_links = []
    for link in links.values():
        if link.enabled:
            enabled_links.append(link)
            var from_neuron = all_neurons[link.from_neuron_id]
            var to_neuron = all_neurons[link.to_neuron_id]
            # register the from_neuron as an input of the to_neuron
            to_neuron.connect_input(from_neuron, link.weight)
    # sort neurons such that they are evaluated left to right, feed_back
    # and loop_back connections are however still delayed (that is desired)
    hiddens.sort_custom(Callable(self, "sort_neurons_by_pos_x"))
    hiddens.sort_custom(Callable(self, "sort_neurons_by_pos_y"))
    # if networks run on active, every neuron is updated once per update(), if they
    # run snapshot, every n. is activ. often enough until inp. is flushed to outputs
    depth = calculate_depth(hiddens)
    flush_count = 1 if Params.is_runtype_active else depth
    # set a Callable to the activation func that will be used
    activation_func = Callable(self, Params.curr_activation_func)


func update(input_values: Array) -> Array:
    """Pass the input_values to the input neurons, loop through every neuron once
    and sum up it's input neurons multiplied by their weight.
    If the runtype of the network is snapshot (used for classification tasks) there
    will be enough passes over the neurons in the network until the input values
    have been passed to every neuron and they can be read from the output.
    Finally return the values of output neurons.
    """
    # happens if the ga node is initialized with the wrong amount of inputs and outputs
    if not (input_values.size() == inputs.size()):
        push_error("Num of inputs not matching num of input neurons"); breakpoint
    # feed the input neurons.
    for i in inputs.size():
        if Params.activate_inputs:
            inputs[i].output = activation_func.call(input_values[i])
        else:
            inputs[i].output = input_values[i]
    # step through every hidden neuron (incl. outputs), sum up their weighted
    # input connections, pass them to activate(), and update their output
    for _flush in flush_count:
        for neuron in hiddens + outputs:
            var weighted_sum = 0
            for connection in neuron.input_connections:
                var input_neuron = connection[0]; var weight = connection[1]
                weighted_sum += input_neuron.output * weight
            neuron.output = activation_func.call(weighted_sum, neuron.activation_curve)
    # copy output of output neurons into output array
    output.clear()
    for out_neuron in outputs:
        output.append(out_neuron.output)
    return output


func save_to_json(name: String) -> void:
    """Saves the network configuration in json format under user://network_configs/
    """
    var network_data = {}
    network_data["network_name"] = name
    # save information about the used activation func and network depth
    network_data["activation_func"] = Params.curr_activation_func
    network_data["runtype_active"] = Params.is_runtype_active
    network_data["depth"] = depth
    # Save all neurons in sorted order
    var sorted_neurons = all_neurons.values()
    sorted_neurons.sort_custom(Callable(self, "sort_neurons_by_pos_x"))
    sorted_neurons.sort_custom(Callable(self, "sort_neurons_by_pos_y"))
    var neuron_data = []
    for neuron in sorted_neurons:
        var neuron_save = {
            "id" : neuron.neuron_id,
            "curve" : neuron.activation_curve,
            "type" : neuron.neuron_type,
        }
        neuron_data.append(neuron_save)
    network_data["neurons"] = neuron_data
    # Next save every link in a dictionary format.
    var link_data = []
    for link in enabled_links:
        var link_save = {
            "from" : link.from_neuron_id,
            "to" : link.to_neuron_id,
            "weight" : link.weight
        }
        link_data.append(link_save)
    network_data["links"] = link_data
    # now save the dictionary as a json file in the user path
    var dir = DirAccess.open("user://network_configs")
    if not dir:
        DirAccess.make_dir_absolute("user://network_configs")
    # save the network in the network directory
    var file = FileAccess.open("user://network_configs/%s.json" % name, FileAccess.WRITE)
    file.store_string(JSON.stringify(network_data, "  "))
    file.close()


func sort_neurons_by_pos_x(neuron1, neuron2) -> bool:
    """Order neurons according to their x position in the network.
    """
    return neuron1.position.x < neuron2.position.x

func sort_neurons_by_pos_y(neuron1, neuron2) -> bool:
    """Order neurons according to their x position in the network.
    """
    return neuron1.position.y < neuron2.position.y

static func calculate_depth(sorted_hiddens: Array) -> int:
    """Calculate the number of hidden layers by counting the number of neurons with
    unique x positions.
    """
    var network_depth = 1
    for i in sorted_hiddens.size():
        if sorted_hiddens[i].position.x > sorted_hiddens[i-1].position.x:
            network_depth += 1
    return network_depth

# --------------- Activation Functions ---------------

static func tanh_activate(weighted_sum: float, activation_modifier: float) -> float:
    """Standard tanh activation_modifier would be 2. Outputs range -1 to 1.
    """
    return (2 / (1 + exp(-weighted_sum * activation_modifier))) - 1


static func sigm_activate(weighted_sum: float, activation_modifier: float) -> float:
    """Standard sigmoid activation_modifier would be 1. Outputs range 0 to 1.
    """
    return (1 / (1 + exp(-weighted_sum * activation_modifier)))


static func gauss_activate(weighted_sum: float, activation_modifier: float) -> float:
    """Gaussian function. Outputs range 0 to 1.
    """
    return exp(-(pow(weighted_sum, 2) / (2 * pow(activation_modifier, 2))))
