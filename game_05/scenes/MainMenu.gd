extends Control

# Intentionally garish AI slop aesthetic
const _LIME   := GameConfig.COLOR_LIME
const _GOLD   := GameConfig.COLOR_GOLD
const _ORANGE := GameConfig.COLOR_ORANGE
const _PINK   := GameConfig.COLOR_BG_PINK

var _coins_lbl: Label  = null
var _daily_btn: Button = null


func _ready() -> void:
	_build_ui()
	EventBus.coins_changed.connect(_on_coins_changed)
	_refresh_daily_btn()


func _build_ui() -> void:
	# ── Garish background ──────────────────────────────
	var bg := ColorRect.new()
	bg.color = GameConfig.COLOR_BG_DARK
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var stripe := ColorRect.new()
	stripe.color = Color(_PINK.r, _PINK.g, _PINK.b, 0.35)
	stripe.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stripe)

	# Gold border bars (top & bottom)
	for is_top in [true, false]:
		var bar := ColorRect.new()
		bar.color = _GOLD
		if is_top:
			bar.set_anchors_preset(PRESET_TOP_WIDE)
			bar.offset_bottom = 4.0
		else:
			bar.set_anchors_preset(PRESET_BOTTOM_WIDE)
			bar.offset_top = -4.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)

	# ── Outer HBox (landscape: left panel | right panel) ──
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	hbox.offset_left   = 16.0
	hbox.offset_right  = -16.0
	hbox.offset_top    = UIFactory.safe_top() + 8.0
	hbox.offset_bottom = -UIFactory.safe_bottom() - 8.0
	hbox.add_theme_constant_override("separation", 20)
	add_child(hbox)

	# ── LEFT: title + coins + daily + GAMBLE button ────
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	left.alignment             = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 10)
	hbox.add_child(left)

	var title := Label.new()
	title.text = "AI SLOP\nSLOTS"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", _LIME)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(title)

	var sub := Label.new()
	sub.text = "DEFINITALY THE BESTEST"
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.85, 0.65, 0.90))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(sub)

	left.add_child(_divider(_GOLD))

	var coins_row := HBoxContainer.new()
	coins_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coins_row.add_theme_constant_override("separation", 6)
	left.add_child(coins_row)

	var coin_lbl := Label.new()
	coin_lbl.text = "COINZ:"
	coin_lbl.add_theme_font_size_override("font_size", 16)
	coin_lbl.add_theme_color_override("font_color", _ORANGE)
	coin_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coins_row.add_child(coin_lbl)

	_coins_lbl = Label.new()
	_coins_lbl.text = _fmt(GameManager.coins)
	_coins_lbl.add_theme_font_size_override("font_size", 28)
	_coins_lbl.add_theme_color_override("font_color", Color.WHITE)
	coins_row.add_child(_coins_lbl)

	left.add_child(_divider(_LIME))

	_daily_btn = UIFactory.make_styled_btn(
		"DAILY FREEE COINZ", Color(0.15, 0.65, 0.20), Color(0.08, 0.35, 0.10),
		Color.WHITE, 15, 50)
	_daily_btn.pressed.connect(_on_daily_pressed)
	left.add_child(_daily_btn)

	var spin_btn := UIFactory.make_styled_btn(
		"PRESS HERE TO GAMBLE", _ORANGE, _ORANGE.darkened(0.4),
		GameConfig.COLOR_BG_DARK, 18, 60)
	spin_btn.pressed.connect(func():
		SceneTransition.go_to("res://scenes/SlotMachine.tscn"))
	left.add_child(spin_btn)

	# ── RIGHT: scatter hint + paytable + stats + debug ─
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	right.alignment             = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 8)
	hbox.add_child(right)

	var scatter_hint := Label.new()
	scatter_hint.text = "3× SCATTER (FROE SHLOT\nMACHINNE SIGN) = BONUS ROUND!!!"
	scatter_hint.add_theme_font_size_override("font_size", 12)
	scatter_hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.30))
	scatter_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scatter_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(scatter_hint)

	right.add_child(_divider(Color(0.5, 0.0, 0.8)))

	var pay_lbl := Label.new()
	pay_lbl.text = "HAND:6×  APLLE:10×  BOOF:15×\nSIGN:25×  SPHERE:50×\nSPUGEHTTI:80×  EYE:200×\n2-match r1+r2: 2×  HAND r1: refund"
	pay_lbl.add_theme_font_size_override("font_size", 11)
	pay_lbl.add_theme_color_override("font_color", Color(0.70, 0.65, 0.80))
	pay_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pay_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(pay_lbl)

	if GameManager.spins_total > 0:
		right.add_child(_divider(_GOLD))
		var stats_lbl := Label.new()
		stats_lbl.text = "SPINS: %d  BEST: %s  BONUS: %d" % [
			GameManager.spins_total, _fmt(GameManager.best_win), GameManager.bonus_wins]
		stats_lbl.add_theme_font_size_override("font_size", 11)
		stats_lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.65))
		stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right.add_child(stats_lbl)

	if OS.is_debug_build():
		var btn_r := UIFactory.make_styled_btn(
			"[D] RESET ALL DATA", Color(0.6, 0.1, 0.1), Color(0.3, 0.05, 0.05),
			Color.WHITE, 11, 34)
		btn_r.pressed.connect(func():
			SaveManager.delete_save()
			GameManager.reset()
			get_tree().reload_current_scene())
		right.add_child(btn_r)


func _refresh_daily_btn() -> void:
	if not is_instance_valid(_daily_btn):
		return
	var avail := GameManager.can_claim_daily_bonus()
	_daily_btn.disabled = not avail
	if avail:
		var idx   := mini(GameManager.streak, GameConfig.DAILY_STREAK_BONUSES.size()-1)
		var bonus := int(GameConfig.DAILY_STREAK_BONUSES[idx])
		_daily_btn.text = "DAILY FREEE COINZ  +%s  (Day %d)" % [_fmt(bonus), GameManager.streak+1]
	else:
		_daily_btn.text = "DAILY COINZ — COME BACK TOMORROW (AI SAYS)"


func _on_daily_pressed() -> void:
	var amount := GameManager.claim_daily_bonus()
	if amount > 0:
		Toast.show_toast("+%s FREEE COINZ!!! STREAK %d" % [_fmt(amount), GameManager.streak],
			_LIME, 2.5)
		_refresh_daily_btn()


func _on_coins_changed(amount: int) -> void:
	if is_instance_valid(_coins_lbl):
		_coins_lbl.text = _fmt(amount)


func _divider(col: Color) -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(col.r, col.g, col.b, 0.40)
	d.custom_minimum_size = Vector2(0, 2)
	return d


static func _fmt(n: int) -> String:
	if n >= 1_000_000: return "%.1fM" % (float(n)/1_000_000.0)
	if n >= 1_000:     return "%.1fK" % (float(n)/1_000.0)
	return str(n)
