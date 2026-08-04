extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "NunoSaPunso"
	damage_value = GameData.enemy_data.get("NunoSaPunso", {}).get("damage", 21)
	super._ready()
