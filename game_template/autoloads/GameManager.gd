extends Node

# -------------------------------------------------------
# GameManager — All game state lives here.
# Reads all content data from GameConfig — do not put
# game-specific values in this file.
#
# Four tracks (configured in GameConfig):
#   TRACK_A — one-time tap boosters        (e.g. careers)
#   TRACK_B — repeatable generators        (e.g. investments)
#   TRACK_C — one-time passive multipliers (e.g. strategies)
#   TRACK_D — one-time tap multipliers     (e.g. raises)
# -------------------------------------------------------

var resources:              float = 0.0
var passive_rate:           float = 0.0
var tap_value:              float = 1.0

var game_days:              float = 0.0
var total_invested:         float = 0.0
var total_dividends_earned: float = 0.0

var track_a_purchased: Array = []   # bool — one-time tap boosters
var track_b_owned:     Array = []   # int  — repeatable generators
var track_c_purchased: Array = []   # bool — one-time passive multipliers
var track_d_purchased: Array = []   # bool — one-time tap multipliers


func _ready() -> void:
	track_a_purchased.resize(GameConfig.TRACK_A.size())
	track_a_purchased.fill(false)
	track_b_owned.resize(GameConfig.TRACK_B.size())
	track_b_owned.fill(0)
	track_c_purchased.resize(GameConfig.TRACK_C.size())
	track_c_purchased.fill(false)
	track_d_purchased.resize(GameConfig.TRACK_D.size())
	track_d_purchased.fill(false)
	_load_game()


func reset() -> void:
	resources              = 0.0
	passive_rate           = 0.0
	tap_value              = 1.0
	game_days              = 0.0
	total_invested         = 0.0
	total_dividends_earned = 0.0
	track_a_purchased.fill(false)
	track_b_owned.fill(0)
	track_c_purchased.fill(false)
	track_d_purchased.fill(false)
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
		resources              += earned
		total_dividends_earned += earned
		EventBus.resource_changed.emit(resources)
		EventBus.portfolio_changed.emit(total_invested, total_dividends_earned)


# -------------------------------------------------------
# Public API
# -------------------------------------------------------

func tap() -> void:
	add_resources(get_effective_tap_value())
	game_days += 1.0 / 24.0   # 1 tap = 1 game hour
	EventBus.game_days_changed.emit(game_days)


func add_resources(amount: float) -> void:
	resources += amount
	EventBus.resource_changed.emit(resources)


# Returns the cost to purchase item [index] on track [track].
# Track B costs scale exponentially with ownership count.
func get_item_cost(track: int, index: int) -> float:
	match track:
		0:
			return float(GameConfig.TRACK_A[index]["cost"])
		1:
			var item: Dictionary = GameConfig.TRACK_B[index]
			return item["base_cost"] * pow(item["growth_rate"], float(track_b_owned[index]))
		2:
			return float(GameConfig.TRACK_C[index]["cost"])
		3:
			return float(GameConfig.TRACK_D[index]["cost"])
	return 0.0


func can_afford(track: int, index: int) -> bool:
	match track:
		0:
			return resources >= get_item_cost(0, index) and not track_a_purchased[index]
		1:
			return resources >= get_item_cost(1, index)
		2:
			return resources >= get_item_cost(2, index) and not track_c_purchased[index]
		3:
			return resources >= get_item_cost(3, index) and not track_d_purchased[index]
	return false


func buy_item(track: int, index: int) -> void:
	if not can_afford(track, index):
		return
	var cost: float = get_item_cost(track, index)
	resources -= cost

	match track:
		0:
			track_a_purchased[index] = true
			tap_value += float(GameConfig.TRACK_A[index]["tap_bonus"])
			EventBus.tap_value_changed.emit(tap_value)
		1:
			total_invested    += cost
			track_b_owned[index] += 1
			_recalculate_passive_rate()
			EventBus.portfolio_changed.emit(total_invested, total_dividends_earned)
		2:
			track_c_purchased[index] = true
			_recalculate_passive_rate()
		3:
			track_d_purchased[index] = true
			EventBus.tap_value_changed.emit(tap_value)

	EventBus.item_purchased.emit(track, index)
	EventBus.resource_changed.emit(resources)
	SaveManager.save()


func get_tap_multiplier() -> float:
	var mult := 1.0
	for i in range(GameConfig.TRACK_D.size()):
		if track_d_purchased[i]:
			mult *= float(GameConfig.TRACK_D[i]["multiplier"])
	return mult


func get_effective_tap_value() -> float:
	return tap_value * get_tap_multiplier()


# Sum of geometric series for Track B: base * (r^n - 1) / (r - 1)
func get_total_invested_in(index: int) -> float:
	var n: int = track_b_owned[index]
	if n == 0:
		return 0.0
	var item: Dictionary = GameConfig.TRACK_B[index]
	return item["base_cost"] * (pow(item["growth_rate"], float(n)) - 1.0) / (item["growth_rate"] - 1.0)


# Rough projection: current assets + passive at today's rate for remaining goal years
func get_retirement_estimate() -> float:
	var years_remaining: float = max(1.0, GameConfig.GOAL_AGE - (game_days / 365.0))
	var projected_passive: float = passive_rate * years_remaining * 365.0
	return resources + total_invested + total_dividends_earned + projected_passive


# -------------------------------------------------------
# Private
# -------------------------------------------------------

func _recalculate_passive_rate() -> void:
	var base := 0.0
	for i in range(GameConfig.TRACK_B.size()):
		base += float(track_b_owned[i]) * float(GameConfig.TRACK_B[i]["income_per_sec"])

	var mult := 1.0
	for i in range(GameConfig.TRACK_C.size()):
		if track_c_purchased[i]:
			mult *= float(GameConfig.TRACK_C[i]["multiplier"])

	passive_rate = base * mult
	EventBus.passive_rate_changed.emit(passive_rate)


func _load_game() -> void:
	var data := SaveManager.load_save()
	if data.is_empty():
		return

	resources              = float(data.get("resources",               0.0))
	game_days              = float(data.get("game_days",               0.0))
	total_invested         = float(data.get("total_invested",          0.0))
	total_dividends_earned = float(data.get("total_dividends_earned",  0.0))

	var saved_a: Array = data.get("track_a_purchased", [])
	for i in range(min(saved_a.size(), track_a_purchased.size())):
		track_a_purchased[i] = bool(saved_a[i])

	var saved_b: Array = data.get("track_b_owned", [])
	for i in range(min(saved_b.size(), track_b_owned.size())):
		track_b_owned[i] = int(saved_b[i])

	var saved_c: Array = data.get("track_c_purchased", [])
	for i in range(min(saved_c.size(), track_c_purchased.size())):
		track_c_purchased[i] = bool(saved_c[i])

	var saved_d: Array = data.get("track_d_purchased", [])
	for i in range(min(saved_d.size(), track_d_purchased.size())):
		track_d_purchased[i] = bool(saved_d[i])

	# Rebuild tap_value from Track A purchases
	tap_value = 1.0
	for i in range(GameConfig.TRACK_A.size()):
		if track_a_purchased[i]:
			tap_value += float(GameConfig.TRACK_A[i]["tap_bonus"])

	_recalculate_passive_rate()

	# Offline income
	var last_time: float = float(data.get("last_save_time", 0.0))
	if last_time > 0.0 and passive_rate > 0.0:
		var now: float     = Time.get_unix_time_from_system()
		var elapsed: float = min(now - last_time, GameConfig.OFFLINE_CAP_SECONDS)
		var offline_earned: float = passive_rate * elapsed
		if offline_earned > 0.0:
			resources += offline_earned
			EventBus.offline_income_collected.emit(offline_earned)

	EventBus.resource_changed.emit(resources)
	EventBus.tap_value_changed.emit(tap_value)
