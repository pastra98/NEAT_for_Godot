extends Control

"""Draws a network. The colors of the various neurons can be set in Params.
"""


# the font used
var roboto = load("res://NEAT_usability/fonts/dynamics/roboto-black.tres")

func _draw():
	"""Loops through every neuron and draws it along with it's input connections.
	"""
	# get the required information from it's owner (a GenomeDetail)
	var depth = owner.inspected_genome.agent.network.depth
	var neurons_dict = owner.inspected_genome.neurons
	for neuron_id in neurons_dict.keys():
		# determine the position of the neuron on the canvas and it's color
		var neuron = neurons_dict[neuron_id]
		var draw_pos = neuron.position * rect_size
		var draw_col = Params.neuron_colors[neuron.neuron_type]
		# first draw all links connecting to the neuron
		for link in neuron.input_connections:
			# color strength is determined by how strong weight relative to wmc
			var w_col = Color(1, 1, 1, 1)
			var wmc = Params.weight_max_color
			var w_col_str = (wmc - min(abs(link[1]), wmc)) / wmc
			# color red by decreasing green and blue
			if link[1] >= 0:
				w_col.g = w_col_str; w_col.b = w_col_str
			# color blue by decreasing red and green
			elif link[1] <= 0:
				w_col.r = w_col_str; w_col.g = w_col_str
			# draw links as tris to indicate their firing direction
			var in_pos = link[0].position * rect_size
			var spacing = Vector2(0, 5)
			var tri_points = PoolVector2Array([in_pos+spacing, draw_pos, in_pos-spacing])
			var colors = PoolColorArray([Color.white, w_col, Color.white])
			draw_primitive(tri_points, colors, tri_points)
		# finally draw the neuron last, so it overlaps all the links
		draw_circle(draw_pos, 6, draw_col)
		# mark if a loop link is connected to the neuron
		if neuron.loop_back:
			draw_char(roboto, draw_pos, "L", "", Color.black)
