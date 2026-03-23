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
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

	var _blue      := Color(0.20, 0.45, 0.85, 1.0)
	var _blue_dim  := Color(0.12, 0.26, 0.50, 1.0)
	var btn_loadout := _make_styled_btn("⚙  LOADOUT", _blue, _blue_dim, Color.WHITE, 20, 58)
	btn_loadout.pressed.connect(_show_loadout_panel)
	vbox.add_child(btn_loadout)

	var _orange     := Color(0.75, 0.38, 0.08, 1.0)
	var _orange_dim := Color(0.45, 0.22, 0.04, 1.0)
	var btn_forge := _make_styled_btn("⚒  FORGE", _orange, _orange_dim, Color.WHITE, 20, 58)
	btn_forge.pressed.connect(_show_forge_panel)
	vbox.add_child(btn_forge)

	if OS.is_debug_build():
		var btn_reset := _make_styled_btn("[D] Reset Save", Color(0.8, 0.3, 0.3), _RED_DIM, Color.WHITE, 16, 44)
		btn_reset.pressed.connect(func():
			SaveManager.delete_save()
			GameManager.reset()
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


# ── Loadout panel ─────────────────────────────────────────

var _loadout_panel: Control = null

func _show_loadout_panel() -> void:
	if is_instance_valid(_loadout_panel):
		return
	var vp: Vector2 = get_viewport_rect().size

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.08, 0.97)
	style.corner_radius_top_left     = 18
	style.corner_radius_top_right    = 18
	style.corner_radius_bottom_left  = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left   = 18.0
	style.content_margin_right  = 18.0
	style.content_margin_top    = 18.0
	style.content_margin_bottom = 18.0
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.position = Vector2(vp.x * 0.5 - 150, vp.y * 0.1)
	dim.add_child(panel)
	_loadout_panel = dim

	var vbox2 := VBoxContainer.new()
	vbox2.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vbox2.add_theme_constant_override("separation", 10)
	panel.add_child(vbox2)

	var title := Label.new()
	title.text = "LOADOUT — SELECT WEAPON"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", _GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox2.add_child(title)

	var equipped: String = GameManager.hero_weapon
	for wid in GameConfig.WEAPONS.keys():
		var w: Dictionary = GameConfig.WEAPONS[wid]
		var owned: bool = GameManager.weapon_inventory.has(wid)
		var is_equipped: bool = (wid == equipped)

		var rarity_color: Color = GameConfig.RARITY_COLORS.get(w["rarity"], Color.WHITE)
		var btn_color: Color = rarity_color if owned else Color(0.3, 0.3, 0.3)
		var btn_dim: Color   = btn_color.darkened(0.3)

		var btn := _make_styled_btn(
			("%s  [%s]%s" % [w["display_name"], w["rarity"].to_upper(),
							  "  ✓ EQUIPPED" if is_equipped else ("" if owned else "  🔒")]),
			btn_color, btn_dim, Color.WHITE if owned else Color(0.5, 0.5, 0.5), 16, 52)
		btn.disabled = not owned
		if owned and not is_equipped:
			btn.pressed.connect(func():
				GameManager.equip_weapon(wid)
				_close_loadout_panel()
				_show_loadout_panel())
		elif owned and is_equipped:
			pass  # already equipped, no action
		vbox2.add_child(btn)

	var stat_lbl := Label.new()
	var w_eq: Dictionary = GameConfig.WEAPONS.get(equipped, {})
	stat_lbl.text = "[%s]\n%s" % [w_eq.get("display_name", ""), w_eq.get("desc", "")]
	stat_lbl.add_theme_font_size_override("font_size", 14)
	stat_lbl.add_theme_color_override("font_color", Color(0.80, 0.78, 0.60))
	stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox2.add_child(stat_lbl)

	var close_btn := _make_styled_btn("Close", Color(0.4, 0.4, 0.4), Color(0.25, 0.25, 0.25), Color.WHITE, 18, 52)
	close_btn.pressed.connect(_close_loadout_panel)
	vbox2.add_child(close_btn)


func _close_loadout_panel() -> void:
	if is_instance_valid(_loadout_panel):
		_loadout_panel.queue_free()
		_loadout_panel = null


var _forge_panel: Control = null


func _show_forge_panel() -> void:
	if is_instance_valid(_forge_panel):
		return
	var vp: Vector2 = get_viewport_rect().size

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_forge_panel = dim

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.06, 0.97)
	style.corner_radius_top_left     = 18
	style.corner_radius_top_right    = 18
	style.corner_radius_bottom_left  = 18
	style.corner_radius_bottom_right = 18
	style.content_margin_left   = 18.0
	style.content_margin_right  = 18.0
	style.content_margin_top    = 16.0
	style.content_margin_bottom = 16.0
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(310, 0)
	panel.position = Vector2(vp.x * 0.5 - 155.0, vp.y * 0.06)
	dim.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(310, vp.y * 0.86)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# ── Title ────────────────────────────────────────────
	var title := Label.new()
	title.text = "⚒  FORGE"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.55, 0.10))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var gems_lbl := Label.new()
	gems_lbl.text = "♦ %d gems available" % GameManager.gems
	gems_lbl.add_theme_font_size_override("font_size", 15)
	gems_lbl.add_theme_color_override("font_color", Color(0.30, 0.60, 1.00))
	gems_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(gems_lbl)

	vbox.add_child(HSeparator.new())

	# ── Uniform section ──────────────────────────────────
	var uni_lbl := Label.new()
	var tier: String = GameConfig.UNIFORM_TIER_NAMES[GameManager.uniform_level]
	var tier_color: Color = GameConfig.UNIFORM_TIER_COLORS[tier]
	uni_lbl.text = "UNIFORM — %s  (Lv %d / %d)" % [tier, GameManager.uniform_level, GameConfig.UNIFORM_MAX_LEVEL]
	uni_lbl.add_theme_font_size_override("font_size", 16)
	uni_lbl.add_theme_color_override("font_color", tier_color)
	uni_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	uni_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(uni_lbl)

	var uni_stats := Label.new()
	uni_stats.text = "+%d HP   +%d%% DMG   +%d%% SPD" % [
		GameConfig.uniform_hp_bonus(GameManager.uniform_level),
		int(GameConfig.uniform_damage_mult(GameManager.uniform_level) * 100.0) - 100,
		int(GameConfig.uniform_speed_mult(GameManager.uniform_level) * 100.0) - 100,
	]
	uni_stats.add_theme_font_size_override("font_size", 14)
	uni_stats.add_theme_color_override("font_color", Color(0.80, 0.78, 0.60))
	uni_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(uni_stats)

	if GameManager.uniform_level < GameConfig.UNIFORM_MAX_LEVEL:
		var cost: int = GameConfig.uniform_upgrade_cost(GameManager.uniform_level)
		var can_up: bool = GameManager.can_upgrade_uniform()
		var up_color: Color = Color(0.25, 0.75, 0.35) if can_up else Color(0.40, 0.40, 0.40)
		var up_dim:   Color = up_color.darkened(0.35)
		var btn_up := _make_styled_btn(
			"Upgrade Uniform  (♦ %d gems)" % cost,
			up_color, up_dim, Color.WHITE, 15, 48)
		btn_up.disabled = not can_up
		btn_up.pressed.connect(func():
			GameManager.upgrade_uniform()
			_close_forge_panel()
			_show_forge_panel())
		vbox.add_child(btn_up)
	else:
		var max_lbl := Label.new()
		max_lbl.text = "UNIFORM MAXED OUT"
		max_lbl.add_theme_color_override("font_color", GameConfig.UNIFORM_TIER_COLORS["Officer"])
		max_lbl.add_theme_font_size_override("font_size", 14)
		max_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(max_lbl)

	vbox.add_child(HSeparator.new())

	# ── Weapon combining section ─────────────────────────
	var craft_title := Label.new()
	craft_title.text = "WEAPON FORGE"
	craft_title.add_theme_font_size_override("font_size", 16)
	craft_title.add_theme_color_override("font_color", Color(0.85, 0.55, 0.10))
	craft_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(craft_title)

	var next_rarity_map: Dictionary = {
		"common": "rare", "rare": "epic", "epic": "legendary"
	}

	for rarity in ["common", "rare", "epic"]:
		var count: int = GameManager._count_rarity(rarity)
		var rarity_color: Color = GameConfig.RARITY_COLORS[rarity]
		var next_r: String = next_rarity_map[rarity]
		var next_color: Color = GameConfig.RARITY_COLORS[next_r]

		# List owned weapons of this rarity
		var inv_text: String = ""
		for wid in GameManager.weapon_inventory.keys():
			if GameConfig.WEAPONS.has(wid) and GameConfig.WEAPONS[wid]["rarity"] == rarity:
				var cnt: int = GameManager.weapon_inventory[wid]
				inv_text += "%s ×%d   " % [GameConfig.WEAPONS[wid]["display_name"], cnt]

		if inv_text.is_empty():
			inv_text = "(none)"

		var row_lbl := Label.new()
		row_lbl.text = "[%s]  %s" % [rarity.to_upper(), inv_text.strip_edges()]
		row_lbl.add_theme_font_size_override("font_size", 13)
		row_lbl.add_theme_color_override("font_color", rarity_color)
		row_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(row_lbl)

		var can_c: bool = GameManager.can_combine(rarity)
		var btn_color: Color = next_color if can_c else Color(0.35, 0.35, 0.35)
		var btn_dim:   Color = btn_color.darkened(0.4)
		var btn_c := _make_styled_btn(
			"Combine 3× %s → 1× %s  (%d/3)" % [rarity.capitalize(), next_r.capitalize(), count],
			btn_color, btn_dim, Color.WHITE, 14, 46)
		btn_c.disabled = not can_c
		btn_c.pressed.connect(func():
			var _gained: String = GameManager.combine_weapons(rarity)
			_close_forge_panel()
			_show_forge_panel())
		vbox.add_child(btn_c)

	# Legendary — just show count, no combine
	var leg_count: int = GameManager._count_rarity("legendary")
	if leg_count > 0:
		var leg_lbl := Label.new()
		leg_lbl.text = "[LEGENDARY]  "
		for wid in GameManager.weapon_inventory.keys():
			if GameConfig.WEAPONS.has(wid) and GameConfig.WEAPONS[wid]["rarity"] == "legendary":
				leg_lbl.text += "%s ×%d" % [GameConfig.WEAPONS[wid]["display_name"], GameManager.weapon_inventory[wid]]
		leg_lbl.add_theme_font_size_override("font_size", 13)
		leg_lbl.add_theme_color_override("font_color", GameConfig.RARITY_COLORS["legendary"])
		leg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(leg_lbl)

	vbox.add_child(HSeparator.new())

	var close_btn := _make_styled_btn("Close", Color(0.35, 0.35, 0.35), Color(0.20, 0.20, 0.20), Color.WHITE, 18, 50)
	close_btn.pressed.connect(_close_forge_panel)
	vbox.add_child(close_btn)


func _close_forge_panel() -> void:
	if is_instance_valid(_forge_panel):
		_forge_panel.queue_free()
		_forge_panel = null
