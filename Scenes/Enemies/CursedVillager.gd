extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "CursedVillager"
	damage_value = GameData.enemy_data.get("CursedVillager", {}).get("damage", 21)
	super._ready()
