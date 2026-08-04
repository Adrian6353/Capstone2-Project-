extends "res://Scenes/Towers/Towers.gd"
## Mutya Focus - Beam tower with sustained damage

var lock_duration = 0.0
var lock_target = null

func _ready() -> void:
	super._ready()
	var anim = get_node_or_null("Tower/Muzzle/AnimatedSprite2D")
	if anim:
		anim.visible = false
		anim.stop()

func _physics_process(delta: float):
	if enemy_array.size() != 0 and built:
		if not lock_target or not is_instance_valid(lock_target):
			select_enemy()
			lock_target = enemy
			lock_duration = 0.0
		
		if lock_target and can_fire:
			lock_duration += delta
			fire()
		turn()

func fire() -> void:
	if not lock_target or not is_instance_valid(lock_target):
		return
	
	can_fire = false
	
	if not type or not GameData.tower_data.has(type):
		await get_tree().create_timer(0.1).timeout
		can_fire = true
		return
	
	# Fire animation
	if category == "Beam":
		fire_bow()
	
	var anim = get_node_or_null("Tower/Muzzle/AnimatedSprite2D")
	if anim:
		anim.visible = true
		anim.play("default")
	
	# Damage scales with lock duration
	var base_damage = GameData.tower_data[type].get("damage", 0)
	var damage_multiplier = 1.0 + (lock_duration * 0.1)  # 10% more damage per second locked
	var final_damage = int(base_damage * damage_multiplier)
	
	lock_target.on_hit(final_damage, tower_family)
	
	play_fire_sfx()
	var cooldown = GameData.tower_data[type].get("rof", 1.0)
	var show_duration = min(0.3, cooldown)
	await get_tree().create_timer(show_duration).timeout
	if anim:
		anim.visible = false
		anim.stop()
	await get_tree().create_timer(cooldown - show_duration).timeout
	can_fire = true

func turn():
	pass  # Beam tower does not rotate to track enemies
