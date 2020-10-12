extends Control

"""A demo that generates a network that simulates an XOR gate. The network receives
rewards dependant on how close the output is to the actual solution (either 0 or 1)
for every one of the four XOR cases. The maximum fitness that could be achieved for
solving every case is 4, but due to the weights never quite reaching full integers,
the threshold for solving the problem should show a bit of tolerance (like 3.999).

This demo follows the model of the other demos where there are bodies that interact
in the world. Here they are just simple nodes that do nothing else but compare their
output to the correct solution and assign a fitness. This is quite bloated, but it just
exists to demonstrate that NEAT for Godot can solve XOR. However, this Library is
intended for evolving agents that interact in game/simulation environments, and it
should not be used to generate classifiers (as there are much better ways of doing that).
"""

# the "body" here is just a node that tests it's networks success at solving xor
var agent_body_path = "res://demos/xor/xor_tester/XorTester.tscn"
# Initialize a GeneticAlgorithm Node with 2 inputs, 1 output and no default gui
# setup. Load xor config.
onready var ga = GeneticAlgorithm.new(2, 1, agent_body_path, false, "xor_params")

# A single GenomeDetail window is used here to show the currently fittest network
# It is the only element from NEAT GUI that is used here
onready var genome_detail = load("res://NEAT_usability/gui/genome_detail/GenomeDetail.tscn").instance()

# the maximum score that can be reached is 4. 1 fitness point per solved xor
var fitness_threshold = 3.99
# A splash screen on how to continue after reaching fitness threshold
onready var DemoCompletedSplash = preload("res://demos/demo_loader/DemoCompletedSplash.tscn")
# While the splashscreen is open, do not continue the genetic algorithm
var paused = false


func _ready() -> void:
    """Add ga node to tree, load the first genome into the detail window.
    """
    # # add the ga node and it's currently active xor bodies to the scene
    # add_child(ga)
    # place_testers(ga.get_curr_bodies())
    # # add the genome detail to the tree, place it roughly in the center of the screen
    # genome_detail.inspected_genome = ga.curr_best
    # add_child(genome_detail)
    # genome_detail.rect_position = rect_size / 3.5
################################################################################
    paused = true
    test_network("best_xor")
################################################################################


func _process(_delta):
    """Use _process to test the current networks and make new generations.
    Significantly reduces fps, but this doesn't really matter in this demonstration,
    since not much is happening on the screen.
    """
    if not paused:
        # let every XorTesters perform one of the 4 tests
        ga.next_timestep()
        # if the fittest network reached the fitness threshold, end this test
        if ga.curr_best.fitness > fitness_threshold:
            end_xor_test()
        # if XorTesters are done with every test, they are marked dead. time for next gen
        elif ga.all_agents_dead:
            # show the best genome from prev generation and start next gen
            genome_detail.update_inspected_genome(ga.curr_best)
################################################################################
            # var past_gen_best = ga.curr_best
            # var past_gen_elite = ga.curr_best
            # if ga.curr_generation_id > 1:
            # 	past_gen_elite = ga.first_elite
            # 	# past_gen_best = ga.curr_species.front().leader
            # 	# genome_detail.update_inspected_genome(past_gen_best)
            # 	genome_detail.update_inspected_genome(past_gen_elite)
################################################################################
            ga.next_generation()
            place_testers(ga.get_curr_bodies())
            # update the info text, and print the same info to the console
            var info_text = "generation: %s \n best fitness: %s \n number species: %s"
            var info_vars = [ga.curr_generation_id, ga.curr_best.fitness, ga.curr_species.size()]
################################################################################
            # # var info_vars = [ga.curr_generation_id, past_gen_best.fitness, ga.curr_species.size()]
            # var info_vars = [ga.curr_generation_id, past_gen_elite.fitness, ga.curr_species.size()]
################################################################################
            $Info.text = info_text % info_vars
            print(info_text % info_vars)


func place_testers(testers: Array) -> void:
    """Remove old tester nodes, add new ones to the tree.
    """
    # remove all old nodes, reducing the memory footprint a little bit
    for tester in $Testers.get_children():
        tester.queue_free()
    # add new testers into the tree
    for tester in testers:
        $Testers.add_child(tester)
    

func end_xor_test() -> void:
    """Save the best performing network, test it, open the DemoCompletedSplash
    """
    # pause the Genetic algorithm
    paused = true
    # display the fittest genome in the detail window
    genome_detail.update_inspected_genome(ga.curr_best)
    # save the best network to disk, test it using standalone_neuralnet.gd
    ga.curr_best.agent.network.save_to_json("best_xor")
    test_network("best_xor")
    # open a new splashscreen
    var demo_completed_splash = DemoCompletedSplash.instance()
    demo_completed_splash.initialize(ga, fitness_threshold)
    demo_completed_splash.connect("set_new_threshold", self, "continue_ga")
    add_child(demo_completed_splash)

    
func test_network(network_name: String) -> void:
    """Demonstrates the functionality of standalone_neuralnetwork. Make a standalone
    network instance, and load the previously saved network config onto it. Then
    run the 4 xor cases through the network and print the results.
    """
    # make a new standalone neural network, and load the config
    var tester = load("res://NEAT_usability/standalone_scripts/standalone_neuralnet.gd").new()
    tester.load_config(network_name)
    # run the tests
    print("\n Testing Network: %s" % network_name)
    for test in [[0, 0], [0, 1], [1, 0], [1, 1]]:
        var output = tester.update(test)
        var test_result = "\n For the inputs %s the network computed an output of %s"
        print(test_result % [test, output[0]])
    print("\n Network Test completed!")


func continue_ga(new_threshold) -> void:
    """Continue the evolution until new_threshold is reached.
    """
    fitness_threshold = new_threshold
    paused = false
