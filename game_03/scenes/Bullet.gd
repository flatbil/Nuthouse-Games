extends Area2D

var velocity:       Vector2 = Vector2.ZERO
var damage:         float   = 1.0
var lifetime:       float   = 2.5
var is_player:      bool    = true
var is_grenade:     bool    = false
var grenade_radius: float   = 70.0
var smoke_size:     float   = 1.0   # 1.0 = small arms, 2+ = musket
var is_penetrating: bool    = false

var _age:     float = 0.0
var _hit_ids: Array = []

@onready var shape:  CollisionShape2D = $Shape
@onready var visual: Polygon2D        = $Visual

func _ready() -> void:
	if is_player:
		collision_layer = 4
		collision_mask  = 8
	else:
		collision_layer = 16
		collision_mask  = 32
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	_setup_visual()
	if not is_grenade:
		_spawn_muzzle_smoke()


func _setup_visual() -> void:
	if is_grenade:
		# Octagonal blob for grenade
		var pts := PackedVector2Array()
		var r := 5.0
		for i in range(8):
			var a: float = i * TAU / 8.0
			pts.append(Vector2(cos(a), sin(a)) * r)
		visual.polygon = pts
		visual.color = Color(0.2, 0.85, 0.15) if is_player else Color(0.85, 0.45, 0.05)
	else:
		# Elongated along +X so rotation = dir.angle() aligns the streak with travel direction
		visual.polygon = PackedVector2Array([
			Vector2(-7.0, -1.5),
			Vector2( 7.0, -1.5),
			Vector2( 7.0,  1.5),
			Vector2(-7.0,  1.5),
		])
		visual.color = Color(1.0, 0.95, 0.25) if is_player else Color(1.0, 0.35, 0.1)


func _process(delta: float) -> void:
	position += velocity * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	_hit(area)


func _on_body_entered(body: Node2D) -> void:
	_hit(body)


func _hit(target: Node) -> void:
	if is_grenade:
		var targets := get_tree().get_nodes_in_group(
			"enemies" if is_player else "soldiers")
		for t in targets:
			if is_instance_valid(t) and t.global_position.distance_to(global_position) <= grenade_radius:
				if t.has_method("take_damage"):
					t.take_damage(damage)
		_spawn_impact(true)
		queue_free()
	elif is_penetrating:
		var tid: int = target.get_instance_id()
		if _hit_ids.has(tid):
			return
		_hit_ids.append(tid)
		if target.has_method("take_damage"):
			target.take_damage(damage)
		_spawn_impact(false)
		# Bullet continues — no queue_free
	else:
		if target.has_method("take_damage"):
			target.take_damage(damage)
		_spawn_impact(false)
		queue_free()


func _spawn_muzzle_smoke() -> void:
	var p := CPUParticles2D.new()
	p.global_position      = global_position
	p.z_index              = 10   # draw over all characters
	p.emitting             = true
	p.one_shot             = true
	p.explosiveness        = 0.95
	p.lifetime             = 0.5 + smoke_size * 0.55   # 1.05s small, ~1.65s musket
	p.amount               = int(4.0 + smoke_size * 4.0)
	p.spread               = 38.0
	p.direction            = velocity.normalized() if velocity.length() > 0.1 else Vector2.UP
	p.gravity              = Vector2.ZERO
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 40.0
	p.scale_amount_min     = 3.0 * smoke_size
	p.scale_amount_max     = 7.0 * smoke_size
	p.color = Color(0.88, 0.88, 0.82, 0.80)
	get_tree().current_scene.add_child(p)
	var timer := get_tree().create_timer(p.lifetime + 0.3)
	timer.timeout.connect(p.queue_free)


func _spawn_impact(is_explosion: bool) -> void:
	var p := CPUParticles2D.new()
	p.global_position      = global_position
	p.emitting             = true
	p.one_shot             = true
	p.explosiveness        = 0.9
	p.lifetime             = 0.25
	p.amount               = 20 if is_explosion else 6
	p.spread               = 180.0
	p.initial_velocity_min = 80.0  if is_explosion else 50.0
	p.initial_velocity_max = 200.0 if is_explosion else 100.0
	p.scale_amount_min     = 3.0
	p.scale_amount_max     = 5.0   if is_explosion else 3.0
	p.color = Color(1.0, 0.55, 0.05) if is_explosion else \
	          (Color(0.9, 0.85, 0.2) if is_player else Color(1.0, 0.3, 0.05))
	get_tree().current_scene.add_child(p)
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(p.queue_free)
