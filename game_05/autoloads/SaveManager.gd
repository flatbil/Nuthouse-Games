extends Node

func save(data: Dictionary) -> void:
	var file := FileAccess.open(GameConfig.SAVE_FILE, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open save file for writing.")
		return
	file.store_string(JSON.stringify(data))
	file.close()

func load_save() -> Dictionary:
	if not FileAccess.file_exists(GameConfig.SAVE_FILE):
		return {}
	var file := FileAccess.open(GameConfig.SAVE_FILE, FileAccess.READ)
	if file == null:
		return {}
	var result = JSON.parse_string(file.get_as_text())
	file.close()
	return result if result is Dictionary else {}

func delete_save() -> void:
	if FileAccess.file_exists(GameConfig.SAVE_FILE):
		DirAccess.remove_absolute(GameConfig.SAVE_FILE)
