extends Node2D

# Настройки физики
const GRAVITY = 200.0  # Пониженная гравитация
const MAX_SPEED = 400.0
const ACCELERATION = 2000.0
const FRICTION = 1000.0

# Позиции спавна игроков - adjusted for scene scale
const LEFT_SPAWN_POSITION = Vector2(300, 360)
const RIGHT_SPAWN_POSITION = Vector2(900, 360)

var network_manager
var local_player_id = ""
var player_nodes = {}
var debug_label
var players_spawned = false
var player_positions = {}
var ui_initialized = false
var players_container_initialized = false

func _ready():
	print("GameScene: Инициализация игровой сцены")
	
	# Clear any existing UI or players from the scene
	_clear_existing_nodes()
	
	# Добавляем отладочную метку
	debug_label = Label.new()
	debug_label.position = Vector2(10, 500)
	debug_label.size = Vector2(600, 200)
	debug_label.modulate = Color.YELLOW  # Make it more visible
	add_child(debug_label)
	
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
	
	# Ждем один кадр для инициализации NetworkManager
	await get_tree().process_frame
	
	# Создаем UI для здоровья игроков
	_setup_ui()
	
	# Настраиваем игроков
	_setup_players()
	
	# Подключаем сигналы сетевого менеджера с проверками
	if network_manager and network_manager.has_signal("game_state_updated"):
		if !network_manager.game_state_updated.is_connected(_on_game_state_updated):
			network_manager.game_state_updated.connect(_on_game_state_updated)
	
	# Сохраняем ID локального игрока
	if network_manager:
		local_player_id = network_manager.player_id
		print("GameScene: Локальный игрок ID: ", local_player_id)
	
		# Проверяем текущую комнату
		if network_manager.current_room:
			print("GameScene: Текущая комната: ", network_manager.current_room)
			
			# Wait a little before sending position to ensure everything is initialized
			await get_tree().create_timer(0.5).timeout
			
			# Send a position update to trigger a game state update from server
			if local_player_id != "":
				# Force a position update to get latest game state
				network_manager.send_position(Vector2.ZERO, Vector2.ZERO)
		else:
			print("GameScene: Комната не найдена! Создаем локальную игру.")
			# Create two placeholder players for testing
			_create_placeholder_players()

func _clear_existing_nodes():
	print("GameScene: Clearing existing nodes")
	# Remove any existing UI and Players nodes
	var ui_node = get_node_or_null("UI")
	if ui_node:
		ui_node.queue_free()
		ui_initialized = false
		
	var players_node = get_node_or_null("Players")
	if players_node:
		players_node.queue_free()
		players_container_initialized = false
	
	# Clear player nodes
	for player_id in player_nodes:
		if player_nodes[player_id]:
			player_nodes[player_id].queue_free()
	player_nodes.clear()
	player_positions.clear()
	players_spawned = false
	
	print("GameScene: Nodes cleared")

func _create_placeholder_players():
	# Create two placeholder players for testing
	var left_player = _create_player("local_player")
	player_positions["local_player"] = "left"
	left_player.global_position = LEFT_SPAWN_POSITION
	left_player.is_local_player = true
	
	var right_player = _create_player("remote_player")
	player_positions["remote_player"] = "right"
	right_player.global_position = RIGHT_SPAWN_POSITION

func _setup_ui():
	if ui_initialized:
		return
		
	# Создаем контейнер для UI
	var ui = Node2D.new()
	ui.name = "UI"
	add_child(ui)
	
	# Создаем контейнер для полосок здоровья
	var health_bars = Node2D.new()
	health_bars.name = "HealthBars"
	ui.add_child(health_bars)
	
	# Добавляем заголовок
	var title = Label.new()
	title.text = "StickStrike - Multiplayer"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(520, 20)
	ui.add_child(title)
	
	# Загружаем шаблон полоски здоровья
	var health_bar_scene = load("res://scenes/HealthBar.tscn")
	var template = health_bar_scene.instantiate()
	template.name = "Player1Health"
	health_bars.add_child(template)
	template.visible = false  # Скрываем шаблон
	
	ui_initialized = true
	
func _setup_players():
	if players_container_initialized:
		return
		
	print("GameScene: Настройка игроков")
	
	# Очищаем существующих игроков
	for player_id in player_nodes:
		player_nodes[player_id].queue_free()
	player_nodes.clear()
	
	# Загружаем шаблон игрока
	var player_scene = load("res://scenes/Player.tscn")
	var players_container = Node2D.new()
	players_container.name = "Players"
	add_child(players_container)
	
	# Создаем шаблон игрока
	var player_template = player_scene.instantiate()
	player_template.name = "Player1"
	players_container.add_child(player_template)
	player_template.visible = false  # Скрываем шаблон
	
	players_container_initialized = true
	
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
			var progress_bar = health_bar.get_node("PlayerHealth")
			if progress_bar:
				progress_bar.value = player.health
				
			# Update HP label
			var hp_label = health_bar.get_node_or_null("HPLabel")
			if hp_label:
				hp_label.text = str(player.health)

func _update_debug_info():
	var debug_text = "Room: "
	if network_manager and network_manager.current_room:
		debug_text += str(network_manager.current_room.get("name", "Unknown"))
	else:
		debug_text += "None"
		
	debug_text += "\nPlayers: " + str(player_nodes.size())
	debug_text += "\nLocal ID: " + local_player_id
	debug_text += "\nConnected: " + str(network_manager and network_manager.connected)
	
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
		
	# Make sure Players container exists
	var players_container = get_node_or_null("Players")
	if not players_container:
		players_container = Node2D.new()
		players_container.name = "Players"
		add_child(players_container)
		players_container_initialized = true
	
	# Make sure UI and health bars container exists
	var ui = get_node_or_null("UI")
	var health_bars = null
	if not ui:
		ui = Node2D.new()
		ui.name = "UI"
		add_child(ui)
		ui_initialized = true
		
		health_bars = Node2D.new()
		health_bars.name = "HealthBars"
		ui.add_child(health_bars)
	else:
		health_bars = ui.get_node_or_null("HealthBars")
		if not health_bars:
			health_bars = Node2D.new()
			health_bars.name = "HealthBars"
			ui.add_child(health_bars)
	
	# Создаем нового игрока на основе шаблона
	var player_scene = load("res://scenes/Player.tscn")
	var new_player = player_scene.instantiate()
	new_player.name = player_id
	new_player.visible = true
	players_container.add_child(new_player)
	
	# Настраиваем игрока
	var is_local = player_id == local_player_id
	var color = Color.RED if is_local else Color.BLUE
	new_player.get_node("ColorRect").color = color
	
	# Настраиваем полосу здоровья
	var health_bar_scene = load("res://scenes/HealthBar.tscn")
	var new_health_bar = health_bar_scene.instantiate()
	new_health_bar.name = player_id + "Health"
	new_health_bar.visible = true
	health_bars.add_child(new_health_bar)
	
	# Определяем начальную позицию игрока на основе сохраненной стороны
	var spawn_position
	var health_bar_position
	var side = player_positions.get(player_id, "left") # Default to left if not set
	
	if side == "left":
		spawn_position = LEFT_SPAWN_POSITION
		health_bar_position = Vector2(20, 50)
		print("GameScene: Player ", player_id, " spawning on LEFT side at ", spawn_position)
	else:
		spawn_position = RIGHT_SPAWN_POSITION
		health_bar_position = Vector2(1000, 50)
		print("GameScene: Player ", player_id, " spawning on RIGHT side at ", spawn_position)
	
	# Устанавливаем позицию полоски здоровья
	new_health_bar.position = health_bar_position
	
	# Если позиция была указана в данных с сервера, используем её
	if player_data and player_data.has("position"):
		var pos = player_data.position
		new_player.global_position = Vector2(pos.x, pos.y)
	else:
		# Иначе используем позицию спавна
		new_player.global_position = spawn_position
		
	print("GameScene: Player ", player_id, " position set to ", new_player.global_position)
	
	# Настройка сетевого взаимодействия
	new_player.setup(player_id, new_health_bar.get_node("PlayerHealth"), network_manager, is_local)
	print("GameScene: Игрок ", player_id, " настроен, локальный: ", is_local)
	
	# Обновляем данные игрока, если они предоставлены
	if player_data:
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
		var player_count = 0
		var player_ids = state.players.keys()
		
		# Print debug info
		print("GameScene: Received players: ", player_ids)
		
		# First, determine player positions before creating them
		for player_id in player_ids:
			if not player_positions.has(player_id):
				# First player gets left side, second gets right side
				if player_count == 0:
					player_positions[player_id] = "left"
					print("GameScene: Assigning LEFT position to player ", player_id)
				else:
					player_positions[player_id] = "right"
					print("GameScene: Assigning RIGHT position to player ", player_id)
			player_count += 1
		
		# Debug positions
		print("GameScene: Player positions map: ", player_positions)
		
		# Now create or update players
		for player_id in player_ids:
			var player_data = state.players[player_id]
			
			# Создаем игрока, если он еще не существует
			if not player_nodes.has(player_id):
				var new_player = _create_player(player_id, player_data)
				# Force position based on side
				var side = player_positions[player_id]
				if side == "left":
					new_player.global_position = LEFT_SPAWN_POSITION
				else:
					new_player.global_position = RIGHT_SPAWN_POSITION
				print("GameScene: Forced position of new player to ", new_player.global_position)
			else:
				# Обновляем существующего игрока
				var player = player_nodes[player_id]
				if player_data.has("health"):
					player.health = player_data.health
				
				# Only update non-local player positions from network
				if player_data.has("position") and player_id != local_player_id and not player.is_local_player:
					var pos = player_data.position
					player.global_position = Vector2(pos.x, pos.y)
					
	# Обновляем отладочную информацию
	_update_debug_info() 
