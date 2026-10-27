class_name DrinkMaterialCatalog
extends RefCounted
## Неизменяемые определения материалов и сосудов; рецепты/эффекты отдельно.

const MAX_FILE_BYTES := 262144
const TASTES := ["sweet", "sour", "bitter"]
var validation_errors: PackedStringArray = []
var _loaded: bool = false
var _ingredients: Dictionary = {}
var _vessels: Dictionary = {}
var _test_content: bool = false


static func valid_id(value: Variant) -> bool:
	if not value is String and not value is StringName:
		return false
	var expression := RegEx.new()
	expression.compile("^[a-z][a-z0-9_]{0,63}$")
	return expression.search(str(value)) != null


static func finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


func is_loaded() -> bool:
	return _loaded


func is_test_content() -> bool:
	return _test_content


func load_file(path: String) -> bool:
	validation_errors.clear()
	if _loaded:
		return _fail("Catalog already loaded")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES:
		return _fail("Cannot read material catalog or file too large")
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return _fail("Invalid material JSON at line %d" % parser.get_error_line())
	return load_document(parser.data)


func load_document(data: Variant) -> bool:
	validation_errors.clear()
	if _loaded:
		return _fail("Catalog already loaded")
	if not data is Dictionary or not _keys(data, ["schema_version", "test_content", "ingredients", "vessels"]):
		return _fail("Unknown or missing catalog fields")
	if not finite_number(data.schema_version) or float(data.schema_version) != 1.0 or not data.test_content is bool:
		return _fail("Unsupported schema version or test_content")
	if not data.ingredients is Array or data.ingredients.is_empty() or data.ingredients.size() > 128:
		return _fail("Expected 1..128 ingredients")
	if not data.vessels is Array or data.vessels.is_empty() or data.vessels.size() > 32:
		return _fail("Expected 1..32 vessels")
	var ingredients: Dictionary = {}
	var vessels: Dictionary = {}
	for item in data.ingredients:
		if not _valid_ingredient(item) or ingredients.has(str(item.id)):
			return _fail("Invalid or duplicate ingredient")
		ingredients[str(item.id)] = item.duplicate(true)
	for item in data.vessels:
		if not _valid_vessel(item) or vessels.has(str(item.id)):
			return _fail("Invalid or duplicate vessel")
		vessels[str(item.id)] = item.duplicate(true)
	_ingredients = ingredients
	_vessels = vessels
	_test_content = data.test_content
	_loaded = true
	return true


func get_ingredient_ids() -> PackedStringArray:
	var result := PackedStringArray(_ingredients.keys())
	result.sort()
	return result


func get_vessel_ids() -> PackedStringArray:
	var result := PackedStringArray(_vessels.keys())
	result.sort()
	return result


func get_ingredient(id: StringName) -> Dictionary:
	return _ingredients.get(str(id), {}).duplicate(true)


func get_vessel(id: StringName) -> Dictionary:
	return _vessels.get(str(id), {}).duplicate(true)


func _valid_ingredient(item: Variant) -> bool:
	if not item is Dictionary or not _keys(item, ["id", "title", "density", "viscosity", "color", "strength", "taste", "mix_group", "tags"]):
		return false
	if not valid_id(item.id) or not _title(item.title) or not valid_id(item.mix_group):
		return false
	if not finite_number(item.density) or item.density <= 0 or item.density > 10:
		return false
	if not _unit(item.viscosity) or not _unit(item.strength):
		return false
	if not item.color is Array or item.color.size() != 4:
		return false
	for component in item.color:
		if not _unit(component):
			return false
	if not item.taste is Dictionary or not _keys(item.taste, TASTES):
		return false
	for key in TASTES:
		if not _unit(item.taste[key]):
			return false
	if not item.tags is Array or item.tags.size() > 32:
		return false
	var unique: Dictionary = {}
	for tag in item.tags:
		if not valid_id(tag) or unique.has(str(tag)):
			return false
		unique[str(tag)] = true
	return true


func _valid_vessel(item: Variant) -> bool:
	return item is Dictionary and _keys(item, ["id", "title", "capacity_ml"]) \
		and valid_id(item.id) and _title(item.title) and finite_number(item.capacity_ml) \
		and item.capacity_ml > 0 and item.capacity_ml <= 2000


func _keys(data: Dictionary, expected: Array) -> bool:
	if data.size() != expected.size():
		return false
	for key in expected:
		if not data.has(key):
			return false
	return true


func _unit(value: Variant) -> bool:
	return finite_number(value) and value >= 0 and value <= 1


func _title(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= 160


func _fail(message: String) -> bool:
	validation_errors.append(message)
	return false
