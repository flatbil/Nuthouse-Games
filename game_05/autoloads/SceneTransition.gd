extends CanvasLayer

# -------------------------------------------------------
# SceneTransition — global fade-to-black between scenes.
# Usage:  SceneTransition.go_to("res://scenes/Game.tscn")
# -------------------------------------------------------

const FADE_OUT := 0.22
const FADE_IN  := 0.28

var _overlay: ColorRect = null
var _busy:    bool      = false


func _ready() -> void:
	layer        = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.color        = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay)


func go_to(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_overlay, "color:a", 1.0, FADE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): get_tree().change_scene_to_file(scene_path))
	tw.tween_property(_overlay, "color:a", 0.0, FADE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_busy = false)
