extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "CorruptedSpirit"
	damage_value = GameData.enemy_data.get("CorruptedSpirit", {}).get("damage", 21)
	super._ready()
