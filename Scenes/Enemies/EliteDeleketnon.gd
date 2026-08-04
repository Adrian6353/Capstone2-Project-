extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "EliteDeleketnon"
	damage_value = GameData.enemy_data.get("EliteDeleketnon", {}).get("damage", 21)
	super._ready()
