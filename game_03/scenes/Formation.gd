extends Node2D

# Formation is controlled by Game.gd via set_move_input().
# When moving: no firing. When stopped: auto-fires at nearest enemy.

const BULLET_SCENE := preload("res://scenes/Bullet.tscn")
const SOLDIER_SCENE := preload("res://scenes/Soldier.tscn")

var soldiers:        Array  = []
var facing_dir:      Vector2 = Vector2.UP
var max_hp:          int    = 0
var current_hp:      int    = 0    # total across all soldiers

var _move_input:     Vector2 = Vector2.ZERO
var _is_moving:      bool    = false
var _turn_speed:     float   = 4.0   # rad/s, decreases with formation size

const BASE_SPEED     := 120.0
const MIN_SPEED      := 55.0
const SPEED_PER_SOLDIER := 6.0

signal formation_destroyed()


func _ready() -> void:
	add_to_group("formation")


func set_move_input(dir: Vector2) -> void:
	_move_input = dir


func add_soldier(unit_type: String) -> void:
	var soldier := SOLDIER_SCENE.instantiate() as Node2D
	add_child(soldier)
	soldier.setup(unit_type)
	soldier.died.connect(_on_soldier_died)
	soldiers.append(soldier)
	_reposition_soldiers()
	_update_hp()
	EventBus.formation_hp_changed.emit(current_hp, max_hp)


func heal_all(amount: float) -> void:
	for s in soldiers:
		if is_instance_valid(s):
			s.heal(amount)
	_update_hp()
	EventBus.formation_hp_changed.emit(current_hp, max_hp)


func take_formation_damage(amount: float) -> void:
	# Damage a random alive soldier
	var alive := soldiers.filter(func(s): return is_instance_valid(s) and s._is_alive)
	if alive.is_empty():
		return
	alive.pick_random().take_damage(amount)
	_update_hp()
	EventBus.formation_hp_changed.emit(current_hp, max_hp)


func get_center() -> Vector2:
	return global_position


func soldier_count() -> int:
	return soldiers.filter(func(s): return is_instance_valid(s) and s._is_alive).size()


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	if not _is_moving:
		_handle_firing(delta)


func _handle_movement(delta: float) -> void:
	if _move_input.length() < 0.1:
		_is_moving = false
		# Rotation handled in firing toward enemy
		return
	_is_moving = true
	var target_dir: Vector2 = _move_input.normalized()
	var spd: float = _get_speed()
	position += target_dir * spd * delta
	# Clamp to screen bounds
	var vp: Vector2 = get_viewport_rect().size
	position.x = clamp(position.x, 30.0, vp.x - 30.0)
	position.y = clamp(position.y, 80.0, vp.y - 80.0)
	# Gradually rotate to face movement direction
	var target_angle: float = target_dir.angle() + PI * 0.5
	rotation = lerp_angle(rotation, target_angle, delta * _turn_speed)
	facing_dir = target_dir


func _handle_firing(delta: float) -> void:
	var target: Node2D = _get_nearest_enemy()
	if not is_instance_valid(target):
		return
	# Rotate to face target
	var to_target: Vector2 = (target.global_position - global_position).normalized()
	var target_angle: float = to_target.angle() + PI * 0.5
	rotation = lerp_angle(rotation, target_angle, delta * _turn_speed)
	# Each soldier fires independently
	for soldier in soldiers:
		if is_instance_valid(soldier):
			soldier.tick_fire(delta, target, BULLET_SCENE, get_parent())


func _get_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var best: Node2D = null
	var best_dist: float = INF
	for e in enemies:
		if is_instance_valid(e):
			var d: float = global_position.distance_to(e.global_position)
			if d < best_dist:
				best_dist = d
				best = e
	return best


func _get_speed() -> float:
	var count: float = float(soldier_count())
	return max(MIN_SPEED, BASE_SPEED - (count - 1.0) * SPEED_PER_SOLDIER)


func _reposition_soldiers() -> void:
	var offsets: Array = GameConfig.get_formation_offsets(soldiers.size())
	for i in range(soldiers.size()):
		if i < offsets.size() and is_instance_valid(soldiers[i]):
			soldiers[i].position = offsets[i]


func _update_hp() -> void:
	current_hp = 0
	max_hp     = 0
	for s in soldiers:
		if is_instance_valid(s):
			max_hp     += int(s.max_hp)
			current_hp += int(max(0.0, s.current_hp))


func _on_soldier_died(soldier: Node) -> void:
	soldiers.erase(soldier)
	_reposition_soldiers()
	_update_hp()
	EventBus.soldier_killed.emit(soldier.unit_type if soldier.has_method("setup") else "unknown")
	EventBus.formation_hp_changed.emit(current_hp, max_hp)
	if soldier_count() == 0:
		formation_destroyed.emit()
