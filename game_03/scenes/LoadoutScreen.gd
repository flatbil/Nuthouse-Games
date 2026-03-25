extends Control

const _GOLD     := Color(0.87, 0.70, 0.00, 1.0)
const _GOLD_DIM := Color(0.55, 0.42, 0.00, 1.0)

const _SHOT_LABELS: Dictionary = {
	"single":      "Single shot",
	"scatter":     "Scatter shot",
	"dual":        "Dual shot",
	"penetrating": "Piercing shot",
}
const _SHOT_COLORS: Dictionary = {
	"single":      Color(0.75, 0.75, 0.75),
	"scatter":     Color(0.85, 0.55, 0.10),
	"dual":        Color(0.30, 0.75, 0.95),
	"penetrating": Color(0.75, 0.20, 0.95),
}


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
	title.text = "LOADOUT"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", _GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	# Spacer to balance back button
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(90, 0)
	header.add_child(spacer)

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

	var sub_lbl := Label.new()
	sub_lbl.text = "Select a weapon for your Captain"
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", Color(0.65, 0.62, 0.48))
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_lbl)

	var div := ColorRect.new()
	div.color = Color(_GOLD.r, _GOLD.g, _GOLD.b, 0.35)
	div.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(div)

	var equipped: String = GameManager.hero_weapon

	for wid in GameConfig.WEAPONS.keys():
		var w: Dictionary  = GameConfig.WEAPONS[wid]
		var in_arsenal: bool  = GameManager.weapon_arsenal.has(wid)
		var is_equipped: bool = (wid == equipped)
		var lv: int           = GameManager.weapon_levels.get(wid, 0)
		var shot_type: String = str(w.get("shot_type", "single"))

		# Card
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.20, 0.24, 0.14, 0.95) if is_equipped \
			else (Color(0.16, 0.18, 0.12, 0.90) if in_arsenal else Color(0.11, 0.12, 0.09, 0.70))
		if is_equipped:
			card_style.border_color        = _GOLD
			card_style.border_width_top    = 1
			card_style.border_width_bottom = 1
			card_style.border_width_left   = 1
			card_style.border_width_right  = 1
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

		# Name row
		var name_row := HBoxContainer.new()
		cvbox.add_child(name_row)

		var name_lbl := Label.new()
		var marks: String = ("  ✓ EQUIPPED" if is_equipped else "") + ("  🔒" if not in_arsenal else "")
		name_lbl.text = "%s%s" % [w["display_name"], marks]
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color",
			_GOLD if is_equipped else (Color(0.85, 0.80, 0.60) if in_arsenal else Color(0.40, 0.40, 0.36)))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_row.add_child(name_lbl)

		if lv > 0:
			var lv_lbl := Label.new()
			lv_lbl.text = "Lv %d" % lv
			lv_lbl.add_theme_font_size_override("font_size", 14)
			lv_lbl.add_theme_color_override("font_color", Color(0.85, 0.55, 0.10))
			name_row.add_child(lv_lbl)

		# Shot type
		var type_lbl := Label.new()
		type_lbl.text = _SHOT_LABELS.get(shot_type, shot_type)
		type_lbl.add_theme_font_size_override("font_size", 13)
		type_lbl.add_theme_color_override("font_color",
			_SHOT_COLORS.get(shot_type, Color.WHITE) if in_arsenal else Color(0.35, 0.35, 0.32))
		cvbox.add_child(type_lbl)

		if in_arsenal:
			var dmg_v: float   = GameConfig.weapon_stat(wid, "damage",    lv)
			var rate_v: float  = GameConfig.weapon_stat(wid, "fire_rate", lv)
			var range_v: float = GameConfig.weapon_stat(wid, "range",     lv)
			var stats_lbl := Label.new()
			stats_lbl.text = "DMG %.1f   %.2f shots/s   RNG %d px" % [dmg_v, 1.0 / rate_v, int(range_v)]
			stats_lbl.add_theme_font_size_override("font_size", 13)
			stats_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.58))
			cvbox.add_child(stats_lbl)

			var desc_lbl := Label.new()
			desc_lbl.text = str(w.get("desc", ""))
			desc_lbl.add_theme_font_size_override("font_size", 13)
			desc_lbl.add_theme_color_override("font_color", Color(0.58, 0.56, 0.44))
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cvbox.add_child(desc_lbl)

			if not is_equipped:
				var equip_btn := UIFactory.make_styled_btn(
					"Equip", Color(0.20, 0.45, 0.85), Color(0.12, 0.26, 0.50),
					Color.WHITE, 15, 42)
				equip_btn.pressed.connect(func():
					GameManager.equip_weapon(wid)
					SceneTransition.go_to("res://scenes/LoadoutScreen.tscn"))
				cvbox.add_child(equip_btn)
