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
	# ── Gradient background ───────────────────────────────
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.05, 1.0)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Subtle vignette overlay
	var vignette := ColorRect.new()
	vignette.color = Color(0.0, 0.0, 0.0, 0.35)
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

	# ── Title block ───────────────────────────────────────
	var title := Label.new()
	title.text = GameConfig.GAME_TITLE
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", _GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title)

	# Gold divider
	var divider := ColorRect.new()
	divider.color = Color(_GOLD.r, _GOLD.g, _GOLD.b, 0.55)
	divider.custom_minimum_size = Vector2(0, 2)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(divider)

	var subtitle := Label.new()
	subtitle.text = "— War of 1812 —"
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.68, 0.46, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(subtitle)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

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
	_play_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	vbox.add_child(_play_btn)

	var btn_upgrades := _make_styled_btn("★  THE HOARD", _GREEN, _GREEN_DIM, _TEXT_DARK, 20, 58)
	btn_upgrades.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/UpgradeScreen.tscn"))
	vbox.add_child(btn_upgrades)

	if OS.is_debug_build():
		var btn_reset := _make_styled_btn("[D] Reset Save", Color(0.8, 0.3, 0.3), _RED_DIM, Color.WHITE, 16, 44)
		btn_reset.pressed.connect(func():
			SaveManager.delete_save()
			get_tree().reload_current_scene())
		vbox.add_child(btn_reset)


# ── Styled button factory ─────────────────────────────────

func _make_styled_btn(text: String, color: Color, hover_color: Color,
		font_color: Color, font_size: int, height: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, height)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", font_color)

	var style := _btn_style(color, 16)
	var style_hover := _btn_style(hover_color.lightened(0.15), 16)
	style_hover.border_color = color.lightened(0.3)
	style_hover.border_width_bottom = 3
	style_hover.border_width_top    = 3
	style_hover.border_width_left   = 3
	style_hover.border_width_right  = 3
	var style_pressed := _btn_style(color.darkened(0.25), 16)

	btn.add_theme_stylebox_override("normal",  style)
	btn.add_theme_stylebox_override("hover",   style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	# Scale pop on press
	btn.button_down.connect(func():
		var t := btn.create_tween()
		t.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.07).set_trans(Tween.TRANS_SINE))
	btn.button_up.connect(func():
		var t := btn.create_tween()
		t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BOUNCE))

	return btn


func _btn_style(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color                   = color
	s.corner_radius_top_left     = radius
	s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left        = 16.0
	s.content_margin_right       = 16.0
	s.content_margin_top         = 8.0
	s.content_margin_bottom      = 8.0
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	s.shadow_size  = 8
	s.shadow_offset = Vector2(0, 3)
	return s


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
