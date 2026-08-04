extends "res://Scenes/Towers/Towers.gd"
## Habing Liwanag Shrine - Aura tower that buffs nearby towers (non-damaging)

var buff_radius = 280
var atk_speed_buff = 0.10
var damage_buff = 0.0
var buffed_towers = []
var sfx_pulse_timer = 0.0
var sfx_pulse_interval = 6.0

func _ready() -> void:
	super._ready()

func _physics_process(delta: float):
	if not built:
		return
	
	sfx_pulse_timer += delta
	update_aura_buffs()

func fire() -> void:
	# This tower doesn't fire in the traditional sense
	pass

func update_aura_buffs() -> void:
	if not type or not GameData.tower_data.has(type):
		return
	
	var current_radius = buff_radius
	var current_atk_speed = atk_speed_buff
	
	# Expand radius and increase buff for higher levels
	var tower_cost = GameData.tower_data[type].get("cost", 0)
	if tower_cost >= 320:  # WovenThreads
		current_radius = int(current_radius * 1.36)
	if tower_cost >= 400:  # SanghayasBlessing
		current_radius = int(current_radius * 1.50)
		damage_buff = 0.15
	
	# Find all towers in radius and apply buff
	var towers_in_radius = find_towers_in_radius(current_radius)
	if towers_in_radius.size() > 0 and sfx_pulse_timer >= sfx_pulse_interval:
		play_fire_sfx()
		sfx_pulse_timer = 0.0
	for tower in towers_in_radius:
		apply_tower_buff(tower, current_atk_speed, damage_buff)

func find_towers_in_radius(radius: float) -> Array:
	var found_towers = []
	# This requires scanning the scene for other tower nodes
	# For now, we'll use a placeholder that can be expanded
	var scene_tree = get_tree()
	
	for node in scene_tree.get_nodes_in_group("towers"):
		if node != self and node.global_position.distance_to(global_position) <= radius:
			found_towers.append(node)
	
	return found_towers

func apply_tower_buff(tower: Node, atk_speed_boost: float, damage_boost: float) -> void:
	if is_instance_valid(tower):
		# Store original ROF and apply boost
		if not tower.has_meta("original_rof"):
			tower.set_meta("original_rof", GameData.tower_data[tower.type].get("rof", 1.0))
		
		var original_rof = tower.get_meta("original_rof")
		var boosted_rof = original_rof * (1.0 - atk_speed_boost)
		tower.set_meta("buffed_rof", boosted_rof)
		
		if damage_boost > 0:
			if not tower.has_meta("original_damage"):
				tower.set_meta("original_damage", GameData.tower_data[tower.type].get("damage", 0))
			tower.set_meta("damage_boost", damage_boost)

func turn():
	# Support towers don't rotate
	pass
