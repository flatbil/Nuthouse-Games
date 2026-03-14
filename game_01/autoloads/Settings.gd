extends Node

# -------------------------------------------------------
# Settings — persists user preferences to user://settings.cfg
# -------------------------------------------------------

const CONFIG_PATH := "user://settings.cfg"

var sfx_enabled:   bool  = true
var music_enabled: bool  = true
var sfx_volume:    float = 1.0   # 0.0 – 1.0
var music_volume:  float = 1.0   # 0.0 – 1.0

signal sfx_changed(enabled: bool)
signal music_changed(enabled: bool)
signal sfx_volume_changed(volume: float)
signal music_volume_changed(volume: float)


func _ready() -> void:
	_load()


func set_sfx(enabled: bool) -> void:
	sfx_enabled = enabled
	sfx_changed.emit(enabled)
	_save()


func set_music(enabled: bool) -> void:
	music_enabled = enabled
	music_changed.emit(enabled)
	_save()


func set_sfx_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)
	sfx_volume_changed.emit(sfx_volume)
	_save()


func set_music_volume(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	music_volume_changed.emit(music_volume)
	_save()


# Convenience: returns volume_db ready to assign to AudioStreamPlayer.volume_db
func sfx_volume_db() -> float:
	return linear_to_db(sfx_volume) if sfx_enabled else -80.0


func music_volume_db() -> float:
	return linear_to_db(music_volume) if music_enabled else -80.0


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx_enabled",   sfx_enabled)
	cfg.set_value("audio", "music_enabled", music_enabled)
	cfg.set_value("audio", "sfx_volume",    sfx_volume)
	cfg.set_value("audio", "music_volume",  music_volume)
	cfg.save(CONFIG_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	sfx_enabled   = cfg.get_value("audio", "sfx_enabled",   true)
	music_enabled = cfg.get_value("audio", "music_enabled", true)
	sfx_volume    = cfg.get_value("audio", "sfx_volume",    1.0)
	music_volume  = cfg.get_value("audio", "music_volume",  1.0)
