extends "res://Scenes/Towers/Towers.gd"
## Agimat Mortar - Artillery tower with area-of-effect splash damage

func _ready() -> void:
	super._ready()
	var anim = get_node_or_null("Tower/Muzzle/AnimatedSprite2D")
	if anim:
		anim.visible = false
		anim.stop()

func turn() -> void:
	pass  # Mortar does not rotate to track enemies

func fire() -> void:
	can_fire = false

	if not type or not GameData.tower_data.has(type):
		await get_tree().create_timer(0.1).timeout
		can_fire = true
		return

	var anim = get_node_or_null("Tower/Muzzle/AnimatedSprite2D")
	if anim:
		anim.visible = true
		anim.play("default")

	if category == "Artillery":
		fire_bow()

	if enemy and is_instance_valid(enemy):
		apply_effect("damage", enemy, 0, 0)
		var splash_radius = GameData.tower_data[type].get("range", 350.0) * 0.2
		apply_splash_damage(enemy.global_position, splash_radius, 0.6, enemy)

	play_fire_sfx()
	var cooldown = GameData.tower_data[type].get("rof", 1.0)
	var show_duration = min(0.3, cooldown)
	await get_tree().create_timer(show_duration).timeout
	if anim:
		anim.visible = false
		anim.stop()
	await get_tree().create_timer(cooldown - show_duration).timeout
	can_fire = true
