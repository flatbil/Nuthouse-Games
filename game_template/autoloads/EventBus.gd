extends Node

# -------------------------------------------------------
# EventBus — Signal hub for decoupled communication.
# All game systems talk through here; nothing imports
# each other directly.
# -------------------------------------------------------

signal resource_changed(new_amount: float)
signal passive_rate_changed(new_rate: float)
signal tap_value_changed(new_tap_value: float)

# Generic purchase signal — replaces separate career/investment/strategy signals.
# track: 0 = Track A (tap boosters), 1 = Track B (generators), 2 = Track C (multipliers)
signal item_purchased(track: int, index: int)

signal offline_income_collected(amount: float)
signal game_days_changed(days: float)
signal portfolio_changed(total_invested: float, dividends_earned: float)
