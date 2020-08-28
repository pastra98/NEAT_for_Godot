extends Node

"""This Singleton is responsible for tracking every new kind of link and neuron, and
assigning an innovation_id to new links or a neuron_id to new neurons.
Whether a link is a new innovation depends not on it's weight configuration, but
rather on the neurons it connects to. Eg. if a direct link between an input and
output neuron has never before been split in any other genome, this is a new
innovation, and so is the neuron that was created in the split.
"""

# the current id's for new neurons and links
var innovation_id = 0
var neuron_id = 0

# link keys consist of neuron_id--->neuron_id, their value is the innov_id of the link
var links_db = {}
# neuron keys are the neuron_id of the neuron, the value is the type of the stored neuron
var neuron_db = {}
# split keys consist of neuron_id-x->neuron_id, their value is an array containing the
# neuron_id's and innovation_id of the new links and neurons. See params.SPLIT_MEMBERS
var splits_db = {}


func store_neuron(neuron_type: int) -> int:
    """This method is only accessed directly, when creating the initial population.
    If a hidden neuron is created using the split mutation, this func gets called
    by check_new_link(), to register that Neuron. Always returns the new neuron id.
    """
    neuron_id += 1; neuron_db[neuron_id] = neuron_type
    return neuron_id


func check_new_split(from_neuron_id: int, to_neuron_id: int) -> Array:
    """Checks if a link between the from neuron and to neuron has been split before,
    if not, new id's are created for the new links and neuron, and this split data
    gets returned. Else the id's of the already existing links and neurons are returned.
    """
    # generate the split id, and check if the split already exists
    var split_id = str(from_neuron_id) + "-x->" + str(to_neuron_id)
    if splits_db.has(split_id):
        var split_data = splits_db[split_id]
        return split_data
    # If this split is new, create 2 new link Innovations, and one new neuron
    else:
        var split_neuron_id = store_neuron(Params.NEURON_TYPE.hidden)
        var link1_innov_id = store_link(from_neuron_id, split_neuron_id)
        var link2_innov_id = store_link(split_neuron_id, to_neuron_id)
        # store everything in a split_data array, store it, and return it
        var split_data = [link1_innov_id, split_neuron_id, link2_innov_id]
        splits_db[split_id] = split_data
        return split_data


func store_link(from_neuron_id: int, to_neuron_id: int) -> int:
    """Only called by check check_new_split and check_new_link. Pushes an error
    if the link_id already exists.
    """
    var link_id = str(from_neuron_id) + "--->" + str(to_neuron_id)
    if links_db.has(link_id):
        push_error("Attempting to store a link that already exists")
    innovation_id += 1
    links_db[link_id] = innovation_id
    return innovation_id


func check_new_link(from_neuron_id: int, to_neuron_id: int) -> int:
    """Called when the genome creates a new link. Checks if a link between from
    and to neuron has been created already, if so, return it's innovation id, else
    return the innovation id of the already existing link.
    """
    var link_id = str(from_neuron_id) + "--->" + str(to_neuron_id)
    if links_db.has(link_id):
        return links_db[link_id]
    # store a new link in the db, and return it's innovation id
    else:
        var new_innov_id = store_link(from_neuron_id, to_neuron_id)
        return new_innov_id
