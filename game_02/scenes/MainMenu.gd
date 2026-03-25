extends Control

# -------------------------------------------------------
# MainMenu — title screen, built entirely in code.
# Swap in a proper background scene/art when ready.
# -------------------------------------------------------

const _CYAN  := Color(0.30, 0.80, 1.00, 1.0)
const _GOLD  := Color(0.87, 0.70, 0.00, 1.0)
const _WHITE := Color(1.0,  1.0,  1.0,  1.0)


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Full-screen dark background
	var bg := ColorRect.new()
	bg.color = GameConfig.COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centre column
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.add_theme_constant_override("separation", 24)
	vbox.custom_minimum_size = Vector2(280, 0)
	# Nudge upward from centre
	vbox.offset_top    = -160.0
	vbox.offset_bottom =  160.0
	vbox.offset_left   = -140.0
	vbox.offset_right  =  140.0
	add_child(vbox)

	# Studio label
	var studio := Label.new()
	studio.text = "NUTHOUSE GAMES"
	studio.add_theme_font_size_override("font_size", 13)
	studio.add_theme_color_override("font_color", _GOLD)
	studio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(studio)

	# Title
	var title := Label.new()
	title.text = "ASTEROID\nMINER"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", _CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Subtitle / flavour
	var sub := Label.new()
	sub.text = "Mine. Upgrade. Dominate the Belt."
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(_WHITE, 0.6))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# Play button
	var play_btn := Button.new()
	play_btn.text = "LAUNCH MISSION"
	play_btn.custom_minimum_size = Vector2(0, 56)
	play_btn.add_theme_font_size_override("font_size", 20)
	play_btn.add_theme_color_override("font_color", _CYAN)
	play_btn.pressed.connect(_on_play_pressed)
	vbox.add_child(play_btn)

	# Version / build info
	var ver := Label.new()
	ver.text = "v0.1 — Early Access"
	ver.add_theme_font_size_override("font_size", 11)
	ver.add_theme_color_override("font_color", Color(_WHITE, 0.3))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(ver)


func _on_play_pressed() -> void:
	SceneTransition.go_to("res://scenes/Game.tscn")
