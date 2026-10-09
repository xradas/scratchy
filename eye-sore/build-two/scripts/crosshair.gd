extends Control
## Pixel geometry keeps the aim point at the camera center, independent of font metrics.
var confirm_seconds: float = 0.0

func confirm_hit() -> void:
	confirm_seconds = 0.12
	queue_redraw()

func _process(delta: float) -> void:
	if confirm_seconds > 0:
		confirm_seconds = maxf(0.0, confirm_seconds - delta)
		queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var color := Color(1.0, 0.65, 0.28) if confirm_seconds > 0 else Color(0.92, 0.96, 0.86)
	for rect in [Rect2(-1, -1, 2, 2), Rect2(-8, -1, 4, 2), Rect2(4, -1, 4, 2), Rect2(-1, -8, 2, 4), Rect2(-1, 4, 2, 4)]:
		draw_rect(Rect2(rect.position + center - Vector2.ONE, rect.size + Vector2(2, 2)), Color(0.03, 0.05, 0.04, 0.8))
		draw_rect(Rect2(rect.position + center, rect.size), color)
