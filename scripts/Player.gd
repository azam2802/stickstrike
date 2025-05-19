extends Node2D

var power = 50
var health = 100
var is_local_player = false
var player_id = ""
var health_bar = null
var network_manager = null

# Joystick input
var joystick_axis = 0.0
var joystick_strength = 0.0

# Debug label for mobile testing
var debug_label = null

func _ready():
	# Create a debug label for mobile testing
	if OS.get_name() == "Android" or OS.get_name() == "iOS" or true: # Always show for testing
		debug_label = Label.new()
		debug_label.position = Vector2(0, -50)
		debug_label.modulate = Color.GREEN
		add_child(debug_label)

func setup(id, health_progress_bar, net_manager, local_player):
	player_id = id
	health_bar = health_progress_bar
	network_manager = net_manager
	is_local_player = local_player
	health = 100

func _physics_process(delta):
	if is_local_player:
		# Handle keyboard input for desktop
		var keyboard_axis = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		
		# Use joystick input if available, otherwise use keyboard
		var movement_axis = joystick_axis if abs(joystick_axis) > 0.1 else keyboard_axis
		
		# Apply movement force
		if abs(movement_axis) > 0.1:
			$Torso.apply_impulse(Vector2.ZERO, Vector2.RIGHT * movement_axis * power)
		
		# Send position update to server if we're connected
		if network_manager and network_manager.connected:
			network_manager.send_position(global_position, Vector2.ZERO)
		
		# Update debug label
		if debug_label:
			debug_label.text = "Joy: %.2f\nStrength: %.2f" % [joystick_axis, joystick_strength]

# Set joystick input from mobile controls
func set_joystick_input(axis, strength):
	joystick_axis = axis
	joystick_strength = strength
