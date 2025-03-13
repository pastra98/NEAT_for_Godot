class_name Species
extends RefCounted

"""Species are a means for the NEAT algorithm to group structurally similar networks
together. The GeneticAlgorithm class uses species to provide new genomes by either
calling elite_spawn(), mate_spawn() or asex_spawn() on a species.
This grouping is necessary to achieve 'fitness sharing', meaning that the fitness
of individual members contributes to the fitness of the entire species, which in
turn determines how many new members the species will spawn in the next generation.
"""

# unique string consisting of the generation the species was founded in, and the
# genome that founded species
var species_id: String
# How many generations this species has existed for
var age = 0
# the representative of this species, that all new genomes are compared to
var representative: Genome
# Leader is the fittest member. If Params.compare_to_leader, he is also the representative
var leader: Genome

# all members of the current generation
var alive_members = []
# expresses the number of members this species had in the previous generation
var num_members: int
# The pool of members from the previous gen that will spawn offspring
var pool: Array
# maximum offspring this species can spawn (may spawn less)
var expected_offspring = 0
# number of spawns the species got during the last generation it was active
var spawn_count = 0
# average fitness of all alive members
var avg_fitness = 0
# average fitness adjusted by the age modifier
var avg_fitness_adjusted = 0
# best ever fitness witnessed in this species
var best_ever_fitness = 0
# should this species be purged?
var obliterate = false
# The amount of offspring to be spawned in the next generation
var num_to_spawn = 0

# if the species doesn't improve for Params.enough_gens_to_change_things, the rates
# of mutations change to their second (heightened) value. this changes back if the
# species improves again.
var curr_mutation_rate = Params.MUTATION_RATE.normal
# if the species continues to not improve, kill species after
# allowed_gens_no_improvement of stale generations.
var num_gens_no_improvement = 0


func _init(id: String) -> void:
    """Creates a new species
    """
    species_id = id


func update() -> void:
    """Checks if the species continues to survive into the next generation. If so,
    the total fitness of the species is calculated and adjusted according to the age
    bonus of the species. It's members are ranked according to their fitness, and
    a certain percentage of them is placed into the pool that gets to produce offspring.
    """
    # first check if the species hasn't spawned new members in the last gen or if it
    # survived for too many generations without improving, in which case it is marked
    # for obliteration.
    if alive_members.is_empty() or num_gens_no_improvement > Params.allowed_gens_no_improvement:
        obliterate = true
    else:
        # the species survives into the next generation
        spawn_count = 0
        num_to_spawn = 0
        age += 1
        # first sort the alive members, and determine the fittest member
        alive_members.sort_custom(Callable(self, "sort_by_fitness"))
        leader = alive_members[0]
        num_members = alive_members.size()
        # check if current best member is fitter than previous best
        if leader.fitness > best_ever_fitness:
            # this means the species is improving -> normal mutation rate
            best_ever_fitness = leader.fitness
            num_gens_no_improvement = 0
            curr_mutation_rate = Params.MUTATION_RATE.normal
        else:
            num_gens_no_improvement += 1
            if num_gens_no_improvement > Params.enough_gens_to_change_things:
                curr_mutation_rate = Params.MUTATION_RATE.heightened
        # if the representative should be updated, do so now
        if Params.update_species_rep:
            representative = leader if Params.leader_is_rep else Utils.random_choice(alive_members)
        # pool is a reference to the alive members of the last gen
        # If a species reaches selection_threshold, not every member gets in the pool
        if alive_members.size() > Params.selection_threshold:
            pool = alive_members.slice(0, int(alive_members.size()*Params.spawn_cutoff))
        else:
            pool = alive_members
        # calculate the average fitness and adjusted fitness of this species
        avg_fitness = get_avg_fitness()
        var fit_modif = Params.youth_bonus if age < Params.old_age else Params.old_penalty
        avg_fitness_adjusted = avg_fitness * fit_modif
        # reassign alive members to a new empty array, so new agents can be placed
        # in the next gen. Clearing it also clear the pool, since pool is a reference.
        alive_members = []
        


func get_avg_fitness() -> float:
    """Returns the average fitness of all members in the species
    """
    var total_fitness = 0
    for member in alive_members:
        total_fitness += member.fitness
    return (total_fitness / alive_members.size())


func calculate_offspring_amount(total_avg_species_fitness) -> void:
    """This func does not care about the fitness of individual members. It
    calculates the total spawn tickets allotted to this species by comparing
    how fit this species is relative to all other species, and multiplying this
    result with the total population size.
    """
    # prevent species added in the current gen from producing offspring
    if age != 0:
        num_to_spawn = round((avg_fitness_adjusted / total_avg_species_fitness) * Params.population_size)


func add_member(new_genome) -> void:
    """Just appends a new genome to the alive_members and updates the new_members
    count.
    """
    alive_members.append(new_genome)
    new_genome.species_id = species_id


func purge() -> void:
    """Actually just included for dramatic effect.
    """
    alive_members.clear()


func sort_by_fitness(member1: Genome, member2: Genome) -> bool:
    """Used for sort_custom(). Sorts members in descending order.
    """
    return member1.fitness > member2.fitness


func elite_spawn(g_id: int) -> Genome:
    """Returns a clone of the species leader without increasing spawn count
    """
    return leader.clone(g_id)


func mate_spawn(g_id: int) -> Genome:
    """Chooses to members from the pool and produces a baby via crossover. Baby
    then gets mutated and returned.
    """
    var mom: Genome; var dad: Genome; var baby: Genome
    # if random mating, pick 2 random unique parent genomes for crossing over.
    if Params.random_mating:
        var found_mate = false
        while not found_mate:
            dad = Utils.random_choice(pool)
            mom = Utils.random_choice(pool)
            if dad != mom:
                found_mate = true
    # else just go through every member of the pool, possibly multiple times and
    # breed genomes sorted by their fitness. Genomes with fitness scores next to each
    # other are therefore picked as mates, the exception being the first and last one.
    else:
        var pool_index = spawn_count % (pool.size() - 1)
        mom = pool[pool_index]
        # ensure that second parent is not out of pool bounds
        dad = pool[-1] if pool_index == 0 else pool[pool_index + 1]
    # now that the parents are determined, produce a baby and mutate it
    baby = dad.crossover(mom, g_id)
    baby.mutate(curr_mutation_rate)
    spawn_count += 1
    return baby

func asex_spawn(g_id) -> Genome:
    """Clones a member from the pool, mutates it, and returns it.
    """
    var baby: Genome
    # As long as not every pool member as been spawned, pick next one from pool
    if spawn_count < pool.size():
        baby = pool[spawn_count].clone(g_id)
    # if more spawns than pool size, start again
    else:
        baby = pool[spawn_count % pool.size()].clone(g_id)
    baby.mutate(curr_mutation_rate)
    spawn_count += 1
    return baby
