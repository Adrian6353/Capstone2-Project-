extends "res://Scenes/Towers/Towers.gd"
## Kidlat Weaver - Chain lightning tower bouncing between nearby enemies

var bounce_count = 1
var bounce_range = 250.0
var paralyze_enabled = false

func _ready() -> void:
	super._ready()
	var anim = get_node_or_null("Tower/Muzzle/AnimatedSprite2D")
	if anim:
		anim.visible = false
		anim.stop()
	# Determine bounce count and paralyze based on tower type
	if not type or not GameData.tower_data.has(type):
		return
	var tower_cost = GameData.tower_data[type].get("cost", 0)
	match tower_cost:
		180:  # KidlatNode
			bounce_count = 2
			paralyze_enabled = false
		240:  # StaticCharge
			bounce_count = 4
			paralyze_enabled = false
		300:  # HighVoltage
			bounce_count = 6
			paralyze_enabled = true

func turn() -> void:
	pass  # Lightning tower does not rotate to track enemies

func fire() -> void:
	can_fire = false
	
	if category == "Lightning":
		fire_bow()
	
	var anim = get_node_or_null("Tower/Muzzle/AnimatedSprite2D")
	if anim:
		anim.visible = true
		anim.play("default")
	
	if enemy and is_instance_valid(enemy):
		# Apply damage to the initial target
		apply_damage_to_target(enemy, 1.0)
		# Apply chain lightning to subsequent bounces
		apply_chain_bounce(enemy, bounce_count, bounce_range)
		
		# Paralyzing shock stuns final target
		if paralyze_enabled and bounce_count > 0:
			apply_stun(enemy, 0.5)
	
	play_fire_sfx()
	var cooldown = GameData.tower_data[type].get("rof", 1.0)
	var show_duration = min(0.3, cooldown)
	await get_tree().create_timer(show_duration).timeout
	if anim:
		anim.visible = false
		anim.stop()
	await get_tree().create_timer(cooldown - show_duration).timeout
	can_fire = true
