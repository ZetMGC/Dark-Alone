class_name HomeExploration
extends Node3D
## Отдельная локация и UI; не управляет прогрессом смены или каноном.

signal work_requested
signal journal_requested
var state := HomeState.new()
var _session: NarrativeSession
var _bar_hud: NavigationHUD
var _at_home: bool = false
var _inspection: StringName = &""
var _event: StringName = &""

@onready var rig: AnchorCamera = $AnchorCamera
@onready var interaction: InteractionController = $InteractionController


func configure(session: NarrativeSession, hud: NavigationHUD, shared_state: HomeState = null, free_roam: bool = false) -> bool:
	if _session != null or session == null or hud == null:
		return false
	(rig as FreeRoamCamera).free_roam_enabled = free_roam
	(rig as FreeRoamCamera).availability_changed.connect(_refresh)
	if not rig.configure($Anchors, &"home_entry"):
		return false
	_session = session
	_bar_hud = hud
	if shared_state != null:
		state = shared_state
	state.changed.connect(_refresh)
	interaction.configure(rig.view)
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
	return _inspection != &"" or _event != &""


func _refresh() -> void:
	if _session == null:
		return
	var enabled := _at_home and _session.mode == NarrativeSession.HOME and not _has_inspection()
	rig.set_controls_enabled(enabled)
	interaction.set_enabled(enabled and not rig.is_transitioning)
	var anchors := rig.get_anchors()
	for index in anchors.size():
		anchors[index].set_available(rig.can_move_to(anchors[index].anchor_id))
		(%Destinations.get_child(index) as Button).disabled = not rig.can_move_to(anchors[index].anchor_id)
	for object: HomeObject in $Objects.get_children():
		object.set_available(enabled and not rig.is_transitioning and rig.current_anchor_id == object.required_anchor)
	var anchor := rig.get_anchor(rig.current_anchor_id)
	%Location.text = "ДОМ · " + anchor.display_name if anchor != null else "ДОМ"
	%Observed.text = "[TEST] Осмотрено: %d / 4" % state.get_observed_ids().size()
	%Work.disabled = not enabled or rig.is_transitioning or rig.current_anchor_id != &"home_entry"
	%Work.tooltip_text = "Вернитесь к двери (1), чтобы выйти на работу."
	%Event.visible = not state.get_available_events().is_empty()
	%Event.disabled = not enabled or rig.is_transitioning
	%Journal.disabled = not enabled or rig.is_transitioning
	%InspectCurrent.disabled = not enabled or rig.is_transitioning
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
		%Prompt.visible = not focused and not _has_inspection()
		%MovementHint.visible = not focused and not _has_inspection()


func _move(id: StringName) -> void:
	if _session.mode == NarrativeSession.HOME and not _has_inspection():
		rig.request_move(id)


func inspect(id: StringName) -> bool:
	if _session.mode != NarrativeSession.HOME or rig.is_transitioning or _has_inspection():
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
	if _session.mode != NarrativeSession.HOME or rig.is_transitioning or _has_inspection():
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
	%Read.text = "Завершить событие" if _event != &"" else "Завершить осмотр"
	%DescriptionScroll.scroll_vertical = 0
	_refresh()
	%Cancel.grab_focus.call_deferred()


func close_inspection(commit: bool) -> bool:
	if _session.mode != NarrativeSession.HOME or not _has_inspection():
		return false
	if commit:
		if _inspection != &"":
			state.observe(_inspection)
		else:
			state.resolve_event(_event)
	_inspection = &""
	_event = &""
	%Inspection.hide()
	_refresh()
	return true


func request_work() -> bool:
	if _session.mode != NarrativeSession.HOME or _has_inspection() or rig.is_transitioning or rig.current_anchor_id != &"home_entry":
		return false
	work_requested.emit()
	return true


func handle_input(event: InputEvent) -> bool:
	if _session == null or _session.mode != NarrativeSession.HOME or event.is_echo():
		return false
	if event.is_action_pressed("toggle_menu") and _has_inspection():
		close_inspection(false)
		return true
	if event.is_action_pressed("toggle_menu") and (rig as FreeRoamCamera).leave_focus():
		return true
	if event.is_action_pressed("interact"):
		if not _has_inspection():
			if not (rig as FreeRoamCamera).try_focus():
				interaction.try_interact()
		return true
	if (rig as FreeRoamCamera).free_roam_enabled:
		return false
	for index in rig.get_anchors().size():
		if event.is_action_pressed("anchor_%d" % [index + 1]):
			_move(rig.get_anchors()[index].anchor_id)
			return true
	return false
