extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "Mambabarang"
	damage_value = GameData.enemy_data.get("Mambabarang", {}).get("damage", 21)
	super._ready()
