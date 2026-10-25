extends SceneTree
## Проверяет словарь и все JSON-пакеты непосредственно в content/dialogues/.


func _initialize() -> void:
	var directory := "res://content/dialogues"
	var paths: PackedStringArray = []
	var entries := DirAccess.get_files_at(directory)
	entries.sort()
	for entry in entries:
		if entry.get_extension().to_lower() == "json":
			paths.append(directory.path_join(entry))
	var catalog := DialogueCatalog.new()
	if not catalog.load_files("res://content/glossary/test_terms.json", paths):
		for error in catalog.validation_errors:
			printerr(error)
		quit(1)
		return
	print("PASS: content v1, %d dialogues, %d terms" % [catalog.get_dialogue_ids().size(), catalog.get_term_ids().size()])
	quit(0)
