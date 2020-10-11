class_name Genome
extends Reference

"""The Genome Class encodes the neurons and links that make up a Neural Network.
It provides the functionality to mutate itself, make a copy of itself and all it's
neurons and links, and it has a method to be combined with another genome.
"""

# the agent is only assigned once generate_agent() gets called
var agent: Agent
# the name of the genome, and the name of the species it belongs to
var genome_id: int
var species_id: String
# a dictionary of every neuron in the genome, keys are the neurons ids
var neurons: Dictionary
# a dictionary of every link in the genome, keys are the innovation ids
var links: Dictionary
# fitness is assigned during ga.finish_current_agents()
var fitness: float
# the adjusted fitness takes into account the age bonus/punishment that the genomes
# species currently has
var fitness_adjusted: float
# only true if the genome is a clone of it's species leader, see ga.next_generation()
var is_leader_clone = false


func _init(id: int, initial_neurons: Dictionary, initial_links: Dictionary) -> void:
    """Generate a new genome, this should not be called outside of the NEAT code
    """
    genome_id = id
    neurons = initial_neurons
    links = initial_links


func mutate(mutation_rate: int) -> void:
    """Mutates the genome according to the current parameters
    """
    if Utils.random_f() < Params.prob_add_link[mutation_rate]:
        add_link()
    if Utils.random_f() < Params.prob_loop_link[mutation_rate]:
        add_loop_link()
    if Utils.random_f() < Params.prob_direct_link[mutation_rate]:
        add_direct_link()
    if Utils.random_f() < Params.prob_disable_link[mutation_rate] and not links.empty():
        disable_link()
    if Utils.random_f() < Params.prob_add_neuron[mutation_rate] and not links.empty():
        add_neuron()
    mutate_weights(mutation_rate)
    mutate_activation_response(mutation_rate)


func add_link() -> void:
    """Tries to find 2 neurons to connect. A new link gene gets appended, and the
    innovation db either registers a new id, or returns existing one. If the connection
    already exists, nothing happens. Note that this method can also create direct
    connections, among all other possible connections, EXCLUDING loop links.
    """
    for _try in Params.num_tries_find_link:
        # the two neurons that are going to be connected
        var from: Neuron = Utils.random_choice(neurons.values())
        var to: Neuron = Utils.random_choice(neurons.values())
        # Neuron 2 should not be input(0) or bias(1) -> don't connect two inputs or bias.
        # Also don't produce a loop_back link, and if enabled, prevent feed-back links
        if (not (to == from or to.neuron_type in [0, 1]) and
            not (Params.no_feed_back and to.position.x < from.position.x)):
            # get the innovation id of this link, prevent adding duplicate links
            var innov_id = Innovations.check_new_link(from.neuron_id, to.neuron_id)
            # check if the link has already been made
            if not links.has(innov_id):
                # determine whether the link is pointing backwards
                var is_feed_back = true if from.position.x > to.position.x else false
                # generate the new link, and connect it to both neurons
                var new_link = Link.new(innov_id,
                                        Utils.gauss(Params.w_range),
                                        is_feed_back,
                                        from.neuron_id,
                                        to.neuron_id)
                links[innov_id] = new_link
                return


func add_loop_link() -> void:
    """Tries to find a neuron that is not of type input or bias, and then connect a
    link to itself, causing the previous output to be fed back in again. If no
    suitable neuron is found, no loop link gets added.
    """
    for _try in Params.num_tries_find_link:
        var loop_neuron = Utils.random_choice(neurons.values())
        # check if neuron is not already looping back or of type input(0) or bias(1)
        if not (loop_neuron.loop_back or loop_neuron.neuron_type in [0, 1]):
            # neuron satisfies all conditions, make a new link that loops back
            loop_neuron.loop_back = true
            var innov_id = Innovations.check_new_link(loop_neuron.neuron_id,
                                                        loop_neuron.neuron_id)
            var loop_link = Link.new(innov_id,
                                    Utils.gauss(Params.w_range),
                                    false,
                                    loop_neuron.neuron_id,
                                    loop_neuron.neuron_id,
                                    true)
            # add the link to genome, and stop the search
            links[innov_id] = loop_link
            return


func add_direct_link() -> void:
    """This mutation guarantees to generate a connection from an input neuron to
    an output neuron.
    """
    for _try in Params.num_tries_find_link:
        var input_neuron = neurons[Utils.random_i_range(2, Params.num_inputs + 1)]
        var output_neuron = neurons[Utils.random_i_range(Params.num_inputs + 1,
                                                        Params.num_outputs + 1)]
        var innov_id = Innovations.check_new_link(input_neuron.neuron_id,
                                                  output_neuron.neuron_id)
        if not links.has(innov_id):
            var new_link = Link.new(innov_id,
                                    Utils.gauss(Params.w_range),
                                    false,
                                    input_neuron.neuron_id,
                                    output_neuron.neuron_id)
            links[innov_id] = new_link
            return


func disable_link() -> void:
    """Disables a link that is currently enabled.
    """
    for _try in Params.num_tries_find_link:
        var link_to_disable = Utils.random_choice(links.values())
        if link_to_disable.enabled:
            link_to_disable.enabled = false
            return


func add_neuron() -> void:
    """Tries to find a link to insert a new neuron into. If the genome is too
    small, there is a chance that no suitable link will be found (num_tries_find).
    If a suitable link is found, it is determined whether this is also a new
    innovation or not. A neuron and 2 links are then created, either using the
    data from an existing innovation, or updating Innovations.
    """
    # placeholders for link to split, and its connecting neurons
    var split_link: Link; var from: Neuron; var to: Neuron
    # try to find a suitable link we can split, break if one is found
    var found_link = false
    for _try in Params.num_tries_find_link:
        split_link = Utils.random_choice(links.values())
        # link only includes neuron_id, get the actual neuron genes from this genome
        from = neurons[split_link.from_neuron_id]
        to = neurons[split_link.to_neuron_id]
        # link should be enabled, avoid splitting bias links and looping links
        if (split_link.enabled and
            not split_link.is_loop_link and
            not from.neuron_type == Params.NEURON_TYPE.bias):
            # check for chaining if the number of HIDDEN neurons is below threshold
            if (Params.prevent_chaining and
                neurons.size()-Params.num_inputs-Params.num_outputs-1 < Params.chain_threshold):
                # if one of the neurons has an x pos other than 0 or 1, do not
                # split this link to avoid creating too much depth in small genomes
                if fmod(from.position.x, 1) + fmod(to.position.x, 1) == 0:
                    found_link = true; break
            else:
                found_link = true; break
    # terminate the func if no suitable link is found
    if not found_link:
        return
    # valid link has been found, disable it, store weight, and also store to_neuron
    split_link.enabled = false
    var original_weight = split_link.weight
    # Innovations checks if this link has ever been split in another genome. If so, it
    # returns the id's of the links and neuron it stored back then. Else it creates
    # new Innovations, and returns their id's.
    var split_data = Innovations.check_new_split(from.neuron_id, to.neuron_id)
    # get the id's returned by split data, SPLIT_MEMBERS just refers to correct index
    var split_neuron_id = split_data[Params.SPLIT_MEMBERS.neuron_id]
    var link1_innov_id = split_data[Params.SPLIT_MEMBERS.from_link]
    var link2_innov_id = split_data[Params.SPLIT_MEMBERS.to_link]
    # calculate new neuron pos by adding half of the split_link vec to from_neuron
    var pos = from.position + (to.position - from.position) / 2
    # now create the gene for the neuron, splitting the old link in the middle 
    var split_neuron = Neuron.new(split_neuron_id,
                                  Params.NEURON_TYPE.hidden,
                                  pos,
                                  Params.default_curve,
                                  false)
    # create the link going to the new neuron, with weight 1
    var link1 = Link.new(link1_innov_id,
                         1,
                         split_link.feed_back,
                         split_link.from_neuron_id,
                         split_neuron_id)
    # create the link going from the new neuron, preserving the original weight
    # to avoid mutations that are too drastic
    var link2 = Link.new(link2_innov_id,
                         original_weight,
                         split_link.feed_back,
                         split_neuron_id,
                         split_link.to_neuron_id)
    # lastly add the new genes to the genome
    neurons[split_neuron_id] = split_neuron
    links[link1_innov_id] = link1
    links[link2_innov_id] = link2


func mutate_weights(mutation_rate: int) -> void:
    """Loop through every link in the genome, and potentially change it's weight.
    """
    for link in links.values():
        if Utils.random_f() < Params.prob_weight_mut[mutation_rate]:
            if Utils.random_f() < Params.prob_weight_replaced[mutation_rate]:
                link.weight = Utils.gauss(Params.w_range)
            else:
                link.weight += Utils.gauss(Params.weight_shift_deviation)


func mutate_activation_response(mutation_rate: int) -> void:
    """Loop through every neuron in the genome, and potentially change it's activation
    func curve.
    """
    for neuron in neurons.values():
        if Utils.random_f() < Params.prob_activation_mut[mutation_rate]:
            neuron.activation_curve += Utils.gauss(Params.activation_shift_deviation)


func clone(g_id: int) -> Genome:
    """Returns a new genome with the exact same genes, but new instances of them.
    """
    # deep copy every neuron in this genome.
    var clone_neurons = {}
    for neuron_id in neurons.keys():
        clone_neurons[neuron_id] = neurons[neuron_id].copy()
    # deep copy every link
    var clone_links = {}
    for innovation_id in links.keys():
        clone_links[innovation_id] = links[innovation_id].copy()
    # return a new instance of Genome, differing only in the genome id
    var clone = get_script().new(g_id,
                                 clone_neurons,
                                 clone_links)
    # copy the species id from the parent
    clone.species_id = species_id
    # mark the new genome as a clone
    clone.is_leader_clone = true
    return clone


func crossover(mate: Genome, g_id: int) -> Genome:
    """Perform a NEAT crossover with another genome. This means that most of the
    neurons and links will be inherited from the more fit genome, however if a neuron
    or link exists in both genomes, there is a chance that the version from the less
    fit parent is inherited to the fitter one.
    """
    # fittest parent gets to keep excess and disjoint genes
    var best: Genome
    if fitness == mate.fitness:
        # Prefer the parent with the smaller genome
        best = self if get_enabled_innovs().size() < mate.get_enabled_innovs().size() else mate
    # obviously pick the fitter one, if the fitness differs (most likely)
    else:
        best = self if fitness > mate.fitness else mate
    # assign the other genome to be "worst"
    var worst: Genome = mate if self == best else self
    # offspring genes
    var baby_links = {}
    var baby_neurons = {}
    # make sure the baby has a copy of all input, bias and output neurons.
    for n_id in best.neurons.keys():
        if best.neurons[n_id].neuron_type != Params.NEURON_TYPE.hidden:
            baby_neurons[n_id] = best.neurons[n_id].copy()
    # go through every link in dominant genome, and add link and connecting neurons
    for link_id in best.links.keys():
        if best.links[link_id].enabled:
            var dominant_genome = best
            # If a link is shared, there is a chance it is inherited from other genome
            if worst.links.has(link_id) and Utils.random_f() < Params.crossover_rate:
                dominant_genome = worst
            # copy the link to add, make var for both neuron id's
            var new_link = dominant_genome.links[link_id].copy()
            var from_id = new_link.from_neuron_id
            var to_id = new_link.to_neuron_id
            # copy connecting neurons into baby genome.
            if not baby_neurons.has(from_id):
                baby_neurons[from_id] = dominant_genome.neurons[from_id].copy()
            if not baby_neurons.has(to_id):
                baby_neurons[to_id] = dominant_genome.neurons[to_id].copy()
            # finally add the link
            baby_links[link_id] = new_link
    # make a new baby by calling the constructor of this class using get_script()
    var baby = get_script().new(g_id,
                                baby_neurons,
                                baby_links)
    # copy the species id from the parents
    baby.species_id = species_id
    return baby


func get_compatibility_score(other_genome: Genome) -> float:
    """Calculates how similar this genome is to another genome according to the
    formula proposed in the original NEAT Paper. See distance variable to see
    how the formula works. It's parameters can be adjusted.
    """
    # numbers needed for compatibility score formula
    var num_matched = 0
    var num_disjoint = 0
    var num_excess = 0
    var weight_difference = 0.0
    # get sorted arrays of both genomes innovation historys 
    var my_innovs = get_enabled_innovs()
    var other_innovs = other_genome.get_enabled_innovs()
    # determine which genomes last innovation is older. Used to calculate excess.
    var older_innovs: Array
    # if both genomes don't have enabled links, they are compatible. stop calculations here
    if my_innovs.empty() and other_innovs.empty():
        return Params.species_boundary - 1
    # if either of the two genomes has no innovs, all of the other genes are excess genes
    # --> the first comparison for excess genes will evaluate true, and a score is calc.
    if my_innovs.empty() or other_innovs.empty():
        older_innovs = [-1]
    # if both have innovs, find the lower last innovation (genome with older innovs)
    else:
        older_innovs = my_innovs if my_innovs.back() < other_innovs.back() else other_innovs
    # get an array of every shared innovation from both genomes, without duplicates
    var all_Innovations = my_innovs + other_innovs
    all_Innovations = Utils.sort_and_remove_duplicates(all_Innovations)
    # the compat. score formula uses the num of enabled links in larger genome
    var longest = my_innovs.size() if my_innovs.size() > other_innovs.size() else other_innovs.size()
    # analyze every innovation and tally up matching, disjoint and excess scores
    var innovation_count = 0
    for innovation in all_Innovations:
        # match: both genomes have invented this link, calculate difference in weights
        if self.links.has(innovation) and other_genome.links.has(innovation):
            var wd = abs(links[innovation].weight - other_genome.links[innovation].weight)
            num_matched += 1
            weight_difference += wd
        # excess: elif innov_id exceeds last innov_id of older_Innovations genome, the
        # remaining Innovations in all_Innovations are excess genes. stop the search.
        elif innovation > older_innovs.back():
            num_excess = all_Innovations.size() - innovation_count
            break
        # disjoint: if we are sure, that both genomes still have Innovations,
        # (=not excess), and just one of them has the innov (xor check) -> disjoint
        elif self.links.has(innovation) != other_genome.links.has(innovation):
            num_disjoint += 1
        # increase the number of Innovations that have been examined
        innovation_count += 1
    # If none match, set to 1 to prevent division by zero if no genes match. The
    # match score is still gives zero because the weight difference is zero.
    if num_matched == 0:
        num_matched = 1
    # calculate the distance
    var distance = ((Params.coeff_matched * weight_difference) / num_matched +
                    (Params.coeff_disjoint * num_disjoint) / longest +
                    (Params.coeff_excess * num_excess) / longest)
    return distance


func generate_agent() -> Agent:
    """This method generates a new agent Object and a neural network according to
    the genomes links and neurons. Should only be called once the genome is finished
    mutating (if it is not a leader clone).
    """
    var new_network = NeuralNet.new(neurons, links.values())
    agent = Agent.new(new_network, is_leader_clone)
    return agent


func get_enabled_innovs() -> Array:
    """Returns the innovation ids of every enabled link in the genome
    """
    var enabled_innovs = []
    for innov_id in links.keys():
        if links[innov_id].enabled:
            enabled_innovs.append(innov_id)
    return enabled_innovs
