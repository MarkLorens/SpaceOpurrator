extends Node2D
## Builds the shared continuous 2D world: a wide horizontal strip with
## alternating background stripes plus a numbered vertical line every 200px,
## so panning/scrolling is immediately noticeable on both connected screens.

const WORLD_WIDTH := 3000.0
const MARK_SPACING := 200.0
const STRIPE_HEIGHT := 2000.0

@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	camera.world_min_x = 0.0
	camera.world_max_x = WORLD_WIDTH
	_generate_landmarks()
	camera.make_current()


func _generate_landmarks() -> void:
	var landmarks := Node2D.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)

	var x := 0.0
	var i := 0
	while x <= WORLD_WIDTH:
		# Alternating background stripe: unmistakable when the camera pans.
		var stripe := ColorRect.new()
		stripe.size = Vector2(MARK_SPACING, STRIPE_HEIGHT)
		stripe.position = Vector2(x, -STRIPE_HEIGHT / 2.0)
		stripe.color = Color(0.16, 0.18, 0.24) if i % 2 == 0 else Color(0.24, 0.26, 0.34)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Decoration only: never eat drag input.
		landmarks.add_child(stripe)

		# Vertical marker line at every 200px world-space increment.
		var line := Line2D.new()
		line.points = PackedVector2Array([
			Vector2(x, -STRIPE_HEIGHT / 2.0), Vector2(x, STRIPE_HEIGHT / 2.0)
		])
		line.width = 3.0
		line.default_color = Color(1, 1, 1, 0.5)
		landmarks.add_child(line)

		# Label showing the world X coordinate at this marker.
		var label := Label.new()
		label.text = "X=%d" % int(x)
		label.position = Vector2(x + 8, -80)
		landmarks.add_child(label)

		x += MARK_SPACING
		i += 1
