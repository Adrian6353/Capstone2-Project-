extends "res://Scenes/Towers/Towers.gd"
## Balete Root-Snare - Crowd control tower with slow and stun effects
## L1 BaleteRootSnare : 30 % slow, stun every 4 hits
## L2 DeepRoots       : 45 % slow, stun every 4 hits
## L3 ThornyVines     : 45 % slow + thorn DoT, stun every 3 hits

var stun_counter: int = 0
var stun_threshold: int = 4  # ThornyVines (L3) reduces this to 3

func _ready() -> void:
	super._ready()
	var anim = get_node_or_null("Tower/Muzzle/AnimatedSprite2D")
	if anim:
		anim.visible = false
		anim.stop()
	# L3 stuns more frequently
	if type and GameData.tower_data.has(type):
		var tower_cost: int = GameData.tower_data[type].get("cost", 0)
		if tower_cost >= 230:  # ThornyVines
			stun_threshold = 3

func fire() -> void:
	can_fire = false

	if not type or not GameData.tower_data.has(type):
		await get_tree().create_timer(0.1).timeout
		can_fire = true
		return

	if category == "Control":
		fire_bow()

	if enemy and is_instance_valid(enemy):
		var tower_cost: int = GameData.tower_data[type].get("cost", 0)

		# Base damage + hit VFX
		apply_effect("damage", enemy, 0, 0)
		spawn_impact_vfx(tower_family, enemy.global_position)

		# Slow: 30 % at L1 (cost 130), 45 % at L2+ (cost 180/230)
		var slow_duration := 4.0
		var slow_percent := 0.30 if tower_cost <= 130 else 0.45
		apply_slow(enemy, slow_duration, slow_percent)

		# ThornyVines (L3): thorn DoT on top of slow
		if tower_cost >= 230:
			apply_dot(enemy, slow_duration, 4)

		# Root-stun every N hits
		stun_counter += 1
		if stun_counter >= stun_threshold:
			apply_stun(enemy, 1.5)
			stun_counter = 0

	play_fire_sfx()
	var cooldown: float = GameData.tower_data[type].get("rof", 1.0)
	await get_tree().create_timer(cooldown).timeout
	can_fire = true
