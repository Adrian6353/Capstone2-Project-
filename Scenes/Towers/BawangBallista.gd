extends "res://Scenes/Towers/Towers.gd"
## Bawang Ballista - Air-only targeting tower

func _ready() -> void:
	super._ready()

func _physics_process(delta: float):
	if enemy_array.size() != 0 and built:
		select_enemy_air_only()
		if enemy and can_fire:
			fire()
		turn()

## Select only air targets
func select_enemy_air_only():
	var air_targets = []
	var air_progress = []
	
	for e in enemy_array:
		if is_instance_valid(e) and e.has_meta("is_flying") and e.get_meta("is_flying"):
			air_targets.append(e)
			air_progress.append(e.progress)
	
	if air_targets.size() > 0:
		var max_progress = air_progress.max()
		var idx = air_progress.find(max_progress)
		enemy = air_targets[idx]
	else:
		enemy = null
