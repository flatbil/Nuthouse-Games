extends CanvasLayer

# -------------------------------------------------------
# Toast — slide-in notification banner at top of screen.
# Usage:  Toast.show_toast("Big Win!", Color.YELLOW)
# -------------------------------------------------------

const DURATION  := 2.2
const FADE_IN   := 0.20
const FADE_OUT  := 0.30

var _panel: PanelContainer = null
var _label: Label          = null
var _tween: Tween          = null
var _safe_y: float         = 0.0


func _ready() -> void:
	layer        = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_safe_y = _get_safe_top()
	_build()


func _build() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.05, 0.05, 0.05, 0.88)
	style.corner_radius_top_left     = 14
	style.corner_radius_top_right    = 14
	style.corner_radius_bottom_left  = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left        = 24.0
	style.content_margin_right       = 24.0
	style.content_margin_top         = 10.0
	style.content_margin_bottom      = 10.0
	style.shadow_color  = Color(0.0, 0.0, 0.0, 0.40)
	style.shadow_size   = 6
	style.shadow_offset = Vector2(0.0, 2.0)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left   = -150.0
	_panel.offset_right  =  150.0
	_panel.offset_top    = _safe_y - 60.0
	_panel.offset_bottom = _safe_y - 20.0
	_panel.modulate.a    = 0.0
	_panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_panel.process_mode  = Node.PROCESS_MODE_ALWAYS
	add_child(_panel)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 15)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)


func show_toast(text: String, color: Color = Color.WHITE, duration: float = DURATION) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_label.text = text
	_label.add_theme_color_override("font_color", color)
	_panel.offset_top    = _safe_y - 60.0
	_panel.offset_bottom = _safe_y - 20.0
	_panel.modulate.a    = 0.0

	_tween = create_tween()
	_tween.tween_property(_panel, "offset_top",    _safe_y + 12.0, FADE_IN) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_panel, "offset_bottom", _safe_y + 52.0, FADE_IN) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_panel, "modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(duration)
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_SINE)


static func _get_safe_top() -> float:
	var safe := DisplayServer.get_display_safe_area()
	if safe.position.y == 0:
		return 0.0
	var scale: float = maxf(DisplayServer.screen_get_scale(), 1.0)
	return float(safe.position.y) / scale
