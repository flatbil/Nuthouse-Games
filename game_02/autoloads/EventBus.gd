extends Node

# -------------------------------------------------------
# EventBus — Signal hub for decoupled communication.
# -------------------------------------------------------

signal resource_changed(new_amount: float)
signal passive_rate_changed(new_rate: float)
signal tap_value_changed(new_tap_value: float)

# Generic purchase signal
# track: 0=DRILLS, 1=DRONES, 2=SHIP MODS, 3=EXOSUIT
signal item_purchased(track: int, index: int)

signal offline_income_collected(amount: float)
signal game_days_changed(days: float)
signal portfolio_changed(total_invested: float, dividends_earned: float)
signal game_ended()

# Asteroid Miner specific
signal asteroid_depleted(position: Vector2)
signal zone_changed(zone_index: int)
signal credits_mined(world_pos: Vector2, amount: float)
signal mine_blocked(world_pos: Vector2)
