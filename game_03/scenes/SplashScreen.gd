extends Control

const DISPLAY_TIME := 10.0
const FADE_IN      := 0.6
const FADE_OUT     := 0.5

var _overlay: ColorRect = null
var _elapsed: float     = 0.0
var _fading:  bool      = false


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Splash image — fills screen, aspect preserved via texture rect
	var tex_rect := TextureRect.new()
	tex_rect.texture      = load("res://assets/splash.png")
	tex_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tex_rect)

	# Tap-to-skip hint at bottom
	var hint := Label.new()
	hint.text = "Tap to continue"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.55))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(PRESET_BOTTOM_WIDE)
	hint.offset_top    = -UIFactory.safe_bottom() - 44.0
	hint.offset_bottom = -UIFactory.safe_bottom() - 12.0
	hint.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	# Gentle pulse
	var tw := create_tween().set_loops()
	tw.tween_property(hint, "modulate:a", 0.15, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(hint, "modulate:a", 0.55, 1.1).set_trans(Tween.TRANS_SINE)

	# Black overlay for fade-in
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 1.0)
	_overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# Fade in
	var fade := create_tween()
	fade.tween_property(_overlay, "color:a", 0.0, FADE_IN).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	if _fading:
		return
	_elapsed += delta
	if _elapsed >= DISPLAY_TIME:
		_go()


func _input(event: InputEvent) -> void:
	if _fading:
		return
	if event is InputEventScreenTouch and event.pressed:
		_go()
	elif event is InputEventMouseButton and event.pressed:
		_go()


func _go() -> void:
	if _fading:
		return
	_fading = true
	var tw := create_tween()
	tw.tween_property(_overlay, "color:a", 1.0, FADE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): SceneTransition.go_to("res://scenes/MainMenu.tscn"))
