extends Node2D

# -------------------------------------------------------
# Game.gd — Orchestrates the asteroid field, player
# movement (tap-to-move), and the upgrade HUD.
#
# World coordinates: the Camera2D inside Player follows
# the player, so all screen taps must be converted to
# world space before setting the player's move target.
# -------------------------------------------------------

# ── HUD node refs (exist in Game.tscn) ─────────────────
@onready var resource_label:   Label          = $HUD/TopHUD/Stats/ResourceLabel
@onready var rate_label:       Label          = $HUD/TopHUD/Stats/RateLabel
@onready var per_sec_label:    Label          = $HUD/TopHUD/Stats/PerSecLabel
@onready var days_label:       Label          = $HUD/TopHUD/Stats/DaysLabel
@onready var zone_label:       Label          = $HUD/TopHUD/Stats/ZoneLabel
@onready var upgrade_list:     VBoxContainer  = $HUD/UpgradeDrawer/ScrollContainer/UpgradeList
@onready var upgrade_drawer:   PanelContainer = $HUD/UpgradeDrawer
@onready var stage_label:      Label          = $HUD/StageLabel
@onready var hamburger_btn:  Button = $HUD/HamburgerBtn
@onready var drawer_overlay: Button = $HUD/DrawerOverlay
@onready var player:           CharacterBody2D = $Player
@onready var asteroid_field:   Node2D          = $World/AsteroidField

# ── Asteroid spawning ───────────────────────────────────
const ASTEROID_SCENE   := preload("res://scenes/Asteroid.tscn")
const ASTEROID_COUNT   := 14

# ── Orbital 3-D perspective ──────────────────────────────
# Side-view compression: the orbit circle seen from the side becomes an ellipse.
# ry = rx * ORBIT_RY_RATIO  (smaller = more edge-on, flatter)
const ORBIT_RY_RATIO   := 0.30

const _PLANET_SCRIPT    := preload("res://scenes/Planet.gd")
const _ORBITLINES_SCRIPT := preload("res://scenes/OrbitLines.gd")

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
const _DIM_BG    := Color(0.06, 0.06, 0.16, 0.95)

var _loan_btn:          Button = null
var _drawer_open := false
const _DRAWER_W  := 300.0

# ── Orbital view state ───────────────────────────────────
var _planet_node:      Node2D = null
var _orbit_lines_node: Node2D = null
var _last_player_x:    float  = 0.0


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
	AdManager.loan_rewarded.connect(_on_loan_rewarded)
	EventBus.zone_changed.connect(_on_zone_changed)

	_setup_orbital_view()
	_apply_theme()
	_build_upgrade_list()
	_spawn_asteroids()
	_refresh_ui()
	hamburger_btn.pressed.connect(_toggle_drawer)
	drawer_overlay.pressed.connect(_toggle_drawer)
	_style_hamburger_btn()


func _process(_delta: float) -> void:
	_refresh_loan_button()
	# Spin planet proportional to horizontal player movement (orbital illusion)
	if is_instance_valid(_planet_node) and is_instance_valid(player):
		var dx := player.global_position.x - _last_player_x
		_planet_node.spin(dx)
		_last_player_x = player.global_position.x


# -------------------------------------------------------
# Input — tap in world area → move player there
# -------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var screen_pos := Vector2.ZERO

	if event is InputEventScreenTouch and event.pressed:
		screen_pos = event.position
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed \
			and not DisplayServer.is_touchscreen_available():
		screen_pos = event.position
	else:
		return

	# Let the upgrade drawer consume its own taps
	if _drawer_open:
		return

	# Convert screen → world coordinates (Camera2D follows player)
	var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen_pos

	# Snap to nearest non-depleted asteroid when tapping within range
	# Snap radius is generous since the orbit is elliptical (compressed y-axis)
	const SNAP_RADIUS := 80.0
	var nearest: Node2D  = null
	var nearest_dist     := SNAP_RADIUS
	for body in get_tree().get_nodes_in_group("asteroids"):
		if body is Node2D and not (body as Node).get("_is_depleted"):
			var d: float = (body as Node2D).global_position.distance_to(world_pos)
			if d < nearest_dist:
				nearest_dist = d
				nearest      = body as Node2D
	if nearest != null:
		world_pos = nearest.global_position

	player.set_move_target(world_pos)


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
	# TODO: wire up an EndScreen scene
	pass


func _on_loan_rewarded(_amount: float) -> void:
	pass


func _on_zone_changed(zone: int) -> void:
	_spawn_asteroids()
	player.set_move_target(Vector2.ZERO)
	_refresh_ui()
	_show_zone_banner(GameConfig.ZONES[zone]["name"])
	_refresh_orbit_lines()


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


func _on_mine_blocked(world_pos: Vector2) -> void:
	var screen_pos := get_viewport().get_canvas_transform() * world_pos
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


func _on_credits_mined(world_pos: Vector2, amount: float) -> void:
	var screen_pos := get_viewport().get_canvas_transform() * world_pos
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
# Asteroid spawning
# -------------------------------------------------------

func _spawn_asteroids() -> void:
	for child in asteroid_field.get_children():
		child.queue_free()
	var zone_idx: int    = GameManager.current_zone
	var zone: Dictionary = GameConfig.ZONES[zone_idx]
	var t: int           = zone_idx + 1
	for i in range(ASTEROID_COUNT):
		var asteroid := ASTEROID_SCENE.instantiate()
		asteroid.tier         = t
		asteroid.orbit_angle  = (TAU / float(ASTEROID_COUNT)) * float(i) + randf() * 0.4
		asteroid.orbit_rx     = randf_range(float(zone["radius_min"]), float(zone["radius_max"]))
		asteroid.orbit_ry     = asteroid.orbit_rx * ORBIT_RY_RATIO
		asteroid_field.add_child(asteroid)  # _ready() reads orbit params
	_refresh_orbit_lines()


# -------------------------------------------------------
# Upgrade HUD — same accordion pattern as template
# -------------------------------------------------------

# -------------------------------------------------------
# Orbital view setup — background planet + orbit arc lines
# -------------------------------------------------------

func _setup_orbital_view() -> void:
	# ── Background CanvasLayer (behind world) ────────────
	var bg := CanvasLayer.new()
	bg.name  = "Background"
	bg.layer = -2
	add_child(bg)

	# Star-field fill
	var stars := ColorRect.new()
	stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	stars.color        = Color(0.01, 0.01, 0.04, 1.0)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(stars)

	# Planet — always screen-centered, spins with player
	_planet_node = Node2D.new()
	_planet_node.set_script(_PLANET_SCRIPT)
	bg.add_child(_planet_node)

	# ── Orbit arc lines in world space ───────────────────
	_orbit_lines_node = Node2D.new()
	_orbit_lines_node.set_script(_ORBITLINES_SCRIPT)
	_orbit_lines_node.z_index = -2
	$World.add_child(_orbit_lines_node)

	_last_player_x = player.global_position.x


func _refresh_orbit_lines() -> void:
	if not is_instance_valid(_orbit_lines_node):
		return
	var data: Array = []
	# Previous (unlocked) zones — faint, smaller radii
	for z in range(GameManager.current_zone):
		var zd: Dictionary = GameConfig.ZONES[z]
		var rx := (float(zd["radius_min"]) + float(zd["radius_max"])) * 0.5
		data.append({"rx": rx, "ry": rx * ORBIT_RY_RATIO,
			"color": Color(0.35, 0.55, 0.85, 0.10)})
	# Current zone — brighter
	var cz: Dictionary = GameConfig.ZONES[GameManager.current_zone]
	var crx := (float(cz["radius_min"]) + float(cz["radius_max"])) * 0.5
	data.append({"rx": crx, "ry": crx * ORBIT_RY_RATIO,
		"color": Color(0.45, 0.75, 1.00, 0.22)})
	_orbit_lines_node.call("set_orbits", data)


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
	drawer_style.bg_color                        = Color(0.08, 0.08, 0.18, 0.97)
	drawer_style.corner_radius_top_left          = 0
	drawer_style.corner_radius_top_right         = 22
	drawer_style.corner_radius_bottom_left       = 0
	drawer_style.corner_radius_bottom_right      = 22
	drawer_style.content_margin_left      = 8.0
	drawer_style.content_margin_right     = 8.0
	drawer_style.content_margin_top       = 8.0
	drawer_style.content_margin_bottom    = 4.0
	drawer_style.shadow_color             = Color(0, 0, 0, 0.2)
	drawer_style.shadow_size              = 10
	upgrade_drawer.add_theme_stylebox_override("panel", drawer_style)


func _make_btn(min_h: int = 52) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, min_h)
	btn.clip_text = true
	return btn


func _set_btn(btn: Button, t: String, disabled: bool) -> void:
	btn.text = t
	btn.disabled = disabled


func _build_upgrade_list() -> void:
	for child in upgrade_list.get_children():
		child.queue_free()
	_loan_btn = null

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
		var h := upgrade_list.get_node_or_null("Header_%s" % k)  as Button
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
		0:   # Spacecraft — one-time mine yield + optional zone unlock
			var item: Dictionary = GameConfig.TRACK_A[index]
			if GameManager.track_a_purchased[index]:
				_set_btn(btn, "✓ %s  [Equipped]" % item["name"], true)
			else:
				var zone_idx: int = int(item.get("unlocks_zone", -1))
				var zone_tag: String = "  ★ %s" % GameConfig.ZONES[zone_idx]["name"] if zone_idx >= 0 else ""
				_set_btn(btn,
					"%s%s — +%s/tap — %s" % [item["name"], zone_tag, _fmt(item["tap_bonus"]), _cur(item["cost"])],
					not GameManager.can_afford(0, index))
		1:   # Drones — repeatable generators
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
		2:   # Ship mods — passive multipliers
			var item: Dictionary = GameConfig.TRACK_C[index]
			if GameManager.track_c_purchased[index]:
				_set_btn(btn, "✓ %s  [Installed]" % item["name"], true)
			else:
				_set_btn(btn,
					"%s — %s — %s" % [item["name"], item["description"], _cur(item["cost"])],
					not GameManager.can_afford(2, index))
		3:   # Pilot skills — mine multipliers
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
	style.bg_color            = Color(0.06, 0.06, 0.16, 0.88)
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
