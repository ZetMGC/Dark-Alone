extends Node
## Управляемая пружина вместо свободного rigid-body рядом с камерой.
signal changed
const HAND := Vector3(0.28, -0.30, -0.55)
var camera: Camera3D
var session: NarrativeSession
var portion: DrinkPreparation
var item: Interactable3D
var holding: bool = false
var world_parent: Node3D
var home_position := Vector3(-5.46, 1.13, -2.0)
var offset := Vector3.ZERO
var velocity := Vector3.ZERO
var tilt := Vector3.ZERO
var tilt_velocity := Vector3.ZERO
var _previous_basis := Basis.IDENTITY
var _previous_position := Vector3.ZERO
var _pickup_origin := Vector3.ZERO
var _pickup_rotation := Quaternion.IDENTITY
var _pickup_time: float = 0
var _walk_phase: float = 0

func configure(view: Camera3D, narrative: NarrativeSession, root: Node3D) -> void:
	camera = view
	session = narrative
	world_parent = root
	var top := root.get_node_or_null("BackCounter/Top") as Node3D
	home_position = top.to_global(Vector3(0.22, 0.5, 0)) if top != null else root.to_global(home_position)
	_baseline()

func stage(preparation: DrinkPreparation) -> bool:
	if is_instance_valid(item) or preparation == null or preparation.get_volume_ml() <= 0 or not preparation.get_result().is_empty():
		return false
	portion = preparation
	item = preload("res://scripts/service/drinks/world_drink.gd").new()
	item.setup(self, portion)
	world_parent.add_child(item)
	item.global_position = home_position
	changed.emit()
	return true

func can_pick_up() -> bool:
	return not holding and is_instance_valid(item) and session.mode in [NarrativeSession.EXPLORATION, NarrativeSession.DIALOGUE] and camera.global_position.distance_to(item.global_position) <= 2.5

func pick_up() -> bool:
	if not can_pick_up():
		return false
	var world := item.global_transform
	holding = true
	item.set_held(true)
	item.reparent(camera, true)
	changed.emit()
	item.global_transform = world
	_pickup_origin = item.position
	_pickup_rotation = item.quaternion
	_pickup_time = 0
	offset = Vector3.ZERO
	velocity = Vector3.ZERO
	tilt = Vector3.ZERO
	tilt_velocity = Vector3.ZERO
	_baseline()
	return true

func place() -> bool:
	if not holding or not is_instance_valid(item):
		return false
	holding = false
	item.reparent(world_parent, true)
	item.global_transform = Transform3D(Basis.IDENTITY, home_position)
	item.set_held(false)
	changed.emit()
	return true

func consume() -> void:
	if is_instance_valid(item):
		item.queue_free()
	item = null
	portion = null
	holding = false
	changed.emit()

func _baseline() -> void:
	if is_instance_valid(camera):
		_previous_basis = camera.global_basis.orthonormalized()
		_previous_position = camera.global_position

func _process(delta: float) -> void:
	if not holding or not is_instance_valid(item):
		return
	var active := session.mode in [NarrativeSession.EXPLORATION, NarrativeSession.DIALOGUE] and (DisplayServer.get_name() == "headless" or DisplayServer.window_is_focused())
	item.visible = session.mode in [NarrativeSession.EXPLORATION, NarrativeSession.DIALOGUE, NarrativeSession.MENU]
	if not active or delta <= 0 or delta > 0.15:
		_baseline()
		return
	var basis := camera.global_basis.orthonormalized()
	var angular := (_previous_basis.inverse() * basis).get_euler() / maxf(delta, 0.001)
	var movement := basis.inverse() * (camera.global_position - _previous_position) / maxf(delta, 0.001)
	_baseline()
	advance_motion(delta, angular, movement)
	_pickup_time = minf(0.25, _pickup_time + delta)
	var pickup := pow(1.0 - _pickup_time / 0.25, 3)
	item.position = HAND + offset + (_pickup_origin - HAND) * pickup
	item.quaternion = Quaternion.from_euler(tilt).slerp(_pickup_rotation, pickup)

func advance_motion(delta: float, angular: Vector3, movement: Vector3) -> void:
	if not is_finite(delta) or delta <= 0 or not angular.is_finite() or not movement.is_finite():
		return
	var dt := minf(delta, 0.1)
	_walk_phase += minf(movement.length(), 3.0) * dt * 4
	var target := Vector3(angular.y * 0.008, -angular.x * 0.008, 0) - movement * 0.012
	target += Vector3(sin(_walk_phase) * 0.003, cos(_walk_phase * 2) * 0.002, 0) * minf(movement.length(), 1)
	target = target.clamp(Vector3(-0.07, -0.05, -0.04), Vector3(0.07, 0.05, 0.04))
	var rotation_target := Vector3(-angular.x * 0.025, -angular.y * 0.012, -angular.y * 0.025 + movement.x * 0.02).clamp(Vector3.ONE * -0.18, Vector3.ONE * 0.18)
	var steps := maxi(1, ceili(dt * 120))
	for step in steps:
		var h := dt / steps
		velocity += ((target - offset) * 196 - velocity * 23) * h
		offset += velocity * h
		tilt_velocity += ((rotation_target - tilt) * 144 - tilt_velocity * 20) * h
		tilt += tilt_velocity * h
