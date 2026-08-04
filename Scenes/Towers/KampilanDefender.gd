extends "res://Scenes/Towers/Towers.gd"
## Kampilan Defender - Armor-shredding melee tower

var armor_shred_counter = 0
var armor_shred_threshold = 4  # Every 4th hit shatters armor

func _ready() -> void:
	super._ready()
	var anim = get_node_or_null("Tower/Muzzle/AnimatedSprite2D")
	if anim:
		anim.visible = false
		anim.stop()
		if anim.sprite_frames:
			for anim_name in anim.sprite_frames.get_animation_names():
				anim.sprite_frames.set_animation_loop(anim_name, false)

func fire_bow() -> void:
	var anim_player = get_node_or_null("AnimationPlayer")
	if anim_player and anim_player.has_animation("Fire"):
		anim_player.play("Fire")
	_play_attack_animation()

func _play_attack_animation() -> void:
	var anim = get_node_or_null("Tower/Muzzle/AnimatedSprite2D")
	if not anim or not anim.sprite_frames:
		return

	var animation_name := "default"
	if not anim.sprite_frames.has_animation(animation_name):
		var anim_names = anim.sprite_frames.get_animation_names()
		if anim_names.is_empty():
			return
		animation_name = anim_names[0]

	anim.visible = true
	anim.frame = 0
	anim.play(animation_name)

	var frame_count = anim.sprite_frames.get_frame_count(animation_name)
	var playback_speed = max(anim.sprite_frames.get_animation_speed(animation_name) * abs(anim.speed_scale), 0.01)
	var anim_duration = max(float(frame_count) / playback_speed, 0.15)
	await get_tree().create_timer(anim_duration).timeout

	if is_instance_valid(anim):
		anim.visible = false
		anim.stop()

func fire() -> void:
	can_fire = false
	if not type or not GameData.tower_data.has(type):
		await get_tree().create_timer(0.1).timeout
		can_fire = true
		return
	
	if category == "Projectile" or category == "Melee":
		fire_bow()
	
	if enemy and is_instance_valid(enemy):
		armor_shred_counter += 1
		
		# Apply base damage
		apply_effect("damage", enemy, 0, 0)
		spawn_impact_vfx(tower_family, enemy.global_position)
		
		# Apply armor reduction
		var rarity = GameData.tower_data[type].get("rarity", "common")
		if rarity == "rare":  # Heated Blade and higher have armor reduction
			apply_armor_reduction(enemy, 1)
		
		# Every 4th hit: complete armor break
		if armor_shred_counter >= armor_shred_threshold:
			apply_armor_shred(enemy, 5.0)
			armor_shred_counter = 0
	
	play_fire_sfx()
	var cooldown = GameData.tower_data[type].get("rof", 1.0)
	await get_tree().create_timer(cooldown).timeout
	can_fire = true
