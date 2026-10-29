class_name EnvironmentAudio
extends Node3D
## Тихие процедурные звуки бара, без игрового состояния и внешних записей.

static var _street_stream: AudioStreamWAV
static var _creak_stream: AudioStreamWAV
static var _rain_stream: AudioStreamWAV
var _gain: float = 0.0
var _active: bool = true
var _events_paused: bool = false
var _focused: bool = true
var _until_creak: float = 0.0
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.randomize()
	_until_creak = _random.randf_range(12.0, 24.0)
	if _street_stream == null:
		_street_stream = _make_street()
	if _creak_stream == null:
		_creak_stream = _make_creak()
	$Street.stream = _street_stream
	$Furniture.stream = _creak_stream
	_apply_gain()


func set_gain(value: float) -> void:
	if not is_finite(value):
		return
	_gain = clampf(value, 0.0, 1.0)
	_apply_gain()


func configure_night_bar() -> void:
	# Профиль новой локации; прежние меню/mute/пауза управляют теми же источниками.
	if _rain_stream == null:
		_rain_stream = _make_rain()
	$Street.stop()
	$Street.stream = _rain_stream
	$Street.position = Vector3(-4.7, 1.8, 0)
	$Furniture.position = Vector3(-3.45, 0.8, 1.55)
	_apply_gain()


func set_context(mode: StringName) -> void:
	# Меню/дневник сохраняют место, из которого открыты.
	if mode in [&"travel", &"home"]:
		_active = false
	elif mode in [&"exploration", &"dialogue", &"service", &"shift_complete"]:
		_active = true
	_events_paused = mode != &"exploration"
	_apply_gain()


func _apply_gain() -> void:
	$Street.volume_db = linear_to_db(maxf(_gain * 0.65, 0.0001))
	$Furniture.volume_db = linear_to_db(maxf(_gain * 0.45, 0.0001))
	if _gain == 0.0 or not _active:
		$Street.stop()
		$Furniture.stop()
	elif not $Street.playing and AudioServer.get_driver_name() != "Dummy":
		$Street.play()
	if _events_paused:
		$Furniture.stream_paused = true
	else:
		$Furniture.stream_paused = false


func _process(delta: float) -> void:
	if not _active or _events_paused or not _focused or _gain <= 0.0:
		return
	_until_creak -= delta
	if _until_creak <= 0.0:
		_until_creak = _random.randf_range(18.0, 38.0)
		if not $Furniture.playing and AudioServer.get_driver_name() != "Dummy":
			$Furniture.pitch_scale = _random.randf_range(0.9, 1.08)
			$Furniture.play()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true


func _exit_tree() -> void:
	$Street.stop()
	$Furniture.stop()


func _make_street() -> AudioStreamWAV:
	const RATE := 11025
	const COUNT := RATE * 12
	var random := RandomNumberGenerator.new()
	random.seed = 48001
	var white := PackedFloat32Array()
	white.resize(COUNT)
	for index in COUNT:
		white[index] = random.randf_range(-1.0, 1.0)
	# Прогреть фильтр концом периодического шума, чтобы не было разрыва на стыке.
	var low: float = 0.0
	for index in range(COUNT - 2048, COUNT):
		low = lerpf(low, white[index], 0.025)
	var pcm := PackedByteArray()
	pcm.resize((COUNT + 1) * 2)
	for index in COUNT:
		var time := float(index) / RATE
		low = lerpf(low, white[index], 0.025)
		var swell := 0.55 - 0.45 * cos(TAU * float(index) / COUNT)
		var value := (low * 0.045 + sin(TAU * 37.0 * time) * 0.006 + sin(TAU * 61.0 * time) * 0.003) * swell
		pcm.encode_s16(index * 2, roundi(value * 32767.0))
	pcm.encode_s16(COUNT * 2, pcm.decode_s16(0))
	var stream := _pcm(pcm, RATE)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = COUNT
	return stream


func _make_creak() -> AudioStreamWAV:
	const RATE := 22050
	const COUNT := 17640
	var pcm := PackedByteArray()
	pcm.resize(COUNT * 2)
	var phase: float = 0.0
	for index in COUNT:
		var progress := float(index) / (COUNT - 1)
		var frequency := 140.0 + 65.0 * sin(PI * progress) + 9.0 * sin(TAU * progress * 7.0)
		phase += TAU * frequency / RATE
		var envelope := pow(sin(PI * progress), 2.0)
		var value := (sin(phase) * 0.022 + sin(phase * 2.0) * 0.007) * envelope
		pcm.encode_s16(index * 2, roundi(value * 32767.0))
	return _pcm(pcm, RATE)


func _make_rain() -> AudioStreamWAV:
	const RATE := 11025
	const COUNT := RATE * 16
	var random := RandomNumberGenerator.new()
	random.seed = 290104
	var noise := PackedFloat32Array()
	noise.resize(COUNT)
	for i in COUNT:
		noise[i] = random.randf_range(-1, 1)
	var low := 0.0
	for i in range(COUNT - 4096, COUNT):
		low = lerpf(low, noise[i], 0.12)
	var pcm := PackedByteArray()
	pcm.resize((COUNT + 1) * 2)
	for i in COUNT:
		low = lerpf(low, noise[i], 0.12)
		var swell := 0.95 + 0.05 * cos(TAU * float(i) / COUNT)
		var value := (low * 0.11 + (noise[i] - low) * 0.012) * swell
		pcm.encode_s16(i * 2, roundi(value * 32767))
	# Дополнительный отсчёт для включительного декодирования стыка Godot.
	pcm.encode_s16(COUNT * 2, pcm.decode_s16(0))
	var stream := _pcm(pcm, RATE)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = COUNT
	return stream


func _pcm(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream
