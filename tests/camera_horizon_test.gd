extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	main.checkpoint_enabled = false
	main.free_roam_enabled = false
	root.add_child(main)
	await process_frame
	for location: Node3D in [main.get_node("BarLevel"), main.get_node("HomeExploration")]:
		var rig: AnchorCamera = main.get_node("AnchorCamera") if location.name == "BarLevel" else location.get_node("AnchorCamera")
		for anchor: AnchorPoint in location.get_node("Anchors").get_children():
			_expect(rig.configure(location.get_node("Anchors"), anchor.anchor_id), "Configure " + str(anchor.anchor_id))
			rig.set_controls_enabled(true)
			var pose := rig.global_transform
			for yaw: float in [-2.0, -0.8, 0.8, 2.0]:
				rig.reset_look()
				rig.apply_look_delta(Vector2(yaw, -0.2))
				_expect(absf(rig.view.global_basis.x.dot(Vector3.UP)) < 0.00001, "Level horizon at " + str(anchor.anchor_id) + ", yaw " + str(yaw))
			_expect(rig.global_transform.is_equal_approx(pose), "Look preserves anchor rig pose")
			rig.reset_look()
			_expect(rig.view.global_basis.z.dot(anchor.global_basis.z) > 0.99999, "Reset restores authored viewing direction")
			for pitch: float in [-100.0, 100.0]:
				rig.apply_look_delta(Vector2(0, pitch))
				_expect(absf(rig.view.global_basis.z.y) <= sin(deg_to_rad(65.0)) + 0.00001, "Pitch limited relative to world vertical")
	main.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("%s: camera horizon, %d checks, %d failures" % ["PASS" if _failures == 0 else "FAIL", _checks, _failures])
	quit(0 if _failures == 0 else 1)
