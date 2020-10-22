extends Control

"""Draws a network. The colors of the various neurons can be set in Params.
"""


var roboto = load("res://NEAT_usability/fonts/dynamics/roboto-black.tres")
var neuron_radius = 15
var link_thickness = 3
var max_offset = 150

# scale radius, canvas thickness etc via param?
# remember to add loop links
# neuron draw method
# add typing to draw_link

func _draw():
    """Loops through every neuron and draws it along with it's input connections.
    """
    # get the required information from it's owner (a GenomeDetail)
    # CHANGE INSPECTED GENOME.NEURONS BACK
    var neurons_dict = owner.inspected_genome.neurons
    for neuron in neurons_dict.values():
        # holds the angles of links leading from the input neuron. prevent overlapping
        var connection_angles = []
        for link_data in neuron.input_connections:
            var from = link_data[0]
            var to = neuron
            var weight = link_data[1]
            var connection_angle = Vector2(0,1).angle_to(to.position - from.position)
            # offsets the connection parallel if it would overlap with another conn.
            # check if the input neuron already has a connection with the same angle
            var offset_link = connection_angles.has(connection_angle)
            if not offset_link: connection_angles.append(connection_angle)
            draw_link(from, to, weight, offset_link, connection_angle)
################################################################################
        # finally draw the neuron last, so it overlaps all the links
        var draw_col = Params.neuron_colors[neuron.neuron_type]
        draw_circle(neuron.position * rect_size, neuron_radius, draw_col)
        # mark if a loop link is connected to the neuron
        if neuron.loop_back:
            draw_char(roboto, neuron.position * rect_size, "L", "", Color.black)
################################################################################


func draw_link(from, to, weight: float, offset_link: float, angle: float) -> void:
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
    # draw the link, tip vec is used to draw the arrow at the tip of the link
    var tip_vec: Vector2
    if offset_link:
        var dir_vec = to_pos - from_pos
        var turn_point1 = from_pos + dir_vec * Vector2(0.1, -0.1)
        var turn_point2 = turn_point1 + dir_vec * 0.9
        draw_line(from_pos, turn_point1, w_col, link_thickness)
        draw_line(turn_point1, turn_point2, w_col, link_thickness)
        draw_line(turn_point2, to_pos, w_col, link_thickness)
        tip_vec = to_pos - turn_point2
    else:
        draw_line(from_pos, to_pos, w_col, link_thickness)
        tip_vec = to_pos - from_pos
    # draw the arrow
    draw_arrow(tip_vec, to_pos, w_col)


func draw_arrow(tip_vec: Vector2, to_pos: Vector2, color: Color) -> void:
    """
    """
    var tip_point = to_pos - tip_vec.normalized()*neuron_radius
    var left_point = tip_point - (tip_vec.normalized()*10).rotated(-PI/6)
    var right_point = tip_point - (tip_vec.normalized()*10).rotated(PI/6)
    var tri_points = PoolVector2Array([tip_point, left_point, right_point])
    var colors = PoolColorArray([color, color, color])
    draw_primitive(tri_points, colors, tri_points)
