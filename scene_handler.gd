extends Node

func _ready() -> void:
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

func on_new_game_pressed() -> void:
	AudioManager.stop_music(0.5)
	get_node("MainMenu").queue_free()

	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

	var game_scene = load("res://Scenes/MainScenes/GameScene.tscn").instantiate()
	game_scene.game_finished.connect(unload_game)
	add_child(game_scene)

	print("New Game Pressed!")

func on_quit_pressed() -> void:
	get_tree().quit()
	
func unload_game(_result):
	AudioManager.stop_music(0.5)
	get_node("GameScene").queue_free()
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var main_menu = load("res://Scenes/UIScenes/main_menu.tscn").instantiate()
	add_child(main_menu)
