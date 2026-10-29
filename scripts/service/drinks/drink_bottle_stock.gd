class_name DrinkBottleStock
extends RefCounted
## Запас одной TEST-бутылки каждого материала на текущую смену.

var _remaining: Dictionary = {}
var _configured: bool = false


func configure(catalog: DrinkMaterialCatalog, capacity_ml: float, capacities: Dictionary = {}) -> bool:
	if _configured or catalog == null or not catalog.is_loaded() or not is_finite(capacity_ml) or capacity_ml <= 0:
		return false
	for id in capacities:
		if catalog.get_ingredient(StringName(id)).is_empty() or not DrinkMaterialCatalog.finite_number(capacities[id]) or float(capacities[id]) <= 0:
			return false
	for id in catalog.get_ingredient_ids():
		_remaining[id] = float(capacities.get(id, capacity_ml))
	_configured = true
	return true


func get_remaining(id: StringName) -> float:
	return float(_remaining.get(str(id), 0.0))


func withdraw(id: StringName, requested_ml: float) -> float:
	if not _configured or not is_finite(requested_ml) or requested_ml <= 0 or not _remaining.has(str(id)):
		return 0.0
	var taken := minf(requested_ml, get_remaining(id))
	_remaining[str(id)] = maxf(0, get_remaining(id) - taken)
	return taken
