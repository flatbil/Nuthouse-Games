extends Control

# -------------------------------------------------------
# SlotMachine — Frontier Slots main game scene.
# 3 reels × 3 rows. Animated strip scroll. Staggered stops.
# Win detection on middle (payline) row only.
# Card images from Kenney boardgame pack.
# -------------------------------------------------------

const _GOLD    := GameConfig.COLOR_GOLD
const _RED     := Color(0.85, 0.15, 0.12, 1.0)
const _RED_DIM := Color(0.50, 0.08, 0.06, 1.0)
const _WIN_COL := Color(1.00, 0.88, 0.10, 1.0)

const STRIP_TOTAL := GameConfig.STRIP_PRE + GameConfig.VISIBLE_ROWS  # 15

# Pre-loaded card textures keyed by symbol id
var _textures: Dictionary = {}

# Per-reel cell references (pre-created, reused each spin)
var _cell_styles:   Array = []   # Array[Array[StyleBoxFlat]]
var _cell_textures: Array = []   # Array[Array[TextureRect]]
var _strips:        Array = []   # Array[VBoxContainer]

var _coins_lbl:  Label  = null
var _result_lbl: Label  = null
var _spin_btn:   Button = null
var _bet_lbl:    Label  = null

# Audio
var _sfx_win:    AudioStreamPlayer = null
var _sfx_bigwin: AudioStreamPlayer = null
var _sfx_slide:  AudioStreamPlayer = null

var _current_bet: int  = 10
var _bet_idx:     int  = 2    # index into GameConfig.BET_OPTIONS
var _spinning:    bool = false


func _ready() -> void:
	_load_textures()
	_build_audio()
	_build_ui()
	EventBus.coins_changed.connect(_on_coins_changed)


# ── Asset loading ────────────────────────────────────────

func _load_textures() -> void:
	for sym_key in GameConfig.SYMBOLS:
		var path: String = GameConfig.SYMBOLS[sym_key]["texture"]
		var tex = load(path)
		if tex != null:
			_textures[sym_key] = tex


func _build_audio() -> void:
	_sfx_win    = _make_sfx("res://assets/sounds/chips_win.ogg")
	_sfx_bigwin = _make_sfx("res://assets/sounds/chips_bigwin.ogg")
	_sfx_slide  = _make_sfx("res://assets/sounds/card_slide.ogg")
	_sfx_slide.volume_db = -6.0


func _make_sfx(path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream = load(path)
	if stream != null:
		player.stream = stream
	add_child(player)
	return player


# ── UI construction ─────────────────────────────────────

func _build_ui() -> void:
	# ── Background ─────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = GameConfig.COLOR_DARK_BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var overlay := ColorRect.new()
	overlay.color = Color(0.12, 0.07, 0.02, 0.50)
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# ── Outer VBox ─────────────────────────────────────
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vbox.offset_left   = 12.0
	vbox.offset_right  = -12.0
	vbox.offset_top    = UIFactory.safe_top() + 8.0
	vbox.offset_bottom = -UIFactory.safe_bottom() - 12.0
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# ── Header ─────────────────────────────────────────
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 56)
	vbox.add_child(header)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.custom_minimum_size = Vector2(88, 50)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.pressed.connect(func(): SceneTransition.go_to("res://scenes/MainMenu.tscn"))
	header.add_child(back_btn)

	var title := Label.new()
	title.text = "FRONTIER SLOTS"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", _GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	_coins_lbl = Label.new()
	_coins_lbl.text = "◆ %s" % _fmt(GameManager.coins)
	_coins_lbl.add_theme_font_size_override("font_size", 16)
	_coins_lbl.add_theme_color_override("font_color", _GOLD)
	_coins_lbl.custom_minimum_size  = Vector2(88, 0)
	_coins_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_coins_lbl)

	# ── Reel frame (centered, takes remaining space) ────
	var reel_center := CenterContainer.new()
	reel_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reel_center.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	vbox.add_child(reel_center)

	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color                   = Color(0.10, 0.06, 0.02, 1.0)
	frame_style.border_color               = _GOLD
	frame_style.border_width_top           = 3
	frame_style.border_width_bottom        = 3
	frame_style.border_width_left          = 3
	frame_style.border_width_right         = 3
	frame_style.corner_radius_top_left     = 10
	frame_style.corner_radius_top_right    = 10
	frame_style.corner_radius_bottom_left  = 10
	frame_style.corner_radius_bottom_right = 10
	frame_style.content_margin_left   = 6.0
	frame_style.content_margin_right  = 6.0
	frame_style.content_margin_top    = 6.0
	frame_style.content_margin_bottom = 6.0

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", frame_style)
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
			cell_style.bg_color     = Color(0.15, 0.10, 0.05)
			cell_style.border_color = Color(0.35, 0.25, 0.10)
			cell_style.border_width_bottom = 1
			cell_style.border_width_top    = 1
			cell_style.border_width_left   = 1
			cell_style.border_width_right  = 1

			var cell := PanelContainer.new()
			cell.custom_minimum_size = Vector2(GameConfig.CELL_W, GameConfig.CELL_H)
			cell.add_theme_stylebox_override("panel", cell_style)

			var margin := MarginContainer.new()
			margin.add_theme_constant_override("margin_top",    4)
			margin.add_theme_constant_override("margin_bottom", 4)
			margin.add_theme_constant_override("margin_left",   6)
			margin.add_theme_constant_override("margin_right",  6)
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

	# ── Payline label ───────────────────────────────────
	var payline_lbl := Label.new()
	payline_lbl.text = "— PAYLINE —"
	payline_lbl.add_theme_font_size_override("font_size", 11)
	payline_lbl.add_theme_color_override("font_color", Color(_GOLD.r, _GOLD.g, _GOLD.b, 0.55))
	payline_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	payline_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(payline_lbl)

	# ── Result label ────────────────────────────────────
	_result_lbl = Label.new()
	_result_lbl.text = ""
	_result_lbl.add_theme_font_size_override("font_size", 22)
	_result_lbl.add_theme_color_override("font_color", _WIN_COL)
	_result_lbl.custom_minimum_size  = Vector2(0, 36)
	_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_result_lbl)

	# ── Bet controls ─────────────────────────────────────
	var bet_row := HBoxContainer.new()
	bet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bet_row.custom_minimum_size = Vector2(0, 50)
	bet_row.add_theme_constant_override("separation", 10)
	vbox.add_child(bet_row)

	var bet_minus := _make_small_btn("-")
	bet_minus.pressed.connect(_on_bet_minus)
	bet_row.add_child(bet_minus)

	_bet_lbl = Label.new()
	_bet_lbl.text = "BET:  %d" % _current_bet
	_bet_lbl.add_theme_font_size_override("font_size", 20)
	_bet_lbl.add_theme_color_override("font_color", Color.WHITE)
	_bet_lbl.custom_minimum_size = Vector2(130, 0)
	_bet_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bet_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	bet_row.add_child(_bet_lbl)

	var bet_plus := _make_small_btn("+")
	bet_plus.pressed.connect(_on_bet_plus)
	bet_row.add_child(bet_plus)

	var bet_max := _make_small_btn("MAX")
	bet_max.add_theme_font_size_override("font_size", 14)
	bet_max.pressed.connect(_on_bet_max)
	bet_row.add_child(bet_max)

	# ── Spin button ──────────────────────────────────────
	_spin_btn = UIFactory.make_styled_btn("SPIN", _RED, _RED_DIM, Color.WHITE, 28, 72)
	_spin_btn.pressed.connect(_on_spin_pressed)
	vbox.add_child(_spin_btn)


# ── Cell helpers ────────────────────────────────────────

func _set_cell(reel: int, cell: int, sym_key: String) -> void:
	var sym: Dictionary = GameConfig.SYMBOLS[sym_key]
	_cell_styles[reel][cell].bg_color     = sym["bg"] as Color
	_cell_styles[reel][cell].border_color = (_GOLD).darkened(0.4)
	if _textures.has(sym_key):
		_cell_textures[reel][cell].texture = _textures[sym_key]


func _randomize_all_cells() -> void:
	for reel in range(GameConfig.REEL_COUNT):
		for cell in range(STRIP_TOTAL):
			_set_cell(reel, cell, GameConfig.weighted_symbol())


# ── Spin logic ──────────────────────────────────────────

func _on_spin_pressed() -> void:
	if _spinning:
		return
	if not GameManager.can_spin(_current_bet):
		Toast.show_toast("Not enough coins!", Color(1.0, 0.4, 0.4))
		return
	_do_spin()


func _do_spin() -> void:
	_spinning          = true
	_spin_btn.disabled = true
	_result_lbl.text   = ""

	var outcome: Dictionary = GameManager.spin(_current_bet)
	if outcome.is_empty():
		_spinning          = false
		_spin_btn.disabled = false
		return

	var result: Array = outcome["result"]
	var winnings: int = outcome["winnings"]

	# Load strips: random pre-cells, then result rows at the bottom
	for reel in range(GameConfig.REEL_COUNT):
		for c in range(GameConfig.STRIP_PRE):
			_set_cell(reel, c, GameConfig.weighted_symbol())
		for row in range(GameConfig.VISIBLE_ROWS):
			_set_cell(reel, GameConfig.STRIP_PRE + row, result[reel][row])
		_strips[reel].position = Vector2.ZERO

	# Play slide sound and animate reels with staggered stops
	if _sfx_slide.stream != null:
		_sfx_slide.play()

	_spin_reel(0, 1.30)
	_spin_reel(1, 1.80)
	_spin_reel(2, 2.30)

	await get_tree().create_timer(2.6).timeout
	_on_spin_settled(winnings, outcome.get("leveled_up", false))


func _spin_reel(reel: int, duration: float) -> void:
	var target_y: float = float(-GameConfig.STRIP_PRE * GameConfig.CELL_H)
	var tw := create_tween()
	tw.tween_property(_strips[reel], "position:y", target_y, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_spin_settled(winnings: int, leveled_up: bool) -> void:
	if winnings > 0:
		_result_lbl.text = "+ %s coins!" % _fmt(winnings)
		_result_lbl.add_theme_color_override("font_color", _WIN_COL)
		Settings.haptic(60)
		if winnings >= _current_bet * 10:
			if _sfx_bigwin.stream != null:
				_sfx_bigwin.play()
			Toast.show_toast("BIG WIN!  +%s" % _fmt(winnings), _WIN_COL, 3.0)
		else:
			if _sfx_win.stream != null:
				_sfx_win.play()
			Toast.show_toast("+%s" % _fmt(winnings), _WIN_COL, 1.8)
	else:
		_result_lbl.text = "No win — try again!"
		_result_lbl.add_theme_color_override("font_color", Color(0.52, 0.46, 0.30))

	if leveled_up:
		await get_tree().create_timer(0.5).timeout
		Toast.show_toast("Level Up!  Lv %d" % GameManager.level,
			Color(0.60, 1.00, 0.60), 2.5)

	_spinning          = false
	_spin_btn.disabled = false


# ── Bet controls ─────────────────────────────────────────

func _on_bet_minus() -> void:
	_bet_idx     = maxi(0, _bet_idx - 1)
	_current_bet = int(GameConfig.BET_OPTIONS[_bet_idx])
	_bet_lbl.text = "BET:  %d" % _current_bet


func _on_bet_plus() -> void:
	_bet_idx     = mini(GameConfig.BET_OPTIONS.size() - 1, _bet_idx + 1)
	_current_bet = int(GameConfig.BET_OPTIONS[_bet_idx])
	_bet_lbl.text = "BET:  %d" % _current_bet


func _on_bet_max() -> void:
	_bet_idx     = GameConfig.BET_OPTIONS.size() - 1
	_current_bet = int(GameConfig.BET_OPTIONS[_bet_idx])
	_bet_lbl.text = "BET:  %d" % _current_bet


# ── Helpers ──────────────────────────────────────────────

func _make_small_btn(txt: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(50, 46)
	btn.add_theme_font_size_override("font_size", 20)
	return btn


func _on_coins_changed(amount: int) -> void:
	if is_instance_valid(_coins_lbl):
		_coins_lbl.text = "◆ %s" % _fmt(amount)


static func _fmt(amount: int) -> String:
	if amount >= 1_000_000:
		return "%.1fM" % (float(amount) / 1_000_000.0)
	if amount >= 1_000:
		return "%.1fK" % (float(amount) / 1_000.0)
	return str(amount)
