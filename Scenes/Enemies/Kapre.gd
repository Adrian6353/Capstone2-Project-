extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "Kapre"
	damage_value = GameData.enemy_data.get("Kapre", {}).get("damage", 21)
	super._ready()
