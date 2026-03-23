extends Node

# Persistent across runs
var hoard:          int  = 0
var meta_levels:    Dictionary = {}   # upgrade_id -> current level
var best_wave:      int  = 0
var total_runs:     int  = 0
var unlocked_units: Array = ["frontiersman", "militiaman", "continental"]

var gems:             int        = 0
var hero_weapon:      String     = "flintlock"
var weapon_inventory: Dictionary = {"flintlock": 1}  # weapon_id -> count
var uniform_level:    int        = 0

# Per-run state (reset each run)
var run_hoard_earned: int   = 0
var waves_cleared:    int   = 0
var run_stat_mults:   Dictionary = {}   # stat -> multiplier accumulated this run
var run_soldiers:     Array = []        # current soldier type list

func _ready() -> void:
	_init_meta_levels()
	_load()


func reset() -> void:
	hoard          = 0
	best_wave      = 0
	total_runs     = 0
	unlocked_units = ["frontiersman", "militiaman", "continental"]
	gems           = 0
	hero_weapon       = "flintlock"
	weapon_inventory  = {"flintlock": 1}
	uniform_level     = 0
	_init_meta_levels()

func _init_meta_levels() -> void:
	for upgrade in GameConfig.META_UPGRADES:
		meta_levels[upgrade["id"]] = 0

# ── Meta upgrade purchase ──────────────────────────────
func can_buy_meta(index: int) -> bool:
	var u: Dictionary = GameConfig.META_UPGRADES[index]
	var level: int    = meta_levels.get(u["id"], 0)
	return hoard >= u["cost"] and level < int(u["max_level"])

func buy_meta(index: int) -> void:
	if not can_buy_meta(index):
		return
	var u: Dictionary = GameConfig.META_UPGRADES[index]
	hoard -= int(u["cost"])
	meta_levels[u["id"]] = meta_levels.get(u["id"], 0) + 1
	if u["type"] == "unlock_unit":
		var uid: String = u["unit"]
		if not unlocked_units.has(uid):
			unlocked_units.append(uid)
	EventBus.hoard_changed.emit(hoard)
	_save()

# ── Run lifecycle ──────────────────────────────────────
func start_run() -> void:
	run_hoard_earned = 0
	waves_cleared    = 0
	run_stat_mults   = {}
	run_soldiers     = _build_starting_soldiers()
	total_runs      += 1
	EventBus.run_started.emit()

func end_run(wave: int) -> void:
	waves_cleared = wave
	if wave > best_wave:
		best_wave = wave
	hoard += run_hoard_earned
	EventBus.hoard_changed.emit(hoard)
	EventBus.run_ended.emit(run_hoard_earned, waves_cleared)
	_save()

func add_run_hoard(amount: int) -> void:
	var mult: float = _hoard_multiplier()
	run_hoard_earned += int(float(amount) * mult)

# ── Run upgrades ───────────────────────────────────────
func apply_run_upgrade(upgrade: Dictionary) -> void:
	match upgrade["type"]:
		"add_unit":
			run_soldiers.append(upgrade["unit"])
		"stat":
			var key: String = upgrade["stat"]
			run_stat_mults[key] = run_stat_mults.get(key, 1.0) * float(upgrade["mult"])
		"heal":
			pass   # handled by Formation directly

func get_run_stat_mult(stat: String) -> float:
	return float(run_stat_mults.get(stat, 1.0))

# ── Effective stats (meta + run mults) ────────────────
func get_unit_stat(unit_type: String, stat: String) -> float:
	var base: float = float(GameConfig.UNIT_TYPES[unit_type].get(stat, 1.0))
	# Apply meta bonuses
	for upgrade in GameConfig.META_UPGRADES:
		var level: int = meta_levels.get(upgrade["id"], 0)
		if level == 0:
			continue
		if upgrade["type"] == "stat" and upgrade["stat"] == stat:
			if upgrade.has("mult"):
				base *= pow(float(upgrade["mult"]), level)
			elif upgrade.has("bonus"):
				base += float(upgrade["bonus"]) * level
	# Apply run mults
	base *= get_run_stat_mult(stat)
	# Apply hero weapon + uniform multipliers
	if unit_type == "hero":
		var weapon: Dictionary = GameConfig.WEAPONS.get(hero_weapon, {})
		if weapon.has(stat):
			base *= float(weapon[stat])
		match stat:
			"max_hp": base += float(GameConfig.uniform_hp_bonus(uniform_level))
			"damage": base *= GameConfig.uniform_damage_mult(uniform_level)
			"speed":  base *= GameConfig.uniform_speed_mult(uniform_level)
	return base

# ── Available run upgrade pool ─────────────────────────
func get_run_upgrade_choices(count: int = 3) -> Array:
	var pool: Array = []
	for u in GameConfig.RUN_UPGRADES:
		if u["type"] == "add_unit":
			if not unlocked_units.has(u["unit"]):
				continue
		pool.append(u)
	pool.shuffle()
	return pool.slice(0, min(count, pool.size()))

# ── Private ────────────────────────────────────────────
func _build_starting_soldiers() -> Array:
	var list: Array = []   # hero is always added separately via Formation.add_hero()
	for upgrade in GameConfig.META_UPGRADES:
		var id: String = upgrade["id"]
		var level: int = meta_levels.get(id, 0)
		if level > 0 and upgrade["type"] == "start_unit":
			for _i in range(level):
				list.append(upgrade["unit"])
	return list

func _hoard_multiplier() -> float:
	var mult := 1.0
	for upgrade in GameConfig.META_UPGRADES:
		if upgrade["type"] == "hoard_mult":
			var level: int = meta_levels.get(upgrade["id"], 0)
			if level > 0:
				mult *= pow(float(upgrade["mult"]), level)
	return mult

# ── Hero equipment ─────────────────────────────────────
func add_gems(amount: int) -> void:
	gems += amount
	EventBus.gem_changed.emit(gems)


func equip_weapon(weapon_id: String) -> void:
	if weapon_inventory.has(weapon_id):
		hero_weapon = weapon_id
		EventBus.hero_weapon_changed.emit(weapon_id)
		_save()


func add_to_inventory(weapon_id: String) -> void:
	weapon_inventory[weapon_id] = weapon_inventory.get(weapon_id, 0) + 1
	_save()


# ── Crafting ───────────────────────────────────────────

func can_combine(rarity: String) -> bool:
	return _count_rarity(rarity) >= 3


func combine_weapons(rarity: String) -> String:
	if not can_combine(rarity):
		return ""
	# Remove 3 weapons of this rarity from inventory
	var to_remove: int = 3
	for wid in weapon_inventory.keys():
		if to_remove == 0:
			break
		if not GameConfig.WEAPONS.has(wid):
			continue
		if GameConfig.WEAPONS[wid]["rarity"] != rarity:
			continue
		var take: int = min(weapon_inventory[wid], to_remove)
		weapon_inventory[wid] -= take
		to_remove -= take
		if weapon_inventory[wid] <= 0:
			weapon_inventory.erase(wid)
			if hero_weapon == wid:
				# Equip whatever is still in inventory, fallback flintlock
				hero_weapon = weapon_inventory.keys()[0] if not weapon_inventory.is_empty() else "flintlock"
				if weapon_inventory.is_empty():
					weapon_inventory["flintlock"] = 1
	# Determine next rarity
	var order: Array = ["common", "rare", "epic", "legendary"]
	var idx: int = order.find(rarity)
	if idx < 0 or idx >= order.size() - 1:
		return ""
	var next_rarity: String = order[idx + 1]
	# Pick a random weapon of next rarity
	var candidates: Array = []
	for wid in GameConfig.WEAPONS.keys():
		if GameConfig.WEAPONS[wid]["rarity"] == next_rarity:
			candidates.append(wid)
	if candidates.is_empty():
		return ""
	candidates.shuffle()
	var gained: String = candidates[0]
	weapon_inventory[gained] = weapon_inventory.get(gained, 0) + 1
	_save()
	return gained


func can_upgrade_uniform() -> bool:
	return uniform_level < GameConfig.UNIFORM_MAX_LEVEL and \
	       gems >= GameConfig.uniform_upgrade_cost(uniform_level)


func upgrade_uniform() -> void:
	if not can_upgrade_uniform():
		return
	gems -= GameConfig.uniform_upgrade_cost(uniform_level)
	uniform_level += 1
	EventBus.gem_changed.emit(gems)
	_save()


func _count_rarity(rarity: String) -> int:
	var total: int = 0
	for wid in weapon_inventory.keys():
		if GameConfig.WEAPONS.has(wid) and GameConfig.WEAPONS[wid]["rarity"] == rarity:
			total += weapon_inventory.get(wid, 0)
	return total


func _save() -> void:
	var data := {
		"hoard":          hoard,
		"meta_levels":    meta_levels,
		"best_wave":      best_wave,
		"total_runs":     total_runs,
		"unlocked_units": unlocked_units,
		"gems":           gems,
		"hero_weapon":    hero_weapon,
		"weapon_inventory": weapon_inventory,
		"uniform_level":    uniform_level,
	}
	SaveManager.save(data)

func _load() -> void:
	var data := SaveManager.load_save()
	if data.is_empty():
		return
	hoard          = int(data.get("hoard", 0))
	best_wave      = int(data.get("best_wave", 0))
	total_runs     = int(data.get("total_runs", 0))
	var saved_meta = data.get("meta_levels", {})
	for key in saved_meta.keys():
		meta_levels[key] = int(saved_meta[key])
	var saved_units = data.get("unlocked_units", [])
	for u in saved_units:
		if not unlocked_units.has(u):
			unlocked_units.append(u)
	gems          = int(data.get("gems", 0))
	hero_weapon   = str(data.get("hero_weapon", "flintlock"))
	uniform_level = int(data.get("uniform_level", 0))
	var saved_inv = data.get("weapon_inventory", {"flintlock": 1})
	weapon_inventory = {}
	for wid in saved_inv.keys():
		weapon_inventory[str(wid)] = int(saved_inv[wid])
	if weapon_inventory.is_empty():
		weapon_inventory["flintlock"] = 1
	# Backward compat: migrate old owned_weapons array
	if data.has("owned_weapons") and not data.has("weapon_inventory"):
		for w in data["owned_weapons"]:
			weapon_inventory[str(w)] = weapon_inventory.get(str(w), 0) + 1
