extends Control

var _hoard_label: Label = null
var _btn_list:    Array = []


func _ready() -> void:
	EventBus.hoard_changed.connect(_on_hoard_changed)
	_build_ui()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = GameConfig.COLOR_DARK_BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.offset_top    = 80.0
	scroll.offset_bottom = -10.0
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(get_viewport_rect().size.x - 20.0, 0)
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# Header
	var header_bar := HBoxContainer.new()
	header_bar.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	header_bar.custom_minimum_size = Vector2(0, 70)
	add_child(header_bar)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.custom_minimum_size = Vector2(90, 60)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(func(): SceneTransition.go_to("res://scenes/MainMenu.tscn"))
	header_bar.add_child(back_btn)

	var title := Label.new()
	title.text = "THE HOARD"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", GameConfig.COLOR_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	header_bar.add_child(title)

	_hoard_label = Label.new()
	_hoard_label.text = "Gold: %d" % GameManager.hoard
	_hoard_label.add_theme_font_size_override("font_size", 18)
	_hoard_label.add_theme_color_override("font_color", GameConfig.COLOR_GOLD)
	_hoard_label.custom_minimum_size = Vector2(110, 60)
	_hoard_label.vertical_alignment  = VERTICAL_ALIGNMENT_CENTER
	_hoard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_bar.add_child(_hoard_label)

	# Upgrade buttons
	for i in range(GameConfig.META_UPGRADES.size()):
		var btn := _make_upgrade_btn(i)
		vbox.add_child(btn)
		_btn_list.append(btn)

	_refresh_buttons()


func _make_upgrade_btn(index: int) -> Button:
	var u: Dictionary = GameConfig.META_UPGRADES[index]
	var btn := Button.new()
	btn.name = "MetaUpgrade_%d" % index
	btn.custom_minimum_size = Vector2(0, 72)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.pressed.connect(_on_buy.bind(index))
	return btn


func _refresh_buttons() -> void:
	for i in range(_btn_list.size()):
		var btn: Button = _btn_list[i]
		var u: Dictionary  = GameConfig.META_UPGRADES[i]
		var level: int     = GameManager.meta_levels.get(u["id"], 0)
		var max_lvl: int   = int(u["max_level"])
		var cost: int      = int(u["cost"])
		if level >= max_lvl:
			btn.text     = "✓ %s  [MAX]\n%s" % [u["name"], u["desc"]]
			btn.disabled = true
			btn.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
		else:
			var lvl_str: String = " (Lv %d/%d)" % [level, max_lvl] if max_lvl > 1 else ""
			btn.text     = "%s%s — %d gold\n%s" % [u["name"], lvl_str, cost, u["desc"]]
			btn.disabled = not GameManager.can_buy_meta(i)
			btn.add_theme_color_override("font_color",
				GameConfig.COLOR_GOLD if not btn.disabled else Color(0.5, 0.5, 0.5))


func _on_buy(index: int) -> void:
	GameManager.buy_meta(index)
	_refresh_buttons()


func _on_hoard_changed(total: int) -> void:
	if is_instance_valid(_hoard_label):
		_hoard_label.text = "Gold: %d" % total
	_refresh_buttons()
