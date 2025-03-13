extends Camera2D

## A simple 2D camera that can pan with right click and zoom using mouse scroll.

const ZOOM_SPEED = Vector2(0.2, 0.2)
const MIN_ZOOM = 0.25
const MAX_ZOOM = 10

@onready var wanted_zoom = zoom
@onready var wanted_position = position
var dragging = false

func _unhandled_input(event):
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT: # Right button
				dragging = true
				if dragging and not event.pressed:
					dragging = false
					
			MOUSE_BUTTON_WHEEL_UP: # Scroll wheel up
				wanted_zoom -= ZOOM_SPEED
				if wanted_zoom.x > MIN_ZOOM:
					wanted_position = wanted_position.lerp(get_global_mouse_position(), 0.3)
				
			MOUSE_BUTTON_WHEEL_DOWN: # Scroll wheel down
				wanted_zoom += ZOOM_SPEED
				if wanted_zoom.x < MAX_ZOOM:
					wanted_position = wanted_position.lerp(get_global_mouse_position(), -0.1)
			_:
				pass
		
		# Clamp the zoom so it doesn't go below MIN_ZOOM or above MAX_ZOOM
		wanted_zoom = Vector2(clamp(wanted_zoom.x, MIN_ZOOM, MAX_ZOOM), clamp(wanted_zoom.y, MIN_ZOOM, MAX_ZOOM))
	
	if event is InputEventMouseMotion and dragging:
		wanted_position -= event.relative*zoom

func _process(delta):
	# Move/Zoom the camera smoothly
	zoom = zoom.lerp(wanted_zoom, 4*delta)
	position = position.lerp(wanted_position, 5*delta)




