class_name JournalNotebook
extends RefCounted
## Личные записи игрока. Координаты на развороте нормализованы, связи не являются фактами сюжета.

signal changed
const MAX_NOTES := 64
const MAX_RECIPES := 32
const MAX_LINKS := 128
const SHEETS := 8
var _notes: Array = []
var _recipes: Array = []
var _links: Array = []
var _next_id: int = 1


func get_notes(sheet: int) -> Array:
	return _notes.filter(func(note: Dictionary) -> bool: return note.sheet == sheet).duplicate(true)


func get_recipes() -> Array:
	return _recipes.duplicate(true)


func get_links() -> Array:
	return _links.duplicate(true)


func _find(items: Array, id: int) -> int:
	for index in items.size():
		if items[index].id == id:
			return index
	return -1


func _valid_text(text: String, limit: int) -> bool:
	return not text.strip_edges().is_empty() and text.length() <= limit


func _valid_position(point: Vector2) -> bool:
	return point.is_finite() and point.x >= 0 and point.x <= 1 and point.y >= 0 and point.y <= 1


func add_note(text: String, position: Vector2, sheet: int = 0) -> int:
	if not _valid_text(text, 320) or not _valid_position(position) or sheet < 0 or sheet >= SHEETS or _notes.size() >= MAX_NOTES or get_notes(sheet).size() >= 8:
		return -1
	var id := _next_id
	_next_id += 1
	_notes.append({"id": id, "text": text, "x": position.x, "y": position.y, "sheet": sheet, "circled": true})
	changed.emit()
	return id


func update_note(id: int, text: String) -> bool:
	var index := _find(_notes, id)
	if index < 0 or not _valid_text(text, 320):
		return false
	_notes[index].text = text
	changed.emit()
	return true


func move_note(id: int, position: Vector2) -> bool:
	var index := _find(_notes, id)
	if index < 0 or not _valid_position(position):
		return false
	_notes[index].x = position.x
	_notes[index].y = position.y
	changed.emit()
	return true


func toggle_circle(id: int) -> bool:
	var index := _find(_notes, id)
	if index < 0:
		return false
	_notes[index].circled = not _notes[index].circled
	changed.emit()
	return true


func remove_note(id: int) -> bool:
	var index := _find(_notes, id)
	if index < 0:
		return false
	_notes.remove_at(index)
	_links = _links.filter(func(link: Dictionary) -> bool: return link.from != id and link.to != id)
	changed.emit()
	return true


func link_notes(from: int, to: int) -> bool:
	var a := _find(_notes, from)
	var b := _find(_notes, to)
	var link := {"from": from, "to": to}
	if a < 0 or b < 0 or from == to or _notes[a].sheet != _notes[b].sheet or link in _links or _links.size() >= MAX_LINKS:
		return false
	_links.append(link)
	changed.emit()
	return true


func unlink_notes(from: int, to: int) -> bool:
	var index := _links.find({"from": from, "to": to})
	if index < 0:
		return false
	_links.remove_at(index)
	changed.emit()
	return true


func add_recipe(text: String) -> int:
	if not _valid_text(text, 4000) or _recipes.size() >= MAX_RECIPES:
		return -1
	var id := _next_id
	_next_id += 1
	_recipes.append({"id": id, "text": text})
	changed.emit()
	return id


func update_recipe(id: int, text: String) -> bool:
	var index := _find(_recipes, id)
	if index < 0 or not _valid_text(text, 4000):
		return false
	_recipes[index].text = text
	changed.emit()
	return true


func remove_recipe(id: int) -> bool:
	var index := _find(_recipes, id)
	if index < 0:
		return false
	_recipes.remove_at(index)
	changed.emit()
	return true


func is_empty() -> bool:
	return _notes.is_empty() and _recipes.is_empty()


func export_data() -> Dictionary:
	return {"notes": _notes.duplicate(true), "links": _links.duplicate(true), "recipes": _recipes.duplicate(true)}


func restore_data(data: Dictionary) -> bool:
	# Проверка до мутации: повреждённые ссылки/нечисловые координаты не дают частичный журнал.
	if data.size() != 3 or not data.get("notes") is Array or not data.get("links") is Array or not data.get("recipes") is Array or data.notes.size() > MAX_NOTES or data.links.size() > MAX_LINKS or data.recipes.size() > MAX_RECIPES:
		return false
	var staged := JournalNotebook.new()
	var ids: Dictionary = {}
	for note in data.notes:
		if not note is Dictionary or note.size() != 6 or not note.get("text") is String or not note.get("circled") is bool or not _number(note.get("x")) or not _number(note.get("y")):
			return false
		var id := Journal._checkpoint_integer(note.get("id"))
		var sheet := Journal._checkpoint_integer(note.get("sheet"))
		if id <= 0 or ids.has(id) or staged.add_note(note.text, Vector2(note.x, note.y), sheet) < 0:
			return false
		ids[id] = true
		staged._notes.back().id = id
		staged._notes.back().circled = note.circled
		staged._next_id = maxi(staged._next_id, id + 1)
	for recipe in data.recipes:
		if not recipe is Dictionary or recipe.size() != 2 or not recipe.get("text") is String:
			return false
		var id := Journal._checkpoint_integer(recipe.get("id"))
		if id <= 0 or ids.has(id) or staged.add_recipe(recipe.text) < 0:
			return false
		ids[id] = true
		staged._recipes.back().id = id
		staged._next_id = maxi(staged._next_id, id + 1)
	for link in data.links:
		if not link is Dictionary or link.size() != 2 or not staged.link_notes(Journal._checkpoint_integer(link.get("from")), Journal._checkpoint_integer(link.get("to"))):
			return false
	_notes = staged._notes
	_recipes = staged._recipes
	_links = staged._links
	_next_id = staged._next_id
	changed.emit()
	return true


func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
