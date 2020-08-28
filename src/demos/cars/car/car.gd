extends RigidBody2D

"""Credit for the original version of this script goes to Ivan Skodje. This is a
modified version of his top_down_vehicle.gd script, which can be found at:
github.com/ivanskodje-godotengine/Vehicle-Controller-2D

The script overrides the behavior of a rigidbody to produce an arcade style top-down
car that can also drift. I have changed the parameters to allow very sharp turns and
high acceleration. All steering happens during the act() method.
"""

# Driving Properties
var acceleration = 15
var max_forward_velocity = 1000
var drag_coefficient = 0.99 # Recommended: 0.99 - Affects how fast you slow down
var steering_torque = 6 # Affects turning speed
var steering_damp = 8 # 7 - Affects how fast the torque slows down

# Drifting & Tire Friction
var can_drift = true
var wheel_grip_sticky = 0.85 # Default drift coef (will stick to road, most of the time)
var wheel_grip_slippery = 0.99 # Affects how much you "slide"
var drift_extremum = 250 # Right velocity higher than this will cause you to slide
var drift_asymptote = 20 # During a slide you need to reduce right velocity to this to gain control
var _drift_factor = wheel_grip_sticky # Determines how much (or little) your vehicle drifts

# Vehicle velocity and angular velocity. Override rigidbody velocity in physics process
var _velocity = Vector2()
var _angular_velocity = 0

# vehicle forward speed
var speed: int

# hold a specified num of raycasts in an array to sense the environment
var raycasters = []
var sight_range = 1000
var num_casts = 8

# A car cannot complete a full lap if it hasn't completed a half lap
var completed_half_lap = false
# if a car drives back from the start, it hasn't driven the full course. This
# variable prevents this.
var has_cheated = false
var num_completed_laps = 0
#
onready var center = get_node("../../Center")
onready var start = get_node("../../Start")

# signal that let's the controlling agent know it just died
signal death

func _ready() -> void:
    """Connect the car to the bounds of the track, receive a signal when (any) car
    collides with the bounds. Generate raycasts to measure the distance to the bounds.
    """
    # connect a signal from track bounds, to detect when a crash occurs
    get_node("../../Bounds").connect("body_entered", self, "crash")
    # Top Down Physics
    set_gravity_scale(0.0)
    # Generate specified number of raycasts 
    var cast_angle = 0
    var cast_arc = TAU / num_casts
    for _new_caster in num_casts:
        var caster = RayCast2D.new()
        var cast_point = Vector2(0, -sight_range).rotated(cast_angle)
        caster.enabled = false
        caster.cast_to = cast_point
        caster.collide_with_areas = true
        caster.collide_with_bodies = false
        add_child(caster)
        raycasters.append(caster)
        cast_angle += cast_arc
    # Added steering_damp since it may not be obvious at first glance that
    # you can simply change angular_damp to get the same effect
    set_angular_damp(steering_damp)


func _physics_process(_delta) -> void:
    """This script overrides the behavior of a rigidbody (Not my idea, but it works).
    """
    # use our own drag
    _velocity *= drag_coefficient
    if can_drift:
        # If we are sticking to the road and our right velocity is high enough
        if _drift_factor == wheel_grip_sticky and get_right_velocity().length() > drift_extremum:
            _drift_factor = wheel_grip_slippery
        # If we are sliding on the road
        elif get_right_velocity().length() < drift_asymptote:
            _drift_factor = wheel_grip_sticky
    # Add drift to velocity
    _velocity = get_up_velocity() + (get_right_velocity() * _drift_factor)
    # Override Rigidbody movement
    set_linear_velocity(_velocity)
    set_angular_velocity(_angular_velocity)
    # Update the forward speed
    speed = -get_up_velocity().dot(transform.y)


func get_up_velocity() -> Vector2:
    # Returns the vehicle's forward velocity
    return -transform.y * _velocity.dot(-transform.y)


func get_right_velocity() -> Vector2:
    # Returns the vehicle's sidewards velocity
    return -transform.x * _velocity.dot(-transform.x)


# ---------- FUNCTIONS REQUIRED BY NEAT

func sense() -> Array:
    """Returns the information used to feed the neural network. Consists of num_casts
    raycast distances, the cars speed relative to it's max velocity, the current angular
    velocity, and the drifting factor of the car.
    """
    var senses = []
    # get the distance to the nearest obstacles
    for caster in raycasters:
        # this performs a raycast even though the caster is disabled
        caster.force_raycast_update()
        if caster.is_colliding():
            var collision = caster.get_collision_point()
            var distance = (collision - global_position).length()
            var relative_distance = range_lerp(distance, 0, sight_range, 0, 2)
            senses.append(relative_distance)
        else:
            senses.append(1)
    var rel_speed = range_lerp(speed, -max_forward_velocity, max_forward_velocity, 0, 2)
    # Append relative speed, angular_velocity and _drift_factor to the cars senses
    senses.append(rel_speed)
    senses.append(angular_velocity)
    senses.append(_drift_factor)
    return senses

func act(actions: Array) -> void:
    """Use the networks output to control the cars steering.
    """
    # Torque depends that the vehicle is moving
    var torque = lerp(0, steering_torque, _velocity.length() / max_forward_velocity)
    # accelerate
    if actions[0] > 0.3:
        _velocity += -transform.y * acceleration
    # break & reverse
    elif actions[1] > 0.3:
        _velocity -= -transform.y * acceleration
    # steer right
    if actions[2] > 0.2:
        _angular_velocity = range_lerp(actions[2], 0.2, 1, 0, 1) * torque * sign(speed)
    # steer left
    elif actions[3] > 0.2:
        _angular_velocity = range_lerp(actions[3], 0.2, 1, 0, 1) * -torque * sign(speed)
    # Prevent exceeding max velocity
    var max_speed = (Vector2(0, -1) * max_forward_velocity).rotated(rotation)
    var x = clamp(_velocity.x, -abs(max_speed.x), abs(max_speed.x))
    var y = clamp(_velocity.y, -abs(max_speed.y), abs(max_speed.y))
    _velocity = Vector2(x, y)


func get_fitness() -> float:
    """fitness is measured in (radian) degrees driven around the center of the track.
    A full lap amounts to TAU (2*PI = 6.28...). If one lap is completed, just continue
    adding to TAU. Because driving backwards from the start would amount to an (almost)
    completed track, a HalfLap and FullLap checkpoint are utilized to prevent the car
    from cheating (see checkpoint.gd script).
    """
    if not has_cheated:
        # get the vectors used to calculate how far from the start the car has driven
        var start_vec = start.global_position - center.global_position 
        var end_vec = self.global_position - center.global_position 
        var angle = start_vec.angle_to(end_vec)
        # degrees 0-180 > 0, degrees 180-360 < 0.
        if angle < 0:
            angle += TAU
        # add TAU for every completed lap
        for lap in num_completed_laps:
            angle += TAU
        return angle
    # return 0 fitness if the car has cheated.
    else:
        return 0.0


# ---------- CRASHING

func crash(body) -> void:
    """Check if the body that collided with the bounds is self. If so, show an explosion
    and emit the death signal, causing the fitness to be evaluated by the ga node.
    JUSTIFICATION: Using a signal from the track and then checking every car if it was the
    one that crashed is apparently a lot more efficient than providing every car with
    it's own collider.
    """
    if body == self:
        $Explosion.show(); $Explosion.play()
        $Sprite.hide()
        emit_signal("death")


func _on_Explosion_animation_finished() -> void:
    $Explosion.stop(); hide()
