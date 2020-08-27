extends RigidBody2D

"""A lunar lander that uses impulses to move around. It uses three colliders to check
for ground contact or crashing, and three raycasts to scan the distance to the ground
and to the left and right.
"""

# ---------- THRUSTERS AND CONTROL
# the power with which the thrusters will fire. Should be high enough that the
# frequency with which neural networks process gives them enough power to control.
var main_power = 40
var side_power = 15
# nested array containing animations, firing directions and strengths for every thruster
onready var thrusters = [
	[$Thrusters/LeftThruster, Vector2(1, 0), side_power],
	[$Thrusters/RightThruster, Vector2(-1, 0), side_power],
	[$Thrusters/MainThruster, Vector2(0, -1), main_power]
]
# used to index the thrusters in the thrusters array
enum THRUSTER {left, right, main}
# used to refer to the networks outputs in the act() method. Going left requires firing
# the right thruster, and vice versa.
enum MANEUVER {go_left, go_right, go_up}

# ---------- LANDING, CRASHING AND FITNESS
# Fitness is reduced by the speed on ground impact and the angle the lander has when
# it comes to a rest (punish landing on slopes). It is increased by the amount of
# remaining fuel. Most points are awarded for landing slow enough not to crash.
# If the hull makes first contact with the terrain instead of the legs, fitness is 0.
var fitness: int
# Impact_velo is always updated during sense(), because querying it once the collider
# has made contact often results in obtaining the velocity after the fall has been already
# stopped by the ground. Gets multiplied with velocity_punishment_mult and reduces fitness.
var impact_velocity: float
var velocity_punishment_mult = 0.5
# true only if both legs make contact with the ground and velocity is below crashing_speed
var landed_successfully = false
var crashing_speed = 75
# bonus awarded for landing successfully
var landing_bonus = 400
# if a part other than the legs makes contact, consider it a fatal_crash, 0 fitness
var fatal_crash = false
# limited fuel causes the landers to drop if they loiter too long
var fuel = 80
# remaining fuel is multiplied with bonus to award fuel-efficiency
var fuel_bonus = 2
# gets emitted when the lander crashes
signal death


func _ready() -> void:
	"""disable all RayCasters, since force_raycast_update() is used
	"""
	$GroundCast.enabled = false
	$LeftCast.enabled = false
	$RightCast.enabled = false


# ---------- FUNCTIONS REQUIRED BY NEAT

func sense() -> Array:
	"""Returns an array containing information about the crafts current state,
	used to feed the neural network.
	"""
	# always update impact_velocity during sense, causing it to lag behind when
	# the craft actually impacts the ground
	impact_velocity = linear_velocity.length()
	# use downward facing raycast to get distance to ground and slope of the ground below
	var ground_measure = get_relative_distance_and_slope($GroundCast)
	# function returns [distance, slope]
	var rel_ground_dist = ground_measure[0]
	var ground_slope = ground_measure[1]
	# get just the distance to the left and right -> scaled to the measure_dist
	var rel_left_dist = get_relative_distance_and_slope($LeftCast)[0]
	var rel_right_dist = get_relative_distance_and_slope($RightCast)[0]
	var rel_speed = (linear_velocity / 50)
	return [rel_ground_dist, rel_speed.x, rel_speed.y, ground_slope, rel_left_dist, rel_right_dist]


func get_relative_distance_and_slope(caster: RayCast2D) -> Array:
	"""Use the Raycast given as an argument to calculate the distance to the terrain,
	and the slope of the terrain.
	"""
	caster.force_raycast_update()
	var distance = (caster.get_collision_point() - global_position).length()
	var relative_distance = distance / caster.cast_to.length()
	var slope = caster.get_collision_normal().x
	return [relative_distance, slope]


func act(actions: Array) -> void:
	"""fire the thrusters according to the networks output.
	"""
	# hide the thruster sprites again
	for thruster in thrusters:
		thruster[0].hide(); thruster[0].stop()
	# fire thrusters based on actions
	if fuel > 0:
		if actions[MANEUVER.go_left] > 0.5:
			fire_thruster(thrusters[THRUSTER.right])
		if actions[MANEUVER.go_right] > 0.5:
			fire_thruster(thrusters[THRUSTER.left])
		if actions[MANEUVER.go_up] > 0.5:
			fire_thruster(thrusters[THRUSTER.main])


func get_fitness() -> int:
	"""Calculate the fitness based on how softly the craft has touched down, how
	much fuel it consumed, and how steep the slope it landed on is
	"""
	sleeping = true
	# if a landing leg made first contact with the ground
	if not fatal_crash:
		# if speed was below crashing speed and slope not too steep
		if landed_successfully:
			# reduce landing bonus based on how steep the terrain is
			var slope_factor_punish = 1 - (abs(transform.get_rotation() / (PI/6)))
			fitness = fuel * fuel_bonus + landing_bonus * slope_factor_punish
		else:
			# reward crashing with lower velocities
			var velocity_punishment = impact_velocity * velocity_punishment_mult
			fitness = fuel * fuel_bonus - velocity_punishment
	# if the hull made first contact with the ground
	else:
		fitness = 0
	# prevent awarding negative fitness (breaks NEAT)
	if fitness < 0:
		fitness = 0
	return fitness

# ---------- FIRING THRUSTERS

func fire_thruster(thruster: Array) -> void:
	"""Apply an impulse to the craft, show a firing animation and reduce fuel.
	"""
	fuel -= 1
	var animation = thruster[0]
	var direction = thruster[1]
	var power = thruster[2]
	# show the sprite again, start the play animation
	animation.show(); animation.play()
	# apply an impulse translated to relative position in the world
	apply_central_impulse(direction.rotated(transform.get_rotation()) * power)

# ---------- CRASHING AND LANDING

"""Unfortunately every method of checking for ground contact that utilizes a single
collider gets exploited by the algorithm somehow. Because I don't want to poll the
colliders every frame, signals are connected to 2 booleans for both legs of the craft.
"""
var left_contact = false
var right_contact = false

# enabling and disabling the left contact
func _on_LeftContact_body_entered(body) -> void:
	if body.is_in_group("terrain"):
		left_contact = true
		check_ground_contact()

func _on_LeftContact_body_exited(body) -> void:
	if body.is_in_group("terrain"):
		left_contact = false

# enabling and disabling the right contact
func _on_RightContact_body_entered(body) -> void:
	if body.is_in_group("terrain"):
		right_contact = true
		check_ground_contact()

func _on_RightContact_body_exited(body) -> void:
	if body.is_in_group("terrain"):
		right_contact = false


func _on_HullContact_body_entered(body) -> void:
	"""A collision with a part that is not a landing leg results in a fatal crash.
	"""
	if body.is_in_group("terrain"):
		fatal_crash = true
		crash()


func check_ground_contact() -> void:
	"""If a leg makes contact with the ground, check first if the craft is too fast.
	If so, crash it and punish it for being to fast. If the craft is slow enough,
	check if both legs make contact and the craft is not tilted too far -> land it.
	"""
	if impact_velocity > crashing_speed:
		fatal_crash = false
		crash()
	elif left_contact and right_contact and abs(transform.get_rotation()) < PI/6:
		land()


func crash() -> void:
	"""Show an explosion and emit the death signal, causing the fitness to be evaluated.
	"""
	$Sprite.hide(); $Thrusters.hide()
	$Explosion.show()
	$Explosion.play()
	emit_signal("death")


func land() -> void:
	"""Plant a flag and emit the death signal, causing the fitness to be evaluated.
	"""
	$Sprite.hide(); $Thrusters.hide()
	$Flag.show()
	landed_successfully = true
	emit_signal("death")


func _on_Explosion_animation_finished() -> void:
	$Explosion.stop(); $Explosion.hide()
