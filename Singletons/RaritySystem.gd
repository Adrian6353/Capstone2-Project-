extends Node
## Rarity System singleton - provides helper methods for tower rarity mechanics

# Rarity color codes
const RARITY_COLORS = {
	"common": Color.GREEN,
	"rare": Color.BLUE,
	"epic": Color.GOLD,
	"legendary": Color.GOLD
}

# Rarity symbols/badges for UI display
const RARITY_SYMBOLS = {
	"common": "🟢",
	"rare": "🔵",
	"epic": "⭐",
	"legendary": "⭐"
}

# Rarity names for display
const RARITY_NAMES = {
	"common": "Common",
	"rare": "Rare",
	"epic": "Epic",
	"legendary": "Legendary"
}

## Get the color for a specific rarity
func get_rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)

## Get the symbol/badge for a specific rarity
func get_rarity_symbol(rarity: String) -> String:
	return RARITY_SYMBOLS.get(rarity, "")

## Get the display name for a specific rarity
func get_rarity_name(rarity: String) -> String:
	return RARITY_NAMES.get(rarity, "Unknown")

## Get the rarity of a tower
func get_tower_rarity(tower_type: String) -> String:
	return GameData.tower_data.get(tower_type, {}).get("rarity", "common")

## Get the base cost of a tower
func get_tower_base_cost(tower_type: String) -> int:
	return GameData.tower_data.get(tower_type, {}).get("cost", 0)

## Get the card requirement for a tower
func get_tower_card_requirement(tower_type: String) -> int:
	return GameData.cards_required_to_build.get(tower_type, 0)

## Get a formatted tower name with rarity symbol
func get_formatted_tower_name(tower_type: String) -> String:
	var tower_data = GameData.tower_data.get(tower_type, {})
	var rarity = tower_data.get("rarity", "common")
	
	# Convert camelCase to Human Readable Name
	var readable_name = _camel_to_human(tower_type)
	var symbol = get_rarity_symbol(rarity)
	
	if symbol:
		return "%s %s" % [symbol, readable_name]
	return readable_name

## Convert camelCase string to Human Readable Name
func _camel_to_human(camel_case: String) -> String:
	var result = ""
	for i in range(camel_case.length()):
		var ch = camel_case[i]
		if i > 0 and ch.to_upper() == ch:
			result += " " + ch
		else:
			if i == 0:
				result += ch.to_upper()
			else:
				result += ch
	return result

## Apply rarity color modulation to a Sprite2D node
func apply_rarity_tint(sprite: Sprite2D, rarity: String) -> void:
	if sprite:
		sprite.modulate = get_rarity_color(rarity)

## Get color-coded cost display string
func get_cost_display(tower_type: String) -> String:
	var cost = get_tower_base_cost(tower_type)
	var color = get_rarity_color(get_tower_rarity(tower_type))
	return "[color=%s]%dg[/color]" % [color.to_html(), cost]
