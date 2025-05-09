extends Node

const SERVER_URL = "ws://127.0.0.1:8080/rawws"  # Raw WebSocket endpoint
var client = WebSocketPeer.new()
var player_id = ""
var connected = false
var current_room = null

signal game_state_updated(state)
signal connection_established
signal connection_closed
signal connection_error(message)
signal rooms_list_updated(rooms)
signal room_joined(room)
signal room_created(room)
signal game_started(room, players)
signal error_received(message)

func _ready():
	print("NetworkManager initialized")
	# In Godot 4, we don't connect signals directly to WebSocketPeer
	# Instead we poll its state in _process

func _process(delta):
	var state = client.get_ready_state()
	
	if state == WebSocketPeer.STATE_OPEN:
		client.poll()
		# Check if there's data to read
		while client.get_available_packet_count() > 0:
			_on_data_received()
	elif state == WebSocketPeer.STATE_CONNECTING:
		# Still connecting
		client.poll()
	elif state == WebSocketPeer.STATE_CLOSING:
		# Closing
		client.poll()
	elif state == WebSocketPeer.STATE_CLOSED:
		# Socket closed, report error if not already connected
		var code = client.get_close_code()
		var reason = client.get_close_reason()
		
		if connected:
			print("WebSocket closed with code: %d, reason: %s" % [code, reason])
			connected = false
			emit_signal("connection_closed")
		else:
			print("WebSocket connection failed with code: %d, reason: %s" % [code, reason])
			emit_signal("connection_error", "Connection failed: %s" % reason)
		
		# We got disconnected, so create a new WebSocketPeer
		if client.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			client = WebSocketPeer.new()

func connect_to_server():
	print("Attempting to connect to server at: ", SERVER_URL)
	
	# Configure WebSocket client
	var error = client.connect_to_url(SERVER_URL)
	
	if error != OK:
		var error_message = "Failed to connect to server: %d" % error
		print(error_message)
		emit_signal("connection_error", error_message)
		return false
	
	print("Connection request sent, waiting for response...")
	return true

# Room management
func get_rooms():
	print("Requesting room list")
	var message = {
		"type": "get_rooms"
	}
	send_message(message)

func create_room(room_name, player_name=""):
	print("Creating room: ", room_name)
	var message = {
		"type": "create_room",
		"name": room_name,
		"playerName": player_name
	}
	send_message(message)

func join_room(room_id, player_name=""):
	print("Joining room: ", room_id)
	var message = {
		"type": "join_room",
		"roomId": room_id,
		"playerName": player_name
	}
	send_message(message)

func leave_room():
	print("Leaving room")
	var message = {
		"type": "leave_room"
	}
	send_message(message)
	current_room = null

# Game actions
func send_position(position: Vector2, velocity: Vector2):
	var message = {
		"type": "position",
		"playerId": player_id,
		"position": {"x": position.x, "y": position.y},
		"velocity": {"x": velocity.x, "y": velocity.y}
	}
	send_message(message)

func send_hit(target_id: String, hit_point: Vector2):
	var message = {
		"type": "hit",
		"attackerId": player_id,
		"targetId": target_id,
		"hitPoint": {"x": hit_point.x, "y": hit_point.y}
	}
	send_message(message)

func send_message(data: Dictionary):
	if client.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var json = JSON.stringify(data)
		print("Sending message: ", json)
		client.send_text(json)
	else:
		print("Cannot send message: WebSocket not open. State: ", client.get_ready_state())

func _on_connection_established():
	print("Connected to server successfully")
	connected = true
	emit_signal("connection_established")
	
	# Request room list
	get_rooms()

func _on_data_received():
	var packet = client.get_packet()
	var message = packet.get_string_from_utf8()
	print("Received message: ", message)
	var data = JSON.parse_string(message)
	
	if data == null:
		print("Failed to parse message")
		return
	
	# Handle different message types
	var type = data.get("type")
	if type == null:
		print("Message has no type: ", data)
		return
	
	print("Handling message type: ", type)
	
	match type:
		"connected":
			print("Connected message received: ", data)
			player_id = data.get("playerId", "")
			_on_connection_established()
		
		"room_list":
			print("Room list received: ", data.get("rooms"))
			var rooms = data.get("rooms", [])
			emit_signal("rooms_list_updated", rooms)
		
		"room_created":
			print("Room created: ", data.get("room"))
			var room = data.get("room")
			current_room = room
			emit_signal("room_created", room)
		
		"room_joined":
			print("Room joined: ", data.get("room"))
			var room = data.get("room")
			current_room = room
			emit_signal("room_joined", room)
		
		"game_started":
			print("Game started message received: ", data)
			var room = data.get("room")
			var players = data.get("players", {})
			current_room = room
			emit_signal("game_started", room, players)
			
		"position_updated":
			# Это просто подтверждение от сервера, что позиция была обновлена
			# Ничего делать не нужно
			pass
			
		"hit_confirmed":
			print("Hit confirmed: ", data)
			# Здесь можно добавить визуальный эффект попадания
			# или звук, если потребуется
			
		"game_state":
			print("Game state received")
			if data.has("players"):
				emit_signal("game_state_updated", data)
		
		"error":
			var error_message = data.get("message", "Unknown error")
			print("Error received: ", error_message)
			emit_signal("error_received", error_message)
		
		_:
			print("Unknown message type: ", type)
			if data.has("body"):
				emit_signal("game_state_updated", data.body) 
