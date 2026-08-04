extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "DarkEngkanto"
	damage_value = GameData.enemy_data.get("DarkEngkanto", {}).get("damage", 21)
	super._ready()
