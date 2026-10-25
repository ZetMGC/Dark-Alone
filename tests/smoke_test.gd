extends SceneTree
## Checks that the configured entry point can be instantiated and enter the tree.

func _initialize() -> void:
	var scene_path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Main scene could not be loaded: " + scene_path)
		quit(1)
		return
	var instance := packed.instantiate()
	root.add_child.call_deferred(instance)
	_verify.call_deferred(instance)


func _verify(instance: Node) -> void:
	await process_frame
	if not is_instance_valid(instance) or not instance.is_inside_tree():
		push_error("Main scene did not enter the scene tree")
		quit(1)
		return
	print("PASS: main scene loaded and entered the tree")
	quit(0)
