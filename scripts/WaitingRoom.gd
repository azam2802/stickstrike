extends Control

@onready var room_name_label = $VBoxContainer/RoomNameLabel
@onready var player_list = $VBoxContainer/PlayerList
@onready var waiting_label = $VBoxContainer/WaitingLabel
var players_count = 0
var max_players = 2  # Maximum number of players for game to start
var connect_timer = 0.0

func _ready():
	# Set a timer to connect signals after a short delay
	connect_timer = 0.5

func _process(delta):
	# Handle connection timer
	if connect_timer > 0:
		connect_timer -= delta
		if connect_timer <= 0:
			_connect_network_signals()

func _connect_network_signals():
	# Connect signals with null checks
	if NetworkManager:
		print("WaitingRoom: Connecting signals to NetworkManager")
		
		# Disconnect existing connections first to avoid duplicates
		_disconnect_signals()
		
		if NetworkManager.has_signal("room_joined"):
			NetworkManager.room_joined.connect(_on_room_joined)
		if NetworkManager.has_signal("game_started"):
			NetworkManager.game_started.connect(_on_game_started)
		if NetworkManager.has_signal("player_joined"):
			NetworkManager.player_joined.connect(_on_player_joined)
		if NetworkManager.has_signal("player_left"):
			NetworkManager.player_left.connect(_on_player_left)
		if NetworkManager.has_signal("error_received"):
			NetworkManager.error_received.connect(_on_error_received)
		if NetworkManager.has_signal("game_state_updated"):
			NetworkManager.game_state_updated.connect(_on_game_state_updated)
		
		# Initialize the room information from the current room data
		if NetworkManager.current_room:
			room_name_label.text = "Room: " + NetworkManager.current_room.name
			
			# Adding initial player to the list (self)
			if NetworkManager.player_id:
				player_list.clear()
				player_list.add_item("Player " + NetworkManager.player_id.substr(0, 4) + " (You)")
				player_list.set_item_metadata(0, NetworkManager.player_id)
				players_count = 1
				waiting_label.text = "Waiting for players... (%d/%d)" % [players_count, max_players]

func _disconnect_signals():
	if NetworkManager:
		if NetworkManager.has_signal("room_joined") and NetworkManager.room_joined.is_connected(_on_room_joined):
			NetworkManager.room_joined.disconnect(_on_room_joined)
		if NetworkManager.has_signal("game_started") and NetworkManager.game_started.is_connected(_on_game_started):
			NetworkManager.game_started.disconnect(_on_game_started)
		if NetworkManager.has_signal("player_joined") and NetworkManager.player_joined.is_connected(_on_player_joined):
			NetworkManager.player_joined.disconnect(_on_player_joined)
		if NetworkManager.has_signal("player_left") and NetworkManager.player_left.is_connected(_on_player_left):
			NetworkManager.player_left.disconnect(_on_player_left)
		if NetworkManager.has_signal("error_received") and NetworkManager.error_received.is_connected(_on_error_received):
			NetworkManager.error_received.disconnect(_on_error_received)
		if NetworkManager.has_signal("game_state_updated") and NetworkManager.game_state_updated.is_connected(_on_game_state_updated):
			NetworkManager.game_state_updated.disconnect(_on_game_state_updated)

func _exit_tree():
	# Disconnect signals when the scene is exited
	_disconnect_signals()

func _on_room_joined(room, players=null):
	if room:
		room_name_label.text = "Room: " + room.name
	if players:
		update_player_list(players)
	else:
		# If we don't have players data, add at least this player
		if NetworkManager and NetworkManager.player_id:
			player_list.clear()
			player_list.add_item("Player " + NetworkManager.player_id.substr(0, 4) + " (You)")
			player_list.set_item_metadata(0, NetworkManager.player_id)
			players_count = 1
		
	# Update waiting label
	waiting_label.text = "Waiting for players... (%d/%d)" % [players_count, max_players]
		
	# Check if we already have 2 players and should start the game
	if players_count >= max_players:
		_start_game()

func _on_game_state_updated(state):
	print("WaitingRoom: Received game state update")
	if state.has("players"):
		var players = state.players
		update_player_list(players)

func _on_game_started(room, players):
	print("WaitingRoom: Game starting with room ", room, " and players ", players)
	waiting_label.text = "Game starting..."
	
	# Use a simple delay instead of SceneTreeTimer
	await get_tree().create_timer(1.0).timeout
	_change_scene_to_game()

func _change_scene_to_game():
	if is_inside_tree() and get_tree():
		get_tree().change_scene_to_file("res://scenes/GameScene.tscn")

func _on_player_joined(player):
	if player:
		print("Player joined: ", player.name)
		player_list.add_item(player.name)
		player_list.set_item_metadata(player_list.get_item_count() - 1, player.id)
		players_count += 1
		
		# Update waiting label
		waiting_label.text = "Waiting for players... (%d/%d)" % [players_count, max_players]
		
		# Check if we need to start the game now
		if players_count >= max_players:
			_start_game()

func _on_player_left(player_id):
	if player_id:
		for i in range(player_list.get_item_count()):
			if player_list.get_item_metadata(i) == player_id:
				player_list.remove_item(i)
				players_count -= 1
				
				# Update waiting label
				waiting_label.text = "Waiting for players... (%d/%d)" % [players_count, max_players]
				break

func _on_error_received(message):
	print("Error in waiting room: ", message)
	var dialog = AcceptDialog.new()
	dialog.title = "Ошибка"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	await dialog.confirmed
	dialog.queue_free()

func update_player_list(players):
	if not players:
		return
		
	player_list.clear()
	players_count = 0
	print("Updating player list with: ", players)
	for player_id in players.keys():
		var player = players[player_id]
		var display_name = player.name
		
		# Add (You) tag for local player
		if player_id == NetworkManager.player_id:
			display_name += " (You)"
			
		player_list.add_item(display_name)
		player_list.set_item_metadata(player_list.get_item_count() - 1, player_id)
		players_count += 1
	
	# Update waiting label
	waiting_label.text = "Waiting for players... (%d/%d)" % [players_count, max_players]
	
	# Check if we need to start the game now
	if players_count >= max_players:
		_start_game()

func _start_game():
	print("Starting game - 2 players have joined!")
	# The server should automatically trigger game_started, but we can also
	# change scene directly if needed after a short delay
	waiting_label.text = "All players joined! Starting game..."
	
	# Use a simple delay instead of SceneTreeTimer
	await get_tree().create_timer(1.0).timeout
	_change_scene_to_game()
