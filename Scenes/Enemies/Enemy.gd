extends PathFollow2D

signal base_damage(damage)
signal enemy_destroyed(reward)

@export var speed: float = 150.0
var hp: float = 0
var damage_value = 21
var enemy_type: String = ""  # Should be set by child classes
var last_x_position: float = 0.0
var is_destroyed: bool = false  # Flag to prevent double-signaling
var lethal_to_base: bool = false  # If true, deals 100% base health damage when reaching the end

@onready var health_bar = get_node("HealthBar")
@onready var impact_area = get_node("Impact")
var projectile_impact = preload("res://Scenes/SupportScenes/projectile_impact.tscn")

func _ready() -> void:
	if hp == 0 and enemy_type != "":
		hp = GameData.enemy_data.get(enemy_type, {}).get("hp", 50)
		health_bar.max_value = hp
		health_bar.value = hp
		# top_level is set in initialize() which always runs with wave data

func initialize(wave_num: int = 1) -> void:
	if enemy_type == "":
		return
	var base_hp = GameData.enemy_data.get(enemy_type, {}).get("hp", 50)
	hp = base_hp * (1.0 + 0.15 * (wave_num - 1))
	speed = GameData.enemy_data.get(enemy_type, {}).get("speed", speed)
	health_bar.max_value = hp
	health_bar.value = hp
	health_bar.top_level = true

func _physics_process(delta: float) -> void:
	health_bar.set_position(position - Vector2(30, 50))
	progress += speed * delta
	
	# Keep rotation at 0 to prevent vertical tilting
	rotation = 0
	
	# Flip sprite based on horizontal movement direction
	if position.x > last_x_position:
		$CharacterBody2D/Sprite2D.flip_h = false  # Moving right
	elif position.x < last_x_position:
		$CharacterBody2D/Sprite2D.flip_h = true   # Moving left
	
	last_x_position = position.x
	
	if progress_ratio >= 1.0 and not is_destroyed:
		is_destroyed = true
		var final_damage = 100 if lethal_to_base else damage_value
		emit_signal("base_damage", final_damage)
		queue_free()
		
func on_hit(damage, tower_family: String = ""):
	hp -= damage
	health_bar.value = hp
	impact(tower_family)
	
	var impact_sound = "enemy_hit"
	if tower_family != "":
		var tower_effects = GameData.get_tower_audio_and_effects(tower_family)
		impact_sound = tower_effects.get("impact_audio_key", impact_sound)
	
	AudioManager.play_sfx(impact_sound, randf_range(-0.15, 0.15))
	if hp <= 0:
		on_destroy()
		
func impact(tower_family: String = ""):
	# Look up tower-family-specific impact scene if provided
	var impact_scene_path = "res://Scenes/SupportScenes/projectile_impact.tscn"
	
	if tower_family != "":
		var tower_effects = GameData.get_tower_audio_and_effects(tower_family)
		if tower_effects.has("impact_scene"):
			impact_scene_path = tower_effects["impact_scene"]
	
	randomize()
	var x_pos = randi() % 31
	randomize()
	var y_pos = randi() % 31
	var impact_location = Vector2(x_pos, y_pos)
	
	var impact_scene = load(impact_scene_path)
	if impact_scene:
		var new_impact = impact_scene.instantiate()
		new_impact.global_position = global_position + impact_location
		get_tree().root.add_child(new_impact)
	else:
		print("ERROR: Could not load impact scene: ", impact_scene_path)
		
func on_destroy():
	# Play enemy death sound
	AudioManager.play_sfx("enemy_death")
	if enemy_type != "" and not is_destroyed:
		is_destroyed = true
		var reward = GameData.enemy_data.get(enemy_type, {}).get("reward", 50)
		emit_signal("enemy_destroyed", reward)
	self.queue_free()
