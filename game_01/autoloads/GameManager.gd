extends Node

# -------------------------------------------------------
# GameManager — All game state lives here.
#
# Five upgrade tracks:
#   CAREERS     — one-time, increase tap value (your salary)
#   INVESTMENTS — repeatable, passive income (your portfolio)
#   STRATEGIES  — one-time, multiply investment income
#   VENTURES    — one-time company milestones, large passive income
#   INVESTORS   — one-time funding rounds, multiply venture income
#
# Total passive = (investment_base * strategy_mult)
#               + (venture_base    * investor_mult)
# -------------------------------------------------------

var resources:              float = 0.0
var passive_rate:           float = 0.0
var tap_value:              float = 1.0

var game_days:              float = 0.0
var total_invested:         float = 0.0
var total_dividends_earned: float = 0.0

var careers_purchased:       Array = []  # bool
var careers_in_progress:     Array = []  # float: -1.0 = not started, >= 0.0 = game_days when study began
var investments_owned:       Array = []  # int
var strategies_purchased:    Array = []  # bool
var ventures_purchased:      Array = []  # bool
var investors_purchased:     Array = []  # bool
var salary_boosts_purchased: Array = []  # bool

# Populated in _ready() from base data + procedurally generated tiers
var VENTURES:  Array = []
var INVESTORS: Array = []

# -------------------------------------------------------
# CAREERS
# -------------------------------------------------------
const CAREERS: Array = [
	{
		"name": "Night Classes",
		"description": "Learn new skills. Tap +$4.",
		"cost": 40.0,
		"tap_bonus": 4.0,
		"requires": -1,
		"duration_days": 90.0,
	},
	{
		"name": "Associate's Degree",
		"description": "Entry-level professional. Tap +$16.",
		"cost": 400.0,
		"tap_bonus": 16.0,
		"requires": 0,
		"duration_days": 365.0,
	},
	{
		"name": "Bachelor's Degree",
		"description": "Career jump. Tap +$80.",
		"cost": 5_000.0,
		"tap_bonus": 80.0,
		"requires": 1,
		"duration_days": 365.0,
	},
	{
		"name": "Professional Certification",
		"description": "Become a specialist. Tap +$300.",
		"cost": 40_000.0,
		"tap_bonus": 300.0,
		"requires": 2,
		"duration_days": 365.0,
	},
	{
		"name": "Master's Degree",
		"description": "Management track. Tap +$1,200.",
		"cost": 350_000.0,
		"tap_bonus": 1_200.0,
		"requires": 3,
		"duration_days": 365.0,
	},
	{
		"name": "Executive Track",
		"description": "C-suite income. Tap +$5,000.",
		"cost": 3_000_000.0,
		"tap_bonus": 5_000.0,
		"requires": 4,
		"duration_days": 365.0,
	},
]

# -------------------------------------------------------
# INVESTMENTS — repeatable, exponential cost scaling
# income_per_day is per game-day (= per real second)
# -------------------------------------------------------
const INVESTMENTS: Array = [
	# Return ratio (income / base_cost) climbs each tier: ~0.067% → 0.075% → 0.083% → 0.10% → 0.12%
	# so higher-tier investments are proportionally more rewarding.
	{
		"name": "Savings Account",
		"description": "+$0.10 / day each",
		"base_cost": 150.0,
		"growth_rate": 1.18,
		"income_per_sec": 0.10,
	},
	{
		"name": "Index Funds",
		"description": "+$1.50 / day each",
		"base_cost": 2_000.0,
		"growth_rate": 1.18,
		"income_per_sec": 1.5,
	},
	{
		"name": "Rental Property",
		"description": "+$25 / day each",
		"base_cost": 30_000.0,
		"growth_rate": 1.18,
		"income_per_sec": 25.0,
	},
	{
		"name": "Business Equity",
		"description": "+$400 / day each",
		"base_cost": 400_000.0,
		"growth_rate": 1.18,
		"income_per_sec": 400.0,
	},
	{
		"name": "Venture Capital",
		"description": "+$7,200 / day each",
		"base_cost": 6_000_000.0,
		"growth_rate": 1.18,
		"income_per_sec": 7_200.0,
	},
]

# -------------------------------------------------------
# STRATEGIES — one-time multipliers on investment income
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

# -------------------------------------------------------
# SALARY_BOOSTS — one-time multipliers on tap (salary) income
# Mirrors STRATEGIES but for the career/tap track.
# -------------------------------------------------------
const SALARY_BOOSTS: Array = [
	{
		"name": "Performance Review",
		"description": "2x tap income",
		"cost": 2_000_000.0,
		"multiplier": 2.0,
	},
	{
		"name": "Raise Negotiation",
		"description": "3x tap income",
		"cost": 25_000_000.0,
		"multiplier": 3.0,
	},
	{
		"name": "Equity Package",
		"description": "5x tap income",
		"cost": 250_000_000.0,
		"multiplier": 5.0,
	},
	{
		"name": "Stock Options Vest",
		"description": "8x tap income",
		"cost": 2_500_000_000.0,
		"multiplier": 8.0,
	},
	{
		"name": "Board Compensation",
		"description": "15x tap income",
		"cost": 25_000_000_000.0,
		"multiplier": 15.0,
	},
	{
		"name": "Billionaire Salary",
		"description": "25x tap income",
		"cost": 250_000_000_000.0,
		"multiplier": 25.0,
	},
]

# -------------------------------------------------------
# VENTURES — one-time company milestones, own passive stream
# Each purchase adds income_per_day to venture_base
# -------------------------------------------------------
const _VENTURES_BASE: Array = [
	# Return ratio (income_per_day / cost) climbs each tier: 1% → 1.2% → 1.5% → 2% → 2.5% → 3% → 3.5% → 4%
	# so later ventures pay back their cost progressively faster.
	{
		"name": "Freelance Consulting",
		"description": "Put your skills to work. +$5K/day",
		"cost": 500_000.0,
		"income_per_day": 5_000.0,
	},
	{
		"name": "Register an LLC",
		"description": "Make it official. +$60K/day",
		"cost": 5_000_000.0,
		"income_per_day": 60_000.0,
	},
	{
		"name": "Hire Your First Employee",
		"description": "Scale beyond yourself. +$525K/day",
		"cost": 35_000_000.0,
		"income_per_day": 525_000.0,
	},
	{
		"name": "Office & Operations",
		"description": "A real business now. +$5M/day",
		"cost": 250_000_000.0,
		"income_per_day": 5_000_000.0,
	},
	{
		"name": "Product Launch",
		"description": "Ship it. +$37.5M/day",
		"cost": 1_500_000_000.0,
		"income_per_day": 37_500_000.0,
	},
	{
		"name": "Enterprise Sales",
		"description": "Land the big clients. +$240M/day",
		"cost": 8_000_000_000.0,
		"income_per_day": 240_000_000.0,
	},
	{
		"name": "IPO",
		"description": "Go public. +$1.05B/day",
		"cost": 30_000_000_000.0,
		"income_per_day": 1_050_000_000.0,
	},
	{
		"name": "Global Expansion",
		"description": "Every market, every continent. +$6B/day",
		"cost": 150_000_000_000.0,
		"income_per_day": 6_000_000_000.0,
	},
]

# -------------------------------------------------------
# INVESTORS — one-time funding rounds that multiply venture income
# -------------------------------------------------------
const _INVESTORS_BASE: Array = [
	{
		"name": "Angel Investors",
		"description": "2x all venture income",
		"cost": 3_000_000.0,
		"multiplier": 2.0,
	},
	{
		"name": "Series A",
		"description": "3x all venture income",
		"cost": 40_000_000.0,
		"multiplier": 3.0,
	},
	{
		"name": "Series B",
		"description": "5x all venture income",
		"cost": 400_000_000.0,
		"multiplier": 5.0,
	},
	{
		"name": "Institutional Investors",
		"description": "8x all venture income",
		"cost": 4_000_000_000.0,
		"multiplier": 8.0,
	},
]

const OFFLINE_CAP_SECONDS  := 28800.0  # 8 hours
const START_AGE            := 16.0
const RETIRE_AGE           := 65.0
const RETIREMENT_AGE_DAYS  := (RETIRE_AGE - START_AGE) * 365.0  # 49 years of game time

# Retirement tiers — evaluated against net worth at retirement.
# "inheritance_pct" is fraction of net worth passed to next generation.
const RETIREMENT_TIERS: Array = [
	{
		"name": "Destitute",
		"subtitle": "Living on Social Security",
		"description": "Barely making ends meet.\nThe golden years feel anything but golden.",
		"min_worth": 0.0,
		"inheritance_pct": 0.0,
		"color": Color(0.55, 0.55, 0.55, 1.0),
	},
	{
		"name": "Modest",
		"subtitle": "A small nest egg",
		"description": "Enough to cover the basics.\nA little dignity, if not much comfort.",
		"min_worth": 10_000.0,
		"inheritance_pct": 0.05,
		"color": Color(0.65, 0.55, 0.40, 1.0),
	},
	{
		"name": "Middle Class",
		"subtitle": "A comfortable retirement",
		"description": "Travel, hobbies, and peace of mind.\nThe American dream, mostly achieved.",
		"min_worth": 250_000.0,
		"inheritance_pct": 0.10,
		"color": Color(0.30, 0.55, 0.75, 1.0),
	},
	{
		"name": "Upper Middle Class",
		"subtitle": "Well-funded and stress-free",
		"description": "Financial security achieved.\nYour hard work paid off handsomely.",
		"min_worth": 1_000_000.0,
		"inheritance_pct": 0.15,
		"color": Color(0.20, 0.65, 0.45, 1.0),
	},
	{
		"name": "Wealthy",
		"subtitle": "Luxury retirement",
		"description": "Homes, travel, and legacy giving.\nMoney is no longer a concern.",
		"min_worth": 10_000_000.0,
		"inheritance_pct": 0.20,
		"color": Color(0.87, 0.70, 0.0, 1.0),
	},
	{
		"name": "Rich",
		"subtitle": "Your money makes money",
		"description": "Fully removed from financial stress.\nYour influence extends beyond your life.",
		"min_worth": 100_000_000.0,
		"inheritance_pct": 0.25,
		"color": Color(0.90, 0.50, 0.10, 1.0),
	},
	{
		"name": "Generational Wealth",
		"subtitle": "A dynasty begins",
		"description": "Your family will never need to worry.\nThe compound effect, fully realised.",
		"min_worth": 1_000_000_000.0,
		"inheritance_pct": 0.30,
		"color": Color(0.60, 0.20, 0.80, 1.0),
	},
]

var _end_triggered: bool = false


func _ready() -> void:
	# Build procedural upgrade arrays before sizing state arrays
	VENTURES  = _VENTURES_BASE.duplicate()
	INVESTORS = _INVESTORS_BASE.duplicate()
	_extend_ventures()
	_extend_investors()
	careers_purchased.resize(CAREERS.size())
	careers_purchased.fill(false)
	careers_in_progress.resize(CAREERS.size())
	careers_in_progress.fill(-1.0)
	investments_owned.resize(INVESTMENTS.size())
	investments_owned.fill(0)
	strategies_purchased.resize(STRATEGIES.size())
	strategies_purchased.fill(false)
	ventures_purchased.resize(VENTURES.size())
	ventures_purchased.fill(false)
	investors_purchased.resize(INVESTORS.size())
	investors_purchased.fill(false)
	salary_boosts_purchased.resize(SALARY_BOOSTS.size())
	salary_boosts_purchased.fill(false)
	_load_game()


func reset() -> void:
	resources              = 0.0
	passive_rate           = 0.0
	tap_value              = 1.0
	game_days              = 0.0
	total_invested         = 0.0
	total_dividends_earned = 0.0
	_end_triggered         = false
	careers_purchased.fill(false)
	careers_in_progress.fill(-1.0)
	investments_owned.fill(0)
	strategies_purchased.fill(false)
	ventures_purchased.fill(false)
	investors_purchased.fill(false)
	salary_boosts_purchased.fill(false)
	EventBus.resource_changed.emit(resources)
	EventBus.tap_value_changed.emit(tap_value)
	EventBus.passive_rate_changed.emit(passive_rate)
	EventBus.game_days_changed.emit(game_days)
	EventBus.portfolio_changed.emit(total_invested, total_dividends_earned)


func _process(delta: float) -> void:
	game_days += delta
	EventBus.game_days_changed.emit(game_days)
	if passive_rate > 0.0:
		var earned: float = passive_rate * delta
		resources += earned
		total_dividends_earned += earned
		EventBus.resource_changed.emit(resources)
		EventBus.portfolio_changed.emit(total_invested, total_dividends_earned)
	# Auto-complete any careers whose study period has elapsed
	for i in range(CAREERS.size()):
		if not careers_purchased[i] and careers_in_progress[i] >= 0.0:
			if game_days - careers_in_progress[i] >= float(CAREERS[i]["duration_days"]):
				_complete_career(i)
	if not _end_triggered and game_days >= RETIREMENT_AGE_DAYS:
		_end_triggered = true
		SaveManager.save()
		EventBus.game_ended.emit()


# -------------------------------------------------------
# Public API
# -------------------------------------------------------

func tap() -> void:
	add_resources(get_effective_tap_value())
	game_days += 1.0 / 24.0  # 1 tap = 1 game hour
	EventBus.game_days_changed.emit(game_days)


func add_resources(amount: float) -> void:
	resources += amount
	EventBus.resource_changed.emit(resources)


# --- Careers ---

func career_prereq_met(index: int) -> bool:
	var req: int = CAREERS[index]["requires"]
	return req < 0 or careers_purchased[req]


func can_start_career(index: int) -> bool:
	return (
		career_prereq_met(index) and
		not careers_purchased[index] and
		careers_in_progress[index] < 0.0 and
		resources >= CAREERS[index]["cost"]
	)


func start_career(index: int) -> void:
	if not can_start_career(index):
		return
	resources -= CAREERS[index]["cost"]
	careers_in_progress[index] = game_days
	EventBus.resource_changed.emit(resources)
	SaveManager.save()


func finish_career_now(index: int) -> void:
	if careers_in_progress[index] < 0.0:
		return
	_complete_career(index)


func _complete_career(index: int) -> void:
	careers_in_progress[index] = -1.0
	careers_purchased[index] = true
	tap_value += float(CAREERS[index]["tap_bonus"])
	EventBus.tap_value_changed.emit(tap_value)
	EventBus.career_purchased.emit(index)
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
func get_net_worth() -> float:
	return resources + total_invested + total_dividends_earned


func get_retirement_tier() -> Dictionary:
	var worth := get_net_worth()
	var best: Dictionary = RETIREMENT_TIERS[0]
	for tier in RETIREMENT_TIERS:
		if worth >= float(tier["min_worth"]):
			best = tier
	return best


func get_inheritance_amount() -> float:
	var tier := get_retirement_tier()
	return get_net_worth() * float(tier["inheritance_pct"])


func debug_advance_years(years: float) -> void:
	var days: float   = years * 365.0
	var earned: float = passive_rate * days
	game_days              += days
	resources              += earned
	total_dividends_earned += earned
	EventBus.game_days_changed.emit(game_days)
	EventBus.resource_changed.emit(resources)
	EventBus.portfolio_changed.emit(total_invested, total_dividends_earned)


func start_new_generation(inheritance: float) -> void:
	reset()
	resources = inheritance
	EventBus.resource_changed.emit(resources)


func get_retirement_estimate() -> float:
	var age_now: float         = START_AGE + game_days / 365.0
	var years_remaining: float = max(1.0, RETIRE_AGE - age_now)
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


# --- Ventures ---

func can_afford_venture(index: int) -> bool:
	return resources >= VENTURES[index]["cost"] and not ventures_purchased[index]


func buy_venture(index: int) -> void:
	if not can_afford_venture(index):
		return
	resources -= VENTURES[index]["cost"]
	ventures_purchased[index] = true
	_recalculate_passive_rate()
	EventBus.venture_purchased.emit(index)
	EventBus.resource_changed.emit(resources)
	SaveManager.save()


# --- Investors ---

func can_afford_investor(index: int) -> bool:
	return resources >= INVESTORS[index]["cost"] and not investors_purchased[index]


func buy_investor(index: int) -> void:
	if not can_afford_investor(index):
		return
	resources -= INVESTORS[index]["cost"]
	investors_purchased[index] = true
	_recalculate_passive_rate()
	EventBus.investor_purchased.emit(index)
	EventBus.resource_changed.emit(resources)
	SaveManager.save()


# --- Salary Boosts ---

func can_afford_salary_boost(index: int) -> bool:
	return resources >= SALARY_BOOSTS[index]["cost"] and not salary_boosts_purchased[index]


func buy_salary_boost(index: int) -> void:
	if not can_afford_salary_boost(index):
		return
	resources -= SALARY_BOOSTS[index]["cost"]
	salary_boosts_purchased[index] = true
	EventBus.salary_boost_purchased.emit(index)
	EventBus.tap_value_changed.emit(tap_value)
	EventBus.resource_changed.emit(resources)
	SaveManager.save()


# --- Helpers ---

func get_strategy_multiplier() -> float:
	var mult := 1.0
	for i in range(STRATEGIES.size()):
		if strategies_purchased[i]:
			mult *= STRATEGIES[i]["multiplier"]
	return mult


func get_investor_multiplier() -> float:
	var mult := 1.0
	for i in range(INVESTORS.size()):
		if investors_purchased[i]:
			mult *= INVESTORS[i]["multiplier"]
	return mult


func get_tap_multiplier() -> float:
	var mult := 1.0
	for i in range(SALARY_BOOSTS.size()):
		if salary_boosts_purchased[i]:
			mult *= SALARY_BOOSTS[i]["multiplier"]
	return mult


func get_effective_tap_value() -> float:
	return tap_value * get_tap_multiplier()


# -------------------------------------------------------
# Private
# -------------------------------------------------------

func _recalculate_passive_rate() -> void:
	# Investment stream (multiplied by strategy multipliers)
	var inv_base := 0.0
	for i in range(INVESTMENTS.size()):
		inv_base += float(investments_owned[i]) * INVESTMENTS[i]["income_per_sec"]

	# Venture stream (multiplied by investor multipliers)
	var ven_base := 0.0
	for i in range(VENTURES.size()):
		if ventures_purchased[i]:
			ven_base += VENTURES[i]["income_per_day"]

	passive_rate = (inv_base * get_strategy_multiplier()) + (ven_base * get_investor_multiplier())
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

	var saved_careers_ip: Array = data.get("careers_in_progress", [])
	for i in range(min(saved_careers_ip.size(), careers_in_progress.size())):
		careers_in_progress[i] = float(saved_careers_ip[i])

	var saved_investments: Array = data.get("investments_owned", [])
	for i in range(min(saved_investments.size(), investments_owned.size())):
		investments_owned[i] = int(saved_investments[i])

	var saved_strategies: Array = data.get("strategies_purchased", [])
	for i in range(min(saved_strategies.size(), strategies_purchased.size())):
		strategies_purchased[i] = bool(saved_strategies[i])

	var saved_ventures: Array = data.get("ventures_purchased", [])
	for i in range(min(saved_ventures.size(), ventures_purchased.size())):
		ventures_purchased[i] = bool(saved_ventures[i])

	var saved_investors: Array = data.get("investors_purchased", [])
	for i in range(min(saved_investors.size(), investors_purchased.size())):
		investors_purchased[i] = bool(saved_investors[i])

	var saved_salary_boosts: Array = data.get("salary_boosts_purchased", [])
	for i in range(min(saved_salary_boosts.size(), salary_boosts_purchased.size())):
		salary_boosts_purchased[i] = bool(saved_salary_boosts[i])

	# Rebuild tap value from purchased careers
	tap_value = 1.0
	for i in range(CAREERS.size()):
		if careers_purchased[i]:
			tap_value += CAREERS[i]["tap_bonus"]

	_recalculate_passive_rate()

	# Offline advancement — age and income both progress in real time
	var last_time: float = float(data.get("last_save_time", 0.0))
	if last_time > 0.0:
		var now: float     = Time.get_unix_time_from_system()
		var elapsed: float = min(now - last_time, OFFLINE_CAP_SECONDS)

		# Age always advances while the app is closed (1 real second = 1 game day)
		game_days += elapsed

		# Dividends accumulate as normal
		if passive_rate > 0.0:
			var offline_earned: float = passive_rate * elapsed
			if offline_earned > 0.0:
				resources += offline_earned
				EventBus.offline_income_collected.emit(offline_earned)

	# Complete any careers whose study period elapsed while offline
	for i in range(CAREERS.size()):
		if not careers_purchased[i] and careers_in_progress[i] >= 0.0:
			if game_days - careers_in_progress[i] >= float(CAREERS[i]["duration_days"]):
				careers_in_progress[i] = -1.0
				careers_purchased[i]   = true
				tap_value += float(CAREERS[i]["tap_bonus"])

	# Suppress in-game ending signal — retirement is handled via RetirementScreen
	if game_days >= RETIREMENT_AGE_DAYS:
		_end_triggered = true

	EventBus.resource_changed.emit(resources)
	EventBus.tap_value_changed.emit(tap_value)


func _extend_ventures() -> void:
	# Procedurally generated tiers beyond the base 8 static entries.
	# Each tier: cost × 7, income × 7. Names escalate from space economy
	# through galactic empire to wealth that transcends comprehension.
	var entries: Array = [
		["Off-World Subsidiary",        "Your empire reaches orbit"],
		["Lunar Mining Rights",          "Own the Moon. Literally"],
		["Martian Colony Corp",          "First city on Mars. Yours"],
		["Asteroid Belt Monopoly",       "Control the solar system's resources"],
		["Outer Planets Conglomerate",   "Jupiter's moons are prime real estate"],
		["Solar Array Megastructure",    "Ring the sun with solar panels"],
		["Mercury Forge Complex",        "Automated factories closest to the sun"],
		["Dyson Swarm Prototype",        "Harvest the full energy of a star"],
		["Stellar Energy Grid",          "Power the galaxy's grid"],
		["Buy-N-Large Franchise",        "You are now the only store in the universe"],
		["Galactic Trade Route Inc.",    "Toll booths between every star system"],
		["Nebula Harvesting Rights",     "Mine the building blocks of stars"],
		["Dark Matter Derivatives",      "Securitise the invisible universe"],
		["Black Hole Power Plant",       "Unlimited energy, questionable safety record"],
		["Galactic Core HQ",             "Corner office at the centre of the galaxy"],
		["Multiverse Holdings",          "Diversify across realities"],
		["Reality Hedge Fund",           "Short-sell alternative timelines"],
		["Spacetime Futures Exchange",   "Trade tomorrow's past today"],
		["Entropy Insurance Co.",        "Insure against the heat death of the universe"],
		["The Known Universe LLC",       "You own it. All of it"],
		["Post-Scarcity Foundation",     "Scarcity is so last universe"],
		["Existence Optimization Corp",  "Restructure reality for maximum ROI"],
		["The Concept of Wealth Itself", "You have become the idea of money"],
		["You Are Now The Economy",      "Markets move when you breathe"],
		["GDP of Everything",            "Gross Domestic Product: all of it"],
		["Omniversal Capital Group",     "Infinite realities, infinite revenue streams"],
		["The Big Bang, Incorporated",   "You funded the original"],
	]
	var cost:   float = _VENTURES_BASE.back()["cost"]
	var income: float = _VENTURES_BASE.back()["income_per_day"]
	for e in entries:
		cost   *= 7.0
		income *= 7.0
		VENTURES.append({
			"name":           e[0],
			"description":    "%s. +$%s/day" % [e[1], _compact_num(income)],
			"cost":           cost,
			"income_per_day": income,
		})


func _extend_investors() -> void:
	# Procedurally generated investor tiers beyond the base 4 static entries.
	# Each tier: cost × 8, with fixed escalating multipliers.
	var entries: Array = [
		["Government Stimulus Package", 12.0,  "12x all venture income"],
		["Sovereign Wealth Fund",        18.0,  "18x all venture income"],
		["Central Bank Backstop",        25.0,  "25x all venture income"],
		["Alien Venture Capital",        35.0,  "35x all venture income"],
		["Interdimensional Equity",      50.0,  "50x all venture income"],
		["The Fed (All of Them)",         70.0,  "70x all venture income"],
		["Galactic Credit Union",        100.0, "100x all venture income"],
		["Universal Constant Capital",   150.0, "150x all venture income"],
		["The Number Itself",             200.0, "200x all venture income"],
		["Concept of Infinity Fund",     300.0, "300x all venture income"],
	]
	var cost: float = _INVESTORS_BASE.back()["cost"]
	for e in entries:
		cost *= 8.0
		INVESTORS.append({
			"name":        e[0],
			"description": e[2],
			"cost":        cost,
			"multiplier":  e[1],
		})


func _compact_num(n: float) -> String:
	# Compact number formatter used when generating descriptions at startup.
	if   n >= 1.0e33: return "%.1fDc" % (n / 1.0e33)
	elif n >= 1.0e30: return "%.1fNo" % (n / 1.0e30)
	elif n >= 1.0e27: return "%.1fOc" % (n / 1.0e27)
	elif n >= 1.0e24: return "%.1fSp" % (n / 1.0e24)
	elif n >= 1.0e21: return "%.1fSx" % (n / 1.0e21)
	elif n >= 1.0e18: return "%.1fQi" % (n / 1.0e18)
	elif n >= 1.0e15: return "%.1fQa" % (n / 1.0e15)
	elif n >= 1.0e12: return "%.1fT"  % (n / 1.0e12)
	elif n >= 1.0e9:  return "%.1fB"  % (n / 1.0e9)
	elif n >= 1.0e6:  return "%.1fM"  % (n / 1.0e6)
	elif n >= 1.0e3:  return "%.1fK"  % (n / 1.0e3)
	return "%.0f" % n
