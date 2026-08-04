extends "res://Scenes/Towers/Towers.gd"
## Parol ng Liwanag - Detection and reveal support tower (non-damaging)

var reveal_radius_base = 300
var flash_interval = 10.0
var flash_timer = 0.0

func _ready() -> void:
	super._ready()

func _physics_process(delta: float):
	if not built:
		return
	
	flash_timer += delta
	
	# Periodically emit a lantern pulse without spamming every frame
	if flash_timer >= flash_interval:
		if enemy_array.size() > 0:
			play_fire_sfx()
		apply_blinding_flash()
		flash_timer = 0.0
	
	# Always reveal invisible units in radius
	reveal_invisible_units()

func fire() -> void:
	# This tower doesn't fire in the traditional sense
	pass

func reveal_invisible_units() -> void:
	if not type or not GameData.tower_data.has(type):
		return
	
	var current_radius = reveal_radius_base
	
	# Expand radius for higher levels
	var tower_cost = GameData.tower_data[type].get("cost", 0)
	if tower_cost >= 130:  # BrightOil
		current_radius = int(current_radius * 1.2)
	if tower_cost >= 170:  # SearingLight
		current_radius = int(current_radius * 1.27)
	
	for enemy_unit in enemy_array:
		if is_instance_valid(enemy_unit) and hasattr_hidden(enemy_unit):
			enemy_unit.set_meta("revealed", true)

func apply_blinding_flash() -> void:
	var tower_cost = GameData.tower_data[type].get("cost", 0)
	if tower_cost >= 260:  # BlindingFlash effect
		for enemy_unit in enemy_array:
			if is_instance_valid(enemy_unit):
				apply_stun(enemy_unit, 0.3)

## Check if enemy has hidden property
func hasattr_hidden(obj) -> bool:
	return obj.has_meta("is_hidden") and obj.get_meta("is_hidden")

func turn():
	# Support towers don't rotate
	pass
