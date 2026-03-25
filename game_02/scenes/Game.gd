extends Node3D

# -------------------------------------------------------
# Game.gd — 3D asteroid miner.
#
# World:    Node3D scene.  Camera3D orbits the planet.
# Planet:   SphereMesh created at runtime (origin).
# Asteroids: Area3D + Sprite3D (billboard) in XZ plane.
# Input:    A/D keys or touch-drag rotates camera azimuth.
#           Tap/click raycasts to select asteroid; auto-mines.
# HUD:      CanvasLayer overlay — upgrade drawer, stats.
# -------------------------------------------------------

# ── HUD node refs ───────────────────────────────────────
@onready var resource_label:  Label          = $HUD/TopHUD/Stats/ResourceLabel
@onready var rate_label:      Label          = $HUD/TopHUD/Stats/RateLabel
@onready var per_sec_label:   Label          = $HUD/TopHUD/Stats/PerSecLabel
@onready var days_label:      Label          = $HUD/TopHUD/Stats/DaysLabel
@onready var zone_label:      Label          = $HUD/TopHUD/Stats/ZoneLabel
@onready var upgrade_list:    VBoxContainer  = $HUD/UpgradeDrawer/ScrollContainer/UpgradeList
@onready var upgrade_drawer:  PanelContainer = $HUD/UpgradeDrawer
@onready var stage_label:     Label          = $HUD/StageLabel
@onready var hamburger_btn:   Button         = $HUD/HamburgerBtn
@onready var drawer_overlay:  Button         = $HUD/DrawerOverlay

# ── 3D world refs ───────────────────────────────────────
@onready var asteroid_field:  Node3D    = $AsteroidField
@onready var orbit_camera:    Camera3D  = $OrbitCamera

# ── Asteroid spawning ───────────────────────────────────
const ASTEROID_SCENE := preload("res://scenes/Asteroid.tscn")
const ASTEROID_COUNT := 50
const PLANET_RADIUS  := 500.0

# ── Camera orbit ────────────────────────────────────────
var _cam_azimuth:   float = 0.0          # horizontal angle around Y axis
var _cam_elevation: float = 0.15         # radians above equator
var _cam_distance:  float = 400.0        # set per zone in _spawn_asteroids()

const CAM_AZIMUTH_SPEED  := 1.6          # rad/s for keyboard
const CAM_ELEVATION_MIN  := 0.1
const CAM_ELEVATION_MAX  := 1.2

# ── Mining state ────────────────────────────────────────
var _selected_asteroid: Node3D = null
var _mine_timer:        float  = 0.0
const MINE_INTERVAL := 0.5               # seconds between mine ticks

# ── Planet material ref (for zone texture swaps) ────────
var _planet_mat: StandardMaterial3D = null

# ── Player ship ─────────────────────────────────────────
var _player_ship:       Node3D = null
var _ship_sprite:       Sprite3D = null
var _ship_orbit_angle:  float  = 0.0   # current orbital angle
var _ship_orbit_r:      float  = 100.0 # set per zone

# ── Tap combo ────────────────────────────────────────────
var _combo_count: int   = 0
var _combo_timer: float = 0.0
const COMBO_TIMEOUT     := 1.5   # seconds before combo resets

# ── Camera shake ─────────────────────────────────────────
var _cam_shake: float = 0.0

# ── Mining laser VFX ─────────────────────────────────────
var _laser_beam:  MeshInstance3D       = null
var _laser_glow:  MeshInstance3D       = null
var _laser_mat:   StandardMaterial3D   = null
var _laser_pulse: float                = 0.0

# ── Prestige UI ──────────────────────────────────────────
var _prestige_btn: Button = null

# ── Event asteroid ────────────────────────────────────────
var _event_asteroid: Node3D = null
var _event_timer:    float  = 0.0
var _event_interval: float  = 0.0

const SHIP_ORBIT_SPEED := TAU / 90.0   # one orbit per 90 s when idle
const SHIP_MOVE_SPEED  := 120.0        # world units per second toward target

# ── Touch tracking (multi-touch: rotate + pinch-zoom) ───
var _touches:     Dictionary = {}   # finger_index → Vector2 position
var _touch_moved: bool       = false
var _touch_start: Vector2    = Vector2.ZERO

const CAM_DIST_MIN := 700.0
const CAM_DIST_MAX := 80000.0

# ── Upgrade drawer state ────────────────────────────────
var _collapsed: Dictionary = {
	"track_0": true,
	"track_1": true,
	"track_2": true,
	"track_3": true,
}

const _CYAN      := Color(0.30, 0.80, 1.00, 1.0)
const _GOLD      := Color(0.87, 0.70, 0.00, 1.0)
const _HEADER_LIT := Color(0.50, 1.00, 0.80, 1.0)

var _loan_btn:    Button = null
var _drawer_open := false
const _DRAWER_W  := 300.0


func _ready() -> void:
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.passive_rate_changed.connect(_on_passive_rate_changed)
	EventBus.tap_value_changed.connect(_on_tap_value_changed)
	EventBus.item_purchased.connect(_on_item_purchased)
	EventBus.game_days_changed.connect(_on_game_days_changed)
	EventBus.offline_income_collected.connect(_on_offline_income)
	EventBus.game_ended.connect(_on_game_ended)
	EventBus.credits_mined.connect(_on_credits_mined)
	EventBus.mine_blocked.connect(_on_mine_blocked)
	EventBus.asteroid_depleted.connect(_on_asteroid_depleted)
	AdManager.loan_rewarded.connect(_on_loan_rewarded)
	EventBus.zone_changed.connect(_on_zone_changed)
	EventBus.prestige_performed.connect(_on_prestige_performed)

	_setup_3d_world()
	_apply_theme()
	_build_upgrade_list()
	_spawn_asteroids()
	_update_ship_zone()   # re-run now that _cam_distance is correct
	_reset_event_timer()
	_refresh_ui()
	hamburger_btn.pressed.connect(_toggle_drawer)
	drawer_overlay.pressed.connect(_toggle_drawer)
	_style_hamburger_btn()
	_update_camera()


func _process(delta: float) -> void:
	_refresh_loan_button()
	_update_camera_input(delta)
	_update_mining(delta)
	_update_player_ship(delta)
	_update_event_asteroid(delta)
	if _combo_count > 0:
		_combo_timer += delta
		if _combo_timer >= COMBO_TIMEOUT:
			_combo_count = 0
			_combo_timer = 0.0
	if _cam_shake > 0.0:
		_cam_shake = move_toward(_cam_shake, 0.0, delta * 8.0)
		_update_camera()


# -------------------------------------------------------
# Camera orbit
# -------------------------------------------------------

func _update_camera_input(delta: float) -> void:
	var dir := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  dir -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir += 1.0
	if dir != 0.0:
		_cam_azimuth += dir * CAM_AZIMUTH_SPEED * delta
		_update_camera()


func _update_camera() -> void:
	var x: float = sin(_cam_azimuth) * cos(_cam_elevation) * _cam_distance
	var y: float = sin(_cam_elevation) * _cam_distance
	var z: float = cos(_cam_azimuth) * cos(_cam_elevation) * _cam_distance
	var base_pos := Vector3(x, y, z)
	if _cam_shake > 0.0:
		var look   := -base_pos.normalized()
		var right  := Vector3.UP.cross(look).normalized()
		var up     := look.cross(right)
		var offset := (right * randf_range(-1.0, 1.0) + up * randf_range(-1.0, 1.0)) \
				* _cam_shake * _cam_distance * 0.012
		orbit_camera.position = base_pos + offset
	else:
		orbit_camera.position = base_pos
	orbit_camera.look_at(Vector3.ZERO, Vector3.UP)


# -------------------------------------------------------
# Mining
# -------------------------------------------------------

func _update_mining(delta: float) -> void:
	if not is_instance_valid(_selected_asteroid):
		_selected_asteroid = null
		_mine_timer = 0.0
		return
	if _selected_asteroid.get("_is_depleted"):
		_deselect_asteroid()
		return
	if not _selected_asteroid.has_method("can_be_mined_by") \
			or not _selected_asteroid.can_be_mined_by(GameManager.ship_tier):
		return
	if not GameManager.is_auto_mine_enabled():
		return
	_mine_timer += delta
	if _mine_timer >= MINE_INTERVAL:
		_mine_timer = 0.0
		Settings.haptic(18)
		_selected_asteroid.take_damage(1.0)


func _deselect_asteroid() -> void:
	if is_instance_valid(_selected_asteroid) and _selected_asteroid.has_method("set_selected"):
		_selected_asteroid.set_selected(false)
	_selected_asteroid = null
	_mine_timer = 0.0
	# Sync idle orbit from current ship position so it doesn't jump back to origin
	if is_instance_valid(_player_ship):
		var xz := Vector2(_player_ship.global_position.x, _player_ship.global_position.z)
		if xz.length() > 1.0:
			_ship_orbit_angle = atan2(_player_ship.global_position.z, _player_ship.global_position.x)
			_ship_orbit_r     = xz.length()


func _on_asteroid_depleted(_pos: Vector3) -> void:
	_deselect_asteroid()


# -------------------------------------------------------
# Input — tap to select, drag to rotate, pinch to zoom
# -------------------------------------------------------

func _get_touch_dist() -> float:
	var keys := _touches.keys()
	if keys.size() < 2:
		return 0.0
	return (_touches[keys[0]] as Vector2).distance_to(_touches[keys[1]] as Vector2)


func _unhandled_input(event: InputEvent) -> void:

	# ── Touch press / release ────────────────────────────
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_touch_start = event.position
				_touch_moved = false
			# second finger down: reset moved flag so release won't fire tap
			elif _touches.size() == 2:
				_touch_moved = true
		else:
			var was_tap: bool = _touches.size() == 1 and not _touch_moved
			_touches.erase(event.index)
			if was_tap and not _drawer_open:
				_handle_tap(event.position)
		return

	# ── Touch drag: single-finger rotate, two-finger pinch-zoom ──
	if event is InputEventScreenDrag:
		_touch_moved = true
		if _touches.size() == 2:
			# Compute pinch delta BEFORE updating this finger's position
			var old_dist: float = _get_touch_dist()
			_touches[event.index] = event.position
			var new_dist: float = _get_touch_dist()
			if old_dist > 1.0 and new_dist > 1.0:
				_cam_distance = clamp(
						_cam_distance * (old_dist / new_dist),
						CAM_DIST_MIN, CAM_DIST_MAX)
		else:
			_touches[event.index] = event.position
			_cam_azimuth  -= event.relative.x * 0.005
			_cam_elevation = clamp(
					_cam_elevation + event.relative.y * 0.003,
					CAM_ELEVATION_MIN, CAM_ELEVATION_MAX)
		_update_camera()
		return

	# ── Mouse drag: rotate camera ────────────────────────
	if event is InputEventMouseMotion \
			and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) \
			and not _drawer_open:
		_cam_azimuth  -= event.relative.x * 0.005
		_cam_elevation = clamp(
				_cam_elevation + event.relative.y * 0.003,
				CAM_ELEVATION_MIN, CAM_ELEVATION_MAX)
		_update_camera()
		return

	# ── Mouse wheel: zoom ────────────────────────────────
	if event is InputEventMouseButton and not _drawer_open:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_cam_distance = clamp(_cam_distance * 0.9, CAM_DIST_MIN, CAM_DIST_MAX)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_cam_distance = clamp(_cam_distance * 1.1, CAM_DIST_MIN, CAM_DIST_MAX)
			_update_camera()
		# ── Mouse left click: tap ────────────────────────
		elif event.button_index == MOUSE_BUTTON_LEFT \
				and event.pressed \
				and not DisplayServer.is_touchscreen_available():
			_handle_tap(event.position)


func _handle_tap(screen_pos: Vector2) -> void:
	var from: Vector3 = orbit_camera.project_ray_origin(screen_pos)
	var dir:  Vector3 = orbit_camera.project_ray_normal(screen_pos)
	var to:   Vector3 = from + dir * (_cam_distance * 4.0)

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 2
	var result: Dictionary = space.intersect_ray(query)

	if result.is_empty() or not result["collider"].is_in_group("asteroids"):
		# Missed — bonus hit on current target (tap anywhere = mine)
		if is_instance_valid(_selected_asteroid) and not _selected_asteroid.get("_is_depleted"):
			_do_tap_hit()
		else:
			_deselect_asteroid()
		return

	var hit := result["collider"] as Node3D

	# Tier gate
	if hit.has_method("can_be_mined_by") and not hit.can_be_mined_by(GameManager.ship_tier):
		hit.show_blocked()
		EventBus.mine_blocked.emit(hit.global_position)
		return

	# Switch target if different asteroid
	if hit != _selected_asteroid:
		_deselect_asteroid()
		hit.set_selected(true)
		_selected_asteroid = hit

	_do_tap_hit()


func _do_tap_hit() -> void:
	if not is_instance_valid(_selected_asteroid) or _selected_asteroid.get("_is_depleted"):
		return
	_combo_count += 1
	_combo_timer  = 0.0
	var mult := _combo_mult()
	_selected_asteroid.take_damage(mult)
	# asteroid may have depleted mid-call (signal fires synchronously), re-check before use
	if _combo_count >= 2 and is_instance_valid(_selected_asteroid):
		_show_combo_label(orbit_camera.unproject_position(_selected_asteroid.global_position), mult)
	# Camera shake scales with combo intensity
	if   mult >= 8.0: _cam_shake = maxf(_cam_shake, 1.0)
	elif mult >= 5.0: _cam_shake = maxf(_cam_shake, 0.55)
	elif mult >= 3.0: _cam_shake = maxf(_cam_shake, 0.25)


func _combo_mult() -> float:
	if _combo_count >= 15: return 8.0
	if _combo_count >= 10: return 5.0
	if _combo_count >= 5:  return 3.0
	if _combo_count >= 2:  return 2.0
	return 1.0


func _show_combo_label(screen_pos: Vector2, mult: float) -> void:
	var names := {2.0: "COMBO", 3.0: "HOT!", 5.0: "ON FIRE!", 8.0: "UNSTOPPABLE!"}
	var label_text: String = names.get(mult, "")
	if label_text.is_empty():
		return
	var lbl := Label.new()
	lbl.text = "×%.0f  %s" % [mult, label_text]
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.add_theme_color_override("font_color", _GOLD)
	lbl.position     = screen_pos + Vector2(-55.0, -70.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(lbl)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", screen_pos.y - 130.0, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.35).set_delay(0.2)
	await tween.finished
	lbl.queue_free()


# -------------------------------------------------------
# 3D world setup
# -------------------------------------------------------

func _setup_3d_world() -> void:
	# Far clip must reach zone 4 objects (~25 000) plus camera distance (~38 000)
	orbit_camera.far = 100_000.0

	# ── Lighting ─────────────────────────────────────────
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, 40.0, 0.0)
	sun.light_energy = 1.4
	sun.shadow_enabled = false
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(30.0, -140.0, 0.0)
	fill.light_energy = 0.18
	fill.shadow_enabled = false
	add_child(fill)

	# ── Sky / environment ─────────────────────────────────
	var env := Environment.new()
	env.background_mode      = Environment.BG_COLOR
	env.background_color     = Color(0.004, 0.004, 0.016)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.08, 0.08, 0.22)
	env.ambient_light_energy = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# ── Build world objects ───────────────────────────────
	_create_starfield()
	_create_planet()
	_create_player_ship()


func _create_starfield() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 98765

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_POINTS)

	for i in range(3000):
		var dir := Vector3(
				rng.randf_range(-1.0, 1.0),
				rng.randf_range(-1.0, 1.0),
				rng.randf_range(-1.0, 1.0)).normalized()
		var brightness := rng.randf_range(0.35, 1.0)
		var roll := rng.randf()
		var color: Color
		if roll < 0.05:
			color = Color(0.65, 0.75, 1.00, brightness)   # blue-white
		elif roll < 0.08:
			color = Color(1.00, 0.70, 0.40, brightness)   # orange
		elif roll < 0.10:
			color = Color(0.90, 0.65, 1.00, brightness)   # purple
		else:
			color = Color(brightness, brightness, brightness, 1.0)
		st.set_color(color)
		st.add_vertex(dir * 72000.0)

	var star_mesh := st.commit()

	var mat := StandardMaterial3D.new()
	mat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.use_point_size             = true
	mat.point_size                 = 2.5
	mat.vertex_color_use_as_albedo = true

	var mi := MeshInstance3D.new()
	mi.name              = "Starfield"
	mi.mesh              = star_mesh
	mi.material_override = mat
	mi.cast_shadow       = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)



func _create_planet() -> void:
	# ── Surface ───────────────────────────────────────────
	var tex_path: String = GameConfig.ZONES[GameManager.current_zone]["planet_texture"]
	var planet_tex: Texture2D = load(tex_path)

	_planet_mat = StandardMaterial3D.new()
	_planet_mat.albedo_texture = planet_tex
	_planet_mat.roughness      = 0.75
	_planet_mat.metallic       = 0.0

	var planet_mat := _planet_mat

	var planet_mesh := SphereMesh.new()
	planet_mesh.radius          = PLANET_RADIUS
	planet_mesh.height          = PLANET_RADIUS * 2.0
	planet_mesh.radial_segments = 64
	planet_mesh.rings           = 32

	var planet := MeshInstance3D.new()
	planet.name              = "Planet"
	planet.mesh              = planet_mesh
	planet.material_override = planet_mat
	planet.rotation_degrees  = Vector3(0.0, 180.0, 0.0)  # hide UV seam at back
	add_child(planet)

	# ── Cloud layer ───────────────────────────────────────
	var c_noise := FastNoiseLite.new()
	c_noise.noise_type      = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	c_noise.seed            = 77
	c_noise.frequency       = 0.004
	c_noise.fractal_octaves = 4

	var cloud_ramp := Gradient.new()
	cloud_ramp.offsets = PackedFloat32Array([0.0, 0.42, 0.62, 1.0])
	cloud_ramp.colors  = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),   # clear sky
		Color(1.0, 1.0, 1.0, 0.0),   # clear sky
		Color(1.0, 1.0, 1.0, 0.65),  # cloud wisps
		Color(1.0, 1.0, 1.0, 0.90),  # dense cloud
	])

	var c_tex := NoiseTexture2D.new()
	c_tex.noise      = c_noise
	c_tex.width      = 512
	c_tex.height     = 256
	c_tex.seamless   = true
	c_tex.color_ramp = cloud_ramp

	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color   = Color(1.0, 1.0, 1.0, 1.0)
	cloud_mat.albedo_texture = c_tex
	cloud_mat.transparency   = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.shading_mode   = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.cull_mode      = BaseMaterial3D.CULL_BACK

	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radius          = PLANET_RADIUS * 1.025
	cloud_mesh.height          = PLANET_RADIUS * 2.05
	cloud_mesh.radial_segments = 48
	cloud_mesh.rings           = 24

	var clouds := MeshInstance3D.new()
	clouds.name              = "Clouds"
	clouds.mesh              = cloud_mesh
	clouds.material_override = cloud_mat
	clouds.cast_shadow       = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(clouds)

	# ── Atmosphere glow (outer limb) ──────────────────────
	var atmo_mesh := SphereMesh.new()
	atmo_mesh.radius          = PLANET_RADIUS * 1.14
	atmo_mesh.height          = PLANET_RADIUS * 2.28
	atmo_mesh.radial_segments = 32
	atmo_mesh.rings           = 16

	var atmo_mat := StandardMaterial3D.new()
	atmo_mat.albedo_color = Color(0.30, 0.60, 1.0, 0.13)
	atmo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	atmo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	atmo_mat.cull_mode    = BaseMaterial3D.CULL_FRONT

	var atmo := MeshInstance3D.new()
	atmo.name              = "Atmosphere"
	atmo.mesh              = atmo_mesh
	atmo.material_override = atmo_mat
	add_child(atmo)


# -------------------------------------------------------
# Player ship
# -------------------------------------------------------

func _create_player_ship() -> void:
	_player_ship = Node3D.new()
	_player_ship.name = "PlayerShip"

	_ship_sprite = Sprite3D.new()
	_ship_sprite.texture     = load("res://assets/sprites/character/tile_0000.png")
	_ship_sprite.billboard   = BaseMaterial3D.BILLBOARD_ENABLED
	_ship_sprite.pixel_size  = 0.3    # tuned for zone 0; updated per zone
	_ship_sprite.modulate    = Color(0.85, 1.0, 0.9)   # slight green tint
	_ship_sprite.no_depth_test = true  # always draw on top of planet when in front
	_player_ship.add_child(_ship_sprite)

	add_child(_player_ship)

	# ── Mining laser — core beam ──────────────────────────
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius    = 2.5
	core_mesh.bottom_radius = 2.5
	core_mesh.height        = 2.0
	_laser_mat = StandardMaterial3D.new()
	_laser_mat.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laser_mat.transparency              = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser_mat.albedo_color              = Color(0.15, 0.90, 1.00, 0.92)
	_laser_mat.emission_enabled          = true
	_laser_mat.emission                  = Color(0.15, 0.90, 1.00)
	_laser_mat.emission_energy_multiplier = 3.0
	_laser_beam = MeshInstance3D.new()
	_laser_beam.mesh              = core_mesh
	_laser_beam.material_override = _laser_mat
	_laser_beam.visible           = false
	_laser_beam.cast_shadow       = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_laser_beam)

	# ── Mining laser — outer glow ─────────────────────────
	var glow_mesh := CylinderMesh.new()
	glow_mesh.top_radius    = 10.0
	glow_mesh.bottom_radius = 10.0
	glow_mesh.height        = 2.0
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode              = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency              = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.albedo_color              = Color(0.15, 0.90, 1.00, 0.14)
	glow_mat.emission_enabled          = true
	glow_mat.emission                  = Color(0.15, 0.90, 1.00)
	glow_mat.emission_energy_multiplier = 1.0
	_laser_glow = MeshInstance3D.new()
	_laser_glow.mesh              = glow_mesh
	_laser_glow.material_override = glow_mat
	_laser_glow.visible           = false
	_laser_glow.cast_shadow       = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_laser_glow)

	_update_ship_zone()


func _update_ship_zone() -> void:
	var zone: Dictionary = GameConfig.ZONES[GameManager.current_zone]
	_ship_orbit_r = float(zone["radius_min"]) + 50.0
	# Scale character to ~2° apparent size at the current camera distance
	_ship_sprite.pixel_size = _cam_distance * 0.0015


func _update_player_ship(delta: float) -> void:
	if not is_instance_valid(_player_ship):
		return

	var target_pos: Vector3

	if is_instance_valid(_selected_asteroid) and not _selected_asteroid.get("_is_depleted"):
		# Fly toward the selected asteroid
		target_pos = _selected_asteroid.global_position
		# Arrive slightly in front of the asteroid (offset toward camera)
		var to_cam: Vector3 = (orbit_camera.global_position - target_pos).normalized()
		target_pos += to_cam * _ship_sprite.pixel_size * 32.0
	else:
		# Idle orbit around the planet
		_ship_orbit_angle += SHIP_ORBIT_SPEED * delta
		target_pos = Vector3(
				cos(_ship_orbit_angle) * _ship_orbit_r,
				_ship_orbit_r * 0.05,
				sin(_ship_orbit_angle) * _ship_orbit_r)

	# Lerp toward target — naturally fast over long distances, slows on arrival
	_player_ship.global_position = _player_ship.global_position.lerp(target_pos, delta * 2.0)

	# ── Laser beam ────────────────────────────────────────
	_laser_pulse += delta
	if is_instance_valid(_selected_asteroid) and not _selected_asteroid.get("_is_depleted"):
		var ship_pos := _player_ship.global_position
		var ast_pos  := _selected_asteroid.global_position
		_set_beam(_laser_beam, ship_pos, ast_pos)
		_set_beam(_laser_glow, ship_pos, ast_pos)
		var pulse := 0.72 + 0.28 * sin(_laser_pulse * TAU * 3.5)
		_laser_mat.emission_energy_multiplier = pulse * 4.0
	else:
		if is_instance_valid(_laser_beam): _laser_beam.visible = false
		if is_instance_valid(_laser_glow): _laser_glow.visible = false


func _set_beam(beam: MeshInstance3D, from_pos: Vector3, to_pos: Vector3) -> void:
	var dir    := to_pos - from_pos
	var length := dir.length()
	if length < 1.0:
		beam.visible = false
		return
	beam.visible  = true
	var y_axis := dir / length
	var ref    := Vector3.RIGHT if abs(y_axis.dot(Vector3.UP)) > 0.9 else Vector3.UP
	var x_axis := ref.cross(y_axis).normalized()
	var z_axis := y_axis.cross(x_axis)
	# Encode length into basis (CylinderMesh default height = 2, so y scale = length/2)
	beam.global_transform = Transform3D(
			Basis(x_axis, y_axis * (length * 0.5), z_axis),
			(from_pos + to_pos) * 0.5)


# -------------------------------------------------------
# Asteroid spawning
# -------------------------------------------------------

func _spawn_asteroids() -> void:
	for child in asteroid_field.get_children():
		child.queue_free()
	_deselect_asteroid()
	_event_asteroid = null
	_reset_event_timer()

	var zone_idx: int    = GameManager.current_zone
	var zone: Dictionary = GameConfig.ZONES[zone_idx]
	var base_tier: int   = zone_idx + 1

	# Camera sits at 1.5× the zone's outer edge — planet fills ~30% of FOV at zone 0,
	# shrinking to a small dot by zone 4 as you venture deeper into the system.
	_cam_distance = float(zone["radius_max"]) * 1.5 + PLANET_RADIUS
	_update_camera()

	# Cumulative size weights: small 30%, medium 40%, large 22%, mega 8%
	const SIZE_WEIGHTS: Array = [0.30, 0.70, 0.92, 1.00]
	for i in range(ASTEROID_COUNT):
		var asteroid := ASTEROID_SCENE.instantiate()
		# Mix lower tiers into the field so not everything is identical
		var tr := randf()
		var t: int
		if zone_idx == 0:
			t = 1
		elif zone_idx == 1:
			t = 1 if tr > 0.65 else 2
		else:
			if   tr < 0.60: t = base_tier
			elif tr < 0.85: t = base_tier - 1
			else:           t = base_tier - 2
		asteroid.tier        = t
		asteroid.orbit_angle = (TAU / float(ASTEROID_COUNT)) * float(i) + randf() * 0.4
		asteroid.orbit_r     = randf_range(float(zone["radius_min"]), float(zone["radius_max"]))
		asteroid.orbit_y     = randf_range(-1.0, 1.0) * asteroid.orbit_r * 0.22
		var r: float = randf()
		var sc: int  = 3
		for w in range(SIZE_WEIGHTS.size()):
			if r < float(SIZE_WEIGHTS[w]):
				sc = w
				break
		asteroid.size_class   = sc
		asteroid.cam_distance = _cam_distance
		asteroid_field.add_child(asteroid)


# -------------------------------------------------------
# Event asteroid
# -------------------------------------------------------

func _reset_event_timer() -> void:
	_event_timer    = 0.0
	_event_interval = randf_range(
			GameConfig.EVENT_ASTEROID_INTERVAL_MIN,
			GameConfig.EVENT_ASTEROID_INTERVAL_MAX)


func _update_event_asteroid(delta: float) -> void:
	if is_instance_valid(_event_asteroid):
		return
	_event_timer += delta
	if _event_timer >= _event_interval:
		_spawn_event_asteroid()
		_reset_event_timer()


func _spawn_event_asteroid() -> void:
	var zone: Dictionary = GameConfig.ZONES[GameManager.current_zone]
	var asteroid := ASTEROID_SCENE.instantiate()
	asteroid.tier           = GameManager.current_zone + 1
	asteroid.size_class     = 2
	asteroid.is_event       = true
	asteroid.event_lifetime = GameConfig.EVENT_ASTEROID_LIFETIME
	asteroid.orbit_angle    = randf() * TAU
	asteroid.orbit_r        = randf_range(float(zone["radius_min"]), float(zone["radius_max"]))
	asteroid.orbit_y        = randf_range(-1.0, 1.0) * asteroid.orbit_r * 0.22
	asteroid.cam_distance   = _cam_distance
	asteroid_field.add_child(asteroid)
	_event_asteroid = asteroid
	_show_event_banner()


func _show_event_banner() -> void:
	var lbl := Label.new()
	lbl.text = GameConfig.EVENT_ASTEROID_LABEL
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", GameConfig.EVENT_ASTEROID_COLOR)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.offset_left   = -200.0
	lbl.offset_right  =  200.0
	lbl.offset_top    = -80.0
	lbl.offset_bottom = -20.0
	lbl.modulate.a    = 0.0
	$HUD.add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(2.5)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5)
	await tween.finished
	lbl.queue_free()


# -------------------------------------------------------
# EventBus handlers
# -------------------------------------------------------

func _on_resource_changed(amount: float) -> void:
	resource_label.text = _cur(amount)
	_update_stage(amount)
	_refresh_all_buttons()


func _on_passive_rate_changed(rate: float) -> void:
	per_sec_label.text = "%s / sec" % _cur(rate) if rate > 0.0 else ""


func _on_tap_value_changed(_val: float) -> void:
	rate_label.text = "%s: %s / hr" % [
		GameConfig.TAP_STAT_LABEL,
		_cur(GameManager.get_effective_tap_value() * GameConfig.TAP_STAT_MULTIPLIER)
	]


func _on_item_purchased(track: int, index: int) -> void:
	_refresh_track_button(track, index)


func _on_game_days_changed(days: float) -> void:
	var year: int = int(days / 365.0) + 1
	var day: int  = int(days) % 365 + 1
	days_label.text = "Day %d  ·  Year %d" % [day, year]


func _on_offline_income(amount: float) -> void:
	resource_label.text = "+%s while away!" % _cur(amount)
	await get_tree().create_timer(2.5).timeout
	resource_label.text = _cur(GameManager.resources)


func _on_game_ended() -> void:
	pass


func _on_loan_rewarded(_amount: float) -> void:
	pass


func _on_zone_changed(zone: int) -> void:
	_spawn_asteroids()
	_update_ship_zone()
	_refresh_ui()
	_show_zone_banner(GameConfig.ZONES[zone]["name"])
	# Swap planet texture for the new zone
	if is_instance_valid(_planet_mat):
		var tex_path: String = GameConfig.ZONES[zone]["planet_texture"]
		_planet_mat.albedo_texture = load(tex_path)


func _show_zone_banner(zone_name: String) -> void:
	var lbl := Label.new()
	lbl.text = "ORBIT REACHED\n%s" % zone_name
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", _GOLD)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.offset_left   = -160.0
	lbl.offset_right  =  160.0
	lbl.offset_top    = -60.0
	lbl.offset_bottom =  60.0
	lbl.modulate.a    = 0.0
	$HUD.add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(2.5)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.6)
	await tween.finished
	lbl.queue_free()


func _on_mine_blocked(world_pos: Vector3) -> void:
	var screen_pos: Vector2 = orbit_camera.unproject_position(world_pos)
	var lbl := Label.new()
	lbl.text = "UPGRADE SHIP!"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.2, 1.0))
	lbl.position     = screen_pos - Vector2(60.0, 32.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(lbl)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", screen_pos.y - 90.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.4)
	await tween.finished
	lbl.queue_free()


func _on_credits_mined(world_pos: Vector3, amount: float) -> void:
	var screen_pos: Vector2 = orbit_camera.unproject_position(world_pos)
	var lbl := Label.new()
	lbl.text = "+%s" % _cur(amount)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", _CYAN)
	lbl.position     = screen_pos - Vector2(30.0, 16.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(lbl)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", screen_pos.y - 80.0, 0.75).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.25)
	await tween.finished
	lbl.queue_free()


# -------------------------------------------------------
# Stage watermark
# -------------------------------------------------------

func _update_stage(amount: float) -> void:
	var new_label: String = GameConfig.STAGES[0]["label"]
	for s in GameConfig.STAGES:
		if amount >= float(s["threshold"]):
			new_label = s["label"]
	if stage_label.text == new_label:
		return
	stage_label.text = new_label
	var tween := create_tween()
	tween.tween_property(stage_label, "modulate:a", 0.7, 0.35)
	tween.tween_property(stage_label, "modulate:a", 0.15, 1.2)


# -------------------------------------------------------
# Upgrade HUD
# -------------------------------------------------------

func _apply_theme() -> void:
	stage_label.visible = false

	var top_style := StyleBoxFlat.new()
	top_style.bg_color                   = Color(0.06, 0.06, 0.16, 0.93)
	top_style.corner_radius_bottom_left  = 14
	top_style.corner_radius_bottom_right = 14
	top_style.content_margin_left        = 76.0
	top_style.content_margin_right       = 16.0
	top_style.content_margin_top         = 6.0
	top_style.content_margin_bottom      = 10.0
	top_style.shadow_color               = Color(0, 0, 0, 0.2)
	top_style.shadow_size                = 6
	($HUD/TopHUD as PanelContainer).add_theme_stylebox_override("panel", top_style)

	var drawer_style := StyleBoxFlat.new()
	drawer_style.bg_color                   = Color(0.08, 0.08, 0.18, 0.97)
	drawer_style.corner_radius_top_right    = 22
	drawer_style.corner_radius_bottom_right = 22
	drawer_style.content_margin_left        = 8.0
	drawer_style.content_margin_right       = 8.0
	drawer_style.content_margin_top         = 8.0
	drawer_style.content_margin_bottom      = 4.0
	drawer_style.shadow_color               = Color(0, 0, 0, 0.2)
	drawer_style.shadow_size                = 10
	upgrade_drawer.add_theme_stylebox_override("panel", drawer_style)


func _make_btn(min_h: int = 52) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, min_h)
	btn.clip_text = true
	return btn


func _set_btn(btn: Button, t: String, disabled: bool) -> void:
	btn.text     = t
	btn.disabled = disabled


func _build_upgrade_list() -> void:
	for child in upgrade_list.get_children():
		child.queue_free()
	_loan_btn     = null
	_prestige_btn = null

	_add_prestige_button()
	_add_loan_button()

	var tracks := [GameConfig.TRACK_A, GameConfig.TRACK_B, GameConfig.TRACK_C, GameConfig.TRACK_D]
	for track in range(tracks.size()):
		_add_section(track)
		var min_h: int = 60 if track == 1 else 52
		for i in range(tracks[track].size()):
			var btn := _make_btn(min_h)
			btn.name = "Item_%d_%d" % [track, i]
			btn.pressed.connect(_on_track_pressed.bind(track, i))
			_section_container(track).add_child(btn)
			_refresh_track_button(track, i)

	if OS.is_debug_build():
		_add_debug_buttons()


func _track_title(track: int) -> String:
	return ([
		GameConfig.TRACK_A_TITLE,
		GameConfig.TRACK_B_TITLE,
		GameConfig.TRACK_C_TITLE,
		GameConfig.TRACK_D_TITLE,
	] as Array)[track]


func _add_section(track: int) -> void:
	var key := "track_%d" % track
	var hdr := Button.new()
	hdr.name = "Header_%s" % key
	hdr.text = "── %s ▶" % _track_title(track)
	hdr.custom_minimum_size = Vector2(0, 36)
	hdr.add_theme_color_override("font_color", _CYAN)
	hdr.add_theme_font_size_override("font_size", 15)
	hdr.pressed.connect(_toggle_section.bind(key))
	upgrade_list.add_child(hdr)

	var container := VBoxContainer.new()
	container.name    = "Section_%s" % key
	container.visible = not _collapsed[key]
	container.add_theme_constant_override("separation", 4)
	upgrade_list.add_child(container)


func _section_container(track: int) -> VBoxContainer:
	return upgrade_list.get_node("Section_track_%d" % track) as VBoxContainer


func _toggle_section(key: String) -> void:
	var was_collapsed: bool = _collapsed[key]
	for k in _collapsed.keys():
		_collapsed[k] = true
		var c := upgrade_list.get_node_or_null("Section_%s" % k) as VBoxContainer
		var h := upgrade_list.get_node_or_null("Header_%s" % k) as Button
		if c: c.visible = false
		if h: h.text = "── %s ▶" % _track_title(int(k.substr(6)))
	if was_collapsed:
		_collapsed[key] = false
		var container := upgrade_list.get_node_or_null("Section_%s" % key) as VBoxContainer
		var hdr       := upgrade_list.get_node_or_null("Header_%s" % key) as Button
		if container: container.visible = true
		if hdr:       hdr.text = "── %s ▼" % _track_title(int(key.substr(6)))


func _on_track_pressed(track: int, index: int) -> void:
	GameManager.buy_item(track, index)


func _refresh_track_button(track: int, index: int) -> void:
	var key       := "track_%d" % track
	var container := upgrade_list.get_node_or_null("Section_%s" % key) as VBoxContainer
	if container == null: return
	var btn := container.get_node_or_null("Item_%d_%d" % [track, index]) as Button
	if btn == null: return

	match track:
		0:
			var item: Dictionary = GameConfig.TRACK_A[index]
			if GameManager.track_a_purchased[index]:
				_set_btn(btn, "✓ %s  [Equipped]" % item["name"], true)
			else:
				var zone_idx: int = int(item.get("unlocks_zone", -1))
				var zone_tag: String = "  ★ %s" % GameConfig.ZONES[zone_idx]["name"] if zone_idx >= 0 else ""
				_set_btn(btn,
					"%s%s — +%s/tap — %s" % [item["name"], zone_tag, _fmt(item["tap_bonus"]), _cur(item["cost"])],
					not GameManager.can_afford(0, index))
		1:
			var item: Dictionary = GameConfig.TRACK_B[index]
			var owned: int       = GameManager.track_b_owned[index]
			var cost: float      = GameManager.get_item_cost(1, index)
			var t: String
			if owned == 0:
				t = "%s — %s — %s" % [item["name"], item["description"], _cur(cost)]
			else:
				var income: float = float(owned) * float(item["income_per_sec"]) * GameManager.get_passive_multiplier()
				t = "%s [x%d] | +%s/sec | Next: %s" % [
					item["name"], owned, _cur(income), _cur(cost)
				]
			_set_btn(btn, t, not GameManager.can_afford(1, index))
		2:
			var item: Dictionary = GameConfig.TRACK_C[index]
			if GameManager.track_c_purchased[index]:
				_set_btn(btn, "✓ %s  [Installed]" % item["name"], true)
			else:
				_set_btn(btn,
					"%s — %s — %s" % [item["name"], item["description"], _cur(item["cost"])],
					not GameManager.can_afford(2, index))
		3:
			var item: Dictionary = GameConfig.TRACK_D[index]
			if GameManager.track_d_purchased[index]:
				_set_btn(btn, "✓ %s  [Equipped]" % item["name"], true)
			else:
				_set_btn(btn,
					"%s — %s — %s" % [item["name"], item["description"], _cur(item["cost"])],
					not GameManager.can_afford(3, index))


func _refresh_all_buttons() -> void:
	var sizes := [
		GameConfig.TRACK_A.size(), GameConfig.TRACK_B.size(),
		GameConfig.TRACK_C.size(), GameConfig.TRACK_D.size(),
	]
	for track in range(sizes.size()):
		for i in range(sizes[track]):
			_refresh_track_button(track, i)
	_refresh_prestige_button()
	_update_hamburger_notif()


func _refresh_ui() -> void:
	resource_label.text = _cur(GameManager.resources)
	rate_label.text = "%s: %s / hr" % [
		GameConfig.TAP_STAT_LABEL,
		_cur(GameManager.get_effective_tap_value() * GameConfig.TAP_STAT_MULTIPLIER)
	]
	if GameManager.passive_rate > 0.0:
		per_sec_label.text = "%s / sec" % _cur(GameManager.passive_rate)
	_refresh_all_buttons()
	_update_stage(GameManager.resources)
	if is_instance_valid(zone_label):
		zone_label.text = "Orbit: %s  ×%.0f" % [
			GameConfig.ZONES[GameManager.current_zone]["name"],
			GameConfig.ZONES[GameManager.current_zone]["ore_multiplier"],
		]


# ── Loan button ─────────────────────────────────────────

func _add_loan_button() -> void:
	var btn := _make_btn(52)
	btn.name = "LoanButton"
	btn.pressed.connect(_on_loan_pressed)
	upgrade_list.add_child(btn)
	_loan_btn = btn
	_refresh_loan_button()


func _refresh_loan_button() -> void:
	if _loan_btn == null or not is_instance_valid(_loan_btn):
		return
	if AdManager.can_request_loan():
		_set_btn(_loan_btn,
			"%s — Watch Ad → +%s" % [GameConfig.AD_LOAN_LABEL, _cur(GameConfig.AD_LOAN_AMOUNT)],
			false)
		_loan_btn.add_theme_color_override("font_color", _GOLD)
	else:
		_set_btn(_loan_btn,
			"%s — Ready in %s" % [GameConfig.AD_LOAN_LABEL, AdManager.cooldown_label()],
			true)
		_loan_btn.remove_theme_color_override("font_color")


func _on_loan_pressed() -> void:
	AdManager.request_loan()


# ── Prestige button ──────────────────────────────────────

func _add_prestige_button() -> void:
	var btn := _make_btn(56)
	btn.name = "PrestigeButton"
	btn.pressed.connect(_on_prestige_pressed)
	upgrade_list.add_child(btn)
	_prestige_btn = btn
	_refresh_prestige_button()


func _refresh_prestige_button() -> void:
	if _prestige_btn == null or not is_instance_valid(_prestige_btn):
		return
	var count      := GameManager.prestige_count
	var cur_bonus  := int(GameManager.get_prestige_multiplier() * 100.0) - 100
	var next_bonus := int((1.0 + (count + 1) * GameConfig.PRESTIGE_BONUS_PER_RUN) * 100.0) - 100
	if GameManager.can_prestige():
		var label := "✦ %s — Reset for +%d%% all income" % [
			GameConfig.PRESTIGE_LABEL, int(GameConfig.PRESTIGE_BONUS_PER_RUN * 100)]
		if count > 0:
			label = "✦ %s [×%d, +%d%% now] — Reset for +%d%% total" % [
				GameConfig.PRESTIGE_LABEL, count, cur_bonus, next_bonus]
		_set_btn(_prestige_btn, label, false)
		_prestige_btn.add_theme_color_override("font_color", _GOLD)
	else:
		var lock_msg := "✦ %s — Reach Kuiper Belt to unlock" % GameConfig.PRESTIGE_LABEL
		if count > 0:
			lock_msg = "✦ %s [×%d, +%d%% income] — Reach Kuiper Belt again" % [
				GameConfig.PRESTIGE_LABEL, count, cur_bonus]
		_set_btn(_prestige_btn, lock_msg, true)
		_prestige_btn.remove_theme_color_override("font_color")


func _on_prestige_pressed() -> void:
	GameManager.prestige()


func _on_prestige_performed(count: int) -> void:
	_spawn_asteroids()
	_update_ship_zone()
	_build_upgrade_list()
	_refresh_ui()
	_show_prestige_banner(count)


func _show_prestige_banner(count: int) -> void:
	var total_bonus := int(count * GameConfig.PRESTIGE_BONUS_PER_RUN * 100)
	var lbl := Label.new()
	lbl.text = "✦ STELLAR REBIRTH ✦\nRun #%d  —  +%d%% all income forever" % [count, total_bonus]
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", _GOLD)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.offset_left   = -200.0
	lbl.offset_right  =  200.0
	lbl.offset_top    = -60.0
	lbl.offset_bottom =  60.0
	lbl.modulate.a    = 0.0
	$HUD.add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(3.0)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.8)
	await tween.finished
	lbl.queue_free()


# ── Debug buttons ───────────────────────────────────────

func _add_debug_buttons() -> void:
	var specs := [
		["[D] +$100K",  func(): GameManager.add_resources(100_000.0)],
		["[D] +$1B",    func(): GameManager.add_resources(1_000_000_000.0)],
		["[D] RESET",   func(): _debug_reset()],
	]
	for spec in specs:
		var btn := Button.new()
		btn.text = spec[0]
		btn.pressed.connect(spec[1])
		upgrade_list.add_child(btn)


func _debug_reset() -> void:
	SaveManager.delete_save()
	GameManager.reset()
	_spawn_asteroids()
	_update_ship_zone()
	_build_upgrade_list()
	_refresh_ui()


func _toggle_drawer() -> void:
	_drawer_open = not _drawer_open
	drawer_overlay.visible = _drawer_open
	hamburger_btn.text = "✕" if _drawer_open else "☰"
	var tween := create_tween()
	tween.set_parallel(true)
	if _drawer_open:
		tween.tween_property(upgrade_drawer, "offset_left",  0.0,        0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(upgrade_drawer, "offset_right", _DRAWER_W,  0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(upgrade_drawer, "offset_left",  -_DRAWER_W, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(upgrade_drawer, "offset_right", 0.0,        0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func _style_hamburger_btn() -> void:
	hamburger_btn.add_theme_font_size_override("font_size", 28)
	hamburger_btn.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.06, 0.06, 0.16, 0.88)
	style.corner_radius_top_left     = 30
	style.corner_radius_top_right    = 30
	style.corner_radius_bottom_left  = 30
	style.corner_radius_bottom_right = 30
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size  = 6
	hamburger_btn.add_theme_stylebox_override("normal", style)
	var style_h := style.duplicate() as StyleBoxFlat
	style_h.bg_color = Color(0.12, 0.12, 0.28, 0.95)
	hamburger_btn.add_theme_stylebox_override("hover",   style_h)
	hamburger_btn.add_theme_stylebox_override("pressed", style_h)
	var ov_style := StyleBoxFlat.new()
	ov_style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	drawer_overlay.add_theme_stylebox_override("normal",  ov_style)
	drawer_overlay.add_theme_stylebox_override("hover",   ov_style)
	drawer_overlay.add_theme_stylebox_override("pressed", ov_style)


func _update_hamburger_notif() -> void:
	if not is_instance_valid(hamburger_btn):
		return
	if _drawer_open:
		return
	var any_affordable := false
	for key in _collapsed.keys():
		if _has_affordable_track(key):
			any_affordable = true
			break
	hamburger_btn.add_theme_color_override("font_color",
		_GOLD if any_affordable else Color.WHITE)


func _has_affordable_track(key: String) -> bool:
	var track := int(key.substr(6))
	var sizes := [GameConfig.TRACK_A.size(), GameConfig.TRACK_B.size(),
		GameConfig.TRACK_C.size(), GameConfig.TRACK_D.size()]
	for i in range(sizes[track]):
		if GameManager.can_afford(track, i):
			return true
	return false


# -------------------------------------------------------
# Number formatting
# -------------------------------------------------------

func _fmt(n: float) -> String:
	if   n >= 1.0e33: return "%.2fDc" % (n / 1.0e33)
	elif n >= 1.0e30: return "%.2fNo" % (n / 1.0e30)
	elif n >= 1.0e27: return "%.2fOc" % (n / 1.0e27)
	elif n >= 1.0e24: return "%.2fSp" % (n / 1.0e24)
	elif n >= 1.0e21: return "%.2fSx" % (n / 1.0e21)
	elif n >= 1.0e18: return "%.2fQi" % (n / 1.0e18)
	elif n >= 1.0e15: return "%.2fQa" % (n / 1.0e15)
	elif n >= 1.0e12: return "%.2fT"  % (n / 1.0e12)
	elif n >= 1.0e9:  return "%.2fB"  % (n / 1.0e9)
	elif n >= 1.0e6:  return "%.2fM"  % (n / 1.0e6)
	elif n >= 1.0e3:  return "%.1fK"  % (n / 1.0e3)
	return "%.2f" % n


func _cur(n: float) -> String:
	return GameConfig.CURRENCY_FORMAT % _fmt(n)
