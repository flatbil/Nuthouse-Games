extends Control

# -------------------------------------------------------
# RetirementScreen — shown when the player reaches age 65.
# Displays retirement tier, net worth, inheritance, and
# lets the player begin a new generation.
# -------------------------------------------------------

const _WHITE := Color(1.0, 1.0, 1.0, 1.0)
const _DIM   := Color(0.75, 0.75, 0.75, 0.85)


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var tier        := GameManager.get_retirement_tier()
	var net_worth   := GameManager.get_net_worth()
	var inheritance := GameManager.get_inheritance_amount()
	var tier_color  := tier["color"] as Color

	# Background — dark, subdued
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Scroll container so content fits all screen sizes
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.set("custom_minimum_size", Vector2(0, get_viewport_rect().size.y))
	scroll.add_child(vbox)

	# Top spacer
	_spacer(vbox, 48)

	# Header
	_add_label(vbox, "You've Retired", 16, _DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(vbox, "Age %d" % int(GameManager.START_AGE + GameManager.game_days / 365.0),
		13, _DIM, HORIZONTAL_ALIGNMENT_CENTER)

	_spacer(vbox, 12)

	# Tier badge
	var tier_lbl := _add_label(vbox, tier["name"], 42, tier_color, HORIZONTAL_ALIGNMENT_CENTER)
	tier_lbl.add_theme_color_override("font_shadow_color", Color(tier_color.r, tier_color.g, tier_color.b, 0.3))
	tier_lbl.add_theme_constant_override("shadow_offset_x", 0)
	tier_lbl.add_theme_constant_override("shadow_offset_y", 3)

	_add_label(vbox, tier["subtitle"], 17, tier_color.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)

	_spacer(vbox, 8)

	_add_label(vbox, tier["description"], 15, _DIM, HORIZONTAL_ALIGNMENT_CENTER)

	_spacer(vbox, 20)

	# Divider
	_add_label(vbox, "──────────────────────", 13, Color(0.3, 0.3, 0.3, 1), HORIZONTAL_ALIGNMENT_CENTER)

	_spacer(vbox, 16)

	# Net worth
	_add_label(vbox, "Final Net Worth", 13, _DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(vbox, "$%s" % _fmt(net_worth), 32, _WHITE, HORIZONTAL_ALIGNMENT_CENTER)

	_spacer(vbox, 20)

	# Inheritance section
	_add_label(vbox, "──────────────────────", 13, Color(0.3, 0.3, 0.3, 1), HORIZONTAL_ALIGNMENT_CENTER)
	_spacer(vbox, 16)

	if inheritance > 0.0:
		var pct := int(tier["inheritance_pct"] * 100.0)
		_add_label(vbox, "Estate passed to your child (%d%%)" % pct,
			13, _DIM, HORIZONTAL_ALIGNMENT_CENTER)
		_add_label(vbox, "$%s" % _fmt(inheritance), 32,
			Color(0.87, 0.70, 0.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		_add_label(vbox, "Your child begins life with a head start.", 14, _DIM, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_add_label(vbox, "Nothing to pass on.", 15, _DIM, HORIZONTAL_ALIGNMENT_CENTER)
		_add_label(vbox, "Your child starts from scratch.", 13, _DIM, HORIZONTAL_ALIGNMENT_CENTER)

	_spacer(vbox, 32)

	# Buttons
	var btn_box := VBoxContainer.new()
	btn_box.add_theme_constant_override("separation", 14)
	btn_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(btn_box)

	# Horizontal padding wrapper
	var h_pad := HBoxContainer.new()
	h_pad.add_theme_constant_override("separation", 0)
	btn_box.add_child(h_pad)
	_spacer_h(h_pad, 32)

	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 14)
	btn_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_pad.add_child(btn_vbox)
	_spacer_h(h_pad, 32)

	var new_life_btn := Button.new()
	new_life_btn.text = "Begin a New Life  →"
	new_life_btn.custom_minimum_size = Vector2(0, 58)
	new_life_btn.add_theme_font_size_override("font_size", 19)
	new_life_btn.add_theme_color_override("font_color", Color(0.87, 0.70, 0.0, 1.0))
	new_life_btn.pressed.connect(_on_new_life.bind(inheritance))
	btn_vbox.add_child(new_life_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Return to Menu"
	menu_btn.custom_minimum_size = Vector2(0, 48)
	menu_btn.add_theme_font_size_override("font_size", 16)
	menu_btn.add_theme_color_override("font_color", _DIM)
	menu_btn.pressed.connect(_on_menu)
	btn_vbox.add_child(menu_btn)

	_spacer(vbox, 48)


# -------------------------------------------------------
# Helpers
# -------------------------------------------------------

func _add_label(parent: Control, text: String, size: int,
		color: Color, align: HorizontalAlignment) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = align
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	return lbl


func _spacer(parent: Control, height: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)


func _spacer_h(parent: Control, width: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(width, 0)
	s.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(s)


# -------------------------------------------------------
# Actions
# -------------------------------------------------------

func _on_new_life(inheritance: float) -> void:
	GameManager.start_new_generation(inheritance)
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


# -------------------------------------------------------
# Formatting
# -------------------------------------------------------

func _fmt(n: float) -> String:
	if   n >= 1.0e33: return "%.2fDc" % (n / 1.0e33)
	elif n >= 1.0e30: return "%.2fNo" % (n / 1.0e30)
	elif n >= 1.0e27: return "%.2fOc" % (n / 1.0e27)
	elif n >= 1.0e24: return "%.2fSp" % (n / 1.0e24)
	elif n >= 1.0e21: return "%.2fSx" % (n / 1.0e21)
	elif n >= 1.0e18: return "%.2fQi" % (n / 1.0e18)
	elif n >= 1.0e15: return "%.2fQa" % (n / 1.0e15)
	elif n >= 1_000_000_000_000.0:
		return "%.2fT"  % (n / 1_000_000_000_000.0)
	elif n >= 1_000_000_000.0:
		return "%.2fB"  % (n / 1_000_000_000.0)
	elif n >= 1_000_000.0:
		return "%.2fM"  % (n / 1_000_000.0)
	elif n >= 1_000.0:
		return "%.1fK"  % (n / 1_000.0)
	else:
		return "%.2f"   % n
