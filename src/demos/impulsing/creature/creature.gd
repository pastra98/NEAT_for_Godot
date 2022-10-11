extends RigidBody2D

# TODO:
# - currently does not account for rotation when applying impulse (should be
#   rotated by angle)
# - maybe fitness should increase exponentially (however 2 is too much)
# - NORMALIZE THE INPUT VALUES IN SENSE. WAY TOO BIG ATM. TEST ACTIVATION CURVE
#   IN GEOGEBRA
# - try 4 outputs using sigmoid instead of 2

var impulse_power = 5
var speed_penalty = 1
var act_threshold = 0.5

onready var target = get_node("../../Target")

var fitness: float
signal death


func sense() -> Array:
    var direction_to_target = (target.global_position - global_position) / target.distance_to_spawn

    return [
        direction_to_target.x if direction_to_target.x > 0 else 0,
        abs(direction_to_target.x) if direction_to_target.x < 0 else 0,
        direction_to_target.y if direction_to_target.y > 0 else 0,
        abs(direction_to_target.y) if direction_to_target.y < 0 else 0,
    ]


func act(actions: Array) -> void:
    if actions[0] > act_threshold:
        apply_central_impulse(Vector2(0, -impulse_power))
    elif actions[1] > act_threshold:
        apply_central_impulse(Vector2(0, impulse_power))
    if actions[2] > act_threshold:
        apply_central_impulse(Vector2(-impulse_power, 0))
    elif actions[3] > act_threshold:
        apply_central_impulse(Vector2(impulse_power, 0))


func update_fitness() -> int:
    # don't subtract fitness for moving away
    var f_boost = max(0, target.distance_to_spawn - global_position.distance_to(target.global_position))
    fitness += f_boost
    return f_boost


func get_fitness() -> float:
    # don't give negative fitness
    return max(1, fitness)
