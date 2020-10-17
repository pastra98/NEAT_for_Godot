class_name GeneticAlgorithm
extends Node


"""This class is responsible for generating genomes, placing them into species and
evaluating them. It can be viewed as the main orchestrator of the evolution process,
by delegating the exact details of how each step is achieved to the other classes
within this directory.
"""

# curr_genome_id gets incremented for every new genome
var curr_genome_id = 0
# the current generation, starting with 1
var curr_generation = 1
# the average fitness of every currently alive genome
var avg_population_fitness = 0
# the all-time best genome
var all_time_best: Genome
# the best genome from the last generation
var curr_best: Genome
# the species with the best average fitness from the last generation
var best_species: Species
# the array of all currently alive genomes
var curr_genomes = []
# array holding all agents, gets updated to only hold alive agents every timestep
var curr_agents = []
# an array containing species objects. Every species holds an array of members.
var curr_species = []
# can be used to determine when a new generation should be started
var all_agents_dead = false
# how many species got purged, and how many new species were founded in the curr generation
var num_dead_species = 0
var num_new_species = 0

# the NeatGUI node is a child of ga, and manages the creation and destruction
# of other GUI nodes.
var gui

# signal to let the gui know when to update
signal made_new_gen
# only true for the first call to next_timestep(), in case any processing needs to
# happen then.
var is_first_timestep = true

# 0 = show all, 1 = show leaders, 2 = show none. Can be changed using gui
var curr_visibility = Params.default_visibility


func _init(number_inputs: int,
           number_outputs: int,
           body_path: String,
           use_gui = true,
           custom_params_name = "Default") -> void:
    """Sets the undefined members of the Params Singleton according to the options
    in the constructor. Body path refers to the filepath for the agents body.
    Loads Params configuration if custom_Params_name is given. Creates the first
    set of genomes and agents, and creates a GUI if use_gui is true.
    """
    # set the name of the node that contains GeneticAlgorithm Object
    set_name("ga")
    # load the specified Params file
    Params.load_config(custom_params_name)
    # save all specified parameters in the Params singleton
    Params.num_inputs = number_inputs
    Params.num_outputs = number_outputs
    Params.agent_body_path = body_path
    Params.use_gui = use_gui
    # create a new population of genomes
    curr_genomes = create_initial_population()
    # add the gui node as child
    if use_gui:
        gui = load("res://NEAT_usability/gui/NeatGUI.gd").new()
        add_child(gui)


func create_initial_population() -> Array:
    """This method creates the first generation of genomes. For the first set of
    genomes, there is just a limited number of links created, and no hidden
    neurons. Every genome gets assigned to a species, new species are created
    if necessary. Returns an array of the current genomes.
    """
    # --- first create a set of input, output and bias neurons
    var made_bias = false
    # current neuron_id is stored in Innovations, and gets incremented there
    var initial_neuron_id: int
    var input_neurons = {}; var output_neurons = {}
    # generate all input neurons and a bias neuron
    for i in Params.num_inputs + 1:
        # calculate the position of the input or bias neuron (in the first layer)
        var new_pos = Vector2(0, float(i)/Params.num_inputs)
        # the first neuron should be the bias neuron
        var neuron_type = Params.NEURON_TYPE.input
        if not made_bias:
            neuron_type = Params.NEURON_TYPE.bias
            made_bias = true
        # register neuron in Innovations, make the new neuron
        initial_neuron_id = Innovations.store_neuron(neuron_type)
        var new_neuron = Neuron.new(initial_neuron_id,
                                    neuron_type,
                                    new_pos,
                                    Params.default_curve,
                                    false)
        input_neurons[initial_neuron_id] = new_neuron
    # now generate all output neurons
    for i in Params.num_outputs:
        var new_pos = Vector2(1, float(i)/Params.num_outputs)
        initial_neuron_id = Innovations.store_neuron(Params.NEURON_TYPE.output)
        var new_neuron = Neuron.new(initial_neuron_id,
                                    Params.NEURON_TYPE.output,
                                    new_pos,
                                    Params.default_curve,
                                    false)
        output_neurons[initial_neuron_id] = new_neuron
    # merge input and output neurons into a single dict.
    var all_neurons = Utils.merge_dicts(input_neurons, output_neurons)
    # --- generate the first generation of genomes
    var initial_genomes = []
    for _initial_genome in Params.population_size:
        # Every genome gets a new set of neurons and random connections
        var links = {}; var neurons = {}
        # copy every input and output neuron for a new genome
        for neuron_id in all_neurons.keys(): 
            neurons[neuron_id] = all_neurons[neuron_id].copy()
        # count how many links are added
        var links_added = 0
        while links_added < Params.num_initial_links:
            # pick some random neuron id's from both input and output
            var from_neuron_id = Utils.random_choice(input_neurons.keys())
            var to_neuron_id = Utils.random_choice(output_neurons.keys())
            # don't add a link that connects from a bias neuron in the first gen
            if neurons[from_neuron_id].neuron_type != Params.NEURON_TYPE.bias:
                # Innovations returns either an existing or new id
                var innov_id = Innovations.check_new_link(from_neuron_id, to_neuron_id)
                # prevent adding duplicates
                if not links.has(innov_id):
                    var new_link = Link.new(innov_id,
                                            Utils.gauss(Params.w_range),
                                            false,
                                            from_neuron_id,
                                            to_neuron_id)
                    # add the new link to the genome
                    links[innov_id] = new_link
                    links_added += 1
        # increase genome counter, create a new genome
        curr_genome_id += 1
        var new_genome = Genome.new(curr_genome_id,
                                    neurons,
                                    links)
        # try to find a species to which the new genome is similar. If no existing
        # species is compatible with the genome, a new species is made and returned
        var found_species = find_species(new_genome)
        found_species.add_member(new_genome)
        curr_agents.append(new_genome.generate_agent())
        initial_genomes.append(new_genome)
    # --- end of for loop that creates all genomes.
    # pick random genome of first gen as all_time_best, to allow for comparison
    all_time_best = Utils.random_choice(initial_genomes)
    # let ui know that it should update the species list
    emit_signal("made_new_gen")
    # return all new genomes 
    return initial_genomes


func next_generation() -> void:
    """Gets called once for every new generation. Kills all agents, updates the
    fitness of every genome, and assigns genomes to a species (or creates new ones).
    Then goes through every species, and tries to spawn their new members (=genomes)
    either through crossover or asexual reproduction, until the max population size
    is reached. The new genomes then generate an agent, which will handle the
    interactions between the entity that lives in the simulated world, and the
    neural network that is coded for by the genome.
    """
    # assign the fitness stored in the agent to the genome, then clear the agent array
    finish_current_agents()
    # Get updated list of species that survived into the next generation, and update
    # their spawn amounts based on fitness. Sort species by fitness
    curr_species = update_curr_species()
    curr_species.sort_custom(self, "sort_by_spec_fitness")
    # print some info about the last generation
    if Params.print_new_generation:
        print_status()
    # keep track of new species, increment generation counter
    num_new_species = 0
    curr_generation += 1
    # the array containing all new genomes that will be spawned
    var new_genomes = []
    # keep track of spawned genomes, to not exceed population size
    var num_spawned = 0
    for species in curr_species:
        # reduce num_to_spawn if it would exceed population size
        if num_spawned == Params.population_size:
            break
        elif num_spawned + species.num_to_spawn > Params.population_size:
            species.num_to_spawn = Params.population_size - num_spawned
        # Elitism: best member of each species gets copied w.o. mutation
        var spawned_elite = false
        # spawn all the new members of a species
        for spawn in species.num_to_spawn:
            var baby: Genome
            # first clone the species leader for elitism
            if not spawned_elite:
                baby = species.elite_spawn(curr_genome_id)
                spawned_elite = true
            # if less than 2 members in spec., crossover cannot be performed
            # there is also prob_asex, which might result in an asex baby
            elif species.pool.size() < 2 or Utils.random_f() < Params.prob_asex:
                baby = species.asex_spawn(curr_genome_id)
            # produce a crossed-over genome
            else:
                baby = species.mate_spawn(curr_genome_id)
            # check if baby should speciate away from it's current species
            if baby.get_compatibility_score(species.representative) > Params.species_boundary:
                # if the baby is too different, find an existing species to change
                # into. If no compatible species is found, a new one is made and returned
                var found_species = find_species(baby)
                found_species.add_member(baby)
            else:
                # If the baby is still within the species of it's parents, add it as member
                species.add_member(baby)
            curr_genome_id += 1
            num_spawned += 1
            # lastly generate an agent for the baby and append it to curr_agents
            curr_agents.append(baby.generate_agent())
            new_genomes.append(baby)
    # if all the current species didn't provide enough offspring, get some more
    if Params.population_size - num_spawned > 0:
        new_genomes += make_hybrids(Params.population_size - num_spawned)
    # update curr_genomes alias
    curr_genomes = new_genomes
    all_agents_dead = false
    # let ui know that it should update the species list
    emit_signal("made_new_gen")
    # reset is_first_timestep so it is true for the first call to next_timestep()
    is_first_timestep = true


func find_species(new_genome: Genome) -> Species:
    """Tries to find a species to which the given genome is similar enough to be
    added as a member. If no compatible species is found, a new one is made. Returns
    the species (but the genome still needs to be added as a member).
    """
    var found_species: Species
    # try to find an existing species to which the genome is close enough to be a member
    var comp_score = Params.species_boundary
    for species in curr_species:
        if new_genome.get_compatibility_score(species.representative) < comp_score:
            comp_score = new_genome.get_compatibility_score(species.representative)
            found_species = species
    # new genome matches no current species -> make a new one
    if typeof(found_species) == TYPE_NIL:
        found_species = make_new_species(new_genome)
    # return the species, whether it is new or not
    return found_species


func make_new_species(founding_member: Genome) -> Species:
    """Generates a new species with a unique id, assigns the founding member as
    representative, and adds the new species to curr_species and returns it.
    """
    var new_species_id = str(curr_generation) + "_" + str(founding_member.id)
    var new_species = Species.new(new_species_id)
    new_species.representative = founding_member
    curr_species.append(new_species)
    num_new_species += 1
    return new_species


func next_timestep() -> void:
    """Loops through the curr_agents array, removes dead ones from active processing,
    and calls the agent.process_inputs() method. process_inputs() takes the sensory
    information obtained by agent.body.sense(), feeds it into the neural net and
    calls the agent.body.act() method with the networks outputs.
    """
    # Because agent.bodies are not in the tree when next_generation() finishes,
    # their visibility can be changed only after they are all in the scene
    if is_first_timestep:
        update_visibility(curr_visibility)
        is_first_timestep = false
    # loop through agents array and remove dead agents from active processing
    # by replacing the curr_agents array.
    var new_agents = []
    for agent in curr_agents:
        if not agent.is_dead:
            agent.process_inputs()
            new_agents.append(agent)
    # replace curr_agents with all agents that are alive, therefore removing dead ones
    curr_agents = new_agents
    if curr_agents.empty():
        all_agents_dead = true


func finish_current_agents() -> void:
    """Kills any agents that are still alive, assigns the fitness of the agent.body
    to the genome, and clears the curr_agents array to make way for a new generation.
    """
    for genome in curr_genomes:
        var agent = genome.agent
        # if the generation is terminated before all agents are dead
        if not agent.is_dead:
            agent.body.emit_signal("death")
        # copy fitness to genome
        genome.fitness = agent.fitness
        agent.body.queue_free()
    # clear the agents array
    curr_agents.clear()


func update_curr_species() -> Array:
    """Determines which species will get to reproduce in the next generation.
    Calls the Species.update() method, which determines the species fitness as a
    group and removes all its members to make way for a new generation. Then loops
    over all species and updates the amount of offspring they will spawn the next
    generation.
    """
    num_dead_species = 0
    # find the fittest genome from the last gen. Start with a random genome to allow comparison
    curr_best = Utils.random_choice(curr_species.front().alive_members)
    # sum the average fitnesses of every species, and sum the average unadjusted fitness
    var total_adjusted_species_avg_fitness = 0
    var total_species_avg_fitness = 0
    # this array holds the updated species
    var updated_species = []
    for species in curr_species:
        # first update the species, this will check if the species gets to survive
        # into the next generation, update the species leader, calculate the average fitness
        # and calculate how many spawns the species gets to have in the next generation
        species.update()
        # check if the species gets to survive
        if not species.obliterate:
            updated_species.append(species)
            # collect the average fitness, and the adjusted average fitness
            total_species_avg_fitness += species.avg_fitness
            total_adjusted_species_avg_fitness += species.avg_fitness_adjusted 
            # update curr_best genome and possibly all_time_best genome
            if species.leader.fitness > curr_best.fitness:
                if species.leader.fitness > all_time_best.fitness:
                    all_time_best = species.leader
                curr_best = species.leader
        # remove dead species
        else:
            num_dead_species += 1
            species.purge()
    # update avg population fitness of the previous generation
    avg_population_fitness = total_species_avg_fitness / curr_species.size()
    # this should not normally happen. Consider different parameters and starting a new run
    if updated_species.size() == 0 or total_adjusted_species_avg_fitness == 0:
        push_error("mass extinction"); breakpoint
    # loop through the species again to calculate their spawn amounts based on their
    # fitness relative to the total_adjusted_species_avg_fitness
    for species in updated_species:
        species.calculate_offspring_amount(total_adjusted_species_avg_fitness)
    # update the current best species
    best_species = updated_species.front()
    # finally return the updated species list
    return updated_species


func make_hybrids(num_to_spawn: int) -> Array:
    """Go through every species num_to_spawn times, pick it's leader, and mate it
    with a species leader from another species.
    """
    var hybrids = []
    var species_index = 0
    while not hybrids.size() == num_to_spawn:
        # ignore newly added species
        if curr_species[species_index].age != 0:
            var mom = curr_species[species_index].leader
            var dad = curr_species[species_index + 1].leader
            var baby = mom.crossover(dad, curr_genome_id)
            curr_genome_id += 1
            # determine which species the new hybrid belongs to
            var mom_score =  baby.get_compatibility_score(mom)
            var dad_score =  baby.get_compatibility_score(dad)
            # find or make a new species if the baby matches none of the parents
            if mom_score > Params.species_boundary and dad_score > Params.species_boundary:
                var found_species = find_species(baby)
                found_species.add_member(baby)
            # baby has a score closer to mom than to dad
            elif mom_score < dad_score:
                curr_species[species_index].add_member(baby)
            # baby has a score closer to dad
            else:
                curr_species[species_index + 1].add_member(baby)
            # make an agent for the baby, and append it to the curr_agents array
            curr_agents.append(baby.generate_agent())
            hybrids.append(baby)
        # go to next species
        species_index += 1 
        # if we went through every species, but still have spawns, go again
        if species_index == curr_species.size() - 2:
            species_index = 0
    return hybrids


func sort_by_spec_fitness(species1: Species, species2: Species) -> bool:
    """Used for sort_custom(). Sorts species in descending order.
    """
    return species1.avg_fitness > species2.avg_fitness


func get_curr_bodies() -> Array:
    """Returns the body of every agent in the current generation. Useful when
    something needs to be done with the bodies in external code.
    """
    var curr_bodies = []
    for agent in curr_agents:
        curr_bodies.append(agent.body)
    return curr_bodies


func print_status() -> void:
    """Prints some basic information about the current progress of evolution.
    """
    var print_str = """\n Last generation performance:
    \n generation number: {gen_id} \n number new species: {new_s}
    \n number dead species: {dead_s} \n total number of species: {tot_s}
    \n avg. fitness: {avg_fit} \n best fitness: {best} \n """
    var print_vars = {"gen_id" : curr_generation, "new_s" : num_new_species,
                      "dead_s" : num_dead_species, "tot_s" : curr_species.size(),
                      "avg_fit" : avg_population_fitness, "best" : curr_best.fitness}
    print(print_str.format(print_vars))


func update_visibility(index: int) -> void:
    """calls the hide() or show() methods on either all bodies, or just leader bodies.
    """
    # if this func was called by the species list, change curr_visibility
    curr_visibility = index
    # configure visibilities
    match Params.visibility_options[index]:
        "Show all":
            get_tree().call_group("all_bodies", "show")
        "Show Leaders":
            get_tree().call_group("all_bodies", "hide")
            get_tree().call_group("leader_bodies", "show")
        "Show none":
            get_tree().call_group("all_bodies", "hide")
