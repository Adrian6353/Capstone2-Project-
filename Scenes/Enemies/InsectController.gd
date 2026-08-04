extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "InsectController"
	damage_value = GameData.enemy_data.get("InsectController", {}).get("damage", 21)
	super._ready()
