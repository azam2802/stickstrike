extends Node2D

# Настройки физики
const GRAVITY = 200.0  # Пониженная гравитация
const MAX_SPEED = 400.0
const ACCELERATION = 2000.0
const FRICTION = 1000.0

var network_manager
var local_player_id = ""
var player_nodes = {}
var debug_label

func _ready():
	print("GameScene: Инициализация игровой сцены")
	
	# Добавляем отладочную метку
	debug_label = Label.new()
	debug_label.position = Vector2(10, 600)
	debug_label.size = Vector2(500, 100)
	add_child(debug_label)
	
	# Устанавливаем глобальную гравитацию
	PhysicsServer2D.area_set_param(get_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, Vector2(0, GRAVITY))
	
	# Получаем существующий NetworkManager из корня дерева или создаем новый
	network_manager = get_node_or_null("/root/NetworkManager")
	print("GameScene: Найден NetworkManager? ", network_manager != null)
	
	if not network_manager:
		print("GameScene: Создание нового NetworkManager")
		network_manager = Node.new()
		network_manager.set_script(load("res://scripts/NetworkManager.gd"))
		network_manager.name = "NetworkManager"
		add_child(network_manager)
		
		# Если мы создали новый NetworkManager, нужно подключиться к серверу
		if not network_manager.connected:
			network_manager.connect_to_server()
	
	# Подключаем сигналы сетевого менеджера
	if !network_manager.game_state_updated.is_connected(_on_game_state_updated):
		network_manager.game_state_updated.connect(_on_game_state_updated)
	
	# Сохраняем ID локального игрока
	local_player_id = network_manager.player_id
	print("GameScene: Локальный игрок ID: ", local_player_id)
	
	# Проверяем текущую комнату
	if network_manager.current_room:
		print("GameScene: Текущая комната: ", network_manager.current_room)
	else:
		print("GameScene: Комната не найдена! Создаем локальную игру.")
	
	# Настраиваем существующих игроков
	_setup_players()
	
func _setup_players():
	print("GameScene: Настройка игроков")
	
	# Очищаем существующих игроков
	for player_id in player_nodes:
		player_nodes[player_id].queue_free()
	player_nodes.clear()
	
	# Убедимся, что у нас есть шаблон игрока
	var player_template = $Players/Player1
	if not player_template:
		print("GameScene: ОШИБКА - Шаблон игрока не найден!")
		return
		
	player_template.visible = false  # Скрываем шаблон
	
	# Если мы знаем ID локального игрока, создадим его
	if local_player_id != "":
		print("GameScene: Создаем локального игрока: ", local_player_id)
		var local_player = _create_player(local_player_id)
		local_player.global_position = Vector2(320, 360)
	else:
		# Если мы не знаем ID локального игрока, создадим временного игрока
		print("GameScene: ВНИМАНИЕ - ID локального игрока не найден, создаем временного")
		var temp_player = _create_player("temp_player")
		temp_player.global_position = Vector2(320, 360)
		temp_player.is_local_player = true
	
	# Обновляем отладочную информацию
	_update_debug_info()
	
func _process(delta):
	# Обновление UI
	_update_health_bars()
	_update_debug_info()

func _update_health_bars():
	# Обновляем полоски здоровья для всех игроков
	for player_id in player_nodes:
		var player = player_nodes[player_id]
		var health_bar = get_node_or_null("UI/HealthBars/" + player_id + "Health")
		if health_bar and player:
			health_bar.value = player.health

func _update_debug_info():
	var debug_text = "Room: "
	if network_manager.current_room:
		debug_text += str(network_manager.current_room.get("name", "Unknown"))
	else:
		debug_text += "None"
		
	debug_text += "\nPlayers: " + str(player_nodes.size())
	debug_text += "\nLocal ID: " + local_player_id
	debug_text += "\nConnected: " + str(network_manager.connected)
	
	# Добавляем информацию о текущих игроках
	for player_id in player_nodes:
		var player = player_nodes[player_id]
		debug_text += "\nPlayer " + player_id.substr(0, 4) + ": " + str(player.global_position) + " HP: " + str(player.health)
	
	debug_label.text = debug_text

func _create_player(player_id, player_data = null):
	print("GameScene: Создание игрока ", player_id)
	
	# Если игрок уже существует, просто обновляем его
	if player_nodes.has(player_id):
		print("GameScene: Игрок ", player_id, " уже существует")
		return player_nodes[player_id]
		
	# Создаем нового игрока на основе шаблона
	var player_template = $Players/Player1
	var new_player = player_template.duplicate()
	new_player.name = player_id
	new_player.visible = true
	$Players.add_child(new_player)
	
	# Настраиваем игрока
	var is_local = player_id == local_player_id
	var color = Color.RED if is_local else Color.BLUE
	new_player.get_node("ColorRect").color = color
	
	# Настраиваем полосу здоровья
	var health_bar_template = $UI/HealthBars/Player1Health
	var new_health_bar = health_bar_template.duplicate()
	new_health_bar.name = player_id + "Health"
	$UI/HealthBars.add_child(new_health_bar)
	
	# Настройка сетевого взаимодействия
	new_player.setup(player_id, new_health_bar, network_manager, is_local)
	print("GameScene: Игрок ", player_id, " настроен, локальный: ", is_local)
	
	# Обновляем данные игрока, если они предоставлены
	if player_data:
		if player_data.has("position"):
			var pos = player_data.position
			new_player.global_position = Vector2(pos.x, pos.y)
			print("GameScene: Установлена позиция игрока ", player_id, ": ", pos.x, ", ", pos.y)
		if player_data.has("health"):
			new_player.health = player_data.health
			print("GameScene: Установлено здоровье игрока ", player_id, ": ", player_data.health)
	
	# Сохраняем ссылку на игрока
	player_nodes[player_id] = new_player
	return new_player

func _on_game_state_updated(state):
	print("GameScene: Обновление состояния игры: ", state)
	
	# Обновляем состояние игры на основе данных с сервера
	if state.has("players"):
		for player_id in state.players:
			var player_data = state.players[player_id]
			
			# Создаем игрока, если он еще не существует
			if not player_nodes.has(player_id):
				_create_player(player_id, player_data)
			else:
				# Обновляем существующего игрока
				var player = player_nodes[player_id]
				if player_data.has("position"):
					var pos = player_data.position
					# Обновляем позицию только для неуправляемых игроков
					if player_id != local_player_id or not player.is_local_player:
						player.global_position = Vector2(pos.x, pos.y)
				if player_data.has("health"):
					player.health = player_data.health
					
	# Обновляем отладочную информацию
	_update_debug_info() 