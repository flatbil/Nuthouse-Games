extends Node

# ═══════════════════════════════════════════════════════════════
# GameConfig — Asteroid Miner
#
# Four-track system:
#   TRACK_A  Mining Drills    — one-time mine yield boosters
#   TRACK_B  Mining Drones    — repeatable passive generators
#   TRACK_C  Ship Upgrades    — one-time passive multipliers
#   TRACK_D  Exosuit Upgrades — one-time mine yield multipliers
# ═══════════════════════════════════════════════════════════════


# ── Identity ───────────────────────────────────────────────────

const SAVE_FILE := "user://asteroid_miner_save.json"


# ── Currency ───────────────────────────────────────────────────

const CURRENCY_FORMAT := "$%s"   # Credits (value of ore sold)


# ── Theme ──────────────────────────────────────────────────────

const COLOR_PRIMARY    := Color(0.30, 0.80, 1.00, 1.0)  # cyan — space tech feel
const COLOR_HEADER_LIT := Color(0.50, 1.00, 0.80, 1.0)  # bright teal when affordable
const COLOR_GOLD       := Color(0.87, 0.70, 0.00, 1.0)  # gold indicators
const COLOR_BG         := Color(0.04, 0.04, 0.12, 1.0)  # deep space background


# ── HUD Labels ─────────────────────────────────────────────────

const IDLE_HINT           := "Tap to Move"
const TAP_STAT_LABEL      := "Mining Rate"
const TAP_STAT_MULTIPLIER := 3600.0     # credits per hour at current mine yield
const PORTFOLIO_LABEL     := "Ore Mined"
const DIVIDENDS_LABEL     := "From Drones"
const GOAL_LABEL          := "Mission End"
const GOAL_MET_LABEL      := "MISSION COMPLETE!"
const GOAL_AGE            := 49.0       # mission years (same as game_01 career span)


# ── Section Titles ─────────────────────────────────────────────

const TRACK_A_TITLE := "DRILLS"
const TRACK_B_TITLE := "DRONES"
const TRACK_C_TITLE := "SHIP MODS"
const TRACK_D_TITLE := "EXOSUIT"


# ── Wealth / Progress Stages ───────────────────────────────────

const STAGES: Array = [
	{"threshold": 0.0,                 "label": "Space Rookie"},
	{"threshold": 1_000.0,             "label": "Belt Prospector"},
	{"threshold": 50_000.0,            "label": "Ore Runner"},
	{"threshold": 1_000_000.0,         "label": "Asteroid Baron"},
	{"threshold": 50_000_000.0,        "label": "Mining Mogul"},
	{"threshold": 1_000_000_000.0,     "label": "Ore Lord"},
	{"threshold": 1_000_000_000_000.0, "label": "Galactic Tycoon"},
	{"threshold": 1.0e15,              "label": "Cosmic Emperor"},
	{"threshold": 1.0e18,              "label": "Star Harvester"},
	{"threshold": 1.0e21,              "label": "Galactic Overlord"},
	{"threshold": 1.0e24,              "label": "Universal Industrialist"},
	{"threshold": 1.0e30,              "label": "Beyond Comprehension"},
]


# ── Track A — Mining Drills ────────────────────────────────────
# One-time purchases that permanently increase mine yield (tap_bonus).

const TRACK_A: Array = [
	{
		"name":        "Rock Hammer",
		"description": "A trusty hammer. Mine +2 credits.",
		"cost":        40.0,
		"tap_bonus":   2.0,
	},
	{
		"name":        "Drill Bit",
		"description": "Upgraded tool. Mine +10 credits.",
		"cost":        350.0,
		"tap_bonus":   10.0,
	},
	{
		"name":        "Plasma Cutter",
		"description": "Slices rock clean. Mine +35 credits.",
		"cost":        4_000.0,
		"tap_bonus":   35.0,
	},
	{
		"name":        "Laser Array",
		"description": "Precision mining laser. Mine +120 credits.",
		"cost":        35_000.0,
		"tap_bonus":   120.0,
	},
	{
		"name":        "Quantum Extractor",
		"description": "Atomic-level extraction. Mine +500 credits.",
		"cost":        280_000.0,
		"tap_bonus":   500.0,
	},
	{
		"name":        "Dark Matter Drill",
		"description": "Reality-bending tech. Mine +2,000 credits.",
		"cost":        2_500_000.0,
		"tap_bonus":   2_000.0,
	},
]


# ── Track B — Mining Drones ────────────────────────────────────
# Repeatable passive generators. Each unit adds income_per_sec.

const TRACK_B: Array = [
	{
		"name":           "Scout Drone",
		"description":    "+0.25 credits/sec each",
		"base_cost":      75.0,
		"growth_rate":    1.14,
		"income_per_sec": 0.25,
	},
	{
		"name":           "Harvester Bot",
		"description":    "+3 credits/sec each",
		"base_cost":      900.0,
		"growth_rate":    1.14,
		"income_per_sec": 3.0,
	},
	{
		"name":           "Mining Pod",
		"description":    "+45 credits/sec each",
		"base_cost":      12_000.0,
		"growth_rate":    1.14,
		"income_per_sec": 45.0,
	},
	{
		"name":           "Ore Processor",
		"description":    "+700 credits/sec each",
		"base_cost":      160_000.0,
		"growth_rate":    1.14,
		"income_per_sec": 700.0,
	},
	{
		"name":           "Asteroid Ripper",
		"description":    "+11,000 credits/sec each",
		"base_cost":      2_200_000.0,
		"growth_rate":    1.14,
		"income_per_sec": 11_000.0,
	},
]


# ── Track C — Ship Upgrades ────────────────────────────────────
# One-time multipliers on total passive (drone) income.

const TRACK_C: Array = [
	{
		"name":        "Cargo Bay Upgrade",
		"description": "2x all drone output",
		"cost":        10_000.0,
		"multiplier":  2.0,
	},
	{
		"name":        "Ore Refinery",
		"description": "3x all drone output",
		"cost":        500_000.0,
		"multiplier":  3.0,
	},
	{
		"name":        "Nanite Processors",
		"description": "5x all drone output",
		"cost":        18_000_000.0,
		"multiplier":  5.0,
	},
]


# ── Track D — Exosuit Upgrades ────────────────────────────────
# One-time multipliers on manual mine yield. Keeps active play
# competitive with passive drone income at late game.

const TRACK_D: Array = [
	{
		"name":        "Exo-Skeleton",
		"description": "2x mine yield",
		"cost":        1_500_000.0,
		"multiplier":  2.0,
	},
	{
		"name":        "Thruster Pack",
		"description": "3x mine yield",
		"cost":        18_000_000.0,
		"multiplier":  3.0,
	},
	{
		"name":        "Quantum Suit",
		"description": "5x mine yield",
		"cost":        180_000_000.0,
		"multiplier":  5.0,
	},
	{
		"name":        "Void Armor",
		"description": "8x mine yield",
		"cost":        1_800_000_000.0,
		"multiplier":  8.0,
	},
	{
		"name":        "Singularity Harness",
		"description": "15x mine yield",
		"cost":        18_000_000_000.0,
		"multiplier":  15.0,
	},
	{
		"name":        "God-Particle Suit",
		"description": "25x mine yield",
		"cost":        180_000_000_000.0,
		"multiplier":  25.0,
	},
]


# ── Rewarded Ad / Emergency Supply Drop ───────────────────────

const AD_LOAN_LABEL    := "Emergency Supply Drop"
const AD_LOAN_AMOUNT   := 100_000.0
const AD_LOAN_COOLDOWN := 300.0
const AD_UNIT_ID       := "ca-app-pub-3940256099942544/5224354917"   # AdMob test ID


# ── Offline earnings cap ───────────────────────────────────────

const OFFLINE_CAP_SECONDS := 28800.0   # 8 hours
