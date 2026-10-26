class_name CommutePanel
extends CanvasLayer

signal arrived(trip_id: int)
signal work_requested
signal journal_requested

@export_range(0.1, 10.0) var travel_seconds: float = 3.0
var progress: float = 0.0:
	set(value):
		progress = value
		if is_node_ready():
			$Screen/Backdrop.progress = value
			$Screen/Backdrop.queue_redraw()
			%Progress.value = value

var _trip_id: int = 0
var _active: bool = false
var _tween: Tween


func _ready() -> void:
	%Skip.pressed.connect(_finish)
	%Work.pressed.connect(func() -> void: work_requested.emit())
	%Journal.pressed.connect(func() -> void: journal_requested.emit())


func begin_trip(id: int, to_home: bool) -> void:
	stop_trip()
	_trip_id = id
	_active = true
	progress = 0.0
	$Screen/Backdrop.at_home = false
	$Screen/Backdrop.to_home = to_home
	%Title.text = "ДОРОГА ДОМОЙ" if to_home else "ДОРОГА НА РАБОТУ"
	%Caption.text = "[TEST] Переход между сменами"
	%Skip.visible = true
	%Skip.disabled = false
	%HomeActions.visible = false
	%Progress.visible = true
	_tween = create_tween()
	_tween.tween_property(self, "progress", 1.0, travel_seconds)
	_tween.tween_callback(_finish)


func show_home() -> void:
	stop_trip()
	$Screen/Backdrop.at_home = true
	$Screen/Backdrop.queue_redraw()
	%Title.text = "МЕЖДУ СМЕНАМИ"
	%Caption.text = "[TEST] Дома · можно перечитать дневник"
	%Skip.visible = false
	%Progress.visible = false
	%HomeActions.visible = true


func stop_trip() -> void:
	_active = false
	if _tween != null and _tween.is_valid():
		_tween.kill()


func set_open(value: bool, travelling: bool, interactive: bool = true) -> void:
	$Screen.visible = value
	%Title.visible = interactive
	%Caption.visible = interactive
	%Actions.visible = interactive
	if _tween != null and _tween.is_valid():
		if value and travelling:
			_tween.play()
		else:
			_tween.pause()
	if value and interactive:
		_focus_action.call_deferred()


func _focus_action() -> void:
	if is_inside_tree() and $Screen.is_visible_in_tree():
		if _active:
			%Skip.grab_focus()
		elif %HomeActions.visible:
			%Work.grab_focus()


func _finish() -> void:
	if not _active or not $Screen.is_visible_in_tree():
		return
	_active = false
	%Skip.disabled = true
	arrived.emit(_trip_id)
