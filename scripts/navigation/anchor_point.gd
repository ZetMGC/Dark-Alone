class_name AnchorPoint
extends Interactable3D
## Глобальная поза этого узла — поза камеры; связи направленные.

signal move_requested(anchor_id: StringName)

@export var anchor_id: StringName
@export var display_name: String = "Якорь"
@export var neighbours: PackedStringArray = []

var _available: bool = false

@onready var _marker: Node3D = $Marker
@onready var _label: Label3D = $Marker/Label


func _ready() -> void:
	_label.text = display_name
	set_available(false)


func set_available(value: bool) -> void:
	_available = value
	if is_node_ready():
		_marker.visible = value
	# Недоступная цель не перекрывает луч к другим точкам.
	set_collision_layer_value(2, value)


func is_available() -> bool:
	return _available


func get_prompt() -> String:
	return "E — подойти: " + display_name


func interact() -> void:
	if is_available():
		move_requested.emit(anchor_id)
