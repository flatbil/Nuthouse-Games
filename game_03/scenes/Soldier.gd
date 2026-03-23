extends Area2D

var unit_type:    String  = "frontiersman"
var max_hp:       float   = 5.0
var current_hp:   float   = 5.0
var damage:       float   = 2.5
var fire_rate:    float   = 1.8
var range_px:     float   = 320.0
var bullet_speed: float   = 420.0
var is_grenade:    bool    = false
var grenade_radius: float = 70.0
var smoke_size:    float  = 1.0
var melee_damage:  float  = 3.0
var melee_range:   float  = 28.0
var melee_rate:    float  = 0.5
var melee_weapon:  String = "weap_sword"

var _fire_timer:  float = 0.0
var _melee_timer: float = 0.0
var _is_alive:    bool  = true

@onready var body:   Sprite2D = $Body
@onready var weapon: Sprite2D = $Weapon

signal died(soldier: Node)


func setup(type: String) -> void:
	unit_type = type
	var cfg: Dictionary = GameConfig.UNIT_TYPES[type]
	max_hp       = GameManager.get_unit_stat(type, "max_hp")
	current_hp   = max_hp
	damage       = GameManager.get_unit_stat(type, "damage")
	fire_rate    = GameManager.get_unit_stat(type, "fire_rate")
	range_px     = GameManager.get_unit_stat(type, "range")
	bullet_speed = float(cfg.get("bullet_speed", 400.0))
	is_grenade   = bool(cfg.get("is_grenade", false))
	grenade_radius = float(cfg.get("grenade_radius", 70.0))
	var sz: Vector2 = cfg.get("size", Vector2(18, 22))
	var sprite_name: String = cfg.get("sprite", "tile_0124")
	body.texture = load("res://assets/sprites/" + sprite_name + ".png")
	body.scale   = sz / 16.0
	melee_damage = float(cfg.get("melee_damage", 3.0))
	melee_range  = float(cfg.get("melee_range",  28.0))
	melee_rate   = float(cfg.get("melee_rate",   0.5))
	melee_weapon = str(cfg.get("melee_weapon", "weap_sword"))
	weapon.texture = load("res://assets/sprites/" + melee_weapon + ".png")
	smoke_size   = float(cfg.get("smoke_size", 1.0))


func take_damage(amount: float) -> void:
	if not _is_alive:
		return
	current_hp -= amount
	# Flash white
	var tween := create_tween()
	tween.tween_property(body, "modulate", Color(4.0, 4.0, 4.0, 1.0), 0.05)
	tween.tween_property(body, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)
	if current_hp <= 0:
		_die()


func swing_weapon() -> void:
	if not _is_alive or not is_instance_valid(weapon):
		return
	var tween := create_tween()
	tween.tween_property(weapon, "rotation_degrees", -75.0, 0.08) \
		.set_trans(Tween.TRANS_SINE)
	tween.tween_property(weapon, "rotation_degrees", 0.0, 0.14) \
		.set_trans(Tween.TRANS_BOUNCE)


func heal(amount: float) -> void:
	current_hp = min(current_hp + amount, max_hp)


func try_fire(target: Node2D, bullet_scene: PackedScene, parent: Node) -> void:
	if not _is_alive or not is_inside_tree():
		return
	_fire_timer += get_process_delta_time()
	if _fire_timer < fire_rate:
		return
	if not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) > range_px:
		return
	_fire_timer = 0.0
	_shoot(target, bullet_scene, parent)


func tick_fire(delta: float, target: Node2D, bullet_scene: PackedScene, parent: Node) -> void:
	if not _is_alive:
		return
	_fire_timer += delta
	if _fire_timer < fire_rate:
		return
	if not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) > range_px:
		return
	_fire_timer = 0.0
	_shoot(target, bullet_scene, parent)


func _shoot(target: Node2D, bullet_scene: PackedScene, parent: Node) -> void:
	var bullet := bullet_scene.instantiate() as Area2D
	bullet.global_position = global_position
	bullet.damage          = damage
	bullet.is_player       = true
	bullet.is_grenade      = is_grenade
	bullet.grenade_radius  = grenade_radius
	bullet.smoke_size      = smoke_size
	if is_grenade:
		bullet.lifetime = 1.2
	var dir: Vector2 = (target.global_position - global_position).normalized()
	bullet.velocity = dir * bullet_speed
	bullet.rotation = dir.angle()
	parent.add_child(bullet)


func _die() -> void:
	_is_alive = false
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(body,   "modulate:a", 0.0, 0.3)
	tween.tween_property(weapon, "modulate:a", 0.0, 0.3)
	tween.tween_property(self,   "scale", Vector2(0.1, 0.1), 0.3)
	await tween.finished
	died.emit(self)
	queue_free()
