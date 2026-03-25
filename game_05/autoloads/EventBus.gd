extends Node

signal coins_changed(amount: int)
signal spin_completed(result: Array, winnings: int)
signal big_win(amount: int)
signal bonus_triggered(bet: int)
signal daily_bonus_claimed(amount: int)
signal level_up(new_level: int)
