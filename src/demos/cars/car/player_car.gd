extends RigidBody2D

"""Credit for the original version of this script goes to Ivan Skodje. This is a
modified version of his top_down_vehicle.gd script, which can be found at:
github.com/ivanskodje-godotengine/Vehicle-Controller-2D

The script overrides the behavior of a rigidbody to produce an arcade style top-down
car that can also drift. I have changed the parameters to allow very sharp turns and
high acceleration.

Initially I used a controller class that simply calls the act() method on the standard
car.gd class that is used by the AI, but this did not result in very smooth steering.
Steering based on keyboard input happens during the _physics_process().
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
# disable/enable showing the distances to the wall
var show_casts = false

# A car cannot complete a full lap if it hasn't completed a half lap
var completed_half_lap = false
# if a car drives back from the start, it hasn't driven the full course. This
# variable prevents this.
var has_cheated = false
var num_completed_laps = 0
onready var center = get_node("../../Center")
onready var start = get_node("../../Start")

# labels showing what the cars senses read
onready var labels = $Labels

# keep track of the time since the last physics update, to update sensor information
# in regular intervals (0.2 seconds).
var time = 0

# gets emitted when the car crashes
signal player_crashed(name)

func _ready():
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
    if show_casts:
        for _new_caster in num_casts:
            var caster = RayCast2D.new()
            var cast_point = Vector2(0, -sight_range).rotated(cast_angle)
            caster.enabled = false; caster.cast_to = cast_point
            # only scan for bounds. maybe do this with groups later?
            caster.collide_with_areas = true; caster.collide_with_bodies = false
            add_child(caster); raycasters.append(caster)
            cast_angle += cast_arc
    # Added steering_damp since it may not be obvious at first glance that
    # you can simply change angular_damp to get the same effect
    set_angular_damp(steering_damp)


func _physics_process(delta):
    """This script overrides the behavior of a rigidbody (Not my idea, but it works).
    """
    # make sure that sensory information gets updated every 0.2 seconds
    time += delta
    if time > 0.2:
        time = 0; sense()
    # Update the forward speed
    speed = -get_up_velocity().dot(transform.y)
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
    # Accelerate
    if Input.is_action_pressed("ui_up"):
        _velocity += -transform.y * acceleration
    # Break / Reverse
    elif Input.is_action_pressed("ui_down"):
        _velocity -= -transform.y * acceleration
    # Prevent exceeding max velocity
    var max_speed = (Vector2(0, -1) * max_forward_velocity).rotated(get_rotation())
    var x = clamp(_velocity.x, -abs(max_speed.x), abs(max_speed.x))
    var y = clamp(_velocity.y, -abs(max_speed.y), abs(max_speed.y))
    _velocity = Vector2(x, y)
    # Torque depends that the vehicle is moving
    var torque = lerp(0, steering_torque, _velocity.length() / max_forward_velocity)
    # Steer Right
    if Input.is_action_pressed("ui_right"):
        set_angular_velocity(torque * sign(speed))
    # Steer Left
    elif Input.is_action_pressed("ui_left"):
        set_angular_velocity(-torque * sign(speed))
    # Apply the force
    set_linear_velocity(_velocity)
    

func get_up_velocity() -> Vector2:
    # Returns the vehicle's forward velocity
    return -transform.y * _velocity.dot(-transform.y)


func get_right_velocity() -> Vector2:
    # Returns the vehicle's sidewards velocity
    return -transform.x * _velocity.dot(-transform.x)


func sense() -> Array:
    """Returns the information used to feed the neural network. Consists of num_casts
    raycast distances, the cars speed relative to it's max velocity, the current angular
    velocity, and the drifting factor of the car.
    """
    var senses = []
    # get the distance to the nearest obstacles
    if show_casts:
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
        # update the labels
        for i in labels.get_child_count():
            labels.get_child(i).text = str(senses[i])
    var rel_speed = range_lerp(speed, -max_forward_velocity, max_forward_velocity, 0, 2)
    # Append relative speed, angular_velocity and _drift_factor to the cars senses
    senses.append(rel_speed)
    senses.append(angular_velocity)
    senses.append(_drift_factor)
    return senses

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
        emit_signal("player_crashed", "The Player")


func _on_Explosion_animation_finished() -> void:
    $Explosion.stop(); $Explosion.hide()
