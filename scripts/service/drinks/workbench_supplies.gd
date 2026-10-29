extends Node3D
var main: Node
var bench: DrinkWorkbench
var carrier: Node
var bottle_homes: Dictionary = {}
var bottle_nodes: Dictionary = {}
const TARGET = preload("res://scripts/service/drinks/supply_target.gd")
func configure(owner_main: Node) -> void:
	main = owner_main
	bench = main.get_node("ServicePanel").workbench
	carrier = main.drink_carry
	bench.supplies_required = true
	bench.queue_redraw()
	bench.bottle_cap_changed.connect(_sync_bottle_cap)
	var back := main.get_node("BackCounter") as Node3D
	# Убрать прежний декор посуды; стол и физические опоры остаются.
	for child in back.get_children():
		if child is MeshInstance3D and child.name not in ["Top", "Cabinet"]: child.hide()
	back.add_child(self)
	for index in 2:
		var drawer = _target("Посуда" if index == 0 else "Инструменты", "Откройте ящик и возьмите один предмет", Vector3(0.31, 0.62, -0.7 + index * 1.4), Vector3(0.08, 0.35, 1.15))
		drawer.drawer = true
		_box(drawer, Vector3.ZERO, Vector3(0.05, 0.34, 1.15), Color(0.20,0.22,0.19))
		_box(drawer, Vector3(0.045,0,0), Vector3(0.04,0.035,0.3), Color(0.4,0.4,0.33))
		drawer.contents = Node3D.new()
		drawer.add_child(drawer.contents)
		_box(drawer.contents, Vector3(0.25,-0.1,0), Vector3(0.5,0.04,1.12), Color(0.12,0.13,0.1))
		for side in [-0.55, 0.55]:
			_box(drawer.contents, Vector3(0.25,0,side), Vector3(0.5,0.20,0.035), Color(0.18,0.19,0.15))
		var ids := ["test_shot", "test_glass"] if index == 0 else ["spoon", "shaker", "mixing", "ice"]
		var titles := ["Рюмка", "Стакан"] if index == 0 else ["Ложка", "Шейкер", "Смесительный стакан", "Лёд"]
		for n in ids.size():
			var descriptions := ["Небольшая посуда для подачи", "Высокий стакан для подачи"] if index == 0 else ["Помешивание и послойный налив", "Смешивание встряхиванием", "Смешивание ложкой и перелив", "Охлаждение и разбавление напитка"]
			var item = _target(titles[n], descriptions[n], Vector3(0.25,0.01,-0.4 + n * 0.25), Vector3(0.13,0.22,0.18), drawer.contents)
			item.supply_id = StringName(ids[n])
			if ids[n] == "spoon":
				_box(item, Vector3.ZERO, Vector3(0.025,0.015,0.18), Color(0.6,0.62,0.55))
			else: _cylinder(item, 0.045, 0.16 if ids[n] != "test_shot" else 0.08, Color(0.45,0.53,0.46))
			if ids[n] in ["test_shot", "test_glass", "mixing"]:
				var rim := MeshInstance3D.new()
				var torus := TorusMesh.new(); torus.inner_radius=0.04; torus.outer_radius=0.047
				rim.mesh=torus; rim.position.y=0.04 if ids[n]=="test_shot" else 0.08
				item.add_child(rim)
			item.collision_layer = 0
		drawer.contents.hide()
	if not main.reference_bar_enabled:
		_box(self, Vector3(-0.08,1.65,0), Vector3(0.45,0.055,3.0), Color(0.19,0.16,0.11))
	var shelf_root := Node3D.new()
	add_child(shelf_root)
	var shelf = _target("Полка бутылок", "Верните сюда бутылку из рабочей зоны", Vector3(0.12,1.67,0), Vector3(0.40,0.10,3.0), shelf_root)
	shelf.return_slot = true
	if main.reference_bar_enabled:
		shelf.position = to_local(Vector3(-0.25,1.45,-3.55))
		(shelf.get_child(0).shape as BoxShape3D).size = Vector3(0.38,0.09,5.0)
	for index in bench._ids.size():
		var id := StringName(bench._ids[index])
		var data: Dictionary = bench._catalog.get_ingredient(id)
		var item = _target(str(data.title).trim_prefix("[TEST] "), "Бутылка · 500 мл. Перенесите на стол", Vector3(0.02,1.82,-1.2 + index * 0.36), Vector3(0.12,0.29,0.16))
		if main.reference_bar_enabled:
			var column := index % 4
			var row := index / 4
			var x := -1.60 + column * 0.90
			item.position = to_local(Vector3(x,1.55 + row * 0.65,-3.58))
		item.supply_id = id
		bottle_homes[id] = item.transform
		bottle_nodes[id] = item
		if id == SmallBottleVisual.ID:
			item.context_description = "Бутылка · 250 мл. Перенесите на стол"
			var visual := SmallBottleVisual.new()
			visual.name = "BottleVisual"
			item.add_child(visual)
			visual.position.y = -0.01
			visual.set_capped(bench.is_bottle_capped(id))
			continue
		_cylinder(item,0.047,0.22,Color(data.color[0],data.color[1],data.color[2]))
		var neck := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius=0.018; mesh.bottom_radius=0.018; mesh.height=0.08
		neck.mesh=mesh; neck.position.y=0.14; item.add_child(neck)
func _target(title: String, description: String, at: Vector3, dimensions: Vector3, parent: Node = self) -> Area3D:
	var target = TARGET.new()
	target.store=self; target.context_title=title; target.context_description=description; target.context_anchor=target
	target.position=at; target.collision_layer=2; target.collision_mask=0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size=dimensions; collision.shape=shape; target.add_child(collision)
	parent.add_child(target)
	return target

func _sync_bottle_cap(id: StringName, capped: bool) -> void:
	if bottle_nodes.has(id):
		var visual := bottle_nodes[id].get_node_or_null("BottleVisual") as SmallBottleVisual
		if visual != null: visual.set_capped(capped)
func _box(parent: Node, at: Vector3, dimensions: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size=dimensions; node.mesh=mesh
	var material := StandardMaterial3D.new(); material.albedo_color=color; material.roughness=0.9
	node.material_override=material; node.position=at; parent.add_child(node)
func _cylinder(parent: Node, radius: float, height: float, color: Color) -> void:
	var node := MeshInstance3D.new(); var mesh := CylinderMesh.new()
	mesh.top_radius=radius; mesh.bottom_radius=radius*0.85; mesh.height=height; mesh.radial_segments=10; node.mesh=mesh
	var material := StandardMaterial3D.new(); material.albedo_color=color; material.roughness=0.8; node.material_override=material; parent.add_child(node)
func available(target: Node3D) -> bool:
	if target.return_slot:
		return carrier.holding and carrier.portion == null and bottle_nodes.has(carrier.item.supply_id) and main.get_node("NarrativeSession").mode in [NarrativeSession.EXPLORATION, NarrativeSession.DIALOGUE] and carrier.camera.global_position.distance_to(target.global_position) < 2.5
	return main.get_node("NarrativeSession").mode in [NarrativeSession.EXPLORATION, NarrativeSession.DIALOGUE] and carrier.camera.global_position.distance_to(target.global_position) < 2.5 and (target.drawer or not is_instance_valid(carrier.item))
func take(target: Interactable3D) -> void:
	if is_instance_valid(carrier.item) or not available(target): return
	target.reparent(main, true)
	target.global_basis = target.global_basis.orthonormalized()
	carrier.item=target
	carrier.portion=null
	if carrier.pick_up() and bottle_nodes.has(target.supply_id):
		bench.remove_bottle(target.supply_id)
func deposit() -> bool:
	if not carrier.holding or carrier.portion != null: return false
	var id: StringName = carrier.item.supply_id
	if not bench.add_supply(id): return false
	if bottle_nodes.has(id):
		var bottle = carrier.item
		bottle.reparent(self, true)
		bottle.transform = bottle_homes[id]
		bottle.position = Vector3(-0.10,1.24,-1.1 + bench._ids.find(str(id)) * 0.36)
		if main.reference_bar_enabled:
			bottle.global_position = Vector3(-1.45 + bench._ids.find(str(id)) * 0.38,1.08,-1.85)
		_release_bottle(bottle)
	else:
		carrier.consume()
	return true

func _release_bottle(bottle: Interactable3D) -> void:
	bottle.set_held(false)
	carrier.item = null
	carrier.holding = false
	carrier.portion = null
	carrier.changed.emit()

func return_bottle() -> bool:
	if not carrier.holding or carrier.portion != null or not bottle_nodes.has(carrier.item.supply_id): return false
	var bottle = carrier.item
	bench.remove_bottle(bottle.supply_id)
	bottle.reparent(self, true)
	bottle.transform = bottle_homes[bottle.supply_id]
	_release_bottle(bottle)
	return true
