extends Node2D
## Space strokes drawing themselves across the background: each one is drawn on
## along its own curve, the tail follows behind until it's gone, and another
## starts somewhere else. Used in the level (the outer space areas, like
## StarField) and on the main menu.
##
## Each stroke needs a flow map saying how far along the stroke every pixel is;
## tools/stroke_flow_maps.py makes them (rerun it after adding stroke art).
## ponytail: cosmetic and random per phone, like StarField.

const SHADER := preload("res://scripts/level/stroke_draw.gdshader")

## Stroke texture -> its flow map (assets/ui/backgrounds/stroke_flow/).
@export var strokes: Dictionary[Texture2D, Texture2D] = {}
## World-X spans (from, to) that strokes appear in.
@export var bands: Array[Vector2] = [Vector2(0, 1850), Vector2(8650, 10488)]
## Height of the area strokes appear in.
@export var height := 1206.0
@export var stroke_scale := 3.0
## Most strokes on screen at once.
@export var max_strokes := 3
## Seconds between one stroke starting and the next.
@export var min_gap := 0.8
@export var max_gap := 2.5
## Seconds for the head to draw the whole stroke; the tail then catches up.
@export var min_draw_time := 1.6
@export var max_draw_time := 2.8
## How much of the stroke shows behind the head (0..1 of its length).
@export_range(0.05, 1.0) var tail := 0.45
## Slow drift while a stroke is drawn, pixels per second (random direction).
@export var drift := 20.0

var _rng := RandomNumberGenerator.new()
var _wait := 0.0

func _ready() -> void:
	_rng.randomize()
	_wait = _rng.randf_range(0.0, min_gap)  # first one soon after the scene opens

func _process(delta: float) -> void:
	if strokes.is_empty() or bands.is_empty():
		return
	_wait -= delta
	if _wait <= 0.0 and get_child_count() < max_strokes:
		_wait = _rng.randf_range(min_gap, max_gap)
		_spawn()

func _spawn() -> void:
	var texture: Texture2D = strokes.keys()[_rng.randi() % strokes.size()]
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("flow_map", strokes[texture])
	material.set_shader_parameter("tail", tail)
	material.set_shader_parameter("reversed", _rng.randf() < 0.5)
	material.set_shader_parameter("head", 0.0)

	var stroke := Sprite2D.new()
	stroke.texture = texture
	stroke.material = material
	stroke.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stroke.scale = Vector2.ONE * stroke_scale
	stroke.flip_h = _rng.randf() < 0.5
	stroke.flip_v = _rng.randf() < 0.5
	var half := texture.get_size() * stroke_scale / 2.0
	var band := bands[_rng.randi() % bands.size()]
	stroke.position = Vector2(
		_rng.randf_range(band.x + half.x, maxf(band.x + half.x, band.y - half.x)),
		_rng.randf_range(half.y, maxf(half.y, height - half.y)))
	add_child(stroke)

	# Head sweeps to the end, then on until the tail has passed it too.
	var time := _rng.randf_range(min_draw_time, max_draw_time) * (1.0 + tail)
	var tween := stroke.create_tween().set_parallel()
	tween.tween_property(material, "shader_parameter/head", 1.0 + tail, time)
	tween.tween_property(stroke, "position", Vector2.from_angle(_rng.randf() * TAU) * drift * time, time).as_relative()
	tween.chain().tween_callback(stroke.queue_free)
