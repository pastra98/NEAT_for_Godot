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
var curr_generation_id = 1
# the average fitness of every currently alive genome
var avg_population_fitness = 0
# total of all average species fitnesses, used to calculate the spawn amount per species
var total_avg_species_fitness = 0
# the all-time best genome. Mustn't be from the current generation. 
var curr_best: Genome
# the species with the best average fitness in the population
var best_species: Species
# the array of all currently alive genomes
var curr_genomes = []
# array holding all agents, gets updated to only hold alive agents every timestep
var curr_agents = []
# an array containging species objects. Every species holds an array of members.
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
    # generate the first generation of genomes
    var initial_genomes = []
    for _initial_genome in Params.population_size:
        # Every genome gets a new set of neurons and random connections
        var links = {}; var neurons = {}
        # copy every input and output neuron for a new genome
        for neuron_id in all_neurons.keys(): 
            neurons[neuron_id] = all_neurons[neuron_id].copy()
        # count how many links are added
        var links_added = 0
        while links_added <= Params.num_initial_links:
            # pick some random neuron id's from both input and output
            var from_neuron_id = Utils.random_choice(input_neurons.keys())
            var to_neuron_id = Utils.random_choice(output_neurons.keys())
            # don't add a link that connects to a bias neuron in the first gen
            if neurons[to_neuron_id].neuron_type != Params.NEURON_TYPE.bias:
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
        # the comp_score is used to check relatedness to other species such that
        # a new genome can be assigned to a species, or a new species is created
        var comp_score = Params.species_boundary + 1
        var found_species: Species
        # first try to find the species to which the genome is closest to
        for species in curr_species:
            if new_genome.get_compatibility_score(species.representative) < comp_score:
                comp_score = new_genome.get_compatibility_score(species.representative)
                found_species = species
        if comp_score < Params.species_boundary:
            found_species.add_member(new_genome)
        # if none was found, create a new species, and assign this genome as repres.
        else:
            var diverged_species = make_new_species()
            diverged_species.add_member(new_genome)
            diverged_species.representative = new_genome
        # set last genome and species to be best species and genome, to allow
        # for comparison later
        curr_best = initial_genomes.back()
        best_species = curr_species.back()
        curr_agents.append(new_genome.generate_agent())
        initial_genomes.append(new_genome)
    # --- end of for loop that creates all genomes.
    # let ui know that it should update the species list
    emit_signal("made_new_gen")
    # return all new genomes 
    return initial_genomes

################################################################################
var first_elite: Genome
################################################################################

func next_generation() -> void:
    """Gets called once for every new generation. Kills all agents, updates the
    fitness of every genome, and assigns genomes to a species (or creates new ones).
    Then goes through every species, and tries to spawn their new members (=genomes)
    either through crossover or asexual reproduction, until the max population size
    is reached. The new genomes then generate an agent, which will handle the
    interactions between the entity that lives in the simulated world, and the
    neural network that is coded for by the genome.
    """
    # extract genomes from current agents, then kill them, clear agent array
    finish_current_agents()
    # get the currently alive species, and update the avg_population_fitness
    prepare_old_species()
    # print some info about the last generation
    if Params.print_new_generation:
        print_status()
    num_new_species = 0
    curr_generation_id += 1
    var new_genomes = []
    var num_spawned = 0
    for species in curr_species:
        var num_to_spawn = species.calculate_offspring_amount(total_avg_species_fitness)
        # Don't exceed population size
        if num_spawned == Params.population_size:
            break
        elif num_spawned + num_to_spawn > Params.population_size:
            num_to_spawn = Params.population_size - num_spawned
        # Elitism: best member of each species gets copied w.o. mutation
        var spawned_elite = false
        for spawn in num_to_spawn:
            var baby: Genome
            # first clone the species leader for elitism
            if not spawned_elite:
                baby = species.elite_spawn(curr_genome_id)
                spawned_elite = true
################################################################################
                if num_spawned == 0:
                    first_elite = baby
################################################################################
            # if less than 2 members in spec., crossover cannot be performed
            # there is also asex_prob, which might result in an asex baby
            elif species.pool.size() < 2 or Utils.random_f() < Params.asex_prob:
                baby = species.asex_spawn(curr_genome_id)
            # produce a crossed-over genome
            else:
                baby = species.mate_spawn(curr_genome_id)
            # check if baby should speciate away from it's current species
            if baby.get_compatibility_score(species.representative) > Params.species_boundary:
                var diverged_species = make_new_species()
                diverged_species.add_member(baby)
                diverged_species.representative = baby
            # If the baby is still within the species of it's parents, add it as member
            else:
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


func make_new_species() -> Species:
    """Generates a new species with a unique id, adds it to curr_species and returns it.
    """
    num_new_species += 1
    var new_species_id = str(curr_generation_id) + "_" + str(curr_genome_id)
    var diverged_species = Species.new(new_species_id)
    curr_species.append(diverged_species)
    return diverged_species


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


func prepare_old_species() -> void:
    """Determines which species will get to reproduce in the next generation.
    Calls the Species.update() method, which determines the species fitness as a
    group and removes all its members to make way for a new generation.
    """
    num_dead_species = 0
    total_avg_species_fitness = 0
    # this array will replace the curr species array
    var updated_species = []
    for species in curr_species:
        # prepare the species for the next gen, and add it's average fitness
        # to avg_population_fitness
        var avg_species_fitness = species.update_species()
        total_avg_species_fitness += avg_species_fitness
        # purge species that are marked for obliteration
        if not species.obliterate:
            updated_species.append(species)
            # update curr best species
            if avg_species_fitness > best_species.avg_fitness:
                best_species = species
            # update curr_best genome by checking if this leader is fitter
            if species.leader.fitness > curr_best.fitness:
                curr_best = species.leader
        # remove dead species
        else:
            num_dead_species += 1
            species.purge()
    curr_species = updated_species
    # this should not normally happen. Consider different parameters and starting
    # a new run.
    if updated_species.size() == 0 or total_avg_species_fitness == 0:
        push_error("mass extinction"); breakpoint
    # calculate new avg population fitness
    avg_population_fitness = total_avg_species_fitness / updated_species.size()
    # sort species by fitness in descending order
    updated_species.sort_custom(self, "sort_by_spec_fitness")


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
            # make a new species if it matches none of the parents
            if mom_score > Params.species_boundary and dad_score > Params.species_boundary:
                var diverged_species = make_new_species()
                diverged_species.add_member(baby)
                diverged_species.representative = baby
            # baby has a score closer to mom than to dad
            elif mom_score < dad_score:
                curr_species[species_index].add_member(baby)
            # baby has a score closer to dad
            else:
                curr_species[species_index + 1].add_member(baby)
            # make an agent for the baby, and append it to the curr_agents array
            curr_agents.append(baby.generate_agent())
            hybrids.append(baby)
            # if we went through every species, but still have spawns, go again
        # go to next species
        species_index += 1 
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
    var print_vars = {"gen_id" : curr_generation_id, "new_s" : num_new_species,
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
