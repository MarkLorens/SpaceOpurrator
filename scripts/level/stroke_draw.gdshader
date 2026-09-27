shader_type canvas_item;
// Draws a space stroke on along its own curve. flow_map holds each pixel's
// distance along the stroke (0 = start, 1 = end; tools/stroke_flow_maps.py).
// Pixels between the tail and the head show: the head sweeps forward drawing
// the stroke, and the tail follows behind, erasing it.

uniform sampler2D flow_map : filter_nearest;
// How far the drawing has got, 0..1 + tail (StrokeField animates it).
uniform float head = 0.0;
// Visible length behind the head, as a fraction of the stroke.
uniform float tail = 0.45;
// Soft fade at the tail end, as a fraction of the stroke.
uniform float fade = 0.15;
// Draw from the other end.
uniform bool reversed = false;

void fragment() {
	float t = texture(flow_map, UV).r;
	if (reversed) {
		t = 1.0 - t;
	}
	float drawn = step(t, head);
	float not_erased = smoothstep(head - tail, head - tail + fade, t);
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= drawn * not_erased;
}
