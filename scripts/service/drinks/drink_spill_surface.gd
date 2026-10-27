class_name DrinkSpillSurface
extends RefCounted
## Состав и объединение луж на условной рабочей плоскости.

var _colors: Dictionary = {}
var _patches: Array[Dictionary] = []


func configure(catalog: DrinkMaterialCatalog) -> bool:
	if not _colors.is_empty() or catalog == null or not catalog.is_loaded():
		return false
	for id in catalog.get_ingredient_ids():
		var color: Array = catalog.get_ingredient(StringName(id)).color
		_colors[id] = Color(color[0], color[1], color[2], 0.7)
	return true


func add_spill(components: Dictionary, point: Vector2) -> bool:
	if not point.is_finite() or components.is_empty():
		return false
	var volume := 0.0
	var weighted := Color(0, 0, 0, 0)
	for id in components:
		if not _colors.has(str(id)) or not (components[id] is float or components[id] is int):
			return false
		var amount := float(components[id])
		if not is_finite(amount) or amount <= 0:
			return false
		volume += amount
		weighted += _colors[str(id)] * amount
	if not is_finite(volume):
		return false
	_patches.append({"position": point, "components": components.duplicate(true), "volume_ml": volume, "color": weighted / volume, "spread": 0.0})
	_merge_touching()
	if _patches.size() > 64:
		# Ограничение детализации: ближайшая пара, без потери состава/объёма.
		var first := 0
		var second := 1
		var nearest := INF
		for a in _patches.size():
			for b in range(a + 1, _patches.size()):
				var distance: float = _patches[a].position.distance_squared_to(_patches[b].position)
				if distance < nearest:
					nearest = distance
					first = a
					second = b
		_merge(first, second)
	return true


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0:
		return
	for patch in _patches:
		patch.spread = minf(1, float(patch.spread) + minf(delta, 0.05) * 1.8)
	_merge_touching()


func get_patches() -> Array[Dictionary]:
	return _patches.duplicate(true)


static func radius(patch: Dictionary) -> float:
	return clampf(7 + sqrt(float(patch.volume_ml)) * 3.5, 7, 70) * lerpf(0.45, 1, float(patch.spread))


func _merge_touching() -> void:
	var changed := true
	while changed:
		changed = false
		for a in _patches.size():
			for b in range(a + 1, _patches.size()):
				var difference: Vector2 = _patches[a].position - _patches[b].position
				if Vector2(difference.x, difference.y / 0.3).length() <= radius(_patches[a]) + radius(_patches[b]):
					_merge(a, b)
					changed = true
					break
			if changed:
				break


func _merge(a: int, b: int) -> void:
	var left := _patches[a]
	var right := _patches[b]
	var total: float = left.volume_ml + right.volume_ml
	left.position = (left.position * left.volume_ml + right.position * right.volume_ml) / total
	left.color = (left.color * left.volume_ml + right.color * right.volume_ml) / total
	left.spread = maxf(left.spread, right.spread)
	for id in right.components:
		left.components[id] = float(left.components.get(id, 0)) + float(right.components[id])
	left.volume_ml = total
	_patches.remove_at(b)
