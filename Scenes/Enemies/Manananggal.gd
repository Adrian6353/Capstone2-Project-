extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "Manananggal"
	damage_value = GameData.enemy_data.get("Manananggal", {}).get("damage", 21)
	set_meta("is_flying", true)
	super._ready()
