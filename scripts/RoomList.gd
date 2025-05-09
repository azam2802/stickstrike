extends Control

var rooms = []
var network_manager

func _ready():
	$VBoxContainer/HBoxContainer/CreateRoomButton.pressed.connect(_on_create_room_button_pressed)
	$VBoxContainer/HBoxContainer/RefreshButton.pressed.connect(_on_refresh_button_pressed)
	$VBoxContainer/BackButton.pressed.connect(_on_back_button_pressed)
	$VBoxContainer/RoomList.item_selected.connect(_on_room_selected)
	
	# Initialize network manager
	network_manager = Node.new()
	network_manager.set_script(load("res://scripts/NetworkManager.gd"))
	add_child(network_manager)
	
	# Connect signals
	network_manager.connection_established.connect(_on_connection_established)
	network_manager.connection_error.connect(_on_connection_error)
	network_manager.rooms_list_updated.connect(_on_rooms_list_updated)
	network_manager.room_created.connect(_on_room_created)
	network_manager.room_joined.connect(_on_room_joined)
	network_manager.game_started.connect(_on_game_started)
	network_manager.error_received.connect(_on_error_received)
	
	# Connect to server
	if network_manager.connect_to_server():
		# Connection started, will get result via signal
		$VBoxContainer/RoomList.clear()
		$VBoxContainer/RoomList.add_item("Connecting to server...")

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
	var room_name = "Новая комната " + str(randi() % 1000)
	network_manager.create_room(room_name, "Player" + str(randi() % 1000))

func _on_room_created(room):
	print("Room created: ", room)
	# We automatically join the room we create, so handle in _on_room_joined

func _on_refresh_button_pressed():
	if network_manager and network_manager.connected:
		network_manager.get_rooms()
	else:
		$VBoxContainer/RoomList.clear()
		$VBoxContainer/RoomList.add_item("Not connected to server")

func _on_back_button_pressed():
	if network_manager:
		network_manager.queue_free()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_room_selected(index):
	if rooms.size() > 0 and index < rooms.size():
		var selected_room = rooms[index]
		network_manager.join_room(selected_room.id, "Player" + str(randi() % 1000))

func _on_room_joined(room):
	print("Joined room: ", room)
	
	# Сохраняем сетевой менеджер, чтобы его не уничтожить при смене сцены
	network_manager.remove_from_group("scene_group")
	network_manager.get_parent().remove_child(network_manager)
	get_tree().root.add_child(network_manager)
	
	print("Переходим в игровую сцену сразу после присоединения к комнате...")
	# Change to game scene immediately after joining
	get_tree().change_scene_to_file("res://scenes/GameScene.tscn")

func _on_game_started(room, players):
	print("Game started in room: ", room, " with players: ", players)
	
	# Сохраняем сетевой менеджер, чтобы его не уничтожить при смене сцены
	network_manager.remove_from_group("scene_group")
	network_manager.get_parent().remove_child(network_manager)
	get_tree().root.add_child(network_manager)
	
	print("Переходим в игровую сцену...")
	# Change to game scene
	get_tree().change_scene_to_file("res://scenes/GameScene.tscn")

func _on_connection_established():
	print("Connected to server")
	network_manager.get_rooms() # Request room list

func _on_connection_error(message):
	print("Connection error: ", message)
	# Show error to user
	$VBoxContainer/RoomList.clear()
	$VBoxContainer/RoomList.add_item("Ошибка подключения: " + message)

func _on_error_received(message):
	print("Error: ", message)
	# Show error to user as a notification
	var dialog = AcceptDialog.new()
	dialog.title = "Ошибка"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	await dialog.confirmed
	dialog.queue_free() 
