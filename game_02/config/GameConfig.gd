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

const TRACK_A_TITLE := "SPACECRAFT"
const TRACK_B_TITLE := "MINING FLEET"
const TRACK_C_TITLE := "SHIP SYSTEMS"
const TRACK_D_TITLE := "PILOT SKILLS"


# ── Asteroid Tiers ─────────────────────────────────────────────
# Matched 1-to-1 with zones (T1 = zone 0, T5 = zone 4).
# hits:         mine swings needed to break
# reward_scale: multiplier on get_effective_tap_value() when asteroid breaks
# sprite_scale: scales the whole asteroid node (visual + collision)
# color:        modulate tint so tiers look distinct

const ASTEROID_TIERS: Array = [
	{"tier": 1, "hits":   3, "reward_scale":  1.0, "sprite_scale": 0.9, "color": Color(1.00, 1.00, 1.00)},
	{"tier": 2, "hits":   8, "reward_scale":  3.0, "sprite_scale": 1.3, "color": Color(0.60, 0.85, 1.00)},
	{"tier": 3, "hits":  20, "reward_scale":  8.0, "sprite_scale": 1.8, "color": Color(0.50, 1.00, 0.60)},
	{"tier": 4, "hits":  50, "reward_scale": 20.0, "sprite_scale": 2.3, "color": Color(1.00, 0.85, 0.30)},
	{"tier": 5, "hits": 100, "reward_scale": 50.0, "sprite_scale": 3.0, "color": Color(1.00, 0.50, 0.50)},
]


# ── Orbital Zones ──────────────────────────────────────────────
# Each zone is a ring of asteroids at a greater orbital radius.
# ore_multiplier scales ALL income (active + passive) when in that zone.
# Unlocked by buying the corresponding TRACK_A spacecraft.

const ZONES: Array = [
	{"name": "Near-Earth Debris",   "radius_min":  80, "radius_max": 130, "ore_multiplier":    1.0},
	{"name": "Inner Asteroid Belt", "radius_min": 170, "radius_max": 240, "ore_multiplier":    6.0},
	{"name": "Main Belt",           "radius_min": 290, "radius_max": 390, "ore_multiplier":   40.0},
	{"name": "Trojan Clusters",     "radius_min": 430, "radius_max": 560, "ore_multiplier":  300.0},
	{"name": "Kuiper Belt",         "radius_min": 640, "radius_max": 820, "ore_multiplier": 2500.0},
]


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


# ── Track A — Spacecraft ───────────────────────────────────────
# One-time purchases. Each adds tap_bonus to mine yield.
# Items with unlocks_zone >= 0 also open a new orbital zone
# (multiplying ALL income by that zone's ore_multiplier).

const TRACK_A: Array = [
	{
		"name":         "Mining Toolkit",
		"description":  "Better tools for your suit. Mine +10 credits.",
		"cost":         350.0,
		"tap_bonus":    10.0,
		"ship_tier":    1,
		"unlocks_zone": -1,
	},
	{
		"name":         "EVA Jetpack",
		"description":  "Boost mobility in zero-g. Mine +35 credits.",
		"cost":         4_000.0,
		"tap_bonus":    35.0,
		"ship_tier":    1,
		"unlocks_zone": -1,
	},
	{
		"name":         "Scout Rocket",
		"description":  "Your first real ship. Reach the Inner Belt!",
		"cost":         50_000.0,
		"tap_bonus":    120.0,
		"ship_tier":    2,
		"unlocks_zone": 1,
	},
	{
		"name":         "Mining Vessel",
		"description":  "Pressurised hull, drill array. Reach the Main Belt!",
		"cost":         600_000.0,
		"tap_bonus":    500.0,
		"ship_tier":    3,
		"unlocks_zone": 2,
	},
	{
		"name":         "Ion Drive Ship",
		"description":  "High-efficiency drive. Reach the Trojan Clusters!",
		"cost":         7_000_000.0,
		"tap_bonus":    2_000.0,
		"ship_tier":    4,
		"unlocks_zone": 3,
	},
	{
		"name":         "Warp Freighter",
		"description":  "Fold space, unlimited range. Reach the Kuiper Belt!",
		"cost":         80_000_000.0,
		"tap_bonus":    10_000.0,
		"ship_tier":    5,
		"unlocks_zone": 4,
	},
]


# ── Track B — Mining Fleet ─────────────────────────────────────
# Repeatable. Each unit adds income_per_sec (before zone multiplier).

const TRACK_B: Array = [
	{
		"name":           "Survey Probe",
		"description":    "+0.25 credits/sec each",
		"base_cost":      75.0,
		"growth_rate":    1.14,
		"income_per_sec": 0.25,
	},
	{
		"name":           "Mining Drone",
		"description":    "+3 credits/sec each",
		"base_cost":      900.0,
		"growth_rate":    1.14,
		"income_per_sec": 3.0,
	},
	{
		"name":           "Harvester Bot",
		"description":    "+45 credits/sec each",
		"base_cost":      12_000.0,
		"growth_rate":    1.14,
		"income_per_sec": 45.0,
	},
	{
		"name":           "Automated Rig",
		"description":    "+700 credits/sec each",
		"base_cost":      160_000.0,
		"growth_rate":    1.14,
		"income_per_sec": 700.0,
	},
	{
		"name":           "Swarm Network",
		"description":    "+11,000 credits/sec each",
		"base_cost":      2_200_000.0,
		"growth_rate":    1.14,
		"income_per_sec": 11_000.0,
	},
]


# ── Track C — Ship Systems ─────────────────────────────────────
# One-time multipliers on total fleet (passive) income.

const TRACK_C: Array = [
	{
		"name":        "Ore Processor",
		"description": "2x all fleet output",
		"cost":        10_000.0,
		"multiplier":  2.0,
	},
	{
		"name":        "Quantum Refinery",
		"description": "3x all fleet output",
		"cost":        500_000.0,
		"multiplier":  3.0,
	},
	{
		"name":        "AI Mining Core",
		"description": "5x all fleet output",
		"cost":        18_000_000.0,
		"multiplier":  5.0,
	},
]


# ── Track D — Pilot Skills ─────────────────────────────────────
# One-time multipliers on manual mine yield.

const TRACK_D: Array = [
	{
		"name":        "Navigation Computer",
		"description": "2x mine yield",
		"cost":        1_500_000.0,
		"multiplier":  2.0,
	},
	{
		"name":        "Predictive Mining AI",
		"description": "3x mine yield",
		"cost":        18_000_000.0,
		"multiplier":  3.0,
	},
	{
		"name":        "Neural Interface",
		"description": "5x mine yield",
		"cost":        180_000_000.0,
		"multiplier":  5.0,
	},
	{
		"name":        "Quantum Targeting",
		"description": "8x mine yield",
		"cost":        1_800_000_000.0,
		"multiplier":  8.0,
	},
	{
		"name":        "Singularity Drive",
		"description": "15x mine yield",
		"cost":        18_000_000_000.0,
		"multiplier":  15.0,
	},
	{
		"name":        "Transcendence",
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
