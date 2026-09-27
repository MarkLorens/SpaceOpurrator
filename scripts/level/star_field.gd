extends Node2D
## Background stars falling down the two outer space areas of the board, so it
## feels like the ship is flying. Sits after Board and before the threat and
## puzzle interface in the level, so it draws between them.
## ponytail: purely cosmetic and random per phone; if both players look at the
## same spot their stars differ. Seed from GameState.session_seed if that matters.

## Star texture -> relative spawn chance (2.0 shows up twice as often as 1.0).
@export var stars: Dictionary[Texture2D, float] = {}
## World-X spans (from, to) that stars spawn in: left and right of the panel.
@export var bands: Array[Vector2] = [Vector2(0, 1850), Vector2(8650, 10488)]
## Board height; stars enter above the top edge and are removed once they
## pass the bottom.
@export var height := 1206.0
## Stars per second, across all bands.
@export var spawn_rate := 1.5
## Pixels per second downward; each star picks a speed in this range.
@export var min_speed := 40.0
@export var max_speed := 90.0
@export var star_scale := 1.2

var _rng := RandomNumberGenerator.new()
var _weights: PackedFloat32Array
var _spawn_timer := 0.0

func _ready() -> void:
	_weights = PackedFloat32Array(stars.values())
	if stars.is_empty():
		return
	# Fill the screen up front so the level doesn't open on empty space.
	var start_count := int(spawn_rate * height / ((min_speed + max_speed) / 2))
	for i in start_count:
		_spawn(_rng.randf_range(0, height))

func _process(delta: float) -> void:
	if stars.is_empty():
		return
	_spawn_timer -= delta
	while _spawn_timer <= 0.0:
		_spawn_timer += 1.0 / spawn_rate
		_spawn(-1.0)  # just above the top edge
	for star: Sprite2D in get_children():
		star.position.y += star.get_meta("speed") * delta
		if star.position.y > height:
			star.queue_free()

## Spawns one star at `y` (its top edge) in a random band. A negative `y`
## means "just above the screen": the star's bottom edge touches the top.
func _spawn(y: float) -> void:
	var star := Sprite2D.new()
	star.texture = stars.keys()[_rng.rand_weighted(_weights)]
	star.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	star.centered = false
	star.scale = Vector2.ONE * star_scale
	var band: Vector2 = bands[_rng.randi() % bands.size()]
	var width := star.texture.get_width() * star_scale
	if y < 0.0:
		y = -star.texture.get_height() * star_scale
	star.position = Vector2(_rng.randf_range(band.x, band.y - width), y)
	star.set_meta("speed", _rng.randf_range(min_speed, max_speed))
	add_child(star)
