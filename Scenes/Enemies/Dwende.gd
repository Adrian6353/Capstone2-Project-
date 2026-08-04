extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "Dwende"
	damage_value = GameData.enemy_data.get("Dwende", {}).get("damage", 21)
	super._ready()
