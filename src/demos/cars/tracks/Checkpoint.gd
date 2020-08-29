extends Area2D

"""Every track has two checkpoint Area2D's, one for completing half of the lap,
and one at the finish line.
"""

func _ready() -> void:
	connect("body_entered", self, "check_curr_lap")


func check_curr_lap(body) -> void:
	"""Based on the name of the node, it is determined whether this is the checkpoint
	at halfway of the track, or the finish line checkpoint. The car has a property
	that tracks if it has passed the halfway checkpoint, in which case it is eligible
	to collect the reward for completing the track (a full rotation = TAU). If it
	passes the FullLap Checkpoint without having passed HalfLap, that means the car
	has driven backwards from the start.
	"""
	if name == "HalfLap":
		body.completed_half_lap = true
	elif name == "FullLap":
		if body.completed_half_lap:
			body.num_completed_laps += 1
			body.completed_half_lap = false
		else:
			body.has_cheated = true
			body.crash(body)