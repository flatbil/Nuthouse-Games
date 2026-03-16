extends Node

# -------------------------------------------------------
# SaveManager — Persists game state to JSON.
# -------------------------------------------------------

const AUTOSAVE_INTERVAL := 60.0

var _timer: float = 0.0


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= AUTOSAVE_INTERVAL:
		_timer = 0.0
		save()


func save() -> void:
	var data := {
		"resources":               GameManager.resources,
		"game_days":               GameManager.game_days,
		"total_invested":          GameManager.total_invested,
		"total_dividends_earned":  GameManager.total_dividends_earned,
		"track_a_purchased":       GameManager.track_a_purchased,
		"track_b_owned":           GameManager.track_b_owned,
		"track_c_purchased":       GameManager.track_c_purchased,
		"track_d_purchased":       GameManager.track_d_purchased,
		"current_zone":            GameManager.current_zone,
		"last_save_time":          Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(GameConfig.SAVE_FILE, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not open save file for writing.")
		return
	file.store_string(JSON.stringify(data))
	file.close()


func load_save() -> Dictionary:
	if not FileAccess.file_exists(GameConfig.SAVE_FILE):
		return {}
	var file := FileAccess.open(GameConfig.SAVE_FILE, FileAccess.READ)
	if file == null:
		push_error("SaveManager: could not open save file for reading.")
		return {}
	var content := file.get_as_text()
	file.close()
	var result = JSON.parse_string(content)
	if result is Dictionary:
		return result
	push_error("SaveManager: save file is corrupt or unreadable.")
	return {}


func delete_save() -> void:
	if FileAccess.file_exists(GameConfig.SAVE_FILE):
		DirAccess.remove_absolute(GameConfig.SAVE_FILE)
