class_name BottleCapItem
extends Control
## Независимая крышка: остаётся на столе, переносится мышью, кликом возвращается к бутылке.

signal return_requested
signal motion_finished(attached: bool)
const DURATION := 0.26
const DIMENSIONS := Vector2(29, 29)
var texture: Texture2D
var logical_position := Vector2.ZERO
var detached: bool = false
var animating: bool = false
var returning: bool = false
var _elapsed: float = 0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _view_origin := Vector2.ZERO
var _view_scale: float = 1
var _pressed: bool = false
var _moving: bool = false
var _press_point := Vector2.ZERO
var _grab_position := Vector2.ZERO
var input_enabled: bool = true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

func set_view(origin: Vector2, scale_value: float) -> void:
	_view_origin = origin
	_view_scale = scale_value
	_sync()

func logical_rect() -> Rect2:
	return Rect2(logical_position, DIMENSIONS)

func start_motion(from: Vector2, to: Vector2, attach: bool) -> void:
	_from = from
	_to = to
	returning = attach
	_elapsed = 0
	animating = true
	detached = true
	logical_position = from
	show()
	_sync()

func advance(delta: float) -> void:
	if not animating or not is_finite(delta) or delta <= 0: return
	_elapsed = minf(DURATION, _elapsed + delta)
	var t := _elapsed / DURATION
	var eased := t * t * (3.0 - 2.0 * t)
	# Короткая дуга: при снятии сначала поднимается, при возврате опускается на горлышко.
	logical_position = _from.lerp(_to, eased) + Vector2(0, -sin(PI * eased) * 24)
	_sync()
	if _elapsed >= DURATION:
		animating = false
		detached = not returning
		visible = detached
		motion_finished.emit(returning)

func cancel_drag() -> void:
	_pressed = false
	_moving = false

func _sync() -> void:
	position = _view_origin + logical_position * _view_scale
	size = DIMENSIONS * _view_scale
	queue_redraw()

func _draw() -> void:
	if texture == null: return
	if not animating:
		draw_set_transform(Vector2(size.x * 0.5, size.y - 4 * _view_scale), 0, Vector2(10, 2) * _view_scale)
		draw_circle(Vector2.ZERO, 1, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO)
	draw_texture_rect(texture, Rect2(Vector2.ONE * 2 * _view_scale, size - Vector2.ONE * 4 * _view_scale), false)

func _gui_input(event: InputEvent) -> void:
	if not input_enabled or animating: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_moving = false
			_press_point = event.global_position
			_grab_position = logical_position
		elif _pressed:
			_pressed = false
			if not _moving: return_requested.emit()
			_moving = false
		accept_event()
	elif event is InputEventMouseMotion and _pressed:
		var travel: Vector2 = (event.global_position - _press_point) / _view_scale
		_moving = _moving or travel.length() > 5
		if _moving:
			logical_position = (_grab_position + travel).clamp(Vector2(16, 165), Vector2(1235, 600))
			_sync()
		accept_event()
