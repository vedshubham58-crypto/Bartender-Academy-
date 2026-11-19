extends SceneTree
## Score card "share" picture: shows a score card and saves what the share button would send.
func _initialize() -> void:
	await process_frame
	var save = root.get_node("/root/Save")
	save.birth_year = 1995
	save.trained = "--training" not in OS.get_cmdline_user_args()
	save.gift_day = save.day_key()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 20:
		await process_frame
	main._close_overlay()
	main.shift_stats = {"score": 2340, "served": 6, "stars": 16.5, "perfect": 9, "speedy": 3, "memory": 2, "best_streak": 4, "coins": 180}
	main._score_card("", true)
	for i in 30:
		await process_frame
	var card: Control = null
	for b in main.ui.find_children("*", "Button", true, false):
		if b.text == "SHARE MY SCORE":
			b.emit_signal("pressed")
			card = b
	for i in 10:
		await process_frame
	var p := ProjectSettings.globalize_path("user://share/score-card.png")
	print("SHARE FILE ", FileAccess.file_exists(p), " ", p, " button found ", card != null)
	DirAccess.copy_absolute(p, OS.get_cmdline_user_args()[0])
	quit()
