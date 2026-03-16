extends StaticBody2D

# -------------------------------------------------------
# Asteroid — a mineable resource node.
#
# Tiers (1–5) are set by the spawner via the `tier` export
# before add_child(), so _ready() can configure visuals,
# collision scale, and HP automatically.
#
# Sprite setup (assign in editor after importing sprites):
#   $Sprite → AnimatedSprite2D
#   Animations: "idle" (loop), "hit" (no loop), "break" (no loop)
#
# Collision setup:
#   $Shape → CollisionShape2D with CircleShape2D
#   Base radius ~20px for T1; scales up with sprite_scale.
# -------------------------------------------------------

@export var tier:          int   = 1
@export var respawn_delay: float = 8.0

var _max_hits:    int   = 0
var _hits_taken:  int   = 0
var _is_depleted: bool  = false
var _reward_scale: float = 1.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var shape:  CollisionShape2D = $Shape


func _ready() -> void:
	add_to_group("asteroids")
	_apply_tier(tier)
	_play_if_exists("idle")
	if is_instance_valid(sprite):
		sprite.animation_finished.connect(_on_animation_finished)


# Called by the spawner or directly before add_child to configure the tier.
func _apply_tier(t: int) -> void:
	tier = clamp(t, 1, GameConfig.ASTEROID_TIERS.size())
	var data: Dictionary = GameConfig.ASTEROID_TIERS[tier - 1]
	_max_hits     = int(data["hits"])
	_reward_scale = float(data["reward_scale"])
	var s: float  = float(data["sprite_scale"])
	scale         = Vector2(s, s)
	modulate      = data["color"]
	_hits_taken   = 0


# Returns true if this asteroid's tier is within the ship's mining capability.
func can_be_mined_by(ship_tier: int) -> bool:
	return ship_tier >= tier


# Called by Player each mine swing.
func take_damage(_amount: float) -> void:
	if _is_depleted:
		return
	_hits_taken += 1
	_play_if_exists("hit")
	if _hits_taken >= _max_hits:
		_deplete()


# Called when player tries to mine but ship tier is too low.
func show_blocked() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.08)
	tween.tween_property(self, "modulate", GameConfig.ASTEROID_TIERS[tier - 1]["color"], 0.25)


# -------------------------------------------------------
# Private
# -------------------------------------------------------

func _deplete() -> void:
	_is_depleted = true
	shape.set_deferred("disabled", true)

	# Award credits — burst reward based on tier and current ship/zone strength.
	var reward: float = GameManager.get_effective_tap_value() * _reward_scale
	GameManager.add_resources(reward)
	EventBus.credits_mined.emit(global_position, reward)
	EventBus.asteroid_depleted.emit(global_position)

	_play_if_exists("break")

	if is_instance_valid(sprite) and sprite.sprite_frames \
			and sprite.sprite_frames.has_animation("break"):
		await sprite.animation_finished

	visible = false
	await get_tree().create_timer(respawn_delay).timeout
	_respawn()


func _respawn() -> void:
	_is_depleted = false
	_hits_taken  = 0
	visible      = true
	shape.disabled = false
	_play_if_exists("idle")


func _on_animation_finished() -> void:
	if sprite.animation == &"hit" and not _is_depleted:
		_play_if_exists("idle")


func _play_if_exists(anim: String) -> void:
	if is_instance_valid(sprite) and sprite.sprite_frames \
			and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
