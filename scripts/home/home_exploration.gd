class_name HomeExploration
extends Node3D
## Отдельная локация и UI; не управляет прогрессом смены или каноном.

signal work_requested
signal journal_requested
const SURFACE_TARGET = preload("res://scripts/home/targets/home_surface_target.gd")
const SURFACES := {
	"Desk": ["Desk", "DeskLegLeft", "DeskLegRight", "Book"],
	"Window": ["Window", "WindowBar"],
	"Bed": ["BedFrame", "Mattress", "Pillow"],
	"Door": ["Door"],
}
var state := HomeState.new()
var _session: NarrativeSession
var _bar_hud: NavigationHUD
var _at_home: bool = false
var _inspection: StringName = &""
var _event: StringName = &""
var house: Node3D
var _house_inspection: bool = false
var _feedback: Label
var _feedback_remaining: float = 0

@onready var rig: AnchorCamera = $AnchorCamera
@onready var interaction: InteractionController = $InteractionController


func configure(session: NarrativeSession, hud: NavigationHUD, shared_state: HomeState = null, free_roam: bool = false) -> bool:
	if _session != null or session == null or hud == null:
		return false
	(rig as FreeRoamCamera).free_roam_enabled = free_roam
	if free_roam:
		house = (load("res://scenes/home/house_interior.tscn") as PackedScene).instantiate()
		add_child(house)
		house.build(self)
		_feedback = Label.new()
		_feedback.name = "HouseFeedback"
		_feedback.position = Vector2(24, 76)
		_feedback.add_theme_font_size_override("font_size", 18)
		_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$HomeHUD/Screen.add_child(_feedback)
	(rig as FreeRoamCamera).availability_changed.connect(_refresh)
	if not rig.configure($Anchors, &"home_entry"):
		return false
	_session = session
	_bar_hud = hud
	if shared_state != null:
		state = shared_state
	state.changed.connect(_refresh)
	interaction.configure(rig.view)
	if free_roam and not _configure_surfaces():
		return false
	interaction.prompt_changed.connect(func(text: String) -> void: %Prompt.text = text)
	rig.transition_started.connect(func(_from: StringName, _to: StringName) -> void: _refresh())
	rig.anchor_reached.connect(func(_id: StringName) -> void: _refresh())
	for anchor in rig.get_anchors():
		anchor.move_requested.connect(_move)
		var button := Button.new()
		button.text = "%d · %s" % [%Destinations.get_child_count() + 1, anchor.display_name]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 44
		button.pressed.connect(_move.bind(anchor.anchor_id))
		%Destinations.add_child(button)
	for object: HomeObject in $Objects.get_children():
		object.inspect_requested.connect(inspect)
	%Read.pressed.connect(func() -> void: close_inspection(true))
	%Cancel.pressed.connect(func() -> void: close_inspection(false))
	%LeaveWorkstation.pressed.connect(func() -> void:
		if _session.mode == NarrativeSession.HOME and not _has_inspection():
			(rig as FreeRoamCamera).leave_focus()
	)
	%Journal.pressed.connect(func() -> void: journal_requested.emit())
	%Work.pressed.connect(request_work)
	%Event.pressed.connect(open_event)
	%InspectCurrent.pressed.connect(func() -> void:
		for object: HomeObject in $Objects.get_children():
			if object.required_anchor == rig.current_anchor_id:
				inspect(object.object_id)
	)
	_session.mode_changed.connect(set_context)
	set_context(_session.mode)
	return true


func set_context(mode: StringName) -> void:
	if mode == NarrativeSession.HOME:
		_at_home = true
		rig.apply_preferences()
	elif mode in [NarrativeSession.EXPLORATION, NarrativeSession.TRAVEL, NarrativeSession.SHIFT_COMPLETE]:
		_at_home = false
		_inspection = &""
		_event = &""
		_house_inspection = false
	visible = _at_home
	if _at_home:
		rig.view.make_current()
	var home_input := _at_home and mode == NarrativeSession.HOME
	$HomeHUD/Screen.visible = home_input
	%Inspection.visible = home_input and _has_inspection()
	# Меню бара остаётся общим; его фоновые кнопки дома не показываются.
	for control: Control in _bar_hud.get_node("Screen").get_children():
		if control.name != "Menu":
			control.visible = not _at_home
	_refresh()
	if %Inspection.visible:
		%Cancel.grab_focus.call_deferred()


func _has_inspection() -> bool:
	return _inspection != &"" or _event != &"" or _house_inspection


func house_actions_allowed() -> bool:
	return _world_enabled() and not (rig as FreeRoamCamera).focus_active


func show_house_inspection(title: String, text: String) -> void:
	if not house_actions_allowed():
		return
	_house_inspection = true
	%InspectionTitle.text = title
	%Description.text = text
	_show_inspection()


func house_feedback(text: String) -> void:
	if is_instance_valid(_feedback):
		_feedback.text = text
		_feedback_remaining = 4.0


func _world_enabled() -> bool:
	return _session != null and _at_home and _session.mode == NarrativeSession.HOME and not _has_inspection() and not rig.is_transitioning and rig.view.is_current()


func _process(_delta: float) -> void:
	if _session == null or not (rig as FreeRoamCamera).free_roam_enabled:
		return
	interaction.set_enabled(_world_enabled())
	if house != null:
		var presentation := get_parent().get_node_or_null("Presentation") as PresentationController
		house.tick(_delta, _world_enabled(), presentation.get_ambience_gain() if presentation != null else 0.0)
		$HomeHUD/Screen/Heading.text = "ДОМ · " + house.room_at(to_local(rig.view.global_position))
		if _feedback_remaining > 0 and _world_enabled():
			_feedback_remaining = maxf(0, _feedback_remaining - _delta)
		_feedback.visible = _feedback_remaining > 0
	if interaction.pointer_mode:
		%Prompt.position = (get_viewport().get_mouse_position() + Vector2(16, 20)).clamp(Vector2.ZERO, get_viewport().get_visible_rect().size - %Prompt.size)


func _configure_surfaces() -> bool:
	interaction.reach = 3.0
	# Прежний вход смотрел в комнату: в локальном ракурсе дверь должна быть видна.
	rig.get_anchor(&"home_entry").rotation_degrees = Vector3(0, 180, 0)
	for object_name: String in SURFACES:
		var object := get_node_or_null("Objects/" + object_name) as HomeObject
		if object == null or rig.get_anchor(object.required_anchor) == null:
			push_error("Home: неверный предмет/ракурс " + object_name)
			return false
		var target := SURFACE_TARGET.new()
		target.name = object_name + "SurfaceTarget"
		target.collision_layer = 0
		target.collision_mask = 0
		target.monitoring = false
		target.rig = rig
		target.object = object
		target.context_allowed = _world_enabled
		add_child(target)
		target.activated.connect(_use_surface.bind(object))
		for part: String in SURFACES[object_name]:
			var body := get_node_or_null("Geometry/" + part + "/Body") as CollisionObject3D
			if not interaction.register_surface(body, target):
				push_error("Home: отсутствует коллизия Geometry/" + part + "/Body")
				return false
	return true


func _use_surface(object: HomeObject) -> void:
	if not _world_enabled():
		return
	if (rig as FreeRoamCamera).focus_active:
		if rig.current_anchor_id == object.required_anchor:
			inspect(object.object_id)
	else:
		rig.request_move(object.required_anchor)


func _refresh() -> void:
	if _session == null:
		return
	var enabled := _at_home and _session.mode == NarrativeSession.HOME and not _has_inspection() and rig.view.is_current()
	rig.set_controls_enabled(enabled)
	interaction.set_enabled(enabled and not rig.is_transitioning)
	var walking := (rig as FreeRoamCamera).free_roam_enabled
	interaction.pointer_mode = walking and (rig as FreeRoamCamera).focus_active
	var anchors := rig.get_anchors()
	for index in anchors.size():
		anchors[index].set_available(not walking and rig.can_move_to(anchors[index].anchor_id))
		(%Destinations.get_child(index) as Button).disabled = not rig.can_move_to(anchors[index].anchor_id)
	for object: HomeObject in $Objects.get_children():
		object.set_available(enabled and not rig.is_transitioning and rig.current_anchor_id == object.required_anchor)
		if walking:
			object.collision_layer = 0
	var anchor := rig.get_anchor(rig.current_anchor_id)
	%Location.text = "ДОМ · " + anchor.display_name if anchor != null else "ДОМ"
	%Observed.text = "[TEST] Осмотрено: %d / 4" % state.get_observed_ids().size()
	%Work.disabled = not enabled or rig.is_transitioning or rig.current_anchor_id != &"home_entry"
	%Work.tooltip_text = "Подойдите к двери и нажмите E, чтобы открыть действия у выхода."
	%Event.visible = not state.get_available_events().is_empty()
	%Event.disabled = not enabled or rig.is_transitioning
	%Journal.disabled = not enabled or rig.is_transitioning
	%InspectCurrent.disabled = not enabled or rig.is_transitioning
	%InspectCurrent.visible = not walking or not str(rig.current_anchor_id).begins_with("seat_")
	if (rig as FreeRoamCamera).free_roam_enabled:
		var focused := (rig as FreeRoamCamera).focus_active
		$HomeHUD/Screen/Bottom.visible = focused and not _has_inspection()
		$HomeHUD/Screen/Bottom.offset_top = -178
		%Destinations.hide()
		$HomeHUD/Screen/Bottom/Margin/Content/Help.hide()
		%LeaveWorkstation.visible = focused
		%Work.visible = rig.current_anchor_id == &"home_entry"
		%Event.visible = focused and not state.get_available_events().is_empty()
		$HomeHUD/Screen/Reticle.visible = not focused and not _has_inspection()
		%MovementHint.visible = not focused and not _has_inspection()
		%Prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if focused else HORIZONTAL_ALIGNMENT_CENTER
		if not focused:
			%Prompt.position = get_viewport().get_visible_rect().size * 0.5 + Vector2(-320, 24)
		%Prompt.visible = enabled and not rig.is_transitioning


func _move(id: StringName) -> void:
	if _session.mode == NarrativeSession.HOME and not _has_inspection():
		rig.request_move(id)


func inspect(id: StringName) -> bool:
	if not _world_enabled():
		return false
	for object: HomeObject in $Objects.get_children():
		if object.object_id == id and object.is_available():
			_inspection = id
			%InspectionTitle.text = object.title
			%Description.text = object.description
			_show_inspection()
			return true
	return false


func open_event() -> bool:
	if not _world_enabled():
		return false
	if (rig as FreeRoamCamera).free_roam_enabled and not (rig as FreeRoamCamera).focus_active:
		return false
	var events := state.get_available_events()
	if events.is_empty():
		return false
	_event = events[0].id
	%InspectionTitle.text = events[0].title
	%Description.text = events[0].description
	_show_inspection()
	return true


func _show_inspection() -> void:
	%Inspection.show()
	%Read.text = "Закрыть" if _house_inspection else ("Завершить событие" if _event != &"" else "Завершить осмотр")
	%DescriptionScroll.scroll_vertical = 0
	_refresh()
	%Cancel.grab_focus.call_deferred()


func close_inspection(commit: bool) -> bool:
	if _session.mode != NarrativeSession.HOME or not _has_inspection():
		return false
	if commit:
		if _inspection != &"":
			state.observe(_inspection)
		elif _event != &"":
			state.resolve_event(_event)
	_inspection = &""
	_event = &""
	_house_inspection = false
	%Inspection.hide()
	_refresh()
	return true


func request_work() -> bool:
	if not _world_enabled() or rig.current_anchor_id != &"home_entry":
		return false
	work_requested.emit()
	return true


func handle_input(event: InputEvent) -> bool:
	if _session == null or _session.mode != NarrativeSession.HOME or event.is_echo() or not rig.view.is_current():
		return false
	if event.is_action_pressed("toggle_menu") and _has_inspection():
		close_inspection(false)
		return true
	if event.is_action_pressed("toggle_menu") and (rig as FreeRoamCamera).leave_focus():
		return true
	if event.is_action_pressed("interact"):
		if not _has_inspection():
			interaction.try_interact()
		return true
	if (rig as FreeRoamCamera).free_roam_enabled:
		return false
	for index in rig.get_anchors().size():
		if event.is_action_pressed("anchor_%d" % [index + 1]):
			_move(rig.get_anchors()[index].anchor_id)
			return true
	return false
