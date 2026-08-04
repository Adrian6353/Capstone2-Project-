extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "Ghoul"
	damage_value = GameData.enemy_data.get("Ghoul", {}).get("damage", 21)
	super._ready()
