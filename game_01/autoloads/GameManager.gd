extends Node

# -------------------------------------------------------
# GameManager — All game state lives here.
# -------------------------------------------------------

var resources: float = 0.0
var passive_rate: float = 0.0
var assets_owned: Array = []          # int — how many of each asset purchased
var multipliers_purchased: Array = [] # bool — one-time multiplier purchases

# --- Repeatable Assets ---
# Each purchase costs more: cost = base_cost * growth_rate ^ owned
# income = owned * income_per_sec (summed across all assets)
const ASSETS: Array = [
	{
		"name": "Side Hustle",
		"description": "+$1 / sec each",
		"base_cost": 10.0,
		"growth_rate": 1.15,
		"income_per_sec": 1.0,
	},
	{
		"name": "Index Fund",
		"description": "+$8 / sec each",
		"base_cost": 100.0,
		"growth_rate": 1.15,
		"income_per_sec": 8.0,
	},
	{
		"name": "Rental Property",
		"description": "+$50 / sec each",
		"base_cost": 1_000.0,
		"growth_rate": 1.15,
		"income_per_sec": 50.0,
	},
	{
		"name": "Hedge Fund",
		"description": "+$300 / sec each",
		"base_cost": 10_000.0,
		"growth_rate": 1.15,
		"income_per_sec": 300.0,
	},
	{
		"name": "Private Equity",
		"description": "+$2000 / sec each",
		"base_cost": 100_000.0,
		"growth_rate": 1.15,
		"income_per_sec": 2_000.0,
	},
]

# --- One-Time Multipliers ---
# Purchased once, multiply total passive income permanently
const MULTIPLIERS: Array = [
	{
		"name": "Reinvest Dividends",
		"description": "2x all passive income",
		"cost": 500.0,
		"multiplier": 2.0,
	},
	{
		"name": "Compound Interest",
		"description": "3x all passive income",
		"cost": 50_000.0,
		"multiplier": 3.0,
	},
	{
		"name": "Market Leverage",
		"description": "5x all passive income",
		"cost": 5_000_000.0,
		"multiplier": 5.0,
	},
]

const OFFLINE_CAP_SECONDS := 28800.0  # 8 hours


func _ready() -> void:
	assets_owned.resize(ASSETS.size())
	assets_owned.fill(0)
	multipliers_purchased.resize(MULTIPLIERS.size())
	multipliers_purchased.fill(false)
	_load_game()


func _process(delta: float) -> void:
	if passive_rate > 0.0:
		add_resources(passive_rate * delta)


# -------------------------------------------------------
# Public API
# -------------------------------------------------------

func tap() -> void:
	add_resources(1.0)


func add_resources(amount: float) -> void:
	resources += amount
	EventBus.resource_changed.emit(resources)


# Cost of the next purchase of a given asset
func get_asset_cost(index: int) -> float:
	var a: Dictionary = ASSETS[index]
	return a["base_cost"] * pow(a["growth_rate"], float(assets_owned[index]))


func can_afford_asset(index: int) -> bool:
	return resources >= get_asset_cost(index)


func buy_asset(index: int) -> void:
	if not can_afford_asset(index):
		return
	resources -= get_asset_cost(index)
	assets_owned[index] += 1
	_recalculate_passive_rate()
	EventBus.asset_purchased.emit(index)
	EventBus.resource_changed.emit(resources)
	SaveManager.save()


func can_afford_multiplier(index: int) -> bool:
	return resources >= MULTIPLIERS[index]["cost"] and not multipliers_purchased[index]


func buy_multiplier(index: int) -> void:
	if not can_afford_multiplier(index):
		return
	resources -= MULTIPLIERS[index]["cost"]
	multipliers_purchased[index] = true
	_recalculate_passive_rate()
	EventBus.multiplier_purchased.emit(index)
	EventBus.resource_changed.emit(resources)
	SaveManager.save()


# -------------------------------------------------------
# Private
# -------------------------------------------------------

func _recalculate_passive_rate() -> void:
	# Sum base income from all owned assets
	var base := 0.0
	for i in range(ASSETS.size()):
		base += float(assets_owned[i]) * ASSETS[i]["income_per_sec"]

	# Apply all purchased multipliers
	var mult := 1.0
	for i in range(MULTIPLIERS.size()):
		if multipliers_purchased[i]:
			mult *= MULTIPLIERS[i]["multiplier"]

	passive_rate = base * mult
	EventBus.passive_rate_changed.emit(passive_rate)


func _load_game() -> void:
	var data := SaveManager.load_save()
	if data.is_empty():
		return

	resources = float(data.get("resources", 0.0))

	var saved_assets: Array = data.get("assets_owned", [])
	for i in range(min(saved_assets.size(), assets_owned.size())):
		assets_owned[i] = int(saved_assets[i])

	var saved_multipliers: Array = data.get("multipliers_purchased", [])
	for i in range(min(saved_multipliers.size(), multipliers_purchased.size())):
		multipliers_purchased[i] = bool(saved_multipliers[i])

	_recalculate_passive_rate()

	# Offline income (capped at 8 hours)
	var last_time: float = float(data.get("last_save_time", 0.0))
	if last_time > 0.0 and passive_rate > 0.0:
		var now: float = Time.get_unix_time_from_system()
		var elapsed: float = min(now - last_time, OFFLINE_CAP_SECONDS)
		var offline_earned: float = passive_rate * elapsed
		if offline_earned > 0.0:
			resources += offline_earned
			EventBus.offline_income_collected.emit(offline_earned)

	EventBus.resource_changed.emit(resources)
