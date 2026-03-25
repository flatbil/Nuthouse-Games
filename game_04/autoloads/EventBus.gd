extends Node

# -------------------------------------------------------
# EventBus — global signals for Lucky Frontier.
# -------------------------------------------------------

signal coins_changed(amount: int)
signal spin_completed(result: Array, winnings: int)
signal big_win(amount: int)
signal daily_bonus_claimed(amount: int)
signal level_up(new_level: int)
