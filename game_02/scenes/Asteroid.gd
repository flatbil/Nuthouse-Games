extends StaticBody3D

# ----------------------------------------------------------
# Asteroid — orbits the planet in the XZ plane.
# Sprite3D in billboard mode always faces the camera.
#
# Set tier, size_class, orbit_angle, orbit_r, orbit_y
# BEFORE add_child() so _ready() initialises correctly.
# ----------------------------------------------------------

@export var tier:           int   = 1
@export var size_class:     int   = 1   # 0=small 1=medium 2=large 3=mega
@export var orbit_angle:    float = 0.0
@export var orbit_r:        float = 100.0
@export var orbit_y:        float = 0.0
@export var cam_distance:   float = 1850.0
@export var respawn_delay:  float = 8.0
@export var is_event:       bool  = false
@export var event_lifetime: float = 60.0

# One full orbit per 60 s
const ORBIT_SPEED := TAU / 60.0

# [sprite_scale_factor, hits_multiplier, reward_multiplier]
const SIZE_CLASSES: Array = [
	[0.55, 0.4,  1.0],   # small
	[1.0,  1.0,  1.0],   # medium  (baseline)
	[1.7,  3.0,  3.2],   # large
	[3.0, 12.0,  8.0],   # mega
]

# Meteor textures — indexed by tier (0-based)
const METEOR_TEXTURES: Array = [
	"res://assets/sprites/asteroids/meteorGrey_tiny1.png",
	"res://assets/sprites/asteroids/meteorGrey_small1.png",
	"res://assets/sprites/asteroids/meteorGrey_med1.png",
	"res://assets/sprites/asteroids/meteorGrey_big1.png",
	"res://assets/sprites/asteroids/meteorBrown_big1.png",
]

var _max_hits:     int   = 0
var _hits_taken:   int   = 0
var _is_depleted:  bool  = false
var _reward_scale: float = 1.0
var _base_scale:   float = 1.0
var _base_color:   Color = Color.WHITE
var _event_timer:  float = 0.0
var _event_pulse:  float = 0.0

@onready var sprite: Sprite3D         = $Sprite
@onready var shape:  CollisionShape3D = $Shape


func _ready() -> void:
	add_to_group("asteroids")
	_apply_tier(tier)
	if is_event:
		_apply_event_visuals()
	_update_position()


func _process(delta: float) -> void:
	if _is_depleted:
		return
	orbit_angle = fmod(orbit_angle + ORBIT_SPEED * delta, TAU)
	_update_position()
	if is_event:
		_event_pulse += delta
		sprite.scale = Vector3.ONE * (1.0 + 0.18 * sin(_event_pulse * TAU * 1.8))
		_event_timer += delta
		if _event_timer >= event_lifetime:
			_expire()


# ── Public API ──────────────────────────────────────────

func can_be_mined_by(ship_tier: int) -> bool:
	return ship_tier >= tier


func take_damage(reward_mult: float = 1.0) -> void:
	if _is_depleted:
		return
	_hits_taken += 1
	_flash_hit()
	var partial := GameManager.get_effective_tap_value() * _reward_scale / float(_max_hits) * reward_mult
	GameManager.add_resources(partial)
	EventBus.credits_mined.emit(global_position, partial)
	if _hits_taken >= _max_hits:
		_deplete()


func set_selected(s: bool) -> void:
	if not is_instance_valid(sprite):
		return
	sprite.modulate = Color(1.0, 0.92, 0.2) if s else _base_color


func show_blocked() -> void:
	if not is_instance_valid(sprite):
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.08)
	tween.tween_property(sprite, "modulate", _base_color, 0.25)


# ── Private ─────────────────────────────────────────────

func _update_position() -> void:
	position = Vector3(cos(orbit_angle) * orbit_r, orbit_y, sin(orbit_angle) * orbit_r)


func _apply_tier(t: int) -> void:
	tier       = clamp(t, 1, GameConfig.ASTEROID_TIERS.size())
	size_class = clamp(size_class, 0, SIZE_CLASSES.size() - 1)
	var sc: Array = SIZE_CLASSES[size_class]

	_base_scale   = float(sc[0])
	_max_hits     = max(1, int(round(
			float(GameConfig.ASTEROID_TIERS[tier - 1]["hits"]) * float(sc[1]))))
	_reward_scale = float(GameConfig.ASTEROID_TIERS[tier - 1]["reward_scale"]) * float(sc[2])
	_hits_taken   = 0

	var tex_idx: int = clamp(tier - 1, 0, METEOR_TEXTURES.size() - 1)
	sprite.texture = load(METEOR_TEXTURES[tex_idx])

	var asteroid_dist: float = max(cam_distance - orbit_r, cam_distance * 0.25)
	sprite.pixel_size = max(0.2, 0.15 * asteroid_dist / 128.0 * _base_scale)

	_base_color     = GameConfig.ASTEROID_TIERS[tier - 1]["color"]
	sprite.modulate = _base_color

	var col_r: float = 64.0 * sprite.pixel_size
	(shape.shape as SphereShape3D).radius = max(5.0, col_r)


func _apply_event_visuals() -> void:
	_base_color     = GameConfig.EVENT_ASTEROID_COLOR
	sprite.modulate = _base_color
	_reward_scale  *= GameConfig.EVENT_ASTEROID_REWARD_MULT
	# Force large size so it's clearly visible
	size_class = 2
	var sc: Array = SIZE_CLASSES[size_class]
	_base_scale = float(sc[0])
	var asteroid_dist: float = max(cam_distance - orbit_r, cam_distance * 0.25)
	sprite.pixel_size = max(0.2, 0.15 * asteroid_dist / 128.0 * _base_scale)
	var col_r: float = 64.0 * sprite.pixel_size
	(shape.shape as SphereShape3D).radius = max(5.0, col_r)


func _flash_hit() -> void:
	if not is_instance_valid(sprite):
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.06)
	tween.tween_property(sprite, "modulate", _base_color, 0.2)


func _deplete() -> void:
	_is_depleted = true
	shape.set_deferred("disabled", true)
	EventBus.asteroid_depleted.emit(global_position)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector3.ONE * 2.0, 0.25)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
	await tween.finished
	visible = false
	if is_event:
		queue_free()
		return
	await get_tree().create_timer(respawn_delay).timeout
	_respawn()


func _expire() -> void:
	_is_depleted = true
	shape.set_deferred("disabled", true)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 1.2)
	tween.tween_property(sprite, "scale", Vector3.ONE * 0.2, 1.2)
	await tween.finished
	queue_free()


func _respawn() -> void:
	_is_depleted    = false
	_hits_taken     = 0
	visible         = true
	shape.disabled  = false
	sprite.scale    = Vector3.ONE
	sprite.modulate = _base_color
	_update_position()
