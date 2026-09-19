extends CharacterBody2D

const SPEED: float = 300.0
const RADIUS: float = 40.0

@onready var camera: Camera2D = $Camera2D

func _enter_tree() -> void:
	# Authority = the peer whose id matches this node's name (set by the spawner).
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	# Only the local player's camera follows; the remote circle is just watched.
	if is_multiplayer_authority():
		camera.make_current()
	queue_redraw()

func _draw() -> void:
	# Blue = the circle you control, red = the other player's circle.
	var col: Color = Color("4a90e2") if is_multiplayer_authority() else Color("e2574a")
	draw_circle(Vector2.ZERO, RADIUS, col)

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority(): return

	velocity = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") * SPEED
	move_and_slide()
