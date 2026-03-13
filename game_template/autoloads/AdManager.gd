extends Node

# -------------------------------------------------------
# AdManager — Rewarded ad wrapper with cooldown.
# All ad config (amount, cooldown, unit ID) lives in GameConfig.
#
# AdMob requires Android Custom Build (Gradle export).
# Without the plugin (editor / debug / iOS), _grant_reward()
# fires immediately — the feature is fully testable without a device.
#
# Plugin signals (godot-admob-android v4+):
#   rewarded_ad_loaded()
#   rewarded_ad_failed_to_load(error_code: int)
#   user_earned_reward(currency: String, amount: int)
# -------------------------------------------------------

signal loan_rewarded(amount: float)

var cooldown_remaining: float = 0.0
var _ad_ready:          bool  = false
var _admob                    = null


func _ready() -> void:
	if Engine.has_singleton("AdMob"):
		_admob = Engine.get_singleton("AdMob")
		if _admob.has_signal("rewarded_ad_loaded"):
			_admob.connect("rewarded_ad_loaded",         _on_ad_loaded)
		if _admob.has_signal("rewarded_ad_failed_to_load"):
			_admob.connect("rewarded_ad_failed_to_load", _on_ad_failed)
		if _admob.has_signal("user_earned_reward"):
			_admob.connect("user_earned_reward",         _on_user_earned_reward)
		_load_ad()


func _process(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)


# -------------------------------------------------------
# Public API
# -------------------------------------------------------

func can_request_loan() -> bool:
	return cooldown_remaining <= 0.0


func request_loan() -> void:
	if not can_request_loan():
		return
	if _admob != null and _ad_ready:
		_admob.show_rewarded_ad()
	else:
		# No plugin or ad not ready — grant immediately (debug / editor fallback)
		_grant_reward()


func cooldown_label() -> String:
	if cooldown_remaining <= 0.0:
		return ""
	var mins: int = int(cooldown_remaining) / 60
	var secs: int = int(cooldown_remaining) % 60
	return "%d:%02d" % [mins, secs]


# -------------------------------------------------------
# AdMob callbacks
# -------------------------------------------------------

func _on_ad_loaded() -> void:
	_ad_ready = true


func _on_ad_failed(_error_code: int) -> void:
	_ad_ready = false


func _on_user_earned_reward(_currency: String, _amount: int) -> void:
	_grant_reward()


# -------------------------------------------------------
# Private
# -------------------------------------------------------

func _grant_reward() -> void:
	cooldown_remaining = GameConfig.AD_LOAN_COOLDOWN
	_ad_ready = false
	GameManager.add_resources(GameConfig.AD_LOAN_AMOUNT)
	loan_rewarded.emit(GameConfig.AD_LOAN_AMOUNT)
	if _admob != null:
		_load_ad()


func _load_ad() -> void:
	if _admob == null:
		return
	_ad_ready = false
	_admob.load_rewarded_ad(GameConfig.AD_UNIT_ID)
