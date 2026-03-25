class_name EndScreen
extends Control

# -------------------------------------------------------
# EndScreen — Retirement celebration + scrolling credits.
# Set EndScreen.credits_only = true before loading this
# scene to skip the celebration and go straight to credits.
# -------------------------------------------------------

static var credits_only: bool = false

const CELEBRATION_DURATION := 3.5
const CREDITS_SKIP_DELAY   := 5.0
const CREDITS_SCROLL_SPEED := 80.0  # pixels per second
const BURST_COUNT          := 14

const _GOLD        := Color(0.87, 0.70, 0.0,  1.0)
const _GREEN       := Color(0.106, 0.369, 0.125, 1.0)

var _bg:              ColorRect
var _celebration:     Control
var _credits_root:    Control
var _credits_content: VBoxContainer
var _skip_btn:        Button
var _scroll_tween:    Tween


func _ready() -> void:
	_build_ui()
	if credits_only:
		_bg.color = Color(0.04, 0.06, 0.04, 1.0)
		_celebration.visible = false
		_start_credits()
	else:
		_start_celebration()


# -------------------------------------------------------
# UI construction
# -------------------------------------------------------

func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0.06, 0.18, 0.07, 1.0)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# ---- Celebration layer ----
	_celebration = Control.new()
	_celebration.set_anchors_preset(Control.PRESET_FULL_RECT)
	_celebration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_celebration)

	var retired_lbl := Label.new()
	retired_lbl.text = "YOU RETIRED!"
	retired_lbl.add_theme_font_size_override("font_size", 52)
	retired_lbl.add_theme_color_override("font_color", _GOLD)
	retired_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	retired_lbl.anchor_left   = 0.0
	retired_lbl.anchor_right  = 1.0
	retired_lbl.anchor_top    = 0.32
	retired_lbl.anchor_bottom = 0.32
	retired_lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_celebration.add_child(retired_lbl)

	var net_worth := GameManager.resources + GameManager.total_invested + GameManager.total_dividends_earned
	var age       := int(GameManager.START_AGE + GameManager.game_days / 365.0)

	var worth_lbl := Label.new()
	worth_lbl.text = "Final Net Worth: $%s" % _fmt(net_worth)
	worth_lbl.add_theme_font_size_override("font_size", 26)
	worth_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	worth_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	worth_lbl.anchor_left   = 0.0
	worth_lbl.anchor_right  = 1.0
	worth_lbl.anchor_top    = 0.50
	worth_lbl.anchor_bottom = 0.50
	worth_lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_celebration.add_child(worth_lbl)

	var year_lbl := Label.new()
	year_lbl.text = "Retired at age %d" % age
	year_lbl.add_theme_font_size_override("font_size", 18)
	year_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 0.9))
	year_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	year_lbl.anchor_left   = 0.0
	year_lbl.anchor_right  = 1.0
	year_lbl.anchor_top    = 0.60
	year_lbl.anchor_bottom = 0.60
	year_lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_celebration.add_child(year_lbl)

	# ---- Credits layer ----
	_credits_root = Control.new()
	_credits_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits_root.visible = false
	add_child(_credits_root)

	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.88)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_credits_root.add_child(overlay)

	var clip := Control.new()
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.clip_contents  = true
	clip.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	_credits_root.add_child(clip)

	_credits_content = VBoxContainer.new()
	_credits_content.add_theme_constant_override("separation", 14)
	_credits_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_credits_content)
	_build_credits_text()

	_skip_btn = Button.new()
	_skip_btn.text = "Skip  ▶"
	_skip_btn.custom_minimum_size = Vector2(120, 44)
	_skip_btn.anchor_left   = 1.0
	_skip_btn.anchor_right  = 1.0
	_skip_btn.anchor_top    = 1.0
	_skip_btn.anchor_bottom = 1.0
	_skip_btn.offset_left   = -140.0
	_skip_btn.offset_top    = -64.0
	_skip_btn.offset_right  = -20.0
	_skip_btn.offset_bottom = -20.0
	_skip_btn.visible = false
	_skip_btn.pressed.connect(_go_to_menu)
	_credits_root.add_child(_skip_btn)


func _build_credits_text() -> void:
	var lines: Array = [
		["COMPOUND",               38, _GOLD,                  true],
		["A financial idle game",  15, Color(0.7, 0.7, 0.7, 1), false],
		["",                       24, Color.TRANSPARENT,       false],
		["────────────────────",   13, Color(0.4, 0.4, 0.4, 1), false],
		["",                       24, Color.TRANSPARENT,       false],
		["Developed by",           14, Color(0.55, 0.55, 0.55, 1), false],
		["Nuthouse Games",         26, Color(1, 1, 1, 1),       true],
		["",                       20, Color.TRANSPARENT,       false],
		["Design & Programming",   14, Color(0.55, 0.55, 0.55, 1), false],
		["William Almond",         22, Color(1, 1, 1, 1),       false],
		["",                       20, Color.TRANSPARENT,       false],
		["Sound Effects",          14, Color(0.55, 0.55, 0.55, 1), false],
		["Kenney.nl",              18, Color(1, 1, 1, 1),       false],
		["",                       20, Color.TRANSPARENT,       false],
		["────────────────────",   13, Color(0.4, 0.4, 0.4, 1), false],
		["",                       24, Color.TRANSPARENT,       false],
		["Thank you for playing!", 24, _GOLD,                   true],
		["",                       16, Color.TRANSPARENT,       false],
		["Go forth and compound.", 16, Color(0.7, 0.7, 0.7, 0.8), false],
		["",                       48, Color.TRANSPARENT,       false],
		["",                       48, Color.TRANSPARENT,       false],
	]
	for line in lines:
		var lbl := Label.new()
		lbl.text = line[0]
		lbl.add_theme_font_size_override("font_size", line[1])
		lbl.add_theme_color_override("font_color", line[2])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_credits_content.add_child(lbl)


# -------------------------------------------------------
# Celebration
# -------------------------------------------------------

func _start_celebration() -> void:
	_fire_burst_wave()
	await get_tree().create_timer(0.5).timeout
	_fire_burst_wave()
	await get_tree().create_timer(0.6).timeout
	_fire_burst_wave()
	await get_tree().create_timer(CELEBRATION_DURATION - 1.1).timeout
	var tween := create_tween()
	tween.tween_property(_celebration, "modulate:a", 0.0, 0.9)
	await tween.finished
	_celebration.visible = false
	_bg.color = Color(0.04, 0.06, 0.04, 1.0)
	_start_credits()


func _fire_burst_wave() -> void:
	var center := get_viewport_rect().size / 2.0
	for i in range(BURST_COUNT):
		_spawn_burst_particle(center, i)


func _spawn_burst_particle(origin: Vector2, index: int) -> void:
	var lbl := Label.new()
	lbl.text = "$"
	lbl.add_theme_font_size_override("font_size", randi_range(20, 48))
	lbl.add_theme_color_override("font_color", _GOLD)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.position     = origin
	_celebration.add_child(lbl)
	var angle  := (TAU / float(BURST_COUNT)) * float(index) + randf() * 0.7
	var dist   := randf_range(80.0, 220.0)
	var target := origin + Vector2(cos(angle), sin(angle)) * dist
	var tween  := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position", target, 1.1) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(lbl, "scale", Vector2(2.2, 2.2), 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.65).set_delay(0.45)
	await tween.finished
	lbl.queue_free()


# -------------------------------------------------------
# Credits
# -------------------------------------------------------

func _start_credits() -> void:
	_credits_root.visible = true
	_credits_root.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(_credits_root, "modulate:a", 1.0, 0.7)
	await fade.finished

	# Let the VBoxContainer measure its contents
	_credits_content.custom_minimum_size.x = get_viewport_rect().size.x
	await get_tree().process_frame
	await get_tree().process_frame

	var vp_h: float      = get_viewport_rect().size.y
	var content_h: float = _credits_content.size.y
	_credits_content.position = Vector2(0.0, vp_h)

	var scroll_dist: float = vp_h + content_h
	var duration: float    = scroll_dist / CREDITS_SCROLL_SPEED

	_scroll_tween = create_tween()
	_scroll_tween.tween_property(_credits_content, "position:y", -content_h, duration) \
		.set_trans(Tween.TRANS_LINEAR)

	# Show skip button after delay
	await get_tree().create_timer(CREDITS_SKIP_DELAY).timeout
	if not is_instance_valid(_skip_btn):
		return
	_skip_btn.visible    = true
	_skip_btn.modulate.a = 0.0
	var skip_fade := create_tween()
	skip_fade.tween_property(_skip_btn, "modulate:a", 1.0, 0.5)

	# Auto-advance when scroll finishes
	await _scroll_tween.finished
	_go_to_menu()


func _go_to_menu() -> void:
	credits_only = false
	SceneTransition.go_to("res://scenes/MainMenu.tscn")


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
