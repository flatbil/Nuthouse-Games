extends Node

# -------------------------------------------------------
# GameManager — Lucky Frontier state and spin logic.
# Virtual coins only. No real-money mechanics.
# -------------------------------------------------------

var coins:                int   = GameConfig.STARTING_COINS
var spins_total:          int   = 0
var best_win:             int   = 0
var level:                int   = 1
var xp:                   int   = 0
var streak:               int   = 0
var last_daily_timestamp: int   = 0
var total_won:            int   = 0
var total_wagered:        int   = 0


func _ready() -> void:
	_load()


func can_spin(bet: int) -> bool:
	return coins >= bet and bet > 0


# Executes a spin. Returns {"result": Array, "winnings": int, "leveled_up": bool}.
# result is Array[Array[String]] — result[reel][row], 3 reels × 3 rows.
func spin(bet: int) -> Dictionary:
	if not can_spin(bet):
		return {}

	coins         -= bet
	spins_total   += 1
	total_wagered += bet

	# Roll 3 reels × 3 rows
	var result: Array = []
	for _r in range(GameConfig.REEL_COUNT):
		var reel: Array = []
		for _row in range(GameConfig.VISIBLE_ROWS):
			reel.append(GameConfig.weighted_symbol())
		result.append(reel)

	# Win detection on middle row (index 1)
	var mid_row: Array = [result[0][1], result[1][1], result[2][1]]
	var winnings: int  = GameConfig.payout(mid_row, bet)

	if winnings > 0:
		coins      += winnings
		total_won  += winnings
		if winnings > best_win:
			best_win = winnings

	# XP and levelling
	xp += GameConfig.XP_PER_SPIN
	var leveled_up := false
	while xp >= GameConfig.xp_for_level(level):
		xp -= GameConfig.xp_for_level(level)
		level      += 1
		leveled_up  = true
		EventBus.level_up.emit(level)

	EventBus.coins_changed.emit(coins)
	EventBus.spin_completed.emit(result, winnings)
	if winnings >= bet * 10:
		EventBus.big_win.emit(winnings)

	_save()
	return {"result": result, "winnings": winnings, "leveled_up": leveled_up}


func can_claim_daily_bonus() -> bool:
	var now: int     = int(Time.get_unix_time_from_system())
	var elapsed: int = now - last_daily_timestamp
	return elapsed >= 86400  # 24 hours


func claim_daily_bonus() -> int:
	if not can_claim_daily_bonus():
		return 0
	var now: int = int(Time.get_unix_time_from_system())
	# Streak resets if more than 48 hours have passed
	if (now - last_daily_timestamp) > 172800:
		streak = 0
	var bonus_idx: int = mini(streak, GameConfig.DAILY_STREAK_BONUSES.size() - 1)
	var bonus: int     = int(GameConfig.DAILY_STREAK_BONUSES[bonus_idx])
	coins                += bonus
	streak               += 1
	last_daily_timestamp  = now
	EventBus.coins_changed.emit(coins)
	EventBus.daily_bonus_claimed.emit(bonus)
	_save()
	return bonus


func reset() -> void:
	coins                = GameConfig.STARTING_COINS
	spins_total          = 0
	best_win             = 0
	level                = 1
	xp                   = 0
	streak               = 0
	last_daily_timestamp = 0
	total_won            = 0
	total_wagered        = 0
	EventBus.coins_changed.emit(coins)
	_save()


func _save() -> void:
	SaveManager.save({
		"coins":                coins,
		"spins_total":          spins_total,
		"best_win":             best_win,
		"level":                level,
		"xp":                   xp,
		"streak":               streak,
		"last_daily_timestamp": last_daily_timestamp,
		"total_won":            total_won,
		"total_wagered":        total_wagered,
	})


func _load() -> void:
	var d: Dictionary = SaveManager.load_save()
	if d.is_empty():
		return
	coins                = d.get("coins",                GameConfig.STARTING_COINS)
	spins_total          = d.get("spins_total",          0)
	best_win             = d.get("best_win",             0)
	level                = d.get("level",                1)
	xp                   = d.get("xp",                   0)
	streak               = d.get("streak",               0)
	last_daily_timestamp = d.get("last_daily_timestamp", 0)
	total_won            = d.get("total_won",            0)
	total_wagered        = d.get("total_wagered",        0)
