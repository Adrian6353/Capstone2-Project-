extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "ElemSpirit"
	damage_value = GameData.enemy_data.get("ElemSpirit", {}).get("damage", 21)
	super._ready()
