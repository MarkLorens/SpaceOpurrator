class_name TutorialPage
extends Resource
## One page of a level's tutorial card. Empty parts are hidden.

## Illustration at the top of the card.
@export var picture: Texture2D
## Bold line under the picture (e.g. "SATISFACTION BAR").
@export var caption := ""
## Purple heading for the steps (e.g. "DESTROY THEM ALL!").
@export var steps_title := ""
## What to do, under the steps title. BBCode works, e.g. an inline button icon:
## [img width=60 height=48]res://assets/items/flip/click.png[/img]
@export_multiline var steps_body := ""
