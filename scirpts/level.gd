extends Control

# NOTE: the two handlers used to be swapped. Client button -> client, Server -> server.

func _on_client_pressed() -> void:
	NetworkHandler.start_client()
	_hide_menu()


func _on_server_pressed() -> void:
	NetworkHandler.start_server()
	_hide_menu()


func _hide_menu() -> void:
	# Hide the connect buttons once we're in so they don't cover the strip.
	$VBoxContainer.hide()
