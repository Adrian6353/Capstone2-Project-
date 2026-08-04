extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "Tiyanak"
	damage_value = GameData.enemy_data.get("Tiyanak", {}).get("damage", 21)
	super._ready()
