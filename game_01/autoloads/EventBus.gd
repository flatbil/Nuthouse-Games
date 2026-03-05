extends Node

# -------------------------------------------------------
# EventBus — Signal hub for decoupled communication.
# -------------------------------------------------------

# Fired whenever the resource total changes
signal resource_changed(new_amount: float)

# Fired when passive income rate is recalculated
signal passive_rate_changed(new_rate: float)

# Fired after a repeatable asset is purchased
signal asset_purchased(asset_index: int)

# Fired after a one-time multiplier is purchased
signal multiplier_purchased(multiplier_index: int)

# Fired on load when offline income is applied
signal offline_income_collected(amount: float)
