class_name DrinkWorkbench
extends Control
## Свободная поверхность одной порции; состав принадлежит DrinkPreparation.

signal preparation_requested(preparation: DrinkPreparation)
signal close_requested
signal menu_requested
signal bottle_cap_changed(id: StringName, capped: bool)

var _stvor_capped: bool = true
var _stvor_preview: SubViewport
var _cap_preview: SubViewport
var cap_item: BottleCapItem
var _glass_preview: SubViewport
var bottle_motion: Dictionary = {}
var _pickup_angles: Dictionary = {}
var _throw_velocity := Vector2.ZERO
var _last_drag_time: int = 0
var _cap_pull_pending: bool = false
var _cap_pull_start := Vector2.ZERO
var _standing_press: StringName = &""
var _standing_press_point := Vector2.ZERO

const DESIGN := Vector2(1280, 720)
const MATERIALS := "res://content/drinks/test_materials.json"
const SERVE_ZONE := Rect2(930, 285, 300, 185)
const SINK := Rect2(1080, 490, 150, 130)
const BOTTLE_CAPACITY_ML: float = 500.0
var supplies_required: bool = false
var supplied: Dictionary = {}
var _stored_cups: Dictionary = {}
var _cup_places: Dictionary = {&"test_shot": Vector2(810,440), &"test_glass": Vector2(650,440)}
var preparation: DrinkPreparation
var _mixing: DrinkPreparation
var _shaker: DrinkPreparation
var _shaker_closed: bool = false
var _shaker_cap_on: bool = false
var _shaker_lid_button: Button
var _shaker_cap_button: Button
var _catalog := DrinkMaterialCatalog.new()
var _positions: Dictionary = {}
var _angles: Dictionary = {}
var _parking: Dictionary = {}
var _ids: PackedStringArray = []
var _active: bool = false
var _focused: bool = true
@onready var _notice = preload("res://scripts/ui/notice_bubble.gd").new()
var _last_notice: String = ""
var world_output: bool = false
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
var _pending_target: StringName = &"cup"
var _pending_point := Vector2.ZERO
var _spilled: float = 0
var spill_surface := DrinkSpillSurface.new()
var bottle_stock := DrinkBottleStock.new()
var _cursor_travel := Vector2.ZERO
var _cursor_velocity := Vector2.ZERO
var _swing: float = 0
var _swing_velocity: float = 0
var _bumps: Dictionary = {}
var _contacts: Dictionary = {}
var _vessel_buttons: Dictionary = {}
var _delivery_button: Button
var _cup_on_tray: bool = false
var _delivered: bool = false
var _spoon_attached: bool = false
var _spoon_container: StringName = &"cup"
var _gesture_distance: float = 0
var _last_direction: int = 0
var _reversals: int = 0
var _message: String = "Возьмите посуду и бутылку"
var _context_item: StringName = &""
var _soda_texture: Texture2D = preload("res://assets/drinks/concepts/test_soda_bottle_v1.png")
var _surface_texture: Texture2D = preload("res://assets/drinks/workbench/worn_materials_v1.png")
var _font: Font
var _scale: float = 1
var _origin := Vector2.ZERO
var _view := Transform2D.IDENTITY


func _ready() -> void:
	add_child(_notice)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	if "test_water" in _ids:
		_ids.remove_at(_ids.find("test_water"))
	bottle_stock.configure(_catalog, BOTTLE_CAPACITY_ML, {str(SmallBottleVisual.ID): SmallBottleVisual.CAPACITY})
	_stvor_preview = SmallBottleVisual.make_preview(self)
	_cap_preview = SmallBottleVisual.make_preview(self, true)
	cap_item = BottleCapItem.new()
	cap_item.name = "StvorCap"
	cap_item.bottle_obstacles = _cap_bottle_obstacles
	cap_item.texture = _cap_preview.get_texture()
	add_child(cap_item)
	cap_item.return_requested.connect(func() -> void:
		if not toggle_bottle_cap(SmallBottleVisual.ID):
			_message = "Верните бутылку на рабочий стол"
	)
	cap_item.dropped.connect(_try_close_cap_at_neck)
	cap_item.motion_finished.connect(_on_bottle_cap_motion_finished)
	_glass_preview = FacetedGlassVisual.make_preview(self)
	spill_surface.configure(_catalog)
	for index in _ids.size():
		_positions[_ids[index]] = Vector2(100 + index * 105, 247)
		_angles[_ids[index]] = 0.0
		_parking[_ids[index]] = _positions[_ids[index]]
	_positions["cup"] = Vector2(810, 440)
	_positions["spoon"] = Vector2(350, 505)
	_positions["shaker"] = Vector2(405, 435)
	_positions["mixing"] = Vector2(560, 430)
	_positions["ice"] = Vector2(275, 535)
	_parking["mixing"] = _positions["mixing"]
	_parking["shaker"] = _positions["shaker"]
	_angles["shaker"] = 0.0
	_angles["mixing"] = 0.0
	_angles["cup"] = 0.0
	_mixing = DrinkPreparation.new()
	_mixing.configure(_catalog, &"test_mixing_glass", StringName("mix_%d" % Time.get_ticks_usec()))
	_shaker = DrinkPreparation.new()
	_shaker.configure(_catalog, &"test_shaker", StringName("shake_%d" % Time.get_ticks_usec()))
	select_vessel(&"test_shot")
	var footer := HBoxContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	footer.offset_left = -178
	footer.offset_right = -18
	footer.offset_top = -54
	footer.offset_bottom = -14
	add_child(footer)
	for title in ["Выйти · Esc"]:
		var button := Button.new()
		button.text = title
		button.name = "WorkbenchMenu" if title == "Меню" else "WorkbenchClose"
		button.custom_minimum_size.x = 140
		if title == "Меню":
			button.pressed.connect(func() -> void: menu_requested.emit())
		else:
			button.pressed.connect(func() -> void: close_requested.emit())
		footer.add_child(button)
	for id in [&"test_shot", &"test_glass"]:
		var button := Button.new()
		button.text = "Взять шот" if id == &"test_shot" else "Взять стакан"
		button.name = "ChooseShot" if id == &"test_shot" else "ChooseGlass"
		button.pressed.connect(func() -> void: select_vessel(id))
		add_child(button)
		_vessel_buttons[id] = button
	_delivery_button = Button.new()
	_delivery_button.name = "DeliverDrink"
	_delivery_button.pressed.connect(request_delivery)
	add_child(_delivery_button)
	_shaker_lid_button = Button.new()
	_shaker_lid_button.name = "ShakerLid"
	_shaker_lid_button.pressed.connect(_advance_shaker)
	add_child(_shaker_lid_button)
	_shaker_cap_button = Button.new()
	_shaker_cap_button.name = "ShakerCap"
	_shaker_cap_button.pressed.connect(toggle_shaker_cap)
	add_child(_shaker_cap_button)
	resized.connect(_resize)
	_resize()
	visible = false


func _resize() -> void:
	_scale = maxf(0.01, minf(size.x / DESIGN.x, size.y / DESIGN.y))
	_origin = (size - DESIGN * _scale) * 0.5
	_view = Transform2D(Vector2(_scale, 0), Vector2(0, _scale), _origin)
	if cap_item != null:
		cap_item.cancel_drag()
		cap_item.set_view(_origin, _scale)
	end_drag(false)
	var index := 0
	for id in _vessel_buttons:
		var button: Button = _vessel_buttons[id]
		button.position = logical_to_screen(Vector2(35 + index * 100, 587))
		button.size = Vector2(90, 32) * _scale
		button.add_theme_font_size_override("font_size", maxi(12, roundi(16 * _scale)))
		index += 1
	if _delivery_button != null:
		_delivery_button.position = logical_to_screen(Vector2(950, 417))
		_delivery_button.size = Vector2(260, 42) * _scale
		_delivery_button.add_theme_font_size_override("font_size", maxi(12, roundi(18 * _scale)))
	for entry in [[_shaker_lid_button, Vector2(450, 640)], [_shaker_cap_button, Vector2(550, 585)]]:
		var button: Button = entry[0]
		button.position = logical_to_screen(entry[1])
		button.size = Vector2(380, 36) * _scale
		button.add_theme_font_size_override("font_size", maxi(12, roundi(15 * _scale)))
	_refresh_buttons()
	queue_redraw()


func set_active(value: bool) -> void:
	if not value:
		_cap_pull_pending = false
		_standing_press = &""
		end_drag(false)
		if cap_item != null: cap_item.cancel_drag()
	_active = value
	visible = value
	_refresh_buttons()
	queue_redraw()


func select_vessel(id: StringName) -> bool:
	if supplies_required and not supplied.has(id): return false
	if _delivered or (preparation != null and (not _active or not _focused)) or not _catalog.is_loaded() or _catalog.get_vessel(id).is_empty() or _dragging != &"":
		return false
	if not supplies_required and preparation != null and preparation.get_volume_ml() > 0:
		_message = "Сначала опустошите посуду над сливом — напиток внутри"
		queue_redraw()
		return false
	if supplies_required and preparation != null and supplied.has(&"cup"):
		_stored_cups[StringName(preparation.get_vessel().id)] = preparation
		_cup_places[StringName(preparation.get_vessel().id)] = get_item_position(&"cup")
	if supplies_required and _stored_cups.has(id):
		preparation = _stored_cups[id]
		_positions["cup"] = _cup_places[id]
		_cup_on_tray = false
		_refresh_buttons()
		queue_redraw()
		return true
	_serial += 1
	preparation = DrinkPreparation.new()
	if not preparation.configure(_catalog, id, StringName("wb_%d_%d" % [Time.get_ticks_usec(), _serial])):
		return false
	_cup_on_tray = false
	_positions["cup"] = _cup_places[id] if supplies_required else Vector2(810, 440)
	_message = "Поставьте бутылку над стаканом"
	_refresh_buttons()
	queue_redraw()
	return true


func get_item_position(id: StringName) -> Vector2:
	return _positions.get(str(id), Vector2.ZERO)


func get_cup_rect() -> Rect2:
	var shot: bool = preparation != null and preparation.get_vessel().id == "test_shot"
	var dimensions := Vector2(96 if shot else 124, 105 if shot else 175)
	if _cup_on_tray:
		dimensions = Vector2(60, 50) if shot else Vector2(76, 66)
	return Rect2(get_item_position(&"cup") - Vector2(dimensions.x / 2, 0), dimensions)


func _container(id: StringName) -> DrinkPreparation:
	return preparation if id == &"cup" else (_mixing if id == &"mixing" else (_shaker if id == &"shaker" else null))


func get_container_snapshot(id: StringName) -> Dictionary:
	var model := _container(id)
	return model.get_snapshot() if model != null else {}


func get_container_rect(id: StringName) -> Rect2:
	if not has_supply(id): return Rect2(-10000, -10000, 0, 0)
	if id == &"cup":
		return get_cup_rect()
	if id == &"shaker":
		return Rect2(get_item_position(id) - Vector2(38, 47 if _shaker_closed else 0), Vector2(76, 172 if _shaker_closed else 125))
	return Rect2(get_item_position(id) - Vector2(52, 0), Vector2(104, 170))


func get_held_item() -> StringName:
	return _dragging


func get_spilled_ml() -> float:
	return _spilled


func get_bottle_remaining(id: StringName) -> float:
	return bottle_stock.get_remaining(id)


func get_spill_patches() -> Array[Dictionary]:
	return spill_surface.get_patches()


func get_bottle_angle(id: StringName) -> float:
	return get_item_angle(id)


func get_item_angle(id: StringName) -> float:
	var inherited := get_item_angle(_spoon_container) if id == &"spoon" and _spoon_attached else 0.0
	var recovery_angle := 0.0
	if _pickup_angles.has(str(id)):
		var recovery: Dictionary = _pickup_angles[str(id)]
		var t: float = recovery.time / 0.22
		recovery_angle = float(recovery.from) * (1 - t * t * (3 - 2 * t))
	return inherited + float(_angles.get(str(id), 0.0)) + rad_to_deg(recovery_angle + (_swing if id == _dragging else float(_bumps.get(str(id), {}).get("angle", 0))))


func is_ready_to_deliver() -> bool:
	return _cup_on_tray and preparation != null and preparation.get_volume_ml() > 0 and not _delivered


func request_delivery() -> bool:
	if not _active or not _focused or _dragging != &"" or not is_ready_to_deliver():
		return false
	preparation_requested.emit(preparation)
	_delivered = _delivered or not preparation.get_result().is_empty()
	_message = ("Напиток готов на рабочей поверхности" if world_output else "Напиток передан на стойку перед гостем") if _delivered else "Сейчас подать нельзя — проверьте оставшееся время смены"
	_refresh_buttons()
	queue_redraw()
	return _delivered


func _refresh_buttons() -> void:
	if _shaker_lid_button != null:
		_shaker_lid_button.text = "[E] Закрыть для встряхивания" if not _shaker_closed else ("[E] Снять колпачок для налива" if _shaker_cap_on else "[E] Открыть для наполнения")
		_shaker_lid_button.visible = _context_item == &"shaker" and _dragging == &"" and not _delivered
		_shaker_lid_button.disabled = not _active or not _focused or _dragging != &"" or _delivered
		_shaker_cap_button.visible = false
		_shaker_cap_button.text = "Снять колпачок" if _shaker_cap_on else "Надеть колпачок"
		_shaker_cap_button.disabled = _shaker_lid_button.disabled
	if _delivery_button != null:
		_delivery_button.text = ("Завершить напиток" if world_output else "Подать гостю →") if is_ready_to_deliver() else "Поставьте сюда напиток"
		_delivery_button.disabled = not is_ready_to_deliver()
		_delivery_button.visible = is_ready_to_deliver() and _dragging == &""
		if _delivery_button.visible:
			_delivery_button.text = "[E] " + _delivery_button.text
			_shaker_lid_button.hide()
	for id in _vessel_buttons:
		_vessel_buttons[id].visible = not supplies_required
		var current: bool = preparation != null and preparation.get_vessel().id == str(id)
		_vessel_buttons[id].text = ("✓ Шот" if id == &"test_shot" else "✓ Стакан") if current else ("Шот" if id == &"test_shot" else "Стакан")
		_vessel_buttons[id].tooltip_text = "Для замены сначала опустошите посуду над сливом" if preparation != null and preparation.get_volume_ml() > 0 else "Взять чистую посуду на рабочий коврик"


func advance_motion(delta: float) -> void:
	if not _active or not _focused or not is_finite(delta) or delta <= 0:
		return
	var dt := minf(delta, 0.05)
	advance_tabletop(delta)
	if _dragging != &"":
		var velocity := (_cursor_travel / dt).limit_length(2200)
		# Бутылка подвешена за горлышко: тело отстаёт от ускорения руки.
		var response := 0.002 if _dragging == &"spoon" else (0.0007 if _dragging == &"cup" else 0.0012)
		_swing_velocity += (velocity.x - _cursor_velocity.x) * response
		_cursor_velocity = velocity
		var steps := int(ceil(dt / (1.0 / 120.0)))
		var step := dt / steps
		for index in steps:
			_swing_velocity += (-42 * _swing - 5.5 * _swing_velocity) * step
			var limit := 0.28 if _dragging == &"cup" else 0.55
			_swing = clampf(_swing + _swing_velocity * step, -limit, limit)
	_cursor_travel = Vector2.ZERO
	for id in _bumps:
		var bump: Dictionary = _bumps[id]
		for step in 6:
			bump.velocity += (-90 * float(bump.angle) - 7 * float(bump.velocity)) * dt / 6
			bump.angle = clampf(float(bump.angle) + float(bump.velocity) * dt / 6, -0.10, 0.10)
	spill_surface.advance(dt)
	queue_redraw()


func get_shaker_state() -> StringName:
	return &"open" if not _shaker_closed else (&"sealed" if _shaker_cap_on else &"straining")


func toggle_shaker_lid() -> bool:
	if not _active or not _focused or _dragging != &"" or _delivered:
		return false
	_flush_pour()
	_shaker_closed = not _shaker_closed
	_shaker_cap_on = _shaker_closed
	_reversals = 0
	if _spoon_attached and _spoon_container == &"shaker":
		_spoon_attached = false
		_positions["spoon"] = Vector2(350, 505)
	_message = "Шейкер закрыт — возьмите корпус и встряхните влево-вправо" if _shaker_closed else "Шейкер открыт — лейте в горловину, затем добавьте лёд"
	_refresh_buttons()
	queue_redraw()
	return true


func toggle_shaker_cap() -> bool:
	if not _active or not _focused or _dragging != &"" or _delivered or not _shaker_closed:
		return false
	_shaker_cap_on = not _shaker_cap_on
	_reversals = 0
	_message = "Колпачок закрыт — можно встряхивать" if _shaker_cap_on else "Колпачок снят — поднимите шейкер над стаканом и наклоните колесом"
	_refresh_buttons()
	queue_redraw()
	return true


func is_in_shaker() -> bool:
	return _shaker != null and _shaker.get_volume_ml() >= DrinkPreparation.MIN_DOSE_ML


func logical_to_screen(point: Vector2) -> Vector2:
	return _origin + point * _scale


func begin_drag(id: StringName, point: Vector2) -> bool:
	if id == SmallBottleVisual.ID and cap_item.animating: return false
	if not has_supply(id): return false
	if not _active or not _focused or preparation == null or not preparation.get_result().is_empty() or _delivered or not _positions.has(str(id)) or _dragging != &"" or not point.is_finite():
		return false
	_dragging = id
	if bottle_motion.has(str(id)):
		var motion: TabletopMotion = bottle_motion[str(id)]
		motion.active = false
		if absf(motion.angle) > 0.05:
			_pickup_angles[str(id)] = {"from": motion.angle, "time": 0.0}
			_angles[str(id)] = 0.0
	_throw_velocity = Vector2.ZERO
	_last_drag_time = Time.get_ticks_usec()
	_offset = get_item_position(id) - point
	_gesture_distance = 0
	_reversals = 0
	_last_direction = 0
	_cursor_travel = Vector2.ZERO
	_cursor_velocity = Vector2.ZERO
	_swing = 0
	_swing_velocity = 0
	if id == &"spoon":
		_spoon_attached = false
	if id == &"cup":
		_cup_on_tray = false
	_bumps.erase(str(id))
	_contacts.clear()
	_refresh_buttons()
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
	var now := Time.get_ticks_usec()
	if movement.length() > 0.1:
		var elapsed := clampf((now - _last_drag_time) / 1000000.0, 1.0 / 120.0, 0.1)
		_throw_velocity = _throw_velocity.lerp((movement / elapsed).limit_length(1400), 0.65)
		_last_drag_time = now
	_cursor_travel += movement
	if str(_dragging) in _ids:
		var old_center := old + Vector2(0, 85).rotated(deg_to_rad(get_item_angle(_dragging)))
		var center := target + Vector2(0, 85).rotated(deg_to_rad(get_item_angle(_dragging)))
		for id in _ids:
			if id == str(_dragging) or not has_supply(StringName(id)):
				continue
			var standing := get_item_position(StringName(id)) + Vector2(0, 85)
			var nearest := Geometry2D.get_closest_point_to_segment(standing, old_center, center)
			if standing.distance_to(nearest) < 64:
				if not _contacts.has(id) and movement.length() > 2:
					var direction := signf(movement.x) if absf(movement.x) > 1 else (-1.0 if center.x < standing.x else 1.0)
					var impulse := direction * clampf(movement.length() * 0.025, 0.15, 1.0)
					_bumps[id] = {"angle": 0.0, "velocity": impulse}
					_swing_velocity -= impulse * 0.12
				_contacts[id] = true
			else:
				_contacts.erase(id)
	if _dragging == &"spoon":
		for id in [&"cup", &"mixing", &"shaker"]:
			if (id != &"shaker" or not _shaker_closed) and get_container_rect(id).grow(15).has_point(target):
				_gesture_distance += movement.length()
				if _gesture_distance >= 180 and _container(id).mix(_next(), &"stir", 2):
					_gesture_distance = 0
					_message = "Перемешиваем — со льдом напиток охлаждается"
	if _dragging == &"shaker" and is_in_shaker() and get_shaker_state() == &"sealed" and absf(movement.x) > 8:
		var direction := int(signf(movement.x))
		if _last_direction != 0 and direction != _last_direction:
			_reversals += 1
		_last_direction = direction
		if _reversals >= 3 and _shaker.mix(_next(), &"shake", 3):
			_reversals = 0
			_message = "Встряхиваем — смесь насыщается воздухом"
		elif _reversals >= 3:
			_message = "Газированные компоненты не встряхивают — добавьте их после шейкера"
			_reversals = 0
	queue_redraw()


func tilt_by(degrees: float) -> void:
	if not _active or not _focused or not is_finite(degrees) or not _angles.has(str(_dragging)):
		return
	_angles[str(_dragging)] = clampf(float(_angles[str(_dragging)]) + degrees, -100, 100)
	queue_redraw()


func end_drag(commit_drop: bool = true) -> void:
	if _dragging == &"":
		return
	_flush_pour()
	var item := _dragging
	var release_angle := deg_to_rad(get_item_angle(item))
	var release_velocity := _throw_velocity * clampf(1.0 - (Time.get_ticks_usec() - _last_drag_time) / 120000.0, 0, 1)
	if commit_drop and item in [&"cup", &"spoon", &"shaker", &"mixing"]:
		_bumps[str(item)] = {"angle": clampf(_swing, -0.08, 0.08), "velocity": _swing_velocity * 0.3}
	_dragging = &""
	_swing = 0
	_swing_velocity = 0
	_cursor_velocity = Vector2.ZERO
	_cursor_travel = Vector2.ZERO
	_contacts.clear()
	if not commit_drop:
		_bumps.clear()
	if _angles.has(str(item)) and str(item) not in _ids:
		_angles[str(item)] = 0.0
	if str(item) in _ids:
		_angles[str(item)] = rad_to_deg(release_angle)
		_bumps.erase(str(item))
		var motion := TabletopMotion.new()
		if item == SmallBottleVisual.ID: motion.half_size = Vector2(25, 71)
		var inset := Vector2(0, 6).rotated(release_angle) if item == SmallBottleVisual.ID else Vector2.ZERO
		motion.release(get_item_position(item) + inset, release_angle, release_velocity if commit_drop else Vector2.ZERO, (0.18 if item == SmallBottleVisual.ID else 0.32) + get_bottle_remaining(item) * 0.001)
		bottle_motion[str(item)] = motion
		_pickup_angles.erase(str(item))
		# Перекрытие экранных силуэтов не означает столкновения на поверхности.
		# В частности, отсутствующие бутылки не должны резервировать невидимые места.
		if commit_drop:
			_parking[str(item)] = get_item_position(item)
		_message = "Бутылка поставлена"
	if commit_drop and _active and _focused:
		var point := get_item_position(item)
		if item == &"ice":
			if _shaker_closed and get_container_rect(&"shaker").grow(10).has_point(point):
				_message = "Сначала откройте шейкер, чтобы добавить лёд"
			for id in [&"cup", &"mixing", &"shaker"]:
				if (id != &"shaker" or not _shaker_closed) and get_container_rect(id).grow(10).has_point(point):
					_message = "Лёд добавлен" if _container(id).add_ice(_next(), 30) else "Для льда не хватает места"
			_positions["ice"] = Vector2(275, 535)
		if item == &"cup":
			if SINK.has_point(point) or SINK.has_point(get_cup_rect().get_center()):
				preparation.empty_container(_next())
				_positions["cup"] = Vector2(810, 440)
				_message = "Стакан пуст"
			elif point.distance_to(get_item_position(&"shaker")) < 65:
				_positions["cup"] = Vector2(810, 440)
				_message = "Переливайте струёй: поднимите стакан над открытым шейкером и наклоните колесом"
			elif SERVE_ZONE.has_point(point):
				if preparation.get_volume_ml() > 0:
					_cup_on_tray = true
					_positions["cup"] = Vector2(1100, 340)
					_message = "Напиток на подносе — завершите его" if world_output else "Напиток готов к подаче"
				else:
					_message = "Стакан пуст"
		elif item in [&"shaker", &"mixing"] and SINK.has_point(point) and (item != &"shaker" or get_shaker_state() != &"sealed"):
			_container(item).empty_container(_next())
			_message = "Ёмкость опустошена"
		elif item == &"spoon":
			for id in [&"cup", &"mixing", &"shaker"]:
				if (id != &"shaker" or not _shaker_closed) and point.distance_to(get_item_position(id)) < 75:
					_spoon_attached = true
					_spoon_container = id
					_message = "Ложка у края — направьте на неё мягкую струю"
	if item in [&"mixing", &"shaker"]:
		if get_container_rect(item).intersects(get_cup_rect()) or SINK.has_point(get_item_position(item)):
			_positions[str(item)] = _parking[str(item)]
		elif commit_drop:
			_parking[str(item)] = get_item_position(item)
	_refresh_buttons()
	queue_redraw()


func _next() -> StringName:
	_command += 1
	return StringName("wb_action_%d" % _command)


func stream_info() -> Dictionary:
	if _dragging == SmallBottleVisual.ID and (_stvor_capped or cap_item.animating):
		return {}
	if not _angles.has(str(_dragging)) or (_dragging == &"shaker" and get_shaker_state() != &"straining"):
		return {}
	if str(_dragging) in _ids and get_bottle_remaining(_dragging) < DrinkPreparation.MIN_DOSE_ML:
		return {}
	if _container(_dragging) != null and _container(_dragging).get_volume_ml() < DrinkPreparation.MIN_DOSE_ML:
		return {}
	var angle := deg_to_rad(get_bottle_angle(_dragging))
	var rate := maxf(0, (absf(rad_to_deg(angle)) - 35) / 55.0) * 24.0
	if rate <= 0:
		return {}
	var start := get_item_position(_dragging)
	if _dragging == SmallBottleVisual.ID:
		start += Vector2(0, 10).rotated(angle)
	if _dragging == &"shaker":
		start += Vector2(0, -23).rotated(angle)
	elif _dragging == &"mixing":
		start += Vector2(63, -8).rotated(angle)
	elif _dragging == &"cup":
		start += Vector2(get_cup_rect().size.x / 2, 0).rotated(angle)
	var velocity := Vector2.UP.rotated(angle) * (50 + rate * 3) + _cursor_velocity * 0.08
	var hit := false
	var time := 0.0
	var target: StringName = &""
	var difference := 0.0
	# Глубина на столе определяется положением руки, а не нижней границей экрана.
	var surface_y := clampf(start.y + 160, 410, 620)
	var endpoint := Vector2(start.x, surface_y)
	for id in [&"cup", &"mixing", &"shaker"]:
		if id == _dragging:
			continue
		var rect := get_container_rect(id)
		var height := rect.position.y - start.y
		var discriminant := velocity.y * velocity.y + 1300 * height
		if height <= 5 or discriminant < 0:
			continue
		var arrival := (-velocity.y + sqrt(discriminant)) / 650.0
		var landing := start + velocity * arrival + Vector2(0, 325 * arrival * arrival)
		if landing.x > rect.position.x + 7 and landing.x < rect.end.x - 7 and (not hit or arrival < time):
			time = arrival
			endpoint = landing
			hit = true
			target = id
			difference = height
	var blocked := hit and target == &"shaker" and _shaker_closed
	if blocked:
		hit = false
		target = &""
	if not hit and not blocked:
		time = (-velocity.y + sqrt(maxf(0, velocity.y * velocity.y + 1300 * (surface_y - start.y)))) / 650.0
		endpoint = start + velocity * time + Vector2(0, 325 * time * time)
		endpoint.x = clampf(endpoint.x, 22, 1258)
	return {"start": start, "velocity": velocity, "time": time, "end": endpoint, "hit": hit, "target": target, "rate": rate, "height": difference, "blocked": blocked}


func advance_pour(delta: float) -> void:
	if not _active or not _focused or not is_finite(delta) or delta <= 0 or preparation == null:
		return
	var dt := minf(delta, 0.05)
	for leak in resting_bottle_streams():
		var amount := bottle_stock.withdraw(leak.id, float(leak.rate) * dt)
		_spill_components({str(leak.id): amount}, leak.end)
		queue_redraw()
	var stream := stream_info()
	if stream.is_empty():
		_flush_pour()
		return
	var over_spoon := _is_spoon_hit(stream)
	# Ложка расширяет допуск. Тихий налив у стенки тоже может сохранить границу.
	var along_wall := false
	if stream.hit:
		var rect := get_container_rect(stream.target)
		along_wall = minf(absf(float(stream.end.x) - rect.position.x), absf(rect.end.x - float(stream.end.x))) <= 20
	var layered: bool = stream.hit and absf(_swing_velocity) < 0.6 and ((over_spoon and stream.rate <= 14 and stream.height <= 180) or (along_wall and stream.rate <= 4 and stream.height <= 35))
	var effective_flow: float = stream.rate * (0.7 if over_spoon else 1.0)
	var source := _container(_dragging)
	if source != null:
		if _pending_id != _dragging or _pending_target != stream.target or layered != _pending_layered or absf(_pending_flow - effective_flow) > 0.5:
			_flush_pour()
		_pending_id = _dragging
		_pending_target = stream.target
		_pending_layered = layered
		_pending_flow = effective_flow
		_pending_point = stream.end
		_pending += float(stream.rate) * dt
		_pending_age += dt
		if _pending_age >= 0.1:
			_flush_pour()
		_message = "Переливаем смесь — лёд остаётся за стрейнером" if stream.hit else "Смесь проливается на стол"
		_refresh_buttons()
		queue_redraw()
		return
	var amount := bottle_stock.withdraw(_dragging, float(stream.rate) * dt)
	if stream.hit:
		if _pending_id != _dragging or _pending_target != stream.target or layered != _pending_layered or absf(_pending_flow - effective_flow) > 0.5:
			_flush_pour()
		_pending_target = stream.target
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
	if get_bottle_remaining(_dragging) < DrinkPreparation.MIN_DOSE_ML:
		_flush_pour()
		_message = "Бутылка пуста"
	queue_redraw()


func _flush_pour() -> void:
	if _pending <= 0 or preparation == null:
		return
	var source := _container(_pending_id)
	if source != null:
		var amount := minf(_pending, source.get_volume_ml())
		var moved := 0.0
		var point := _pending_point
		if _pending_target != &"":
			var receiving := _container(_pending_target)
			moved = minf(amount, receiving.get_free_space_ml())
			if moved < DrinkPreparation.MIN_DOSE_ML or source.transfer_to(_next(), receiving, moved, _pending_flow, _pending_layered).is_empty():
				moved = 0
			var rect := get_container_rect(_pending_target)
			point = Vector2(rect.end.x + 8, maxf(410, rect.end.y - 3))
		if amount - moved >= DrinkPreparation.MIN_DOSE_ML:
			var removed := source.extract(_next(), amount - moved)
			if not removed.is_empty():
				_spill_components(removed.components, point)
		_pending = 0
		_pending_age = 0
		return
	var target := _container(_pending_target)
	var space := target.get_free_space_ml()
	var amount := minf(_pending, space)
	var accepted := 0.0
	var before := target.get_volume_ml()
	if amount >= DrinkPreparation.MIN_DOSE_ML and target.pour(_next(), _pending_id, amount, _pending_flow, _pending_layered):
		accepted = target.get_volume_ml() - before
	if _pending > accepted:
		var cup := get_container_rect(_pending_target)
		_spill(_pending - accepted, Vector2(cup.end.x + 8, maxf(410, cup.end.y - 3)))
	_pending = 0
	_pending_age = 0


func _spill(amount: float, point: Vector2) -> void:
	var id := _pending_id if _dragging == &"" else _dragging
	if str(id) in _ids:
		_spill_components({str(id): amount}, point)


func _spill_components(components: Dictionary, point: Vector2) -> void:
	for amount in components.values():
		_spilled += float(amount)
	if not SINK.grow(-10).has_point(point):
		spill_surface.add_spill(components, point.clamp(Vector2(22, 383), Vector2(1258, 627)))


func _gui_input(event: InputEvent) -> void:
	if not _active or not _focused:
		return
	if event is InputEventMouse:
		_pointer = (event.position - _origin) / _scale
	if event is InputEventMouseMotion:
		if _cap_pull_pending:
			if _pointer.distance_to(_cap_pull_start) >= 8:
				_detach_cap_by_drag(_cap_pull_start, _pointer)
				_cap_pull_pending = false
			accept_event()
			return
		if cap_item.external_drag:
			cap_item.drag_pointer(_pointer)
			accept_event()
			return
		if _standing_press != &"" and _pointer.distance_to(_standing_press_point) > 5:
			begin_drag(_standing_press, _standing_press_point)
			_standing_press = &""
		if _dragging == &"":
			var hovered := _hit_item(_pointer)
			if hovered != &"":
				_context_item = hovered
			_refresh_buttons()
		drag_to(_pointer)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _stvor_capped and _dragging == &"" and has_supply(SmallBottleVisual.ID) and get_bottle_cap_rect().has_point(_pointer):
					_cap_pull_pending = true
					_cap_pull_start = _pointer
					accept_event()
					return
				if supplies_required:
					for vessel_id in _stored_cups:
						if vessel_id != StringName(preparation.get_vessel().id) and Rect2(_cup_places[vessel_id] - Vector2(55,0), Vector2(110,175)).has_point(_pointer):
							select_vessel(vessel_id)
							break
				var item := _hit_item(_pointer)
				_context_item = item
				if item != &"":
					if is_bottle_lying(item):
						stand_bottle(item)
						_standing_press = item
						_standing_press_point = _pointer
					else:
						begin_drag(item, _pointer)
				elif Rect2(35, 425, 90, 190).has_point(_pointer):
					select_vessel(&"test_shot")
				elif Rect2(130, 425, 90, 190).has_point(_pointer):
					select_vessel(&"test_glass")
			else:
				_cap_pull_pending = false
				_standing_press = &""
				if cap_item.external_drag:
					cap_item.release_pointer()
				end_drag()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			tilt_by(7 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -7)
		elif event.button_index == MOUSE_BUTTON_RIGHT and _angles.has(str(_dragging)):
			_angles[str(_dragging)] = 70.0 if event.pressed else 0.0
		accept_event()
	queue_redraw()


func _hit_item(point: Vector2) -> StringName:
	var hit := _hit_present_item(point)
	return hit if has_supply(hit) else &""

func _hit_present_item(point: Vector2) -> StringName:
	if has_supply(&"ice") and point.distance_to(Vector2(275, 535)) < 27:
		return &"ice"
	var spoon := _spoon_position()
	var nearest := Geometry2D.get_closest_point_to_segment(point, spoon, spoon + Vector2(-65, 75).rotated(deg_to_rad(get_item_angle(&"spoon"))))
	var hits_spoon := has_supply(&"spoon") and (point.distance_to(spoon) < 20 or point.distance_to(nearest) < 13)
	if _spoon_attached and hits_spoon:
		_positions["spoon"] = spoon
		return &"spoon"
	var cup_point := (point - get_item_position(&"cup")).rotated(-deg_to_rad(get_item_angle(&"cup"))) + get_item_position(&"cup")
	if has_supply(&"cup") and get_cup_rect().grow(10).has_point(cup_point):
		return &"cup"
	if hits_spoon:
		_positions["spoon"] = spoon
		return &"spoon"
	if has_supply(&"shaker") and Rect2(get_item_position(&"shaker") - Vector2(40, 5), Vector2(80, 135)).has_point(point):
		return &"shaker"
	if get_container_rect(&"mixing").grow(8).has_point(point):
		return &"mixing"
	for index in range(_ids.size() - 1, -1, -1):
		var id := _ids[index]
		if not has_supply(StringName(id)): continue
		var transform := _bottle_transform(StringName(id))
		if id == str(SmallBottleVisual.ID):
			if Rect2(-29, 7, 58, 145).has_point(transform.affine_inverse() * point): return SmallBottleVisual.ID
			continue
		if Rect2(-35, -12, 70, 170).has_point(transform.affine_inverse() * point):
			return StringName(id)
	return &""


func _spoon_position() -> Vector2:
	return get_item_position(_spoon_container) + Vector2(34, -10).rotated(deg_to_rad(get_item_angle(_spoon_container))) if _spoon_attached else get_item_position(&"spoon")


func _process(delta: float) -> void:
	if cap_item != null: cap_item.input_enabled = _active and _focused and _dragging == &""
	if not _active or not _focused:
		return
	if cap_item.animating and cap_item.returning:
		cap_item._to = _bottle_transform(SmallBottleVisual.ID) * Vector2(0, 12.5) - BottleCapItem.DIMENSIONS / 2
		cap_item.target_rotation = deg_to_rad(get_item_angle(SmallBottleVisual.ID))
	cap_item.advance(delta)
	if _message != _last_notice:
		_last_notice = _message
		_notice.show_hint(_message)
	_refresh_buttons()
	advance_motion(delta)
	advance_pour(delta)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cap_pull_pending = false
		_standing_press = &""
		end_drag(false)
		if cap_item != null: cap_item.cancel_drag()
		_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true


func _local(position: Vector2 = Vector2.ZERO, angle: float = 0) -> void:
	draw_set_transform_matrix(_view * Transform2D(angle, position))


func _bottle_transform(id: StringName) -> Transform2D:
	var angle := deg_to_rad(get_item_angle(id))
	var position := get_item_position(id)
	return Transform2D(angle, position)


func _text(point: Vector2, value: String, color: Color = Color(0.84, 0.8, 0.69), font_size: int = 18) -> void:
	draw_string(_font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.055, 0.065, 0.06))
	_local()
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.12, 0.14, 0.12))
	_surface(Rect2(0, 60, 1280, 340), Vector2i(1, 0), Color(0.50, 0.53, 0.48))
	_surface(Rect2(0, 380, 1280, 266), Vector2i(0, 0), Color(0.72, 0.70, 0.65))
	_surface(Rect2(0, 649, 1280, 71), Vector2i(0, 0), Color(0.32, 0.30, 0.26))
	draw_rect(Rect2(0, 644, 1280, 6), Color(0.025,0.03,0.02))
	# Край столешницы отделяет предметы от задника без яркой рамки.
	draw_line(Vector2(0, 399), Vector2(1280, 399), Color(0.08, 0.07, 0.05), 5)
	draw_rect(Rect2(0, 0, 1280, 60), Color(0.065, 0.075, 0.065))
	_text(Vector2(30, 38), "РАБОЧАЯ СТОЙКА", Color(0.85, 0.77, 0.56), 25)
	_text(Vector2(30, 112), "БУТЫЛКИ")
	var guidance := "Возьмите посуду из ящика и бутылки с полки" if supplies_required and supplied.is_empty() else "Перенесите бутылку к горлышку посуды и наклоните колесом"
	if _dragging != &"":
		guidance = "Колесо — наклон · отпустите предмет, чтобы поставить" if _angles.has(str(_dragging)) else "Перетащите к нужной посуде и отпустите"
	elif is_ready_to_deliver():
		guidance = "Напиток на подносе — можно завершить"
	elif _context_item == &"shaker":
		guidance = "Закройте шейкер и двигайте им из стороны в сторону" if not _shaker_closed else ("Шейкер закрыт — можно встряхивать" if _shaker_cap_on else "Колпачок снят — можно переливать")
	_text(Vector2(340, 37), guidance, Color(0.64, 0.65, 0.57), 15)
	draw_rect(Rect2(45, 385, 665, 14), Color(0.14, 0.12, 0.09))
	draw_rect(Rect2(637, 401, 416, 244), Color(0.035, 0.045, 0.035))
	_surface(Rect2(640, 404, 410, 238), Vector2i(0, 1), Color(0.62, 0.67, 0.62))
	var hover: bool = _dragging == &"cup" and SERVE_ZONE.has_point(get_item_position(&"cup"))
	draw_rect(SERVE_ZONE, Color(0.55, 0.49, 0.30) if hover or _cup_on_tray else Color(0.35, 0.33, 0.27))
	_surface(SERVE_ZONE.grow(-6), Vector2i(1, 1), Color(0.50, 0.53, 0.47))
	# Спокойная подложка помогает читать текст на металле.
	draw_rect(Rect2(SERVE_ZONE.position + Vector2(10, 8), Vector2(280, 118)), Color(0.055, 0.065, 0.05, 0.48))
	_text(SERVE_ZONE.position + Vector2(18, 25), "ГОТОВЫЙ НАПИТОК" if world_output else "ВЫДАЧА → ГОСТЮ", Color(0.9, 0.82, 0.61), 18)
	if not _cup_on_tray:
		_text(SERVE_ZONE.position + Vector2(18, 78), "Перетащите сюда стакан", Color(0.83, 0.78, 0.63), 16)
		_text(SERVE_ZONE.position + Vector2(18, 104), "Затем завершите напиток" if world_output else "Затем нажмите «Подать»", Color(0.83, 0.78, 0.63), 16)
	_surface(SINK, Vector2i(1, 1), Color(0.78, 0.82, 0.75))
	_surface(SINK.grow(-10), Vector2i(1, 1), Color(0.24, 0.28, 0.25))
	draw_circle(SINK.get_center(), 15, Color(0.025, 0.035, 0.03))
	_text(SINK.position + Vector2(42, -12), "СЛИВ")
	_draw_rack()
	_draw_item_shadows()
	_local()
	for patch in spill_surface.get_patches():
		var radius := DrinkSpillSurface.radius(patch)
		draw_set_transform_matrix(_view * Transform2D(0, Vector2(radius, radius * 0.3), 0, patch.position))
		draw_circle(Vector2.ZERO, 1, patch.color)
		draw_circle(Vector2(0.6, -0.35), 0.5, patch.color)
	_local()
	if preparation == null:
		return
	for id in _ids:
		if StringName(id) != _dragging:
			_draw_bottle(StringName(id))
	_draw_shaker()
	_draw_mixing()
	if has_supply(&"ice"):
		_surface(Rect2(246, 518, 58, 52), Vector2i(1, 1), Color(0.50, 0.57, 0.53))
		_text(Vector2(247, 511), "ЛЁД", Color(0.7, 0.82, 0.83), 14)
		var ice_position := get_item_position(&"ice")
		draw_rect(Rect2(ice_position - Vector2(12, 12), Vector2(24, 24)), Color(0.65, 0.82, 0.86, 0.8))
	if not _spoon_attached:
		_draw_spoon()
	if not _delivered:
		_draw_cup()
		if supplies_required:
			var active_cup := preparation
			var active_position := get_item_position(&"cup")
			for vessel_id in _stored_cups:
				if vessel_id == StringName(active_cup.get_vessel().id): continue
				preparation = _stored_cups[vessel_id]
				_positions["cup"] = _cup_places[vessel_id]
				_draw_cup()
			preparation = active_cup
			_positions["cup"] = active_position
	if _spoon_attached:
		_draw_spoon()
	if str(_dragging) in _ids:
		_draw_bottle(_dragging)
	_draw_stream()
	_local()
	_draw_hover_card()



func _draw_rack() -> void:
	if supplies_required: return
	_text(Vector2(35, 420), "ЧИСТАЯ ПОСУДА")
	for index in 2:
		var base := Vector2(75 + index * 100, 475)
		var height := 60 if index == 0 else 110
		draw_polyline(PackedVector2Array([base + Vector2(-25, 0), base + Vector2(-20, height), base + Vector2(20, height), base + Vector2(25, 0)]), Color(0.65, 0.72, 0.68), 3)
		_text(base + Vector2(-25, -10), "Шот" if index == 0 else "Стакан", Color(0.72, 0.7, 0.61), 14)


func _draw_bottle(id: StringName) -> void:
	if not has_supply(id): return
	var item := _catalog.get_ingredient(id)
	draw_set_transform_matrix(_view * _bottle_transform(id))
	if id == SmallBottleVisual.ID:
		draw_texture_rect(_stvor_preview.get_texture(), Rect2(-45, 0, 90, 153), false)
		_local()
		return
	if id == &"test_soda":
		draw_texture_rect_region(_soda_texture, Rect2(-34, 0, 68, 153), Rect2(288, 20, 448, 1496))
		var remaining := get_bottle_remaining(id) / BOTTLE_CAPACITY_ML
		draw_rect(Rect2(27, 66, 3, 73), Color(0.035, 0.05, 0.03))
		draw_rect(Rect2(27, 139 - remaining * 73, 3, remaining * 73), Color(0.40, 0.57, 0.57))
		_local()
		return
	draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(12, 0), Vector2(12, 38), Vector2(34, 58), Vector2(34, 153), Vector2(-34, 153), Vector2(-34, 58), Vector2(-12, 38)]), Color(0.2, 0.27, 0.22))
	var fill := get_bottle_remaining(id) / BOTTLE_CAPACITY_ML
	var color := Color(item.color[0], item.color[1], item.color[2], 0.85)
	# Поверхность жидкости отстаёт от качания стекла, силуэт остаётся внутри корпуса.
	var slosh := clampf(_swing_velocity * 3, -9, 9) if id == _dragging else 0.0
	var level := 147.0 - fill * 92.0
	if fill > 0:
		draw_colored_polygon(PackedVector2Array([Vector2(-27, clampf(level + slosh, 55, 147)), Vector2(27, clampf(level - slosh, 55, 147)), Vector2(27, 147), Vector2(-27, 147)]), color)
	draw_rect(Rect2(-28, 87, 56, 37), Color(0.67, 0.62, 0.47))
	_text(Vector2(-10, 113), str(_ids.find(str(id)) + 1), Color(0.14, 0.17, 0.13), 24)
	draw_line(Vector2(-9, 7), Vector2(-9, 40), Color(0.56, 0.62, 0.51), 3)
	draw_line(Vector2(-13, 0), Vector2(13, 0), Color(0.64, 0.65, 0.55), 4)
	# Узкое смотровое окно не перекрывается этикеткой.
	draw_rect(Rect2(20, 62, 5, 80), Color(0.08, 0.12, 0.1, 0.7))
	draw_rect(Rect2(20, 142 - fill * 80, 5, fill * 80), color.lightened(0.25))
	_local()



func _draw_cup() -> void:
	if not has_supply(&"cup"): return
	var rect := get_cup_rect()
	var origin := get_item_position(&"cup")
	_local(origin, deg_to_rad(get_item_angle(&"cup")))
	rect.position -= origin
	var state := preparation.get_view()
	if preparation.get_vessel().id == "test_glass":
		var visual := _glass_preview.get_node("GlassVisual") as FacetedGlassVisual
		if visual.set_contents(state): _glass_preview.render_target_update_mode = SubViewport.UPDATE_ONCE
		draw_texture_rect(_glass_preview.get_texture(), rect, false)
		_local()
		return
	draw_rect(rect, Color(0.65, 0.73, 0.68, 0.07))
	var level := rect.end.y - 4
	for layer in state.layers:
		var height: float = (rect.size.y - 8) * float(layer.volume_ml) / float(state.vessel.capacity_ml)
		var color := Color(layer.color[0], layer.color[1], layer.color[2], 0.85)
		draw_rect(Rect2(rect.position.x + 6, level - height, rect.size.x - 12, height), color)
		draw_line(Vector2(rect.position.x + 7, level - height), Vector2(rect.end.x - 7, level - height), color.lightened(0.22), 2)
		level -= height
	_draw_ice_and_foam(state, rect)
	draw_polyline(PackedVector2Array([rect.position, Vector2(rect.position.x + 5, rect.end.y), rect.end - Vector2(5, 0), Vector2(rect.end.x, rect.position.y)]), Color(0.65, 0.75, 0.7), 3)
	var stream := stream_info()
	var rim := PackedVector2Array()
	for segment in 25:
		var angle := TAU * segment / 24.0
		rim.append(Vector2(rect.get_center().x + cos(angle) * rect.size.x * 0.5, rect.position.y + sin(angle) * 8))
	draw_polyline(rim, Color(0.95, 0.85, 0.6) if not stream.is_empty() and stream.hit else Color(0.75,0.8,0.72), 2)
	_local()


func _draw_spoon() -> void:
	if not has_supply(&"spoon"): return
	var position := _spoon_position()
	_local(position, deg_to_rad(get_item_angle(&"spoon")))
	draw_line(Vector2.ZERO, Vector2(-65, 75), Color(0.63, 0.66, 0.62), 5)
	draw_circle(Vector2.ZERO, 12, Color(0.48, 0.52, 0.47))
	draw_circle(Vector2(-2, -3), 6, Color(0.66, 0.68, 0.6))
	_local()


func _draw_shaker() -> void:
	if not has_supply(&"shaker"): return
	_local(get_item_position(&"shaker"), deg_to_rad(get_item_angle(&"shaker")))
	# Гранёный металл и статичная шлифовка читаются в ретро-изображении без внешней текстуры.
	var outline := PackedVector2Array([Vector2(-38, 4), Vector2(38, 4), Vector2(28, 115), Vector2(-28, 115)])
	draw_colored_polygon(outline, Color("626d70"))
	for band in 16:
		var x := -38.0 + band * 4.75
		var shade := 0.33 + 0.38 * exp(-pow((band - 5.0) / 3.8, 2))
		draw_colored_polygon(PackedVector2Array([Vector2(x, 4), Vector2(x + 4.75, 4), Vector2((x + 4.75) * 0.735, 115), Vector2(x * 0.735, 115)]), Color(shade, shade * 1.03, shade * 1.04))
	for line in 25:
		var y := 14.0 + line * 3.8
		var half := lerpf(37, 28, y / 115)
		draw_line(Vector2(-half + 2, y), Vector2(half - 2, y), Color(0.85, 0.88, 0.86, 0.055), 1)
	draw_polyline(PackedVector2Array([Vector2(-38, 4), Vector2(-28, 115), Vector2(28, 115), Vector2(38, 4)]), Color("aeb8b5"), 1.5, true)
	if _shaker_closed:
		draw_colored_polygon(PackedVector2Array([Vector2(-39, 4), Vector2(-33, -13), Vector2(-15, -27), Vector2(15, -27), Vector2(33, -13), Vector2(39, 4)]), Color("a1adae"))
		draw_line(Vector2(-33, -1), Vector2(33, -1), Color("4a5659"), 2)
		if _shaker_cap_on:
			draw_style_box(_metal_cap(), Rect2(-17, -47, 34, 23))
		else:
			draw_circle(Vector2(0, -25), 10, Color("394649"))
			for hole in [-5, 0, 5]:
				draw_circle(Vector2(hole, -25), 1.4, Color("b5c0ba"))
	else:
		_draw_ellipse_rim(Vector2.ZERO)
	_local()
	var label := "ОТКРЫТ · НАЛИВ" if not _shaker_closed else ("ЗАКРЫТ · ВСТРЯХНУТЬ" if _shaker_cap_on else "СТРЕЙНЕР · ПЕРЕЛИТЬ")
	_text(get_item_position(&"shaker") + Vector2(-80, 143), label, Color(0.74, 0.77, 0.72), 12)
	if not _shaker_closed:
		_local(get_item_position(&"shaker") + Vector2(72, 93), 0.18)
		draw_style_box(_metal_cap(), Rect2(-24, -13, 48, 23))
		_local()


func _metal_cap() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("9aa6a6")
	style.border_color = Color("c1c9c1")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style


func _draw_ellipse_rim(center: Vector2) -> void:
	var points := PackedVector2Array()
	for index in 33:
		var angle := TAU * index / 32.0
		points.append(center + Vector2(cos(angle) * 38, sin(angle) * 8))
	draw_colored_polygon(points, Color("222d30"))
	var state := _shaker.get_view()
	if is_in_shaker():
		draw_colored_polygon(points, Color(state.overall.color[0], state.overall.color[1], state.overall.color[2], 0.8))
	if state.technique.ice_ml > 0:
		draw_rect(Rect2(center + Vector2(-8, -4), Vector2(10, 7)), Color("a8ced3"))
	draw_polyline(points, Color("c2c9c3"), 2, true)


func _draw_mixing() -> void:
	if not has_supply(&"mixing"): return
	var position := get_item_position(&"mixing")
	_local(position, deg_to_rad(get_item_angle(&"mixing")))
	var rect := Rect2(-52, 0, 104, 170)
	draw_rect(rect, Color(0.4, 0.6, 0.6, 0.06))
	var state := _mixing.get_view()
	var bottom := 166.0
	for layer in state.layers:
		var height: float = 162 * float(layer.volume_ml) / float(state.vessel.capacity_ml)
		draw_rect(Rect2(-46, bottom - height, 92, height), Color(layer.color[0], layer.color[1], layer.color[2], 0.85))
		bottom -= height
	_draw_ice_and_foam(state, rect)
	draw_polyline(PackedVector2Array([Vector2(-52, 0), Vector2(-48, 170), Vector2(48, 170), Vector2(52, 0), Vector2(63, -8), Vector2(47, -5)]), Color(0.65, 0.76, 0.73), 3)
	_local()
	_text(position + Vector2(-70, -22), "СМЕСИТЕЛЬНЫЙ", Color(0.72, 0.75, 0.67), 13)


func _draw_ice_and_foam(state: Dictionary, rect: Rect2) -> void:
	if state.technique.ice_ml > 0:
		for index in 3:
			var point := Vector2(rect.position.x + 12 + index * 18, rect.end.y - 24 - index % 2 * 20)
			draw_rect(Rect2(point, Vector2(17, 17)), Color(0.6, 0.8, 0.88, 0.65))
	if state.technique.aeration > 0.05 and state.overall.volume_ml > 0:
		var level: float = rect.end.y - (rect.size.y - 8) * float(state.overall.volume_ml) / float(state.vessel.capacity_ml)
		draw_line(Vector2(rect.position.x + 7, level), Vector2(rect.end.x - 7, level), Color(0.82, 0.82, 0.73, state.technique.aeration), 4)


func _is_spoon_hit(stream: Dictionary) -> bool:
	return not stream.is_empty() and stream.hit and _spoon_attached and stream.target == _spoon_container and absf(float(stream.end.x) - _spoon_position().x) <= 44


func _pour_hint(stream: Dictionary) -> String:
	if stream.is_empty():
		if _dragging == &"shaker" and get_shaker_state() != &"straining":
			return "Поставьте шейкер и снимите колпачок перед переливом" if _shaker_closed else "Сначала закройте шейкер; для перелива снимите маленький колпачок"
		return "Колесо вверх — наклонить и начать налив · вниз — выпрямить и остановить"
	var intensity := "По каплям" if stream.rate <= 4 else ("Тонкая струя" if stream.rate <= 14 else "Сильная струя")
	if stream.get("blocked", false):
		return "Струя попадает на крышку — сначала откройте шейкер"
	if not stream.hit:
		return intensity + " · мимо посуды — переместите горлышко над краем"
	if absf(_swing_velocity) >= 0.6:
		return intensity + " · рука раскачивается — задержите бутылку для слоёв"
	if _is_spoon_hit(stream):
		if stream.rate > 14:
			return intensity + " · по ложке, но слишком быстро для слоя — убавьте наклон"
		if stream.height > 180:
			return intensity + " · по ложке, но слишком высоко — опустите горлышко"
		return intensity + " · по ложке — мягкий налив; лёгкое поверх плотного"
	if _spoon_attached and stream.target == _spoon_container:
		return intensity + " · струя проходит мимо ложки — подведите горлышко к ней"
	return intensity + " · для слоёв направьте струю на ложку у края"


func _draw_stream() -> void:
	_draw_liquid_stream(stream_info(), _dragging)
	for leak in resting_bottle_streams():
		_draw_liquid_stream(leak, leak.id)


func _draw_liquid_stream(stream: Dictionary, source_id: StringName) -> void:
	if stream.is_empty():
		return
	var points := PackedVector2Array()
	for index in 18:
		var time: float = stream.time * index / 17.0
		points.append(stream.start + stream.velocity * time + Vector2(0, 325 * time * time))
	points[points.size() - 1] = stream.end
	if stream.hit:
		var rect := get_container_rect(stream.target)
		var model := _container(stream.target)
		var fraction: float = model.get_volume_ml() / float(model.get_vessel().capacity_ml)
		points.append(Vector2(stream.end.x, rect.end.y - (rect.size.y - 8) * fraction - 4))
	var color := Color(0.65, 0.53, 0.32)
	if str(source_id) in _ids:
		var data := _catalog.get_ingredient(source_id)
		color = Color(data.color[0], data.color[1], data.color[2]).lightened(0.1)
	elif _container(source_id) != null:
		var data: Array = _container(source_id).get_view().overall.color
		color = Color(data[0], data[1], data[2]).lightened(0.1)
	# Один фактический расход определяет дозу, траекторию и вид струи.
	var intensity := clampf(float(stream.rate) / 24.0, 0, 1)
	var width := lerpf(0.8, 7.0, intensity)
	var seconds := Time.get_ticks_msec() / 1000.0
	if stream.rate <= 4:
		# При малом наклоне видны отдельные движущиеся капли вместо толстой линии.
		for index in 6:
			var phase := fposmod(seconds * 1.8 + index / 6.0, 1.0)
			var time: float = stream.time * phase
			var drop: Vector2 = stream.start + stream.velocity * time + Vector2(0, 325 * time * time)
			draw_circle(drop, width + 0.6, color)
	else:
		draw_polyline(points, color, width, false)
		# Блики текут по той же дуге, не меняя реальный объём жидкости.
		for index in 4:
			var phase := fposmod(seconds * 2.5 + index / 4.0, 1.0)
			var time: float = stream.time * phase
			var highlight: Vector2 = stream.start + stream.velocity * time + Vector2(0, 325 * time * time)
			draw_circle(highlight, width * 0.25, color.lightened(0.25))
	var endpoint := points[points.size() - 1]
	var splash := lerpf(2, 15, intensity) * (0.85 + sin(seconds * 20) * 0.15)
	draw_line(endpoint + Vector2(-splash, -1), endpoint + Vector2(splash, -1), color, maxf(1, width * 0.4))
	if intensity > 0.5:
		for direction in [-1, 1]:
			var phase := fposmod(seconds * 3 + (0.4 if direction < 0 else 0), 1)
			draw_circle(endpoint + Vector2(direction * splash * phase, -sin(phase * PI) * splash * 0.6), width * 0.2, color)


func _draw_hover_card() -> void:
	var point := (get_local_mouse_position() - _origin) / _scale
	var info := get_hovered_bottle_info(point)
	var cap_info := get_hovered_cap_info(point)
	if not cap_info.is_empty(): info = cap_info
	if info.is_empty():
		return
	var title := str(info.title)
	var width := clampf(_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28, 180, 360)
	var position := (point + Vector2(18, 22)).clamp(Vector2(8, 8), DESIGN - Vector2(width + 8, 70))
	draw_style_box(preload("res://scenes/ui/context_bubble_style.tres"), Rect2(position, Vector2(width, 62)))
	_text(position + Vector2(12, 23), title, Color(0.94, 0.88, 0.74), 16)
	var detail := str(info.description) if info.has("description") else "%d мл · Крепость %d%%" % [info.remaining_ml, info.strength * 100]
	_text(position + Vector2(12, 47), detail, Color(0.72, 0.74, 0.67), 14)


func get_hovered_bottle_info(point: Vector2) -> Dictionary:
	if _dragging != &"" or not _active or not _focused:
		return {}
	var id := _hit_item(point)
	if str(id) not in _ids:
		return {}
	return {"id": id, "title": str(_catalog.get_ingredient(id).title).trim_prefix("[TEST] "), "remaining_ml": get_bottle_remaining(id), "strength": _catalog.get_ingredient(id).strength}

func mark_world_staged() -> void:
	_delivered = true
	_refresh_buttons()
	queue_redraw()


func _advance_shaker() -> void:
	if not _shaker_closed or not _shaker_cap_on:
		toggle_shaker_lid()
	else:
		toggle_shaker_cap()


func _input(event: InputEvent) -> void:
	if not _active or not _focused or _dragging != &"" or event.is_echo():
		return
	if event is InputEventKey and event.pressed and (event.physical_keycode == KEY_E or event.keycode == KEY_E):
		if is_ready_to_deliver():
			request_delivery()
		elif _context_item == &"shaker" and not _delivered:
			_advance_shaker()
		else:
			return
		get_viewport().set_input_as_handled()


func _surface(rect: Rect2, tile: Vector2i, tint: Color = Color.WHITE) -> void:
	var half := _surface_texture.get_size() * 0.5
	# Отступ убирает соседний материал на стыке атласа.
	var region := Rect2(Vector2(tile) * half + Vector2(3, 3), half - Vector2(6, 6))
	draw_texture_rect_region(_surface_texture, rect, region, tint)


func has_supply(id: StringName) -> bool:
	return not supplies_required or supplied.has(id)

func add_supply(id: StringName) -> bool:
	if supplied.has(id): return false
	if id in [&"test_shot", &"test_glass"]:
		supplied[id] = true
		# Пустая посуда выбирается при переносе, до открытия интерфейса.
		var active_before := _active
		_active = true
		var accepted := select_vessel(id)
		_active = active_before
		if not accepted:
			supplied.erase(id)
			return false
		supplied[&"cup"] = true
	else:
		supplied[id] = true
	_refresh_buttons()
	queue_redraw()
	return true


func remove_bottle(id: StringName) -> bool:
	if str(id) not in _ids or not supplied.has(id): return false
	if id == SmallBottleVisual.ID and cap_item.animating:
		cap_item.advance(BottleCapItem.DURATION)
	supplied.erase(id)
	queue_redraw()
	return true


func is_bottle_capped(id: StringName) -> bool:
	return id == SmallBottleVisual.ID and _stvor_capped


func get_bottle_cap_rect() -> Rect2:
	return _bottle_transform(SmallBottleVisual.ID) * Rect2(-15, 0, 30, 25) if _stvor_capped else cap_item.logical_rect()


func toggle_bottle_cap(id: StringName) -> bool:
	if id != SmallBottleVisual.ID or not _active or not _focused or _dragging != &"" or not has_supply(id) or cap_item.animating: return false
	var neck := get_item_position(id) + Vector2(-14.5, 0)
	if _stvor_capped:
		_stvor_capped = false
		(_stvor_preview.get_node("Bottle") as SmallBottleVisual).set_capped(false)
		_stvor_preview.render_target_update_mode = SubViewport.UPDATE_ONCE
		bottle_cap_changed.emit(id, false)
		cap_item.start_motion(neck, (get_item_position(id) + Vector2(32, 124)).clamp(Vector2(16, 165), Vector2(1235, 600)), false)
	else:
		neck = _bottle_transform(id) * Vector2(0, 12.5) - BottleCapItem.DIMENSIONS / 2
		cap_item.start_motion(cap_item.logical_position, neck, true, deg_to_rad(get_item_angle(id)))
	queue_redraw()
	return true


func _on_bottle_cap_motion_finished(attached: bool) -> void:
	_stvor_capped = attached
	(_stvor_preview.get_node("Bottle") as SmallBottleVisual).set_capped(attached)
	_stvor_preview.render_target_update_mode = SubViewport.UPDATE_ONCE
	bottle_cap_changed.emit(SmallBottleVisual.ID, attached)
	_message = "Крышка надета" if _stvor_capped else "Крышка снята — можно наливать"
	queue_redraw()


func get_hovered_cap_info(point: Vector2) -> Dictionary:
	if not _active or not _focused or _dragging != &"" or cap_item.animating or not cap_item.detached or not cap_item.logical_rect().has_point(point): return {}
	return {"id": SmallBottleVisual.ID, "title": "Крышка · Северный створ", "description": "Бутылка 0,25 л" if has_supply(SmallBottleVisual.ID) else "Бутылка вне рабочей зоны"}


func _detach_cap_by_drag(start: Vector2, pointer: Vector2) -> void:
	var neck := _bottle_transform(SmallBottleVisual.ID) * Vector2(0, 12.5) - BottleCapItem.DIMENSIONS / 2
	_stvor_capped = false
	(_stvor_preview.get_node("Bottle") as SmallBottleVisual).set_capped(false)
	_stvor_preview.render_target_update_mode = SubViewport.UPDATE_ONCE
	bottle_cap_changed.emit(SmallBottleVisual.ID, false)
	cap_item.take_from_bottle(neck, start, deg_to_rad(get_item_angle(SmallBottleVisual.ID)))
	cap_item.drag_pointer(pointer)
	queue_redraw()


func is_bottle_lying(id: StringName) -> bool:
	return str(id) in _ids and absf(get_item_angle(id)) > 45 and _dragging != id


func stand_bottle(id: StringName) -> bool:
	if not has_supply(id) or not bottle_motion.has(str(id)) or not _active or not _focused: return false
	(bottle_motion[str(id)] as TabletopMotion).stand_up()
	return true


func advance_tabletop(delta: float) -> void:
	if not _active or not _focused or not is_finite(delta) or delta <= 0: return
	for key in bottle_motion:
		if not has_supply(StringName(key)): continue
		var motion: TabletopMotion = bottle_motion[key]
		if StringName(key) == _dragging:
			if _pickup_angles.has(key):
				var recovery: Dictionary = _pickup_angles[key]
				recovery.time = minf(0.22, recovery.time + delta)
				var t: float = recovery.time / 0.22
				if t >= 1: _pickup_angles.erase(key)
			continue
		if motion.active:
			motion.advance(delta)
			_positions[key] = _motion_origin(StringName(key), motion)
			_angles[key] = rad_to_deg(motion.angle)
	queue_redraw()


func _draw_item_shadows() -> void:
	for key in _positions:
		var id := StringName(key)
		if not has_supply(id): continue
		var at := get_item_position(id)
		var axes := Vector2(30, 7)
		var opacity := 0.56
		var rotation := 0.0
		var lift := 22.0 if id == _dragging else 0.0
		if key in _ids:
			var angle := deg_to_rad(get_item_angle(id))
			var half := Vector2(25,71) if id == SmallBottleVisual.ID else Vector2(34,76.5)
			var support := absf(cos(angle)) * half.y + absf(sin(angle)) * half.x
			var center := at + Vector2(0, half.y + (6 if id == SmallBottleVisual.ID else 0)).rotated(angle)
			var bottom := center.y + support
			at = Vector2(center.x, clampf(bottom + lift, TabletopMotion.TABLE.position.y + 10, TabletopMotion.TABLE.end.y - 3))
			lift = maxf(lift, at.y - bottom)
			if bottle_motion.has(key) and id != _dragging:
				var motion: TabletopMotion = bottle_motion[key]
				at = motion.ground
				lift = motion.elevation
			var lying := absf(sin(angle))
			axes = Vector2(lerpf(24, 73, lying), lerpf(5, 14, lying))
			at.y -= lying * 6
			rotation = sin(angle) * 0.12
		elif id == &"cup":
			if _delivered: continue
			at += Vector2(0, get_cup_rect().size.y + lift)
			axes = Vector2(get_cup_rect().size.x * 0.32, 6)
			opacity = 0.30
		elif id == &"spoon":
			at += Vector2(-30, 60)
			axes = Vector2(47, 3)
			rotation = -0.85
			opacity = 0.24
		elif id == &"ice":
			at += Vector2(0, 24)
			axes = Vector2(16, 5)
			opacity = 0.19
		else:
			at += Vector2(0, 125 + lift)
			axes = Vector2(33, 8) if id == &"shaker" else Vector2(38, 7)
		at.y = clampf(at.y, TabletopMotion.TABLE.position.y + 5, TabletopMotion.TABLE.end.y)
		TabletopMotion.shadow(self, _view, at, axes, rotation, lift, opacity)
	if supplies_required and preparation != null:
		for vessel_id in _stored_cups:
			if vessel_id == StringName(preparation.get_vessel().id): continue
			var bottom: Vector2 = _cup_places[vessel_id] + Vector2(0, 105 if vessel_id == &"test_shot" else 175)
			TabletopMotion.shadow(self, _view, bottom, Vector2(32, 6), 0, 0, 0.22)


func _motion_origin(id: StringName, motion: TabletopMotion) -> Vector2:
	return motion.origin() - (Vector2(0, 6).rotated(motion.angle) if id == SmallBottleVisual.ID else Vector2.ZERO)


func _try_close_cap_at_neck() -> void:
	if not _active or not _focused or _stvor_capped or cap_item.animating or _dragging != &"" or not has_supply(SmallBottleVisual.ID): return
	# Попадание в координатах бутылки: корпус не является горлышком.
	var center := cap_item.logical_position + BottleCapItem.DIMENSIONS / 2
	var local := _bottle_transform(SmallBottleVisual.ID).affine_inverse() * center
	if Rect2(-21, -10, 42, 38).has_point(local):
		toggle_bottle_cap(SmallBottleVisual.ID)


func resting_bottle_streams() -> Array[Dictionary]:
	var streams: Array[Dictionary] = []
	for key in _ids:
		var id := StringName(key)
		if not has_supply(id) or id == _dragging or is_bottle_capped(id) or get_bottle_remaining(id) <= 0: continue
		var angle := deg_to_rad(get_item_angle(id))
		if absf(angle) < deg_to_rad(65): continue
		var rate := 18.0 * clampf((absf(rad_to_deg(angle)) - 65) / 25.0, 0, 1)
		var start := _bottle_transform(id) * Vector2(0, 10 if id == SmallBottleVisual.ID else 0)
		var velocity := Vector2.UP.rotated(angle) * 65
		var floor_y := clampf(start.y + 30, TabletopMotion.TABLE.position.y + 3, TabletopMotion.TABLE.end.y - 3)
		var time := (-velocity.y + sqrt(maxf(0, velocity.y * velocity.y + 1300 * (floor_y - start.y)))) / 650.0
		var end := start + velocity * time + Vector2(0, 325 * time * time)
		end = end.clamp(TabletopMotion.TABLE.position + Vector2.ONE * 3, TabletopMotion.TABLE.end - Vector2.ONE * 3)
		streams.append({"id": id, "start": start, "velocity": velocity, "time": time, "end": end, "rate": rate, "hit": false})
	return streams


func _cap_bottle_obstacles() -> Array[Dictionary]:
	var obstacles: Array[Dictionary] = []
	for key in _ids:
		var id := StringName(key)
		if not has_supply(id): continue
		obstacles.append({"transform": _bottle_transform(id), "rect": Rect2(-25, 30, 50, 118) if id == SmallBottleVisual.ID else Rect2(-34, 15, 68, 138)})
	return obstacles
