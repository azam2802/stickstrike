extends Control

func _ready():
	$VBoxContainer/PlayButton.pressed.connect(_on_play_button_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_button_pressed)

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://scenes/RoomList.tscn")

func _on_quit_button_pressed():
	get_tree().quit() 
