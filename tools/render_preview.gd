extends SceneTree
## Render the actual game viewport to an image for a shareable local preview.
func _initialize() -> void:
	call_deferred("render")

func render() -> void:
	root.size = Vector2i(1280, 900)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.on_cell_clicked(Vector2i(2, 5))
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty() and arguments[0] == "Alert":
		main.battle.terrain.clear()
		main.battle.unit_by_id(4).cell = Vector2i(5, 5)
		main.battle.unit_by_id(5).cell = Vector2i(7, 4)
		main.battle.unit_by_id(6).cell = Vector2i(7, 6)
		main.board.clear_units()
		main.update_view()
	if not arguments.is_empty() and arguments[0] in ["Victory", "Defeat"]:
		for unit in main.battle.units:
			if unit.team == ("enemy" if arguments[0] == "Victory" else "player"):
				unit.hp = 0
		main.battle.check_outcome()
		main.update_view()
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://.godot/prototype-preview.png")
	print("Preview saved: ", error_string(error))
	quit(0 if error == OK else 1)
