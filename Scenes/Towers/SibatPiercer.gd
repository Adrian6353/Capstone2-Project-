extends "res://Scenes/Towers/Towers.gd"
## Sibat Piercer - Line-piercing tower attacking through formations

var max_pierce = 3
var knockback_range = 50.0

func _ready() -> void:
	super._ready()
	if not type or not GameData.tower_data.has(type):
		return
	# Determine pierce count based on tower type
	var tower_cost = GameData.tower_data[type].get("cost", 0)
	match tower_cost:
		160:  # SibatPiercer
			max_pierce = 3
		210:  # IronTipped
			max_pierce = 5
		260:  # WeightedShafts
			max_pierce = 5

func fire() -> void:
	can_fire = false
	
	if not type or not GameData.tower_data.has(type):
		await get_tree().create_timer(0.1).timeout
		can_fire = true
		return
	
	if category == "Piercing":
		fire_bow()
	
	if enemy and is_instance_valid(enemy):
		var fire_direction = (enemy.global_position - global_position).normalized()
		
		# Apply piercing attack
		apply_pierce_attack(global_position, fire_direction, max_pierce)
		
		# WeightedShafts adds knockback
		var tower_cost = GameData.tower_data[type].get("cost", 0)
		if tower_cost >= 260:
			apply_knockback(enemy, fire_direction, knockback_range)
	
	play_fire_sfx()
	var cooldown = GameData.tower_data[type].get("rof", 1.0)
	await get_tree().create_timer(cooldown).timeout
	can_fire = true

## Apply knockback to an enemy
func apply_knockback(target, direction: Vector2, force: float) -> void:
	if target and target.has_meta("can_knockback"):
		target.global_position += direction * force
