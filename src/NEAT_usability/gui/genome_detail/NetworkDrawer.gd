extends Control

"""Draws a network. The colors of the various neurons can be set in Params.
"""


var roboto = load("res://NEAT_usability/fonts/dynamics/roboto-black.tres")
var neuron_radius = 6
var link_thickness = 3
var max_offset = 150

# that shit don't work? feed back working?
# remember to add loop links

func _draw():
    """Loops through every neuron and draws it along with it's input connections.
    """
    # get the required information from it's owner (a GenomeDetail)
    # CHANGE INSPECTED GENOME.NEURONS BACK
    var neurons_dict = owner.inspected_genome.all_neurons
    for neuron in neurons_dict.values():
        # holds the angles of links leading from the input neuron. prevent overlapping
        var connection_angles = []
        for link_data in neuron.input_connections:
            var from = neuron
            var to = link_data[0]
            var weight = link_data[1]
            var connection_angle = Vector2(0,1).angle_to(to.position - from.position)
            # offsets the connection parallel if it would overlap with another conn.
            var connection_offset = 0
            # check if the input neuron already has a connection with the same angle
            if connection_angles.has(connection_angle):
                connection_offset = from.position.x - to.position.x * max_offset
            else:
                connection_angles.append(connection_angle)
            #
            draw_link(from, to, weight, connection_offset, connection_angle)
################################################################################
        # finally draw the neuron last, so it overlaps all the links
        var draw_col = Params.neuron_colors[neuron.neuron_type]
        draw_circle(neuron.position * rect_size, 6, draw_col)
        # mark if a loop link is connected to the neuron
        if neuron.loop_back:
            draw_char(roboto, neuron.position * rect_size, "L", "", Color.black)
################################################################################


func draw_link(from, to, weight: float, offset: float, angle: float) -> void:
    """
    """
    # the points on the drawing canvas
    var from_pos = from.position * rect_size
    var to_pos = to.position * rect_size
    # link color strength is determined by how strong the weight  is relative to wmc
    var w_col = Color(1, 1, 1, 1)
    var wmc = Params.weight_max_color
    var w_col_str = (wmc - min(abs(weight), wmc)) / wmc
    # color red by decreasing green and blue
    if weight >= 0:
        w_col.g = w_col_str; w_col.b = w_col_str
    # color blue by decreasing red and green
    elif weight <= 0:
        w_col.r = w_col_str; w_col.g = w_col_str
    # draw the link
    if abs(offset) > 0:
        var angle1 = angle + PI/2 if offset > 0 else angle - PI/2
        var angle2 = -angle1
        draw_line(from_pos, from_pos + Vector2(0,offset).rotated(angle1), w_col, link_thickness)
        draw_line(from_pos + Vector2(0,offset).rotated(angle1), to_pos, w_col, link_thickness)
    else:
        draw_line(from_pos, to_pos, w_col, link_thickness)
