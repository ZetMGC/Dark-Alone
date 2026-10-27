class_name DrinkWorkbench
extends Control
## Свободная поверхность одной порции; состав принадлежит DrinkPreparation.

signal preparation_requested(preparation: DrinkPreparation)
signal close_requested
signal menu_requested

const DESIGN := Vector2(1280, 720)
const MATERIALS := "res://content/drinks/test_materials.json"
const SERVE_ZONE := Rect2(860, 310, 190, 78)
const SINK := Rect2(1080, 490, 150, 130)
var preparation: DrinkPreparation
var _catalog := DrinkMaterialCatalog.new()
var _positions: Dictionary = {}
var _angles: Dictionary = {}
var _parking: Dictionary = {}
var _ids: PackedStringArray = []
var _active: bool = false
var _focused: bool = true
var _dragging: StringName = &""
var _offset := Vector2.ZERO
var _pointer := Vector2.ZERO
var _serial: int = 0
var _command: int = 0
var _pending: float = 0
var _pending_id: StringName = &""
var _pending_flow: float = 0
var _pending_layered: bool = false
var _pending_age: float = 0
var _spilled: float = 0
var _marks: Array[Vector2] = []
var _spoon_attached: bool = false
var _in_shaker: bool = false
var _gesture_distance: float = 0
var _last_direction: int = 0
var _reversals: int = 0
var _mixed_this_drag: bool = false
var _message: String = "Возьмите посуду и бутылку"
var _font: Font
var _scale: float = 1
var _origin := Vector2.ZERO
var _view := Transform2D.IDENTITY
var _transfer_time: float = 0
var _transfer_from := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = load("res://scenes/ui/prototype_theme.tres")
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial", "Noto Sans"])
	font.multichannel_signed_distance_field = true
	_font = font
	if not _catalog.load_file(MATERIALS):
		_message = "Не удалось загрузить материалы напитков"
		return
	_ids = _catalog.get_ingredient_ids()
	for index in _ids.size():
		_positions[_ids[index]] = Vector2(100 + index * 105, 225)
		_angles[_ids[index]] = 0.0
		_parking[_ids[index]] = _positions[_ids[index]]
	_positions["cup"] = Vector2(810, 440)
	_positions["spoon"] = Vector2(350, 505)
	_positions["shaker"] = Vector2(505, 460)
	_angles["shaker"] = 0.0
	select_vessel(&"test_shot")
	var footer := HBoxContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	footer.offset_left = -314
	footer.offset_right = -18
	footer.offset_top = -54
	footer.offset_bottom = -14
	add_child(footer)
	for title in ["К стойке · Esc", "Меню"]:
		var button := Button.new()
		button.text = title
		button.name = "WorkbenchMenu" if title == "Меню" else "WorkbenchClose"
		button.custom_minimum_size.x = 140
		if title == "Меню":
			button.pressed.connect(func() -> void: menu_requested.emit())
		else:
			button.pressed.connect(func() -> void: close_requested.emit())
		footer.add_child(button)
	resized.connect(_resize)
	_resize()
	visible = false


func _resize() -> void:
	_scale = maxf(0.01, minf(size.x / DESIGN.x, size.y / DESIGN.y))
	_origin = (size - DESIGN * _scale) * 0.5
	_view = Transform2D(Vector2(_scale, 0), Vector2(0, _scale), _origin)
	end_drag(false)
	queue_redraw()


func set_active(value: bool) -> void:
	if not value:
		end_drag(false)
	_active = value
	visible = value
	queue_redraw()


func select_vessel(id: StringName) -> bool:
	if (preparation != null and (not _active or not _focused)) or not _catalog.is_loaded() or _catalog.get_vessel(id).is_empty() or (preparation != null and preparation.get_volume_ml() > 0):
		return false
	_serial += 1
	preparation = DrinkPreparation.new()
	if not preparation.configure(_catalog, id, StringName("wb_%d_%d" % [Time.get_ticks_usec(), _serial])):
		return false
	_in_shaker = false
	_positions["cup"] = Vector2(810, 440)
	_message = "Поставьте бутылку над стаканом"
	queue_redraw()
	return true


func get_item_position(id: StringName) -> Vector2:
	return _positions.get(str(id), Vector2.ZERO)


func get_cup_rect() -> Rect2:
	var shot: bool = preparation != null and preparation.get_snapshot().vessel.id == "test_shot"
	return Rect2(get_item_position(&"cup") - Vector2(48 if shot else 62, 0), Vector2(96 if shot else 124, 105 if shot else 175))


func get_held_item() -> StringName:
	return _dragging


func get_spilled_ml() -> float:
	return _spilled


func is_in_shaker() -> bool:
	return _in_shaker


func logical_to_screen(point: Vector2) -> Vector2:
	return _origin + point * _scale


func begin_drag(id: StringName, point: Vector2) -> bool:
	if not _active or not _focused or preparation == null or not preparation.get_result().is_empty() or not _positions.has(str(id)) or _dragging != &"" or not point.is_finite():
		return false
	_dragging = id
	_offset = get_item_position(id) - point
	_gesture_distance = 0
	_reversals = 0
	_last_direction = 0
	_mixed_this_drag = false
	if id == &"spoon":
		_spoon_attached = false
	queue_redraw()
	return true


func drag_to(point: Vector2) -> void:
	if not _active or not _focused or _dragging == &"" or not point.is_finite():
		return
	var old := get_item_position(_dragging)
	var target := point + _offset
	target.x = clampf(target.x, 45, 1235)
	var max_y := 470.0 if str(_dragging) in _ids else (515.0 if _dragging == &"shaker" else 550.0)
	if _dragging == &"cup":
		max_y = 630 - get_cup_rect().size.y
		target.x = clampf(target.x, 75, 1205)
	target.y = clampf(target.y, 165, max_y)
	_positions[str(_dragging)] = target
	var movement := target - old
	if _dragging == &"spoon" and not _in_shaker and target.distance_to(get_item_position(&"cup") + Vector2(0, 45)) < 100:
		_gesture_distance += movement.length()
		if _gesture_distance >= 180 and not _mixed_this_drag and preparation.mix(_next(), &"stir"):
			_mixed_this_drag = true
			_message = "Напиток перемешан"
	if _dragging == &"shaker" and _in_shaker and absf(movement.x) > 8:
		var direction := int(signf(movement.x))
		if _last_direction != 0 and direction != _last_direction:
			_reversals += 1
		_last_direction = direction
		if _reversals >= 3 and not _mixed_this_drag and preparation.mix(_next(), &"shake"):
			_mixed_this_drag = true
			_message = "Напиток взбит"
	queue_redraw()


func tilt_by(degrees: float) -> void:
	if not _active or not _focused or not is_finite(degrees) or not _angles.has(str(_dragging)):
		return
	_angles[str(_dragging)] = clampf(float(_angles[str(_dragging)]) + degrees, 0, 100)
	queue_redraw()


func end_drag(commit_drop: bool = true) -> void:
	if _dragging == &"":
		return
	_flush_pour()
	var item := _dragging
	_dragging = &""
	if _angles.has(str(item)):
		_angles[str(item)] = 0.0
	if str(item) in _ids:
		var bounds := Rect2(get_item_position(item) - Vector2(34, 0), Vector2(68, 155))
		if bounds.intersects(get_cup_rect().grow(12)):
			_positions[str(item)] = _parking[str(item)]
		elif commit_drop:
			_parking[str(item)] = get_item_position(item)
		_message = "Бутылка поставлена"
	if commit_drop and _active and _focused:
		var point := get_item_position(item)
		if item == &"cup":
			if SINK.has_point(point) or SINK.has_point(get_cup_rect().get_center()):
				if _in_shaker:
					_positions["cup"] = Vector2(810, 440)
					_message = "Напиток ещё в шейкере"
					queue_redraw()
					return
				if preparation.get_volume_ml() > 0:
					preparation.discard(_next(), preparation.get_volume_ml())
				_in_shaker = false
				_positions["cup"] = Vector2(810, 440)
				_message = "Стакан пуст"
			elif point.distance_to(get_item_position(&"shaker")) < 80 and not _in_shaker:
				_in_shaker = preparation.get_volume_ml() > 0
				_positions["cup"] = Vector2(810, 440)
				_message = "Напиток в шейкере" if _in_shaker else "Стакан пуст"
			elif SERVE_ZONE.has_point(point):
				if _in_shaker:
					_message = "Сначала верните напиток из шейкера"
				elif preparation.get_volume_ml() > 0:
					preparation_requested.emit(preparation)
					_message = "Напиток подан" if not preparation.get_result().is_empty() else "Сейчас подать нельзя"
				else:
					_message = "Стакан пуст"
		elif item == &"shaker" and SINK.has_point(point) and _in_shaker:
			preparation.discard(_next(), preparation.get_volume_ml())
			_in_shaker = false
			_message = "Шейкер пуст"
		elif item == &"spoon" and not _in_shaker and point.distance_to(get_item_position(&"cup")) < 85:
			_spoon_attached = true
			_message = "Ложка у края — струя будет мягче"
	queue_redraw()


func _next() -> StringName:
	_command += 1
	return StringName("wb_action_%d" % _command)


func stream_info() -> Dictionary:
	if not _angles.has(str(_dragging)):
		return {}
	var angle := deg_to_rad(float(_angles[str(_dragging)]))
	var rate := maxf(0, (rad_to_deg(angle) - 35) / 55.0) * 24.0
	if rate <= 0:
		return {}
	var start := get_item_position(_dragging)
	var velocity := Vector2.UP.rotated(angle) * (50 + rate * 3)
	var cup := get_cup_rect()
	var difference := cup.position.y - start.y
	var discriminant := velocity.y * velocity.y + 1300 * difference
	var hit := false
	var time := 0.0
	var endpoint := Vector2(start.x, 625)
	if difference > 5 and discriminant >= 0:
		time = (-velocity.y + sqrt(discriminant)) / 650.0
		endpoint = start + velocity * time + Vector2(0, 325 * time * time)
		hit = endpoint.x > cup.position.x + 7 and endpoint.x < cup.end.x - 7
	if not hit:
		time = (-velocity.y + sqrt(maxf(0, velocity.y * velocity.y + 1300 * (625 - start.y)))) / 650.0
		endpoint = start + velocity * time + Vector2(0, 325 * time * time)
	return {"start": start, "velocity": velocity, "time": time, "end": endpoint, "hit": hit, "rate": rate, "height": difference}


func advance_pour(delta: float) -> void:
	if not _active or not _focused or not is_finite(delta) or delta <= 0 or preparation == null:
		return
	var dt := minf(delta, 0.05)
	var stream := stream_info()
	if stream.is_empty():
		_flush_pour()
		return
	if _dragging == &"shaker":
		if _in_shaker and stream.hit:
			_flush_pour()
			_in_shaker = false
			_transfer_time = 0.4
			_transfer_from = get_item_position(&"shaker")
			_message = "Напиток возвращён в стакан"
		return
	if str(_dragging) not in _ids:
		return
	var amount: float = stream.rate * dt
	if stream.hit and not _in_shaker:
		var layered: bool = stream.rate <= (14.0 if _spoon_attached else 8.0) and stream.height <= (180 if _spoon_attached else 90)
		var effective_flow: float = stream.rate * (0.7 if _spoon_attached else 1.0)
		if _pending_id != _dragging or layered != _pending_layered or absf(_pending_flow - effective_flow) > 0.5:
			_flush_pour()
		_pending_id = _dragging
		_pending_layered = layered
		_pending_flow = effective_flow
		_pending += amount
		_pending_age += dt
		if _pending_age >= 0.1:
			_flush_pour()
		_message = "Струя попадает в стакан"
	else:
		_flush_pour()
		_spill(amount, stream.end)
		_message = "Мимо стакана"
	queue_redraw()


func _flush_pour() -> void:
	if _pending <= 0 or preparation == null:
		return
	var space: float = maxf(0, float(preparation.get_snapshot().vessel.capacity_ml) - preparation.get_volume_ml())
	var amount := minf(_pending, space)
	var accepted := 0.0
	var before := preparation.get_volume_ml()
	if amount >= DrinkPreparation.MIN_DOSE_ML and preparation.pour(_next(), _pending_id, amount, _pending_flow, _pending_layered):
		accepted = preparation.get_volume_ml() - before
	if _pending > accepted:
		_spill(_pending - accepted, get_item_position(&"cup") + Vector2(50, 160))
	_pending = 0
	_pending_age = 0


func _spill(amount: float, point: Vector2) -> void:
	_spilled += amount
	if _marks.is_empty() or point.distance_to(_marks.back()) > 8:
		_marks.append(point.clamp(Vector2(25, 405), Vector2(1255, 630)))
		if _marks.size() > 24:
			_marks.pop_front()


func _gui_input(event: InputEvent) -> void:
	if not _active or not _focused:
		return
	if event is InputEventMouse:
		_pointer = (event.position - _origin) / _scale
	if event is InputEventMouseMotion:
		drag_to(_pointer)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if Rect2(35, 425, 90, 190).has_point(_pointer):
					select_vessel(&"test_shot")
				elif Rect2(130, 425, 90, 190).has_point(_pointer):
					select_vessel(&"test_glass")
				else:
					begin_drag(_hit_item(_pointer), _pointer)
			else:
				end_drag()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			tilt_by(7 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -7)
		elif event.button_index == MOUSE_BUTTON_RIGHT and _angles.has(str(_dragging)):
			_angles[str(_dragging)] = 70.0 if event.pressed else 0.0
		accept_event()
	queue_redraw()


func _hit_item(point: Vector2) -> StringName:
	var spoon := _spoon_position()
	var nearest := Geometry2D.get_closest_point_to_segment(point, spoon, spoon + Vector2(-65, 75))
	if point.distance_to(spoon) < 20 or point.distance_to(nearest) < 13:
		_positions["spoon"] = spoon
		return &"spoon"
	if Rect2(get_item_position(&"shaker") - Vector2(40, 5), Vector2(80, 135)).has_point(point):
		return &"shaker"
	if get_cup_rect().grow(10).has_point(point):
		return &"cup"
	for id in _ids:
		var transform := Transform2D(deg_to_rad(float(_angles[id])), _positions[id])
		if Rect2(-35, -12, 70, 170).has_point(transform.affine_inverse() * point):
			return StringName(id)
	return &""


func _spoon_position() -> Vector2:
	return get_item_position(&"cup") + Vector2(34, -10) if _spoon_attached else get_item_position(&"spoon")


func _process(delta: float) -> void:
	if not _active or not _focused:
		return
	advance_pour(delta)
	if _transfer_time > 0:
		_transfer_time = maxf(0, _transfer_time - delta)
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		end_drag(false)
		_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true


func _local(position: Vector2 = Vector2.ZERO, angle: float = 0) -> void:
	draw_set_transform_matrix(_view * Transform2D(angle, position))


func _text(point: Vector2, value: String, color: Color = Color(0.84, 0.8, 0.69), font_size: int = 18) -> void:
	draw_string(_font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.065, 0.06))
	_local()
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.12, 0.14, 0.12))
	for x in range(0, 1280, 120):
		draw_line(Vector2(x, 65), Vector2(x, 360), Color(0.09, 0.11, 0.09), 4)
	draw_rect(Rect2(0, 380, 1280, 340), Color(0.24, 0.215, 0.175))
	for y in range(380, 720, 38):
		draw_line(Vector2(0, y), Vector2(1280, y), Color(0.18, 0.17, 0.14), 2)
	for index in 34:
		var x := float((index * 173) % 1240)
		var y := float(400 + (index * 47) % 220)
		draw_line(Vector2(x, y), Vector2(x + 24 + index % 17, y + 1), Color(0.3, 0.27, 0.21, 0.4))
	draw_rect(Rect2(0, 0, 1280, 60), Color(0.065, 0.075, 0.065))
	_text(Vector2(30, 38), "РАБОЧАЯ СТОЙКА", Color(0.85, 0.77, 0.56), 25)
	_text(Vector2(30, 112), "БУТЫЛКИ")
	draw_rect(Rect2(45, 385, 665, 14), Color(0.14, 0.12, 0.09))
	draw_rect(Rect2(640, 404, 410, 238), Color(0.065, 0.085, 0.075))
	for x in range(650, 1050, 8):
		draw_line(Vector2(x, 413), Vector2(x, 634), Color(0.11, 0.13, 0.11), 2)
	draw_rect(SERVE_ZONE, Color(0.35, 0.33, 0.27))
	draw_rect(SERVE_ZONE.grow(-6), Color(0.21, 0.22, 0.19))
	_text(SERVE_ZONE.position + Vector2(33, 46), "ПОДАТЬ ГОСТЮ", Color(0.83, 0.78, 0.63), 16)
	draw_rect(SINK, Color(0.43, 0.44, 0.39))
	draw_rect(SINK.grow(-10), Color(0.075, 0.09, 0.08))
	draw_circle(SINK.get_center(), 15, Color(0.025, 0.035, 0.03))
	_text(SINK.position + Vector2(42, -12), "СЛИВ")
	_draw_rack()
	for mark in _marks:
		draw_circle(mark, 8, Color(0.35, 0.26, 0.16, 0.6))
	if preparation == null:
		return
	for id in _ids:
		if StringName(id) != _dragging:
			_draw_bottle(StringName(id))
	_draw_cup()
	_draw_spoon()
	_draw_shaker()
	if str(_dragging) in _ids:
		_draw_bottle(_dragging)
	_draw_stream()
	_local()
	_text(Vector2(28, 662), _message)
	var help := "ЛКМ — перетаскивать · ложка — мешать · стакан в поднос — подать"
	if _dragging == &"cup":
		help = "Поднос — подать · шейкер — перелить · слив — опустошить"
	elif _dragging == &"spoon":
		help = "Поводите ложкой в стакане — перемешать · оставьте у края — слои"
	elif _dragging == &"shaker":
		help = "Влево-вправо — взбить · наклон над стаканом — вернуть" if _in_shaker else "Перелейте напиток из стакана в шейкер"
	elif _angles.has(str(_dragging)):
		help = "Колесо — наклон · ПКМ — быстрый налив · отпустить ЛКМ — поставить"
	_text(Vector2(28, 695), help, Color(0.7, 0.69, 0.61), 16)


func _draw_rack() -> void:
	_text(Vector2(35, 420), "ЧИСТАЯ ПОСУДА")
	for index in 2:
		var base := Vector2(75 + index * 100, 475)
		var height := 60 if index == 0 else 110
		draw_polyline(PackedVector2Array([base + Vector2(-25, 0), base + Vector2(-20, height), base + Vector2(20, height), base + Vector2(25, 0)]), Color(0.65, 0.72, 0.68), 3)
		_text(base + Vector2(-25, height + 24), "Шот" if index == 0 else "Стакан", Color(0.72, 0.7, 0.61), 14)


func _draw_bottle(id: StringName) -> void:
	var item := _catalog.get_ingredient(id)
	_local(get_item_position(id), deg_to_rad(float(_angles[str(id)])))
	draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(12, 0), Vector2(12, 38), Vector2(34, 58), Vector2(34, 153), Vector2(-34, 153), Vector2(-34, 58), Vector2(-12, 38)]), Color(0.2, 0.27, 0.22))
	draw_rect(Rect2(-27, 67, 54, 75), Color(item.color[0], item.color[1], item.color[2], 0.85))
	draw_rect(Rect2(-28, 87, 56, 37), Color(0.67, 0.62, 0.47))
	_text(Vector2(-10, 113), str(_ids.find(str(id)) + 1), Color(0.14, 0.17, 0.13), 24)
	draw_line(Vector2(-9, 7), Vector2(-9, 40), Color(0.56, 0.62, 0.51), 3)
	draw_line(Vector2(-13, 0), Vector2(13, 0), Color(0.64, 0.65, 0.55), 4)
	_local()
	if _dragging == id:
		_text(Vector2(32, 153), str(item.title).trim_prefix("[TEST] "), Color(0.8, 0.75, 0.61), 18)


func _draw_cup() -> void:
	var rect := get_cup_rect()
	draw_rect(rect, Color(0.65, 0.73, 0.68, 0.07))
	var state := preparation.get_snapshot()
	var level := rect.end.y - 4
	if not _in_shaker:
		for layer in state.layers:
			var height: float = (rect.size.y - 8) * float(layer.volume_ml) / float(state.vessel.capacity_ml)
			var color := Color(layer.color[0], layer.color[1], layer.color[2], 0.85)
			draw_rect(Rect2(rect.position.x + 6, level - height, rect.size.x - 12, height), color)
			draw_line(Vector2(rect.position.x + 7, level - height), Vector2(rect.end.x - 7, level - height), color.lightened(0.22), 2)
			level -= height
	draw_polyline(PackedVector2Array([rect.position, Vector2(rect.position.x + 5, rect.end.y), rect.end - Vector2(5, 0), Vector2(rect.end.x, rect.position.y)]), Color(0.65, 0.75, 0.7), 3)
	var stream := stream_info()
	draw_line(rect.position - Vector2(3, 0), Vector2(rect.end.x + 3, rect.position.y), Color(0.95, 0.85, 0.6) if not stream.is_empty() and stream.hit else Color(0.75, 0.8, 0.72), 3)


func _draw_spoon() -> void:
	var position := _spoon_position()
	draw_line(position, position + Vector2(-65, 75), Color(0.63, 0.66, 0.62), 5)
	draw_circle(position, 12, Color(0.48, 0.52, 0.47))
	draw_circle(position - Vector2(2, 3), 6, Color(0.66, 0.68, 0.6))


func _draw_shaker() -> void:
	_local(get_item_position(&"shaker"), deg_to_rad(float(_angles["shaker"])))
	draw_colored_polygon(PackedVector2Array([Vector2(-28, 0), Vector2(28, 0), Vector2(37, 110), Vector2(-37, 110)]), Color(0.43, 0.46, 0.42))
	draw_rect(Rect2(-28, 0, 56, 10), Color(0.7, 0.71, 0.65))
	draw_line(Vector2(-20, 20), Vector2(-26, 100), Color(0.57, 0.59, 0.54), 5)
	if _in_shaker:
		draw_circle(Vector2(0, 60), 10, Color(0.65, 0.52, 0.27))
	_local()


func _draw_stream() -> void:
	var stream := stream_info()
	if stream.is_empty() or (_dragging == &"shaker" and not _in_shaker):
		if _transfer_time > 0:
			draw_line(_transfer_from, get_item_position(&"cup"), Color(0.65, 0.53, 0.32), 4)
		return
	var points := PackedVector2Array()
	for index in 18:
		var time: float = stream.time * index / 17.0
		points.append(stream.start + stream.velocity * time + Vector2(0, 325 * time * time))
	if stream.hit:
		var rect := get_cup_rect()
		var fraction: float = preparation.get_volume_ml() / float(preparation.get_snapshot().vessel.capacity_ml)
		points.append(Vector2(stream.end.x, rect.end.y - (rect.size.y - 8) * fraction - 4))
	var color := Color(0.65, 0.53, 0.32)
	if str(_dragging) in _ids:
		var data := _catalog.get_ingredient(_dragging)
		color = Color(data.color[0], data.color[1], data.color[2]).lightened(0.1)
	draw_polyline(points, color, clampf(float(stream.rate) / 5.0, 2, 7), false)
	var endpoint := points[points.size() - 1]
	var wobble := sin(Time.get_ticks_msec() * 0.02) * 6
	draw_line(endpoint + Vector2(-9 - wobble, -1), endpoint + Vector2(9 + wobble, -1), color, 2)
