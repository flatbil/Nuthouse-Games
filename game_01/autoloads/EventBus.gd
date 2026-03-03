extends Node

# -------------------------------------------------------
# EventBus — Signal hub for decoupled communication.
#
# HOW TO USE:
#   Emit:   EventBus.resource_changed.emit(amount)
#   Listen: EventBus.resource_changed.connect(_on_resource_changed)
#
# WHY: Systems never import each other directly.
#      This keeps every system independently testable
#      and makes it safe to add or remove features
#      without breaking unrelated code.
# -------------------------------------------------------

# Fired whenever the resource total changes (tap or passive tick)
signal resource_changed(new_amount: float)

# Fired when the passive income rate is recalculated
signal passive_rate_changed(new_rate: float)

# Fired after an upgrade is successfully purchased
signal upgrade_purchased(upgrade_index: int)

# Fired on load when offline income is applied
signal offline_income_collected(amount: float)
