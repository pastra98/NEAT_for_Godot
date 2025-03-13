extends Node

"""Simple Agent that tries to solve one of the four XOR cases every time it's sense() and
act() methods are called. Emits the 'death' signal once it is finished with all cases.
"""

# fitness gets incremented every time the network calculates an output for one of
# the four xor_inputs. The closer the output is to the solution, the higher the reward.
var fitness = 0
# The four cases of an xor gate.
var xor_inputs = [[0, 0], [0, 1], [1, 0], [1, 1]]
# the currently selected xor_input. 
var curr_input: Array
# emitted as soon as the xor_tester has worked on every input.
signal death


func sense() -> Array:
    """Selects a new input to solve when act() gets called.
    """
    curr_input = xor_inputs.pop_front()
    return curr_input


func act(xor_output: Array) -> void:
    """Calculates how good the solution of the network (xor_output) was by calculating
    the delta between correct answer and output, and squaring it to proportionally
    increase the reward the closer the output is to the solution.
    """
    var xor_answer = xor_output[0]
    var expected = float(curr_input[0] != curr_input[1])
    var distance_squared = pow((expected - xor_answer), 2)
    fitness += (1 - distance_squared)
    if xor_inputs.is_empty():
        emit_signal("death")


func get_fitness() -> float:
    return fitness
