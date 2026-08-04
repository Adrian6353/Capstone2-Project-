extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "Aswang"
	damage_value = GameData.enemy_data.get("Aswang", {}).get("damage", 21)
	super._ready()
