extends Node

# -------------------------------------------------------
# GameManager — All game state lives here.
#
# This is the single source of truth for:
#   - Current resources
#   - Passive income rate
#   - Which upgrades have been purchased
#
# UI scripts NEVER modify state directly.
# They call methods here, and listen to EventBus signals
# to know when to redraw.
# -------------------------------------------------------

# --- State ---
var resources: float = 0.0
var passive_rate: float = 0.0          # resources per second (recalculated)
var upgrades_purchased: Array = []     # parallel bool array to UPGRADES

# --- Upgrade Definitions ---
# Each entry is a Dictionary with:
#   name, description, cost
#   passive_bonus      → adds flat +N/sec to base rate
#   passive_multiplier → multiplies the total passive rate
const UPGRADES: Array = [
	{
		"name": "Auto Tap",
		"description": "+1 Data per second, passively.",
		"cost": 25.0,
		"passive_bonus": 1.0,
	},
	{
		"name": "Double Down",
		"description": "2× all passive income.",
		"cost": 200.0,
		"passive_multiplier": 2.0,
	},
	{
		"name": "Overdrive",
		"description": "5× all passive income.",
		"cost": 2000.0,
		"passive_multiplier": 5.0,
	},
]

# Offline income cap: 8 hours in seconds
const OFFLINE_CAP_SECONDS := 28800.0


func _ready() -> void:
	upgrades_purchased.resize(UPGRADES.size())
	upgrades_purchased.fill(false)
	_load_game()


func _process(delta: float) -> void:
	if passive_rate > 0.0:
		_add_resources(passive_rate * delta)


# -------------------------------------------------------
# Public API — called by UI scripts
# -------------------------------------------------------

func tap() -> void:
	_add_resources(1.0)


func can_afford(index: int) -> bool:
	if index < 0 or index >= UPGRADES.size():
		return false
	return resources >= UPGRADES[index]["cost"] and not upgrades_purchased[index]


func buy_upgrade(index: int) -> void:
	if not can_afford(index):
		return

	resources -= UPGRADES[index]["cost"]
	upgrades_purchased[index] = true

	_recalculate_passive_rate()

	EventBus.upgrade_purchased.emit(index)
	EventBus.resource_changed.emit(resources)

	SaveManager.save()


# -------------------------------------------------------
# Private helpers
# -------------------------------------------------------

func _add_resources(amount: float) -> void:
	add_resources(amount)


func add_resources(amount: float) -> void:
	resources += amount
	EventBus.resource_changed.emit(resources)


func _recalculate_passive_rate() -> void:
	# Step 1: sum all flat bonuses from purchased upgrades
	var base := 0.0
	for i in range(UPGRADES.size()):
		if upgrades_purchased[i] and UPGRADES[i].has("passive_bonus"):
			base += UPGRADES[i]["passive_bonus"]

	# Step 2: apply all multipliers from purchased upgrades
	var multiplier := 1.0
	for i in range(UPGRADES.size()):
		if upgrades_purchased[i] and UPGRADES[i].has("passive_multiplier"):
			multiplier *= UPGRADES[i]["passive_multiplier"]

	passive_rate = base * multiplier
	EventBus.passive_rate_changed.emit(passive_rate)


func _load_game() -> void:
	var data := SaveManager.load_save()

	if data.is_empty():
		return  # Fresh install, nothing to load

	resources = float(data.get("resources", 0.0))

	# Restore upgrade state from save
	var saved: Array = data.get("upgrades_purchased", [])
	for i in range(min(saved.size(), upgrades_purchased.size())):
		upgrades_purchased[i] = bool(saved[i])

	# Recalculate passive rate from restored upgrades
	_recalculate_passive_rate()

	# Apply offline income (capped at 8 hours)
	var last_time: float = float(data.get("last_save_time", 0.0))
	if last_time > 0.0 and passive_rate > 0.0:
		var now: float = Time.get_unix_time_from_system()
		var elapsed: float = min(now - last_time, OFFLINE_CAP_SECONDS)
		var offline_earned: float = passive_rate * elapsed
		if offline_earned > 0.0:
			resources += offline_earned
			EventBus.offline_income_collected.emit(offline_earned)

	EventBus.resource_changed.emit(resources)
