extends Label
## Точка плавно раскрывается в кольцо только у доступной цели.
var amount: float = 0.0
@onready var interaction: InteractionController = get_node_or_null("../../../InteractionController")
func _ready() -> void:
	text = ""
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		amount = 0.0
		return
	var target: Interactable3D = interaction.get_target() if is_instance_valid(interaction) else null
	var active := is_instance_valid(target) and target.is_available() and not target.context_passive
	amount = lerpf(amount, 1.0 if active else 0.0, 1.0 - exp(-delta / 0.12))
	queue_redraw()
func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, 1.8, Color(0.94, 0.91, 0.81, 0.8 * (1.0 - amount)))
	draw_arc(center, lerpf(2.0, 6.0, amount), 0, TAU, 40, Color(0.94, 0.91, 0.81, 0.85 * amount), 1.4, true)
