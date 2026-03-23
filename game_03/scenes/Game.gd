extends Node2D

# ── Scene refs ────────────────────────────────────────
@onready var world:        Node2D      = $World
@onready var enemy_layer:  Node2D      = $EnemyLayer
@onready var bullet_layer: Node2D      = $BulletLayer
@onready var formation:    Node2D      = $Formation
@onready var hud:          CanvasLayer = $HUD
@onready var joy_layer:    CanvasLayer = $JoystickLayer

const ENEMY_SCENE       := preload("res://scenes/Enemy.tscn")
const FORMATION_SCENE   := preload("res://scenes/Formation.tscn")
const COLLECTIBLE_SCENE := preload("res://scenes/Collectible.tscn")

# ── HUD refs (built in _ready) ────────────────────────
var _wave_label:      Label   = null
var _hp_label:        Label   = null
var _hoard_label:     Label   = null
var _gems_label:      Label   = null
var _wave_banner:     Label   = null
var _upgrade_panel:   Control = null

# ── Joystick ──────────────────────────────────────────
var _joy_base_pos:    Vector2 = Vector2.ZERO
var _joy_knob_pos:    Vector2 = Vector2.ZERO
var _joy_active:      bool    = false
var _joy_touch_idx:   int     = -1
const JOY_RADIUS      := 70.0
var _joy_base_node:   Control = null
var _joy_knob_node:   Control = null

# ── Wave state ────────────────────────────────────────
var _current_wave:    int   = 0
var _enemies_alive:   int   = 0
var _wave_in_progress: bool = false
var _run_active:      bool  = false
var _between_waves:   bool  = false
var _spawn_queue:     Array = []
var _spawn_timer:     float = 0.0
const SPAWN_INTERVAL  := 0.8

# ── Game state ────────────────────────────────────────
var _game_over:       bool  = false
var _upgrade_pending: bool  = false
var _is_paused:       bool  = false
var _sound_muted:     bool  = false
var _pause_panel:     Control = null
var _sound_btn:       Button  = null


func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.formation_hp_changed.connect(_on_hp_changed)
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.enemy_dropped.connect(_on_enemy_dropped)
	EventBus.gem_changed.connect(_on_gem_changed)
	EventBus.hero_weapon_changed.connect(_on_hero_weapon_changed)
	formation.formation_destroyed.connect(_on_formation_destroyed)
	_build_hud()
	_build_pause_menu()
	_build_joystick()
	_draw_background()
	GameManager.start_run()
	_setup_formation()
	_start_wave()


func _process(delta: float) -> void:
	if _game_over or _between_waves:
		return
	_tick_spawner(delta)
	_update_keyboard_input()
	# Check wave clear
	if _wave_in_progress and _spawn_queue.is_empty() and _enemies_alive == 0:
		_on_wave_cleared()


func _update_keyboard_input() -> void:
	if _joy_active:
		return   # joystick takes priority on mobile
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1.0
	formation.set_move_input(dir.normalized() if dir.length() > 0.1 else Vector2.ZERO)


# ── Formation setup ────────────────────────────────────
func _setup_formation() -> void:
	var vp: Vector2 = get_viewport_rect().size
	formation.position = Vector2(vp.x * 0.5, vp.y * 0.75)
	formation.add_hero()
	for unit_type in GameManager.run_soldiers:
		formation.add_soldier(unit_type)


# ── Wave management ────────────────────────────────────
func _start_wave() -> void:
	_current_wave += 1
	_wave_in_progress = true
	_between_waves    = false
	_enemies_alive    = 0
	# Build spawn queue
	var wave_idx: int = (_current_wave - 1) % GameConfig.WAVES.size()
	var wave_def: Array = GameConfig.WAVES[wave_idx]
	_spawn_queue = []
	for entry in wave_def:
		var type:  String = entry[0]
		var count: int    = entry[1]
		for _i in range(count):
			_spawn_queue.append(type)
	_spawn_queue.shuffle()
	_spawn_timer = 0.0
	EventBus.wave_started.emit(_current_wave)
	_show_wave_banner("WAVE %d" % _current_wave)
	_update_hud()


func _tick_spawner(delta: float) -> void:
	if _spawn_queue.is_empty():
		return
	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		_spawn_enemy(_spawn_queue.pop_front())


func _spawn_enemy(type: String) -> void:
	var enemy := ENEMY_SCENE.instantiate()
	enemy_layer.add_child(enemy)
	enemy.setup(type, _current_wave - 1)
	enemy.set_target(formation)
	# Spawn from a random edge
	var vp: Vector2  = get_viewport_rect().size
	var side: int    = randi() % 4
	var pos: Vector2
	match side:
		0: pos = Vector2(randf_range(0, vp.x), -30.0)           # top
		1: pos = Vector2(randf_range(0, vp.x), vp.y + 30.0)    # bottom
		2: pos = Vector2(-30.0, randf_range(0, vp.y))           # left
		3: pos = Vector2(vp.x + 30.0, randf_range(0, vp.y))    # right
	enemy.global_position = pos
	_enemies_alive += 1


func _on_wave_cleared() -> void:
	_wave_in_progress = false
	_between_waves    = true
	EventBus.wave_cleared.emit(_current_wave)
	if _current_wave >= GameConfig.WAVES.size():
		_end_run(true)
		return
	_show_upgrade_panel()


func _end_run(victory: bool) -> void:
	_game_over = true
	_run_active = false
	get_tree().paused = false
	_is_paused = false
	GameManager.end_run(_current_wave)
	_show_run_over_screen(victory)


# ── Run over screen ────────────────────────────────────
func _show_run_over_screen(victory: bool) -> void:
	var panel := _make_panel(Vector2(280, 340), Vector2(
		get_viewport_rect().size.x * 0.5 - 140,
		get_viewport_rect().size.y * 0.5 - 170))
	hud.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "VICTORY!" if victory else "DEFEATED"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color",
		GameConfig.COLOR_GOLD if victory else GameConfig.COLOR_RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var stats := Label.new()
	stats.text = "Waves Cleared: %d\nGold Earned: %d\nTotal Hoard: %d" % [
		_current_wave,
		GameManager.run_hoard_earned,
		GameManager.hoard,
	]
	stats.add_theme_font_size_override("font_size", 18)
	stats.add_theme_color_override("font_color", Color.WHITE)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats)

	var btn_menu := Button.new()
	btn_menu.text = "Main Menu"
	btn_menu.custom_minimum_size = Vector2(0, 52)
	btn_menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	vbox.add_child(btn_menu)

	var btn_again := Button.new()
	btn_again.text = "Play Again"
	btn_again.custom_minimum_size = Vector2(0, 52)
	btn_again.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	vbox.add_child(btn_again)


# ── Upgrade pick panel ─────────────────────────────────
func _show_upgrade_panel() -> void:
	# Force-unpause so upgrade buttons are always interactive
	get_tree().paused = false
	_is_paused = false
	if is_instance_valid(_pause_panel):
		_pause_panel.visible = false
		(_pause_panel.get_meta("dim") as ColorRect).visible = false
	var choices := GameManager.get_run_upgrade_choices(3)
	var vp: Vector2 = get_viewport_rect().size
	var panel := _make_panel(Vector2(320, 380), Vector2(vp.x * 0.5 - 160, vp.y * 0.5 - 190))
	panel.name = "UpgradePanel"
	hud.add_child(panel)
	_upgrade_panel = panel

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "CHOOSE UPGRADE"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", GameConfig.COLOR_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	for choice in choices:
		var btn := Button.new()
		btn.text = "%s\n%s" % [choice["name"], choice["desc"]]
		btn.custom_minimum_size = Vector2(0, 72)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_upgrade_chosen.bind(choice))
		vbox.add_child(btn)


func _on_upgrade_chosen(choice: Dictionary) -> void:
	if is_instance_valid(_upgrade_panel):
		_upgrade_panel.queue_free()
		_upgrade_panel = null
	GameManager.apply_run_upgrade(choice)
	if choice["type"] == "add_unit":
		formation.add_soldier(choice["unit"])
	elif choice["type"] == "heal":
		formation.heal_all(float(choice["amount"]))
	EventBus.upgrade_chosen.emit(choice["id"])
	_between_waves = false
	_start_wave()


# ── HUD ───────────────────────────────────────────────
func _build_hud() -> void:
	# Wave label
	_wave_label = Label.new()
	_wave_label.add_theme_font_size_override("font_size", 18)
	_wave_label.add_theme_color_override("font_color", Color.WHITE)
	_wave_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wave_label.offset_left   = -120.0
	_wave_label.offset_top    = 10.0
	_wave_label.offset_right  = -8.0
	_wave_label.offset_bottom = 40.0
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wave_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_wave_label)

	# HP label
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 18)
	_hp_label.add_theme_color_override("font_color", GameConfig.COLOR_GREEN)
	_hp_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hp_label.offset_left   = 8.0
	_hp_label.offset_top    = 10.0
	_hp_label.offset_right  = 160.0
	_hp_label.offset_bottom = 40.0
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_hp_label)

	# Hoard label
	_hoard_label = Label.new()
	_hoard_label.add_theme_font_size_override("font_size", 16)
	_hoard_label.add_theme_color_override("font_color", GameConfig.COLOR_GOLD)
	_hoard_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hoard_label.offset_left   = 8.0
	_hoard_label.offset_top    = 38.0
	_hoard_label.offset_right  = 180.0
	_hoard_label.offset_bottom = 62.0
	_hoard_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_hoard_label)

	# Gems label
	_gems_label = Label.new()
	_gems_label.add_theme_font_size_override("font_size", 16)
	_gems_label.add_theme_color_override("font_color", Color(0.30, 0.60, 1.00))
	_gems_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_gems_label.offset_left   = 8.0
	_gems_label.offset_top    = 62.0
	_gems_label.offset_right  = 180.0
	_gems_label.offset_bottom = 86.0
	_gems_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gems_label.text = "♦ %d gems" % GameManager.gems
	hud.add_child(_gems_label)

	# Wave banner (center, transient)
	_wave_banner = Label.new()
	_wave_banner.add_theme_font_size_override("font_size", 28)
	_wave_banner.add_theme_color_override("font_color", GameConfig.COLOR_GOLD)
	_wave_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_banner.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_wave_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_banner.set_anchors_preset(Control.PRESET_CENTER)
	_wave_banner.offset_left   = -160.0
	_wave_banner.offset_right  =  160.0
	_wave_banner.offset_top    = -30.0
	_wave_banner.offset_bottom =  30.0
	_wave_banner.modulate.a    = 0.0
	hud.add_child(_wave_banner)

	# Hamburger menu button — top-center
	var menu_btn := Button.new()
	menu_btn.text = "☰"
	menu_btn.add_theme_font_size_override("font_size", 22)
	menu_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	menu_btn.offset_left   = -28.0
	menu_btn.offset_right  =  28.0
	menu_btn.offset_top    =  6.0
	menu_btn.offset_bottom =  44.0
	menu_btn.flat = true
	menu_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_btn.pressed.connect(_toggle_pause)
	hud.add_child(menu_btn)

	_update_hud()


func _build_pause_menu() -> void:
	var vp: Vector2 = get_viewport_rect().size

	# Full-screen dim overlay
	var overlay := ColorRect.new()
	overlay.color        = Color(0.0, 0.0, 0.0, 0.55)
	overlay.size         = vp
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible      = false
	overlay.name         = "PauseDim"
	hud.add_child(overlay)

	# Centred panel
	var panel := _make_panel(Vector2(270, 320), Vector2(vp.x * 0.5 - 135, vp.y * 0.5 - 160))
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible      = false
	panel.name         = "PausePanel"
	hud.add_child(panel)
	_pause_panel = panel

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", GameConfig.COLOR_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var btn_resume := Button.new()
	btn_resume.text = "Resume"
	btn_resume.custom_minimum_size = Vector2(0, 52)
	btn_resume.pressed.connect(_toggle_pause)
	vbox.add_child(btn_resume)

	_sound_btn = Button.new()
	_sound_btn.text = "Sound: ON"
	_sound_btn.custom_minimum_size = Vector2(0, 52)
	_sound_btn.pressed.connect(_toggle_sound)
	vbox.add_child(_sound_btn)

	var btn_menu := Button.new()
	btn_menu.text = "Main Menu"
	btn_menu.custom_minimum_size = Vector2(0, 52)
	btn_menu.add_theme_color_override("font_color", GameConfig.COLOR_RED)
	btn_menu.pressed.connect(_go_to_main_menu)
	vbox.add_child(btn_menu)

	# Store overlay ref on the panel so we can show/hide it together
	panel.set_meta("dim", overlay)


func _toggle_pause() -> void:
	_is_paused = not _is_paused
	get_tree().paused = _is_paused
	if is_instance_valid(_pause_panel):
		_pause_panel.visible = _is_paused
		var dim: ColorRect = _pause_panel.get_meta("dim")
		dim.visible = _is_paused


func _toggle_sound() -> void:
	_sound_muted = not _sound_muted
	AudioServer.set_bus_mute(0, _sound_muted)
	if is_instance_valid(_sound_btn):
		_sound_btn.text = "Sound: OFF" if _sound_muted else "Sound: ON"


func _go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _update_hud() -> void:
	if is_instance_valid(_wave_label):
		_wave_label.text = "Wave %d / %d" % [_current_wave, GameConfig.WAVES.size()]
	if is_instance_valid(_hoard_label):
		_hoard_label.text = "⚙ Gold: %d" % GameManager.run_hoard_earned


func _show_wave_banner(text: String) -> void:
	if not is_instance_valid(_wave_banner):
		return
	_wave_banner.text = text
	var tween := create_tween()
	tween.tween_property(_wave_banner, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.2)
	tween.tween_property(_wave_banner, "modulate:a", 0.0, 0.4)


func _on_enemy_killed(_pos: Vector2, _reward: int) -> void:
	_enemies_alive = max(0, _enemies_alive - 1)
	_update_hud()


func _on_hp_changed(current: int, maximum: int) -> void:
	if is_instance_valid(_hp_label):
		_hp_label.text = "❤ %d / %d" % [current, maximum]


func _on_entity_died(pos: Vector2, is_enemy: bool) -> void:
	var p := CPUParticles2D.new()
	p.global_position      = pos
	p.emitting             = true
	p.one_shot             = true
	p.explosiveness        = 0.95
	p.lifetime             = 0.45
	p.amount               = 14
	p.spread               = 180.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min     = 3.0
	p.scale_amount_max     = 6.0
	# Red blood for enemies, blue for friendly soldiers
	p.color = Color(0.72, 0.02, 0.02) if is_enemy else Color(0.1, 0.35, 0.85)
	world.add_child(p)
	var timer := get_tree().create_timer(1.5)
	timer.timeout.connect(p.queue_free)


func _on_formation_destroyed() -> void:
	if not _game_over:
		_end_run(false)


func _on_enemy_dropped(pos: Vector2, enemy_type: String) -> void:
	var drops: Array = GameConfig.COLLECTIBLE_DROPS.get(enemy_type, [])
	for drop in drops:
		if randf() <= float(drop["chance"]):
			_spawn_collectible(pos, drop["type"], int(drop["amount"]))


func _spawn_collectible(pos: Vector2, type: String, amount: int) -> void:
	var c = COLLECTIBLE_SCENE.instantiate()
	world.add_child(c)
	c.global_position = pos
	c.setup(type, amount, formation)


func _on_gem_changed(total: int) -> void:
	if is_instance_valid(_gems_label):
		_gems_label.text = "♦ %d gems" % total


func _on_hero_weapon_changed(weapon_id: String) -> void:
	if weapon_id.begins_with("__found__"):
		var wid: String = weapon_id.substr(9)
		var w: Dictionary = GameConfig.WEAPONS.get(wid, {})
		if not w.is_empty():
			var rarity: String = w["rarity"]
			_show_wave_banner("%s\n[%s]" % [w["display_name"], rarity.to_upper()])


# ── Virtual joystick ──────────────────────────────────
func _build_joystick() -> void:
	_joy_base_node = ColorRect.new()
	_joy_base_node.color = Color(1.0, 1.0, 1.0, 0.12)
	_joy_base_node.size  = Vector2(JOY_RADIUS * 2, JOY_RADIUS * 2)
	_joy_base_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_layer.add_child(_joy_base_node)
	_joy_base_node.visible = false

	_joy_knob_node = ColorRect.new()
	_joy_knob_node.color = Color(1.0, 1.0, 1.0, 0.35)
	_joy_knob_node.size  = Vector2(44.0, 44.0)
	_joy_knob_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_layer.add_child(_joy_knob_node)
	_joy_knob_node.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _game_over or _between_waves:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _joy_touch_idx == -1:
			_joy_touch_idx = event.index
			_joy_active    = true
			_joy_base_pos  = event.position
			_joy_knob_pos  = event.position
			_joy_base_node.position = _joy_base_pos - Vector2(JOY_RADIUS, JOY_RADIUS)
			_joy_base_node.visible  = true
			_joy_knob_node.visible  = true
		elif not event.pressed and event.index == _joy_touch_idx:
			_joy_active    = false
			_joy_touch_idx = -1
			_joy_base_node.visible  = false
			_joy_knob_node.visible  = false
			formation.set_move_input(Vector2.ZERO)
	elif event is InputEventScreenDrag and event.index == _joy_touch_idx:
		_joy_knob_pos = event.position
		var offset: Vector2 = _joy_knob_pos - _joy_base_pos
		if offset.length() > JOY_RADIUS:
			offset = offset.normalized() * JOY_RADIUS
		var knob_center := Vector2(22.0, 22.0)
		_joy_knob_node.position = _joy_base_pos + offset - knob_center
		formation.set_move_input(offset / JOY_RADIUS)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_joy_active   = true
			_joy_base_pos = event.position
			_joy_base_node.position = _joy_base_pos - Vector2(JOY_RADIUS, JOY_RADIUS)
			_joy_base_node.visible  = true
			_joy_knob_node.position = _joy_base_pos - Vector2(22, 22)
			_joy_knob_node.visible  = true
		else:
			_joy_active = false
			_joy_base_node.visible = false
			_joy_knob_node.visible = false
			formation.set_move_input(Vector2.ZERO)
	elif event is InputEventMouseMotion and _joy_active:
		var offset: Vector2 = event.position - _joy_base_pos
		if offset.length() > JOY_RADIUS:
			offset = offset.normalized() * JOY_RADIUS
		_joy_knob_node.position = _joy_base_pos + offset - Vector2(22, 22)
		formation.set_move_input(offset / JOY_RADIUS)


# ── Background ────────────────────────────────────────
func _draw_background() -> void:
	var vp: Vector2 = get_viewport_rect().size
	# Tiled grass using Kenney Tiny Battle tile
	var grass_tex := load("res://assets/sprites/tile_0000.png") as Texture2D
	var grass := Sprite2D.new()
	grass.texture = grass_tex
	grass.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	grass.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	grass.region_enabled = true
	grass.region_rect    = Rect2(0.0, 0.0, vp.x, vp.y)
	grass.position       = vp * 0.5
	grass.z_index        = -10
	world.add_child(grass)
	# Subtle dark overlay so HUD text stays readable
	var overlay := ColorRect.new()
	overlay.color    = Color(0.0, 0.0, 0.0, 0.22)
	overlay.size     = vp
	overlay.z_index  = -9
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(overlay)


# ── Helper ────────────────────────────────────────────
func _make_panel(sz: Vector2, pos: Vector2) -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color                   = GameConfig.COLOR_PANEL_BG
	style.corner_radius_top_left     = 16
	style.corner_radius_top_right    = 16
	style.corner_radius_bottom_left  = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left        = 16.0
	style.content_margin_right       = 16.0
	style.content_margin_top         = 16.0
	style.content_margin_bottom      = 16.0
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = sz
	panel.position = pos
	return panel
