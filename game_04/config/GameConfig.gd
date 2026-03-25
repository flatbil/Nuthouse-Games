extends Node

# -------------------------------------------------------
# GameConfig — Frontier Slots (Western poker card theme).
# Virtual coins only. No real-money gambling.
# -------------------------------------------------------

const SAVE_FILE := "user://frontier_slots_v2.sav"

# ── Reel layout ────────────────────────────────────────
const CELL_W       := 108    # pixels per cell width
const CELL_H       := 112    # pixels per cell height (tall enough for card aspect ratio)
const VISIBLE_ROWS := 3      # rows visible in the reel window
const REEL_COUNT   := 3
const STRIP_PRE    := 12     # random cells before the result rows
# Total cells per strip = STRIP_PRE + VISIBLE_ROWS = 15

# ── Economy ────────────────────────────────────────────
const STARTING_COINS := 5000
const BET_OPTIONS: Array  = [1, 5, 10, 25, 50, 100]
const XP_PER_SPIN  := 1
const XP_PER_LEVEL := 50

const DAILY_STREAK_BONUSES: Array = [100, 250, 500, 1000, 1500, 2000, 5000]

# ── Symbols — poker card theme ─────────────────────────
# weight:    relative probability (higher = more common)
# payout_3x: multiplier on bet for three-of-a-kind on middle row
# texture:   path to card PNG asset
# bg:        cell background color
const SYMBOLS: Dictionary = {
	"nine": {
		"label":   "9",
		"texture": "res://assets/sprites/cards/card_nine.png",
		"bg":      Color(0.12, 0.16, 0.20),
		"weight":  24,
		"payout_3x": 6,
	},
	"ten": {
		"label":   "10",
		"texture": "res://assets/sprites/cards/card_ten.png",
		"bg":      Color(0.20, 0.10, 0.10),
		"weight":  20,
		"payout_3x": 10,
	},
	"jack": {
		"label":   "J",
		"texture": "res://assets/sprites/cards/card_jack.png",
		"bg":      Color(0.20, 0.10, 0.10),
		"weight":  16,
		"payout_3x": 15,
	},
	"queen": {
		"label":   "Q",
		"texture": "res://assets/sprites/cards/card_queen.png",
		"bg":      Color(0.12, 0.16, 0.20),
		"weight":  12,
		"payout_3x": 25,
	},
	"king": {
		"label":   "K",
		"texture": "res://assets/sprites/cards/card_king.png",
		"bg":      Color(0.20, 0.10, 0.10),
		"weight":  8,
		"payout_3x": 50,
	},
	"ace": {
		"label":   "A",
		"texture": "res://assets/sprites/cards/card_ace.png",
		"bg":      Color(0.12, 0.16, 0.20),
		"weight":  4,
		"payout_3x": 80,
	},
	"wild": {
		"label":   "WILD",
		"texture": "res://assets/sprites/cards/card_wild.png",
		"bg":      Color(0.25, 0.05, 0.05),
		"weight":  2,
		"payout_3x": 200,
	},
}

const COLOR_DARK_BG  := Color(0.07, 0.04, 0.02, 1.0)
const COLOR_GOLD     := Color(0.90, 0.75, 0.10, 1.0)
const COLOR_GOLD_DIM := Color(0.55, 0.42, 0.00, 1.0)


# Returns a weighted-random symbol key.
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
	return "nine"


# Returns the coin payout for a middle-row triplet and bet amount.
#
# Priority order:
#   1. Three-of-a-kind (wild substitutes for any symbol) → symbol payout × bet
#   2. Two-of-a-kind on reels 1+2 (wild counts)         → 2× bet
#   3. Nine or wild on reel 1 (consolation)              → 1× bet (break even)
#   4. No win                                            → 0
#
# Targeting ~90% RTP with these payouts and weights.
static func payout(symbols: Array, bet: int) -> int:
	var s0: String = symbols[0]
	var s1: String = symbols[1]
	var s2: String = symbols[2]

	# ── 1. Find the non-wild base symbol ───────────────
	var base: String = ""
	for s: String in [s0, s1, s2]:
		if s != "wild":
			base = s
			break

	# All wilds → jackpot
	if base == "":
		return bet * int(SYMBOLS["wild"]["payout_3x"])

	# ── 2. Three-of-a-kind (wild substitutes) ──────────
	var match3 := true
	for s: String in [s0, s1, s2]:
		if s != base and s != "wild":
			match3 = false
			break
	if match3:
		return bet * int(SYMBOLS[base]["payout_3x"])

	# ── 3. Two-of-a-kind on reels 1 + 2 ───────────────
	# Wild on either reel counts as a match.
	var two_match: bool = (s0 == s1) or (s0 == "wild") or (s1 == "wild")
	if two_match:
		return bet * 2

	# ── 4. Consolation — nine or wild on reel 1 ────────
	if s0 == "nine" or s0 == "wild":
		return bet

	return 0


static func xp_for_level(_level: int) -> int:
	return XP_PER_LEVEL
