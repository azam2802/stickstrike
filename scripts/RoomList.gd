extends Control

var rooms = []
var connect_timer = 0.0

func _ready():
	$VBoxContainer/HBoxContainer/CreateRoomButton.pressed.connect(_on_create_room_button_pressed)
	$VBoxContainer/HBoxContainer/RefreshButton.pressed.connect(_on_refresh_button_pressed)
	$VBoxContainer/BackButton.pressed.connect(_on_back_button_pressed)
	$VBoxContainer/RoomList.item_selected.connect(_on_room_selected)
	
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
		print("RoomList: Connecting signals to NetworkManager")
		
		# Disconnect existing connections first to avoid duplicates
		_disconnect_signals()
		
		if NetworkManager.has_signal("connection_established"):
			NetworkManager.connection_established.connect(_on_connection_established)
		if NetworkManager.has_signal("connection_error"):
			NetworkManager.connection_error.connect(_on_connection_error)
		if NetworkManager.has_signal("rooms_list_updated"):
			NetworkManager.rooms_list_updated.connect(_on_rooms_list_updated)
		if NetworkManager.has_signal("room_created"):
			NetworkManager.room_created.connect(_on_room_created)
		if NetworkManager.has_signal("room_joined"):
			NetworkManager.room_joined.connect(_on_room_joined)
		if NetworkManager.has_signal("game_started"):
			NetworkManager.game_started.connect(_on_game_started)
		if NetworkManager.has_signal("error_received"):
			NetworkManager.error_received.connect(_on_error_received)
		
		# Connect to server if not already connected
		if not NetworkManager.connected:
			if NetworkManager.connect_to_server():
				# Connection started, will get result via signal
				$VBoxContainer/RoomList.clear()
				$VBoxContainer/RoomList.add_item("Connecting to server...")

func _disconnect_signals():
	if NetworkManager:
		if NetworkManager.connection_established.is_connected(_on_connection_established):
			NetworkManager.connection_established.disconnect(_on_connection_established)
		if NetworkManager.connection_error.is_connected(_on_connection_error):
			NetworkManager.connection_error.disconnect(_on_connection_error)
		if NetworkManager.rooms_list_updated.is_connected(_on_rooms_list_updated):
			NetworkManager.rooms_list_updated.disconnect(_on_rooms_list_updated)
		if NetworkManager.room_created.is_connected(_on_room_created):
			NetworkManager.room_created.disconnect(_on_room_created)
		if NetworkManager.room_joined.is_connected(_on_room_joined):
			NetworkManager.room_joined.disconnect(_on_room_joined)
		if NetworkManager.game_started.is_connected(_on_game_started):
			NetworkManager.game_started.disconnect(_on_game_started)
		if NetworkManager.error_received.is_connected(_on_error_received):
			NetworkManager.error_received.disconnect(_on_error_received)

func _exit_tree():
	# Disconnect signals when the scene is exited
	_disconnect_signals()

func _on_rooms_list_updated(room_list):
	print("Received room list: ", room_list)
	rooms = room_list
	_update_room_list_display()

func _update_room_list_display():
	$VBoxContainer/RoomList.clear()
	
	if rooms.size() == 0:
		$VBoxContainer/RoomList.add_item("No rooms available. Create one!")
		return
		
	for room in rooms:
		$VBoxContainer/RoomList.add_item(
			"%s (Игроков: %d/%d)" % [room.name, room.playerCount, room.maxPlayers]
		)

func _on_create_room_button_pressed():
	if NetworkManager and NetworkManager.connected:
		var room_name = "Новая комната " + str(randi() % 1000)
		NetworkManager.create_room(room_name, "Player" + str(randi() % 1000))
	else:
		_show_error("Not connected to server. Please wait or restart the application.")

func _on_room_created(room):
	print("Room created: ", room)
	_go_to_waiting_room()

func _on_refresh_button_pressed():
	if NetworkManager and NetworkManager.connected:
		NetworkManager.get_rooms()
	else:
		$VBoxContainer/RoomList.clear()
		$VBoxContainer/RoomList.add_item("Not connected to server")

func _on_back_button_pressed():
	if get_tree():
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_room_selected(index):
	if NetworkManager and NetworkManager.connected and rooms.size() > 0 and index < rooms.size():
		var selected_room = rooms[index]
		NetworkManager.join_room(selected_room.id, "Player" + str(randi() % 1000))
	else:
		_show_error("Cannot join room. Not connected or room not available.")

func _on_room_joined(room):
	print("Joined room: ", room)
	_go_to_waiting_room()

func _go_to_waiting_room():
	if not NetworkManager:
		_show_error("NetworkManager is null")
		return
		
	# Only proceed if tree is available
	if not is_inside_tree() or not get_tree():
		print("Error: Scene tree not available")
		return
		
	print("Переходим в комнату ожидания...")
	# Переходим в комнату ожидания
	if get_tree():
		get_tree().change_scene_to_file("res://scenes/WaitingRoom.tscn")

func _on_game_started(room, players):
	print("Game started in room: ", room, " with players: ", players)
	
	# Only proceed if tree is available
	if not is_inside_tree() or not get_tree():
		print("Error: Scene tree not available")
		return
	
	print("Переходим в игровую сцену...")
	# Change to game scene
	if get_tree():
		get_tree().change_scene_to_file("res://scenes/GameScene.tscn")

func _on_connection_established():
	print("Connected to server")
	if NetworkManager:
		NetworkManager.get_rooms() # Request room list

func _on_connection_error(message):
	print("Connection error: ", message)
	# Show error to user
	$VBoxContainer/RoomList.clear()
	$VBoxContainer/RoomList.add_item("Ошибка подключения: " + message)

func _on_error_received(message):
	_show_error(message)

func _show_error(message):
	print("Error: ", message)
	# Show error to user as a notification
	var dialog = AcceptDialog.new()
	dialog.title = "Ошибка"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	await dialog.confirmed
	dialog.queue_free() 
