extends Control
## Original placeholder terrain and grid visual. Rules live in battle_model.gd.

signal cell_clicked(cell: Vector2i)
signal effects_finished
const UNIT_SCENE = preload("res://scenes/unit_placeholder.tscn")
const ATTACK_EFFECT = preload("res://scenes/attack_effect_placeholder.tscn")
const TILE: int = 48
@export_range(0.25, 4.0) var effect_playback_speed: float = 1.0
@export var show_patrol_debug: bool = true
var patrol_tiles: Dictionary = {}
var effects: Array[Node2D] = []
var pending_impacts: Dictionary = {}
var model: RefCounted
var hover := Vector2i(-1, -1)
var unit_nodes: Dictionary = {}
var reachable: Array[Vector2i] = []
var attackable: Array[Vector2i] = []
var enemy_threat: Array[Vector2i] = []
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	mouse_exited.connect(func(): set_hover(Vector2i(-1, -1)))

func is_animating() -> bool:
	return not effects.is_empty()

func play_attack(from_cell: Vector2i, to_cell: Vector2i, attacker_id: int, target_id: int) -> void:
	var effect = ATTACK_EFFECT.instantiate()
	effect.source = Vector2(from_cell) * TILE + Vector2.ONE * TILE / 2.0
	effect.target = Vector2(to_cell) * TILE + Vector2.ONE * TILE / 2.0
	effect.melee = model.distance(from_cell, to_cell) == 1
	effect.playback_speed = effect_playback_speed
	if unit_nodes.has(attacker_id) and unit_nodes[attacker_id].position.distance_to(effect.source) > 1.0:
		effect.lead_in = 0.16 # Let a moving attacker arrive before its attack starts.
	pending_impacts[target_id] = pending_impacts.get(target_id, 0) + 1
	effect.impact.connect(on_attack_impact.bind(target_id))
	effect.finished.connect(on_effect_finished.bind(effect))
	effects.append(effect)
	add_child(effect)

func on_attack_impact(target_id: int) -> void:
	var remaining: int = pending_impacts.get(target_id, 0) - 1
	if remaining <= 0:
		pending_impacts.erase(target_id)
	else:
		pending_impacts[target_id] = remaining
	refresh()

func on_effect_finished(effect: Node2D) -> void:
	effects.erase(effect)
	effect.queue_free()
	if effects.is_empty():
		effects_finished.emit()

func set_hover(cell: Vector2i) -> void:
	if cell == hover:
		return
	hover = cell
	refresh_threat()
	queue_redraw()

func refresh_threat() -> void:
	enemy_threat.clear()
	if model == null:
		return
	var unit: Dictionary = model.at(hover)
	if not unit.is_empty() and unit.team == "enemy":
		enemy_threat = model.threat_cells(unit)

func refresh() -> void:
	reachable.clear()
	attackable.clear()
	patrol_tiles.clear()
	for group in model.enemy_groups:
		if group.patrol and not model.living_members(group).is_empty():
			for anchor in group.anchors:
				for cell in model.patrol_area(anchor):
					patrol_tiles[cell] = group.color
	var active: Dictionary = model.unit_by_id(model.active_id)
	if not active.is_empty() and model.team == "player" and model.outcome == "":
		if not active.moved:
			reachable = model.destinations(active)
		if not active.attacked:
			attackable = model.attack_cells(active, active.cell)
	refresh_threat()
	for unit in model.units:
		if unit.hp <= 0 and not pending_impacts.has(unit.id):
			if unit_nodes.has(unit.id):
				unit_nodes[unit.id].queue_free()
				unit_nodes.erase(unit.id)
			continue
		var node: Node2D
		var target := Vector2(unit.cell) * TILE + Vector2.ONE * TILE / 2.0
		if not unit_nodes.has(unit.id):
			node = UNIT_SCENE.instantiate()
			add_child(node)
			unit_nodes[unit.id] = node
			node.position = target
		else:
			node = unit_nodes[unit.id]
			# A short slide provides feedback without delaying the rule state.
			if node.position != target:
				if node.has_meta("slide"):
					node.get_meta("slide").kill()
				var tween := create_tween()
				tween.tween_property(node, "position", target, 0.16)
				node.set_meta("slide", tween)
		node.unit_data = unit
		node.selected = unit.id == model.active_id
		node.sees_heroes = unit.team == "enemy" and unit.hp > 0 and not model.visible_heroes(unit).is_empty()
		node.queue_redraw()
	queue_redraw()

func clear_units() -> void:
	for effect in effects:
		effect.queue_free()
	effects.clear()
	pending_impacts.clear()
	effects_finished.emit()
	for node in unit_nodes.values():
		node.queue_free()
	unit_nodes.clear()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		set_hover(Vector2i(event.position / TILE))
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := Vector2i(event.position / TILE)
		if model.inside(cell):
			cell_clicked.emit(cell)
		accept_event()

func _draw() -> void:
	if model == null:
		return
	for y in range(model.height):
		for x in range(model.width):
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell) * TILE, Vector2.ONE * TILE)
			var color := Color("293d3b") if (x + y) % 2 == 0 else Color("2c4140")
			draw_rect(rect.grow(-1), color)
			if show_patrol_debug and patrol_tiles.has(cell):
				var patrol_color: Color = patrol_tiles[cell]
				draw_rect(rect.grow(-2), Color(patrol_color, 0.12))
				draw_rect(rect.grow(-2), Color(patrol_color, 0.7), false)
			# Sparse small tile flecks for a quiet pixel texture.
			draw_rect(Rect2(rect.position + Vector2(7 + (x * 7 % 29), 9 + (y * 11 % 25)), Vector2(3, 2)), color.lightened(0.05))
			if cell in reachable:
				draw_rect(rect.grow(-2), Color(0.35, 0.9, 0.77, 0.20))
				draw_rect(rect.grow(-3), Color(0.35, 0.9, 0.77, 0.45), false)
			if cell in attackable:
				# Inset coral marks remain distinct inside overlapping teal movement tiles.
				draw_rect(rect.grow(-8), Color(1.0, 0.5, 0.4, 0.20))
				draw_rect(rect.grow(-8), Color(1.0, 0.5, 0.4, 0.8), false, 2)
			if cell in enemy_threat:
				draw_rect(rect.grow(-2), Color(1.0, 0.67, 0.2, 0.12))
				var threat_color := Color(1.0, 0.67, 0.2, 0.65)
				draw_rect(rect.grow(-4), threat_color, false)
				draw_line(rect.position + Vector2(5, 18), rect.position + Vector2(18, 5), threat_color)
				draw_line(rect.position + Vector2(5, 34), rect.position + Vector2(34, 5), threat_color)
				draw_line(rect.position + Vector2(17, 43), rect.position + Vector2(43, 17), threat_color)
			var terrain: int = model.terrain.get(cell, 0)
			if terrain == 2:
				draw_rect(rect.grow(-3), Color("18262e"))
				draw_rect(Rect2(rect.position + Vector2(4, 4), Vector2(40, 34)), Color("68797c"))
				draw_line(rect.position + Vector2(4, 21), rect.position + Vector2(44, 21), Color("3b4d54"), 2)
				draw_line(rect.position + Vector2(23, 4), rect.position + Vector2(23, 20), Color("3b4d54"), 2)
			elif terrain == 1:
				draw_rect(Rect2(rect.position + Vector2(5, 17), Vector2(38, 25)), Color("403c30"))
				draw_rect(Rect2(rect.position + Vector2(5, 12), Vector2(38, 23)), Color("a5966a"))
				draw_line(rect.position + Vector2(8, 23), rect.position + Vector2(40, 23), Color("6b654a"), 2)
			if cell == hover:
				draw_rect(rect.grow(-1), Color("ecdfad"), false, 2)
	for x in range(model.width):
		draw_string(font, Vector2(x * TILE + 4, 11), str(x + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("6e8580"))
	if show_patrol_debug:
		for group in model.enemy_groups:
			if not group.patrol or model.living_members(group).is_empty():
				continue
			for index in range(2):
				var anchor: Vector2i = group.anchors[index]
				var origin := Vector2(anchor) * TILE
				var flag_color: Color = group.color
				if index != group.waypoint:
					flag_color = flag_color.darkened(0.3)
				draw_line(origin + Vector2(6, 5), origin + Vector2(6, 31), Color("edf0db"), 2)
				draw_colored_polygon(PackedVector2Array([origin + Vector2(7, 5), origin + Vector2(21, 9), origin + Vector2(7, 15)]), flag_color)
				draw_string(font, origin + Vector2(20, 13), "P%d%s" % [group.id + 1, "A" if index == 0 else "B"], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, flag_color)
