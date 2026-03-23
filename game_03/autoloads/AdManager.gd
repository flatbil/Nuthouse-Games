extends Node

signal revive_rewarded()

const REVIVE_COOLDOWN := 180.0
const AD_UNIT_ID := "ca-app-pub-3940256099942544/5224354917"

var _last_ad_time: float = -999.0

func can_watch_revive_ad() -> bool:
	return Time.get_ticks_msec() / 1000.0 - _last_ad_time >= REVIVE_COOLDOWN

func request_revive_ad() -> void:
	if not can_watch_revive_ad():
		return
	_last_ad_time = Time.get_ticks_msec() / 1000.0
	if Engine.has_singleton("AdMob"):
		pass  # TODO: real ad
	else:
		revive_rewarded.emit()
