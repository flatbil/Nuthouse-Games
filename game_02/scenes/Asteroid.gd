extends StaticBody2D

# -------------------------------------------------------
# Asteroid — orbits the world origin, mimicking a 3D side-
# view via depth scaling:
#
#   sin(orbit_angle) = +1  → front of orbit
#     → full tier scale, fully opaque, drawn in front
#   sin(orbit_angle) = -1  → back of orbit (behind planet)
#     → 12% scale, ~18% opacity  → appears tiny/distant
#
# Set  tier, orbit_angle, orbit_rx, orbit_ry  BEFORE
# add_child() so _ready() initialises correctly.
# -------------------------------------------------------

# ── Set by spawner before add_child() ──────────────────
@export var tier:          int   = 1
@export var orbit_angle:   float = 0.0
@export var orbit_rx:      float = 0.0
@export var orbit_ry:      float = 0.0
@export var respawn_delay: float = 8.0

# Orbital motion speed — one full revolution per 60 s.
const ORBIT_SPEED := TAU / 60.0

# ── Runtime state ───────────────────────────────────────
var _max_hits:     int   = 0
var _hits_taken:   int   = 0
var _is_depleted:  bool  = false
var _reward_scale: float = 1.0
var _base_scale:   float = 1.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var shape:  CollisionShape2D = $Shape


func _ready() -> void:
	add_to_group("asteroids")
	_apply_tier(tier)
	if orbit_rx > 0.0:
		position = Vector2(cos(orbit_angle) * orbit_rx, sin(orbit_angle) * orbit_ry)
		_update_depth()
	_play_if_exists("idle")
	if is_instance_valid(sprite):
		sprite.animation_finished.connect(_on_animation_finished)


func _process(delta: float) -> void:
	orbit_angle = fmod(orbit_angle + ORBIT_SPEED * delta, TAU)
	if orbit_rx <= 0.0 or _is_depleted:
		return
	position = Vector2(cos(orbit_angle) * orbit_rx, sin(orbit_angle) * orbit_ry)
	_update_depth()


# ── Public API ─────────────────────────────────────────

func can_be_mined_by(ship_tier: int) -> bool:
	return ship_tier >= tier


func take_damage(_amount: float) -> void:
	if _is_depleted:
		return
	_hits_taken += 1
	_play_if_exists("hit")
	if _hits_taken >= _max_hits:
		_deplete()


# Flash sprite red — tweens sprite.modulate so it doesn't
# fight the depth effect on self.modulate.
func show_blocked() -> void:
	if not is_instance_valid(sprite):
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.RED,   0.08)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)


# ── Private ────────────────────────────────────────────

func _apply_tier(t: int) -> void:
	tier          = clamp(t, 1, GameConfig.ASTEROID_TIERS.size())
	var data      := GameConfig.ASTEROID_TIERS[tier - 1] as Dictionary
	_max_hits     = int(data["hits"])
	_reward_scale = float(data["reward_scale"])
	_base_scale   = float(data["sprite_scale"])
	_hits_taken   = 0


func _update_depth() -> void:
	# depth 0 = back of orbit, 1 = front
	var depth := (sin(orbit_angle) + 1.0) * 0.5
	var s     := _base_scale * lerp(0.12, 1.0, depth)
	scale = Vector2(s, s)
	var tc: Color = GameConfig.ASTEROID_TIERS[tier - 1]["color"]
	# Tier colour tint preserved; alpha fades with depth
	modulate = Color(tc.r, tc.g, tc.b, lerp(0.18, 1.0, depth))
	# Draw behind player / orbit lines when in back half
	z_index = -2 if depth < 0.45 else 0


func _deplete() -> void:
	_is_depleted = true
	shape.set_deferred("disabled", true)
	var reward := GameManager.get_effective_tap_value() * _reward_scale
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
	if orbit_rx > 0.0:
		position = Vector2(cos(orbit_angle) * orbit_rx, sin(orbit_angle) * orbit_ry)
	_update_depth()
	_play_if_exists("idle")


func _on_animation_finished() -> void:
	if sprite.animation == &"hit" and not _is_depleted:
		_play_if_exists("idle")


func _play_if_exists(anim: String) -> void:
	if is_instance_valid(sprite) and sprite.sprite_frames \
			and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
