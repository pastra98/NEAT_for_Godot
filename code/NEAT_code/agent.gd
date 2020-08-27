class_name Agent
extends Reference

""" Agents may only be created by the GeneticAlgorithm class. Agents generate the
entity that interacts with the world. This is the agents body. The Agent is also
provided upon its creation a neural network that was coded for by the genome that
generated the agent.

The Agent provides a sort of interface for the GA class to handle all interactions
between the body, controlled by a neural network, and the environment it lives in.

The body must have a method called act(), that uses the outputs of the neural network.
Furthermore a method called sense() must be provided, that returns an array containing
the observations from the environment which are used as inputs to the nn. The third
method that the body must have is called get_fitness(), which returns a POSITIVE
real or integer number that represents how well the agent has acted in this generation.

Lastly, the agent must emit a 'death' signal if it dies.
"""

# the body must be a scene due to the call to instance. If a simple script should
# be used, change instance() to new()
var body = load(Params.agent_body_path).instance()
# Reference to the neural network that is encoded by the genome
var network: NeuralNet

# the fitness only gets assigned when the body dies by calling body.get_fitness()
var fitness = 0
# once set to true the agent can be removed from curr_agents in ga.next_timestep()
var is_dead = false
# the highlighter shows the current location of the body in the world
var highlighter


func _init(neural_net: NeuralNet, is_leader_clone: bool) -> void:
	"""Called by genome.generate_agent(), requires a neural network to work.
	"""
	network = neural_net
	# connect the death signal of the body
	body.connect("death", self, "on_body_death")
	# make a highlighter only if the NEAT GUI is used
	if Params.use_gui:
		highlighter = load("res://NEAT_usability/gui/highlighter.gd").new()
		body.add_child(highlighter)
	# Groups are used to hide and show bodies with the GUI
	body.add_to_group("all_bodies")
	if is_leader_clone:
		body.add_to_group("leader_bodies")


func process_inputs() -> void:
	"""Gets agent sensory information, feeds it to network, and passes
	network output to act method of the agent.
	"""
	var action = network.update(body.sense())
	body.act(action)


func on_body_death() -> void:
	"""Marks the agent as dead, assigns the fitness, and removes it from all groups
	"""
	is_dead = true
	fitness = body.get_fitness()
	# remove body from groups to make sure it receives no calls from change_visibility
	for group in body.get_groups():
		if group in ["all_bodies", "leader_bodies"]:
			body.remove_from_group(group)


func enable_highlight(enabled: bool) -> void:
	"""Used to show or hide the highlighter.
	"""
	if Params.is_highlighter_enabled:
		if body != null:
			if enabled:
				highlighter.show()
			else:
				highlighter.hide()
