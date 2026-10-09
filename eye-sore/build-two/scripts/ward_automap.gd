extends Control
## Visited architecture only, drawn at window resolution over the live world.
var state: Dictionary = {}
var actor := Vector3.ZERO
var heading: float = 0.0

func update_map(data: Dictionary, player_position: Vector3, player_heading: float) -> void:
	state = data
	actor = player_position
	heading = player_heading
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.02, 0.017, 0.90))
	var rooms: Array = state.get("map_rooms", [])
	if rooms.is_empty(): return
	var extent: Rect2 = rooms[0].rect
	for room in rooms: extent = extent.merge(room.rect)
	extent = extent.grow(4.0)
	var zoom := minf((size.x - 100) / extent.size.x, (size.y - 100) / extent.size.y)
	var origin := (size - extent.size * zoom) * 0.5 - extent.position * zoom
	var font := ThemeDB.fallback_font
	for room in rooms:
		var rect := Rect2(origin + room.rect.position * zoom, room.rect.size * zoom)
		draw_rect(rect, Color(0.12, 0.14, 0.10))
		draw_rect(rect, Color(0.62, 0.65, 0.38), false, 2)
		draw_string(font, rect.position + Vector2(5, 20), String(room.label), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 10, 14, Color(0.86, 0.85, 0.68))
	var center := origin + Vector2(actor.x, actor.z) * zoom
	var forward := Vector2(-sin(heading), -cos(heading))
	draw_circle(center, 4, Color(1, 0.75, 0.28))
	draw_line(center, center + forward * 18, Color(1, 0.75, 0.28), 3)
	draw_string(font, Vector2(24, 28), "PALE WARD / VISITED AREAS     TAB: CLOSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.84, 0.69))
