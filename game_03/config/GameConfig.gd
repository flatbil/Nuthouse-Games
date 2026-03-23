extends Node

const SAVE_FILE := "user://frontier_battalion_save.json"
const GAME_TITLE := "FRONTIER BATTALION"

# ── Colors ─────────────────────────────────────────────
const COLOR_GOLD     := Color(0.87, 0.70, 0.00, 1.0)
const COLOR_RED      := Color(0.85, 0.15, 0.10, 1.0)
const COLOR_BLUE     := Color(0.20, 0.45, 0.85, 1.0)
const COLOR_GREEN    := Color(0.25, 0.75, 0.35, 1.0)
const COLOR_DARK_BG  := Color(0.10, 0.12, 0.08, 1.0)
const COLOR_PANEL_BG := Color(0.14, 0.16, 0.11, 0.95)

# ── Unit types ─────────────────────────────────────────
# max_hp, speed, damage, fire_rate (s), range (px), bullet_speed, color, description
const UNIT_TYPES: Dictionary = {
	"frontiersman": {
		"display_name": "Frontiersman",
		"max_hp":       5,
		"speed":        130.0,
		"damage":       2.5,
		"fire_rate":    1.8,
		"range":        320.0,
		"bullet_speed": 420.0,
		"color":        Color(0.72, 0.55, 0.30),   # buckskin
		"size":         Vector2(18, 22),
		"description":  "Your starting unit. Reliable rifle, good range.",
	},
	"militiaman": {
		"display_name": "Militiaman",
		"max_hp":       3,
		"speed":        120.0,
		"damage":       1.8,
		"fire_rate":    1.2,
		"range":        260.0,
		"bullet_speed": 380.0,
		"color":        Color(0.45, 0.55, 0.40),   # drab green
		"size":         Vector2(16, 20),
		"description":  "Fast firing, low HP. Good in numbers.",
	},
	"continental": {
		"display_name": "Continental",
		"max_hp":       6,
		"speed":        110.0,
		"damage":       2.2,
		"fire_rate":    1.5,
		"range":        280.0,
		"bullet_speed": 400.0,
		"color":        Color(0.20, 0.30, 0.65),   # blue coat
		"size":         Vector2(18, 22),
		"description":  "Disciplined soldier. Steady under fire.",
	},
	"rifleman": {
		"display_name": "Rifleman",
		"max_hp":       3,
		"speed":        115.0,
		"damage":       5.0,
		"fire_rate":    3.2,
		"range":        480.0,
		"bullet_speed": 550.0,
		"color":        Color(0.35, 0.55, 0.25),   # dark green
		"size":         Vector2(16, 20),
		"description":  "Long range, high damage, slow reload.",
	},
	"grenadier": {
		"display_name": "Grenadier",
		"max_hp":       8,
		"speed":        90.0,
		"damage":       9.0,
		"fire_rate":    4.0,
		"range":        220.0,
		"bullet_speed": 250.0,
		"color":        Color(0.70, 0.20, 0.15),   # red coat (captured!)
		"size":         Vector2(20, 24),
		"description":  "Slow but devastating. Grenade arc damage.",
		"is_grenade":   true,
		"grenade_radius": 80.0,
	},
	"native_scout": {
		"display_name": "Native Scout",
		"max_hp":       3,
		"speed":        160.0,
		"damage":       2.0,
		"fire_rate":    0.7,
		"range":        200.0,
		"bullet_speed": 500.0,
		"color":        Color(0.80, 0.45, 0.20),   # copper
		"size":         Vector2(15, 19),
		"description":  "Fastest unit. Rapid-fire tomahawk.",
	},
}

# ── Enemy types ────────────────────────────────────────
const ENEMY_TYPES: Dictionary = {
	"skirmisher": {
		"display_name": "Skirmisher",
		"max_hp":       4.0,
		"speed":        55.0,
		"damage":       1.5,
		"attack_range": 30.0,   # melee
		"fire_rate":    1.2,
		"bullet_speed": 0.0,    # melee
		"reward":       3,
		"color":        Color(0.75, 0.15, 0.10),
		"size":         Vector2(16, 20),
		"is_melee":     true,
	},
	"musketman": {
		"display_name": "Redcoat",
		"max_hp":       6.0,
		"speed":        40.0,
		"damage":       2.0,
		"attack_range": 240.0,
		"fire_rate":    2.5,
		"bullet_speed": 320.0,
		"reward":       5,
		"color":        Color(0.80, 0.12, 0.10),
		"size":         Vector2(18, 22),
		"is_melee":     false,
	},
	"grenadier_enemy": {
		"display_name": "British Grenadier",
		"max_hp":       12.0,
		"speed":        35.0,
		"damage":       7.0,
		"attack_range": 200.0,
		"fire_rate":    4.0,
		"bullet_speed": 200.0,
		"reward":       12,
		"color":        Color(0.85, 0.20, 0.15),
		"size":         Vector2(20, 25),
		"is_melee":     false,
		"is_grenade":   true,
		"grenade_radius": 70.0,
	},
	"cavalry": {
		"display_name": "Cavalry",
		"max_hp":       8.0,
		"speed":        130.0,
		"damage":       5.0,
		"attack_range": 25.0,
		"fire_rate":    1.0,
		"bullet_speed": 0.0,
		"reward":       10,
		"color":        Color(0.60, 0.10, 0.10),
		"size":         Vector2(22, 18),
		"is_melee":     true,
		"is_cavalry":   true,
	},
}

# ── Wave definitions ───────────────────────────────────
# Each wave: array of [enemy_type, count]
const WAVES: Array = [
	# Wave 1
	[["skirmisher", 4]],
	# Wave 2
	[["skirmisher", 3], ["musketman", 2]],
	# Wave 3
	[["musketman", 5]],
	# Wave 4
	[["skirmisher", 4], ["musketman", 3]],
	# Wave 5 — BOSS WAVE
	[["musketman", 6], ["grenadier_enemy", 1]],
	# Wave 6
	[["cavalry", 2], ["musketman", 4]],
	# Wave 7
	[["skirmisher", 5], ["musketman", 4], ["cavalry", 1]],
	# Wave 8
	[["musketman", 6], ["grenadier_enemy", 2]],
	# Wave 9 — BOSS WAVE
	[["cavalry", 3], ["musketman", 5], ["grenadier_enemy", 2]],
	# Wave 10 — FINAL
	[["musketman", 8], ["cavalry", 3], ["grenadier_enemy", 3]],
]

# ── Run upgrades (pick 1 of 3 between waves) ──────────
const RUN_UPGRADES: Array = [
	{"id": "add_militiaman",  "name": "Recruit Militiaman",    "desc": "Add a Militiaman to your formation.",         "type": "add_unit",  "unit": "militiaman"},
	{"id": "add_continental", "name": "Recruit Continental",   "desc": "Add a Continental soldier to your ranks.",    "type": "add_unit",  "unit": "continental"},
	{"id": "add_rifleman",    "name": "Recruit Rifleman",      "desc": "A sharpshooter joins the formation.",         "type": "add_unit",  "unit": "rifleman"},
	{"id": "add_grenadier",   "name": "Recruit Grenadier",     "desc": "A grenadier adds explosive firepower.",       "type": "add_unit",  "unit": "grenadier"},
	{"id": "add_scout",       "name": "Recruit Native Scout",  "desc": "A swift scout flanks your enemies.",         "type": "add_unit",  "unit": "native_scout"},
	{"id": "hp_up",           "name": "Field Surgeon",         "desc": "Restore 3 HP to each soldier.",               "type": "heal",      "amount": 3},
	{"id": "damage_up",       "name": "Powder Upgrade",        "desc": "+25% damage for all soldiers this run.",      "type": "stat",      "stat": "damage",    "mult": 1.25},
	{"id": "speed_up",        "name": "Light Marching Order",  "desc": "+20% movement speed this run.",               "type": "stat",      "stat": "speed",     "mult": 1.20},
	{"id": "reload_up",       "name": "Cartridge Drill",       "desc": "+25% fire rate for all soldiers.",            "type": "stat",      "stat": "fire_rate", "mult": 0.75},
	{"id": "range_up",        "name": "Long Rifle",            "desc": "+30% range for all soldiers.",                "type": "stat",      "stat": "range",     "mult": 1.30},
]

# ── Meta upgrades (spend Hoard between runs) ───────────
const META_UPGRADES: Array = [
	{"id": "extra_recruit",  "name": "Frontier Recruitment", "desc": "Start each run with 1 extra Militiaman.",  "cost": 50,  "max_level": 2, "type": "start_unit", "unit": "militiaman"},
	{"id": "starting_hp",    "name": "Field Rations",         "desc": "+1 max HP for all soldiers.",             "cost": 40,  "max_level": 5, "type": "stat", "stat": "max_hp",  "bonus": 1},
	{"id": "starting_dmg",   "name": "Better Powder",         "desc": "+10% base damage.",                       "cost": 60,  "max_level": 4, "type": "stat", "stat": "damage",  "mult": 1.10},
	{"id": "starting_speed", "name": "Trail Experience",      "desc": "+8% movement speed.",                     "cost": 45,  "max_level": 4, "type": "stat", "stat": "speed",   "mult": 1.08},
	{"id": "hoard_bonus",    "name": "Scavenger",             "desc": "+20% gold from enemies.",                 "cost": 80,  "max_level": 3, "type": "hoard_mult", "mult": 1.20},
	{"id": "unlock_rifleman","name": "Marksman Training",     "desc": "Riflemen can appear as run upgrades.",    "cost": 100, "max_level": 1, "type": "unlock_unit", "unit": "rifleman"},
	{"id": "unlock_grenadier","name":"Grenadier Corps",       "desc": "Grenadiers can appear as run upgrades.",  "cost": 150, "max_level": 1, "type": "unlock_unit", "unit": "grenadier"},
	{"id": "unlock_scout",   "name": "Native Alliance",       "desc": "Native Scouts can appear as run upgrades.","cost": 120, "max_level": 1, "type": "unlock_unit", "unit": "native_scout"},
]

# ── Formation layout ───────────────────────────────────
# Positions relative to formation center for N soldiers.
# Soldiers arranged in a line (perpendicular to facing direction).
# This gives offset in LOCAL space (x = along line, y = 0 means front)
static func get_formation_offsets(count: int) -> Array:
	var offsets: Array = []
	var spacing: float = 26.0
	# Line formation: 1 row up to 5, then 2 rows
	var per_row: int = min(count, 5)
	var rows: int = ceili(float(count) / float(per_row))
	var idx: int = 0
	for row in range(rows):
		var in_row: int = min(per_row, count - row * per_row)
		for col in range(in_row):
			var x: float = (float(col) - float(in_row - 1) * 0.5) * spacing
			var y: float = float(row) * spacing * 0.8
			offsets.append(Vector2(x, y))
			idx += 1
	return offsets

# ── Difficulty scaling ─────────────────────────────────
static func enemy_hp_scale(wave: int) -> float:
	return 1.0 + float(wave) * 0.15

static func enemy_speed_scale(wave: int) -> float:
	return 1.0 + float(wave) * 0.05
