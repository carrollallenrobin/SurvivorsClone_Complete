extends Area2D

var spin := 0.0

func _process(delta):
	spin += delta * 2.5
	queue_redraw()

func _draw():
	draw_circle(Vector2.ZERO, 14, Color(0.28, 0.06, 0.55, 0.92))
	draw_arc(Vector2.ZERO, 20, spin, spin + TAU * 0.72, 28, Color(0.55, 0.95, 1.0), 3.0)
	draw_arc(Vector2.ZERO, 11, -spin * 1.4, -spin * 1.4 + PI, 16, Color(0.95, 0.86, 1.0), 2.0)
	draw_circle(Vector2.ZERO, 5, Color(0.9, 0.97, 1.0, 0.95))
