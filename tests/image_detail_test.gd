extends Node

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _frame() -> void:
	await get_tree().create_timer(0.12).timeout
	await RenderingServer.frame_post_draw


func _edges(frame: Image) -> int:
	var result: int = 0
	var y := frame.get_height() / 2
	for x in range(frame.get_width() / 10 + 1, frame.get_width() * 4 / 10):
		if absf(frame.get_pixel(x, y).r - frame.get_pixel(x - 1, y).r) > 0.2:
			result += 1
	return result


func _capture(frame: Image, name: String) -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			var folder := argument.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(folder)
			_expect(frame.save_png(folder.path_join("da042_" + name + ".png")) == OK, "Capture " + name)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: image detail pixels require graphical renderer")
		get_tree().quit()
		return
	get_tree().create_timer(35).timeout.connect(func() -> void:
		printerr("FAIL: image detail timed out")
		get_tree().quit(1)
	)
	JournalPanel.motion_mode = &"off"
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	main.free_roam_enabled = false
	get_tree().root.add_child(main)
	var rig: AnchorCamera = main.get_node("AnchorCamera")
	rig.request_move(&"counter")
	while rig.is_transitioning:
		await get_tree().process_frame
	var presentation: PresentationController = main.get_node("Presentation")
	var session: NarrativeSession = main.get_node("NarrativeSession")
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160), Vector2i(3440, 1440)]:
		get_window().size = size
		for detail in [&"classic", &"adaptive", &"native"]:
			presentation.set_image_detail(detail)
			await _frame()
			var frame := get_viewport().get_texture().get_image()
			_expect(frame.get_size() == size, "Native frame size " + str(size))
			_capture(frame, "%dx%d_%s" % [size.x, size.y, detail])
		session.start_dialogue(&"test_guest_intro")
		session.choose_for_node(&"test_guest_intro", &"opening", &"ask_more")
		session.open_journal()
		await _frame()
		_capture(get_viewport().get_texture().get_image(), "%dx%d_book" % [size.x, size.y])
		session.close_journal()
		session.cancel_dialogue()
	# Синтетическая полосатая мишень проверяет сохранение мелких деталей на GPU.
	get_window().size = Vector2i(3840, 2160)
	var target_layer := CanvasLayer.new()
	target_layer.layer = 1
	var target := ColorRect.new()
	target.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; render_mode unshaded; void fragment() { float stripe = mod(floor(SCREEN_UV.x / SCREEN_PIXEL_SIZE.x / 3.0), 2.0); COLOR = vec4(vec3(stripe), 1.0); }"
	var target_material := ShaderMaterial.new()
	target_material.shader = shader
	target.material = target_material
	target_layer.add_child(target)
	add_child(target_layer)
	var text_layer := CanvasLayer.new()
	text_layer.layer = 10
	var paper := ColorRect.new()
	paper.position = Vector2(16, 16)
	paper.size = Vector2(400, 70)
	paper.color = Color(0.05, 0.05, 0.05, 1)
	var label := Label.new()
	label.text = "Кириллица · Чёткий текст 4K"
	label.position = Vector2(12, 12)
	label.add_theme_font_size_override("font_size", 26)
	paper.add_child(label)
	text_layer.add_child(paper)
	add_child(text_layer)
	presentation.set_image_detail(&"classic")
	await _frame()
	var classic := get_viewport().get_texture().get_image()
	presentation.set_image_detail(&"adaptive")
	await _frame()
	var adaptive := get_viewport().get_texture().get_image()
	print("INFO: 4K stripe edges classic=%d adaptive=%d" % [_edges(classic), _edges(adaptive)])
	_expect(_edges(adaptive) > _edges(classic) * 2 + 100, "Adaptive 4K preserves fine stripes lost by fixed 360 lines")
	# Непрозрачная подложка исключает ожидаемое изменение фона под буквами.
	var crop := Rect2i(Vector2i(96, 78), Vector2i(1050, 150))
	_expect(classic.get_region(crop).get_data() == adaptive.get_region(crop).get_data(), "World effect does not pixelate UI text")
	_expect(session.shift.remaining == 2 and not session.service.served and session.journal.get_entries().size() == 2, "Graphics changes preserve gameplay")
	presentation.set_image_detail(&"adaptive")
	JournalPanel.motion_mode = &"full"
	print("%s: image detail, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)
