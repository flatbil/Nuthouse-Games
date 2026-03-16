extends Node2D

# -------------------------------------------------------
# OrbitLines — draws orbital ellipses in world space.
# Positioned at world origin so ellipses circle the planet.
#
# Call set_orbits() with an Array of Dictionaries:
#   [{"rx": float, "ry": float, "color": Color}, ...]
# -------------------------------------------------------

var _orbits: Array = []


func set_orbits(data: Array) -> void:
	_orbits = data
	queue_redraw()


func _draw() -> void:
	for od: Dictionary in _orbits:
		_draw_ellipse(float(od["rx"]), float(od["ry"]), od["color"] as Color)


func _draw_ellipse(rx: float, ry: float, col: Color) -> void:
	const SEGS := 80
	var prev := Vector2(rx, 0.0)
	for i in range(1, SEGS + 1):
		var a  := TAU * float(i) / float(SEGS)
		var pt := Vector2(cos(a) * rx, sin(a) * ry)
		draw_line(prev, pt, col, 1.2, true)
		prev = pt
