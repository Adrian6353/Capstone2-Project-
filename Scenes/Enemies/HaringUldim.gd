extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "HaringUldim"
	damage_value = GameData.enemy_data.get("HaringUldim", {}).get("damage", 90)
	super._ready()
