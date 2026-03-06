extends Control

# -------------------------------------------------------
# Game.gd — UI only. Reads state via EventBus signals.
# Calls GameManager for all state changes.
# -------------------------------------------------------

@onready var resource_label:   Label         = $VBox/ResourceLabel
@onready var salary_label:     Label         = $VBox/SalaryLabel
@onready var per_sec_label:    Label         = $VBox/PerSecLabel
@onready var days_label:       Label         = $VBox/DaysLabel
@onready var tap_button:       Button        = $VBox/TapButton
@onready var portfolio_label:  Label         = $VBox/PortfolioLabel
@onready var retirement_label: Label         = $VBox/RetirementLabel
@onready var upgrade_list:     VBoxContainer = $VBox/ScrollContainer/UpgradeList

# Which upgrade sections are collapsed (false = expanded)
var _collapsed: Dictionary = {
	"career": false,
	"investments": false,
	"strategies": false,
}

const _TITLES: Dictionary = {
	"career": "CAREER",
	"investments": "INVESTMENTS",
	"strategies": "STRATEGIES",
}


func _ready() -> void:
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.passive_rate_changed.connect(_on_passive_rate_changed)
	EventBus.tap_value_changed.connect(_on_tap_value_changed)
	EventBus.career_purchased.connect(_on_career_purchased)
	EventBus.investment_purchased.connect(_on_investment_purchased)
	EventBus.strategy_purchased.connect(_on_strategy_purchased)
	EventBus.offline_income_collected.connect(_on_offline_income)
	EventBus.game_days_changed.connect(_on_game_days_changed)
	EventBus.portfolio_changed.connect(_on_portfolio_changed)

	tap_button.pressed.connect(_on_tap_pressed)

	_build_lists()
	_refresh_ui()

	if OS.is_debug_build():
		var cheat := Button.new()
		cheat.text = "[DEBUG] +$100,000"
		cheat.pressed.connect(func() -> void: GameManager.add_resources(100_000.0))
		$VBox.add_child(cheat)


# -------------------------------------------------------
# Input
# -------------------------------------------------------

func _on_tap_pressed() -> void:
	GameManager.tap()


# -------------------------------------------------------
# EventBus handlers
# -------------------------------------------------------

func _on_resource_changed(amount: float) -> void:
	resource_label.text = "$" + _fmt(amount)
	_refresh_all_buttons()


func _on_passive_rate_changed(rate: float) -> void:
	per_sec_label.text = "$%s / day" % _fmt(rate) if rate > 0.0 else ""
	_refresh_retirement()


func _on_tap_value_changed(val: float) -> void:
	tap_button.text = "TAP  ($%s / hr)" % _fmt(val)
	salary_label.text = "Annual Salary: $%s" % _fmt(val * 8760.0)


func _on_career_purchased(index: int) -> void:
	_refresh_career_button(index)


func _on_investment_purchased(index: int) -> void:
	_refresh_investment_button(index)


func _on_strategy_purchased(index: int) -> void:
	_refresh_strategy_button(index)


func _on_offline_income(amount: float) -> void:
	resource_label.text = "+$%s while away!" % _fmt(amount)
	await get_tree().create_timer(2.5).timeout
	resource_label.text = "$" + _fmt(GameManager.resources)


func _on_game_days_changed(days: float) -> void:
	var years: int     = int(days / 365.0)
	var day_in_year: int = int(days) % 365
	days_label.text = "Day %d  ·  Year %d" % [day_in_year + 1, years]
	_refresh_retirement()


func _on_portfolio_changed(total_invested: float, dividends: float) -> void:
	portfolio_label.text = "Portfolio: $%s  |  Dividends: $%s" % [
		_fmt(total_invested + dividends), _fmt(dividends)
	]
	_refresh_retirement()


# -------------------------------------------------------
# UI builders — collapsible sections
# -------------------------------------------------------

func _build_lists() -> void:
	for child in upgrade_list.get_children():
		child.queue_free()

	_add_section("career")
	for i in range(GameManager.CAREERS.size()):
		var btn := Button.new()
		btn.name = "Career_%d" % i
		btn.custom_minimum_size = Vector2(0, 52)
		btn.pressed.connect(_on_career_pressed.bind(i))
		_section_container("career").add_child(btn)
		_refresh_career_button(i)

	_add_section("investments")
	for i in range(GameManager.INVESTMENTS.size()):
		var btn := Button.new()
		btn.name = "Investment_%d" % i
		btn.custom_minimum_size = Vector2(0, 60)
		btn.pressed.connect(_on_investment_pressed.bind(i))
		_section_container("investments").add_child(btn)
		_refresh_investment_button(i)

	_add_section("strategies")
	for i in range(GameManager.STRATEGIES.size()):
		var btn := Button.new()
		btn.name = "Strategy_%d" % i
		btn.custom_minimum_size = Vector2(0, 52)
		btn.pressed.connect(_on_strategy_pressed.bind(i))
		_section_container("strategies").add_child(btn)
		_refresh_strategy_button(i)


func _add_section(key: String) -> void:
	var hdr := Button.new()
	hdr.name = "Header_%s" % key
	hdr.text = _section_label(key)
	hdr.custom_minimum_size = Vector2(0, 36)
	hdr.pressed.connect(_toggle_section.bind(key))
	upgrade_list.add_child(hdr)

	var container := VBoxContainer.new()
	container.name = "Section_%s" % key
	container.visible = not _collapsed[key]
	container.add_theme_constant_override("separation", 4)
	upgrade_list.add_child(container)


func _section_container(key: String) -> VBoxContainer:
	return upgrade_list.get_node("Section_%s" % key) as VBoxContainer


func _section_label(key: String) -> String:
	var arrow: String = "▼" if not _collapsed[key] else "▶"
	return "── %s %s" % [_TITLES[key], arrow]


func _toggle_section(key: String) -> void:
	_collapsed[key] = not _collapsed[key]
	var container := upgrade_list.get_node_or_null("Section_%s" % key) as VBoxContainer
	var hdr       := upgrade_list.get_node_or_null("Header_%s" % key)  as Button
	if container:
		container.visible = not _collapsed[key]
	if hdr:
		hdr.text = _section_label(key)


func _on_career_pressed(index: int) -> void:
	GameManager.buy_career(index)


func _on_investment_pressed(index: int) -> void:
	GameManager.buy_investment(index)


func _on_strategy_pressed(index: int) -> void:
	GameManager.buy_strategy(index)


# -------------------------------------------------------
# Button refresh — find buttons inside section containers
# -------------------------------------------------------

func _refresh_career_button(index: int) -> void:
	var container := upgrade_list.get_node_or_null("Section_career") as VBoxContainer
	if container == null:
		return
	var btn := container.get_node_or_null("Career_%d" % index) as Button
	if btn == null:
		return
	var c: Dictionary = GameManager.CAREERS[index]
	if GameManager.careers_purchased[index]:
		btn.text = "%s  [Completed]" % c["name"]
		btn.disabled = true
	else:
		btn.text = "%s — %s — Cost: $%s" % [c["name"], c["description"], _fmt(c["cost"])]
		btn.disabled = not GameManager.can_afford_career(index)


func _refresh_investment_button(index: int) -> void:
	var container := upgrade_list.get_node_or_null("Section_investments") as VBoxContainer
	if container == null:
		return
	var btn := container.get_node_or_null("Investment_%d" % index) as Button
	if btn == null:
		return
	var inv: Dictionary = GameManager.INVESTMENTS[index]
	var owned: int      = GameManager.investments_owned[index]
	var cost: float     = GameManager.get_investment_cost(index)
	var total_in: float = GameManager.get_total_invested_in(index)
	var income: float   = float(owned) * inv["income_per_sec"]

	if owned == 0:
		btn.text = "%s — %s — Buy: $%s" % [inv["name"], inv["description"], _fmt(cost)]
	else:
		btn.text = "%s [x%d] | In: $%s | +$%s/day | Next: $%s" % [
			inv["name"], owned, _fmt(total_in), _fmt(income), _fmt(cost)
		]
	btn.disabled = not GameManager.can_afford_investment(index)


func _refresh_strategy_button(index: int) -> void:
	var container := upgrade_list.get_node_or_null("Section_strategies") as VBoxContainer
	if container == null:
		return
	var btn := container.get_node_or_null("Strategy_%d" % index) as Button
	if btn == null:
		return
	var s: Dictionary = GameManager.STRATEGIES[index]
	if GameManager.strategies_purchased[index]:
		btn.text = "%s  [Active]" % s["name"]
		btn.disabled = true
	else:
		btn.text = "%s — %s — Cost: $%s" % [s["name"], s["description"], _fmt(s["cost"])]
		btn.disabled = not GameManager.can_afford_strategy(index)


func _refresh_retirement() -> void:
	var years_elapsed: float   = GameManager.game_days / 365.0
	var years_remaining: float = max(0.0, 65.0 - years_elapsed)
	var estimate: float        = GameManager.get_retirement_estimate()
	if years_remaining <= 0.0:
		retirement_label.text = "RETIRED!  Nest egg: $%s" % _fmt(estimate)
	else:
		retirement_label.text = "Retire in ~%dyr  ·  est. $%s" % [int(ceil(years_remaining)), _fmt(estimate)]


func _refresh_all_buttons() -> void:
	for i in range(GameManager.CAREERS.size()):
		_refresh_career_button(i)
	for i in range(GameManager.INVESTMENTS.size()):
		_refresh_investment_button(i)
	for i in range(GameManager.STRATEGIES.size()):
		_refresh_strategy_button(i)


func _refresh_ui() -> void:
	resource_label.text  = "$" + _fmt(GameManager.resources)
	tap_button.text      = "TAP  ($%s / hr)" % _fmt(GameManager.tap_value)
	salary_label.text    = "Annual Salary: $%s" % _fmt(GameManager.tap_value * 8760.0)
	if GameManager.passive_rate > 0.0:
		per_sec_label.text = "$%s / day" % _fmt(GameManager.passive_rate)
	var portfolio_val: float = GameManager.total_invested + GameManager.total_dividends_earned
	portfolio_label.text = "Portfolio: $%s  |  Dividends: $%s" % [
		_fmt(portfolio_val), _fmt(GameManager.total_dividends_earned)
	]
	_refresh_retirement()
	_refresh_all_buttons()


# -------------------------------------------------------
# Number formatting
# -------------------------------------------------------

func _fmt(n: float) -> String:
	if n >= 1_000_000_000_000_000.0:
		return "%.2fQa" % (n / 1_000_000_000_000_000.0)
	elif n >= 1_000_000_000_000.0:
		return "%.2fT" % (n / 1_000_000_000_000.0)
	elif n >= 1_000_000_000.0:
		return "%.2fB" % (n / 1_000_000_000.0)
	elif n >= 1_000_000.0:
		return "%.2fM" % (n / 1_000_000.0)
	elif n >= 1_000.0:
		return "%.1fK" % (n / 1_000.0)
	else:
		return "%.2f" % n
