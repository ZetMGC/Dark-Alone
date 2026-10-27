class_name PreferenceStore
extends RefCounted
## Предпочтения отдельно от checkpoint. Не сериализует игровые модели.

const MAX_BYTES := 16384
var last_error: String = ""
var _directory: String


func _init(directory: String = "user://settings") -> void:
	_directory = directory.trim_suffix("/") if directory.begins_with("user://") and directory.length() > 7 and ".." not in directory and "\\" not in directory else ""


func get_path() -> String:
	return _directory.path_join("preferences.json") if not _directory.is_empty() else ""


static func defaults() -> Dictionary:
	return {"version": 1, "presentation": {"retro": true, "ambience": 0.35, "detail": "adaptive"}, "camera": {"sensitivity": 1.0, "transition": 0.5}, "book": {"motion": "full", "page_volume": 0.35}, "display": {"fullscreen": false, "monitor": 0, "size": [1280, 720], "maximized": false}}


func validate(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 5 or not _integer(data.get("version"), 1, 1):
		return false
	if not data.get("presentation") is Dictionary or not data.get("camera") is Dictionary or not data.get("book") is Dictionary or not data.get("display") is Dictionary:
		return false
	var art: Dictionary = data.presentation
	var camera: Dictionary = data.camera
	var book: Dictionary = data.book
	var display: Dictionary = data.display
	if art.size() != 3 or not art.get("retro") is bool or not _number(art.get("ambience"), 0, 1) or art.get("detail") not in ["adaptive", "native", "classic"]:
		return false
	if camera.size() != 2 or not _number(camera.get("sensitivity"), 0.5, 2) or not _number(camera.get("transition"), 0.2, 1):
		return false
	if book.size() != 2 or book.get("motion") not in ["full", "reduced", "off"] or not _number(book.get("page_volume"), 0, 1):
		return false
	return display.size() == 4 and display.get("fullscreen") is bool and display.get("maximized") is bool and _integer(display.get("monitor"), 0, 255) and display.get("size") is Array and display["size"].size() == 2 and _integer(display["size"][0], 960, 7680) and _integer(display["size"][1], 600, 4320)


func load_preferences() -> Dictionary:
	last_error = ""
	if _directory.is_empty():
		last_error = "Хранилище настроек недоступно."
		return {}
	if not FileAccess.file_exists(get_path()):
		return {}
	var file := FileAccess.open(get_path(), FileAccess.READ)
	if file == null:
		last_error = "Не удалось прочитать настройки."
		return {}
	if file.get_length() > MAX_BYTES:
		file.close()
		last_error = "Файл настроек слишком большой."
		return {}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not validate(parser.data):
		last_error = "Файл настроек повреждён или несовместим. Используются текущие настройки."
		return {}
	var result: Dictionary = parser.data.duplicate(true)
	result.version = int(result.version)
	result.display.monitor = int(result.display.monitor)
	result.display["size"] = [int(result.display["size"][0]), int(result.display["size"][1])]
	return result


func save_preferences(data: Dictionary) -> bool:
	last_error = ""
	if _directory.is_empty() or not validate(data):
		last_error = "Не удалось подготовить настройки для записи."
		return false
	var text := JSON.stringify(data, "\t")
	if text.to_utf8_buffer().size() > MAX_BYTES:
		last_error = "Файл настроек слишком большой."
		return false
	var error := DirAccess.make_dir_recursive_absolute(_directory)
	if error == OK and (DirAccess.dir_exists_absolute(get_path()) or DirAccess.dir_exists_absolute(get_path() + ".tmp")):
		error = ERR_CANT_CREATE
	if error == OK:
		var file := FileAccess.open(get_path() + ".tmp", FileAccess.WRITE)
		if file == null:
			error = FileAccess.get_open_error()
		else:
			file.store_string(text)
			file.flush()
			error = file.get_error()
			file.close()
	if error == OK:
		error = DirAccess.rename_absolute(get_path() + ".tmp", get_path())
	if error != OK:
		last_error = "Настройки не записаны. Предыдущий файл сохранён."
	return error == OK


func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum


func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and float(value) == floorf(float(value))
