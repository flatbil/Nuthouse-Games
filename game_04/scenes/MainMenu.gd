extends Control

const _GOLD     := Color(0.90, 0.75, 0.10, 1.0)
const _GOLD_DIM := Color(0.55, 0.42, 0.00, 1.0)
const _RED      := Color(0.85, 0.15, 0.12, 1.0)
const _RED_DIM  := Color(0.50, 0.08, 0.06, 1.0)
const _GREEN    := Color(0.12, 0.58, 0.20, 1.0)

var _coins_lbl:  Label   = null
var _xp_bar:     ColorRect = null
var _xp_fill:    ColorRect = null
var _level_lbl:  Label   = null
var _daily_btn:  Button  = null
var _spin_btn:   Button  = null


func _ready() -> void:
	_build_ui()
	EventBus.coins_changed.connect(_on_coins_changed)
	_refresh_daily_btn()


func _build_ui() -> void:
	# ── Background ─────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = GameConfig.COLOR_DARK_BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Warm wood overlay
	var felt := ColorRect.new()
	felt.color = Color(0.12, 0.07, 0.02, 0.55)
	felt.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(felt)

	# Gold border lines
	_add_border()

	# ── Main VBox ──────────────────────────────────────
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vbox.offset_left   = 24.0
	vbox.offset_right  = -24.0
	vbox.offset_top    = UIFactory.safe_top() + 20.0
	vbox.offset_bottom = -UIFactory.safe_bottom() - 20.0
	vbox.alignment     = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	# ── Title ─────────────────────────────────────────
	var title := Label.new()
	title.text = "FRONTIER SLOTS"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", _GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Wild West Social Slots"
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.65, 0.60, 0.40))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	vbox.add_child(_divider())

	# ── Coins display ──────────────────────────────────
	var coins_row := HBoxContainer.new()
	coins_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coins_row.add_theme_constant_override("separation", 8)
	vbox.add_child(coins_row)

	var chip_tex = load("res://assets/sprites/chip_coin.png")
	if chip_tex != null:
		var coin_icon := TextureRect.new()
		coin_icon.texture     = chip_tex
		coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin_icon.custom_minimum_size = Vector2(36, 36)
		coins_row.add_child(coin_icon)
	else:
		var coin_icon := Label.new()
		coin_icon.text = "◆"
		coin_icon.add_theme_font_size_override("font_size", 28)
		coin_icon.add_theme_color_override("font_color", _GOLD)
		coins_row.add_child(coin_icon)

	_coins_lbl = Label.new()
	_coins_lbl.text = _format_coins(GameManager.coins)
	_coins_lbl.add_theme_font_size_override("font_size", 32)
	_coins_lbl.add_theme_color_override("font_color", Color.WHITE)
	coins_row.add_child(_coins_lbl)

	# ── Level + XP ────────────────────────────────────
	var level_row := HBoxContainer.new()
	level_row.alignment = BoxContainer.ALIGNMENT_CENTER
	level_row.add_theme_constant_override("separation", 8)
	vbox.add_child(level_row)

	_level_lbl = Label.new()
	_level_lbl.text = "Lv %d" % GameManager.level
	_level_lbl.add_theme_font_size_override("font_size", 14)
	_level_lbl.add_theme_color_override("font_color", Color(0.75, 0.70, 0.50))
	level_row.add_child(_level_lbl)

	var xp_track := Control.new()
	xp_track.custom_minimum_size = Vector2(200, 12)
	xp_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_row.add_child(xp_track)

	_xp_bar = ColorRect.new()
	_xp_bar.color = Color(0.15, 0.15, 0.10)
	_xp_bar.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	xp_track.add_child(_xp_bar)

	_xp_fill = ColorRect.new()
	_xp_fill.color = _GOLD
	_xp_fill.set_anchors_preset(PRESET_LEFT_WIDE)
	xp_track.add_child(_xp_fill)
	_refresh_xp_bar()

	var xp_lbl := Label.new()
	xp_lbl.text = "%d / %d XP" % [GameManager.xp, GameConfig.xp_for_level(GameManager.level)]
	xp_lbl.add_theme_font_size_override("font_size", 12)
	xp_lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.38))
	level_row.add_child(xp_lbl)

	vbox.add_child(_divider())

	# ── Daily bonus button ─────────────────────────────
	_daily_btn = UIFactory.make_styled_btn(
		"DAILY BONUS", _GREEN, _GREEN.darkened(0.35), Color.WHITE, 18, 58)
	_daily_btn.pressed.connect(_on_daily_bonus_pressed)
	vbox.add_child(_daily_btn)

	# ── Spin button ────────────────────────────────────
	_spin_btn = UIFactory.make_styled_btn(
		"SPIN", _RED, _RED_DIM, Color.WHITE, 28, 74)
	_spin_btn.pressed.connect(func():
		SceneTransition.go_to("res://scenes/SlotMachine.tscn"))
	vbox.add_child(_spin_btn)

	vbox.add_child(_divider())

	# ── Paytable (quick reference) ─────────────────────
	var pay_lbl := Label.new()
	pay_lbl.text = "9s:6×  10s:10×  Js:15×  Qs:25×  Ks:50×  As:80×  ★:200×\n2-match reels 1+2: 2×   9 on reel 1: refund"
	pay_lbl.add_theme_font_size_override("font_size", 11)
	pay_lbl.add_theme_color_override("font_color", Color(0.60, 0.56, 0.38))
	pay_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pay_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(pay_lbl)

	vbox.add_child(_divider())

	# ── Stats ──────────────────────────────────────────
	if GameManager.spins_total > 0:
		var stats_lbl := Label.new()
		stats_lbl.text = "Spins: %d   Best Win: %s" % [
			GameManager.spins_total,
			_format_coins(GameManager.best_win),
		]
		stats_lbl.add_theme_font_size_override("font_size", 13)
		stats_lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.38))
		stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(stats_lbl)

	# ── Debug reset ────────────────────────────────────
	if OS.is_debug_build():
		var btn_reset := UIFactory.make_styled_btn(
			"[D] Reset Save", Color(0.7, 0.2, 0.2), Color(0.4, 0.1, 0.1), Color.WHITE, 14, 40)
		btn_reset.pressed.connect(func():
			SaveManager.delete_save()
			GameManager.reset()
			get_tree().reload_current_scene())
		vbox.add_child(btn_reset)


func _add_border() -> void:
	var top := ColorRect.new()
	top.color = Color(_GOLD.r, _GOLD.g, _GOLD.b, 0.45)
	top.set_anchors_preset(PRESET_TOP_WIDE)
	top.offset_bottom = 2.0
	top.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(top)

	var bot := ColorRect.new()
	bot.color = Color(_GOLD.r, _GOLD.g, _GOLD.b, 0.45)
	bot.set_anchors_preset(PRESET_BOTTOM_WIDE)
	bot.offset_top   = -2.0
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bot)


func _refresh_xp_bar() -> void:
	if _xp_fill == null:
		return
	var pct: float = float(GameManager.xp) / float(GameConfig.xp_for_level(GameManager.level))
	_xp_fill.offset_right = pct   # anchor_right is 0 by default; this sets width as fraction


func _refresh_daily_btn() -> void:
	if _daily_btn == null:
		return
	var available: bool = GameManager.can_claim_daily_bonus()
	_daily_btn.disabled = not available
	if available:
		var bonus_idx: int = mini(GameManager.streak, GameConfig.DAILY_STREAK_BONUSES.size() - 1)
		var bonus: int     = int(GameConfig.DAILY_STREAK_BONUSES[bonus_idx])
		_daily_btn.text = "DAILY BONUS  +%s  (Day %d)" % [
			_format_coins(bonus), GameManager.streak + 1]
		_pulse_daily_btn()
	else:
		_daily_btn.text = "Daily Bonus — Come back tomorrow!"


func _pulse_daily_btn() -> void:
	if not is_instance_valid(_daily_btn):
		return
	var tween := create_tween().set_loops()
	tween.tween_property(_daily_btn, "modulate",
		Color(1.4, 1.4, 0.9, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_daily_btn, "modulate",
		Color(1.0, 1.0, 1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)


func _on_daily_bonus_pressed() -> void:
	var amount: int = GameManager.claim_daily_bonus()
	if amount > 0:
		Toast.show_toast("+%s coins! Streak: %d" % [_format_coins(amount), GameManager.streak],
			_GOLD, 2.5)
		_refresh_daily_btn()


func _on_coins_changed(amount: int) -> void:
	if is_instance_valid(_coins_lbl):
		_coins_lbl.text = _format_coins(amount)


static func _format_coins(amount: int) -> String:
	if amount >= 1_000_000:
		return "%.1fM" % (float(amount) / 1_000_000.0)
	if amount >= 1_000:
		return "%.1fK" % (float(amount) / 1_000.0)
	return str(amount)


func _divider() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(_GOLD.r, _GOLD.g, _GOLD.b, 0.20)
	d.custom_minimum_size = Vector2(0, 1)
	return d
