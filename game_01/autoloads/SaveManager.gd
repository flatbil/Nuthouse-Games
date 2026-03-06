extends Node

const SAVE_PATH := "user://save.json"
const AUTOSAVE_INTERVAL := 60.0

var _timer: float = 0.0


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= AUTOSAVE_INTERVAL:
		_timer = 0.0
		save()


func save() -> void:
	var data := {
		"resources": GameManager.resources,
		"game_days": GameManager.game_days,
		"total_invested": GameManager.total_invested,
		"total_dividends_earned": GameManager.total_dividends_earned,
		"careers_purchased": GameManager.careers_purchased,
		"investments_owned": GameManager.investments_owned,
		"strategies_purchased": GameManager.strategies_purchased,
		"last_save_time": Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not open save file for writing.")
		return
	file.store_string(JSON.stringify(data))
	file.close()


func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
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
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
