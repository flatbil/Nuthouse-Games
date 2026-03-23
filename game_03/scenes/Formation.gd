extends Node2D

# Formation is controlled by Game.gd via set_move_input().
# When moving: no firing. When stopped: auto-fires at nearest enemy.

const BULLET_SCENE := preload("res://scenes/Bullet.tscn")
const SOLDIER_SCENE := preload("res://scenes/Soldier.tscn")

var soldiers:        Array  = []
var facing_dir:      Vector2 = Vector2.UP
var max_hp:          int    = 0
var current_hp:      int    = 0    # total across all soldiers
var _hero_node:      Node2D = null

var _move_input:     Vector2 = Vector2.ZERO
var _is_moving:      bool    = false
var _turn_speed:     float   = 4.0   # rad/s, decreases with formation size
var _soldier_targets: Array  = []    # target local offsets for organic lerp

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
	# Snap every soldier to their target on join — no lerp drift during upgrades
	for i in range(soldiers.size()):
		if i < _soldier_targets.size() and is_instance_valid(soldiers[i]):
			soldiers[i].position = _soldier_targets[i]
	_update_hp()
	EventBus.formation_hp_changed.emit(current_hp, max_hp)


func add_hero() -> void:
	var hero := SOLDIER_SCENE.instantiate() as Node2D
	add_child(hero)
	hero.setup("hero")
	hero.died.connect(_on_soldier_died)
	soldiers.insert(0, hero)
	_hero_node = hero
	_reposition_soldiers()
	if _soldier_targets.size() > 0:
		hero.position = _soldier_targets[0]
	_update_hp()
	EventBus.formation_hp_changed.emit(current_hp, max_hp)


func heal_all(amount: float) -> void:
	for s in soldiers:
		if is_instance_valid(s):
			s.heal(amount)
	_update_hp()
	EventBus.formation_hp_changed.emit(current_hp, max_hp)


func take_formation_damage(amount: float, from_pos: Vector2 = Vector2.ZERO) -> void:
	var mod := _direction_damage_mod(from_pos)
	if mod <= 0.0:
		return
	var alive := soldiers.filter(func(s): return is_instance_valid(s) and s._is_alive)
	if alive.is_empty():
		return
	alive.pick_random().take_damage(amount * mod)
	_update_hp()
	EventBus.formation_hp_changed.emit(current_hp, max_hp)


# Returns damage multiplier based on which direction the hit comes from.
# facing_dir points the direction the formation is facing.
# Front arc = immune, flanks = partial, rear = full.
func _direction_damage_mod(from_pos: Vector2) -> float:
	if from_pos == Vector2.ZERO or facing_dir == Vector2.ZERO:
		return 1.0
	var to_attacker: Vector2 = (from_pos - global_position).normalized()
	var dot: float = facing_dir.dot(to_attacker)
	# dot  1.0 = directly in front,  -1.0 = directly behind
	if   dot >  0.5: return 0.0   # front cone  (~60°): immune
	elif dot >  0.0: return 0.35  # front-flank (~90°): 35%
	elif dot > -0.5: return 0.65  # rear-flank  (~90°): 65%
	else:            return 1.0   # rear cone   (~60°): full


func get_center() -> Vector2:
	return global_position


# Returns a world-space position to aim at — random alive soldier, with a
# small chance of targeting the hero so they remain in some danger.
func get_random_soldier_pos() -> Vector2:
	var alive := soldiers.filter(func(s): return is_instance_valid(s) and s._is_alive)
	if alive.is_empty():
		return global_position
	# 20% chance to aim at the hero specifically
	if is_instance_valid(_hero_node) and _hero_node._is_alive and randf() < 0.20:
		return _hero_node.global_position
	return alive.pick_random().global_position


func soldier_count() -> int:
	return soldiers.filter(func(s): return is_instance_valid(s) and s._is_alive).size()


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_lerp_soldiers(delta)
	if _is_moving:
		_handle_melee(delta)
	else:
		_handle_firing(delta)


func _lerp_soldiers(delta: float) -> void:
	for i in range(soldiers.size()):
		var s = soldiers[i]
		if not is_instance_valid(s) or not s._is_alive:
			continue
		if i >= _soldier_targets.size():
			continue
		# Slightly different lerp speed per soldier (6 – 9 s⁻¹) gives staggered drift
		var spd: float = 6.0 + fmod(float(i) * 1.7, 3.0)
		s.position = s.position.lerp(_soldier_targets[i], delta * spd)


func _handle_movement(delta: float) -> void:
	if _move_input.length() < 0.1:
		_is_moving = false
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
	# Formation does NOT auto-rotate — it holds the last movement direction.
	# Each soldier independently finds the nearest enemy inside its own fire cone.
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var offsets := GameConfig.get_formation_offsets(soldiers.size())
	for i in range(soldiers.size()):
		var soldier = soldiers[i]
		if not is_instance_valid(soldier) or not soldier._is_alive:
			continue
		var cone := _soldier_fire_cone(i, offsets)
		var target := _nearest_in_cone(enemies, soldier.global_position,
				cone.dir, cone.half_angle)
		if is_instance_valid(target):
			soldier.tick_fire(delta, target, BULLET_SCENE, get_parent())


# Returns {dir: Vector2, half_angle: float} for soldier at index idx.
# End soldiers get a wider arc biased toward their outer flank.
# Middle soldiers get a narrow forward-only cone.
func _soldier_fire_cone(idx: int, offsets: Array) -> Dictionary:
	var fwd := facing_dir if facing_dir.length() > 0.01 else Vector2.UP
	var right := Vector2(-fwd.y, fwd.x)   # perpendicular right in world space
	if idx >= offsets.size():
		return {"dir": fwd, "half_angle": deg_to_rad(55.0)}
	var ox: float = offsets[idx].x
	# Find the maximum absolute x offset to identify edge soldiers
	var max_ox := 0.0
	for off in offsets:
		max_ox = max(max_ox, abs(off.x))
	var is_edge: bool = max_ox > 5.0 and abs(ox) >= max_ox - 2.0
	if is_edge:
		# Lean cone ~25° toward outer side; wider arc so flanks are covered
		var lean: Vector2 = right * sign(ox) * 0.45
		return {"dir": (fwd + lean).normalized(), "half_angle": deg_to_rad(80.0)}
	else:
		return {"dir": fwd, "half_angle": deg_to_rad(50.0)}


# Returns the nearest enemy whose bearing from `from_pos` falls inside the cone.
func _nearest_in_cone(enemies: Array, from_pos: Vector2,
		cone_dir: Vector2, half_angle: float) -> Node2D:
	var best: Node2D = null
	var best_dist: float = INF
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var to_e: Vector2 = e.global_position - from_pos
		if absf(cone_dir.angle_to(to_e.normalized())) > half_angle:
			continue
		var d: float = to_e.length()
		if d < best_dist:
			best_dist = d
			best = e
	return best


func _handle_melee(delta: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	for soldier in soldiers:
		if not is_instance_valid(soldier) or not soldier._is_alive:
			continue
		soldier._melee_timer += delta
		if soldier._melee_timer < soldier.melee_rate:
			continue
		# Find nearest enemy within range that is in the forward hemisphere
		var best_enemy: Node2D = null
		var best_dist: float = soldier.melee_range
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			var to_enemy: Vector2 = enemy.global_position - soldier.global_position
			var dist: float = to_enemy.length()
			if dist > soldier.melee_range:
				continue
			if facing_dir.dot(to_enemy.normalized()) < 0.0:
				continue   # behind the soldier
			if dist < best_dist:
				best_dist = dist
				best_enemy = enemy
		if is_instance_valid(best_enemy):
			soldier._melee_timer = 0.0
			best_enemy.take_damage(soldier.melee_damage)
			soldier.swing_weapon()


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
	_soldier_targets.resize(soldiers.size())
	for i in range(soldiers.size()):
		if i < offsets.size() and is_instance_valid(soldiers[i]):
			_soldier_targets[i] = offsets[i]


func _update_hp() -> void:
	current_hp = 0
	max_hp     = 0
	for s in soldiers:
		if is_instance_valid(s):
			max_hp     += int(s.max_hp)
			current_hp += int(max(0.0, s.current_hp))


func _on_soldier_died(soldier: Node) -> void:
	var death_pos: Vector2 = soldier.global_position
	var was_hero: bool = (soldier == _hero_node)
	soldiers.erase(soldier)
	if was_hero:
		_hero_node = null
	_reposition_soldiers()
	for i in range(soldiers.size()):
		if i < _soldier_targets.size() and is_instance_valid(soldiers[i]):
			soldiers[i].position = _soldier_targets[i]
	_update_hp()
	EventBus.soldier_killed.emit(soldier.unit_type if soldier.has_method("setup") else "unknown")
	EventBus.entity_died.emit(death_pos, false)
	EventBus.formation_hp_changed.emit(current_hp, max_hp)
	if was_hero or soldier_count() == 0:
		formation_destroyed.emit()
