extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "Tikbalang"
	damage_value = GameData.enemy_data.get("Tikbalang", {}).get("damage", 21)
	super._ready()
