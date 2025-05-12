extends CharacterBody2D

# Настройки игрока
var health = 100
var max_health = 100
var damage = 10
var knockback_force = 400.0
var is_local_player = false
var player_id = ""
var player_name = ""
var last_collision_time = 0
var collision_cooldown = 0.5 # Секунды между ударами
var hit_effect_active = false

# Ссылки на UI элементы
var health_bar
var network_manager
var name_label

func _ready():
	print("Player: Инициализация игрока: ", player_id)
	
	# Ensure visibility
	visible = true
	
	# Создаем метку с именем игрока
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-50, -40)  # Размещаем над игроком
	name_label.size = Vector2(100, 20)
	add_child(name_label)

func setup(id, health_bar_ref, network_mgr, is_local = false):
	self.player_id = id
	self.is_local_player = is_local
	health_bar = health_bar_ref
	network_manager = network_mgr
	health = max_health
	
	# Make sure player is visible
	visible = true
	
	# Update health bar
	if health_bar:
		health_bar.value = health
		# Update HP label
		var hp_label = health_bar.get_parent().get_node_or_null("HPLabel")
		if hp_label:
			hp_label.text = str(health)
	
	# Устанавливаем имя игрока
	if is_local:
		player_name = "You (Player " + id.substr(0, 4) + ")"
	else:
		player_name = "Player " + id.substr(0, 4)
	
	# Обновляем метку с именем
	if name_label:
		name_label.text = player_name
	
	print("Player: Настройка игрока ", id, ", локальный: ", is_local)

func _process(delta):
	# Debug visibility check
	if not visible:
		visible = true
		print("Player: Fixed visibility for ", player_id)

func _physics_process(delta):
	if is_local_player:
		# Получаем ввод только для локального игрока
		var input_vector = Vector2.ZERO
		input_vector.x = Input.get_axis("ui_left", "ui_right")
		input_vector.y = Input.get_axis("ui_up", "ui_down")
		
		# Debug movement info
		if input_vector != Vector2.ZERO:
			print("Player: Movement input detected: ", input_vector)
		
		input_vector = input_vector.normalized()
		
		# Применяем движение с повышенной скоростью для лучшей отзывчивости
		if input_vector != Vector2.ZERO:
			velocity = input_vector * 500.0  # Increased speed for better responsiveness
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 2000.0 * delta)  # Faster deceleration
		
		# Actually move the character
		var previous_position = global_position
		move_and_slide()
		var has_moved = previous_position != global_position
		
		if has_moved:
			print("Player: Moved to position: ", global_position)
		
		# Отправляем позицию на сервер только если игрок двигается
		if network_manager and network_manager.connected and (has_moved or velocity.length() > 0.1):
			network_manager.send_position(global_position, velocity)
	
	# Проверяем столкновения только для локального игрока
	if is_local_player:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider is CharacterBody2D and collider.has_method("get_player_id"):
				_handle_player_collision(collider)

func _handle_player_collision(other_player):
	# Проверяем кулдаун между ударами
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_collision_time < collision_cooldown:
		return
		
	last_collision_time = current_time
	
	# Отправляем информацию об ударе на сервер
	if network_manager and network_manager.connected and other_player.has_method("get_player_id"):
		var target_id = other_player.get_player_id()
		print("Player: Удар по игроку ", target_id)
		network_manager.send_hit(target_id, other_player.global_position)
		
		# Показываем визуальный эффект удара
		_show_hit_effect()
		
		# Применяем локальный визуальный эффект удара
		other_player.take_damage(damage, global_position)

func get_player_id():
	return player_id

func get_player_name():
	return player_name

func take_damage(amount, attacker_position = null):
	print("Player: Получен урон ", amount, " игроком ", player_id)
	health = max(0, health - amount)
	
	# Обновляем полоску здоровья
	if health_bar:
		health_bar.value = health
		# Update HP label
		var hp_label = health_bar.get_parent().get_node_or_null("HPLabel")
		if hp_label:
			hp_label.text = str(health)
	
	# Применяем отбрасывание
	if attacker_position != null:
		var knockback_direction = (global_position - attacker_position).normalized()
		velocity = knockback_direction * knockback_force
		print("Player: Применено отбрасывание в направлении ", knockback_direction)
	
	# Показываем визуальный эффект получения урона
	_show_damage_effect()
	
	# Сообщаем о смерти, если здоровье закончилось
	if health <= 0:
		_on_death()

func _show_hit_effect():
	# Создаем вспышку при ударе
	modulate = Color.YELLOW
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)

func _show_damage_effect():
	# Эффект получения урона (мигание красным)
	if not hit_effect_active:
		hit_effect_active = true
		modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.3)
		tween.tween_callback(func(): hit_effect_active = false)

func _on_death():
	print("Player: Игрок ", player_id, " погиб")
	# Временная реализация - просто восстанавливаем здоровье
	health = max_health
	# Визуальный эффект смерти
	modulate = Color.WHITE
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.2)
	tween.tween_property(self, "modulate", Color.BLACK, 0.2)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2) 
