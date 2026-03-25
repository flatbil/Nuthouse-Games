extends Area2D

var collectible_type: String = "gold"
var amount:           int    = 1

var _target:          Node2D = null
var _age:             float  = 0.0

const SEEK_RANGE  := 110.0
const MOVE_SPEED  := 190.0
const MAX_LIFETIME := 20.0   # auto-despawn if never collected


func setup(type: String, amt: int, target: Node2D) -> void:
	collectible_type = type
	amount = amt
	_target = target
	_setup_visual()
	# Small random initial scatter
	global_position += Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= MAX_LIFETIME:
		queue_free()
		return
	if not is_instance_valid(_target):
		return
	var dist: float = global_position.distance_to(_target.global_position)
	if dist < SEEK_RANGE:
		if dist < 14.0:
			_collect()
			return
		var dir: Vector2 = (_target.global_position - global_position).normalized()
		global_position += dir * MOVE_SPEED * delta


func _collect() -> void:
	match collectible_type:
		"gold":
			GameManager.add_run_hoard(amount)
		"gem":
			GameManager.add_gems(amount)
		"weapon":
			_roll_weapon_drop()
	EventBus.collectible_picked.emit(collectible_type, amount)
	queue_free()


func _roll_weapon_drop() -> void:
	var weapons: Array = GameConfig.WEAPONS.keys()
	weapons.shuffle()
	var chosen: String = weapons[0]
	GameManager.add_to_inventory(chosen)
	EventBus.hero_weapon_changed.emit("__found__" + chosen)


func _setup_visual() -> void:
	var poly: Polygon2D = $Visual
	match collectible_type:
		"gold":
			var pts := PackedVector2Array()
			for i in range(8):
				var a: float = i * TAU / 8.0
				pts.append(Vector2(cos(a), sin(a)) * 5.0)
			poly.polygon = pts
			poly.color = Color(1.0, 0.85, 0.0)
		"gem":
			poly.polygon = PackedVector2Array([
				Vector2( 0.0, -7.0),
				Vector2( 5.0,  0.0),
				Vector2( 0.0,  7.0),
				Vector2(-5.0,  0.0),
			])
			poly.color = Color(0.25, 0.60, 1.00)
		"weapon":
			var pts := PackedVector2Array()
			for i in range(10):
				var a: float = i * TAU / 10.0
				var r: float = 7.0 if i % 2 == 0 else 3.5
				pts.append(Vector2(cos(a), sin(a)) * r)
			poly.polygon = pts
			poly.color = Color(0.75, 0.20, 0.95)
	# Pulse animation
	var tween := create_tween().set_loops()
	tween.tween_property(poly, "scale", Vector2(1.25, 1.25), 0.55).set_trans(Tween.TRANS_SINE)
	tween.tween_property(poly, "scale", Vector2(1.00, 1.00), 0.55).set_trans(Tween.TRANS_SINE)
