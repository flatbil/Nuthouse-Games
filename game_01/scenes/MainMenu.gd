extends Control

# -------------------------------------------------------
# MainMenu — Title screen. Continue / New Game / Credits.
# -------------------------------------------------------

const _MONEY_GREEN := Color(0.106, 0.369, 0.125, 1.0)
const _GOLD        := Color(0.87,  0.70,  0.0,   1.0)


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Background — matches game's mint green
	var bg := ColorRect.new()
	bg.color = Color(0.937, 0.984, 0.937, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Title
	var title := Label.new()
	title.text = "COMPOUND"
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", _MONEY_GREEN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left   = 0.0
	title.anchor_right  = 1.0
	title.anchor_top    = 0.20
	title.anchor_bottom = 0.20
	title.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(title)

	# Tagline
	var tagline := Label.new()
	tagline.text = "grow your wealth"
	tagline.add_theme_font_size_override("font_size", 16)
	tagline.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45, 1))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.anchor_left   = 0.0
	tagline.anchor_right  = 1.0
	tagline.anchor_top    = 0.34
	tagline.anchor_bottom = 0.34
	tagline.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(tagline)

	# Button column
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.anchor_left   = 0.15
	vbox.anchor_right  = 0.85
	vbox.anchor_top    = 0.46
	vbox.anchor_bottom = 0.46
	add_child(vbox)

	var has_save    := FileAccess.file_exists("user://save.json")
	var is_retired  := has_save and GameManager.game_days >= GameManager.RETIREMENT_AGE_DAYS
	if has_save:
		var cont_btn := _make_btn("Continue" if not is_retired else "View Retirement")
		cont_btn.pressed.connect(_on_continue)
		vbox.add_child(cont_btn)

	var new_btn := _make_btn("New Game")
	new_btn.pressed.connect(_on_new_game)
	vbox.add_child(new_btn)

	var credits_btn := _make_btn("Credits")
	credits_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	credits_btn.pressed.connect(_on_credits)
	vbox.add_child(credits_btn)

	# Version stamp
	var ver := Label.new()
	ver.text = "Nuthouse Games"
	ver.add_theme_font_size_override("font_size", 11)
	ver.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.6))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.anchor_left   = 0.0
	ver.anchor_right  = 1.0
	ver.anchor_top    = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_top    = -28.0
	ver.offset_bottom = -8.0
	ver.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(ver)


func _make_btn(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, 58)
	btn.add_theme_font_size_override("font_size", 20)
	return btn


func _on_continue() -> void:
	if GameManager.game_days >= GameManager.RETIREMENT_AGE_DAYS:
		SceneTransition.go_to("res://scenes/RetirementScreen.tscn")
	else:
		SceneTransition.go_to("res://scenes/Game.tscn")


func _on_new_game() -> void:
	SaveManager.delete_save()
	GameManager.reset()
	SceneTransition.go_to("res://scenes/Game.tscn")


func _on_credits() -> void:
	EndScreen.credits_only = true
	SceneTransition.go_to("res://scenes/EndScreen.tscn")
