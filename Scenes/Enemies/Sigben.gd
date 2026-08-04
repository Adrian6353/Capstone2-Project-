extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "Sigben"
	damage_value = GameData.enemy_data.get("Sigben", {}).get("damage", 21)
	super._ready()
