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
var _ice_ml: float = 0
var _temperature_c: float = 20
var _dilution_ml: float = 0
var _aeration: float = 0
var _stirred_s: float = 0
var _shaken_s: float = 0


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
	var space := get_free_space_ml()
	if volume_ml > space + EPSILON or space <= 0:
		return false
	var amount := minf(volume_ml, space)
	var outcome := _append_blend({str(ingredient_id): amount}, flow_ml_s, layered)
	_record(command_id, "pour", {"ingredient_id": str(ingredient_id), "volume_ml": amount, "requested_volume_ml": volume_ml, "flow_ml_s": flow_ml_s, "layered": layered, "outcome": outcome})
	return true


func pour_blend(command_id: StringName, components: Dictionary, flow_ml_s: float = 10, layered: bool = false) -> bool:
	if not _can_apply(command_id) or not _valid_blend(components, flow_ml_s):
		return false
	var requested := _volume(components)
	var accepted := minf(requested, get_free_space_ml())
	if accepted < MIN_DOSE_ML:
		return false
	var dose := components.duplicate(true)
	for id in dose:
		dose[id] = float(dose[id]) * accepted / requested
	var outcome := _append_blend(dose, flow_ml_s, layered)
	_record(command_id, "pour_blend", {"components": dose, "volume_ml": accepted, "requested_volume_ml": requested, "flow_ml_s": flow_ml_s, "layered": layered, "outcome": outcome})
	return true


func _valid_blend(components: Dictionary, flow: float) -> bool:
	if components.is_empty() or not _positive(flow) or flow > 500:
		return false
	for id in components:
		if not _ingredients.has(str(id)) or not (components[id] is float or components[id] is int) or not _positive(float(components[id])):
			return false
	var amount := _volume(components)
	return is_finite(amount) and amount >= MIN_DOSE_ML and amount <= float(_vessel.capacity_ml) - get_volume_ml() - _ice_ml + EPSILON


func _same_blend(first: Dictionary, second: Dictionary) -> bool:
	if first.size() != second.size():
		return false
	for id in first:
		if not second.has(id) or absf(float(first[id]) / _volume(first) - float(second[id]) / _volume(second)) > EPSILON:
			return false
	return true


func _append_blend(components: Dictionary, flow: float, layered: bool) -> String:
	if _layers.is_empty():
		_aeration = 0
		_stirred_s = 0
		_shaken_s = 0
		_dilution_ml = 0
		_temperature_c = 20
	var keep_layer := false
	var extend_layer := false
	var outcome := "first_pour"
	if not _layers.is_empty():
		var top := _properties(_layers.back())
		var incoming := _properties(components)
		var max_flow := BASE_LAYER_FLOW + VISCOUS_FLOW_BONUS * float(top.viscosity)
		extend_layer = layered and flow <= max_flow and _same_blend(_layers.back(), components)
		keep_layer = layered and float(top.density) + EPSILON >= float(incoming.density) + MIN_DENSITY_GAP and flow <= max_flow
		outcome = "layer_extended" if extend_layer else ("layer_preserved" if keep_layer else "mixed_pour")
	var emulsified := _has_emulsion()
	if extend_layer:
		for id in components:
			_layers.back()[id] = float(_layers.back()[id]) + float(components[id])
	else:
		_layers.append(components.duplicate(true))
	if _layers.size() > 1 and not keep_layer and not extend_layer:
		_mix_layers(emulsified)
	return outcome


func get_free_space_ml() -> float:
	return maxf(0, float(_vessel.get("capacity_ml", 0)) - get_volume_ml() - _ice_ml)


func _sample_top(amount: float) -> Dictionary:
	var result: Dictionary = {}
	var remaining := amount
	for index in range(_layers.size() - 1, -1, -1):
		var layer := _layers[index]
		var part := minf(remaining, _volume(layer))
		for id in layer:
			result[id] = float(result.get(id, 0)) + float(layer[id]) * part / _volume(layer)
		remaining -= part
		if remaining <= EPSILON:
			break
	return result


func extract(command_id: StringName, volume_ml: float) -> Dictionary:
	if not _can_apply(command_id) or not _positive(volume_ml) or volume_ml < MIN_DOSE_ML or volume_ml > get_volume_ml() + EPSILON:
		return {}
	var amount := minf(volume_ml, get_volume_ml())
	var components := _sample_top(amount)
	if not discard(command_id, amount):
		return {}
	return {"volume_ml": amount, "components": components}


func transfer_to(command_id: StringName, target: DrinkPreparation, volume_ml: float, flow_ml_s: float = 10, layered: bool = false) -> Dictionary:
	if target == null or target == self or not _can_apply(command_id) or not target._can_apply(command_id) or not _positive(volume_ml) or volume_ml < MIN_DOSE_ML or volume_ml > get_volume_ml() + EPSILON:
		return {}
	var amount := minf(volume_ml, get_volume_ml())
	var components := _sample_top(amount)
	if not target._valid_blend(components, flow_ml_s):
		return {}
	amount = minf(amount, target.get_free_space_ml())
	if amount < MIN_DOSE_ML:
		return {}
	components = _sample_top(amount)
	for id in components:
		if _ingredients[id] != target._ingredients.get(id, {}):
			return {}
	var before := target.get_volume_ml()
	var water := float(_all_components().get("test_water", 0))
	var diluted := _dilution_ml * float(components.get("test_water", 0)) / water if water > 0 else 0.0
	var technique := get_technique()
	var emulsified := _has_emulsion() or target._has_emulsion()
	var removed := extract(command_id, amount)
	var outcome := target._append_blend(components, flow_ml_s, layered)
	if not emulsified and target._properties(components).emulsified:
		target._mix_layers(false)
	target._temperature_c = (target._temperature_c * before + _temperature_c * amount) / (before + amount)
	target._aeration = (target._aeration * before + _aeration * amount) / (before + amount)
	target._dilution_ml += diluted
	target._stirred_s = maxf(target._stirred_s, _stirred_s)
	target._shaken_s = maxf(target._shaken_s, _shaken_s)
	target._record(command_id, "transfer_in", {"source": str(_preparation_id), "components": components, "volume_ml": amount, "layered": layered, "outcome": outcome, "source_technique": technique, "dilution_ml": diluted})
	_commands[str(command_id)].operation = "transfer_out"
	_commands[str(command_id)].data.target = str(target._preparation_id)
	return removed


func add_ice(command_id: StringName, volume_ml: float = 40) -> bool:
	if not _can_apply(command_id) or not _ingredients.has("test_water") or not _positive(volume_ml) or volume_ml > get_free_space_ml():
		return false
	_ice_ml += volume_ml
	_record(command_id, "add_ice", {"volume_ml": volume_ml})
	return true


func mix(command_id: StringName, method: StringName = &"stir", duration_s: float = 1) -> bool:
	if not _can_apply(command_id) or _layers.is_empty() or method not in [&"stir", &"shake"] or not _positive(duration_s) or duration_s > 60:
		return false
	if method == &"shake":
		for id in _all_components():
			if "test_carbonated" in _ingredients[id].tags:
				return false
	_aeration = minf(1, _aeration + duration_s * 0.06) if method == &"shake" else _aeration * 0.95
	if method == &"shake":
		_shaken_s += duration_s
	else:
		_stirred_s += duration_s
	var melted := 0.0
	if _ice_ml > 0 and _temperature_c > 0:
		# Игровое приближение: охлаждение связано с растаявшим льдом, не с магическим флагом.
		var power := 1.6 if method == &"shake" else 0.65
		melted = minf(_ice_ml, minf(duration_s * power, get_volume_ml() * _temperature_c / 80.0))
		_temperature_c = maxf(0, _temperature_c - melted * 80.0 / maxf(get_volume_ml(), 1))
		_ice_ml -= melted
		_dilution_ml += melted
		if melted > 0:
			_layers.append({"test_water": melted})
	_mix_layers(method == &"shake" or _has_emulsion())
	_record(command_id, str(method), {"duration_s": duration_s, "melted_ml": melted})
	return true


func settle(command_id: StringName) -> bool:
	if not _can_apply(command_id) or _layers.is_empty():
		return false
	_mix_layers(false)
	_record(command_id, "settle", {})
	return true


func discard(command_id: StringName, volume_ml: float) -> bool:
	if not _can_apply(command_id) or get_volume_ml() <= 0 or not _positive(volume_ml) or volume_ml > get_volume_ml() + EPSILON:
		return false
	var amount := minf(volume_ml, get_volume_ml())
	var water := float(_all_components().get("test_water", 0))
	if water > 0:
		_dilution_ml *= maxf(0, (water - float(_sample_top(amount).get("test_water", 0))) / water)
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


func empty_container(command_id: StringName) -> bool:
	if not _can_apply(command_id) or (get_volume_ml() <= 0 and _ice_ml <= 0):
		return false
	var liquid := get_volume_ml()
	var ice := _ice_ml
	_layers.clear()
	_ice_ml = 0
	_dilution_ml = 0
	_aeration = 0
	_stirred_s = 0
	_shaken_s = 0
	_temperature_c = 20
	_record(command_id, "empty_container", {"liquid_ml": liquid, "ice_ml": ice})
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


func get_vessel() -> Dictionary:
	return _vessel.duplicate(true)


func get_technique() -> Dictionary:
	return {"ice_ml": _ice_ml, "temperature_c": _temperature_c, "dilution_ml": _dilution_ml, "aeration": _aeration, "stirred_s": _stirred_s, "shaken_s": _shaken_s}


func get_view() -> Dictionary:
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
	return {"vessel": get_vessel(), "structure": structure, "overall": overall, "layers": layers, "technique": get_technique()}


func get_snapshot() -> Dictionary:
	var snapshot := get_view()
	if not snapshot.is_empty():
		snapshot.merge({"schema_version": 1, "test_content": _test_content, "preparation_id": str(_preparation_id), "sealed": _sealed, "revision": _commands.size(), "operations": _commands.values().duplicate(true)})
	return snapshot


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
