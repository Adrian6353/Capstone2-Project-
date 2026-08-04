extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "Trickster"
	damage_value = GameData.enemy_data.get("Trickster", {}).get("damage", 21)
	super._ready()
