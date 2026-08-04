extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "PugotBoss"
	damage_value = GameData.enemy_data.get("PugotBoss", {}).get("damage", 21)
	super._ready()
