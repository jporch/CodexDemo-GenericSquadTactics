extends Node2D
## Original code-drawn pixel placeholders. Replace this scene's visual when art is ready.

var unit_data: Dictionary = {}
var selected: bool = false
var sees_heroes: bool = false
var font: Font = ThemeDB.fallback_font

func _draw() -> void:
	if unit_data.is_empty():
		return
	var ally: bool = unit_data.team == "player"
	var ranged: bool = unit_data.kind in ["ranger", "slinger"]
	var color := Color("71dcca") if ally else Color("f1997e")
	if ranged:
		color = Color("a9c7ff") if ally else Color("d3a4ef")
	var muted: bool = unit_data.finished and ally
	if muted:
		color = color.darkened(0.45)
	draw_ellipse_shadow()
	var rows := ["...HH...", "..HHHH..", "..HSSH..", "...SS...", "..CCCC..", ".WCCCCW.", ".WCCCCW.", "..CCCC..", "..C..C..", "..B..B.."]
	if ranged:
		rows = ["...HH...", "..HHHH..", ".HHSSHH.", "...SS...", "..CCCC.W", "..CCCCW.", ".WCCCC.W", "..CCCC.W", "..C..C..", "..B..B.."]
	var palette := {"H": color.darkened(0.2), "S": Color("efd9bc"), "C": color,
		"B": Color("c8c4b5"), "W": Color("e5c88d")}
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var pixel: String = rows[y][x]
			if palette.has(pixel):
				draw_rect(Rect2(Vector2(x * 3 - 12, y * 3 - 18), Vector2(3, 3)), palette[pixel])
	if unit_data.kind == "knight":
		# Tall, broad shield with a tapered base and metal rim.
		draw_colored_polygon(PackedVector2Array([Vector2(-21, -13), Vector2(-6, -13), Vector2(-6, 9), Vector2(-13.5, 15), Vector2(-21, 9)]), color.darkened(0.5))
		draw_colored_polygon(PackedVector2Array([Vector2(-19, -11), Vector2(-8, -11), Vector2(-8, 8), Vector2(-13.5, 12), Vector2(-19, 8)]), color.lightened(0.3))
		draw_rect(Rect2(-15, -9, 3, 19), Color("edf0db"))
		draw_rect(Rect2(-18, -3, 9, 3), Color("edf0db"))
	elif not ranged:
		draw_rect(Rect2(-17, -2, 9, 12), color.lightened(0.2))
		draw_rect(Rect2(-14, 0, 3, 8), Color("edf0db"))
	if selected:
		draw_arc(Vector2.ZERO, 21, 0, TAU, 32, Color("f4d47e"), 2)
	# Both color and a letter distinguish the two enemy types.
	var tag: String = "R" if ranged else (str(unit_data.id + 1) if ally else "M")
	draw_string(font, Vector2(11, -12), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f6f1da"))
	if not ally and unit_data.get("group_id", -1) >= 0:
		var badge := ("P" if unit_data.get("group_patrol", false) else "G") + str(unit_data.group_id + 1)
		draw_string(font, Vector2(-22, -18), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, unit_data.group_color)
	draw_rect(Rect2(-18, 17, 36, 4), Color("17232c"))
	draw_rect(Rect2(-18, 17, 36.0 * float(unit_data.hp) / unit_data.max_hp, 4), color)
	if muted:
		draw_string(font, Vector2(-5, 12), "x", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	if sees_heroes and not ally and unit_data.hp > 0:
		# Pixel exclamation mark stays distinct from the type/group labels.
		draw_rect(Rect2(-4, -34, 8, 16), Color("17232c"))
		draw_rect(Rect2(-2, -32, 4, 7), Color("ff4b4b"))
		draw_rect(Rect2(-2, -22, 4, 3), Color("ff4b4b"))

func draw_ellipse_shadow() -> void:
	draw_rect(Rect2(-16, 10, 32, 5), Color(0, 0, 0, 0.3))
