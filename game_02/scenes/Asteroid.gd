extends StaticBody2D

# -------------------------------------------------------
# Asteroid — a mineable resource node.
#
# Sprite setup (assign in editor after importing Kenney pack):
#   $Sprite → AnimatedSprite2D
#   Animations to create in SpriteFrames:
#     "idle"  — slowly rotating rock (4-8 frames, 6 fps)
#     "hit"   — flash/shake on damage (2-3 frames, 12 fps)
#     "break" — shattering explosion  (4-6 frames, 10 fps, no loop)
#
# Collision setup:
#   $Shape → CollisionShape2D with CircleShape2D
#   Adjust radius to match your sprite (typically 20-32px).
#
# Export vars let you tune per-asteroid in the editor or spawner.
# -------------------------------------------------------

@export var max_health:    float = 20.0
@export var respawn_delay: float = 10.0

var health:       float = 0.0
var _is_depleted: bool  = false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var shape:  CollisionShape2D = $Shape


func _ready() -> void:
	add_to_group("asteroids")
	health = max_health
	_play_if_exists("idle")


# Called by Player each mine swing.
func take_damage(amount: float) -> void:
	if _is_depleted:
		return
	health -= amount
	_play_if_exists("hit")
	if health <= 0.0:
		_deplete()


# -------------------------------------------------------
# Private
# -------------------------------------------------------

func _deplete() -> void:
	_is_depleted = true
	shape.set_deferred("disabled", true)   # safe to disable mid-physics step
	_play_if_exists("break")
	EventBus.asteroid_depleted.emit(global_position)

	# Wait for break animation, then hide
	if is_instance_valid(sprite) and sprite.sprite_frames \
			and sprite.sprite_frames.has_animation("break"):
		await sprite.animation_finished

	visible = false
	await get_tree().create_timer(respawn_delay).timeout
	_respawn()


func _respawn() -> void:
	_is_depleted = false
	health       = max_health
	visible      = true
	shape.disabled = false
	_play_if_exists("idle")


func _play_if_exists(anim: String) -> void:
	if is_instance_valid(sprite) and sprite.sprite_frames \
			and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
