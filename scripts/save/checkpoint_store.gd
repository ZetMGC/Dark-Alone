class_name CheckpointStore
extends RefCounted
## Одна запись + предыдущая успешная копия; временные файлы никогда не загружаются.

const MAX_BYTES := 1048576
var last_error: String = ""
var recovered_backup: bool = false
var _directory: String
var _busy: bool = false
var _codec := CheckpointCodec.new()


func _init(directory: String = "user://checkpoints") -> void:
	_directory = directory.trim_suffix("/") if directory.begins_with("user://") and directory.length() > 7 and ".." not in directory and "\\" not in directory else ""


func get_path() -> String:
	return _directory.path_join("shift.json") if not _directory.is_empty() else ""


func has_checkpoint() -> bool:
	return not get_path().is_empty() and (FileAccess.file_exists(get_path()) or FileAccess.file_exists(get_path() + ".bak"))


func load_checkpoint(catalog: DialogueCatalog) -> Dictionary:
	last_error = ""
	recovered_backup = false
	if _busy or _directory.is_empty():
		last_error = "Хранилище автосохранения недоступно."
		return {}
	if not has_checkpoint():
		return {}
	for path in [get_path(), get_path() + ".bak"]:
		var result := _read(path, catalog)
		if not result.is_empty():
			recovered_backup = path.ends_with(".bak")
			last_error = "Восстановлена предыдущая контрольная точка." if recovered_backup else ""
			return result
	last_error = "Автосохранение не загружено: " + _codec.last_error + " Начата новая игра; файлы сохранены."
	return {}


func save_checkpoint(number: int, journal: Journal, home: HomeState, catalog: DialogueCatalog) -> bool:
	last_error = ""
	if _busy or _directory.is_empty():
		last_error = "Хранилище автосохранения недоступно."
		return false
	var data := _codec.encode(number, journal, home, catalog)
	if data.is_empty():
		last_error = _codec.last_error
		return false
	var text := JSON.stringify(data, "\t")
	if text.to_utf8_buffer().size() > MAX_BYTES:
		last_error = "Автосохранение превышает допустимый размер."
		return false
	_busy = true
	var error := DirAccess.make_dir_recursive_absolute(_directory)
	if error == OK and (DirAccess.dir_exists_absolute(get_path()) or DirAccess.dir_exists_absolute(get_path() + ".tmp") or DirAccess.dir_exists_absolute(get_path() + ".bak.tmp")):
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
	if error == OK and not _read(get_path(), catalog).is_empty():
		error = DirAccess.copy_absolute(get_path(), get_path() + ".bak.tmp")
		if error == OK:
			error = DirAccess.rename_absolute(get_path() + ".bak.tmp", get_path() + ".bak")
	if error == OK:
		error = DirAccess.rename_absolute(get_path() + ".tmp", get_path())
	_busy = false
	if error != OK:
		last_error = "Не удалось записать автосохранение. Предыдущая запись сохранена."
	return error == OK


func clear_checkpoint() -> bool:
	last_error = ""
	if _busy or _directory.is_empty():
		last_error = "Хранилище автосохранения недоступно."
		return false
	for suffix in [".tmp", ".bak.tmp", ".bak", ""]:
		var path: String = get_path() + suffix
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
			last_error = "Не удалось удалить автосохранение. Новая игра не начата."
			return false
	return true


func _read(path: String, catalog: DialogueCatalog) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	if file.get_length() > MAX_BYTES:
		file.close()
		_codec.last_error = "Файл слишком большой."
		return {}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK:
		_codec.last_error = "Неверный JSON."
		return {}
	return _codec.decode(parser.data, catalog)
