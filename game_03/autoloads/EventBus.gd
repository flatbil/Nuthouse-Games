extends Node

signal run_started()
signal run_ended(hoard_earned: int, waves_cleared: int)
signal wave_started(wave_num: int)
signal wave_cleared(wave_num: int)
signal enemy_killed(position: Vector2, reward: int)
signal soldier_killed(unit_type: String)
signal formation_hp_changed(current: int, maximum: int)
signal hoard_changed(total: int)
signal upgrade_chosen(upgrade_id: String)
signal game_over()
