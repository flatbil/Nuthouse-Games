extends Control

# -------------------------------------------------------
# Game.gd — UI only. Reads state via EventBus signals.
# Calls GameManager for all state changes.
# All game-specific strings and colors come from GameConfig.
#
# Four generic sections map to GameConfig tracks:
#   "track_0" → TRACK_A (one-time tap boosters)
#   "track_1" → TRACK_B (repeatable generators)
#   "track_2" → TRACK_C (one-time passive multipliers)
#   "track_3" → TRACK_D (one-time tap multipliers)
# -------------------------------------------------------

@onready var resource_label:   Label         = $TopHUD/Stats/ResourceLabel
@onready var salary_label:     Label         = $TopHUD/Stats/SalaryLabel
@onready var per_sec_label:    Label         = $TopHUD/Stats/PerSecLabel
@onready var days_label:       Label         = $TopHUD/Stats/DaysLabel
@onready var portfolio_label:  Label         = $TopHUD/Stats/PortfolioLabel
@onready var retirement_label: Label         = $TopHUD/Stats/RetirementLabel
@onready var upgrade_list:     VBoxContainer = $UpgradeDrawer/ScrollContainer/UpgradeList
@onready var stage_label:      Label         = $StageLabel
@onready var hamburger_btn:  Button        = $HamburgerBtn
@onready var drawer_overlay: Button        = $DrawerOverlay
@onready var upgrade_drawer: PanelContainer = $UpgradeDrawer

# Section collapse state — keys are "track_0" … "track_3"
var _collapsed: Dictionary = {
	"track_0": true,
	"track_1": true,
	"track_2": true,
	"track_3": true,
}

const _BURST_COUNT := 8

var _section_indicators:     Dictionary = {}   # key → Label ($)
var _section_had_affordable: Dictionary = {}   # key → bool
var _bob_tweens:             Dictionary = {}   # key → Tween

var _idle_timer:   float = 0.0
var _idle_showing: bool  = false
var _idle_tween:   Tween = null
var _idle_label:   Label = null

var _drawer_open := false
const _DRAWER_W  := 300.0

var _loan_btn: Button = null


func _ready() -> void:
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.passive_rate_changed.connect(_on_passive_rate_changed)
	EventBus.tap_value_changed.connect(_on_tap_value_changed)
	EventBus.item_purchased.connect(_on_item_purchased)
	EventBus.offline_income_collected.connect(_on_offline_income)
	EventBus.game_days_changed.connect(_on_game_days_changed)
	EventBus.portfolio_changed.connect(_on_portfolio_changed)
	AdManager.loan_rewarded.connect(_on_loan_rewarded)

	_apply_theme()
	hamburger_btn.pressed.connect(_toggle_drawer)
	drawer_overlay.pressed.connect(_toggle_drawer)
	_style_hamburger_btn()
	_build_lists()
	_refresh_ui()
	await get_tree().process_frame
	_create_section_indicators()
	_create_idle_hint()


func _process(delta: float) -> void:
	_idle_timer += delta
	if not _idle_showing and _idle_timer >= 10.0:
		_show_idle_hint()
	_refresh_loan_button()


# -------------------------------------------------------
# Input — entire background is the tap target.
# _input() fires before GUI so background taps always
# register. UpgradeDrawer rect check prevents game taps
# while pressing upgrade buttons.
# Do NOT call set_input_as_handled() — breaks buttons.
# -------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch \
			or event is InputEventScreenDrag \
			or (event is InputEventMouseButton and event.pressed):
		_reset_idle()

	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed \
			and not DisplayServer.is_touchscreen_available():
		pos = event.position
	else:
		return
	if _drawer_open:
		return
	GameManager.tap()
	_spawn_tap_label(pos, GameManager.get_effective_tap_value())


# -------------------------------------------------------
# EventBus handlers
# -------------------------------------------------------

func _on_resource_changed(amount: float) -> void:
	resource_label.text = _cur(amount)
	_update_stage(amount)
	_refresh_all_buttons()
	_update_section_indicators()


func _on_passive_rate_changed(rate: float) -> void:
	per_sec_label.text = "%s / day" % _cur(rate) if rate > 0.0 else ""
	_refresh_retirement()


func _on_tap_value_changed(_val: float) -> void:
	salary_label.text = "%s: %s" % [
		GameConfig.TAP_STAT_LABEL,
		_cur(GameManager.get_effective_tap_value() * GameConfig.TAP_STAT_MULTIPLIER)
	]


func _on_item_purchased(track: int, index: int) -> void:
	_refresh_track_button(track, index)
	var key := "track_%d" % track
	_burst_at_upgrade(key, "Item_%d_%d" % [track, index])


func _on_offline_income(amount: float) -> void:
	resource_label.text = "+%s while away!" % _cur(amount)
	await get_tree().create_timer(2.5).timeout
	resource_label.text = _cur(GameManager.resources)


func _on_game_days_changed(days: float) -> void:
	var years: int       = int(days / 365.0)
	var day_in_year: int = int(days) % 365
	days_label.text = "Day %d  ·  Year %d" % [day_in_year + 1, years]
	_refresh_retirement()


func _on_portfolio_changed(total_invested: float, dividends: float) -> void:
	portfolio_label.text = "%s: %s  |  %s: %s" % [
		GameConfig.PORTFOLIO_LABEL,  _cur(total_invested + dividends),
		GameConfig.DIVIDENDS_LABEL,  _cur(dividends),
	]
	_refresh_retirement()


# -------------------------------------------------------
# Wealth / progress stage — watermark in tap zone
# -------------------------------------------------------

func _update_stage(amount: float) -> void:
	var new_label: String = GameConfig.STAGES[0]["label"]
	for s in GameConfig.STAGES:
		if amount >= float(s["threshold"]):
			new_label = s["label"]
	if stage_label.text == new_label:
		return
	stage_label.text = new_label
	var tween := create_tween()
	tween.tween_property(stage_label, "modulate:a", 0.7, 0.35)
	tween.tween_property(stage_label, "modulate:a", 0.15, 1.2)


# -------------------------------------------------------
# UI builders — collapsible sections (accordion)
# -------------------------------------------------------

func _make_btn(min_h: int = 52) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, min_h)
	var lbl := Label.new()
	lbl.name = "InnerLabel"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	btn.add_child(lbl)
	return btn


func _set_btn(btn: Button, t: String, disabled: bool) -> void:
	(btn.get_node("InnerLabel") as Label).text = t
	btn.disabled = disabled
	(btn.get_node("InnerLabel") as Label).modulate = \
		Color(1, 1, 1, 0.5) if disabled else Color(1, 1, 1, 1)


func _build_lists() -> void:
	for child in upgrade_list.get_children():
		child.queue_free()
	_loan_btn = null

	_add_loan_button()

	var tracks := [GameConfig.TRACK_A, GameConfig.TRACK_B, GameConfig.TRACK_C, GameConfig.TRACK_D]
	for track in range(tracks.size()):
		_add_section(track)
		var min_h: int = 60 if track == 1 else 52   # Track B buttons are taller (more text)
		for i in range(tracks[track].size()):
			var btn := _make_btn(min_h)
			btn.name = "Item_%d_%d" % [track, i]
			btn.pressed.connect(_on_track_button_pressed.bind(track, i))
			_section_container(track).add_child(btn)
			_refresh_track_button(track, i)

	if OS.is_debug_build():
		_add_debug_buttons()


func _add_section(track: int) -> void:
	var key := "track_%d" % track
	var hdr := Button.new()
	hdr.name = "Header_%s" % key
	hdr.text = _section_label(key)
	hdr.custom_minimum_size = Vector2(0, 36)
	hdr.add_theme_color_override("font_color", GameConfig.COLOR_PRIMARY)
	hdr.add_theme_font_size_override("font_size", 15)
	hdr.pressed.connect(_toggle_section.bind(key))
	upgrade_list.add_child(hdr)

	var container := VBoxContainer.new()
	container.name    = "Section_%s" % key
	container.visible = not _collapsed[key]
	container.add_theme_constant_override("separation", 4)
	upgrade_list.add_child(container)


func _section_container(track: int) -> VBoxContainer:
	return upgrade_list.get_node("Section_track_%d" % track) as VBoxContainer


func _track_title(track: int) -> String:
	return ([GameConfig.TRACK_A_TITLE, GameConfig.TRACK_B_TITLE, GameConfig.TRACK_C_TITLE, GameConfig.TRACK_D_TITLE] as Array)[track]


func _section_label(key: String) -> String:
	var track := int(key.substr(6))   # "track_" = 6 chars
	var arrow: String = "▼" if not _collapsed[key] else "▶"
	return "── %s %s" % [_track_title(track), arrow]


func _toggle_section(key: String) -> void:
	var was_collapsed: bool = _collapsed[key]
	for k in _collapsed.keys():
		_collapsed[k] = true
		var c := upgrade_list.get_node_or_null("Section_%s" % k) as VBoxContainer
		var h := upgrade_list.get_node_or_null("Header_%s" % k)  as Button
		if c: c.visible = false
		if h: h.text = _section_label(k)
	if was_collapsed:
		_collapsed[key] = false
		var container := upgrade_list.get_node_or_null("Section_%s" % key) as VBoxContainer
		var hdr       := upgrade_list.get_node_or_null("Header_%s" % key)  as Button
		if container: container.visible = true
		if hdr:       hdr.text = _section_label(key)
	call_deferred("_update_section_indicators")


func _on_track_button_pressed(track: int, index: int) -> void:
	GameManager.buy_item(track, index)


# -------------------------------------------------------
# Button refresh
# -------------------------------------------------------

func _refresh_track_button(track: int, index: int) -> void:
	var key := "track_%d" % track
	var container := upgrade_list.get_node_or_null("Section_%s" % key) as VBoxContainer
	if container == null:
		return
	var btn := container.get_node_or_null("Item_%d_%d" % [track, index]) as Button
	if btn == null:
		return

	match track:
		0:   # one-time tap boosters
			var item: Dictionary = GameConfig.TRACK_A[index]
			if GameManager.track_a_purchased[index]:
				_set_btn(btn, "%s  [Completed]" % item["name"], true)
			else:
				_set_btn(btn,
					"%s — %s — Cost: %s" % [item["name"], item["description"], _cur(item["cost"])],
					not GameManager.can_afford(0, index))
		1:   # repeatable generators
			var item: Dictionary = GameConfig.TRACK_B[index]
			var owned: int       = GameManager.track_b_owned[index]
			var cost: float      = GameManager.get_item_cost(1, index)
			var total_in: float  = GameManager.get_total_invested_in(index)
			var income: float    = float(owned) * float(item["income_per_sec"])
			var t: String
			if owned == 0:
				t = "%s — %s — Buy: %s" % [item["name"], item["description"], _cur(cost)]
			else:
				t = "%s [x%d] | In: %s | +%s/day | Next: %s" % [
					item["name"], owned, _cur(total_in), _cur(income), _cur(cost)
				]
			_set_btn(btn, t, not GameManager.can_afford(1, index))
		2:   # one-time passive multipliers
			var item: Dictionary = GameConfig.TRACK_C[index]
			if GameManager.track_c_purchased[index]:
				_set_btn(btn, "%s  [Active]" % item["name"], true)
			else:
				_set_btn(btn,
					"%s — %s — Cost: %s" % [item["name"], item["description"], _cur(item["cost"])],
					not GameManager.can_afford(2, index))
		3:   # one-time tap multipliers
			var item: Dictionary = GameConfig.TRACK_D[index]
			if GameManager.track_d_purchased[index]:
				_set_btn(btn, "%s  [Active]" % item["name"], true)
			else:
				_set_btn(btn,
					"%s — %s — Cost: %s" % [item["name"], item["description"], _cur(item["cost"])],
					not GameManager.can_afford(3, index))


func _refresh_retirement() -> void:
	var years_elapsed: float   = GameManager.game_days / 365.0
	var years_remaining: float = max(0.0, GameConfig.GOAL_AGE - years_elapsed)
	var estimate: float        = GameManager.get_retirement_estimate()
	if years_remaining <= 0.0:
		retirement_label.text = "%s  Nest egg: %s" % [GameConfig.GOAL_MET_LABEL, _cur(estimate)]
	else:
		retirement_label.text = "%s in ~%dyr  ·  est. %s" % [
			GameConfig.GOAL_LABEL, int(ceil(years_remaining)), _cur(estimate)
		]


func _refresh_all_buttons() -> void:
	var sizes := [GameConfig.TRACK_A.size(), GameConfig.TRACK_B.size(), GameConfig.TRACK_C.size(), GameConfig.TRACK_D.size()]
	for track in range(sizes.size()):
		for i in range(sizes[track]):
			_refresh_track_button(track, i)


func _refresh_ui() -> void:
	resource_label.text = _cur(GameManager.resources)
	salary_label.text   = "%s: %s" % [
		GameConfig.TAP_STAT_LABEL,
		_cur(GameManager.get_effective_tap_value() * GameConfig.TAP_STAT_MULTIPLIER)
	]
	if GameManager.passive_rate > 0.0:
		per_sec_label.text = "%s / day" % _cur(GameManager.passive_rate)
	var portfolio_val: float = GameManager.total_invested + GameManager.total_dividends_earned
	portfolio_label.text = "%s: %s  |  %s: %s" % [
		GameConfig.PORTFOLIO_LABEL, _cur(portfolio_val),
		GameConfig.DIVIDENDS_LABEL, _cur(GameManager.total_dividends_earned),
	]
	_refresh_retirement()
	_refresh_all_buttons()
	_update_stage(GameManager.resources)


# -------------------------------------------------------
# Loan / rewarded ad button
# -------------------------------------------------------

func _add_loan_button() -> void:
	var btn := _make_btn(52)
	btn.name = "LoanButton"
	btn.pressed.connect(_on_loan_pressed)
	upgrade_list.add_child(btn)
	_loan_btn = btn
	_refresh_loan_button()


func _refresh_loan_button() -> void:
	if _loan_btn == null or not is_instance_valid(_loan_btn):
		return
	var inner := _loan_btn.get_node_or_null("InnerLabel") as Label
	if AdManager.can_request_loan():
		_set_btn(_loan_btn,
			"%s — Watch Ad → +%s" % [GameConfig.AD_LOAN_LABEL, _cur(GameConfig.AD_LOAN_AMOUNT)],
			false)
		if inner:
			inner.add_theme_color_override("font_color", GameConfig.COLOR_GOLD)
	else:
		_set_btn(_loan_btn,
			"%s — Ready in %s" % [GameConfig.AD_LOAN_LABEL, AdManager.cooldown_label()],
			true)


func _on_loan_pressed() -> void:
	AdManager.request_loan()


func _on_loan_rewarded(_amount: float) -> void:
	_spawn_upgrade_burst(hamburger_btn.global_position + hamburger_btn.size / 2.0)


# -------------------------------------------------------
# Debug buttons (debug builds only)
# -------------------------------------------------------

func _add_debug_buttons() -> void:
	var specs := [
		["[D] +$100K", func(): GameManager.add_resources(100_000.0)],
		["[D] +$1B",   func(): GameManager.add_resources(1_000_000_000.0)],
		["[D] RESET",  func(): _debug_reset_game()],
	]
	for spec in specs:
		var btn := Button.new()
		btn.text = spec[0]
		btn.pressed.connect(spec[1])
		upgrade_list.add_child(btn)


func _debug_reset_game() -> void:
	SaveManager.delete_save()
	GameManager.reset()
	_build_lists()
	_refresh_ui()
	call_deferred("_create_section_indicators")


# -------------------------------------------------------
# Visual effects
# -------------------------------------------------------

func _spawn_tap_label(pos: Vector2, amount: float) -> void:
	var lbl := Label.new()
	lbl.text = "+%s" % _cur(amount)
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", GameConfig.COLOR_PRIMARY)
	lbl.position     = pos - Vector2(40.0, 20.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", pos.y - 120.0, 0.9) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.2)
	await tween.finished
	lbl.queue_free()


func _burst_at_upgrade(section_key: String, btn_name: String) -> void:
	var container := upgrade_list.get_node_or_null("Section_%s" % section_key) as VBoxContainer
	if container == null:
		return
	var btn := container.get_node_or_null(btn_name) as Button
	if btn == null:
		return
	_spawn_upgrade_burst(btn.global_position + btn.size / 2.0)


func _spawn_upgrade_burst(origin: Vector2) -> void:
	for i in range(_BURST_COUNT):
		_spawn_burst_particle(origin, i)


func _spawn_burst_particle(origin: Vector2, index: int) -> void:
	var lbl := Label.new()
	lbl.text = "$"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", GameConfig.COLOR_GOLD)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.position     = origin
	add_child(lbl)
	var angle  := (TAU / float(_BURST_COUNT)) * float(index) + randf() * 0.5
	var dist   := randf_range(60.0, 130.0)
	var target := origin + Vector2(cos(angle), sin(angle)) * dist
	var tween  := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position",    target,          0.65) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(lbl, "scale",       Vector2(1.5, 1.5), 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a",  0.0,               0.5).set_delay(0.15)
	await tween.finished
	lbl.queue_free()


# -------------------------------------------------------
# Idle hint — configurable text, pulses after 10s idle
# -------------------------------------------------------

func _create_idle_hint() -> void:
	_idle_label = Label.new()
	_idle_label.text = GameConfig.IDLE_HINT
	_idle_label.add_theme_font_size_override("font_size", 26)
	_idle_label.add_theme_color_override("font_color", GameConfig.COLOR_PRIMARY)
	_idle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_idle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_idle_label.visible  = false
	_idle_label.modulate.a = 0.0
	_idle_label.anchor_left   = 0.0
	_idle_label.anchor_right  = 1.0
	_idle_label.anchor_top    = 0.0
	_idle_label.anchor_bottom = 0.0
	add_child(_idle_label)
	var zone_top:    float = ($TopHUD as Control).global_position.y + ($TopHUD as Control).size.y
	var zone_bottom: float = get_viewport().get_visible_rect().size.y
	var mid:         float = (zone_top + zone_bottom) * 0.5
	_idle_label.offset_top    = mid - 20.0
	_idle_label.offset_bottom = mid + 20.0
	_show_idle_hint()


func _show_idle_hint() -> void:
	if _idle_label == null or not is_instance_valid(_idle_label):
		return
	_idle_showing = true
	_idle_label.visible    = true
	_idle_label.modulate.a = 0.0
	if is_instance_valid(_idle_tween):
		_idle_tween.kill()
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(_idle_label, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_interval(1.65)
	_idle_tween.tween_property(_idle_label, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_interval(3.0)


func _hide_idle_hint() -> void:
	_idle_showing = false
	if is_instance_valid(_idle_tween):
		_idle_tween.kill()
		_idle_tween = null
	if _idle_label != null and is_instance_valid(_idle_label):
		_idle_label.visible    = false
		_idle_label.modulate.a = 0.0


func _reset_idle() -> void:
	_idle_timer = 0.0
	if _idle_showing:
		_hide_idle_hint()


# -------------------------------------------------------
# Section affordability indicators
# -------------------------------------------------------

func _create_section_indicators() -> void:
	for key in _section_indicators.keys():
		_stop_bob(key)
		var old: Label = _section_indicators[key]
		if is_instance_valid(old):
			old.queue_free()
	_section_indicators.clear()
	_section_had_affordable.clear()
	for key in _collapsed.keys():
		_section_had_affordable[key] = false
		var lbl := Label.new()
		lbl.text = "$"
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", GameConfig.COLOR_GOLD)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.visible = false
		add_child(lbl)
		_section_indicators[key] = lbl
	_update_section_indicators()


func _update_section_indicators() -> void:
	for key in _section_indicators.keys():
		var lbl: Label = _section_indicators[key]
		if not is_instance_valid(lbl):
			continue
		var affordable := _has_affordable(key)

		var hdr := upgrade_list.get_node_or_null("Header_%s" % key) as Button
		if hdr:
			hdr.add_theme_color_override("font_color",
				GameConfig.COLOR_HEADER_LIT if affordable else GameConfig.COLOR_PRIMARY)

		if affordable and not _section_had_affordable.get(key, false):
			_flash_header(key)
		_section_had_affordable[key] = affordable

		if not affordable:
			lbl.visible = false
			_stop_bob(key)
			continue

		lbl.visible = true

		if _collapsed[key]:
			if not _bob_tweens.has(key):
				_start_bob(key)
		else:
			_stop_bob(key)
			var btn := _find_best_affordable_btn(key)
			if btn != null:
				lbl.position = btn.global_position + Vector2(6.0, btn.size.y * 0.5 - 10.0)
			else:
				lbl.visible = false
	_update_hamburger_notif()


func _has_affordable(key: String) -> bool:
	var track := int(key.substr(6))
	var sizes := [GameConfig.TRACK_A.size(), GameConfig.TRACK_B.size(), GameConfig.TRACK_C.size(), GameConfig.TRACK_D.size()]
	for i in range(sizes[track]):
		if GameManager.can_afford(track, i):
			return true
	return false


func _find_best_affordable_btn(key: String) -> Button:
	var track     := int(key.substr(6))
	var container := upgrade_list.get_node_or_null("Section_%s" % key) as VBoxContainer
	if container == null:
		return null
	var sizes     := [GameConfig.TRACK_A.size(), GameConfig.TRACK_B.size(), GameConfig.TRACK_C.size(), GameConfig.TRACK_D.size()]
	var best_idx  := -1
	var best_cost := 0.0
	for i in range(sizes[track]):
		if GameManager.can_afford(track, i):
			var cost: float = GameManager.get_item_cost(track, i)
			if cost > best_cost:
				best_idx  = i
				best_cost = cost
	if best_idx >= 0:
		return container.get_node_or_null("Item_%d_%d" % [track, best_idx]) as Button
	return null


func _flash_header(key: String) -> void:
	var hdr := upgrade_list.get_node_or_null("Header_%s" % key) as Button
	if hdr == null:
		return
	var tween := create_tween()
	tween.tween_property(hdr, "modulate", Color(1.6, 1.4, 0.3, 1.0), 0.12)
	tween.tween_property(hdr, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)


func _start_bob(key: String) -> void:
	_stop_bob(key)
	var lbl: Label = _section_indicators.get(key)
	if lbl == null or not is_instance_valid(lbl):
		return
	var hdr := upgrade_list.get_node_or_null("Header_%s" % key) as Button
	if hdr == null:
		return
	var base := hdr.global_position + Vector2(6.0, hdr.size.y * 0.5 - 10.0)
	lbl.position = base
	var tween := create_tween().set_loops()
	tween.tween_property(lbl, "position:y", base.y - 6.0, 0.45) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(lbl, "position:y", base.y + 6.0, 0.45) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_bob_tweens[key] = tween


func _stop_bob(key: String) -> void:
	if _bob_tweens.has(key):
		var t: Tween = _bob_tweens[key]
		if is_instance_valid(t):
			t.kill()
		_bob_tweens.erase(key)


func _toggle_drawer() -> void:
	_drawer_open = not _drawer_open
	drawer_overlay.visible = _drawer_open
	hamburger_btn.text = "✕" if _drawer_open else "☰"
	var tween := create_tween()
	tween.set_parallel(true)
	if _drawer_open:
		tween.tween_property(upgrade_drawer, "offset_left",  0.0,        0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(upgrade_drawer, "offset_right", _DRAWER_W,  0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(upgrade_drawer, "offset_left",  -_DRAWER_W, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(upgrade_drawer, "offset_right", 0.0,        0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)


func _style_hamburger_btn() -> void:
	hamburger_btn.add_theme_font_size_override("font_size", 28)
	hamburger_btn.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.10, 0.10, 0.20, 0.88)
	style.corner_radius_top_left     = 30
	style.corner_radius_top_right    = 30
	style.corner_radius_bottom_left  = 30
	style.corner_radius_bottom_right = 30
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size  = 6
	hamburger_btn.add_theme_stylebox_override("normal", style)
	var style_h := style.duplicate() as StyleBoxFlat
	style_h.bg_color = Color(0.18, 0.18, 0.32, 0.95)
	hamburger_btn.add_theme_stylebox_override("hover",   style_h)
	hamburger_btn.add_theme_stylebox_override("pressed", style_h)
	# Overlay semi-transparent style
	var ov_style := StyleBoxFlat.new()
	ov_style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	drawer_overlay.add_theme_stylebox_override("normal",  ov_style)
	drawer_overlay.add_theme_stylebox_override("hover",   ov_style)
	drawer_overlay.add_theme_stylebox_override("pressed", ov_style)


func _update_hamburger_notif() -> void:
	if not is_instance_valid(hamburger_btn):
		return
	if _drawer_open:
		return
	var any_affordable := false
	for key in _collapsed.keys():
		if _has_affordable(key):
			any_affordable = true
			break
	hamburger_btn.add_theme_color_override("font_color",
		GameConfig.COLOR_GOLD if any_affordable else Color.WHITE)


# -------------------------------------------------------
# Theme / styling
# -------------------------------------------------------

func _apply_theme() -> void:
	stage_label.modulate.a = 0.15

	var hud := StyleBoxFlat.new()
	hud.bg_color                   = Color(1.0, 1.0, 1.0, 0.93)
	hud.corner_radius_bottom_left  = 18
	hud.corner_radius_bottom_right = 18
	hud.content_margin_left        = 16.0
	hud.content_margin_right       = 16.0
	hud.content_margin_top         = 6.0
	hud.content_margin_bottom      = 10.0
	hud.shadow_color               = Color(0.0, 0.0, 0.0, 0.10)
	hud.shadow_size                = 8
	$TopHUD.add_theme_stylebox_override("panel", hud)

	var drawer := StyleBoxFlat.new()
	drawer.bg_color                       = Color(1.0, 1.0, 1.0, 0.97)
	drawer.corner_radius_top_left         = 0
	drawer.corner_radius_top_right        = 22
	drawer.corner_radius_bottom_left      = 0
	drawer.corner_radius_bottom_right     = 22
	drawer.content_margin_left      = 8.0
	drawer.content_margin_right     = 8.0
	drawer.content_margin_top       = 8.0
	drawer.content_margin_bottom    = 4.0
	drawer.shadow_color             = Color(0.0, 0.0, 0.0, 0.12)
	drawer.shadow_size              = 10
	$UpgradeDrawer.add_theme_stylebox_override("panel", drawer)


# -------------------------------------------------------
# Number formatting
# -------------------------------------------------------

# Formats a float as a compact string: 1234567 → "1.23M"
func _fmt(n: float) -> String:
	if n >= 1_000_000_000_000_000.0:
		return "%.2fQa" % (n / 1_000_000_000_000_000.0)
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


# Applies the game's currency format (set in GameConfig.CURRENCY_FORMAT)
func _cur(n: float) -> String:
	return GameConfig.CURRENCY_FORMAT % _fmt(n)
