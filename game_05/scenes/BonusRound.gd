extends Control

# -------------------------------------------------------
# BonusRound — AI Slop Slots bonus round.
# Single large prize reel spins and stops on a random prize.
# Glitch screen effects. AI congratulation message. Collect.
# -------------------------------------------------------

const _LIME   := GameConfig.COLOR_LIME
const _PINK   := GameConfig.COLOR_BG_PINK
const _GOLD   := GameConfig.COLOR_GOLD

const PRIZE_CELL_H := 110
const PRIZE_STRIP_PRE := 14   # random cells before the winner

var _strip:        VBoxContainer = null
var _clip:         Control       = null
var _result_lbl:   Label         = null
var _congrats_lbl: Label         = null
var _collect_btn:  Button        = null
var _frame_style:  StyleBoxFlat  = null

# Pre-created cell styles for glitch flashing
var _cell_styles: Array = []

# Audio
var _sfx_spin:    AudioStreamPlayer = null
var _sfx_collect: AudioStreamPlayer = null

var _chosen_prize_idx: int = 0
var _spinning: bool        = false
var _collected: bool       = false

# Glitch
var _glitch_timer:  float = 0.0
var _glitch_active: bool  = false


func _ready() -> void:
	_build_audio()
	_build_ui()
	await get_tree().process_frame
	await get_tree().process_frame
	_start_spin()


func _process(delta: float) -> void:
	if _glitch_active:
		_glitch_timer += delta
		if _glitch_timer >= 0.07:
			_glitch_timer = 0.0
			_flash_glitch()


# ── Audio ───────────────────────────────────────────────

func _build_audio() -> void:
	_sfx_spin    = _make_sfx("res://assets/sounds/sfx_zap.ogg")
	_sfx_collect = _make_sfx("res://assets/sounds/sfx_twoTone.ogg")


func _make_sfx(path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream: AudioStream = load(path)
	if stream != null:
		player.stream = stream
	add_child(player)
	return player


# ── UI ──────────────────────────────────────────────────

func _build_ui() -> void:
	# ── Background ─────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = GameConfig.COLOR_BG_DARK
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var overlay := ColorRect.new()
	overlay.color = Color(_PINK.r, _PINK.g, _PINK.b, 0.25)
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# ── Outer HBox: left=reel, right=results ───────────
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	hbox.offset_left   = 16.0
	hbox.offset_right  = -16.0
	hbox.offset_top    = UIFactory.safe_top() + 8.0
	hbox.offset_bottom = -UIFactory.safe_bottom() - 8.0
	hbox.add_theme_constant_override("separation", 20)
	add_child(hbox)

	# ── LEFT: title + prize reel + arrow ───────────────
	var left := VBoxContainer.new()
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.alignment           = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 8)
	hbox.add_child(left)

	var title := Label.new()
	title.text = "BONUS ROUND!!!"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", _LIME)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(title)

	var sub := Label.new()
	sub.text = "AI CHOSE YOUR PRIZE (MAYBE)"
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.80, 0.60, 0.90))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(sub)

	# Prize reel frame
	var reel_center := CenterContainer.new()
	left.add_child(reel_center)

	_frame_style = StyleBoxFlat.new()
	_frame_style.bg_color                   = Color(0.04, 0.00, 0.08, 1.0)
	_frame_style.border_color               = _GOLD
	_frame_style.border_width_top           = 4
	_frame_style.border_width_bottom        = 4
	_frame_style.border_width_left          = 4
	_frame_style.border_width_right         = 4
	_frame_style.corner_radius_top_left     = 10
	_frame_style.corner_radius_top_right    = 10
	_frame_style.corner_radius_bottom_left  = 10
	_frame_style.corner_radius_bottom_right = 10
	_frame_style.content_margin_left   = 6.0
	_frame_style.content_margin_right  = 6.0
	_frame_style.content_margin_top    = 6.0
	_frame_style.content_margin_bottom = 6.0

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _frame_style)
	reel_center.add_child(frame)

	_clip = Control.new()
	_clip.clip_contents = true
	_clip.custom_minimum_size = Vector2(200, PRIZE_CELL_H)
	frame.add_child(_clip)

	_strip = VBoxContainer.new()
	_strip.add_theme_constant_override("separation", 0)
	_clip.add_child(_strip)

	var total_cells := PRIZE_STRIP_PRE + 1
	for _i in range(total_cells):
		var cell_style := StyleBoxFlat.new()
		cell_style.bg_color     = Color(0.10, 0.00, 0.16)
		cell_style.border_color = Color(_PINK.r, _PINK.g, _PINK.b, 0.5)
		cell_style.border_width_top    = 1
		cell_style.border_width_bottom = 1
		cell_style.border_width_left   = 1
		cell_style.border_width_right  = 1

		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(200, PRIZE_CELL_H)
		cell.add_theme_stylebox_override("panel", cell_style)

		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		cell.add_child(lbl)

		_strip.add_child(cell)
		_cell_styles.append(cell_style)

	var arrow_lbl := Label.new()
	arrow_lbl.text = "▼  WINNER  ▼"
	arrow_lbl.add_theme_font_size_override("font_size", 12)
	arrow_lbl.add_theme_color_override("font_color", _GOLD)
	arrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(arrow_lbl)

	# ── RIGHT: result + congrats + collect ─────────────
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	right.alignment             = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 12)
	hbox.add_child(right)

	_result_lbl = Label.new()
	_result_lbl.text = "SPINNNNING..."
	_result_lbl.add_theme_font_size_override("font_size", 24)
	_result_lbl.add_theme_color_override("font_color", _LIME)
	_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_lbl.custom_minimum_size  = Vector2(0, 36)
	right.add_child(_result_lbl)

	_congrats_lbl = Label.new()
	_congrats_lbl.text = ""
	_congrats_lbl.add_theme_font_size_override("font_size", 14)
	_congrats_lbl.add_theme_color_override("font_color", Color(0.80, 0.70, 0.95))
	_congrats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_congrats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_congrats_lbl)

	_collect_btn = UIFactory.make_styled_btn(
		"CLLECT WINNINGZ!!!", Color(0.10, 0.55, 0.15), Color(0.05, 0.28, 0.08),
		Color.WHITE, 18, 58)
	_collect_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collect_btn.disabled = true
	_collect_btn.pressed.connect(_on_collect_pressed)
	right.add_child(_collect_btn)


# ── Spin logic ───────────────────────────────────────────

func _start_spin() -> void:
	_spinning = true
	_glitch_active = true
	_glitch_timer  = 0.0

	# Pick prize with weighted random (500× and GLITCH are rarer)
	var weights := [10, 10, 10, 8, 6, 4, 3, 1, 2]  # matches BONUS_PRIZES order
	var total_w := 0
	for w in weights:
		total_w += w
	var r := randi() % total_w
	var acc := 0
	_chosen_prize_idx = 0
	for i in range(weights.size()):
		acc += weights[i]
		if r < acc:
			_chosen_prize_idx = i
			break

	# Resolve glitch prize
	var chosen := GameConfig.BONUS_PRIZES[_chosen_prize_idx]
	var final_mult: int = chosen["mult"]
	if final_mult == -1:
		final_mult = (randi() % 50 + 1) * 10  # random 10–500 in steps of 10

	# Fill strip cells randomly except last = winner
	var prizes := GameConfig.BONUS_PRIZES
	for i in range(PRIZE_STRIP_PRE):
		var rand_prize: Dictionary = prizes[randi() % prizes.size()]
		_fill_strip_cell(i, rand_prize)
	_fill_strip_cell(PRIZE_STRIP_PRE, chosen)

	_strip.position = Vector2.ZERO

	if _sfx_spin.stream != null:
		_sfx_spin.play()

	# Animate
	var target_y: float = float(-PRIZE_STRIP_PRE * PRIZE_CELL_H)
	var tw := create_tween()
	tw.tween_property(_strip, "position:y", target_y, 2.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(3.0).timeout

	_glitch_active = false
	if is_instance_valid(_frame_style):
		_frame_style.border_color = chosen["color"] as Color

	_on_spin_settled(final_mult, chosen)


func _fill_strip_cell(idx: int, prize: Dictionary) -> void:
	var cell := _strip.get_child(idx) as PanelContainer
	if cell == null:
		return
	var lbl := cell.get_child(0) as Label
	if lbl == null:
		return
	lbl.text = prize["label"]
	lbl.add_theme_color_override("font_color", prize["color"] as Color)
	_cell_styles[idx].bg_color = (prize["color"] as Color).darkened(0.72)


func _on_spin_settled(final_mult: int, prize: Dictionary) -> void:
	_spinning = false

	var prize_coins: int = GameManager.collect_bonus(final_mult)

	# Show result
	_result_lbl.text = "+ %s COINZ!!" % _fmt(prize_coins)
	_result_lbl.add_theme_color_override("font_color", prize["color"] as Color)

	# Pick random AI congrats message
	var tmpl: String = GameConfig.AI_CONGRATS[randi() % GameConfig.AI_CONGRATS.size()]
	_congrats_lbl.text = tmpl % prize_coins

	_collect_btn.disabled = false

	Settings.haptic(80)
	if _sfx_collect.stream != null:
		_sfx_collect.play()

	Toast.show_toast(prize["label"] + "  +%s!!" % _fmt(prize_coins),
		prize["color"] as Color, 3.0)


func _on_collect_pressed() -> void:
	if _collected:
		return
	_collected = true
	_collect_btn.disabled = true
	SceneTransition.go_to("res://scenes/SlotMachine.tscn")


# ── Glitch effect ─────────────────────────────────────────

func _flash_glitch() -> void:
	if not is_instance_valid(_frame_style):
		return
	var colors := [
		Color(1.0, 0.0, 0.8), Color(0.0, 1.0, 0.0), Color(1.0, 1.0, 0.0),
		Color(0.0, 0.8, 1.0), _PINK, _LIME, _GOLD,
	]
	_frame_style.border_color = colors[randi() % colors.size()]


# ── Helpers ──────────────────────────────────────────────

static func _fmt(amount: int) -> String:
	if amount >= 1_000_000:
		return "%.1fM" % (float(amount) / 1_000_000.0)
	if amount >= 1_000:
		return "%.1fK" % (float(amount) / 1_000.0)
	return str(amount)
