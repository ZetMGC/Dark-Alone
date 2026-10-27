extends SceneTree

var _capture: String = ""
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _snap(label: String) -> void:
	if _capture.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(_capture.path_join(label + ".png")) == OK, "Capture " + label)


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			_capture = arg.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(_capture)
	if "--small" in OS.get_cmdline_user_args():
		root.size = Vector2i(960, 600)
	var lab := (load("res://tests/parallel/bar/drink_lab.tscn") as PackedScene).instantiate()
	root.add_child(lab)
	await process_frame
	await process_frame
	(lab.find_child("Dose", true, false) as SpinBox).value = 40
	(lab.find_child("Layered", true, false) as CheckButton).button_pressed = true
	for id in ["test_heavy", "test_base", "test_light"]:
		(lab.find_child("Pour_" + id, true, false) as Button).pressed.emit()
	await process_frame
	_expect(lab.preparation.get_snapshot().layers.size() == 3 and lab.preparation.get_volume_ml() == 120, "Lab buttons produce three actual model layers")
	var bounds := Rect2(Vector2.ZERO, lab.size)
	_expect(bounds.encloses((lab.find_child("NewCup", true, false) as Control).get_global_rect()) and bounds.encloses((lab.find_child("Status", true, false) as Control).get_global_rect()), "Lab actions and status fit viewport")
	await _snap("01-layered")
	(lab.find_child("Stir", true, false) as Button).pressed.emit()
	_expect(lab.preparation.get_snapshot().structure == "homogeneous" and lab.preparation.get_volume_ml() == 120, "Lab stir changes structure without changing volume")
	await process_frame
	await _snap("02-mixed")
	(lab.find_child("Seal", true, false) as Button).pressed.emit()
	(lab.find_child("Pour_test_trace", true, false) as Button).pressed.emit()
	_expect(lab.preparation.get_result().sealed and lab.preparation.get_volume_ml() == 120, "Lab rejects adding to fixed result")
	(lab.find_child("NewCup", true, false) as Button).pressed.emit()
	_expect(lab.preparation.get_volume_ml() == 0 and lab.preparation.get_result().is_empty(), "New lab glass has independent state")
	print("%s: drink lab, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)
