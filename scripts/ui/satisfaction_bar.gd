extends Control
## The satisfaction bar drawn on the main board, as a row of split-flap
## segments. When the value jumps up (a solve), the newly filled segments flip
## open one after another in orange, then flip again to pink. When the value
## drops (drain, penalty) the fill shrinks straight away, no flips.
##
## The HUD owns the number; it calls show_value() whenever it changes, on both
## host and client. Processes while paused so the end screen shows the final fill.

@export var orange_texture: Texture2D
@export var pink_texture: Texture2D
## How many flaps the bar is split into.
@export var segment_count := 20
## Seconds for one flap to close and reopen.
@export var flip_time := 0.12
## Delay between neighbouring flaps starting, for the left-to-right ripple.
@export var stagger := 0.04
## Pause after the orange ripple before the pink ripple starts.
@export var catch_up_delay := 0.15
## A rise bigger than this fraction of the bar counts as a jump (not jitter).
@export var jump_threshold := 0.005

var _value := 0.0
var _max := 100.0
var _started := false
var _segments: Array[TextureRect] = []
var _atlases: Array[AtlasTexture] = []
var _edges: Array[int] = []  # pixel x of each segment boundary, integer so flaps tile exactly
var _shown: Array[float] = []  # how much of each flap is revealed (0..1); only flips raise it
var _pink: Array[bool] = []
var _tweens: Array[Tween] = []

func _ready() -> void:
	var width := int(orange_texture.get_width())
	var height := float(orange_texture.get_height())
	for i in segment_count + 1:
		_edges.append(roundi(float(i) * width / segment_count))
	for i in segment_count:
		var atlas := AtlasTexture.new()
		var seg := TextureRect.new()
		seg.texture = atlas
		seg.position = Vector2(_edges[i], 0)
		seg.pivot_offset = Vector2(0, height / 2.0)  # flaps fold at their vertical middle
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(seg)
		_segments.append(seg)
		_atlases.append(atlas)
		_shown.append(0.0)
		_pink.append(true)
		_tweens.append(null)

func show_value(value: float, max_value: float) -> void:
	var jumped := _started and value - _value > max_value * jump_threshold
	var old_fill := _fills(_value, _max)
	_value = value
	_max = max_value
	var new_fill := _fills(value, max_value)
	if not _started:  # the level's starting value appears instantly
		_started = true
		_shown = new_fill
	elif jumped:
		_flip_up(old_fill, new_fill)
	else:
		for i in segment_count:  # drain, penalty or tiny rise: follow immediately
			if new_fill[i] < _shown[i] or new_fill[i] - _shown[i] < 0.02:
				_shown[i] = new_fill[i]
	for i in segment_count:
		_draw_segment(i)

## Ripple the segments that gained fill: flip to orange left to right, then
## after a pause ripple them again to pink.
func _flip_up(old_fill: Array[float], new_fill: Array[float]) -> void:
	var gained: Array[int] = []
	for i in segment_count:
		if new_fill[i] > old_fill[i]:
			gained.append(i)
	var orange_done := (gained.size() - 1) * stagger + flip_time
	for k in gained.size():
		var i := gained[k]
		if _tweens[i]:
			_tweens[i].kill()
		var seg := _segments[i]
		seg.scale.y = 1.0
		var t := create_tween()
		t.tween_interval(k * stagger)
		t.tween_property(seg, "scale:y", 0.0, flip_time / 2.0)
		t.tween_callback(func() -> void:
			_shown[i] = 1.0  # capped by the live value in _draw_segment
			_pink[i] = false
			_draw_segment(i))
		t.tween_property(seg, "scale:y", 1.0, flip_time / 2.0)
		t.tween_interval(orange_done + catch_up_delay - flip_time)  # pink ripple starts once orange is done
		t.tween_property(seg, "scale:y", 0.0, flip_time / 2.0)
		t.tween_callback(func() -> void:
			_pink[i] = true
			_draw_segment(i))
		t.tween_property(seg, "scale:y", 1.0, flip_time / 2.0)
		_tweens[i] = t

## How full each segment is (0..1) for a bar value.
func _fills(value: float, max_value: float) -> Array[float]:
	var fills: Array[float] = []
	var ratio := clampf(value / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	for i in segment_count:
		fills.append(clampf(ratio * segment_count - i, 0.0, 1.0))
	return fills

func _draw_segment(i: int) -> void:
	var live := clampf(clampf(_value / _max, 0.0, 1.0) * segment_count - i, 0.0, 1.0) if _max > 0.0 else 0.0
	var frac := minf(_shown[i], live)
	var seg := _segments[i]
	var full_w := _edges[i + 1] - _edges[i]
	var w := roundi(full_w * frac)
	seg.visible = w > 0
	if w > 0:
		var atlas := _atlases[i]
		atlas.atlas = pink_texture if _pink[i] else orange_texture
		atlas.region = Rect2(_edges[i], 0, w, orange_texture.get_height())
		seg.size = Vector2(w, orange_texture.get_height())
