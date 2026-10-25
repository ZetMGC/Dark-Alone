extends Node3D
## Точка композиции: связывает локацию, камеру, ввод и HUD.

@onready var _rig: AnchorCamera = $AnchorCamera
@onready var _interaction: InteractionController = $InteractionController
@onready var _hud: NavigationHUD = $NavigationHUD
@onready var _anchors_root: Node3D = $BarLevel/Anchors

var _menu_open: bool = false
var _configured: bool = false


func _ready() -> void:
	_hud.resume_requested.connect(_set_menu.bind(false))
	_hud.quit_requested.connect(func() -> void: get_tree().quit())
	if not _rig.configure(_anchors_root, &"entry"):
		_rig.set_controls_enabled(false)
		_hud.show_notice("Ошибка локации: " + "; ".join(_rig.validation_errors))
		push_error("Invalid anchor graph: " + "; ".join(_rig.validation_errors))
		return
	_configured = true
	_interaction.configure(_rig.view)
	_interaction.prompt_changed.connect(_hud.set_prompt)
	_hud.configure(_rig.get_anchors())
	_hud.destination_requested.connect(_request_destination)
	_rig.transition_started.connect(_on_transition_started)
	_rig.anchor_reached.connect(_on_anchor_reached)
	for anchor in _rig.get_anchors():
		anchor.move_requested.connect(_move_to)
	_refresh_navigation()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_menu"):
		_set_menu(not _menu_open)
		get_viewport().set_input_as_handled()
		return
	if not _configured or _menu_open:
		return
	if event.is_action_pressed("interact"):
		if not _interaction.try_interact() and not _rig.is_transitioning:
			_hud.show_notice("Наведите прицел на метку или выберите доступную точку внизу.")
		get_viewport().set_input_as_handled()
	for index in _rig.get_anchors().size():
		if event.is_action_pressed("anchor_%d" % [index + 1]):
			_request_destination(_rig.get_anchors()[index].anchor_id)
			get_viewport().set_input_as_handled()
			return


func _request_destination(anchor_id: StringName) -> void:
	if not _configured or _menu_open:
		return
	if not _interaction.activate(_rig.get_anchor(anchor_id)):
		if _rig.is_transitioning:
			_hud.show_notice("Дождитесь завершения перехода.")
		elif anchor_id == _rig.current_anchor_id:
			_hud.show_notice("Вы уже в этой точке.")
		else:
			_hud.show_notice("Нет прямого перехода. Выберите одну из доступных соседних точек.")


func _move_to(anchor_id: StringName) -> void:
	_rig.request_move(anchor_id)


func _on_transition_started(_from_id: StringName, _to_id: StringName) -> void:
	_refresh_navigation()


func _on_anchor_reached(_anchor_id: StringName) -> void:
	_refresh_navigation()


func _set_menu(open: bool) -> void:
	_menu_open = open
	_rig.set_controls_enabled(not open and _configured)
	_hud.set_menu_visible(open)
	_refresh_navigation()


func _refresh_navigation() -> void:
	if not _configured:
		return
	_interaction.set_enabled(not _menu_open and not _rig.is_transitioning)
	for anchor in _rig.get_anchors():
		anchor.set_available(_rig.can_move_to(anchor.anchor_id))
	_hud.update_navigation(_rig)
