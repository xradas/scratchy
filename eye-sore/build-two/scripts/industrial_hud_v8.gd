extends Control
## Read-only native-window instrumentation. No gameplay nodes or input ownership.
## The approved steel swatch is sampled directly; every icon/frame is drawn here.
const STEEL = preload("res://assets/materials/pale-ward-approved-board.png")
const STEEL_REGION := Rect2(1362, 625, 111, 102)
const SLOT_IDS := [&"pistol", &"shotgun", &"melee", &"twin_shotgun", &"rivet_cannon", &"siege_launcher"]
const SLOT_NAMES := ["PISTOL", "SHOTGUN", "MELEE", "TWIN", "RIVET", "SIEGE"]
const AMMO_FIELDS := {&"pistol": "ammo_pistol", &"shells": "ammo_shotgun", &"rivets": "ammo_rivets", &"rockets": "ammo_rockets"}
const INK := Color("d9d5bd")
const MUTED := Color("878e83")
const DIM := Color("454c47")
const RED := Color("ed765c")
const GOLD := Color("d7b865")
const GREEN := Color("b5c488")
const SEGMENTS := ["abcdef", "bc", "abdeg", "abcdg", "bcfg", "acdfg", "acdefg", "abc", "abcdefg", "abcdfg"]

var _combat: Dictionary = {}
var _stage: Dictionary = {}
var _capacities: Dictionary = {}
var _fallback := "MOVEMENT PREVIEW"
var _world_rect := Rect2(0, 0, 1280, 720)
var _actor := Vector3.ZERO
var _heading := 0.0
var _has_actor := false
var minimap_enabled := true:
	set(value):
		minimap_enabled = value
		queue_redraw()
## Compatibility for source fixtures and movement preview. Display state wins.
var text: String:
	get:
		if _combat.is_empty(): return _fallback
		var ammo := active_ammunition()
		var ammo_text := "READY" if ammo.kind == &"" else "AMMO %d/%d" % [ammo.amount, ammo.capacity]
		return "HEALTH %d    ARMOR %d    KILLS %d/%d\n%s    %s" % [int(_combat.get("health", 0)), int(_combat.get("armor", 0)), int(_combat.get("kills", 0)), int(_combat.get("total_enemies", 0)), String(_combat.get("weapon_id", "")).replace("_", " ").to_upper(), ammo_text]
	set(value):
		_fallback = value
		if value == "MOVEMENT PREVIEW": _combat.clear()
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true

func set_display_state(combat: Dictionary, stage: Dictionary, capacities: Dictionary) -> void:
	# Snapshot ownership ensures a later display update cannot mutate gameplay.
	_combat = combat.duplicate(true)
	_stage = stage.duplicate(true)
	_capacities = capacities.duplicate(true)
	queue_redraw()

func set_world_rect(rect: Rect2) -> void:
	_world_rect = rect
	var compact := rect.size.x < 1000.0
	var height := 56.0 if compact else 98.0
	position = (rect.position + Vector2(10, rect.size.y - height - (0 if compact else 8))).floor()
	# Whole-pixel world scaling creates generous lower letterboxing at 4:3.
	# Put native instrumentation there instead of covering the weapon receiver.
	var parent_control := get_parent_control()
	if compact and is_instance_valid(parent_control):
		var below := parent_control.size.y - rect.end.y
		if below >= 118:
			height = 118
			position.y = floorf(rect.end.y + minf(4, below - height))
	size = Vector2(maxf(rect.size.x - 20, 1), height)
	queue_redraw()

func update_map(stage: Dictionary, player_position: Vector3, player_heading: float) -> void:
	_stage = stage.duplicate(true)
	_actor = player_position
	_heading = player_heading
	_has_actor = true
	queue_redraw()

func set_minimap_enabled(enabled: bool) -> void:
	minimap_enabled = enabled

func active_ammunition() -> Dictionary:
	var kind: StringName = &""
	match String(_combat.get("weapon_id", "")):
		"pistol": kind = &"pistol"
		"shotgun", "twin_shotgun": kind = &"shells"
		"rivet_cannon": kind = &"rivets"
		"siege_launcher": kind = &"rockets"
	return {"kind": kind, "amount": int(_combat.get(AMMO_FIELDS.get(kind, ""), 0)), "capacity": int(_capacities.get(kind, 0))}

func inventory_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var owned: Array = _combat.get("owned_weapons", [])
	for i in SLOT_IDS.size():
		result.append({"hotkey": i + 1, "weapon_id": SLOT_IDS[i], "name": SLOT_NAMES[i], "owned": owned.has(SLOT_IDS[i]) or owned.has(String(SLOT_IDS[i])), "selected": String(_combat.get("weapon_id", "")) == String(SLOT_IDS[i])})
	return result

func held_keys() -> Array[String]:
	var result: Array[String] = []
	if bool(_stage.get("brass_key", _stage.get("key", false))): result.append("brass")
	if bool(_stage.get("red_key", false)): result.append("red")
	return result

func visible_map_rooms() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var visited: Array = _stage.get("visited_rooms", [])
	for candidate in _stage.get("map_rooms", []):
		if not candidate is Dictionary: continue
		var room: Dictionary = candidate
		# Require both the stage's visited identity and positive room declaration.
		# No secret/flag, enemy, pickup or label data is ever drawn on this map.
		if not bool(room.get("visited", false)) or not visited.has(room.get("id", "")): continue
		if room.get("rect") is Rect2:
			var visible_room := {"id": room.get("id", ""), "rect": room.rect}
			if room.get("footprint") is PackedVector2Array and room.footprint.size() >= 3: visible_room["footprint"] = room.footprint
			result.append(visible_room)
	return result

func layout_snapshot() -> Dictionary:
	var compact := size.x < 980.0
	var micro := compact and size.y < 80
	var gap := 6.0
	var map_width := 88.0 if micro else 114.0 if compact else 150.0
	var body_width := size.x - map_width - gap
	var layout := {"compact": compact, "micro": micro, "map": Rect2(body_width + gap, 0, map_width, size.y)}
	if micro:
		var widths := [body_width * 0.145, body_width * 0.145, body_width * 0.19, body_width * 0.35]
		var x := 0.0
		for i in 4:
			layout[["health", "armor", "ammo", "inventory"][i]] = Rect2(x, 0, floorf(widths[i] - gap), size.y)
			x += floorf(widths[i])
		layout["utility"] = Rect2(x, 0, body_width - x, size.y)
	elif compact:
		var widths := [body_width * 0.225, body_width * 0.225, body_width * 0.31]
		var x := 0.0
		for i in 3:
			layout[["health", "armor", "ammo"][i]] = Rect2(x, 0, floorf(widths[i] - gap), 61)
			x += floorf(widths[i])
		layout["utility"] = Rect2(x, 0, body_width - x, 61)
		layout["inventory"] = Rect2(0, 67, body_width, 51)
	else:
		var widths := [body_width * 0.13, body_width * 0.13, body_width * 0.175, body_width * 0.445]
		var x := 0.0
		for i in 4:
			layout[["health", "armor", "ammo", "inventory"][i]] = Rect2(x, 0, floorf(widths[i] - gap), size.y)
			x += floorf(widths[i])
		layout["utility"] = Rect2(x, 0, body_width - x, size.y)
	return layout

func _draw() -> void:
	if size.x < 400: return
	if _combat.is_empty():
		_plate(Rect2(0, size.y - 42, minf(size.x, 280), 42))
		_label(Vector2(16, size.y - 16), _fallback, 14, INK, minf(size.x - 32, 248))
		return
	var layout := layout_snapshot()
	var compact: bool = layout.compact
	_vital(layout.health, "HEALTH", int(_combat.get("health", 0)), RED, compact, true)
	_vital(layout.armor, "ARMOR", int(_combat.get("armor", 0)), GOLD, compact, false)
	_ammunition(layout.ammo, compact)
	_inventory(layout.inventory, compact)
	_utility(layout.utility, compact)
	if minimap_enabled: _minimap(layout.map)

func _plate(rect: Rect2) -> void:
	draw_rect(rect, Color("101512"))
	# Native source UV tiles, without stretching/resampling/repacking the PNG.
	var y := rect.position.y
	while y < rect.end.y:
		var x := rect.position.x
		while x < rect.end.x:
			var tile := Vector2(minf(111, rect.end.x - x), minf(102, rect.end.y - y))
			draw_texture_rect_region(STEEL, Rect2(Vector2(x, y), tile), Rect2(STEEL_REGION.position, tile), Color(0.50, 0.52, 0.44))
			x += 111
		y += 102
	draw_rect(rect.grow(-1), Color("68695a"), false, 1)
	draw_line(rect.position + Vector2(2, 2), Vector2(rect.end.x - 2, rect.position.y + 2), Color("8a8974"), 1)
	draw_line(Vector2(rect.position.x + 2, rect.end.y - 2), rect.end - Vector2(2, 2), Color("070c0a"), 2)
	for point in [rect.position + Vector2(5, 5), Vector2(rect.end.x - 6, rect.position.y + 5), Vector2(rect.position.x + 5, rect.end.y - 6), rect.end - Vector2(6, 6)]:
		draw_rect(Rect2(point - Vector2.ONE * 2, Vector2.ONE * 4), Color("101411"))
		draw_line(point - Vector2(1, 1), point + Vector2(1, 1), MUTED, 1)

func _recess(rect: Rect2) -> void:
	draw_rect(rect, Color("070e0c"))
	draw_rect(rect, Color("434b40"), false, 1)
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), Color.BLACK, 2)

func _label(at: Vector2, value: String, pixels: int, color: Color, width: float = -1, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(ThemeDB.fallback_font, at.floor() + Vector2(1, 1), value, align, width, pixels, Color(0, 0, 0, 0.9))
	draw_string(ThemeDB.fallback_font, at.floor(), value, align, width, pixels, color)

func _digits(at: Vector2, value: int, height: float, color: Color, max_width: float) -> void:
	var number := str(clampi(value, 0, 9999))
	var h := floorf(minf(height, max_width / maxf(number.length() * 0.65, 1)))
	var w := floorf(h * 0.52)
	var thick := maxf(2, floorf(h / 9))
	var segments := {"a": Rect2(thick, 0, w - thick * 2, thick), "b": Rect2(w - thick, thick, thick, h / 2 - thick * 1.5), "c": Rect2(w - thick, h / 2 + thick / 2, thick, h / 2 - thick * 1.5), "d": Rect2(thick, h - thick, w - thick * 2, thick), "e": Rect2(0, h / 2 + thick / 2, thick, h / 2 - thick * 1.5), "f": Rect2(0, thick, thick, h / 2 - thick * 1.5), "g": Rect2(thick, floorf(h / 2 - thick / 2), w - thick * 2, thick)}
	var x := at.x
	for character in number:
		for segment in segments:
			var piece: Rect2 = segments[segment]
			piece.position += Vector2(x, at.y)
			draw_rect(piece, color if SEGMENTS[int(character)].contains(segment) else Color(color, 0.075))
		x += w + thick * 2

func _vital(rect: Rect2, title: String, value: int, color: Color, compact: bool, health_icon: bool) -> void:
	_plate(rect)
	var inset := rect.grow(-10)
	_label(inset.position + Vector2(0, 11), title, 11 if compact else 13, INK, inset.size.x)
	var well := Rect2(inset.position + Vector2(0, 17 if compact else 23), Vector2(inset.size.x, 27 if compact else 43))
	_recess(well)
	_digits(well.position + Vector2(7, 5), value, 19 if compact else 31, color, well.size.x - 14)
	if not compact:
		var p := Vector2(rect.end.x - 21, rect.position.y + 13)
		if health_icon:
			draw_rect(Rect2(p + Vector2(3, 0), Vector2(3, 9)), RED)
			draw_rect(Rect2(p + Vector2(0, 3), Vector2(9, 3)), RED)
		else:
			draw_colored_polygon(PackedVector2Array([p, p + Vector2(9, 0), p + Vector2(8, 7), p + Vector2(4, 11), p + Vector2(1, 7)]), GOLD)
		var units := clampi(int(ceil(value / 10.0)), 0, 10)
		var segment_width := (inset.size.x - 9) / 10
		for i in 10: draw_rect(Rect2(inset.position.x + i * (segment_width + 1), rect.end.y - 14, segment_width, 4), color.darkened(0.25) if i < units else Color("202a21"))

func _ammunition(rect: Rect2, compact: bool) -> void:
	_plate(rect)
	var ammo := active_ammunition()
	var inset := rect.grow(-10)
	_label(inset.position + Vector2(0, 11), "AMMO" if compact else String(ammo.kind).to_upper() if ammo.kind != &"" else "MELEE", 11 if compact else 13, INK, inset.size.x)
	var well := Rect2(inset.position + Vector2(0, 17 if compact else 23), Vector2(inset.size.x, 27 if compact else 43))
	_recess(well)
	if ammo.kind == &"":
		_label(well.position + Vector2(7, 20 if compact else 29), "READY", 14 if compact else 20, GREEN, well.size.x - 14)
	else:
		_digits(well.position + Vector2(7, 5), ammo.amount, 19 if compact else 31, RED, well.size.x * 0.57)
		if ammo.capacity >= 0:
			_label(Vector2(well.position.x + well.size.x * 0.61, well.end.y - 7), "/%d" % ammo.capacity, 11 if compact else 15, MUTED, well.size.x * 0.38)
	if not compact:
		_label(Vector2(inset.position.x, rect.end.y - 11), String(_combat.get("weapon_id", "")).replace("_", " ").to_upper(), 10, MUTED, inset.size.x)

func _inventory(rect: Rect2, compact: bool) -> void:
	_plate(rect)
	if compact and size.y < 80:
		var rail := rect.grow(-6)
		var slots := inventory_slots()
		var cell_width := (rail.size.x - 10) / 6
		for i in slots.size():
			var cell := Rect2(rail.position + Vector2(i * (cell_width + 2), 0), Vector2(cell_width, rail.size.y))
			_recess(cell)
			var slot: Dictionary = slots[i]
			var color := GOLD if slot.selected else GREEN if slot.owned else DIM
			if slot.selected: draw_rect(cell.grow(-1), GOLD, false, 2)
			if slot.owned: draw_rect(Rect2(cell.position + Vector2(4, 5), Vector2(cell.size.x - 8, 3)), color)
			_label(cell.position + Vector2(0, 29), str(i + 1), 16, color, cell.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		return
	if not compact: _label(rect.position + Vector2(12, 22), "ARMAMENT", 11, INK, rect.size.x - 24)
	var rail := Rect2(rect.position + Vector2(10, 7 if compact else 30), rect.size - Vector2(20, 14 if compact else 42))
	var slot_width := (rail.size.x - 5 * 3) / 6
	var slots := inventory_slots()
	for i in slots.size():
		var slot: Dictionary = slots[i]
		var cell := Rect2(rail.position + Vector2(i * (slot_width + 3), 0), Vector2(slot_width, rail.size.y))
		_recess(cell)
		var color := GOLD if slot.selected else GREEN if slot.owned else DIM
		if slot.selected:
			draw_rect(cell.grow(-1), Color("b7984d"), false, 2)
			draw_rect(Rect2(cell.position + Vector2(2, 2), Vector2(cell.size.x - 4, 3)), GOLD)
		elif slot.owned: draw_rect(Rect2(cell.position + Vector2(3, 2), Vector2(4, 3)), GREEN)
		_label(cell.position + Vector2(4, 17 if not compact else 14), str(i + 1), 13 if not compact else 11, color, 12)
		_weapon_icon(cell.position + Vector2(cell.size.x * 0.52, 16 if not compact else 12), i, color, 0.9 if compact else 1.0)
		_label(Vector2(cell.position.x + 1, cell.end.y - 5), SLOT_NAMES[i], 9 if compact else 10, color, cell.size.x - 2, HORIZONTAL_ALIGNMENT_CENTER)

func _weapon_icon(at: Vector2, index: int, color: Color, factor: float) -> void:
	var blocks: Array[Rect2] = []
	match index:
		0: blocks = [Rect2(-8, -3, 19, 5), Rect2(-7, 1, 6, 8), Rect2(8, -2, 5, 3)]
		1: blocks = [Rect2(-13, -2, 27, 3), Rect2(-9, 2, 15, 3), Rect2(-13, 3, 5, 5)]
		2: blocks = [Rect2(-10, -3, 16, 6), Rect2(5, -5, 6, 10), Rect2(-13, -1, 5, 3)]
		3: blocks = [Rect2(-13, -4, 27, 3), Rect2(-13, 1, 27, 3), Rect2(-13, 4, 7, 5)]
		4: blocks = [Rect2(-12, -3, 21, 7), Rect2(8, -1, 6, 3), Rect2(-8, 4, 7, 4), Rect2(0, -6, 6, 3)]
		5: blocks = [Rect2(-13, -4, 27, 9), Rect2(8, -6, 4, 13), Rect2(-7, 5, 5, 4)]
	for block in blocks: draw_rect(Rect2((at + block.position * factor).floor(), (block.size * factor).ceil()), color)

func _utility(rect: Rect2, compact: bool) -> void:
	_plate(rect)
	if compact and size.y < 80:
		_label(rect.position + Vector2(9, 19), "%d/%d" % [int(_combat.get("kills", 0)), int(_combat.get("total_enemies", 0))], 11, INK, rect.size.x - 18)
		var keys := held_keys()
		for i in keys.size(): _key_icon(rect.position + Vector2(14 + i * 27, 39), GOLD if keys[i] == "brass" else RED, 0.75)
		return
	var top := rect.position + Vector2(10, 20)
	_label(top, "KILLS", 10 if compact else 11, MUTED, rect.size.x - 20)
	_label(top + Vector2(0, 17), "%d/%d" % [int(_combat.get("kills", 0)), int(_combat.get("total_enemies", 0))], 12 if compact else 16, INK, rect.size.x - 20)
	var keys := held_keys()
	for i in keys.size():
		var at := Vector2(rect.position.x + 14 + i * 28, rect.end.y - (12 if compact else 24))
		_key_icon(at, GOLD if keys[i] == "brass" else RED, 0.75 if compact else 1.0)

func _key_icon(at: Vector2, color: Color, factor: float) -> void:
	for block in [Rect2(-4, -4, 9, 2), Rect2(-4, -2, 2, 5), Rect2(3, -2, 2, 5), Rect2(-4, 3, 9, 2), Rect2(5, -1, 13, 3), Rect2(12, 1, 3, 5), Rect2(17, 1, 3, 4)]:
		draw_rect(Rect2((at + block.position * factor).floor(), (block.size * factor).ceil()), color)

func minimap_geometry() -> Array[Rect2]:
	var result: Array[Rect2] = []
	var rect: Rect2 = layout_snapshot().map
	var screen := rect.grow(-10)
	screen.position.y += 17; screen.size.y -= 17
	var center := screen.get_center()
	var actor := Vector2(_actor.x, _actor.z)
	# Fixed world scale; discovering a room never changes zoom or reveals extents.
	for room in visible_map_rooms():
		if room.has("footprint"): continue
		var source: Rect2 = room.rect
		var projected := Rect2(center + (source.position - actor) * 2.4, source.size * 2.4)
		if projected.intersects(screen): result.append(projected.intersection(screen))
	return result

func minimap_polygons() -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var screen: Rect2 = layout_snapshot().map.grow(-10)
	screen.position.y += 17; screen.size.y -= 17
	var center := screen.get_center()
	var actor := Vector2(_actor.x, _actor.z)
	var clip := PackedVector2Array([screen.position, Vector2(screen.end.x, screen.position.y), screen.end, Vector2(screen.position.x, screen.end.y)])
	for room in visible_map_rooms():
		if not room.has("footprint"): continue
		var polygon := PackedVector2Array()
		for point in room.footprint: polygon.append(center + (point - actor) * 2.4)
		for piece in Geometry2D.intersect_polygons(polygon, clip):
			if piece.size() >= 3: result.append(piece)
	return result

func _minimap(rect: Rect2) -> void:
	_plate(rect)
	_label(rect.position + Vector2(12, 18), "N", 11, GOLD, 12)
	_label(rect.position + Vector2(29, 18), "VISITED", 10, MUTED, rect.size.x - 41)
	var screen := rect.grow(-10)
	screen.position.y += 17; screen.size.y -= 17
	_recess(screen)
	if not _has_actor: return
	for room in minimap_geometry():
		draw_rect(room, Color("202c22"))
		draw_rect(room.grow(-0.5), Color("7b8961"), false, 1)
	for polygon in minimap_polygons():
		draw_colored_polygon(polygon, Color("202c22"))
		var outline := polygon.duplicate(); outline.append(polygon[0])
		draw_polyline(outline, Color("7b8961"), 1)
	var center := screen.get_center().floor()
	var forward := Vector2(-sin(_heading), -cos(_heading))
	var side := Vector2(-forward.y, forward.x)
	draw_colored_polygon(PackedVector2Array([center + forward * 6, center - forward * 4 + side * 4, center - forward * 2, center - forward * 4 - side * 4]), GOLD)
