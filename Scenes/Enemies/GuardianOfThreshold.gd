extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "GuardianOfThreshold"
	damage_value = GameData.enemy_data.get("GuardianOfThreshold", {}).get("damage", 21)
	super._ready()
