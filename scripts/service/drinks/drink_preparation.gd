class_name DrinkPreparation
extends RefCounted
## Один стакан: состав/слои снизу вверх, операции и копия результата подачи.

const EPSILON := 0.000001
const MIN_DOSE_ML := 0.001
const MIN_DENSITY_GAP := 0.02
const BASE_LAYER_FLOW := 8.0
const VISCOUS_FLOW_BONUS := 32.0
const MAX_COMMANDS := 4096

var _test_content: bool = false
var _ready: bool = false
var _sealed: bool = false
var _preparation_id: StringName
var _vessel: Dictionary = {}
var _ingredients: Dictionary = {}
var _layers: Array[Dictionary] = []
var _commands: Dictionary = {}
var _result: Dictionary = {}


func configure(catalog: DrinkMaterialCatalog, vessel_id: StringName, preparation_id: StringName) -> bool:
	if _ready or catalog == null or not catalog.is_loaded() or not DrinkMaterialCatalog.valid_id(preparation_id):
		return false
	var vessel := catalog.get_vessel(vessel_id)
	if vessel.is_empty():
		return false
	for id in catalog.get_ingredient_ids():
		_ingredients[str(id)] = catalog.get_ingredient(StringName(id))
	_test_content = catalog.is_test_content()
	_vessel = vessel
	_preparation_id = preparation_id
	_ready = true
	return true


func pour(command_id: StringName, ingredient_id: StringName, volume_ml: float, flow_ml_s: float = 10.0, layered: bool = false) -> bool:
	if not _can_apply(command_id) or not _ingredients.has(str(ingredient_id)) or not _positive(volume_ml) or volume_ml < MIN_DOSE_ML or not _positive(flow_ml_s) or flow_ml_s > 500:
		return false
	var space := maxf(0, float(_vessel.capacity_ml) - get_volume_ml())
	if volume_ml > space + EPSILON or space <= 0:
		return false
	var amount := minf(volume_ml, space)
	var keep_layer := false
	var outcome := "first_pour"
	if not _layers.is_empty():
		var top := _properties(_layers.back())
		var incoming: Dictionary = _ingredients[str(ingredient_id)]
		var max_flow := BASE_LAYER_FLOW + VISCOUS_FLOW_BONUS * float(top.viscosity)
		keep_layer = layered and float(top.density) + EPSILON >= float(incoming.density) + MIN_DENSITY_GAP and flow_ml_s <= max_flow
		outcome = "layer_preserved" if keep_layer else "mixed_pour"
	var emulsified := _has_emulsion()
	_layers.append({str(ingredient_id): amount})
	if _layers.size() > 1 and not keep_layer:
		_mix_layers(emulsified)
	_record(command_id, "pour", {"ingredient_id": str(ingredient_id), "volume_ml": amount, "requested_volume_ml": volume_ml, "flow_ml_s": flow_ml_s, "layered": layered, "outcome": outcome})
	return true


func mix(command_id: StringName, method: StringName = &"stir") -> bool:
	if not _can_apply(command_id) or _layers.is_empty() or method not in [&"stir", &"shake"]:
		return false
	_mix_layers(method == &"shake" or _has_emulsion())
	_record(command_id, str(method), {})
	return true


func settle(command_id: StringName) -> bool:
	if not _can_apply(command_id) or _layers.is_empty():
		return false
	_mix_layers(false)
	_record(command_id, "settle", {})
	return true


func discard(command_id: StringName, volume_ml: float) -> bool:
	if not _can_apply(command_id) or not _positive(volume_ml) or volume_ml > get_volume_ml() + EPSILON:
		return false
	var amount := minf(volume_ml, get_volume_ml())
	var remaining := amount
	while remaining > 0 and not _layers.is_empty():
		var top: Dictionary = _layers.back()
		var size := _volume(top)
		if remaining >= size:
			remaining -= size
			_layers.pop_back()
		else:
			var fraction := (size - remaining) / size
			for id in top:
				top[id] = float(top[id]) * fraction
			remaining = 0
	_record(command_id, "discard", {"volume_ml": amount, "requested_volume_ml": volume_ml})
	return true


func seal(command_id: StringName) -> Dictionary:
	if not _can_apply(command_id, true) or _layers.is_empty() or get_volume_ml() <= 0:
		return {}
	_record(command_id, "seal", {})
	_sealed = true
	_result = get_snapshot()
	_result["event_id"] = "drink:%s:%s" % [_preparation_id, command_id]
	return _result.duplicate(true)


func get_result() -> Dictionary:
	return _result.duplicate(true)


func get_volume_ml() -> float:
	var total := 0.0
	for layer in _layers:
		total += _volume(layer)
	return total


func get_snapshot() -> Dictionary:
	if not _ready:
		return {}
	var layers: Array[Dictionary] = []
	for layer in _layers:
		layers.append(_properties(layer))
	var overall := _properties(_all_components())
	overall.emulsified = _has_emulsion()
	var structure := "empty"
	if not layers.is_empty():
		structure = "layered" if layers.size() > 1 else ("emulsified" if layers[0].emulsified else "homogeneous")
	return {"schema_version": 1, "test_content": _test_content, "preparation_id": str(_preparation_id), "vessel": _vessel.duplicate(true), "sealed": _sealed, "revision": _commands.size(), "structure": structure, "overall": overall, "layers": layers, "operations": _commands.values().duplicate(true)}


func _can_apply(id: StringName, finalizing: bool = false) -> bool:
	return _ready and not _sealed and DrinkMaterialCatalog.valid_id(id) and not _commands.has(str(id)) and (_commands.size() < MAX_COMMANDS or (finalizing and _commands.size() == MAX_COMMANDS))


func _positive(value: float) -> bool:
	return is_finite(value) and value > 0


func _record(id: StringName, operation: String, data: Dictionary) -> void:
	_commands[str(id)] = {"command_id": str(id), "operation": operation, "data": data.duplicate(true)}


func _volume(components: Dictionary) -> float:
	var total := 0.0
	for id in _sorted_keys(components):
		total += float(components[id])
	return total


func _sorted_keys(data: Dictionary) -> Array:
	var result := data.keys()
	result.sort()
	return result


func _all_components() -> Dictionary:
	var result: Dictionary = {}
	for layer in _layers:
		for id in _sorted_keys(layer):
			result[id] = float(result.get(id, 0.0)) + float(layer[id])
	return result


func _has_emulsion() -> bool:
	for layer in _layers:
		var groups: Dictionary = {}
		for id in layer:
			groups[_ingredients[id].mix_group] = true
		if groups.size() > 1:
			return true
	return false


func _mix_layers(emulsify: bool) -> void:
	var components := _all_components()
	_layers.clear()
	if emulsify:
		_layers.append(components)
		return
	var groups: Dictionary = {}
	for id in _sorted_keys(components):
		var group: String = _ingredients[id].mix_group
		if not groups.has(group):
			groups[group] = {}
		groups[group][id] = components[id]
	var order := _sorted_keys(groups)
	order.sort_custom(func(a: String, b: String) -> bool:
		var first: float = _properties(groups[a]).density
		var second: float = _properties(groups[b]).density
		return a < b if first == second else first > second
	)
	for group in order:
		_layers.append(groups[group])


func _properties(components: Dictionary) -> Dictionary:
	var volume := _volume(components)
	var result := {"volume_ml": volume, "components": {}, "density": 0.0, "viscosity": 0.0, "strength": 0.0, "color": [0.0, 0.0, 0.0, 0.0], "taste": {"sweet": 0.0, "sour": 0.0, "bitter": 0.0}, "tags": [], "emulsified": false}
	if volume <= 0:
		return result
	var groups: Dictionary = {}
	var tags: Dictionary = {}
	for id in _sorted_keys(components):
		var amount := float(components[id])
		var weight := amount / volume
		var item: Dictionary = _ingredients[id]
		result.components[id] = amount
		for property in ["density", "viscosity", "strength"]:
			result[property] += float(item[property]) * weight
		for channel in 4:
			result.color[channel] += float(item.color[channel]) * weight
		for taste in DrinkMaterialCatalog.TASTES:
			result.taste[taste] += float(item.taste[taste]) * weight
		for tag in item.tags:
			tags[str(tag)] = true
		groups[str(item.mix_group)] = true
	result.tags = _sorted_keys(tags)
	result.emulsified = groups.size() > 1
	return result
