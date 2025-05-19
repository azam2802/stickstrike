extends Control

# Joystick properties
var joystick_active = false
var joystick_origin = Vector2.ZERO
var joystick_position = Vector2.ZERO
var joystick_direction = Vector2.ZERO
var joystick_strength = 0.0
var max_distance = 100.0  # Maximum distance the joystick can move from center
var mouse_pressed = false # For mouse input on desktop

# Emitted when joystick moves
signal joystick_moved(direction, strength)

func _ready():
	# Set the joystick origin to the center of the control
	joystick_origin = Vector2($OuterCircle.size.x / 2, $OuterCircle.size.y / 2)
	joystick_position = joystick_origin
	
	# Make the joystick circular
	$OuterCircle.set_anchors_preset(Control.PRESET_CENTER)
	$InnerCircle.set_anchors_preset(Control.PRESET_CENTER)
	
	# Set the initial position of the inner circle
	$InnerCircle.position = joystick_origin - $InnerCircle.size / 2

func _process(delta):
	if joystick_active:
		# Update joystick position based on input
		update_joystick()

func _input(event):
	# Handle touch input
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		# Check if the touch is within the joystick area
		if event.position.distance_to(global_position + joystick_origin) <= max_distance + 50:
			if event is InputEventScreenTouch:
				if event.pressed:
					joystick_active = true
				else:
					joystick_active = false
					reset_joystick()
			elif event is InputEventScreenDrag and joystick_active:
				joystick_position = event.position - global_position
				
				# Limit the joystick position to the maximum distance
				var distance = joystick_position.distance_to(joystick_origin)
				if distance > max_distance:
					joystick_position = joystick_origin + (joystick_position - joystick_origin).normalized() * max_distance
	
	# Handle mouse input for testing on desktop
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.position.distance_to(global_position + joystick_origin) <= max_distance + 50:
					mouse_pressed = true
					joystick_active = true
					joystick_position = event.position - global_position
			else:
				mouse_pressed = false
				joystick_active = false
				reset_joystick()
	
	if event is InputEventMouseMotion and mouse_pressed:
		joystick_position = event.position - global_position
		
		# Limit the joystick position to the maximum distance
		var distance = joystick_position.distance_to(joystick_origin)
		if distance > max_distance:
			joystick_position = joystick_origin + (joystick_position - joystick_origin).normalized() * max_distance

func update_joystick():
	# Calculate the joystick direction and strength
	joystick_direction = (joystick_position - joystick_origin).normalized()
	joystick_strength = joystick_position.distance_to(joystick_origin) / max_distance
	
	# Update the inner circle position
	$InnerCircle.position = joystick_position - $InnerCircle.size / 2
	
	# Emit the joystick_moved signal
	emit_signal("joystick_moved", joystick_direction, joystick_strength)

func reset_joystick():
	# Reset the joystick to its original position
	joystick_position = joystick_origin
	joystick_direction = Vector2.ZERO
	joystick_strength = 0.0
	$InnerCircle.position = joystick_origin - $InnerCircle.size / 2
	
	# Emit the joystick_moved signal with zero values
	emit_signal("joystick_moved", Vector2.ZERO, 0.0)

func _on_touch_screen_button_pressed():
	joystick_active = true

func _on_touch_screen_button_released():
	joystick_active = false
	reset_joystick() 