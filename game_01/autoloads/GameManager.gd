extends Node

# -------------------------------------------------------
# GameManager — All game state lives here.
#
# Three upgrade tracks:
#   CAREERS     — one-time, increase tap value (your salary)
#   INVESTMENTS — repeatable, passive income (your portfolio)
#   STRATEGIES  — one-time, multiply passive income (smart money moves)
#
# Design intent:
#   Tapping dominates early game. Investments supplement.
#   Compound growth eventually catches up — mirrors reality.
# -------------------------------------------------------

var resources:   float = 0.0
var passive_rate: float = 0.0
var tap_value:   float = 1.0

var game_days:            float = 0.0  # 1 real second = 1 game day
var total_invested:       float = 0.0  # cumulative cash put into investments
var total_dividends_earned: float = 0.0  # cumulative passive income received

var careers_purchased:    Array = []  # bool — one-time career upgrades
var investments_owned:    Array = []  # int  — repeatable investment purchases
var strategies_purchased: Array = []  # bool — one-time passive multipliers

# -------------------------------------------------------
# CAREERS — increase tap value permanently (one-time each)
# Tapping represents your active income / salary.
# Each career step should feel like a meaningful life event.
# -------------------------------------------------------
const CAREERS: Array = [
	{
		"name": "Night Classes",
		"description": "Learn new skills. Tap +$4.",
		"cost": 40.0,
		"tap_bonus": 4.0,
	},
	{
		"name": "Associate's Degree",
		"description": "Entry-level professional. Tap +$16.",
		"cost": 400.0,
		"tap_bonus": 16.0,
	},
	{
		"name": "Bachelor's Degree",
		"description": "Career jump. Tap +$80.",
		"cost": 5_000.0,
		"tap_bonus": 80.0,
	},
	{
		"name": "Professional Certification",
		"description": "Become a specialist. Tap +$300.",
		"cost": 40_000.0,
		"tap_bonus": 300.0,
	},
	{
		"name": "Master's Degree",
		"description": "Management track. Tap +$1,200.",
		"cost": 350_000.0,
		"tap_bonus": 1_200.0,
	},
	{
		"name": "Executive Track",
		"description": "C-suite income. Tap +$5,000.",
		"cost": 3_000_000.0,
		"tap_bonus": 5_000.0,
	},
]

# -------------------------------------------------------
# INVESTMENTS — repeatable, exponential cost scaling
# cost = base_cost * growth_rate ^ owned
# Passive income should feel like a bonus, not a replacement
# for active income — especially early game.
# -------------------------------------------------------
const INVESTMENTS: Array = [
	{
		"name": "Savings Account",
		"description": "+$0.10 / sec each",
		"base_cost": 150.0,
		"growth_rate": 1.2,
		"income_per_sec": 0.10,
	},
	{
		"name": "Index Funds",
		"description": "+$1 / sec each",
		"base_cost": 2_000.0,
		"growth_rate": 1.2,
		"income_per_sec": 1.0,
	},
	{
		"name": "Rental Property",
		"description": "+$12 / sec each",
		"base_cost": 30_000.0,
		"growth_rate": 1.2,
		"income_per_sec": 12.0,
	},
	{
		"name": "Business Equity",
		"description": "+$120 / sec each",
		"base_cost": 400_000.0,
		"growth_rate": 1.2,
		"income_per_sec": 120.0,
	},
	{
		"name": "Venture Capital",
		"description": "+$1,500 / sec each",
		"base_cost": 6_000_000.0,
		"growth_rate": 1.2,
		"income_per_sec": 1_500.0,
	},
]

# -------------------------------------------------------
# STRATEGIES — one-time multipliers on passive income
# Represent smart financial decisions: tax efficiency,
# diversification, employer matching.
# -------------------------------------------------------
const STRATEGIES: Array = [
	{
		"name": "401k Employer Match",
		"description": "2x all investment income",
		"cost": 8_000.0,
		"multiplier": 2.0,
	},
	{
		"name": "Tax Optimization",
		"description": "3x all investment income",
		"cost": 500_000.0,
		"multiplier": 3.0,
	},
	{
		"name": "Diversified Portfolio",
		"description": "5x all investment income",
		"cost": 20_000_000.0,
		"multiplier": 5.0,
	},
]

const OFFLINE_CAP_SECONDS := 28800.0  # 8 hours


func _ready() -> void:
	careers_purchased.resize(CAREERS.size())
	careers_purchased.fill(false)
	investments_owned.resize(INVESTMENTS.size())
	investments_owned.fill(0)
	strategies_purchased.resize(STRATEGIES.size())
	strategies_purchased.fill(false)
	_load_game()


func _process(delta: float) -> void:
	game_days += delta
	EventBus.game_days_changed.emit(game_days)
	if passive_rate > 0.0:
		var earned: float = passive_rate * delta
		resources += earned
		total_dividends_earned += earned
		EventBus.resource_changed.emit(resources)
		EventBus.portfolio_changed.emit(total_invested, total_dividends_earned)


# -------------------------------------------------------
# Public API
# -------------------------------------------------------

func tap() -> void:
	add_resources(tap_value)


func add_resources(amount: float) -> void:
	resources += amount
	EventBus.resource_changed.emit(resources)


# --- Careers ---

func can_afford_career(index: int) -> bool:
	return resources >= CAREERS[index]["cost"] and not careers_purchased[index]


func buy_career(index: int) -> void:
	if not can_afford_career(index):
		return
	resources -= CAREERS[index]["cost"]
	careers_purchased[index] = true
	tap_value += CAREERS[index]["tap_bonus"]
	EventBus.tap_value_changed.emit(tap_value)
	EventBus.career_purchased.emit(index)
	EventBus.resource_changed.emit(resources)
	SaveManager.save()


# --- Investments ---

func get_investment_cost(index: int) -> float:
	var inv: Dictionary = INVESTMENTS[index]
	return inv["base_cost"] * pow(inv["growth_rate"], float(investments_owned[index]))


func can_afford_investment(index: int) -> bool:
	return resources >= get_investment_cost(index)


func buy_investment(index: int) -> void:
	if not can_afford_investment(index):
		return
	var cost: float = get_investment_cost(index)
	resources -= cost
	total_invested += cost
	investments_owned[index] += 1
	_recalculate_passive_rate()
	EventBus.investment_purchased.emit(index)
	EventBus.resource_changed.emit(resources)
	EventBus.portfolio_changed.emit(total_invested, total_dividends_earned)
	SaveManager.save()


# Sum of geometric series: base * (r^n - 1) / (r - 1)
func get_total_invested_in(index: int) -> float:
	var n: int = investments_owned[index]
	if n == 0:
		return 0.0
	var inv: Dictionary = INVESTMENTS[index]
	return inv["base_cost"] * (pow(inv["growth_rate"], float(n)) - 1.0) / (inv["growth_rate"] - 1.0)


# Rough projection: current assets + passive at today's rate for remaining years
func get_retirement_estimate() -> float:
	var years_remaining: float = max(1.0, 65.0 - (game_days / 365.0))
	var projected_passive: float = passive_rate * years_remaining * 365.0
	return resources + total_invested + total_dividends_earned + projected_passive


# --- Strategies ---

func can_afford_strategy(index: int) -> bool:
	return resources >= STRATEGIES[index]["cost"] and not strategies_purchased[index]


func buy_strategy(index: int) -> void:
	if not can_afford_strategy(index):
		return
	resources -= STRATEGIES[index]["cost"]
	strategies_purchased[index] = true
	_recalculate_passive_rate()
	EventBus.strategy_purchased.emit(index)
	EventBus.resource_changed.emit(resources)
	SaveManager.save()


# -------------------------------------------------------
# Private
# -------------------------------------------------------

func _recalculate_passive_rate() -> void:
	var base := 0.0
	for i in range(INVESTMENTS.size()):
		base += float(investments_owned[i]) * INVESTMENTS[i]["income_per_sec"]

	var mult := 1.0
	for i in range(STRATEGIES.size()):
		if strategies_purchased[i]:
			mult *= STRATEGIES[i]["multiplier"]

	passive_rate = base * mult
	EventBus.passive_rate_changed.emit(passive_rate)


func _load_game() -> void:
	var data := SaveManager.load_save()
	if data.is_empty():
		return

	resources             = float(data.get("resources", 0.0))
	game_days             = float(data.get("game_days", 0.0))
	total_invested        = float(data.get("total_invested", 0.0))
	total_dividends_earned = float(data.get("total_dividends_earned", 0.0))

	var saved_careers: Array = data.get("careers_purchased", [])
	for i in range(min(saved_careers.size(), careers_purchased.size())):
		careers_purchased[i] = bool(saved_careers[i])

	var saved_investments: Array = data.get("investments_owned", [])
	for i in range(min(saved_investments.size(), investments_owned.size())):
		investments_owned[i] = int(saved_investments[i])

	var saved_strategies: Array = data.get("strategies_purchased", [])
	for i in range(min(saved_strategies.size(), strategies_purchased.size())):
		strategies_purchased[i] = bool(saved_strategies[i])

	# Rebuild tap value from purchased careers
	tap_value = 1.0
	for i in range(CAREERS.size()):
		if careers_purchased[i]:
			tap_value += CAREERS[i]["tap_bonus"]

	_recalculate_passive_rate()

	# Offline income
	var last_time: float = float(data.get("last_save_time", 0.0))
	if last_time > 0.0 and passive_rate > 0.0:
		var now: float = Time.get_unix_time_from_system()
		var elapsed: float = min(now - last_time, OFFLINE_CAP_SECONDS)
		var offline_earned: float = passive_rate * elapsed
		if offline_earned > 0.0:
			resources += offline_earned
			EventBus.offline_income_collected.emit(offline_earned)

	EventBus.resource_changed.emit(resources)
	EventBus.tap_value_changed.emit(tap_value)
