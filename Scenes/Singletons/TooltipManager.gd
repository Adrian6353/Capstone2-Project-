extends Node

# Tooltip data structure
var tooltip_data = {
	"GreenTower": {
		"name": "Green Tower",
		"description": "Basic tower with moderate damage and range",
		"cost": 100,
		"damage": 10,
		"range": 200,
		"fire_rate": "Normal"
	},
	"PurpleTower": {
		"name": "Purple Tower",
		"description": "Alternative tower with different attack pattern",
		"cost": 150,
		"damage": 15,
		"range": 180,
		"fire_rate": "Normal"
	}
}

var active_tooltip = null
var tooltip_scene = null

func _ready() -> void:
	# Create tooltip scene dynamically if not already loaded
	tooltip_scene = preload("res://Scenes/UIScenes/tooltip_display.tscn")

func show_tooltip(tower_name: String, position: Vector2) -> void:
	# Hide any existing tooltip
	hide_tooltip()
	
	# Check if tower data exists
	if not tower_name in tooltip_data:
		return
	
	var data = tooltip_data[tower_name]
	
	# Create tooltip instance
	active_tooltip = tooltip_scene.instantiate()
	add_child(active_tooltip)
	active_tooltip.global_position = position
	
	# Set tooltip content
	active_tooltip.set_content(data)
	active_tooltip.show_tooltip()

func hide_tooltip() -> void:
	if active_tooltip:
		active_tooltip.hide_tooltip()
		await get_tree().create_timer(0.3).timeout  # Wait for animation
		active_tooltip.queue_free()
		active_tooltip = null

func update_tower_data(tower_name: String, new_data: Dictionary) -> void:
	if tower_name in tooltip_data:
		tooltip_data[tower_name].merge(new_data)

# Helper to get tooltip for a tower
func get_tooltip_text(tower_name: String) -> String:
	if tower_name in tooltip_data:
		var data = tooltip_data[tower_name]
		return "%s\nCost: %d | Damage: %d | Range: %d\n%s" % [
			data["name"],
			data["cost"],
			data["damage"],
			data["range"],
			data["description"]
		]
	return ""
