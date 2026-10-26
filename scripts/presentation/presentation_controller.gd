class_name PresentationController
extends CanvasLayer
## Только оформление и настройки восприятия; не хранит игровой прогресс.

static var _retro_enabled: bool = true
static var _ambience_gain: float = 0.35
static var _image_detail: StringName = &"adaptive"
static var _hum: AudioStreamWAV

var _retro_control: CheckButton
var _volume_control: HSlider
var _volume_label: Label
var _detail_control: OptionButton


func _ready() -> void:
	$Screen.visible = _retro_enabled
	_apply_image_detail()
	if _hum == null:
		_hum = _make_hum()
	$Ambience.stream = _hum
	_apply_volume()


func configure_controls(hud: NavigationHUD) -> void:
	_retro_control = hud.get_node("%RetroCheck")
	_volume_control = hud.get_node("%AmbienceVolume")
	_volume_label = hud.get_node("%AmbienceLabel")
	_detail_control = hud.get_node("%ImageDetail")
	_detail_control.select([&"adaptive", &"native", &"classic"].find(_image_detail))
	_detail_control.item_selected.connect(func(index: int) -> void: set_image_detail([&"adaptive", &"native", &"classic"][index]))
	_retro_control.set_pressed_no_signal(_retro_enabled)
	_volume_control.set_value_no_signal(_ambience_gain)
	_update_label()
	_retro_control.toggled.connect(set_retro_enabled)
	_volume_control.value_changed.connect(set_ambience_gain)


func set_retro_enabled(value: bool) -> void:
	_retro_enabled = value
	$Screen.visible = value
	if is_instance_valid(_retro_control):
		_retro_control.set_pressed_no_signal(value)


func is_retro_enabled() -> bool:
	return _retro_enabled


func set_image_detail(value: StringName) -> bool:
	if value not in [&"adaptive", &"native", &"classic"]:
		return false
	_image_detail = value
	_apply_image_detail()
	if is_instance_valid(_detail_control):
		_detail_control.select([&"adaptive", &"native", &"classic"].find(value))
	return true


func get_image_detail() -> StringName:
	return _image_detail


func _apply_image_detail() -> void:
	var material: ShaderMaterial = $Screen.material
	material.set_shader_parameter("virtual_height", 360.0 if _image_detail == &"classic" else 0.0)
	material.set_shader_parameter("pixel_block", 1.0 if _image_detail == &"native" else 2.0)


func set_ambience_gain(value: float) -> void:
	if not is_finite(value):
		return
	_ambience_gain = clampf(value, 0.0, 1.0)
	_apply_volume()
	_update_label()
	if is_instance_valid(_volume_control):
		_volume_control.set_value_no_signal(_ambience_gain)


func get_ambience_gain() -> float:
	return _ambience_gain


func _apply_volume() -> void:
	$Ambience.volume_db = linear_to_db(maxf(_ambience_gain, 0.0001))
	if _ambience_gain == 0.0:
		$Ambience.stop()
	elif not $Ambience.playing and AudioServer.get_driver_name() != "Dummy":
		$Ambience.play()


func _update_label() -> void:
	if is_instance_valid(_volume_label):
		_volume_label.text = "Фоновый звук: %d%%" % roundi(_ambience_gain * 100.0)


func _make_hum() -> AudioStreamWAV:
	const RATE := 11025
	const COUNT := RATE * 4
	var pcm := PackedByteArray()
	pcm.resize(COUNT * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 30030
	var noise: float = 0.0
	for frame in COUNT:
		var time := float(frame) / RATE
		noise = lerpf(noise, random.randf_range(-1.0, 1.0), 0.06)
		var signal_value := sin(TAU * 55.0 * time) * 0.035 + sin(TAU * 110.0 * time) * 0.008
		# Огибающая шума с нулём на стыке; синусы укладываются в целые периоды.
		signal_value += noise * 0.055 * sin(PI * float(frame) / COUNT)
		pcm.encode_s16(frame * 2, roundi(clampf(signal_value, -1.0, 1.0) * 32767.0))
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = RATE
	result.data = pcm
	result.loop_mode = AudioStreamWAV.LOOP_FORWARD
	result.loop_end = COUNT
	return result
