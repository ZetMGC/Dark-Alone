class_name GuestService
extends RefCounted
## Одно обслуживание одного гостя в текущей сессии, без денег и времени.

signal service_completed(event_id: StringName, guest_id: StringName, drink_id: StringName)

var served: bool:
	get: return _served
var guest_id: StringName:
	get: return _guest_id
var selected_drink_id: StringName:
	get: return _selected_drink_id
var validation_errors: PackedStringArray = []

var _configured: bool = false
var _served: bool = false
var _mutating: bool = false
var _guest_id: StringName = &""
var _selected_drink_id: StringName = &""
var _options: Dictionary = {}


func configure(id: StringName, options: Array[Dictionary]) -> bool:
	validation_errors = []
	if _configured:
		validation_errors.append("Service is already configured")
		return false
	var pattern := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	if pattern.search(str(id)) == null:
		validation_errors.append("Invalid guest id")
	if options.is_empty():
		validation_errors.append("Drink menu must not be empty")
	var candidates: Dictionary = {}
	for index in options.size():
		var option := options[index]
		for key: String in ["id", "title", "description"]:
			if not option.get(key) is String or str(option.get(key)).strip_edges().is_empty():
				validation_errors.append("Menu[%d].%s must be a non-empty string" % [index, key])
		for key in option:
			if key not in ["id", "title", "description"]:
				validation_errors.append("Unknown menu field: " + str(key))
		var drink_id: Variant = option.get("id")
		if not drink_id is String or pattern.search(drink_id) == null:
			validation_errors.append("Invalid drink id at menu[%d]" % index)
		elif candidates.has(drink_id):
			validation_errors.append("Duplicate drink id: " + drink_id)
		else:
			candidates[drink_id] = option.duplicate(true)
	if not validation_errors.is_empty():
		return false
	_guest_id = id
	_options = candidates
	_configured = true
	return true


func is_configured() -> bool:
	return _configured


func get_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for option: Dictionary in _options.values():
		options.append(option.duplicate(true))
	return options


func get_served_drink() -> Dictionary:
	return _options.get(str(_selected_drink_id), {}).duplicate(true) if _served else {}


func serve(drink_id: StringName) -> bool:
	if not _configured or _served or _mutating or not _options.has(str(drink_id)):
		return false
	_mutating = true
	_selected_drink_id = drink_id
	_served = true
	service_completed.emit(StringName("service:" + str(_guest_id)), _guest_id, drink_id)
	_mutating = false
	return true
