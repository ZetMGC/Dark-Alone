extends SceneTree
class Target extends Interactable3D:
	var calls: int = 0
	func is_available() -> bool:
		return true
	func get_context_actions() -> Array[Dictionary]:
		var result: Array[Dictionary] = []
		if not context_passive:
			result.append({"id": &"first", "text": "Включить"})
			result.append({"id": &"second", "text": "Открыть"})
		return result
	func activate_context_action(id: StringName) -> bool:
		if context_passive:
			return false
		calls += 1 if id == &"first" else 2
		return true
class Controller extends InteractionController:
	var selected: Interactable3D
	func get_target() -> Interactable3D:
		return selected
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	run.call_deferred()
func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)
func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event
func run() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	var controller := Controller.new()
	root.add_child(controller)
	controller.hit_position = Vector3(0,0,-2)
	var target := Target.new()
	root.add_child(target)
	target.position = Vector3(0,0,-2)
	target.context_title = "Часы"
	target.context_description = "На циферблате 00:00."
	var bubble = load("res://scripts/ui/object_context_bubble.gd").new()
	root.add_child(bubble)
	bubble.configure(controller, camera)
	controller.selected = target
	await process_frame
	bubble.refresh_context()
	expect(bubble.visible and bubble.text_label.text.contains("00:00"), "Object description follows current target")
	target.context_anchor = target
	var before: Vector2 = bubble.info_panel.position
	var action_before: Vector2 = bubble.action_panel.position
	target.position.x = 0.25
	bubble.refresh_context()
	expect(bubble.info_panel.position != before, "Bubble follows the object projection")
	expect(bubble.action_panel.position == action_before, "Actions stay in reply area when object moves")
	expect(is_equal_approx(bubble.action_panel.position.y + bubble.action_panel.size.y, root.get_visible_rect().size.y - 60), "Actions share dialogue bottom offset")
	expect(bubble.choices.get_child(0).text.contains("[E]"), "Selected action displays actual activation keys")
	expect(not bubble.text_label.text.contains("Включить"), "Actions are absent from object information")
	target.context_feedback = "Открыто"
	bubble.refresh_context()
	expect(bubble.text_label.text.contains("Открыто"), "Action feedback stays by object")
	expect(bubble.actions.size() == 2, "Only target actions listed")
	expect(bubble.handle_input(key(KEY_2)) and target.calls == 2, "Number activates corresponding action")
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	expect(bubble.handle_input(wheel) and bubble.selected == 1, "Wheel chooses next action")
	expect(not bubble.handle_input(key(KEY_F)) and target.calls == 2, "Old F binding does not execute actions")
	expect(bubble.handle_input(key(KEY_E)) and target.calls == 4, "E confirms selected action")
	controller.selected = null
	expect(not bubble.handle_input(key(KEY_E)) and target.calls == 4 and not bubble.visible, "Look-away rejects stale action and immediately hides bubble")
	expect(target.context_feedback.is_empty(), "Look-away clears object feedback")
	controller.selected = target
	target.context_passive = true
	bubble.refresh_context()
	expect(bubble.visible and bubble.actions.is_empty() and not bubble.action_panel.visible, "Passive information needs no action")
	expect(not bubble.handle_input(key(KEY_1)) and target.calls == 4, "Passive read cannot change world")
	bubble.enabled = false
	expect(not bubble.handle_input(key(KEY_E)), "Disabled context cannot consume actions")
	bubble.refresh_context()
	expect(not bubble.visible, "Context hidden during modal modes")
	bubble.enabled = true
	camera.rotate_y(PI)
	bubble.refresh_context()
	expect(not bubble.visible, "Object behind camera cannot leave bubble on screen")
	expect(bubble.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Bubble does not capture pointer")
	print("%s: object context, %d checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
