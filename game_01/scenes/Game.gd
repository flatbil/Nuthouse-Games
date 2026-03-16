extends Control

# -------------------------------------------------------
# Game.gd — UI only. Reads state via EventBus signals.
# Calls GameManager for all state changes.
# The entire background is the tap target; input is caught
# via _unhandled_input so UI controls still consume their
# own events normally.
# -------------------------------------------------------

@onready var resource_label:   Label               = $TopHUD/Stats/ResourceLabel
@onready var salary_label:     Label               = $TopHUD/Stats/SalaryLabel
@onready var per_sec_label:    Label               = $TopHUD/Stats/PerSecLabel
@onready var days_label:       Label               = $TopHUD/Stats/DaysLabel
@onready var portfolio_label:  Label               = $TopHUD/Stats/PortfolioLabel
@onready var retirement_label: Label               = $TopHUD/Stats/RetirementLabel
@onready var upgrade_list:     VBoxContainer       = $UpgradeDrawer/ScrollContainer/UpgradeList
@onready var stage_label:      Label               = $StageLabel
@onready var _coin_sfx:        AudioStreamPlayer   = $CoinSound
@onready var _tada_sfx:        AudioStreamPlayer   = $TadaSound
@onready var hamburger_btn:  Button         = $HamburgerBtn
@onready var drawer_overlay: Button         = $DrawerOverlay
@onready var upgrade_drawer: PanelContainer = $UpgradeDrawer

var _collapsed: Dictionary = {
	"career":         true,
	"investments":    true,
	"strategies":     true,
	"salary_boosts":  true,
	"ventures":       true,
	"investors":      true,
}

const _TITLES: Dictionary = {
	"career":         "CAREER",
	"investments":    "INVESTMENTS",
	"strategies":     "STRATEGIES",
	"salary_boosts":  "RAISES",
	"ventures":       "VENTURES",
	"investors":      "INVESTORS",
}

const _MONEY_GREEN    := Color(0.106, 0.369, 0.125, 1.0)
const _GOLD           := Color(0.87,  0.70,  0.0,   1.0)
const _HEADER_LIT     := Color(0.15,  0.72,  0.28,  1.0)
const _BURST_COUNT    := 8

var _section_indicators:     Dictionary = {}  # key → Label ($)
var _section_had_affordable: Dictionary = {}  # key → bool
var _bob_tweens:             Dictionary = {}  # key → Tween

var _drawer_open := false
const _DRAWER_W  := 300.0

var _loan_btn: Button = null
var _career_refresh_timer: float = 0.0

var _settings_overlay:  Control = null
var _settings_visible:  bool    = false

var _idle_timer:   float = 0.0
var _idle_showing: bool  = false
var _idle_tween:   Tween = null
var _idle_label:   Label = null

const STAGES: Array = [
	{"threshold": 0.0,                 "label": "Starting Out"},
	{"threshold": 1_000.0,             "label": "Getting By"},
	{"threshold": 50_000.0,            "label": "Building Wealth"},
	{"threshold": 1_000_000.0,         "label": "Comfortable"},
	{"threshold": 50_000_000.0,        "label": "Wealthy"},
	{"threshold": 1_000_000_000.0,     "label": "Rich"},
	{"threshold": 1_000_000_000_000.0, "label": "Ultra Rich"},
	{"threshold": 1.0e15,              "label": "Corporate Empire"},
	{"threshold": 1.0e18,              "label": "Buy-N-Large"},
	{"threshold": 1.0e21,              "label": "Galactic Mogul"},
	{"threshold": 1.0e24,              "label": "Universal Overlord"},
	{"threshold": 1.0e30,              "label": "Beyond Comprehension"},
]


func _ready() -> void:
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.passive_rate_changed.connect(_on_passive_rate_changed)
	EventBus.tap_value_changed.connect(_on_tap_value_changed)
	EventBus.career_purchased.connect(_on_career_purchased)
	EventBus.investment_purchased.connect(_on_investment_purchased)
	EventBus.strategy_purchased.connect(_on_strategy_purchased)
	EventBus.venture_purchased.connect(_on_venture_purchased)
	EventBus.investor_purchased.connect(_on_investor_purchased)
	EventBus.salary_boost_purchased.connect(_on_salary_boost_purchased)
	EventBus.offline_income_collected.connect(_on_offline_income)
	EventBus.game_days_changed.connect(_on_game_days_changed)
	EventBus.portfolio_changed.connect(_on_portfolio_changed)
	AdManager.loan_rewarded.connect(_on_loan_rewarded)
	EventBus.game_ended.connect(_on_game_ended)

	_apply_theme()
	hamburger_btn.pressed.connect(_toggle_drawer)
	drawer_overlay.pressed.connect(_toggle_drawer)
	_style_hamburger_btn()
	_build_lists()
	_refresh_ui()
	await get_tree().process_frame
	_create_section_indicators()
	_create_idle_hint()
	_build_settings_button()
	_build_settings_overlay()


func _process(delta: float) -> void:
	_idle_timer += delta
	_career_refresh_timer += delta
	if not _idle_showing and _idle_timer >= 10.0:
		_show_idle_hint()
	_refresh_loan_button()
	if _career_refresh_timer >= 1.0:
		_career_refresh_timer = 0.0
		_refresh_active_career_progress()


# -------------------------------------------------------
# Input — entire background is the tap target.
# Uses _input (fires before GUI) so background taps always
# register. We skip the UpgradeDrawer rect to avoid firing
# a game tap when the player is pressing an upgrade button.
# Do NOT call set_input_as_handled() — that would block GUI
# events and break buttons/accordion headers.
# -------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _settings_visible:
		return

	# Dismiss idle hint on any meaningful input (before rect checks,
	# so button taps and scroll also dismiss it)
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
	if _coin_sfx.stream != null and Settings.sfx_enabled:
		_coin_sfx.volume_db = Settings.sfx_volume_db()
		_coin_sfx.play()


# -------------------------------------------------------
# EventBus handlers
# -------------------------------------------------------

func _on_resource_changed(amount: float) -> void:
	resource_label.text = "$" + _fmt(amount)
	_update_stage(amount)
	_refresh_all_buttons()
	_update_section_indicators()


func _on_passive_rate_changed(rate: float) -> void:
	per_sec_label.text = "$%s / day" % _fmt(rate) if rate > 0.0 else ""
	_refresh_retirement()


func _on_tap_value_changed(_val: float) -> void:
	salary_label.text = "Annual Salary: $%s" % _fmt(GameManager.get_effective_tap_value() * 2082.0)


func _on_career_purchased(index: int) -> void:
	_refresh_career_button(index)
	_burst_at_upgrade("career", "Career_%d" % index)


func _on_investment_purchased(index: int) -> void:
	_refresh_investment_button(index)
	_burst_at_upgrade("investments", "Investment_%d" % index)
	if _tada_sfx.stream != null and Settings.sfx_enabled:
		_tada_sfx.pitch_scale = randf_range(0.95, 1.05)
		_tada_sfx.volume_db   = Settings.sfx_volume_db()
		_tada_sfx.play()


func _on_strategy_purchased(index: int) -> void:
	_refresh_strategy_button(index)
	_refresh_all_buttons()  # strategy multiplier affects all investment displays
	_burst_at_upgrade("strategies", "Strategy_%d" % index)


func _on_venture_purchased(index: int) -> void:
	_refresh_venture_button(index)
	_burst_at_upgrade("ventures", "Venture_%d" % index)
	if _tada_sfx.stream != null and Settings.sfx_enabled:
		_tada_sfx.pitch_scale = randf_range(0.95, 1.05)
		_tada_sfx.volume_db   = Settings.sfx_volume_db()
		_tada_sfx.play()


func _on_investor_purchased(index: int) -> void:
	_refresh_investor_button(index)
	_refresh_all_buttons()  # investor multiplier affects all venture displays
	_burst_at_upgrade("investors", "Investor_%d" % index)
	if _tada_sfx.stream != null and Settings.sfx_enabled:
		_tada_sfx.pitch_scale = randf_range(0.95, 1.05)
		_tada_sfx.volume_db   = Settings.sfx_volume_db()
		_tada_sfx.play()


func _on_salary_boost_purchased(index: int) -> void:
	_refresh_salary_boost_button(index)
	_refresh_all_buttons()
	_burst_at_upgrade("salary_boosts", "SalaryBoost_%d" % index)
	if _tada_sfx.stream != null and Settings.sfx_enabled:
		_tada_sfx.pitch_scale = randf_range(0.95, 1.05)
		_tada_sfx.volume_db   = Settings.sfx_volume_db()
		_tada_sfx.play()


func _on_salary_boost_pressed(index: int) -> void:
	GameManager.buy_salary_boost(index)


func _on_offline_income(amount: float) -> void:
	resource_label.text = "+$%s while away!" % _fmt(amount)
	await get_tree().create_timer(2.5).timeout
	resource_label.text = "$" + _fmt(GameManager.resources)


func _on_game_days_changed(days: float) -> void:
	var age: int         = int(GameManager.START_AGE + days / 365.0)
	var day_in_year: int = int(days) % 365
	days_label.text = "Day %d  ·  Age %d" % [day_in_year + 1, age]
	_refresh_retirement()


func _on_portfolio_changed(total_invested: float, dividends: float) -> void:
	portfolio_label.text = "Portfolio: $%s  |  Dividends: $%s" % [
		_fmt(total_invested + dividends), _fmt(dividends)
	]
	_refresh_retirement()


# -------------------------------------------------------
# Wealth stage — watermark text, placeholder for art
# -------------------------------------------------------

func _update_stage(amount: float) -> void:
	var new_label: String = STAGES[0]["label"]
	for s in STAGES:
		if amount >= float(s["threshold"]):
			new_label = s["label"]
	if stage_label.text == new_label:
		return
	stage_label.text = new_label
	# Brief flash on stage unlock
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
	_add_section("career")
	for i in range(GameManager.CAREERS.size()):
		var btn := _make_btn(52)
		btn.name = "Career_%d" % i
		btn.pressed.connect(_on_career_pressed.bind(i))
		_section_container("career").add_child(btn)
		var finish_btn := _make_btn(36)
		finish_btn.name = "CareerFinish_%d" % i
		finish_btn.visible = false
		finish_btn.pressed.connect(_on_career_finish_pressed.bind(i))
		(finish_btn.get_node("InnerLabel") as Label).add_theme_color_override("font_color", _GOLD)
		_section_container("career").add_child(finish_btn)
		_refresh_career_button(i)

	_add_section("investments")
	for i in range(GameManager.INVESTMENTS.size()):
		var btn := _make_btn(60)
		btn.name = "Investment_%d" % i
		btn.pressed.connect(_on_investment_pressed.bind(i))
		_section_container("investments").add_child(btn)
		_refresh_investment_button(i)

	_add_section("strategies")
	for i in range(GameManager.STRATEGIES.size()):
		var btn := _make_btn(52)
		btn.name = "Strategy_%d" % i
		btn.pressed.connect(_on_strategy_pressed.bind(i))
		_section_container("strategies").add_child(btn)
		_refresh_strategy_button(i)

	_add_section("salary_boosts")
	for i in range(GameManager.SALARY_BOOSTS.size()):
		var btn := _make_btn(52)
		btn.name = "SalaryBoost_%d" % i
		btn.pressed.connect(_on_salary_boost_pressed.bind(i))
		_section_container("salary_boosts").add_child(btn)
		_refresh_salary_boost_button(i)

	_add_section("ventures")
	for i in range(GameManager.VENTURES.size()):
		var btn := _make_btn(52)
		btn.name = "Venture_%d" % i
		btn.pressed.connect(_on_venture_pressed.bind(i))
		_section_container("ventures").add_child(btn)
		_refresh_venture_button(i)

	_add_section("investors")
	for i in range(GameManager.INVESTORS.size()):
		var btn := _make_btn(52)
		btn.name = "Investor_%d" % i
		btn.pressed.connect(_on_investor_pressed.bind(i))
		_section_container("investors").add_child(btn)
		_refresh_investor_button(i)

	if OS.is_debug_build():
		_add_debug_buttons()


func _add_loan_button() -> void:
	var btn := _make_btn(52)
	btn.name = "LoanButton"
	btn.pressed.connect(_on_loan_pressed)
	btn.add_theme_color_override("font_color", _GOLD)
	upgrade_list.add_child(btn)
	_loan_btn = btn
	_refresh_loan_button()


func _refresh_loan_button() -> void:
	if _loan_btn == null or not is_instance_valid(_loan_btn):
		return
	var inner := _loan_btn.get_node_or_null("InnerLabel") as Label
	if AdManager.can_request_loan():
		_set_btn(_loan_btn, "Student Loan — Watch Ad → +$100K", false)
		if inner:
			inner.add_theme_color_override("font_color", _GOLD)
	else:
		_set_btn(_loan_btn, "Student Loan — Ready in %s" % AdManager.cooldown_label(), true)


func _on_loan_pressed() -> void:
	AdManager.request_loan()


func _on_loan_rewarded(amount: float) -> void:
	_spawn_upgrade_burst(hamburger_btn.global_position + hamburger_btn.size / 2.0)


func _on_game_ended() -> void:
	get_tree().change_scene_to_file("res://scenes/RetirementScreen.tscn")


func _add_debug_buttons() -> void:
	var specs := [
		["[D] +$100K",   func(): GameManager.add_resources(100_000.0)],
		["[D] +$1B",     func(): GameManager.add_resources(1_000_000_000.0)],
		["[D] +10 Years", func(): GameManager.debug_advance_years(10.0)],
		["[D] RESET",    func(): _debug_reset_game()],
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


func _add_section(key: String) -> void:
	var hdr := Button.new()
	hdr.name = "Header_%s" % key
	hdr.text = _section_label(key)
	hdr.custom_minimum_size = Vector2(0, 36)
	hdr.add_theme_color_override("font_color", _MONEY_GREEN)
	hdr.add_theme_font_size_override("font_size", 15)
	hdr.pressed.connect(_toggle_section.bind(key))
	upgrade_list.add_child(hdr)

	var container := VBoxContainer.new()
	container.name    = "Section_%s" % key
	container.visible = not _collapsed[key]
	container.add_theme_constant_override("separation", 4)
	upgrade_list.add_child(container)


func _section_container(key: String) -> VBoxContainer:
	return upgrade_list.get_node("Section_%s" % key) as VBoxContainer


func _section_label(key: String) -> String:
	var arrow: String = "▼" if not _collapsed[key] else "▶"
	return "── %s %s" % [_TITLES[key], arrow]


func _toggle_section(key: String) -> void:
	var was_collapsed: bool = _collapsed[key]
	# Collapse all
	for k in _collapsed.keys():
		_collapsed[k] = true
		var c := upgrade_list.get_node_or_null("Section_%s" % k) as VBoxContainer
		var h := upgrade_list.get_node_or_null("Header_%s" % k)  as Button
		if c: c.visible = false
		if h: h.text = _section_label(k)
	# Expand tapped section only if it was closed
	if was_collapsed:
		_collapsed[key] = false
		var container := upgrade_list.get_node_or_null("Section_%s" % key) as VBoxContainer
		var hdr       := upgrade_list.get_node_or_null("Header_%s" % key)  as Button
		if container: container.visible = true
		if hdr:       hdr.text = _section_label(key)
	call_deferred("_update_section_indicators")


func _on_career_pressed(index: int) -> void:
	GameManager.start_career(index)


func _on_career_finish_pressed(index: int) -> void:
	AdManager.request_career_finish(index)


func _refresh_active_career_progress() -> void:
	for i in range(GameManager.CAREERS.size()):
		if GameManager.careers_in_progress[i] >= 0.0:
			_refresh_career_button(i)


func _on_investment_pressed(index: int) -> void:
	GameManager.buy_investment(index)


func _on_strategy_pressed(index: int) -> void:
	GameManager.buy_strategy(index)


func _on_venture_pressed(index: int) -> void:
	GameManager.buy_venture(index)


func _on_investor_pressed(index: int) -> void:
	GameManager.buy_investor(index)


# -------------------------------------------------------
# Button refresh
# -------------------------------------------------------

func _refresh_career_button(index: int) -> void:
	var container := upgrade_list.get_node_or_null("Section_career") as VBoxContainer
	if container == null: return
	var btn := container.get_node_or_null("Career_%d" % index) as Button
	if btn == null: return
	var finish_btn := container.get_node_or_null("CareerFinish_%d" % index) as Button
	var c: Dictionary  = GameManager.CAREERS[index]
	var in_prog: float = GameManager.careers_in_progress[index]

	if GameManager.careers_purchased[index]:
		_set_btn(btn, "%s  [Completed]" % c["name"], true)
		if finish_btn: finish_btn.visible = false

	elif in_prog >= 0.0:
		var pct: float = min(100.0, ((GameManager.game_days - in_prog) / float(c["duration_days"])) * 100.0)
		_set_btn(btn, "Studying: %s  —  %.0f%% complete" % [c["name"], pct], true)
		if finish_btn:
			finish_btn.visible = true
			_set_btn(finish_btn, "Finish Now  ·  Watch Ad", false)

	elif not GameManager.career_prereq_met(index):
		var req: int = int(c["requires"])
		_set_btn(btn, "%s  [finish %s first]" % [c["name"], GameManager.CAREERS[req]["name"]], true)
		if finish_btn: finish_btn.visible = false

	else:
		var dur_days: float = float(c["duration_days"])
		var dur_str: String = ("~%d yr" % int(round(dur_days / 365.0))) if dur_days >= 365.0 \
			else ("~%d mo" % int(round(dur_days / 30.0)))
		_set_btn(btn,
			"%s — %s — $%s  ·  %s" % [c["name"], c["description"], _fmt(c["cost"]), dur_str],
			not GameManager.can_start_career(index))
		if finish_btn: finish_btn.visible = false


func _refresh_investment_button(index: int) -> void:
	var container := upgrade_list.get_node_or_null("Section_investments") as VBoxContainer
	if container == null: return
	var btn := container.get_node_or_null("Investment_%d" % index) as Button
	if btn == null: return
	var inv: Dictionary = GameManager.INVESTMENTS[index]
	var owned: int      = GameManager.investments_owned[index]
	var cost: float     = GameManager.get_investment_cost(index)
	var total_in: float = GameManager.get_total_invested_in(index)
	# Show effective income including strategy multipliers
	var effective: float = float(owned) * inv["income_per_sec"] * GameManager.get_strategy_multiplier()
	var t: String
	if owned == 0:
		t = "%s — %s — Buy: $%s" % [inv["name"], inv["description"], _fmt(cost)]
	else:
		t = "%s [x%d] | In: $%s | +$%s/day | Next: $%s" % [
			inv["name"], owned, _fmt(total_in), _fmt(effective), _fmt(cost)
		]
	_set_btn(btn, t, not GameManager.can_afford_investment(index))


func _refresh_strategy_button(index: int) -> void:
	var container := upgrade_list.get_node_or_null("Section_strategies") as VBoxContainer
	if container == null: return
	var btn := container.get_node_or_null("Strategy_%d" % index) as Button
	if btn == null: return
	var s: Dictionary = GameManager.STRATEGIES[index]
	if GameManager.strategies_purchased[index]:
		_set_btn(btn, "%s  [Active]" % s["name"], true)
	else:
		_set_btn(btn,
			"%s — %s — Cost: $%s" % [s["name"], s["description"], _fmt(s["cost"])],
			not GameManager.can_afford_strategy(index))


func _refresh_venture_button(index: int) -> void:
	var container := upgrade_list.get_node_or_null("Section_ventures") as VBoxContainer
	if container == null: return
	var btn := container.get_node_or_null("Venture_%d" % index) as Button
	if btn == null: return
	var v: Dictionary = GameManager.VENTURES[index]
	if GameManager.ventures_purchased[index]:
		var effective: float = v["income_per_day"] * GameManager.get_investor_multiplier()
		_set_btn(btn, "%s  [Active — +$%s/day]" % [v["name"], _fmt(effective)], true)
	else:
		_set_btn(btn,
			"%s — %s — Cost: $%s" % [v["name"], v["description"], _fmt(v["cost"])],
			not GameManager.can_afford_venture(index))


func _refresh_salary_boost_button(index: int) -> void:
	var container := upgrade_list.get_node_or_null("Section_salary_boosts") as VBoxContainer
	if container == null: return
	var btn := container.get_node_or_null("SalaryBoost_%d" % index) as Button
	if btn == null: return
	var s: Dictionary = GameManager.SALARY_BOOSTS[index]
	if GameManager.salary_boosts_purchased[index]:
		_set_btn(btn, "%s  [Active]" % s["name"], true)
	else:
		_set_btn(btn,
			"%s — %s — Cost: $%s" % [s["name"], s["description"], _fmt(s["cost"])],
			not GameManager.can_afford_salary_boost(index))


func _refresh_investor_button(index: int) -> void:
	var container := upgrade_list.get_node_or_null("Section_investors") as VBoxContainer
	if container == null: return
	var btn := container.get_node_or_null("Investor_%d" % index) as Button
	if btn == null: return
	var inv: Dictionary = GameManager.INVESTORS[index]
	if GameManager.investors_purchased[index]:
		_set_btn(btn, "%s  [Active]" % inv["name"], true)
	else:
		_set_btn(btn,
			"%s — %s — Cost: $%s" % [inv["name"], inv["description"], _fmt(inv["cost"])],
			not GameManager.can_afford_investor(index))


func _refresh_retirement() -> void:
	var age_now: float         = GameManager.START_AGE + GameManager.game_days / 365.0
	var years_remaining: float = max(0.0, GameManager.RETIRE_AGE - age_now)
	var estimate: float        = GameManager.get_retirement_estimate()
	if years_remaining <= 0.0:
		retirement_label.text = "RETIRED!  Nest egg: $%s" % _fmt(estimate)
	else:
		retirement_label.text = "Retire in ~%dyr  ·  est. $%s" % [
			int(ceil(years_remaining)), _fmt(estimate)
		]


func _refresh_all_buttons() -> void:
	for i in range(GameManager.CAREERS.size()):
		_refresh_career_button(i)
	for i in range(GameManager.INVESTMENTS.size()):
		_refresh_investment_button(i)
	for i in range(GameManager.STRATEGIES.size()):
		_refresh_strategy_button(i)
	for i in range(GameManager.SALARY_BOOSTS.size()):
		_refresh_salary_boost_button(i)
	for i in range(GameManager.VENTURES.size()):
		_refresh_venture_button(i)
	for i in range(GameManager.INVESTORS.size()):
		_refresh_investor_button(i)


func _refresh_ui() -> void:
	resource_label.text = "$" + _fmt(GameManager.resources)
	salary_label.text   = "Annual Salary: $%s" % _fmt(GameManager.get_effective_tap_value() * 2082.0)
	if GameManager.passive_rate > 0.0:
		per_sec_label.text = "$%s / day" % _fmt(GameManager.passive_rate)
	var portfolio_val: float = GameManager.total_invested + GameManager.total_dividends_earned
	portfolio_label.text = "Portfolio: $%s  |  Dividends: $%s" % [
		_fmt(portfolio_val), _fmt(GameManager.total_dividends_earned)
	]
	_refresh_retirement()
	_refresh_all_buttons()
	_update_stage(GameManager.resources)


# -------------------------------------------------------
# Visual effects
# -------------------------------------------------------

func _spawn_tap_label(pos: Vector2, amount: float) -> void:
	var lbl := Label.new()
	lbl.text = "+$%s" % _fmt(amount)
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", _MONEY_GREEN)
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


func _burst_at_upgrade(section: String, btn_name: String) -> void:
	var container := upgrade_list.get_node_or_null("Section_%s" % section) as VBoxContainer
	if container == null: return
	var btn := container.get_node_or_null(btn_name) as Button
	if btn == null: return
	_spawn_upgrade_burst(btn.global_position + btn.size / 2.0)


func _spawn_upgrade_burst(origin: Vector2) -> void:
	for i in range(_BURST_COUNT):
		_spawn_burst_particle(origin, i)


func _spawn_burst_particle(origin: Vector2, index: int) -> void:
	var lbl := Label.new()
	lbl.text = "$"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", _GOLD)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.position     = origin
	add_child(lbl)
	var angle  := (TAU / float(_BURST_COUNT)) * float(index) + randf() * 0.5
	var dist   := randf_range(60.0, 130.0)
	var target := origin + Vector2(cos(angle), sin(angle)) * dist
	var tween  := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position", target, 0.65) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(lbl, "scale",      Vector2(1.5, 1.5), 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0,               0.5).set_delay(0.15)
	await tween.finished
	lbl.queue_free()


# -------------------------------------------------------
# Idle hint — "Tap Anywhere"
# -------------------------------------------------------

func _create_idle_hint() -> void:
	_idle_label = Label.new()
	_idle_label.text = "Tap Anywhere"
	_idle_label.add_theme_font_size_override("font_size", 26)
	_idle_label.add_theme_color_override("font_color", _MONEY_GREEN)
	_idle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_idle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_idle_label.visible = false
	_idle_label.modulate.a = 0.0
	# Full-width strip; position vertically after layout is ready
	_idle_label.anchor_left   = 0.0
	_idle_label.anchor_right  = 1.0
	_idle_label.anchor_top    = 0.0
	_idle_label.anchor_bottom = 0.0
	add_child(_idle_label)
	# Center vertically inside the tap zone
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
	_idle_label.visible = true
	_idle_label.modulate.a = 0.0
	if is_instance_valid(_idle_tween):
		_idle_tween.kill()
	# Pulse loop: fade in → hold (2 s total) → fade out → 3 s dark → repeat
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(_idle_label, "modulate:a", 1.0, 0.35) \
		.set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_interval(1.65)
	_idle_tween.tween_property(_idle_label, "modulate:a", 0.0, 0.35) \
		.set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_interval(3.0)


func _hide_idle_hint() -> void:
	_idle_showing = false
	if is_instance_valid(_idle_tween):
		_idle_tween.kill()
		_idle_tween = null
	if _idle_label != null and is_instance_valid(_idle_label):
		_idle_label.visible = false
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
		lbl.add_theme_color_override("font_color", _GOLD)
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

		# Brighten or dim the header text
		var hdr := upgrade_list.get_node_or_null("Header_%s" % key) as Button
		if hdr:
			hdr.add_theme_color_override("font_color",
				_HEADER_LIT if affordable else _MONEY_GREEN)

		# Flash on newly-affordable transition
		if affordable and not _section_had_affordable.get(key, false):
			_flash_header(key)
		_section_had_affordable[key] = affordable

		if not affordable:
			lbl.visible = false
			_stop_bob(key)
			continue

		lbl.visible = true

		if _collapsed[key]:
			# Collapsed: bob on the header's left side
			if not _bob_tweens.has(key):
				_start_bob(key)
		else:
			# Open: pin to left of most-expensive affordable button
			_stop_bob(key)
			var btn := _find_best_affordable_btn(key)
			if btn != null:
				lbl.position = btn.global_position + Vector2(6.0, btn.size.y * 0.5 - 10.0)
			else:
				lbl.visible = false
	_update_hamburger_notif()


func _has_affordable(key: String) -> bool:
	match key:
		"career":
			for i in range(GameManager.CAREERS.size()):
				if GameManager.can_start_career(i):
					return true
		"investments":
			for i in range(GameManager.INVESTMENTS.size()):
				if GameManager.can_afford_investment(i):
					return true
		"strategies":
			for i in range(GameManager.STRATEGIES.size()):
				if GameManager.can_afford_strategy(i):
					return true
		"salary_boosts":
			for i in range(GameManager.SALARY_BOOSTS.size()):
				if GameManager.can_afford_salary_boost(i):
					return true
		"ventures":
			for i in range(GameManager.VENTURES.size()):
				if GameManager.can_afford_venture(i):
					return true
		"investors":
			for i in range(GameManager.INVESTORS.size()):
				if GameManager.can_afford_investor(i):
					return true
	return false


func _find_best_affordable_btn(key: String) -> Button:
	var container := upgrade_list.get_node_or_null("Section_%s" % key) as VBoxContainer
	if container == null:
		return null
	var best_idx  := -1
	var best_cost := 0.0
	match key:
		"career":
			for i in range(GameManager.CAREERS.size()):
				var cost: float = GameManager.CAREERS[i]["cost"]
				if GameManager.can_start_career(i) and cost > best_cost:
					best_idx = i
					best_cost = cost
			if best_idx >= 0:
				return container.get_node_or_null("Career_%d" % best_idx) as Button
		"investments":
			for i in range(GameManager.INVESTMENTS.size()):
				var cost: float = GameManager.get_investment_cost(i)
				if GameManager.can_afford_investment(i) and cost > best_cost:
					best_idx = i
					best_cost = cost
			if best_idx >= 0:
				return container.get_node_or_null("Investment_%d" % best_idx) as Button
		"strategies":
			for i in range(GameManager.STRATEGIES.size()):
				var cost: float = GameManager.STRATEGIES[i]["cost"]
				if GameManager.can_afford_strategy(i) and cost > best_cost:
					best_idx = i
					best_cost = cost
			if best_idx >= 0:
				return container.get_node_or_null("Strategy_%d" % best_idx) as Button
		"salary_boosts":
			for i in range(GameManager.SALARY_BOOSTS.size()):
				var cost: float = GameManager.SALARY_BOOSTS[i]["cost"]
				if GameManager.can_afford_salary_boost(i) and cost > best_cost:
					best_idx = i
					best_cost = cost
			if best_idx >= 0:
				return container.get_node_or_null("SalaryBoost_%d" % best_idx) as Button
		"ventures":
			for i in range(GameManager.VENTURES.size()):
				var cost: float = GameManager.VENTURES[i]["cost"]
				if GameManager.can_afford_venture(i) and cost > best_cost:
					best_idx = i
					best_cost = cost
			if best_idx >= 0:
				return container.get_node_or_null("Venture_%d" % best_idx) as Button
		"investors":
			for i in range(GameManager.INVESTORS.size()):
				var cost: float = GameManager.INVESTORS[i]["cost"]
				if GameManager.can_afford_investor(i) and cost > best_cost:
					best_idx = i
					best_cost = cost
			if best_idx >= 0:
				return container.get_node_or_null("Investor_%d" % best_idx) as Button
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
		_GOLD if any_affordable else Color.WHITE)


# -------------------------------------------------------
# Theme / styling
# -------------------------------------------------------

func _apply_theme() -> void:
	# Stage watermark starts faded
	stage_label.modulate.a = 0.15

	# TopHUD — white card, rounded bottom corners, soft shadow
	var hud := StyleBoxFlat.new()
	hud.bg_color                    = Color(1.0, 1.0, 1.0, 0.93)
	hud.corner_radius_bottom_left   = 18
	hud.corner_radius_bottom_right  = 18
	hud.content_margin_left         = 76.0
	hud.content_margin_right        = 16.0
	hud.content_margin_top          = 6.0
	hud.content_margin_bottom       = 10.0
	hud.shadow_color                = Color(0.0, 0.0, 0.0, 0.10)
	hud.shadow_size                 = 8
	$TopHUD.add_theme_stylebox_override("panel", hud)

	# UpgradeDrawer — white card, rounded right corners, soft shadow
	var drawer := StyleBoxFlat.new()
	drawer.bg_color                       = Color(1.0, 1.0, 1.0, 0.97)
	drawer.corner_radius_top_left         = 0
	drawer.corner_radius_top_right        = 22
	drawer.corner_radius_bottom_left      = 0
	drawer.corner_radius_bottom_right     = 22
	drawer.content_margin_left       = 8.0
	drawer.content_margin_right      = 8.0
	drawer.content_margin_top        = 8.0
	drawer.content_margin_bottom     = 4.0
	drawer.shadow_color              = Color(0.0, 0.0, 0.0, 0.12)
	drawer.shadow_size               = 10
	$UpgradeDrawer.add_theme_stylebox_override("panel", drawer)


# -------------------------------------------------------
# Settings button + overlay
# -------------------------------------------------------

func _build_settings_button() -> void:
	var btn := Button.new()
	btn.text = "⚙"
	btn.custom_minimum_size = Vector2(44, 44)
	btn.add_theme_font_size_override("font_size", 22)
	# Anchor to top-right corner
	btn.anchor_left   = 1.0
	btn.anchor_right  = 1.0
	btn.anchor_top    = 0.0
	btn.anchor_bottom = 0.0
	btn.offset_left   = -48.0
	btn.offset_right  = -4.0
	btn.offset_top    = 4.0
	btn.offset_bottom = 48.0
	btn.pressed.connect(_open_settings)
	add_child(btn)


func _build_settings_overlay() -> void:
	_settings_overlay = Control.new()
	_settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.visible = false
	add_child(_settings_overlay)

	# Dim background — blocks input to game
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.add_child(dim)

	# Card panel
	var card := PanelContainer.new()
	card.anchor_left   = 0.08
	card.anchor_right  = 0.92
	card.anchor_top    = 0.22
	card.anchor_bottom = 0.82
	var style := StyleBoxFlat.new()
	style.bg_color                  = Color(1.0, 1.0, 1.0, 0.97)
	style.corner_radius_top_left    = 20
	style.corner_radius_top_right   = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.content_margin_left   = 20.0
	style.content_margin_right  = 20.0
	style.content_margin_top    = 16.0
	style.content_margin_bottom = 16.0
	card.add_theme_stylebox_override("panel", style)
	_settings_overlay.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", _MONEY_GREEN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	# Sound FX row
	vbox.add_child(_make_settings_label("Sound FX"))
	var sfx_toggle := _make_toggle_btn(Settings.sfx_enabled, func(on): Settings.set_sfx(on))
	vbox.add_child(sfx_toggle)
	var sfx_slider := _make_slider(Settings.sfx_volume, func(v): Settings.set_sfx_volume(v))
	vbox.add_child(sfx_slider)

	# Music row
	vbox.add_child(_make_settings_label("Music"))
	var music_toggle := _make_toggle_btn(Settings.music_enabled, func(on): Settings.set_music(on))
	vbox.add_child(music_toggle)
	var music_slider := _make_slider(Settings.music_volume, func(v): Settings.set_music_volume(v))
	vbox.add_child(music_slider)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# Return to menu
	var menu_btn := Button.new()
	menu_btn.text = "Return to Menu"
	menu_btn.custom_minimum_size = Vector2(0, 48)
	menu_btn.add_theme_font_size_override("font_size", 17)
	menu_btn.add_theme_color_override("font_color", Color(0.75, 0.15, 0.15, 1))
	menu_btn.pressed.connect(_on_return_to_menu)
	vbox.add_child(menu_btn)

	# Resume
	var resume_btn := Button.new()
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size = Vector2(0, 48)
	resume_btn.add_theme_font_size_override("font_size", 17)
	resume_btn.pressed.connect(_close_settings)
	vbox.add_child(resume_btn)


func _make_settings_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45, 1))
	return lbl


func _make_toggle_btn(initial: bool, callback: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 42)
	btn.add_theme_font_size_override("font_size", 16)
	_set_toggle_style(btn, initial)
	btn.pressed.connect(func():
		var now: bool = not bool(btn.get_meta("on"))
		_set_toggle_style(btn, now)
		callback.call(now)
	)
	return btn


func _set_toggle_style(btn: Button, on: bool) -> void:
	btn.set_meta("on", on)
	btn.text = "ON" if on else "OFF"
	btn.add_theme_color_override("font_color",
		_MONEY_GREEN if on else Color(0.6, 0.6, 0.6, 1))


func _make_slider(initial: float, callback: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value    = 0.0
	slider.max_value    = 1.0
	slider.step         = 0.01
	slider.value        = initial
	slider.custom_minimum_size = Vector2(0, 32)
	slider.value_changed.connect(func(v): callback.call(v))
	return slider


func _open_settings() -> void:
	_settings_visible = true
	_settings_overlay.visible = true


func _close_settings() -> void:
	_settings_visible = false
	_settings_overlay.visible = false


func _on_return_to_menu() -> void:
	SaveManager.save()
	_settings_visible = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


# -------------------------------------------------------
# Number formatting
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
