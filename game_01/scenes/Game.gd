extends Control

# -------------------------------------------------------
# Game.gd — UI only. Reads state via EventBus signals.
# Calls GameManager for all state changes.
# -------------------------------------------------------

@onready var resource_label:    Label         = $VBox/ResourceLabel
@onready var per_sec_label:     Label         = $VBox/PerSecLabel
@onready var tap_label:         Label         = $VBox/TapLabel
@onready var days_label:        Label         = $VBox/DaysLabel
@onready var tap_button:        Button        = $VBox/TapButton
@onready var portfolio_label:   Label         = $VBox/PortfolioLabel
@onready var retirement_label:  Label         = $VBox/RetirementLabel
@onready var upgrade_list:      VBoxContainer = $VBox/ScrollContainer/UpgradeList


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
	if rate > 0.0:
		per_sec_label.text = "$%s / day" % _fmt(rate)
	else:
		per_sec_label.text = ""
	_refresh_retirement()


func _on_tap_value_changed(val: float) -> void:
	tap_label.text = "$%s / hr" % _fmt(val)


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
	var years: int = int(days / 365.0)
	var day_in_year: int = int(days) % 365
	days_label.text = "Day %d  ·  Year %d" % [day_in_year + 1, years]
	_refresh_retirement()


func _on_portfolio_changed(total_invested: float, dividends: float) -> void:
	var portfolio_value: float = total_invested + dividends
	portfolio_label.text = "Portfolio: $%s  |  Dividends: $%s" % [_fmt(portfolio_value), _fmt(dividends)]
	_refresh_retirement()


# -------------------------------------------------------
# UI builders
# -------------------------------------------------------

func _build_lists() -> void:
	for child in upgrade_list.get_children():
		child.queue_free()

	# --- CAREER ---
	_add_section_header("── CAREER ──")
	for i in range(GameManager.CAREERS.size()):
		var btn := Button.new()
		btn.name = "Career_%d" % i
		btn.custom_minimum_size = Vector2(0, 72)
		btn.pressed.connect(_on_career_pressed.bind(i))
		upgrade_list.add_child(btn)
		_refresh_career_button(i)

	# --- INVESTMENTS ---
	_add_section_header("── INVESTMENTS ──")
	for i in range(GameManager.INVESTMENTS.size()):
		var btn := Button.new()
		btn.name = "Investment_%d" % i
		btn.custom_minimum_size = Vector2(0, 88)
		btn.pressed.connect(_on_investment_pressed.bind(i))
		upgrade_list.add_child(btn)
		_refresh_investment_button(i)

	# --- STRATEGIES ---
	_add_section_header("── STRATEGIES ──")
	for i in range(GameManager.STRATEGIES.size()):
		var btn := Button.new()
		btn.name = "Strategy_%d" % i
		btn.custom_minimum_size = Vector2(0, 72)
		btn.pressed.connect(_on_strategy_pressed.bind(i))
		upgrade_list.add_child(btn)
		_refresh_strategy_button(i)


func _add_section_header(title: String) -> void:
	var lbl := Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	upgrade_list.add_child(lbl)


func _on_career_pressed(index: int) -> void:
	GameManager.buy_career(index)


func _on_investment_pressed(index: int) -> void:
	GameManager.buy_investment(index)


func _on_strategy_pressed(index: int) -> void:
	GameManager.buy_strategy(index)


func _refresh_career_button(index: int) -> void:
	var btn: Button = upgrade_list.get_node_or_null("Career_%d" % index)
	if btn == null:
		return
	var c: Dictionary = GameManager.CAREERS[index]
	if GameManager.careers_purchased[index]:
		btn.text = "%s\n[Completed]" % c["name"]
		btn.disabled = true
	else:
		btn.text = "%s\n%s\nCost: $%s" % [c["name"], c["description"], _fmt(c["cost"])]
		btn.disabled = not GameManager.can_afford_career(index)


func _refresh_investment_button(index: int) -> void:
	var btn: Button = upgrade_list.get_node_or_null("Investment_%d" % index)
	if btn == null:
		return
	var inv: Dictionary = GameManager.INVESTMENTS[index]
	var owned: int = GameManager.investments_owned[index]
	var cost: float = GameManager.get_investment_cost(index)
	var total_in: float = GameManager.get_total_invested_in(index)
	var income: float = float(owned) * inv["income_per_sec"]

	if owned == 0:
		btn.text = "%s\n%s\nBuy first: $%s" % [inv["name"], inv["description"], _fmt(cost)]
	else:
		btn.text = "%s  [x%d]  |  Total in: $%s  |  +$%s/day\nNext: $%s" % [
			inv["name"], owned, _fmt(total_in), _fmt(income), _fmt(cost)
		]
	btn.disabled = not GameManager.can_afford_investment(index)


func _refresh_strategy_button(index: int) -> void:
	var btn: Button = upgrade_list.get_node_or_null("Strategy_%d" % index)
	if btn == null:
		return
	var s: Dictionary = GameManager.STRATEGIES[index]
	if GameManager.strategies_purchased[index]:
		btn.text = "%s\n[Active]" % s["name"]
		btn.disabled = true
	else:
		btn.text = "%s\n%s\nCost: $%s" % [s["name"], s["description"], _fmt(s["cost"])]
		btn.disabled = not GameManager.can_afford_strategy(index)


func _refresh_retirement() -> void:
	var years_elapsed: float = GameManager.game_days / 365.0
	var years_remaining: float = max(0.0, 65.0 - years_elapsed)
	var estimate: float = GameManager.get_retirement_estimate()
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
	resource_label.text = "$" + _fmt(GameManager.resources)
	tap_label.text = "$%s / hr" % _fmt(GameManager.tap_value)
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
