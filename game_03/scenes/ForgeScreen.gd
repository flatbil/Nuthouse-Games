extends Control

const _GOLD     := Color(0.87, 0.70, 0.00, 1.0)
const _ORANGE   := Color(0.85, 0.55, 0.10, 1.0)

var _gems_label: Label = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var vp: Vector2 = get_viewport_rect().size

	var bg := ColorRect.new()
	bg.color = GameConfig.COLOR_DARK_BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	# ── Header ────────────────────────────────────────────
	var header := HBoxContainer.new()
	header.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	header.custom_minimum_size = Vector2(0, 70)
	add_child(header)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.custom_minimum_size = Vector2(90, 60)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(func(): SceneTransition.go_to("res://scenes/MainMenu.tscn"))
	header.add_child(back_btn)

	var title := Label.new()
	title.text = "⚒  FORGE"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", _ORANGE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	_gems_label = Label.new()
	_gems_label.text = "♦ %d" % GameManager.gems
	_gems_label.add_theme_font_size_override("font_size", 18)
	_gems_label.add_theme_color_override("font_color", Color(0.30, 0.60, 1.00))
	_gems_label.custom_minimum_size  = Vector2(90, 60)
	_gems_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_gems_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_gems_label)

	# ── Scrollable content ────────────────────────────────
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.offset_top    = 75.0
	scroll.offset_bottom = -UIFactory.safe_bottom() - 10.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(vp.x - 32.0, 0)
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# ── Uniform section ───────────────────────────────────
	var uni_header := Label.new()
	var tier: String      = GameConfig.UNIFORM_TIER_NAMES[GameManager.uniform_level]
	var tier_color: Color = GameConfig.UNIFORM_TIER_COLORS[tier]
	uni_header.text = "UNIFORM — %s  (Lv %d / %d)" % [tier, GameManager.uniform_level, GameConfig.UNIFORM_MAX_LEVEL]
	uni_header.add_theme_font_size_override("font_size", 17)
	uni_header.add_theme_color_override("font_color", tier_color)
	uni_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	uni_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(uni_header)

	var uni_stats := Label.new()
	uni_stats.text = "+%d HP   +%d%% DMG   +%d%% SPD" % [
		GameConfig.uniform_hp_bonus(GameManager.uniform_level),
		int(GameConfig.uniform_damage_mult(GameManager.uniform_level) * 100.0) - 100,
		int(GameConfig.uniform_speed_mult(GameManager.uniform_level) * 100.0) - 100,
	]
	uni_stats.add_theme_font_size_override("font_size", 14)
	uni_stats.add_theme_color_override("font_color", Color(0.75, 0.72, 0.55))
	uni_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(uni_stats)

	if GameManager.uniform_level < GameConfig.UNIFORM_MAX_LEVEL:
		var cost: int    = GameConfig.uniform_upgrade_cost(GameManager.uniform_level)
		var can_up: bool = GameManager.can_upgrade_uniform()
		var up_col: Color = Color(0.25, 0.75, 0.35) if can_up else Color(0.35, 0.35, 0.35)
		var btn_up := UIFactory.make_styled_btn(
			"Upgrade Uniform  (♦ %d gems)" % cost,
			up_col, up_col.darkened(0.35), Color.WHITE, 15, 50)
		btn_up.disabled = not can_up
		btn_up.pressed.connect(func():
			GameManager.upgrade_uniform()
			SceneTransition.go_to("res://scenes/ForgeScreen.tscn"))
		vbox.add_child(btn_up)
	else:
		var max_lbl := Label.new()
		max_lbl.text = "✓ UNIFORM MAXED OUT"
		max_lbl.add_theme_color_override("font_color", GameConfig.UNIFORM_TIER_COLORS["Officer"])
		max_lbl.add_theme_font_size_override("font_size", 14)
		max_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(max_lbl)

	vbox.add_child(_divider())

	# ── Weapon forge section ──────────────────────────────
	var forge_header := Label.new()
	forge_header.text = "WEAPON FORGE"
	forge_header.add_theme_font_size_override("font_size", 17)
	forge_header.add_theme_color_override("font_color", _ORANGE)
	forge_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(forge_header)

	var hint := Label.new()
	hint.text = "Collect 3 copies of a weapon to upgrade it (max Lv 3)"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.58, 0.56, 0.44))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)

	var any_shown: bool = false
	for wid in GameConfig.WEAPONS.keys():
		if not GameManager.weapon_arsenal.has(wid):
			continue
		any_shown = true
		var w: Dictionary = GameConfig.WEAPONS[wid]
		var lv: int       = GameManager.weapon_levels.get(wid, 0)
		var copies: int   = GameManager.weapon_inventory.get(wid, 0)
		var maxed: bool   = lv >= GameConfig.WEAPON_MAX_LEVEL
		var can_up: bool  = GameManager.can_upgrade_weapon(wid)

		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.15, 0.16, 0.11, 0.90)
		card_style.corner_radius_top_left     = 10
		card_style.corner_radius_top_right    = 10
		card_style.corner_radius_bottom_left  = 10
		card_style.corner_radius_bottom_right = 10
		card_style.content_margin_left   = 14.0
		card_style.content_margin_right  = 14.0
		card_style.content_margin_top    = 12.0
		card_style.content_margin_bottom = 12.0
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", card_style)
		vbox.add_child(card)

		var cvbox := VBoxContainer.new()
		cvbox.add_theme_constant_override("separation", 5)
		card.add_child(cvbox)

		var name_row := HBoxContainer.new()
		cvbox.add_child(name_row)

		var name_lbl := Label.new()
		name_lbl.text = w["display_name"]
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.add_theme_color_override("font_color", _GOLD)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_row.add_child(name_lbl)

		var lv_lbl := Label.new()
		lv_lbl.text = "MAX" if maxed else "Lv %d / %d" % [lv, GameConfig.WEAPON_MAX_LEVEL]
		lv_lbl.add_theme_font_size_override("font_size", 14)
		lv_lbl.add_theme_color_override("font_color",
			Color(1.00, 0.75, 0.00) if maxed else _ORANGE)
		name_row.add_child(lv_lbl)

		if not maxed:
			var prog := Label.new()
			prog.text = "Forge copies: %d / %d" % [copies, GameConfig.WEAPON_UPGRADE_COST]
			prog.add_theme_font_size_override("font_size", 13)
			prog.add_theme_color_override("font_color",
				Color(0.35, 0.80, 0.45) if can_up else Color(0.55, 0.55, 0.45))
			cvbox.add_child(prog)

			var up_col: Color = _ORANGE if can_up else Color(0.35, 0.35, 0.30)
			var btn_up := UIFactory.make_styled_btn(
				"Forge  (%d copies → Lv %d)" % [GameConfig.WEAPON_UPGRADE_COST, lv + 1],
				up_col, up_col.darkened(0.4), Color.WHITE, 14, 44)
			btn_up.disabled = not can_up
			btn_up.pressed.connect(func():
				GameManager.upgrade_weapon(wid)
				SceneTransition.go_to("res://scenes/ForgeScreen.tscn"))
			cvbox.add_child(btn_up)

	if not any_shown:
		var none_lbl := Label.new()
		none_lbl.text = "Find weapons in battle to unlock forging."
		none_lbl.add_theme_font_size_override("font_size", 14)
		none_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.45))
		none_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(none_lbl)


func _divider() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(1.0, 1.0, 1.0, 0.10)
	d.custom_minimum_size = Vector2(0, 1)
	return d
