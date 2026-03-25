extends Node

# -------------------------------------------------------
# GameConfig — AI Slop Slots.
# Intentionally chaotic aesthetic. Virtual coins only.
# -------------------------------------------------------

const SAVE_FILE := "user://ai_slop_slots.sav"

# ── Reel layout ────────────────────────────────────────
const CELL_W       := 90
const CELL_H       := 90
const VISIBLE_ROWS := 3
const REEL_COUNT   := 3
const STRIP_PRE    := 12
# Total strip cells = STRIP_PRE + VISIBLE_ROWS = 15

# ── Economy ────────────────────────────────────────────
const STARTING_COINS := 5000
const BET_OPTIONS: Array = [1, 5, 10, 25, 50, 100]
const XP_PER_SPIN  := 1
const XP_PER_LEVEL := 50

const DAILY_STREAK_BONUSES: Array = [200, 500, 1000, 2000, 3000, 5000, 10000]

# ── Symbols ────────────────────────────────────────────
# The SIGN symbol is also the scatter — 3+ anywhere = bonus round.
const SCATTER_SYMBOL := "sign"
const SCATTER_COUNT  := 3   # how many scatters trigger the bonus

const SYMBOLS: Dictionary = {
	"hand": {
		"label":   "6 FNGERS",
		"texture": "res://assets/sprites/symbols/hand.png",
		"bg":      Color(0.50, 0.04, 0.28),
		"weight":  24,
		"payout_3x": 6,
	},
	"apple": {
		"label":   "APLLE",
		"texture": "res://assets/sprites/symbols/apple.png",
		"bg":      Color(0.02, 0.38, 0.38),
		"weight":  20,
		"payout_3x": 10,
	},
	"dog": {
		"label":   "GOOD BOOF",
		"texture": "res://assets/sprites/symbols/dog.png",
		"bg":      Color(0.45, 0.38, 0.02),
		"weight":  16,
		"payout_3x": 15,
	},
	"sign": {
		"label":   "SCATTER",
		"texture": "res://assets/sprites/symbols/sign.png",
		"bg":      Color(0.25, 0.00, 0.48),
		"weight":  12,
		"payout_3x": 25,
	},
	"sphere": {
		"label":   "SPHERE MAN",
		"texture": "res://assets/sprites/symbols/sphere.png",
		"bg":      Color(0.04, 0.04, 0.06),
		"weight":  8,
		"payout_3x": 50,
	},
	"spaghetti": {
		"label":   "SPUGEHTTI",
		"texture": "res://assets/sprites/symbols/spaghetti.png",
		"bg":      Color(0.42, 0.36, 0.20),
		"weight":  4,
		"payout_3x": 80,
	},
	"eye": {
		"label":   "WILD",
		"texture": "res://assets/sprites/symbols/eye.png",
		"bg":      Color(0.10, 0.00, 0.20),
		"weight":  2,
		"payout_3x": 200,
	},
}

# ── Bonus round prizes ─────────────────────────────────
# mult = -1 means GLITCH (random 10-500×)
const BONUS_PRIZES: Array = [
	{"label": "5×",           "mult": 5,   "color": Color(0.9, 0.1, 0.1)},
	{"label": "10×",          "mult": 10,  "color": Color(0.1, 0.8, 0.1)},
	{"label": "20×",          "mult": 20,  "color": Color(0.1, 0.2, 0.9)},
	{"label": "NOPE\n(2×)",   "mult": 2,   "color": Color(0.4, 0.4, 0.4)},
	{"label": "50×!",         "mult": 50,  "color": Color(0.9, 0.5, 0.0)},
	{"label": "100×!!",       "mult": 100, "color": Color(0.9, 0.0, 0.9)},
	{"label": "200×!!!",      "mult": 200, "color": Color(0.0, 0.9, 0.9)},
	{"label": "AI SAYS\n500×","mult": 500, "color": Color(1.0, 1.0, 0.0)},
	{"label": "GLITCH\n???×", "mult": -1,  "color": Color(0.6, 0.0, 0.8)},
]

# Silly AI congratulation messages shown on bonus win
const AI_CONGRATS: Array = [
	"CONGRAULATIONS!\nYOU WINS %d COINZ!",
	"AI HAS DECIDED\nYOU ARE LUCKY TODAY\n(+%d COINS)",
	"THE SLOT MACHINE\nHAS APPROVED YOUR\nVICTORY OF %d!",
	"ERROR 404:\nLOSS NOT FOUND\n+%d MONIES",
	"BONUS COMPLETE!\nPLEASE ACCEPT\n%d DIGITAL COINS",
	"INCREDIBLE!\nEVEN AI IS SURPRISED\nYOU WON %d!",
]

# ── Theme colors ───────────────────────────────────────
const COLOR_BG_PINK  := Color(0.55, 0.02, 0.42, 1.0)   # hot magenta
const COLOR_BG_DARK  := Color(0.08, 0.02, 0.12, 1.0)   # dark purple-black
const COLOR_LIME     := Color(0.40, 1.00, 0.10, 1.0)
const COLOR_GOLD     := Color(1.00, 0.88, 0.10, 1.0)
const COLOR_ORANGE   := Color(1.00, 0.45, 0.05, 1.0)


func weighted_symbol() -> String:
	var total := 0
	for k in SYMBOLS:
		total += int(SYMBOLS[k]["weight"])
	var r := randi() % total
	var acc := 0
	for k in SYMBOLS:
		acc += int(SYMBOLS[k]["weight"])
		if r < acc:
			return k
	return "hand"


# Counts scatter symbols in the full 3×3 result grid.
static func count_scatters(result: Array) -> int:
	var n := 0
	for reel in result:
		for sym in reel:
			if sym == SCATTER_SYMBOL:
				n += 1
	return n


# Payout for the middle row (payline).
# Priority: 3-of-a-kind → 2-of-a-kind (reels 1+2) → hand consolation
static func payout(symbols: Array, bet: int) -> int:
	var s0: String = symbols[0]
	var s1: String = symbols[1]
	var s2: String = symbols[2]

	var base: String = ""
	for s: String in [s0, s1, s2]:
		if s != "eye":   # eye is wild
			base = s
			break

	if base == "":
		return bet * int(SYMBOLS["eye"]["payout_3x"])

	var match3 := true
	for s: String in [s0, s1, s2]:
		if s != base and s != "eye":
			match3 = false
			break
	if match3:
		return bet * int(SYMBOLS[base]["payout_3x"])

	var two_match: bool = (s0 == s1) or (s0 == "eye") or (s1 == "eye")
	if two_match:
		return bet * 2

	if s0 == "hand" or s0 == "eye":
		return bet

	return 0


static func xp_for_level(_level: int) -> int:
	return XP_PER_LEVEL
