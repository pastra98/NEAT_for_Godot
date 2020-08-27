class_name Neuron
extends Reference

"""Neurons are created when a new population of genomes is created in
ga.create_initial_population(), or when an existing link between neurons is split.
They contain information about their spatial position in the network, whether they
are connected to themselves via a link (loop_back) and how they change the curve of
their activation function.
The class stores an array of input_connections that holds references to the other
neurons a neuron connects to, along with the associated weight, but the array is
only filled using the connect_input() method when a new network gets built.
"""

# the neuron id is determined by the Innovations singleton
var neuron_id: int
# See Params.NEURON_TYPE enum how the id is mapped
var neuron_type: int
# the spatial position is used for drawing the network, determining the depth of
# the network, and checking whether a link feeds backwards.
var position: Vector2
# activation functions can be modified using a Neurons activation_curve property
var activation_curve: float
# set to true if this neuron has a link that connects back to itself
var loop_back: bool

# Array consisting of an input neuron[0], and it's associated weight[1]
var input_connections: Array

# these vars are only used once the network starts updating
var activation_sum: float
var output: float

func _init(n_id: int,
		   type: int,
		   pos: Vector2,
		   curve: float,
		   loop: bool) -> void:
	"""Generate a new neuron
	"""
	neuron_id = n_id
	neuron_type = type
	position = pos
	activation_curve = curve
	loop_back = loop


func copy() -> Neuron:
	"""Returns a deep copy of this Neuron.
	"""
	var copy = get_script().new(neuron_id,
								neuron_type,
								position,
								activation_curve,
								loop_back)
	return copy


func connect_input(in_neuron: Neuron, weight: float) -> void:
	"""Stores a new input connection to the neuron.
	"""
	var have_neuron = false
	for input in input_connections:
		if input[0].neuron_id == in_neuron.neuron_id:
			have_neuron = true; break
	if not have_neuron:
		input_connections.append([in_neuron, weight])
