extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "GeneralMaruk"
	damage_value = GameData.enemy_data.get("GeneralMaruk", {}).get("damage", 68)
	super._ready()
