extends Control
## Tutorial popup at the start of a level: the level's Tutorial one page at a
## time (picture, bold caption, purple steps title, steps body), flipped with
## the arrows. Each phone flips its own. Closing it tells the level; play starts
## once both players have closed theirs (GameState), so until then this shows
## a waiting note instead.
##
## Buttons click through AudioManager, which hooks every BaseButton.

signal closed

## Largest a page's picture is drawn, in screen pixels. Bigger pictures shrink
## to fit; small 1x pixel art grows by whole steps (2x, 3x…) so it stays crisp.
@export var picture_max_size := Vector2(1000, 310)

@onready var board: Control = $Center/Board
@onready var picture: TextureRect = %Picture
@onready var caption: Label = %Caption
@onready var steps_title: Label = %StepsTitle
@onready var steps_body: RichTextLabel = %StepsBody
@onready var page_label: Label = %PageLabel
@onready var prev_button: TextureButton = %PrevButton
@onready var next_button: TextureButton = %NextButton
@onready var close_button: TextureButton = %CloseButton
@onready var waiting_label: Label = $WaitingLabel

var _tutorial: Tutorial
var _page := 0

func _ready() -> void:
	hide()
	prev_button.pressed.connect(func() -> void: _show_page(_page - 1))
	next_button.pressed.connect(func() -> void: _show_page(_page + 1))
	close_button.pressed.connect(_close)
	GameState.play_started.connect(hide)

func open(tutorial: Tutorial) -> void:
	_tutorial = tutorial
	board.show()
	waiting_label.hide()
	show()
	_show_page(0)

func _show_page(index: int) -> void:
	var pages := _tutorial.pages
	_page = clampi(index, 0, pages.size() - 1)
	var page := pages[_page]
	picture.texture = page.picture
	picture.visible = page.picture != null
	if page.picture:
		picture.custom_minimum_size = _fit_picture(page.picture.get_size())
	caption.text = page.caption
	caption.visible = not page.caption.is_empty()
	steps_title.text = page.steps_title
	steps_title.visible = not page.steps_title.is_empty()
	steps_body.text = "[center]%s[/center]" % page.steps_body
	steps_body.visible = not page.steps_body.is_empty()
	page_label.text = "%d / %d" % [_page + 1, pages.size()]
	_set_arrow(prev_button, _page > 0)
	_set_arrow(next_button, _page < pages.size() - 1)

## No arrow past either end. Hidden by alpha, not visibility, so the page
## number stays centred in the bar.
func _set_arrow(arrow: TextureButton, usable: bool) -> void:
	arrow.disabled = not usable
	arrow.modulate.a = 1.0 if usable else 0.0

func _fit_picture(picture_size: Vector2) -> Vector2:
	var fit := minf(picture_max_size.x / picture_size.x, picture_max_size.y / picture_size.y)
	if fit >= 1.0:
		fit = floorf(fit)
	return (picture_size * fit).floor()

func _close() -> void:
	board.hide()
	# Hidden for good by play_started; that can fire during closed.emit() when
	# the other player already closed theirs (or there is no other player).
	waiting_label.visible = not GameState.game_running
	visible = waiting_label.visible
	closed.emit()
