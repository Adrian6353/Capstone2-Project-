extends "res://Scenes/Enemies/Enemy.gd"

func _ready() -> void:
	enemy_type = "BossSpiritGuardian"
	damage_value = GameData.enemy_data.get("BossSpiritGuardian", {}).get("damage", 21)
	lethal_to_base = true  # Weave Breaker boss deals 100% base health damage if it reaches the end
	super._ready()
