extends Control

const _GOLD        := Color(0.87, 0.70, 0.00, 1.0)
const _GOLD_DIM    := Color(0.55, 0.42, 0.00, 1.0)
const _GREEN       := Color(0.40, 0.72, 0.42, 1.0)
const _GREEN_DIM   := Color(0.22, 0.42, 0.24, 1.0)
const _RED_DIM     := Color(0.50, 0.12, 0.12, 1.0)
const _TEXT_DARK   := Color(0.08, 0.07, 0.04, 1.0)
const _PANEL_BG    := Color(0.10, 0.12, 0.08, 1.0)

var _play_btn: Button = null


func _ready() -> void:
	_build_ui()
	# Animate play button pulse after a short delay
	await get_tree().create_timer(0.4).timeout
	_pulse_play_btn()


func _build_ui() -> void:
	# ── Background ────────────────────────────────────────
	_build_background()

	# ── Vignette over background ──────────────────────────
	var vignette := ColorRect.new()
	vignette.color = Color(0.0, 0.0, 0.0, 0.52)
	vignette.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	# ── Decorative top bar ────────────────────────────────
	var top_bar := ColorRect.new()
	top_bar.color = Color(_GOLD.r, _GOLD.g, _GOLD.b, 0.18)
	top_bar.set_anchors_preset(PRESET_TOP_WIDE)
	top_bar.offset_bottom = 3.0
	top_bar.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)

	var bot_bar := ColorRect.new()
	bot_bar.color = Color(_GOLD.r, _GOLD.g, _GOLD.b, 0.18)
	bot_bar.set_anchors_preset(PRESET_BOTTOM_WIDE)
	bot_bar.offset_top    = -3.0
	bot_bar.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(bot_bar)

	# ── Main layout ───────────────────────────────────────
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vbox.offset_left   = 32.0
	vbox.offset_right  = -32.0
	vbox.offset_top    = 60.0
	vbox.offset_bottom = -50.0
	vbox.alignment     = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	add_child(vbox)

	# ── Stats pill ────────────────────────────────────────
	if GameManager.total_runs > 0:
		var stats_panel := _make_pill()
		vbox.add_child(stats_panel)
		var stats := Label.new()
		stats.text = "Best Wave: %d     Hoard: %d gold" % [GameManager.best_wave, GameManager.hoard]
		stats.add_theme_font_size_override("font_size", 14)
		stats.add_theme_color_override("font_color", Color(0.80, 0.78, 0.60, 1.0))
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stats_panel.add_child(stats)

	# ── Buttons ───────────────────────────────────────────
	_play_btn = _make_styled_btn("⚔  MARCH TO BATTLE", _GOLD, _GOLD_DIM, _TEXT_DARK, 24, 68)
	_play_btn.pressed.connect(func(): SceneTransition.go_to("res://scenes/Game.tscn"))
	vbox.add_child(_play_btn)

	var btn_upgrades := _make_styled_btn("★  THE HOARD", _GREEN, _GREEN_DIM, _TEXT_DARK, 20, 58)
	btn_upgrades.pressed.connect(func(): SceneTransition.go_to("res://scenes/UpgradeScreen.tscn"))
	vbox.add_child(btn_upgrades)

	var _blue      := Color(0.20, 0.45, 0.85, 1.0)
	var _blue_dim  := Color(0.12, 0.26, 0.50, 1.0)
	var btn_loadout := _make_styled_btn("⚙  LOADOUT", _blue, _blue_dim, Color.WHITE, 20, 58)
	btn_loadout.pressed.connect(func(): SceneTransition.go_to("res://scenes/LoadoutScreen.tscn"))
	vbox.add_child(btn_loadout)

	var _orange     := Color(0.75, 0.38, 0.08, 1.0)
	var _orange_dim := Color(0.45, 0.22, 0.04, 1.0)
	var btn_forge := _make_styled_btn("⚒  FORGE", _orange, _orange_dim, Color.WHITE, 20, 58)
	btn_forge.pressed.connect(func(): SceneTransition.go_to("res://scenes/ForgeScreen.tscn"))
	vbox.add_child(btn_forge)

	if OS.is_debug_build():
		var btn_reset := _make_styled_btn("[D] Reset Save", Color(0.8, 0.3, 0.3), _RED_DIM, Color.WHITE, 16, 44)
		btn_reset.pressed.connect(func():
			SaveManager.delete_save()
			GameManager.reset()
			get_tree().reload_current_scene())
		vbox.add_child(btn_reset)


# ── Background ────────────────────────────────────────────

func _build_background() -> void:
	var vp: Vector2 = get_viewport_rect().size

	# Solid fallback — always visible even if texture fails to load
	var bg_solid := ColorRect.new()
	bg_solid.color = Color(0.07, 0.09, 0.05, 1.0)
	bg_solid.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg_solid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_solid)

	# Splash image, dimmed — safe load
	var tex = load("res://assets/splash.png")
	if tex != null:
		var bg_tex := TextureRect.new()
		bg_tex.texture      = tex
		bg_tex.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_tex.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		bg_tex.modulate     = Color(0.55, 0.50, 0.42, 1.0)
		bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg_tex)

	# Smoke — thick billowing clouds rising from the bottom
	var smoke := CPUParticles2D.new()
	smoke.position             = Vector2(vp.x * 0.5, vp.y + 30.0)
	smoke.emitting             = true
	smoke.amount               = 40
	smoke.lifetime             = 7.0
	smoke.explosiveness        = 0.0
	smoke.randomness           = 0.9
	smoke.direction            = Vector2(0.0, -1.0)
	smoke.spread               = 88.0
	smoke.gravity              = Vector2.ZERO
	smoke.initial_velocity_min = 22.0
	smoke.initial_velocity_max = 55.0
	smoke.angular_velocity_min = -15.0
	smoke.angular_velocity_max =  15.0
	smoke.scale_amount_min     = 40.0
	smoke.scale_amount_max     = 80.0
	var smoke_grad := Gradient.new()
	smoke_grad.set_color(0, Color(0.78, 0.68, 0.50, 0.0))
	smoke_grad.set_color(1, Color(0.35, 0.28, 0.20, 0.0))
	smoke_grad.add_point(0.12, Color(0.78, 0.68, 0.50, 0.55))
	smoke_grad.add_point(0.55, Color(0.58, 0.50, 0.38, 0.35))
	smoke.color_ramp = smoke_grad
	add_child(smoke)

	# Embers — bright sparks drifting upward
	var embers := CPUParticles2D.new()
	embers.position             = Vector2(vp.x * 0.5, vp.y + 10.0)
	embers.emitting             = true
	embers.amount               = 55
	embers.lifetime             = 4.5
	embers.explosiveness        = 0.0
	embers.randomness           = 1.0
	embers.direction            = Vector2(0.0, -1.0)
	embers.spread               = 90.0
	embers.gravity              = Vector2(-6.0, -18.0)
	embers.initial_velocity_min = 50.0
	embers.initial_velocity_max = 130.0
	embers.scale_amount_min     = 3.0
	embers.scale_amount_max     = 6.5
	var ember_grad := Gradient.new()
	ember_grad.set_color(0, Color(1.0, 0.90, 0.40, 0.0))
	ember_grad.set_color(1, Color(0.70, 0.10, 0.02, 0.0))
	ember_grad.add_point(0.06, Color(1.0, 0.85, 0.20, 1.0))
	ember_grad.add_point(0.45, Color(1.0, 0.45, 0.05, 0.80))
	embers.color_ramp = ember_grad
	add_child(embers)


# ── Styled button factory — delegates to shared UIFactory ──

func _make_styled_btn(text: String, color: Color, hover_color: Color,
		font_color: Color, font_size: int, height: int) -> Button:
	return UIFactory.make_styled_btn(text, color, hover_color, font_color, font_size, height)


func _btn_style(color: Color, radius: int) -> StyleBoxFlat:
	return UIFactory.make_btn_style(color, radius)


func _make_pill() -> PanelContainer:
	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(1.0, 1.0, 1.0, 0.06)
	style.corner_radius_top_left     = 20
	style.corner_radius_top_right    = 20
	style.corner_radius_bottom_left  = 20
	style.corner_radius_bottom_right = 20
	style.content_margin_left        = 20.0
	style.content_margin_right       = 20.0
	style.content_margin_top         = 8.0
	style.content_margin_bottom      = 8.0
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	return panel


# ── Play button idle pulse ─────────────────────────────────

func _pulse_play_btn() -> void:
	if not is_instance_valid(_play_btn):
		return
	var tween := create_tween().set_loops()
	tween.tween_property(_play_btn, "scale", Vector2(1.03, 1.03), 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_play_btn, "scale", Vector2(1.00, 1.00), 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
