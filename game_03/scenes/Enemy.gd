extends CharacterBody2D

var enemy_type:     String  = "musketman"
var max_hp:         float   = 6.0
var current_hp:     float   = 6.0
var speed:          float   = 60.0
var damage:         float   = 2.0
var attack_range:   float   = 240.0
var fire_rate:      float   = 2.0
var bullet_spd:     float   = 350.0
var reward:         int     = 5
var is_melee:       bool    = false
var is_cavalry:     bool    = false
var is_grenade:     bool    = false
var grenade_radius: float   = 70.0

var _fire_timer:   float  = 0.0
var _target:       Node2D = null
var _is_alive:     bool   = true
var _charge_dir:   Vector2 = Vector2.ZERO

@onready var body:    Sprite2D = $Body
@onready var hp_bar:  ColorRect = $HPBar
@onready var hp_bg:   ColorRect = $HPBarBG

const BULLET_SCENE := preload("res://scenes/Bullet.tscn")


func setup(type: String, wave: int) -> void:
	enemy_type = type
	add_to_group("enemies")
	var cfg: Dictionary = GameConfig.ENEMY_TYPES[type]
	max_hp        = float(cfg["max_hp"])   * GameConfig.enemy_hp_scale(wave)
	current_hp    = max_hp
	speed         = float(cfg["speed"])   * GameConfig.enemy_speed_scale(wave)
	damage        = float(cfg["damage"])
	attack_range  = float(cfg["attack_range"])
	fire_rate     = float(cfg["fire_rate"])
	bullet_spd    = float(cfg["bullet_speed"])
	reward        = int(cfg["reward"])
	is_melee      = bool(cfg.get("is_melee", false))
	is_cavalry    = bool(cfg.get("is_cavalry", false))
	is_grenade    = bool(cfg.get("is_grenade", false))
	grenade_radius = float(cfg.get("grenade_radius", 70.0))
	var sz: Vector2 = cfg.get("size", Vector2(18, 22))
	var sprite_name: String = cfg.get("sprite", "tile_0151")
	body.texture = load("res://assets/sprites/" + sprite_name + ".png")
	body.scale   = sz / 16.0
	# Resize collision to match
	($Shape.shape as CircleShape2D).radius = sz.x * 0.55
	_update_hp_bar()


func set_target(t: Node2D) -> void:
	_target = t


func take_damage(amount: float) -> void:
	if not _is_alive:
		return
	current_hp -= amount
	_update_hp_bar()
	var tween := create_tween()
	tween.tween_property(body, "modulate", Color(4.0, 4.0, 4.0, 1.0), 0.05)
	tween.tween_property(body, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)
	if current_hp <= 0:
		_die()


func _physics_process(delta: float) -> void:
	if not _is_alive or not is_instance_valid(_target):
		velocity = Vector2.ZERO
		return

	var dist: float = global_position.distance_to(_target.global_position)

	if is_cavalry:
		# Re-aim toward target if heading away and far enough
		var to_target: Vector2 = (_target.global_position - global_position).normalized()
		if _charge_dir == Vector2.ZERO or \
				(dist > attack_range * 3.0 and _charge_dir.dot(to_target) < -0.3):
			_charge_dir = to_target
		velocity = _charge_dir * speed
		move_and_slide()
		if dist < attack_range:
			_fire_timer += delta
			if _fire_timer >= fire_rate:
				_fire_timer = 0.0
				_melee_hit()
		return

	if dist > attack_range:
		# Move toward target
		var dir: Vector2 = (_target.global_position - global_position).normalized()
		velocity = dir * speed
		move_and_slide()
		_fire_timer = 0.0   # reset charge while out of range
	else:
		velocity = Vector2.ZERO
		if is_melee:
			_fire_timer += delta
			if _fire_timer >= fire_rate:
				_fire_timer = 0.0
				_melee_hit()
		else:
			_fire_timer += delta
			_update_charge_visual()
			if _fire_timer >= fire_rate:
				_fire_timer = 0.0
				_shoot()


func _update_charge_visual() -> void:
	# Lerp modulate from normal → bright yellow as shot charges up.
	# Only kicks in during the last 60% of the reload window.
	var charge_ratio: float = _fire_timer / fire_rate
	if charge_ratio < 0.4:
		body.modulate = Color(1.0, 1.0, 1.0, 1.0)
		return
	var t: float = (charge_ratio - 0.4) / 0.6   # 0→1 over the warning window
	var warn_color := Color(2.0, 1.7, 0.0, 1.0) if not is_grenade else Color(2.0, 0.9, 0.0, 1.0)
	body.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(warn_color, t)


func _shoot() -> void:
	if not is_instance_valid(_target):
		return
	var bullet := BULLET_SCENE.instantiate() as Area2D
	bullet.global_position = global_position
	bullet.damage          = damage
	bullet.is_player       = false
	bullet.is_grenade      = is_grenade
	bullet.grenade_radius  = grenade_radius
	if is_grenade:
		bullet.lifetime = 1.0
	var dir: Vector2 = (_target.global_position - global_position).normalized()
	bullet.velocity = dir * bullet_spd
	bullet.rotation = dir.angle()
	get_parent().add_child(bullet)


func _melee_hit() -> void:
	if is_instance_valid(_target) and _target.has_method("take_formation_damage"):
		_target.take_formation_damage(damage)
		if is_cavalry:
			_charge_dir = -_charge_dir.normalized()   # reverse at full speed


func _die() -> void:
	_is_alive = false
	remove_from_group("enemies")
	EventBus.enemy_killed.emit(global_position, reward)
	GameManager.add_run_hoard(reward)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(body,   "modulate:a", 0.0, 0.25)
	tween.tween_property(hp_bar, "modulate:a", 0.0, 0.25)
	tween.tween_property(hp_bg,  "modulate:a", 0.0, 0.25)
	await tween.finished
	queue_free()


func _update_hp_bar() -> void:
	var ratio: float = max(0.0, current_hp / max_hp)
	hp_bar.offset_right = hp_bg.offset_left + (hp_bg.offset_right - hp_bg.offset_left) * ratio
