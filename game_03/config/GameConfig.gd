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
		"color":        Color(0.72, 0.55, 0.30),
		"size":         Vector2(18, 22),
		"sprite":       "tile_0124",
		"smoke_size":   1.0,
		"melee_damage": 4.0,
		"melee_range":  28.0,
		"melee_rate":   0.5,
		"melee_weapon": "weap_axe",
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
		"color":        Color(0.45, 0.55, 0.40),
		"size":         Vector2(16, 20),
		"sprite":       "tile_0122",
		"smoke_size":   1.0,
		"melee_damage": 2.0,
		"melee_range":  24.0,
		"melee_rate":   0.4,
		"melee_weapon": "weap_sword",
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
		"color":        Color(0.20, 0.30, 0.65),
		"size":         Vector2(18, 22),
		"sprite":       "tile_0142",
		"smoke_size":   2.2,
		"melee_damage": 3.5,
		"melee_range":  28.0,
		"melee_rate":   0.5,
		"melee_weapon": "weap_sword",
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
		"color":        Color(0.35, 0.55, 0.25),
		"size":         Vector2(16, 20),
		"sprite":       "tile_0143",
		"smoke_size":   1.4,
		"melee_damage": 2.5,
		"melee_range":  26.0,
		"melee_rate":   0.6,
		"melee_weapon": "weap_sword",
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
		"color":        Color(0.70, 0.20, 0.15),
		"size":         Vector2(20, 24),
		"sprite":       "tile_0125",
		"smoke_size":   1.0,
		"melee_damage": 6.0,
		"melee_range":  30.0,
		"melee_rate":   0.7,
		"melee_weapon": "weap_sword",
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
		"color":        Color(0.80, 0.45, 0.20),
		"size":         Vector2(15, 19),
		"sprite":       "tile_0120",
		"smoke_size":   0.8,
		"melee_damage": 3.5,
		"melee_range":  24.0,
		"melee_rate":   0.35,
		"melee_weapon": "weap_axe",
		"description":  "Fastest unit. Rapid-fire tomahawk.",
	},
	"hero": {
		"display_name": "Captain",
		"max_hp":       12,
		"damage":       3.0,
		"fire_rate":    1.5,
		"range":        340.0,
		"bullet_speed": 440.0,
		"sprite":       "tile_0138",
		"size":         Vector2(20, 24),
		"smoke_size":   1.3,
		"melee_damage": 5.0,
		"melee_range":  32.0,
		"melee_rate":   0.4,
		"melee_weapon": "weap_sword",
		"description":  "Your Captain. Leads from the front. Equip weapons to enhance.",
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
		"sprite":       "tile_0149",
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
		"sprite":       "tile_0151",
		"smoke_size":   2.5,
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
		"sprite":       "tile_0153",
		"smoke_size":   1.0,
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
		"sprite":       "tile_0156",
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

# ── Weapons (equippable by hero) ───────────────────────
# Absolute stats — each weapon has a distinct playstyle.
# fire_rate = reload time in seconds (lower = faster).
# scatter_count / scatter_angle apply to shot_type "scatter".
# dual_spread applies to shot_type "dual".
const WEAPONS: Dictionary = {
	"flintlock": {
		"display_name":  "Flintlock Pistol",
		"shot_type":     "single",
		"damage":        3.5,
		"fire_rate":     1.1,
		"range":         300.0,
		"bullet_speed":  440.0,
		"scatter_count": 1,
		"scatter_angle": 0.0,
		"dual_spread":   0.0,
		"smoke_size":    1.0,
		"desc":          "Quick draw sidearm. Fast shots, medium range.",
	},
	"long_rifle": {
		"display_name":  "Long Rifle",
		"shot_type":     "single",
		"damage":        7.0,
		"fire_rate":     3.5,
		"range":         520.0,
		"bullet_speed":  580.0,
		"scatter_count": 1,
		"scatter_angle": 0.0,
		"dual_spread":   0.0,
		"smoke_size":    1.4,
		"desc":          "Superior range and stopping power. Slow to reload.",
	},
	"blunderbuss": {
		"display_name":  "Blunderbuss",
		"shot_type":     "scatter",
		"damage":        3.2,
		"fire_rate":     2.2,
		"range":         165.0,
		"bullet_speed":  360.0,
		"scatter_count": 5,
		"scatter_angle": 38.0,
		"dual_spread":   0.0,
		"smoke_size":    2.5,
		"desc":          "Close-range devastation. Fires 5 pellets in a wide cone.",
	},
	"cavalry_pistols": {
		"display_name":  "Cavalry Pistols",
		"shot_type":     "dual",
		"damage":        2.2,
		"fire_rate":     0.75,
		"range":         220.0,
		"bullet_speed":  460.0,
		"scatter_count": 1,
		"scatter_angle": 0.0,
		"dual_spread":   10.0,
		"smoke_size":    1.0,
		"desc":          "Dual pistols fire together. Rapid and relentless.",
	},
	"kentucky_rifle": {
		"display_name":  "Kentucky Rifle",
		"shot_type":     "penetrating",
		"damage":        12.0,
		"fire_rate":     4.5,
		"range":         700.0,
		"bullet_speed":  620.0,
		"scatter_count": 1,
		"scatter_angle": 0.0,
		"dual_spread":   0.0,
		"smoke_size":    1.6,
		"desc":          "Master-crafted. Bullet pierces through multiple enemies.",
	},
}

const WEAPON_MAX_LEVEL    := 3
const WEAPON_UPGRADE_COST := 3   # copies needed per level

# Per-level scaling: damage +15%, fire_rate -10% (faster), range +10%
static func weapon_stat(weapon_id: String, stat: String, level: int) -> float:
	var base: float = float(WEAPONS.get(weapon_id, {}).get(stat, 0.0))
	if base == 0.0:
		return base
	match stat:
		"damage":    return base * pow(1.15, level)
		"fire_rate": return base * pow(0.90, level)
		"range":     return base * (1.0 + level * 0.10)
		_:           return base

# ── Uniform upgrade ────────────────────────────────────
const UNIFORM_MAX_LEVEL   := 10
const UNIFORM_TIER_NAMES  := [
	"Recruit", "Recruit", "Recruit",    # 0-2
	"Soldier", "Soldier", "Soldier",    # 3-5
	"Veteran", "Veteran", "Veteran",    # 6-8
	"Officer", "Officer",               # 9-10
]
const UNIFORM_TIER_COLORS := {
	"Recruit": Color(0.75, 0.75, 0.75),
	"Soldier": Color(0.20, 0.55, 1.00),
	"Veteran": Color(0.70, 0.20, 0.95),
	"Officer": Color(1.00, 0.75, 0.00),
}

static func uniform_upgrade_cost(level: int) -> int:
	return 10 * (level + 1)   # 10, 20, 30 … 100 gems

static func uniform_hp_bonus(level: int) -> int:
	return level * 2           # +2 HP per level

static func uniform_damage_mult(level: int) -> float:
	return 1.0 + level * 0.08  # +8% damage per level

static func uniform_speed_mult(level: int) -> float:
	return 1.0 + level * 0.04  # +4% speed per level

# ── Collectible drop tables ─────────────────────────────
# Each entry: {type, amount, chance}  (chance 0–1 per drop roll)
const COLLECTIBLE_DROPS: Dictionary = {
	"skirmisher":      [{"type": "gold",   "amount": 3,  "chance": 1.00}],
	"musketman":       [{"type": "gold",   "amount": 5,  "chance": 0.80},
	                    {"type": "gem",    "amount": 1,  "chance": 0.20},
	                    {"type": "weapon", "amount": 1,  "chance": 0.05}],
	"grenadier_enemy": [{"type": "gold",   "amount": 12, "chance": 0.70},
	                    {"type": "gem",    "amount": 2,  "chance": 0.30},
	                    {"type": "weapon", "amount": 1,  "chance": 0.15}],
	"cavalry":         [{"type": "gold",   "amount": 10, "chance": 0.60},
	                    {"type": "gem",    "amount": 2,  "chance": 0.30},
	                    {"type": "weapon", "amount": 1,  "chance": 0.25}],
}

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
	var per_row: int = min(count, 5)
	var rows: int = ceili(float(count) / float(per_row))
	for row in range(rows):
		var in_row: int = min(per_row, count - row * per_row)
		for col in range(in_row):
			var x: float = (float(col) - float(in_row - 1) * 0.5) * spacing
			var y: float = float(row) * spacing * 0.8
			offsets.append(Vector2(x, y))
	# Sort center-first so index 0 (hero slot) is always the centermost position
	offsets.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var da: float = a.length_squared()
		var db: float = b.length_squared()
		if abs(da - db) < 1.0:
			return a.x < b.x
		return da < db)
	return offsets

# ── Difficulty scaling ─────────────────────────────────
static func enemy_hp_scale(wave: int) -> float:
	return 1.0 + float(wave) * 0.15

static func enemy_speed_scale(wave: int) -> float:
	return 1.0 + float(wave) * 0.05
