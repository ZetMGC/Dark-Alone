extends Control
## Самостоятельный TEST-стенд модели; не игровой интерфейс стойки.

const DATA := "res://tests/parallel/bar/drink_materials.json"
var preparation: DrinkPreparation
var _catalog := DrinkMaterialCatalog.new()
var _serial: int = 0
var _command: int = 0
var _glass: VBoxContainer
var _status: Label
var _dose: SpinBox
var _flow: SpinBox
var _layered: CheckButton
var _vessel: OptionButton


func _ready() -> void:
	theme = load("res://scenes/ui/prototype_theme.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.045, 0.05, 0.055)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	_label(column, "[TEST] ЛАБОРАТОРИЯ НАПИТКОВ", 26)
	_label(column, "Выберите дозу и темп. Для слоя включите «Слоем» и наливайте лёгкий компонент поверх плотного.")
	if not _catalog.load_file(DATA):
		_label(column, "Ошибка каталога: " + str(_catalog.validation_errors))
		return
	var settings := HBoxContainer.new()
	settings.add_theme_constant_override("separation", 16)
	column.add_child(settings)
	_vessel = OptionButton.new()
	for id in _catalog.get_vessel_ids():
		_vessel.add_item(_catalog.get_vessel(StringName(id)).title)
		_vessel.set_item_metadata(_vessel.item_count - 1, id)
	settings.add_child(_vessel)
	_vessel.item_selected.connect(func(_index: int) -> void: _new_cup())
	_label(settings, "Доза, мл")
	_dose = _spin(settings, "Dose", 1, 60, 10)
	_label(settings, "Темп, мл/с")
	_flow = _spin(settings, "Flow", 1, 100, 5)
	_layered = CheckButton.new()
	_layered.text = "Слоем"
	_layered.name = "Layered"
	settings.add_child(_layered)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	column.add_child(body)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 12)
	body.add_child(controls)
	_label(controls, "Налить компонент")
	var ingredients := GridContainer.new()
	ingredients.columns = 2
	controls.add_child(ingredients)
	for id in _catalog.get_ingredient_ids():
		var item := _catalog.get_ingredient(StringName(id))
		_button(ingredients, "Pour_" + id, str(item.title).trim_prefix("[TEST] "), func() -> void: _pour(StringName(id)))
	_label(controls, "Обработка стакана")
	var actions := GridContainer.new()
	actions.columns = 2
	controls.add_child(actions)
	_button(actions, "Stir", "Перемешать", func() -> void: _show(preparation.mix(_next(), &"stir")))
	_button(actions, "Shake", "Встряхнуть", func() -> void: _show(preparation.mix(_next(), &"shake")))
	_button(actions, "Settle", "Дать отстояться", func() -> void: _show(preparation.settle(_next())))
	_button(actions, "Discard", "Слить выбранную дозу", func() -> void: _show(preparation.discard(_next(), _dose.value)))
	_button(actions, "Seal", "Зафиксировать результат", func() -> void: _show(not preparation.seal(_next()).is_empty()))
	_button(actions, "NewCup", "Новый стакан", _new_cup)
	var vessel_view := VBoxContainer.new()
	vessel_view.custom_minimum_size.x = 300
	body.add_child(vessel_view)
	_label(vessel_view, "СТАКАН · СЛОИ СНИЗУ ВВЕРХ")
	_glass = VBoxContainer.new()
	_glass.add_theme_constant_override("separation", 0)
	vessel_view.add_child(_glass)
	_status = _label(column, "")
	_status.name = "Status"
	_new_cup()


func _label(parent: Node, value: String, font_size: int = 18) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_OFF if parent is HBoxContainer else TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _spin(parent: Node, node_name: String, low: float, high: float, value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.name = node_name
	spin.min_value = low
	spin.max_value = high
	spin.value = value
	parent.add_child(spin)
	return spin


func _button(parent: Node, node_name: String, title: String, action: Callable) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = title
	button.custom_minimum_size = Vector2(200, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)


func _next() -> StringName:
	_command += 1
	return StringName("action_%d" % _command)


func _new_cup() -> void:
	_serial += 1
	preparation = DrinkPreparation.new()
	_show(preparation.configure(_catalog, StringName(_vessel.get_item_metadata(_vessel.selected)), StringName("lab_cup_%d" % _serial)))


func _pour(id: StringName) -> void:
	_show(preparation.pour(_next(), id, _dose.value, _flow.value, _layered.button_pressed))


func _show(accepted: bool) -> void:
	for child in _glass.get_children():
		_glass.remove_child(child)
		child.queue_free()
	var state := preparation.get_snapshot()
	var height := 320.0
	var empty := ColorRect.new()
	empty.color = Color(0.12, 0.13, 0.14)
	empty.custom_minimum_size.y = maxf(0, height * (1.0 - preparation.get_volume_ml() / float(state.vessel.capacity_ml)))
	_glass.add_child(empty)
	for index in range(state.layers.size() - 1, -1, -1):
		var layer: Dictionary = state.layers[index]
		var rectangle := ColorRect.new()
		rectangle.color = Color(layer.color[0], layer.color[1], layer.color[2], 1)
		rectangle.custom_minimum_size.y = height * float(layer.volume_ml) / float(state.vessel.capacity_ml)
		_glass.add_child(rectangle)
		if rectangle.custom_minimum_size.y >= 24:
			var label := _label(rectangle, "%.1f мл · плотность %.2f" % [layer.volume_ml, layer.density])
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 5)
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var titles := {"empty": "пусто", "homogeneous": "однородная смесь", "layered": "слои", "emulsified": "эмульсия"}
	_status.text = "%s · %.1f / %.1f мл · %s · слоёв: %d\n%s" % ["Действие выполнено" if accepted else "Действие отклонено", preparation.get_volume_ml(), state.vessel.capacity_ml, titles[state.structure], state.layers.size(), "Результат зафиксирован. Для новой порции выберите новый стакан." if state.sealed else "TEST-стенд. Рецепты, барная подача и реакции подключаются следующими этапами."]
