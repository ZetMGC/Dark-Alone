extends SceneTree
## Визуальная проверка книги/анимаций на TEST-данных без файлов игрока.

var panel: JournalPanel
var output := "res://artifacts/da068-motion"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			output = arg.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	JournalPanel.motion_mode = &"full"
	var scene := (load("res://scenes/main/reasoning_demo.tscn") as PackedScene).instantiate()
	scene.checkpoint_enabled = false
	scene.preferences_enabled = false
	root.add_child(scene)
	current_scene = scene
	var session: NarrativeSession = scene.get_node("NarrativeSession")
	panel = scene.get_node("JournalPanel")
	for id in [&"test_war", &"test_battles", &"test_weapons", &"test_crates"]:
		session.journal.add_term(id)
	await process_frame
	session.open_journal()
	await _record("raise")
	panel.open_cover()
	await _record("unfold")
	panel.request_page(1)
	await _record("turn")
	panel.select_section(&"notes")
	await _record("section")
	var paper: JournalPaperPages = panel.get_node("%PaperPages")
	paper.open_conclusion(&"test_memories")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("popup-first.png"))
	session.journal.choose_conclusion(&"test_memories", &"test_cinema")
	paper.open_conclusion(&"test_arsenal")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("popup-second.png"))
	session.journal.choose_conclusion(&"test_arsenal", &"test_props")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("notes.png"))
	session.request_close_journal()
	await _record("close")
	print("PASS: journal motion preview")
	quit()


func _record(prefix: String) -> void:
	var frame := 0
	var times: Array = []
	while panel.is_transitioning() and frame < 90:
		await RenderingServer.frame_post_draw
		var path := output.path_join("%s-%03d.png" % [prefix, frame])
		if root.get_texture().get_image().save_png(path) != OK:
			printerr("FAIL: preview image write")
			quit(1)
			return
		times.append(Time.get_ticks_msec())
		frame += 1
		await process_frame
	var file := FileAccess.open(output.path_join(prefix + "-times.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(times))
