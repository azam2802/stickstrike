extends Control
@onready var room_list = $RoomListVBox

func _ready():
	load_rooms()

func load_rooms():
	var http = HTTPRequest.new()
	add_child(http)
	http.request("http://127.0.0.1:8080/api/rooms")
	http.request_completed.connect(_on_request_completed)

func _on_request_completed(result, response_code, headers, body):
	var rooms = JSON.parse_string(body.get_string_from_utf8())
	for room in rooms:
		var btn = Button.new()
		btn.text = "Room: %s" % room["id"]
		btn.pressed.connect(join_room.bind(room["id"]))
		room_list.add_child(btn)

func join_room(room_id):
	get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
