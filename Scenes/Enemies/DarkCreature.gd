extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "DarkCreature"
	damage_value = GameData.enemy_data.get("DarkCreature", {}).get("damage", 21)
	super._ready()
