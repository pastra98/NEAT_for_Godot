class_name Link
extends Reference


"""Because NEAT doesn't have a concept of network layers, neurons are connected via
link objects. The link object however doesn't get used in the final NeuralNet Object,
it merely holds the information that is required by the genome class to perform new
mutations and finally build a new neural network.
"""

# this links innovation id -> places it in a timeline of other Innovations
var innovation_id: int
# the weight associated with this link
var weight: float
# does this link point back in the network
var feed_back: bool
# the id's of the neurons this link connects from and to
var from_neuron_id: int
var to_neuron_id: int
# a link that connects back to the same neuron
var is_loop_link: bool

var enabled = true

func _init(i_id: int,
           w: float,
           feed_b: bool,
           f_neuron: int,
           t_neuron: int,
           is_looped = false) -> void:
    """Create a new link
    """
    innovation_id = i_id
    weight = w
    feed_back = feed_b
    from_neuron_id = f_neuron
    to_neuron_id = t_neuron
    is_loop_link = is_looped


func copy() -> Link:
    """Returns a deep copy of this Link.
    """
    var copy = get_script().new(innovation_id,
                                weight,
                                feed_back,
                                from_neuron_id,
                                to_neuron_id,
                                is_loop_link)
    copy.enabled = self.enabled
    return copy
