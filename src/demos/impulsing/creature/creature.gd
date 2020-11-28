extends RigidBody2D

# TODO:
# - currently does not account for rotation when applying impulse (should be
#   rotated by angle)
# - maybe fitness should increase exponentially (however 2 is too much)

var impulse_power = 10

onready var target = get_node("../../Target")

var fitness: float
signal death


func sense() -> Array:
    var direction_to_target = target.global_position - global_position
    return [direction_to_target.x, direction_to_target.y,
            linear_velocity.x, linear_velocity.y]


func act(actions: Array) -> void:
    if actions[0] > 0.2:
        apply_central_impulse(Vector2(0, -impulse_power))
    elif actions[0] < -0.2:
        apply_central_impulse(Vector2(0, impulse_power))
    if actions[1] > 0.2:
        apply_central_impulse(Vector2(-impulse_power, 0))
    elif actions[1] < -0.2:
        apply_central_impulse(Vector2(impulse_power, 0))


func get_fitness() -> float:
    fitness = 2000 - global_position.distance_to(target.global_position)
    # don't give negative fitness
    return max(10, fitness)
