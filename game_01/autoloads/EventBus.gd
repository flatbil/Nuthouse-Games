extends Node

# -------------------------------------------------------
# EventBus — Signal hub for decoupled communication.
# -------------------------------------------------------

signal resource_changed(new_amount: float)
signal passive_rate_changed(new_rate: float)
signal tap_value_changed(new_tap_value: float)

signal career_purchased(index: int)
signal investment_purchased(index: int)
signal strategy_purchased(index: int)

signal offline_income_collected(amount: float)
