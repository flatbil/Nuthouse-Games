extends Node

# -------------------------------------------------------
# UIFactory — shared UI building blocks for all Nuthouse Games.
# -------------------------------------------------------


func make_panel_style(
		bg_color: Color    = Color(0.14, 0.16, 0.11, 0.95),
		corner_radius: int = 16,
		padding: float     = 16.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color                   = bg_color
	s.corner_radius_top_left     = corner_radius
	s.corner_radius_top_right    = corner_radius
	s.corner_radius_bottom_left  = corner_radius
	s.corner_radius_bottom_right = corner_radius
	s.content_margin_left        = padding
	s.content_margin_right       = padding
	s.content_margin_top         = padding
	s.content_margin_bottom      = padding
	return s


func make_btn_style(color: Color, corner_radius: int = 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color                   = color
	s.corner_radius_top_left     = corner_radius
	s.corner_radius_top_right    = corner_radius
	s.corner_radius_bottom_left  = corner_radius
	s.corner_radius_bottom_right = corner_radius
	s.content_margin_left        = 16.0
	s.content_margin_right       = 16.0
	s.content_margin_top         = 8.0
	s.content_margin_bottom      = 8.0
	s.shadow_color  = Color(0.0, 0.0, 0.0, 0.45)
	s.shadow_size   = 8
	s.shadow_offset = Vector2(0.0, 3.0)
	return s


func make_panel(sz: Vector2, pos: Vector2,
		bg_color: Color = Color(0.14, 0.16, 0.11, 0.95)) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", make_panel_style(bg_color))
	panel.custom_minimum_size = sz
	panel.position = pos
	return panel


func make_styled_btn(text: String, color: Color, hover_color: Color,
		font_color: Color, font_size: int, height: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, height)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", font_color)

	btn.add_theme_stylebox_override("normal",  make_btn_style(color))
	var style_hover := make_btn_style(hover_color.lightened(0.15))
	style_hover.border_color        = color.lightened(0.3)
	style_hover.border_width_bottom = 3
	style_hover.border_width_top    = 3
	style_hover.border_width_left   = 3
	style_hover.border_width_right  = 3
	btn.add_theme_stylebox_override("hover",   style_hover)
	btn.add_theme_stylebox_override("pressed", make_btn_style(color.darkened(0.25)))

	add_press_anim(btn)
	return btn


func add_press_anim(btn: Button) -> void:
	btn.button_down.connect(func():
		var t := btn.create_tween()
		t.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.07) \
				.set_trans(Tween.TRANS_SINE))
	btn.button_up.connect(func():
		var t := btn.create_tween()
		t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12) \
				.set_trans(Tween.TRANS_BOUNCE))


func safe_top() -> float:
	var safe := DisplayServer.get_display_safe_area()
	if safe.position.y == 0:
		return 0.0
	var scale: float = maxf(DisplayServer.screen_get_scale(), 1.0)
	return float(safe.position.y) / scale


func safe_bottom() -> float:
	var safe := DisplayServer.get_display_safe_area()
	var vp_h: int = DisplayServer.window_get_size().y
	var inset: int = vp_h - (safe.position.y + safe.size.y)
	if inset <= 0:
		return 0.0
	var scale: float = maxf(DisplayServer.screen_get_scale(), 1.0)
	return float(inset) / scale
