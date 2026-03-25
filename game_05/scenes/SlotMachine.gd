extends Control

# -------------------------------------------------------
# SlotMachine — AI Slop Slots main game scene.
# 3 reels × 3 rows. Animated strip scroll. Staggered stops.
# Scatter detection across all 9 cells → BonusRound.
# Garish hot-pink aesthetic because AI said so.
# -------------------------------------------------------

const _LIME   := GameConfig.COLOR_LIME
const _PINK   := GameConfig.COLOR_BG_PINK
const _GOLD   := GameConfig.COLOR_GOLD
const _ORANGE := GameConfig.COLOR_ORANGE

const STRIP_TOTAL := GameConfig.STRIP_PRE + GameConfig.VISIBLE_ROWS  # 15

var _textures:     Dictionary = {}
var _cell_styles:  Array      = []   # Array[Array[StyleBoxFlat]]
var _cell_textures: Array     = []   # Array[Array[TextureRect]]
var _strips:       Array      = []   # Array[VBoxContainer]

var _coins_lbl:    Label  = null
var _result_lbl:   Label  = null
var _spin_btn:     Button = null
var _bet_lbl:      Label  = null
var _scatter_lbl:  Label  = null
var _frame_style:  StyleBoxFlat = null

# Audio
var _sfx_win:    AudioStreamPlayer = null
var _sfx_bigwin: AudioStreamPlayer = null
var _sfx_slide:  AudioStreamPlayer = null
var _sfx_bonus:  AudioStreamPlayer = null

var _current_bet: int  = 10
var _bet_idx:     int  = 2
var _spinning:    bool = false

# Glitch effect state
var _glitch_timer: float = 0.0
var _glitch_active: bool = false


func _ready() -> void:
	_load_textures()
	_build_audio()
	_build_ui()
	EventBus.coins_changed.connect(_on_coins_changed)


func _process(delta: float) -> void:
	if _glitch_active:
		_glitch_timer += delta
		if _glitch_timer >= 0.08:
			_glitch_timer = 0.0
			_flash_glitch()


# ── Asset loading ────────────────────────────────────────

func _load_textures() -> void:
	for sym_key in GameConfig.SYMBOLS:
		var path: String = GameConfig.SYMBOLS[sym_key]["texture"]
		var tex: Texture2D = load(path)
		if tex != null:
			_textures[sym_key] = tex


func _build_audio() -> void:
	_sfx_win    = _make_sfx("res://assets/sounds/sfx_twoTone.ogg")
	_sfx_bigwin = _make_sfx("res://assets/sounds/sfx_lose.ogg")   # ironic big-win sound
	_sfx_slide  = _make_sfx("res://assets/sounds/sfx_zap.ogg")
	_sfx_bonus  = _make_sfx("res://assets/sounds/sfx_twoTone.ogg")
	_sfx_slide.volume_db = -4.0


func _make_sfx(path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream: AudioStream = load(path)
	if stream != null:
		player.stream = stream
	add_child(player)
	return player


# ── UI construction ─────────────────────────────────────
# Landscape layout: header strip on top, then left=reels / right=controls

func _build_ui() -> void:
	# ── Background ─────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = GameConfig.COLOR_BG_DARK
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var overlay := ColorRect.new()
	overlay.color = Color(_PINK.r, _PINK.g, _PINK.b, 0.18)
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# ── Outer VBox ─────────────────────────────────────
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vbox.offset_left   = 8.0
	vbox.offset_right  = -8.0
	vbox.offset_top    = UIFactory.safe_top() + 4.0
	vbox.offset_bottom = -UIFactory.safe_bottom() - 4.0
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# ── Header strip ───────────────────────────────────
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 44)
	vbox.add_child(header)

	var back_btn := Button.new()
	back_btn.text = "← BICK"
	back_btn.custom_minimum_size = Vector2(80, 40)
	back_btn.add_theme_font_size_override("font_size", 14)
	back_btn.pressed.connect(func(): SceneTransition.go_to("res://scenes/MainMenu.tscn"))
	header.add_child(back_btn)

	var title := Label.new()
	title.text = "SLOTT MACHEEN"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", _LIME)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	_coins_lbl = Label.new()
	_coins_lbl.text = "$ %s" % _fmt(GameManager.coins)
	_coins_lbl.add_theme_font_size_override("font_size", 14)
	_coins_lbl.add_theme_color_override("font_color", _GOLD)
	_coins_lbl.custom_minimum_size  = Vector2(90, 0)
	_coins_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_coins_lbl)

	# ── Body: reels LEFT, controls RIGHT ───────────────
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	vbox.add_child(body)

	# Left: reel frame centered vertically
	var reel_center := CenterContainer.new()
	reel_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(reel_center)

	_frame_style = StyleBoxFlat.new()
	_frame_style.bg_color                   = Color(0.06, 0.01, 0.10, 1.0)
	_frame_style.border_color               = _PINK
	_frame_style.border_width_top           = 4
	_frame_style.border_width_bottom        = 4
	_frame_style.border_width_left          = 4
	_frame_style.border_width_right         = 4
	_frame_style.corner_radius_top_left     = 8
	_frame_style.corner_radius_top_right    = 8
	_frame_style.corner_radius_bottom_left  = 8
	_frame_style.corner_radius_bottom_right = 8
	_frame_style.content_margin_left   = 6.0
	_frame_style.content_margin_right  = 6.0
	_frame_style.content_margin_top    = 6.0
	_frame_style.content_margin_bottom = 6.0

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _frame_style)
	reel_center.add_child(frame)

	var reels_hbox := HBoxContainer.new()
	reels_hbox.add_theme_constant_override("separation", 4)
	frame.add_child(reels_hbox)

	# Build 3 reels
	for reel in range(GameConfig.REEL_COUNT):
		var clip := Control.new()
		clip.clip_contents = true
		clip.custom_minimum_size = Vector2(
			GameConfig.CELL_W,
			float(GameConfig.VISIBLE_ROWS) * GameConfig.CELL_H)
		reels_hbox.add_child(clip)

		var strip := VBoxContainer.new()
		strip.add_theme_constant_override("separation", 0)
		clip.add_child(strip)
		_strips.append(strip)

		var reel_styles:   Array = []
		var reel_textures: Array = []

		for _cell in range(STRIP_TOTAL):
			var cell_style := StyleBoxFlat.new()
			cell_style.bg_color     = Color(0.12, 0.02, 0.18)
			cell_style.border_color = Color(_PINK.r, _PINK.g, _PINK.b, 0.6)
			cell_style.border_width_bottom = 1
			cell_style.border_width_top    = 1
			cell_style.border_width_left   = 1
			cell_style.border_width_right  = 1

			var cell := PanelContainer.new()
			cell.custom_minimum_size = Vector2(GameConfig.CELL_W, GameConfig.CELL_H)
			cell.add_theme_stylebox_override("panel", cell_style)

			var margin := MarginContainer.new()
			margin.add_theme_constant_override("margin_top",    3)
			margin.add_theme_constant_override("margin_bottom", 3)
			margin.add_theme_constant_override("margin_left",   4)
			margin.add_theme_constant_override("margin_right",  4)
			cell.add_child(margin)

			var tex_rect := TextureRect.new()
			tex_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tex_rect.size_flags_vertical   = Control.SIZE_EXPAND_FILL
			margin.add_child(tex_rect)

			strip.add_child(cell)
			reel_styles.append(cell_style)
			reel_textures.append(tex_rect)

		_cell_styles.append(reel_styles)
		_cell_textures.append(reel_textures)

	_randomize_all_cells()

	# Right: controls VBox
	var ctrl_vbox := VBoxContainer.new()
	ctrl_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctrl_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	ctrl_vbox.alignment             = BoxContainer.ALIGNMENT_CENTER
	ctrl_vbox.add_theme_constant_override("separation", 8)
	body.add_child(ctrl_vbox)

	# Payline + scatter row
	var pay_row := HBoxContainer.new()
	pay_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pay_row.add_theme_constant_override("separation", 16)
	ctrl_vbox.add_child(pay_row)

	var pay_lbl := Label.new()
	pay_lbl.text = "— PAYLINNE —"
	pay_lbl.add_theme_font_size_override("font_size", 11)
	pay_lbl.add_theme_color_override("font_color", Color(_LIME.r, _LIME.g, _LIME.b, 0.55))
	pay_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pay_row.add_child(pay_lbl)

	_scatter_lbl = Label.new()
	_scatter_lbl.text = ""
	_scatter_lbl.add_theme_font_size_override("font_size", 11)
	_scatter_lbl.add_theme_color_override("font_color", _GOLD)
	_scatter_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pay_row.add_child(_scatter_lbl)

	# Result label
	_result_lbl = Label.new()
	_result_lbl.text = ""
	_result_lbl.add_theme_font_size_override("font_size", 18)
	_result_lbl.add_theme_color_override("font_color", _GOLD)
	_result_lbl.custom_minimum_size  = Vector2(0, 28)
	_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl_vbox.add_child(_result_lbl)

	# Bet controls
	var bet_row := HBoxContainer.new()
	bet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bet_row.add_theme_constant_override("separation", 8)
	ctrl_vbox.add_child(bet_row)

	var bet_minus := _make_small_btn("-")
	bet_minus.pressed.connect(_on_bet_minus)
	bet_row.add_child(bet_minus)

	_bet_lbl = Label.new()
	_bet_lbl.text = "BETT:  %d" % _current_bet
	_bet_lbl.add_theme_font_size_override("font_size", 18)
	_bet_lbl.add_theme_color_override("font_color", Color.WHITE)
	_bet_lbl.custom_minimum_size = Vector2(120, 0)
	_bet_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bet_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	bet_row.add_child(_bet_lbl)

	var bet_plus := _make_small_btn("+")
	bet_plus.pressed.connect(_on_bet_plus)
	bet_row.add_child(bet_plus)

	var bet_max := _make_small_btn("MAX")
	bet_max.add_theme_font_size_override("font_size", 12)
	bet_max.pressed.connect(_on_bet_max)
	bet_row.add_child(bet_max)

	# Spin button
	_spin_btn = UIFactory.make_styled_btn(
		"PRES SPIN!!", _PINK, _PINK.darkened(0.5), _LIME, 22, 60)
	_spin_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spin_btn.pressed.connect(_on_spin_pressed)
	ctrl_vbox.add_child(_spin_btn)


# ── Cell helpers ─────────────────────────────────────────

func _set_cell(reel: int, cell: int, sym_key: String) -> void:
	var sym: Dictionary = GameConfig.SYMBOLS[sym_key]
	_cell_styles[reel][cell].bg_color = sym["bg"] as Color
	_cell_styles[reel][cell].border_color = Color(_PINK.r, _PINK.g, _PINK.b, 0.5)
	if _textures.has(sym_key):
		_cell_textures[reel][cell].texture = _textures[sym_key]


func _randomize_all_cells() -> void:
	for reel in range(GameConfig.REEL_COUNT):
		for cell in range(STRIP_TOTAL):
			_set_cell(reel, cell, GameConfig.weighted_symbol())


# ── Spin logic ───────────────────────────────────────────

func _on_spin_pressed() -> void:
	if _spinning:
		return
	if not GameManager.can_spin(_current_bet):
		Toast.show_toast("NO MONIES!! GET MORE COINZ!!", Color(1.0, 0.2, 0.8))
		return
	_do_spin()


func _do_spin() -> void:
	_spinning          = true
	_spin_btn.disabled = true
	_result_lbl.text   = ""
	_scatter_lbl.text  = ""

	var outcome: Dictionary = GameManager.spin(_current_bet)
	if outcome.is_empty():
		_spinning          = false
		_spin_btn.disabled = false
		return

	var result:   Array = outcome["result"]
	var winnings: int   = outcome["winnings"]
	var scatters: int   = outcome.get("scatters", 0)

	# Load strips
	for reel in range(GameConfig.REEL_COUNT):
		for c in range(GameConfig.STRIP_PRE):
			_set_cell(reel, c, GameConfig.weighted_symbol())
		for row in range(GameConfig.VISIBLE_ROWS):
			_set_cell(reel, GameConfig.STRIP_PRE + row, result[reel][row])
		_strips[reel].position = Vector2.ZERO

	# Start glitch effect
	_glitch_active = true
	_glitch_timer  = 0.0

	if _sfx_slide.stream != null:
		_sfx_slide.play()

	_spin_reel(0, 1.30)
	_spin_reel(1, 1.80)
	_spin_reel(2, 2.30)

	await get_tree().create_timer(2.6).timeout

	_glitch_active = false
	if is_instance_valid(_frame_style):
		_frame_style.border_color = _PINK   # reset

	_on_spin_settled(winnings, outcome.get("leveled_up", false), scatters)


func _spin_reel(reel: int, duration: float) -> void:
	var target_y: float = float(-GameConfig.STRIP_PRE * GameConfig.CELL_H)
	var tw := create_tween()
	tw.tween_property(_strips[reel], "position:y", target_y, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_spin_settled(winnings: int, leveled_up: bool, scatters: int) -> void:
	# Show scatter count if any
	if scatters > 0:
		_scatter_lbl.text = "SCCATTER × %d" % scatters

	if winnings > 0:
		_result_lbl.text = "+ %s COINZ!!" % _fmt(winnings)
		_result_lbl.add_theme_color_override("font_color", _LIME)
		Settings.haptic(60)
		if winnings >= _current_bet * 10:
			if _sfx_bigwin.stream != null:
				_sfx_bigwin.play()
			Toast.show_toast("BIGG WIN!!! +%s COINZ!!!!" % _fmt(winnings), _LIME, 3.0)
		else:
			if _sfx_win.stream != null:
				_sfx_win.play()
			Toast.show_toast("+%s" % _fmt(winnings), _LIME, 1.8)
	else:
		_result_lbl.text = "NO WIN (AI APPOLOGISES)"
		_result_lbl.add_theme_color_override("font_color", Color(0.55, 0.20, 0.60))

	if leveled_up:
		await get_tree().create_timer(0.4).timeout
		Toast.show_toast("LEVLE UP!! LVL %d!!" % GameManager.level, _GOLD, 2.5)

	_spinning          = false
	_spin_btn.disabled = false

	# Check bonus pending — transition after short delay so player sees result
	if GameManager.bonus_pending:
		await get_tree().create_timer(1.2).timeout
		Toast.show_toast("BONUS ROUND!!!! ENTER NOW$$$", _GOLD, 1.5)
		if _sfx_bonus.stream != null:
			_sfx_bonus.play()
		await get_tree().create_timer(1.6).timeout
		SceneTransition.go_to("res://scenes/BonusRound.tscn")


# ── Glitch effect ────────────────────────────────────────

func _flash_glitch() -> void:
	if not is_instance_valid(_frame_style):
		return
	var glitch_colors := [
		Color(1.0, 0.0, 1.0), Color(0.0, 1.0, 0.0), Color(1.0, 1.0, 0.0),
		Color(0.0, 1.0, 1.0), Color(1.0, 0.2, 0.0), _PINK, _LIME,
	]
	_frame_style.border_color = glitch_colors[randi() % glitch_colors.size()]


# ── Bet controls ─────────────────────────────────────────

func _on_bet_minus() -> void:
	_bet_idx     = maxi(0, _bet_idx - 1)
	_current_bet = int(GameConfig.BET_OPTIONS[_bet_idx])
	_bet_lbl.text = "BETT:  %d" % _current_bet


func _on_bet_plus() -> void:
	_bet_idx     = mini(GameConfig.BET_OPTIONS.size() - 1, _bet_idx + 1)
	_current_bet = int(GameConfig.BET_OPTIONS[_bet_idx])
	_bet_lbl.text = "BETT:  %d" % _current_bet


func _on_bet_max() -> void:
	_bet_idx     = GameConfig.BET_OPTIONS.size() - 1
	_current_bet = int(GameConfig.BET_OPTIONS[_bet_idx])
	_bet_lbl.text = "BETT:  %d" % _current_bet


# ── Helpers ──────────────────────────────────────────────

func _make_small_btn(txt: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(50, 46)
	btn.add_theme_font_size_override("font_size", 20)
	return btn


func _on_coins_changed(amount: int) -> void:
	if is_instance_valid(_coins_lbl):
		_coins_lbl.text = "$ %s" % _fmt(amount)


static func _fmt(amount: int) -> String:
	if amount >= 1_000_000:
		return "%.1fM" % (float(amount) / 1_000_000.0)
	if amount >= 1_000:
		return "%.1fK" % (float(amount) / 1_000.0)
	return str(amount)
