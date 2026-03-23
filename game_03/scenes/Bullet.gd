extends Area2D

var velocity:       Vector2 = Vector2.ZERO
var damage:         float   = 1.0
var lifetime:       float   = 2.5
var is_player:      bool    = true
var is_grenade:     bool    = false
var grenade_radius: float   = 70.0

var _age: float = 0.0

@onready var shape: CollisionShape2D = $Shape

func _ready() -> void:
	if is_player:
		collision_layer = 4
		collision_mask  = 8
	else:
		collision_layer = 16
		collision_mask  = 32
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


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
		# Area explosion
		var targets := get_tree().get_nodes_in_group(
			"enemies" if is_player else "soldiers")
		for t in targets:
			if is_instance_valid(t) and t.global_position.distance_to(global_position) <= grenade_radius:
				if t.has_method("take_damage"):
					t.take_damage(damage)
	else:
		if target.has_method("take_damage"):
			target.take_damage(damage)
	queue_free()
