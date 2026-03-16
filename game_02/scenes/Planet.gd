extends Node2D

# -------------------------------------------------------
# Planet — procedurally drawn planet background.
# Lives inside a CanvasLayer so it stays screen-centered
# regardless of Camera2D movement.
#
# Call:  planet.spin(delta_x)  each frame to rotate with
# the player's horizontal world-movement.
# -------------------------------------------------------

const RADIUS  := 220.0
const _BASE   := Color(0.16, 0.30, 0.60)
const _ATMO   := Color(0.28, 0.58, 1.00)


func _ready() -> void:
	# Centre on the viewport each frame via the CanvasLayer.
	position = get_viewport().get_visible_rect().size * Vector2(0.5, 0.5)


# Called by Game._process() each frame.
func spin(delta_x: float) -> void:
	rotation += delta_x * 0.0045   # radians per world-pixel


func _draw() -> void:
	var R := RADIUS

	# ── Atmosphere glow ─────────────────────────────────
	for i in range(6, 0, -1):
		var r := R + float(i) * 16.0
		var a := 0.008 * float(i)
		draw_circle(Vector2.ZERO, r, Color(_ATMO.r, _ATMO.g, _ATMO.b, a))

	# ── Planet base ─────────────────────────────────────
	draw_circle(Vector2.ZERO, R, _BASE)

	# ── Cloud band (equatorial, offset for rotation visibility) ──
	draw_circle(Vector2(-R * 0.12, R * 0.06), R * 0.78, Color(0.22, 0.44, 0.70, 0.38))

	# ── Polar highlight ─────────────────────────────────
	draw_circle(Vector2(-R * 0.05, -R * 0.70), R * 0.32, Color(0.60, 0.76, 0.96, 0.28))

	# ── Storm spot (off-centre = clearly shows rotation) ─
	draw_circle(Vector2( R * 0.50,  R * 0.20), R * 0.22, Color(0.18, 0.12, 0.34, 0.80))
	draw_circle(Vector2( R * 0.50,  R * 0.20), R * 0.12, Color(0.30, 0.20, 0.50, 0.60))

	# ── Smaller distant spot ────────────────────────────
	draw_circle(Vector2(-R * 0.58, -R * 0.28), R * 0.09, Color(0.32, 0.52, 0.78, 0.50))

	# ── Specular highlight ──────────────────────────────
	draw_circle(Vector2(-R * 0.30, -R * 0.32), R * 0.46, Color(0.62, 0.80, 0.97, 0.22))

	# ── Shadow / terminator (right side) ────────────────
	draw_circle(Vector2( R * 0.44,  R * 0.04), R * 0.74, Color(0.00, 0.01, 0.06, 0.64))
