extends RefCounted

"""This class builds a neural network that can be used independently without running
the GeneticAlgorithm or Genome nodes, provided it has access to a network
configuration saved under user://network_configs/.
The user has to emulate the behavior of the agent class by simply feeding the update()
method with the array returned by the sense() method on the body, and using the return
value of update() to control the agent with an act() method.
"""

# if set to true, input neurons pass their inputs through the defined activation
# function. If this parameter is not subject to change, CONSIDER REMOVING THE
# CONDITIONAL IN THE UPDATE() FUNCTION.
var activate_inputs = false
# Enumeration for neuron types
enum NEURON_TYPE{input, bias, hidden, output}

# ---- all of these parameters are set once a network config is loaded ----
# Should the network ensure that all inputs have been fully flushed through
# the network (=snapshot), or should it give an output after every neuron has
# been activated once (= active)
var is_runtype_active: bool
# selected activation func
var curr_activation_func: String
# the number of hidden layers in the network.
var depth: int
# flush count is 1 if run_type active, else it is the number of hidden layers.
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

class StandaloneNeuron:
    """A tiny class that is internal to this file to emulate the Neuron Class.
    """
    var input_connections: Array
    var output: float
    var neuron_id: int
    var activation_curve: float

    func _init(n_id: int, curve: float) -> void:
        neuron_id = n_id
        activation_curve = curve

    func connect_input(in_neuron: StandaloneNeuron, weight: float) -> void:
        input_connections.append([in_neuron, weight])


func load_config(network_name: String) -> void:
    """Opens a config saved under user://network_configs/ and updates the properties
    of this script accordingly.
    """
    # open the file specified by the network name, store it in a dict
    var file = FileAccess.open("user://network_configs/%s.json" % network_name, FileAccess.READ)
    # If it exists, open file and parse it's contents into a dict, else push error
    if not file:
        push_error("file not found"); breakpoint
    var test_json_conv = JSON.new()
    test_json_conv.parse(file.get_as_text())
    var network_data = test_json_conv.get_data()
    file.close()
    # generate Neurons and put them into appropriate arrays
    for neuron_data in network_data["neurons"]:
        var neuron = StandaloneNeuron.new(int(neuron_data["id"]), neuron_data["curve"])
        all_neurons[neuron_data["id"]] = neuron
        match int(neuron_data["type"]):
            NEURON_TYPE.input:
                inputs.append(neuron)
            NEURON_TYPE.bias:
                # bias always outputs 1.0
                neuron.output = 1.0
            NEURON_TYPE.hidden:
                hiddens.append(neuron)
            NEURON_TYPE.output:
                outputs.append(neuron)
    # connect links just like in regular NeuralNet class.
    for link_data in network_data["links"]:
        var from_neuron = all_neurons[link_data["from"]]
        var to_neuron = all_neurons[link_data["to"]]
        to_neuron.connect_input(from_neuron, link_data["weight"])
    # extract the rest of the network Metadata
    depth = network_data["depth"]
    is_runtype_active = network_data["runtype_active"]
    curr_activation_func = network_data["activation_func"]
    # set the flush-count and make a Callable for the chosen activation func
    flush_count = 1 if is_runtype_active else depth
    activation_func = Callable(self, curr_activation_func)


static func get_saved_networks() -> Array:
    """Returns an array containing the names of every currently saved network
    """
    var dir = DirAccess.open("user://network_configs")
    # make a new directory for network configs if necessary
    if not dir:
        push_error("no networks saved yet")
        return []
    # only show files
    dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
    # append every file to saved networks array
    var saved_networks = []
    var file_name = "This is just a placeholder"
    while file_name != "":
        file_name = dir.get_next()
        file_name = file_name.rsplit(".", true, 1)[0]
        if file_name != "":
            saved_networks.append(file_name)
    return saved_networks


func update(input_values: Array) -> Array:
    """Pass the input_values to the input neurons, flush the network, and copy the
    values of output neurons into the output array.
    """
    if not (input_values.size() == inputs.size()):
        push_error("Num of inputs not matching num of input neurons"); breakpoint
    # feed the input neurons.
    for i in inputs.size():
        if Params.activate_inputs:
            inputs[i].output = activation_func.call(input_values[i])
        else:
            inputs[i].output = input_values[i]
    # step through every hidden neuron (incl. outputs), sum up their weighted
    # input connections, pass them to activate(), and update the output
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
