extends "res://Scenes/Towers/Towers.gd"
## Pitik-Kawayan - Basic rapid-fire bamboo projectile tower
## No special mechanics - pure damage dealer

func _ready() -> void:
	super._ready()

func fire() -> void:
	can_fire = false
	
	if not type or not GameData.tower_data.has(type):
		await get_tree().create_timer(0.1).timeout
		can_fire = true
		return
	
	if category == "Projectile":
		fire_bow()
	
	var tower_cost: int = GameData.tower_data[type].get("cost", 0)
	if tower_cost >= 230:  # TwinShooters (L3) fires 2 projectiles
		for i in range(2):
			if enemy and is_instance_valid(enemy):
				apply_effect("damage", enemy, 0, 0)
	else:
		# Single shot for L1 and L2
		if enemy and is_instance_valid(enemy):
			apply_effect("damage", enemy, 0, 0)
	
	play_fire_sfx()
	var cooldown = GameData.tower_data[type].get("rof", 1.0)
	await get_tree().create_timer(cooldown).timeout
	can_fire = true
