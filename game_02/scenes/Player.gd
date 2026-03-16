extends CharacterBody2D

# -------------------------------------------------------
# Player — tap-to-move character with auto-mining.
#
# Sprite setup (assign in editor after importing Kenney pack):
#   $Sprite → AnimatedSprite2D
#   Animations to create in SpriteFrames:
#     "idle"  — standing still (2-4 frames, 8 fps)
#     "walk"  — walking cycle (4-6 frames, 10 fps)
#     "mine"  — mining swing  (3-4 frames, 8 fps)
#
# Collision setup:
#   $BodyShape → CollisionShape2D with CapsuleShape2D (~8px radius)
#   $MineArea/MineShape → CircleShape2D (~72px radius)
#   Adjust both after importing sprites to match sprite size.
# -------------------------------------------------------

const SPEED           := 120.0
const MINE_INTERVAL   := 0.5    # seconds between mine ticks while in range
const CAMERA_DRIFT    := 28.0   # max pixel offset toward rotation direction

var move_target:       Vector2        = Vector2.ZERO
var current_asteroid:  StaticBody2D   = null
var _mine_timer:       float          = 0.0
var _is_moving:        bool           = false
var _cam_offset_target: Vector2       = Vector2.ZERO

@onready var sprite:     AnimatedSprite2D = $Sprite
@onready var mine_area:  Area2D           = $MineArea
@onready var camera:     Camera2D         = $Camera


func _ready() -> void:
	move_target = global_position
	mine_area.body_entered.connect(_on_mine_area_body_entered)
	mine_area.body_exited.connect(_on_mine_area_body_exited)


func _physics_process(delta: float) -> void:
	_update_movement()
	_update_mining(delta)
	_update_animation()


# Called by Game.gd when the player taps the world.
func set_move_target(world_pos: Vector2) -> void:
	move_target = world_pos


# -------------------------------------------------------
# Movement
# -------------------------------------------------------

func _update_movement() -> void:
	# W/S move the player toward/away from the orbital centre.
	# A/D are handled by Game.gd to rotate the orbit — NOT character movement.
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):   dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1.0

	# Camera drifts slightly toward the rotation direction for depth feedback
	var rot_dir := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  rot_dir -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): rot_dir += 1.0
	_cam_offset_target = Vector2(rot_dir * CAMERA_DRIFT, 0.0)
	camera.offset = camera.offset.lerp(_cam_offset_target, 0.12)

	if dir != Vector2.ZERO:
		velocity    = dir.normalized() * SPEED
		move_target = global_position
		_is_moving  = true
		move_and_slide()
		return

	# Tap-to-move
	var to_target := move_target - global_position
	if to_target.length() > 6.0:
		velocity    = to_target.normalized() * SPEED
		_is_moving  = true
		if sprite and sprite.sprite_frames:
			sprite.flip_h = velocity.x < 0.0
	else:
		velocity   = Vector2.ZERO
		_is_moving = false
	move_and_slide()


# -------------------------------------------------------
# Mining
# -------------------------------------------------------

func _update_mining(delta: float) -> void:
	if current_asteroid == null or not is_instance_valid(current_asteroid):
		current_asteroid = null
		_mine_timer = 0.0
		return

	# Block mining if asteroid is in background or ship tier is too low
	if current_asteroid.has_method("is_in_foreground") \
			and not current_asteroid.is_in_foreground():
		return
	if current_asteroid.has_method("can_be_mined_by") \
			and not current_asteroid.can_be_mined_by(GameManager.ship_tier):
		return

	# Stop moving while mining — feel attached to the rock
	if not _is_moving:
		_mine_timer += delta
		if _mine_timer >= MINE_INTERVAL:
			_mine_timer = 0.0
			if current_asteroid.has_method("take_damage"):
				current_asteroid.take_damage(1.0)


# -------------------------------------------------------
# Animation
# -------------------------------------------------------

func _update_animation() -> void:
	if not is_instance_valid(sprite) or sprite.sprite_frames == null:
		return

	var anim: String
	if current_asteroid != null and not _is_moving:
		anim = "mine" if sprite.sprite_frames.has_animation("mine") else "idle"
	elif _is_moving:
		anim = "walk" if sprite.sprite_frames.has_animation("walk") else "idle"
	else:
		anim = "idle"

	if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)


# -------------------------------------------------------
# Mine area detection
# -------------------------------------------------------

func _on_mine_area_body_entered(body: Node) -> void:
	# Only latch on to one asteroid at a time
	if body != self and current_asteroid == null and body is StaticBody2D:
		current_asteroid = body as StaticBody2D
		# Show upgrade prompt only when visible but wrong tier (not for background asteroids)
		var in_fg: bool = not current_asteroid.has_method("is_in_foreground") \
				or current_asteroid.is_in_foreground()
		if in_fg and current_asteroid.has_method("can_be_mined_by") \
				and not current_asteroid.can_be_mined_by(GameManager.ship_tier):
			current_asteroid.show_blocked()
			EventBus.mine_blocked.emit(global_position)


func _on_mine_area_body_exited(body: Node) -> void:
	if body == current_asteroid:
		current_asteroid = null
		_mine_timer = 0.0
