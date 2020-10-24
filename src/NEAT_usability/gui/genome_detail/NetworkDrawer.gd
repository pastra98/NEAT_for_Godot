extends Control

"""Draws a network. The colors of the various neurons can be set in Params.
"""


var roboto = load("res://NEAT_usability/fonts/dynamics/roboto-black.tres")
var neuron_radius = 15
var link_thickness = 2
var max_offset = 150

# scale radius, canvas thickness etc via param?
# remember to add loop links
# neuron draw method
# add typing to draw_link
# use some trig shit to figure out length of offset links

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
            # if there is a link going the same direction from this neuron, or if
            # the link feeds backward or goes vertical, draw the link with an offset
            if from == to:
                draw_loop_link(from, weight)
            else:
                var offset = connection_angles.has(connection_angle) or not from.position.x < to.position.x
                if not offset: connection_angles.append(connection_angle)
                draw_link(from, to, weight, offset, connection_angle)
    # loop over neurons again to draw neurons over the links
    for neuron in neurons_dict.values():
        draw_neuron(neuron)
################################################################################


func draw_link(from, to, weight: float, offset_link: float, angle: float) -> void:
    """
    """
    # the points on the drawing canvas
    var from_draw_pos = from.position * (rect_size - rect_position) + rect_position
    var to_draw_pos = to.position * (rect_size - rect_position) + rect_position
    var weight_color = get_weight_color(weight)
    # draw the link, tip vec is used to draw the arrow at the tip of the link
    var tip_vec: Vector2
    if offset_link:
        var dir_vec = to_draw_pos - from_draw_pos
        # rename turn point
        var turn_point1 = from_draw_pos + dir_vec*0.1 - (dir_vec*0.1).tangent()
        var turn_point2 = turn_point1 + dir_vec*0.8
        draw_line(from_draw_pos, turn_point1, weight_color, link_thickness)
        draw_line(turn_point1, turn_point2, weight_color, link_thickness)
        draw_line(turn_point2, to_draw_pos, weight_color, link_thickness)
        tip_vec = to_draw_pos - turn_point2
    else:
        draw_line(from_draw_pos, to_draw_pos, weight_color, link_thickness)
        tip_vec = to_draw_pos - from_draw_pos
    # draw the arrow
    draw_arrow(tip_vec, to_draw_pos, weight_color)


func draw_loop_link(neuron, weight: float) -> void:
    """
    """
    var draw_pos = neuron.position * (rect_size - rect_position) + rect_position
    var loop_offset = Vector2(-2*neuron_radius, 0)
    var weight_color = get_weight_color(weight)
    draw_arc(draw_pos + loop_offset, 2*neuron_radius, 0, TAU, 20, weight_color, link_thickness)
    draw_arrow(Vector2(0.35,-1), draw_pos, weight_color)


func get_weight_color(weight: float) -> Color:
    """
    """
    # link color strength is determined by how strong the weight  is relative to wmc
    var weight_color = Color(1, 1, 1, 1)
    var wmc = Params.weight_max_color
    var weight_color_str = (wmc - min(abs(weight), wmc)) / wmc
    # color red by decreasing green and blue
    if weight >= 0:
        weight_color.g = weight_color_str; weight_color.b = weight_color_str
    # color blue by decreasing red and green
    elif weight <= 0:
        weight_color.r = weight_color_str; weight_color.g = weight_color_str
    return weight_color


func draw_arrow(tip_vec: Vector2, draw_pos: Vector2, weight_color: Color) -> void:
    """
    """
    var tip_point = draw_pos - tip_vec.normalized()*neuron_radius
    var left_point = tip_point - (tip_vec.normalized()*10).rotated(-PI/6)
    var right_point = tip_point - (tip_vec.normalized()*10).rotated(PI/6)
    var tri_points = PoolVector2Array([tip_point, left_point, right_point])
    var colors = PoolColorArray([weight_color, weight_color, weight_color])
    draw_primitive(tri_points, colors, tri_points)


func draw_neuron(neuron) -> void:
    """
    """
    var neuron_color = Params.neuron_colors[neuron.neuron_type]
    var draw_pos = neuron.position * (rect_size - rect_position) + rect_position
    var char_offset = Vector2((-neuron_radius/3)*len(str(neuron.neuron_id)), neuron_radius/3)
    draw_circle(draw_pos, neuron_radius, neuron_color)
    draw_string(roboto, draw_pos + char_offset, str(neuron.neuron_id), Color.black)
