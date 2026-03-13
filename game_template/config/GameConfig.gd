extends Node

# ═══════════════════════════════════════════════════════════════
# GameConfig — THE only file you edit to make a new idle game.
#
# Workflow:
#   1. Duplicate game_template/ → game_XX/
#   2. Edit this file (names, costs, colors, labels)
#   3. Swap art assets in scenes/
#   4. Change package name in project.godot
#   5. Ship
#
# Three-track system — maps to almost every idle game:
#   TRACK_A  one-time tap boosters    (e.g. Careers, Vehicles, Tiers)
#   TRACK_B  repeatable generators    (e.g. Investments, Routes, Factories)
#   TRACK_C  one-time multipliers     (e.g. Strategies, Logistics, Automation)
# ═══════════════════════════════════════════════════════════════


# ── Identity ───────────────────────────────────────────────────

const SAVE_FILE := "user://save.json"   # change per game to avoid save conflicts


# ── Currency ───────────────────────────────────────────────────

# CURRENCY_FORMAT uses %s as a placeholder for the formatted number.
# Examples:
#   "$%s"     →  "$1.23M"
#   "%s cr"   →  "1.23M cr"
#   "%s pts"  →  "1.23M pts"
const CURRENCY_FORMAT := "$%s"


# ── Theme ──────────────────────────────────────────────────────

const COLOR_PRIMARY    := Color(0.106, 0.369, 0.125, 1.0)  # main text / headings
const COLOR_HEADER_LIT := Color(0.15,  0.72,  0.28,  1.0)  # header when item is affordable
const COLOR_GOLD       := Color(0.87,  0.70,  0.0,   1.0)  # indicators, loan button
const COLOR_BG         := Color(0.937, 0.984, 0.937, 1.0)  # background tint


# ── HUD Labels ─────────────────────────────────────────────────

const IDLE_HINT           := "Tap Anywhere"

# Tap-value stat line (below the resource counter)
const TAP_STAT_LABEL      := "Annual Salary"
const TAP_STAT_MULTIPLIER := 2082.0          # tap_value * this = displayed amount
# e.g. for a drone game: LABEL = "Deliveries/Day", MULTIPLIER = 1.0

# Portfolio stat line
const PORTFOLIO_LABEL     := "Portfolio"     # left side of portfolio row
const DIVIDENDS_LABEL     := "Dividends"     # right side

# Long-term goal line (replaces "retirement" for non-finance games)
const GOAL_LABEL          := "Retire"        # e.g. "IPO", "Exit", "Retire"
const GOAL_MET_LABEL      := "RETIRED!"      # shown when GOAL_AGE is reached
const GOAL_AGE            := 65.0            # target age in game-years


# ── Section Titles ─────────────────────────────────────────────

const TRACK_A_TITLE := "CAREER"
const TRACK_B_TITLE := "INVESTMENTS"
const TRACK_C_TITLE := "STRATEGIES"


# ── Wealth / Progress Stages ───────────────────────────────────
# Watermark text shown in the tap zone. Advances as resources grow.

const STAGES: Array = [
	{"threshold": 0.0,                 "label": "Starting Out"},
	{"threshold": 1_000.0,             "label": "Getting By"},
	{"threshold": 50_000.0,            "label": "Building Wealth"},
	{"threshold": 1_000_000.0,         "label": "Comfortable"},
	{"threshold": 50_000_000.0,        "label": "Wealthy"},
	{"threshold": 1_000_000_000.0,     "label": "Rich"},
	{"threshold": 1_000_000_000_000.0, "label": "Ultra Rich"},
]


# ── Track A — one-time tap boosters ───────────────────────────
# Each item permanently increases tap_value when purchased.
# Required keys: name, description, cost (float), tap_bonus (float)

const TRACK_A: Array = [
	{
		"name":        "Night Classes",
		"description": "Learn new skills. Tap +$4.",
		"cost":        40.0,
		"tap_bonus":   4.0,
	},
	{
		"name":        "Associate's Degree",
		"description": "Entry-level professional. Tap +$16.",
		"cost":        400.0,
		"tap_bonus":   16.0,
	},
	{
		"name":        "Bachelor's Degree",
		"description": "Career jump. Tap +$80.",
		"cost":        5_000.0,
		"tap_bonus":   80.0,
	},
	{
		"name":        "Professional Certification",
		"description": "Become a specialist. Tap +$300.",
		"cost":        40_000.0,
		"tap_bonus":   300.0,
	},
	{
		"name":        "Master's Degree",
		"description": "Management track. Tap +$1,200.",
		"cost":        350_000.0,
		"tap_bonus":   1_200.0,
	},
	{
		"name":        "Executive Track",
		"description": "C-suite income. Tap +$5,000.",
		"cost":        3_000_000.0,
		"tap_bonus":   5_000.0,
	},
]


# ── Track B — repeatable passive generators ────────────────────
# Each purchase adds income_per_sec to passive rate.
# Cost scales: base_cost * growth_rate ^ owned
# Required keys: name, description, base_cost, growth_rate, income_per_sec

const TRACK_B: Array = [
	{
		"name":           "Savings Account",
		"description":    "+$0.10 / sec each",
		"base_cost":      150.0,
		"growth_rate":    1.2,
		"income_per_sec": 0.10,
	},
	{
		"name":           "Index Funds",
		"description":    "+$1 / sec each",
		"base_cost":      2_000.0,
		"growth_rate":    1.2,
		"income_per_sec": 1.0,
	},
	{
		"name":           "Rental Property",
		"description":    "+$12 / sec each",
		"base_cost":      30_000.0,
		"growth_rate":    1.2,
		"income_per_sec": 12.0,
	},
	{
		"name":           "Business Equity",
		"description":    "+$120 / sec each",
		"base_cost":      400_000.0,
		"growth_rate":    1.2,
		"income_per_sec": 120.0,
	},
	{
		"name":           "Venture Capital",
		"description":    "+$1,500 / sec each",
		"base_cost":      6_000_000.0,
		"growth_rate":    1.2,
		"income_per_sec": 1_500.0,
	},
]


# ── Track C — one-time passive multipliers ─────────────────────
# Each item multiplies the total passive rate when purchased.
# Required keys: name, description, cost (float), multiplier (float)

const TRACK_C: Array = [
	{
		"name":        "401k Employer Match",
		"description": "2x all investment income",
		"cost":        8_000.0,
		"multiplier":  2.0,
	},
	{
		"name":        "Tax Optimization",
		"description": "3x all investment income",
		"cost":        500_000.0,
		"multiplier":  3.0,
	},
	{
		"name":        "Diversified Portfolio",
		"description": "5x all investment income",
		"cost":        20_000_000.0,
		"multiplier":  5.0,
	},
]


# ── Rewarded Ad / Loan ─────────────────────────────────────────
# Button shown at top of upgrade drawer. Shows a rewarded ad,
# awards AD_LOAN_AMOUNT on completion. 5-min cooldown.
# Replace AD_UNIT_ID with your real AdMob rewarded unit ID before shipping.

const AD_LOAN_LABEL    := "Student Loan"
const AD_LOAN_AMOUNT   := 100_000.0
const AD_LOAN_COOLDOWN := 300.0    # seconds (5 minutes)
const AD_UNIT_ID       := "ca-app-pub-3940256099942544/5224354917"   # AdMob test ID


# ── Offline earnings cap ───────────────────────────────────────

const OFFLINE_CAP_SECONDS := 28800.0   # 8 hours
