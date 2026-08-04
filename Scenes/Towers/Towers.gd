extends Node2D

var can_fire = true
var category
var type
var enemy
var enemy_array = []
var built = false

var projectile_pool = null
var tower_family: String = ""
var audio_params: Dictionary = {}

func get_configured_range_radius() -> float:
	if type == null or not GameData.tower_data.has(type):
		return 0.0
	var desired_world_radius: float = float(GameData.tower_data[type].get("range", 0.0))
	var collision_shape: CollisionShape2D = get_node_or_null("Range/CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return desired_world_radius
	# Tower scenes use different root/range scales. CircleShape2D.radius is local,
	# so compensate for the full scene transform to keep GameData ranges in
	# consistent world-space pixels.
	var world_scale: float = absf(collision_shape.global_scale.x)
	if world_scale <= 0.0001:
		return desired_world_radius
	return desired_world_radius / world_scale

func apply_configured_range() -> void:
	var collision_shape: CollisionShape2D = get_node_or_null("Range/CollisionShape2D") as CollisionShape2D
	if collision_shape and collision_shape.shape is CircleShape2D:
		# Scene subresources may be shared by multiple instances. Give this tower
		# its own shape before applying its level-specific range.
		var circle: CircleShape2D = collision_shape.shape.duplicate() as CircleShape2D
		circle.radius = get_configured_range_radius()
		collision_shape.shape = circle

func _ready() -> void:
	if built:
		if GameData.tower_data.has(type):
			apply_configured_range()
		else:
			push_error("Tower type '" + str(type) + "' not found in tower_data. Check GameData.gd.")
	
	# Initialize family / audio only when type is known (not during preview)
	if type != null:
		tower_family = GameData.get_tower_family(type)
		audio_params = GameData.get_tower_audio_and_effects(tower_family)

		# Add aura visualizer for support towers
		if tower_family == "HabingLiwanagShrine":
			var aura_range = GameData.tower_data[type].get("range", 280.0)
			var aura_viz = load("res://Scenes/Effects/AuraVisualizer.tscn")
			if aura_viz:
				var aura = aura_viz.instantiate()
				add_child(aura)
				aura.set_radius(aura_range)

func _physics_process(delta: float):
	if enemy_array.size() != 0 and built:
		select_enemy()
		if can_fire:
			fire()
		turn()
	
func turn():
	if not enemy:
		return
	var muzzle_node = get_node_or_null("Tower/Muzzle/MuzzleFlash")
	if muzzle_node == null:
		muzzle_node = get_node_or_null("Tower/Muzzle/AnimatedSprite2D")
	if muzzle_node:
		muzzle_node.look_at(enemy.global_position)
	
func select_enemy():
	# Remove any freed/invalid enemies before selecting
	enemy_array = enemy_array.filter(func(e): return is_instance_valid(e))
	if enemy_array.is_empty():
		enemy = null
		return
	var enemy_progress_array = []
	for i in enemy_array:
		enemy_progress_array.append(i.progress)
	var max_progress = enemy_progress_array.max()
	var enemy_index = enemy_progress_array.find(max_progress)
	enemy = enemy_array[enemy_index]
	
func fire() -> void:
	can_fire = false
	if category == "Projectile":
		fire_bow()
		fire_projectile()
	
	# Apply damage using the effect system (for non-projectile towers)
	if category != "Projectile" and enemy and is_instance_valid(enemy):
		apply_effect("damage", enemy, 0, 0)
	
	play_fire_sfx()
	
	var cooldown = GameData.tower_data[type].get("rof", 1.0)
	await get_tree().create_timer(cooldown).timeout
	if not is_instance_valid(self):
		return
	can_fire = true

func play_fire_sfx() -> void:
	var sound_key: String = str(audio_params.get("audio_key", "tower_fire"))
	if sound_key.is_empty():
		return
	AudioManager.play_sfx(sound_key, randf_range(-0.1, 0.1))

## Fire a projectile toward the target
func fire_projectile() -> void:
	if not projectile_pool or not enemy:
		return
	
	var projectile = projectile_pool.get_projectile()
	if not projectile:
		return
	
	# Get damage for this tower
	var damage = GameData.tower_data[type].get("damage", 0)
	var projectile_speed = GameData.tower_data[type].get("projectile_speed", 400.0)
	var splash_radius = GameData.tower_data[type].get("splash_radius", 0.0)
	
	# Setup projectile impact callback
	projectile.on_impact_callback = Callable(self, "_on_projectile_impact")
	projectile.on_despawn_callback = Callable(self, "_on_projectile_despawn")
	
	# Launch projectile from tower position to enemy
	var muzzle_pos = global_position
	if has_node("Tower/Muzzle"):
		muzzle_pos = get_node("Tower/Muzzle").global_position
	projectile.launch(tower_family, muzzle_pos, enemy.global_position, damage, projectile_speed, splash_radius)

## Called when projectile impacts target
func _on_projectile_impact(target_area: Area2D, _damage: int, impact_pos: Vector2, _tower_family_name: String) -> void:
	if not is_instance_valid(self):
		return
	# Find the enemy and apply damage
	var hit_enemy = target_area.get_parent() if target_area.get_parent() else target_area
	if hit_enemy and hit_enemy in enemy_array:
		apply_damage(hit_enemy)
		
		# Spawn impact VFX with tower family specific effect
		if audio_params.has("impact_scene"):
			spawn_impact_vfx(tower_family, impact_pos)
		
		# Impact audio is resolved in the enemy hit flow using the tower family
		
		# Chain lightning effects for Kidlat towers
		if tower_family == "KidlatWeaver" and audio_params.has("impact_vfx") and audio_params["impact_vfx"] == "chain":
			spawn_chain_lightning(impact_pos, hit_enemy.global_position)

## Called when projectile despawns
func _on_projectile_despawn(projectile: Node) -> void:
	if projectile_pool:
		projectile_pool.return_projectile(projectile)

## Spawn tower-family-specific impact VFX at location
func spawn_impact_vfx(family_name: String, impact_position: Vector2) -> void:
	# Look up tower-family-specific impact scene from GameData
	var tower_effects = GameData.get_tower_audio_and_effects(family_name)
	var vfx_scene_path = tower_effects.get("impact_scene", "res://Scenes/SupportScenes/projectile_impact.tscn")
	
	var vfx_scene = load(vfx_scene_path)
	if vfx_scene:
		var vfx = vfx_scene.instantiate()
		get_parent().add_child(vfx)
		vfx.global_position = impact_position
	else:
		print("ERROR: Could not load impact VFX scene for tower family ", family_name, ": ", vfx_scene_path)

## Spawn chain lightning between targets
func spawn_chain_lightning(_start_pos: Vector2, target_pos: Vector2) -> void:
	var chain_distance = 200.0
	
	# Find additional targets within chain distance
	var chain_targets: Array[Vector2] = []
	for other_enemy in enemy_array:
		if other_enemy and other_enemy.global_position != target_pos:
			if target_pos.distance_to(other_enemy.global_position) <= chain_distance:
				chain_targets.append(other_enemy.global_position)
	
	if chain_targets.is_empty():
		return
	
	# Spawn chain lightning VFX to nearby targets
	var current_pos = target_pos
	for next_target in chain_targets:
		var midpoint = (current_pos + next_target) / 2.0
		spawn_impact_vfx("chain", midpoint)
		current_pos = next_target
	
func fire_bow():
	get_node("AnimationPlayer").play("Fire")

## Generic effect application system
func apply_effect(effect_type: String, target, duration: float = 0.0, stacks: int = 0) -> void:
	match effect_type:
		"damage":
			apply_damage(target)
		"dot":
			apply_dot(target, duration, stacks)
		"armor_reduction":
			apply_armor_reduction(target, stacks)
		"slow":
			apply_slow(target, duration)
		"stun":
			apply_stun(target, duration)
		"armor_shred":
			apply_armor_shred(target, duration)

## Apply base damage to target
func apply_damage(target) -> void:
	if target:
		var damage = GameData.tower_data[type].get("damage", 0)
		target.on_hit(damage, tower_family)

## Apply damage over time (DoT) effect
func apply_dot(target, duration: float, ticks: int = 5) -> void:
	if target and duration > 0 and ticks > 0:
		var damage_per_tick = GameData.tower_data[type].get("damage", 0) * 0.3
		var tick_duration = duration / ticks
		
		for i in range(ticks):
			await get_tree().create_timer(tick_duration).timeout
			if not is_instance_valid(self):
				return
			if target and is_instance_valid(target):
				target.on_hit(int(damage_per_tick), tower_family)

## Apply armor reduction (stacking debuff)
func apply_armor_reduction(target, stacks: int = 1) -> void:
	if target and not target.is_queued_for_deletion():
		if not target.has_meta("armor_reduction_stacks"):
			target.set_meta("armor_reduction_stacks", 0)
		
		var current = target.get_meta("armor_reduction_stacks")
		target.set_meta("armor_reduction_stacks", min(current + stacks, 10))  # Cap at 10 stacks
		
		# Reduce armor in target
		if target.has_meta("armor"):
			var reduction = 0.05 * target.get_meta("armor_reduction_stacks")
			target.set_meta("armor_modifier", 1.0 - reduction)

## Apply armor shred (instant armor break)
func apply_armor_shred(target, duration: float = 5.0) -> void:
	if target:
		target.set_meta("armor_shredded", true)
		await get_tree().create_timer(duration).timeout
		if not is_instance_valid(self):
			return
		if target and is_instance_valid(target):
			target.set_meta("armor_shredded", false)

## Apply slow effect (reduces movement speed)
func apply_slow(target, duration: float = 2.0, slow_percent: float = 0.35) -> void:
	if target and not target.has_meta("is_slowed"):
		target.set_meta("is_slowed", true)
		if "speed" in target:
			target.set_meta("original_speed", target.speed)
			target.speed *= (1.0 - slow_percent)
			await get_tree().create_timer(duration).timeout
			if not is_instance_valid(self):
				return
			if target and is_instance_valid(target):
				var original_speed = target.get_meta("original_speed", null)
				if original_speed != null:
					target.speed = original_speed
				target.remove_meta("is_slowed")
				target.remove_meta("original_speed")

## Apply stun effect (stop movement temporarily)
func apply_stun(target, duration: float = 1.5) -> void:
	if target and not target.has_meta("is_stunned"):
		target.set_meta("is_stunned", true)
		if "speed" in target:
			target.set_meta("original_speed", target.speed)
			target.speed = 0
			await get_tree().create_timer(duration).timeout
			if not is_instance_valid(self):
				return
			if target and is_instance_valid(target):
				var original_speed = target.get_meta("original_speed", null)
				if original_speed != null:
					target.speed = original_speed
				target.remove_meta("is_stunned")
				target.remove_meta("original_speed")

## Apply splash damage in an area
func apply_splash_damage(center_position: Vector2, radius: float, damage_multiplier: float = 0.8, exclude_target = null) -> void:
	var base_damage = GameData.tower_data[type].get("damage", 0)
	var splash_damage = int(base_damage * damage_multiplier)
	
	for enemy_unit in enemy_array:
		if enemy_unit and not enemy_unit.is_queued_for_deletion() and enemy_unit != exclude_target:
			var distance = center_position.distance_to(enemy_unit.global_position)
			if distance <= radius:
				enemy_unit.on_hit(splash_damage, tower_family)

## Chain lightning to nearby enemies
func apply_chain_bounce(start_target, max_bounces: int = 3, bounce_range: float = 250) -> void:
	if not start_target:
		return
	
	var bounced_enemies = [start_target]
	var current_target = start_target
	var damage_multiplier = 1.0
	
	for bounce in range(max_bounces):
		var nearest_enemy = null
		var nearest_distance = bounce_range
		
		for enemy_unit in enemy_array:
			if enemy_unit and enemy_unit not in bounced_enemies:
				var distance = current_target.global_position.distance_to(enemy_unit.global_position)
				if distance < nearest_distance:
					nearest_enemy = enemy_unit
					nearest_distance = distance
		
		if nearest_enemy:
			apply_damage_to_target(nearest_enemy, damage_multiplier)
			bounced_enemies.append(nearest_enemy)
			current_target = nearest_enemy
			damage_multiplier *= 0.85  # Damage drops off slightly per bounce
		else:
			break

## Pierce through line of enemies
func apply_pierce_attack(start_position: Vector2, direction: Vector2, max_pierce: int = 3) -> void:
	var base_damage = GameData.tower_data[type].get("damage", 0)
	var pierced_count = 0
	
	# Sort enemies by distance along the direction
	var enemies_in_line = []
	for enemy_unit in enemy_array:
		if enemy_unit:
			var to_enemy = (enemy_unit.global_position - start_position).normalized()
			var dot = direction.dot(to_enemy)
			if dot > 0.7:  # Only count enemies roughly in the direction
				enemies_in_line.append(enemy_unit)
	
	enemies_in_line.sort_custom(func(a, b): 
		return start_position.distance_to(a.global_position) < start_position.distance_to(b.global_position)
	)
	
	for enemy_unit in enemies_in_line:
		if pierced_count < max_pierce:
			enemy_unit.on_hit(base_damage, tower_family)
			pierced_count += 1

## Helper to apply damage with multiplier
func apply_damage_to_target(target, multiplier: float = 1.0) -> void:
	if target:
		var damage = int(GameData.tower_data[type].get("damage", 0) * multiplier)
		target.on_hit(damage, tower_family)
	
func _on_range_body_entered(body: Node2D) -> void:
	var e = body.get_parent()
	if is_instance_valid(e) and e not in enemy_array:
		enemy_array.append(e)


func _on_range_body_exited(body: Node2D) -> void:
	if is_instance_valid(body):
		enemy_array.erase(body.get_parent())
	# Also clean up any freed entries that may have accumulated
	enemy_array = enemy_array.filter(func(e): return is_instance_valid(e))
