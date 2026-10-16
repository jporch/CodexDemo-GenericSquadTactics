extends Control

const Battle = preload("res://scripts/battle_model.gd")
@export var randomize_map: bool = true
@export var map_seed: int = 7241
@export_range(0.1, 2.0) var enemy_action_delay: float = 0.42
var battle := Battle.new()
var mode: String = "move"
var generation: int = 0
var history: Array[String] = []
var result_dismissed: bool = false
@onready var board = $Layout/Body/Field/Board
@onready var phase: Label = $Layout/Header/Phase
@onready var detail: Label = $Layout/Body/Sidebar/DetailsSlot/Details
@onready var status: Label = $Layout/Status
@onready var log_label: Label = $Layout/Body/Sidebar/LogSlot/Log
@onready var move_button: Button = $Layout/Body/Sidebar/Move
@onready var attack_button: Button = $Layout/Body/Sidebar/Attack
@onready var cancel_button: Button = $Layout/Body/Sidebar/Cancel
@onready var finish_button: Button = $Layout/Body/Sidebar/Finish
@onready var undo_button: Button = $Layout/Body/Sidebar/UndoMove
@onready var end_button: Button = $Layout/Body/Sidebar/EndTurn
@onready var restart_dialog: ConfirmationDialog = $RestartDialog
@onready var result_screen: ColorRect = $ResultScreen
@onready var result_title: Label = $ResultScreen/Center/Panel/Content/Title
@onready var result_summary: Label = $ResultScreen/Center/Panel/Content/Summary

func _ready() -> void:
	board.model = battle
	battle.attack_resolved.connect(board.play_attack)
	board.effects_finished.connect(update_result)
	board.cell_clicked.connect(on_cell_clicked)
	move_button.pressed.connect(func(): set_mode("move"))
	attack_button.pressed.connect(func(): set_mode("attack"))
	cancel_button.pressed.connect(cancel)
	finish_button.pressed.connect(finish)
	undo_button.pressed.connect(undo_move)
	end_button.pressed.connect(end_turn)
	$Layout/Header/Restart.pressed.connect(request_restart)
	restart_dialog.confirmed.connect(restart)
	$ResultScreen/Center/Panel/Content/Restart.pressed.connect(restart)
	$ResultScreen/Center/Panel/Content/Dismiss.pressed.connect(dismiss_result)
	restart()

func restart() -> void:
	generation += 1 # Invalidates an enemy sequence waiting on a timer.
	result_dismissed = false
	if randomize_map:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var next_seed := rng.randi()
		while next_seed == map_seed:
			next_seed = rng.randi()
		map_seed = next_seed
	battle.reset(map_seed)
	board.clear_units()
	mode = "move"
	history.clear()
	update_view()

func _unhandled_input(event: InputEvent) -> void:
	if restart_dialog.visible or (event is InputEventKey and event.echo):
		return
	if result_screen.visible:
		if event.is_action_pressed("cancel_activation"):
			dismiss_result()
		elif event.is_action_pressed("restart_battle"):
			restart()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("restart_battle"):
		request_restart()
	elif battle.outcome != "":
		return
	elif event.is_action_pressed("attack_mode"):
		set_mode("attack")
	elif event.is_action_pressed("move_mode"):
		set_mode("move")
	elif event.is_action_pressed("cancel_activation"):
		cancel()
	elif event.is_action_pressed("finish_activation"):
		finish()
	elif event.is_action_pressed("undo_move"):
		undo_move()
	elif event.is_action_pressed("end_turn"):
		end_turn()

func on_cell_clicked(cell: Vector2i) -> void:
	if battle.team != "player" or battle.outcome != "" or restart_dialog.visible:
		return
	var occupant: Dictionary = battle.at(cell)
	if battle.active_id == -1:
		if not occupant.is_empty() and battle.activate(occupant.id):
			mode = "move"
		elif not occupant.is_empty() and occupant.team == "player":
			battle.last_event = "That ally has finished this turn."
	else:
		var active: Dictionary = battle.unit_by_id(battle.active_id)
		if not occupant.is_empty() and occupant.id == active.id:
			return
		# Both ranges are visible: the clicked target determines the action.
		if not occupant.is_empty() and occupant.team != active.team:
			if active.attacked:
				battle.last_event = "Attack already spent. Move or finish activation."
			elif not battle.attack_active(occupant.id):
				battle.last_event = "Choose an enemy in range with a clear shot."
			elif battle.active_id != -1:
				mode = "move"
		elif occupant.is_empty():
			if active.moved:
				battle.last_event = "Move already spent. Attack or finish activation."
			elif not battle.move_active(cell):
				battle.last_event = "Choose a highlighted empty tile."
			elif battle.active_id != -1:
				mode = "attack"
		else:
			battle.last_event = "Finish or cancel the active unit before switching allies."
	update_view()

func set_mode(value: String) -> void:
	if battle.team != "player" or battle.outcome != "" or battle.active_id == -1:
		return
	var active: Dictionary = battle.unit_by_id(battle.active_id)
	if (value == "move" and active.moved) or (value == "attack" and active.attacked):
		return
	mode = value
	update_view(false)

func cancel() -> void:
	if battle.cancel_activation():
		mode = "move"
	elif battle.active_id != -1:
		battle.last_event = "Already committed: use the remaining action or finish activation."
	update_view()

func finish() -> void:
	battle.finish_activation()
	mode = "move"
	update_view()

func undo_move() -> void:
	if restart_dialog.visible:
		return
	if battle.undo_move():
		mode = "move"
	update_view()

func end_turn() -> void:
	if restart_dialog.visible or not battle.begin_enemy_turn():
		return
	var current_generation := generation
	update_view()
	if board.is_animating():
		await board.effects_finished
		if generation != current_generation:
			return
	for unit in battle.units:
		if unit.team != "enemy" or unit.hp <= 0:
			continue
		await get_tree().create_timer(enemy_action_delay).timeout
		if generation != current_generation:
			return
		# Pause the sequence while the player is deciding whether to restart.
		while restart_dialog.visible:
			await get_tree().process_frame
			if generation != current_generation:
				return
		battle.enemy_action(unit.id)
		update_view()
		if board.is_animating():
			await board.effects_finished
			if generation != current_generation:
				return
		if battle.outcome != "":
			return
	battle.begin_player_turn()
	mode = "move"
	update_view()

func request_restart() -> void:
	restart_dialog.popup_centered()

func update_view(record: bool = true) -> void:
	var active: Dictionary = battle.unit_by_id(battle.active_id)
	var player_turn := battle.team == "player" and battle.outcome == ""
	var selected := player_turn and not active.is_empty()
	var allies := 0
	var enemies := 0
	var available := 0
	for unit in battle.units:
		if unit.hp > 0:
			if unit.team == "player":
				allies += 1
				if not unit.finished:
					available += 1
			else:
				enemies += 1
	phase.text = "ROUND %02d  /  %s" % [battle.round_number, "YOUR TURN" if player_turn else "ENEMY TURN"]
	if battle.outcome != "":
		phase.text = battle.outcome.to_upper() + "  /  R TO RESTART"
	$Layout/Body/Sidebar/Count.text = "%d allies   /   %d enemies\n%d allies available" % [allies, enemies, available]
	if selected:
		detail.text = "%s\nHP  %d / %d     ATK  %d\nDEF  %d    MOVE  %d    RANGE  %s\n\nMove: %s\nAttack: %s\n%s" % [active.name, active.hp, active.max_hp, active.attack, active.defense, active.move, (str(active.range) if active.min_range == active.range else "%d-%d" % [active.min_range, active.range]),
			"spent" if active.moved else "ready", "spent" if active.attacked else "ready", "Undo move or end hero turn." if active.moved and active.attacked else ("Choose an enemy to attack." if mode == "attack" else "Choose a tile to move.")]
	else:
		detail.text = "SELECT A UNIT\n2 Guards / 1 Knight   •   Range 1\n1 Ranger   •   Range 2-3\nEnemies\nM  Raider   •   Move 2 / Range 1 / Per 6\nR  Slinger  •   Move 1 / Range 2 / Per 8\n" + ("Choose a fresh ally." if player_turn else "Waiting for enemy actions.")
		if battle.outcome != "":
			detail.text = ("ROOM CLEARED\n\nAll enemies defeated." if battle.outcome == "Victory" else "SQUAD LOST\n\nAll allies defeated.") + "\n\nPress R to restart this map."
	move_button.disabled = not selected or (selected and active.moved)
	attack_button.disabled = not selected or (selected and active.attacked)
	move_button.text = ("> " if mode == "move" and selected else "") + "Move  [M]"
	attack_button.text = ("> " if mode == "attack" and selected else "") + "Attack  [A]"
	cancel_button.disabled = not selected or (selected and (active.moved or active.attacked))
	finish_button.disabled = not selected
	finish_button.text = "Deactivate [Space]" if selected and not active.moved and not active.attacked else "End hero turn [Space]"
	undo_button.disabled = not battle.can_undo_move()
	end_button.disabled = not player_turn
	status.text = battle.last_event
	if record and (history.is_empty() or history.back() != battle.last_event):
		history.append(battle.last_event)
		if history.size() > 3:
			history.pop_front()
	log_label.text = "RECENT ACTIONS\n\n" + "\n".join(history)
	board.refresh()
	update_result()

func dismiss_result() -> void:
	result_dismissed = true
	result_screen.hide()

func update_result() -> void:
	# Let the final hit land before covering the board with the result.
	result_screen.visible = battle.outcome != "" and not result_dismissed and not board.is_animating()
	if not result_screen.visible:
		return
	var enemies_defeated := 0
	var heroes_lost := 0
	for unit in battle.units:
		if unit.hp <= 0:
			if unit.team == "enemy":
				enemies_defeated += 1
			else:
				heroes_lost += 1
	result_title.text = battle.outcome.to_upper()
	result_title.modulate = Color("f4d47e") if battle.outcome == "Victory" else Color("f1997e")
	result_summary.text = ("All enemies defeated." if battle.outcome == "Victory" else "All heroes defeated.") + "\n\nEnemies defeated: %d\nHeroes lost: %d" % [enemies_defeated, heroes_lost]
