extends CharacterBody2D

# Настройки игрока
var health = 100
var max_health = 100
var damage = 10
var knockback_force = 400.0
var is_local_player = false
var player_id = ""
var last_collision_time = 0
var collision_cooldown = 0.5 # Секунды между ударами
var hit_effect_active = false

# Ссылки на UI элементы
var health_bar
var network_manager

func _ready():
	print("Player: Инициализация игрока: ", player_id)

func setup(id, health_bar_ref, network_mgr, is_local = false):
	self.player_id = id
	self.is_local_player = is_local
	health_bar = health_bar_ref
	network_manager = network_mgr
	health = max_health
	print("Player: Настройка игрока ", id, ", локальный: ", is_local)

func _physics_process(delta):
	if is_local_player:
		# Получаем ввод только для локального игрока
		var input_vector = Vector2.ZERO
		input_vector.x = Input.get_axis("ui_left", "ui_right")
		input_vector.y = Input.get_axis("ui_up", "ui_down")
		
		input_vector = input_vector.normalized()
		
		# Применяем движение
		if input_vector != Vector2.ZERO:
			velocity = velocity.move_toward(input_vector * 400.0, 2000.0 * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
		
		move_and_slide()
		
		# Отправляем позицию на сервер
		if network_manager and network_manager.connected:
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

func take_damage(amount, attacker_position = null):
	print("Player: Получен урон ", amount, " игроком ", player_id)
	health = max(0, health - amount)
	
	# Обновляем полоску здоровья
	if health_bar:
		health_bar.value = health
	
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