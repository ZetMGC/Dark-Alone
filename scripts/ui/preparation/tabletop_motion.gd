class_name TabletopMotion
extends RefCounted
## Небольшая 2.5D-модель: положение на столе, высота, вращение, инерция и трение.
const TABLE := Rect2(20, 380, 1240, 250)
var half_size := Vector2(34, 76.5)
var mass: float = 0.7
var ground := Vector2(400, 500)
var elevation: float = 0
var velocity := Vector2.ZERO
var vertical_speed: float = 0
var angle: float = 0
var spin: float = 0
var active: bool = false
var restoring: bool = false
var is_cap: bool = false
var _target_angle: float = 0
var _restore_from: float = 0
var _restore_time: float = 0
var _restore_height: float = 0

func support() -> float:
	return absf(cos(angle)) * half_size.y + absf(sin(angle)) * half_size.x

func center() -> Vector2:
	return ground - Vector2(0, support() + elevation)

func pose() -> Transform2D:
	return Transform2D(angle, center())

func origin() -> Vector2:
	return pose() * Vector2(0, -half_size.y)

func release(at: Vector2, radians: float, cursor_velocity: Vector2, weight: float) -> void:
	mass = maxf(0.008, weight)
	angle = radians
	var visual_center := at + Vector2(0, half_size.y).rotated(angle)
	var bottom := visual_center.y + support()
	ground = Vector2(visual_center.x, clampf(bottom, TABLE.position.y + 8, TABLE.end.y - 5))
	elevation = maxf(0, ground.y - bottom)
	var response := clampf(sqrt(0.55 / mass), 0.55, 1.7)
	velocity = cursor_velocity.limit_length(1400) * 0.40 * response
	vertical_speed = minf(180, cursor_velocity.length() * 0.10 * response)
	var direction := signf(cursor_velocity.x) if absf(cursor_velocity.x) > 20 else (signf(angle) if absf(angle) > 0.05 else 1.0)
	var falls := cursor_velocity.length() > 190 or absf(angle) > 0.40
	_target_angle = direction * PI / 2 if falls and not is_cap else 0.0
	spin = direction * minf(7, cursor_velocity.length() * 0.006 * response) if falls else 0.0
	active = true
	restoring = false

func stand_up() -> void:
	_target_angle = 0
	_restore_from = angle
	_restore_time = 0
	_restore_height = elevation
	restoring = true
	active = true
	velocity = Vector2.ZERO
	vertical_speed = 0
	spin = 0

func advance(delta: float) -> void:
	if not active or not is_finite(delta) or delta <= 0: return
	var remaining := minf(delta, 0.25)
	while remaining > 0.00001:
		var dt := minf(remaining, 1.0 / 120.0)
		remaining -= dt
		if restoring:
			_restore_time = minf(0.24, _restore_time + dt)
			var t := _restore_time / 0.24
			var eased := t * t * (3 - 2 * t)
			angle = lerpf(_restore_from, 0, eased)
			elevation = lerpf(_restore_height, 0, eased)
			if t >= 1:
				restoring = false
				active = false
		else:
			ground += velocity * dt
			vertical_speed -= 850 * dt
			elevation += vertical_speed * dt
			if elevation <= 0:
				elevation = 0
				vertical_speed = -vertical_speed * (0.28 if is_cap else 0.13) if vertical_speed < -60 else 0.0
				velocity = velocity.move_toward(Vector2.ZERO, (310 if is_cap else 520) * dt)
			else:
				velocity *= exp(-0.65 * dt)
			if is_cap:
				angle += spin * dt
				spin *= exp(-(6.0 if elevation == 0 else 1.5) * dt)
			else:
				spin += ((_target_angle - angle) * 52 - spin * 11) * dt
				angle += spin * dt
			if velocity.length() < 0.5 and elevation == 0 and absf(vertical_speed) < 1 and absf(spin) < 0.01 and (is_cap or absf(angle - _target_angle) < 0.002):
				active = false
		var extent := absf(cos(angle)) * half_size.x + absf(sin(angle)) * half_size.y
		var minimum := Vector2(TABLE.position.x + extent, TABLE.position.y + (support() * 2 if is_cap else absf(sin(angle)) * half_size.x * 2) + 3)
		var maximum := Vector2(TABLE.end.x - extent, TABLE.end.y - 3)
		var bounded := ground.clamp(minimum, maximum)
		if not ground.is_equal_approx(bounded):
			# Ограничение мягко возвращает предмет из пограничной позы, без скачка.
			if ground.x != bounded.x: velocity.x = -velocity.x * 0.22
			if ground.y != bounded.y: velocity.y = -velocity.y * 0.22
			ground = ground.move_toward(bounded, 700 * dt)
			active = true

static func shadow(canvas: CanvasItem, view: Transform2D, at: Vector2, dimensions: Vector2, rotation: float, height: float, opacity: float) -> void:
	var softness := clampf(height / 100.0, 0, 1.8)
	for layer in range(5, 0, -1):
		var spread := 1.0 + layer * (0.10 + softness * 0.07)
		var axes := dimensions * spread * (1 + softness * 0.18)
		canvas.draw_set_transform_matrix(view * Transform2D(rotation, axes, 0, at + Vector2(height * 0.12, height * 0.04)))
		canvas.draw_circle(Vector2.ZERO, 1, Color(0.015, 0.02, 0.015, opacity / 5.0 / (1 + softness)))
