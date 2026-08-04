extends Node

# Display names for all tower types (mirrors ui.gd _tower_display_name())
const TOWER_DISPLAY_NAMES: Dictionary = {
	"PitikKawayan":        "Pitik-Kawayan",
	"SharpenedBamboo":     "Sharpened Bamboo",
	"TwinShooters":        "Twin Shooters",
	"KampilanDefender":    "Kampilan Defender",
	"HeatedBlade":         "Heated Blade",
	"WideSweep":           "Wide Sweep",
	"BawangBallista":      "Bawang Ballista",
	"HeavyCloves":         "Heavy Cloves",
	"SaltTreatedWood":     "Salt Treated Wood",
	"MutyaFocus":          "Mutya Focus",
	"RefractedLight":      "Refracted Light",
	"Intensify":           "Intensify",
	"AgimatMortar":        "Agimat Mortar",
	"GuidedTalismans":     "Guided Talismans",
	"ShrapnelBurst":       "Shrapnel Burst",
	"ParolNgLiwanag":      "Parol ng Liwanag",
	"BrightOil":           "Bright Oil",
	"SearingLight":        "Searing Light",
	"BaleteRootSnare":     "Balete Root-Snare",
	"DeepRoots":           "Deep Roots",
	"ThornyVines":         "Thorny Vines",
	"KidlatWeaver":        "Kidlat Weaver",
	"StaticCharge":        "Static Charge",
	"HighVoltage":         "High Voltage",
	"SibatPiercer":        "Sibat Piercer",
	"IronTipped":          "Iron Tipped",
	"WeightedShafts":      "Weighted Shafts",
	"HabingLiwanagShrine": "Habing Liwanag Shrine",
	"WovenThreads":        "Woven Threads",
	"SanghayasBlessing":   "Sanghayas' Blessing",
}

# Static tooltips for UI elements (buttons, menus — not towers)
var tooltip_data: Dictionary = {
	"PauseButton": {
		"name":        "Pause / Play",
		"description": "Pause or resume the game to plan your next move"
	},
	"SpeedUpButton": {
		"name":        "Speed Up",
		"description": "Toggle 2x game speed for faster waves"
	},
	"HelpButton": {
		"name":        "Tutorial",
		"description": "Replay the tutorial walkthrough"
	},
	"MenuButton": {
		"name":        "Menu",
		"description": "Open the pause menu to adjust settings or return to main menu"
	},
	"StartWaveButton": {
		"name":        "Start Wave",
		"description": "Send the next wave of enemies. Prepare your defenses first!"
	},
	"GoldDisplay": {
		"name":        "Gold",
		"description": "Your current gold. Earn more by defeating enemies. Spend it to build towers."
	},
	"HealthBar": {
		"name":        "Base Health",
		"description": "Your base health. Enemies that reach the end deal damage. Hits zero = game over!"
	},
	"WavePreview": {
		"name":        "Wave Preview",
		"description": "Shows what enemies are coming in the next wave so you can plan ahead"
	},
}

var active_tooltip = null
var tooltip_scene  = null

func _ready() -> void:
	tooltip_scene = preload("res://Scenes/UIScenes/tooltip_display.tscn")

func show_tooltip(tower_name: String, button_pos: Vector2) -> void:
	hide_tooltip()

	var data: Dictionary = {}

	if tower_name in tooltip_data:
		# UI button or other static entry
		data = tooltip_data[tower_name]
	elif GameData.tower_data.has(tower_name):
		# Build rich data directly from GameData — no duplication needed
		var td: Dictionary = GameData.tower_data[tower_name]
		data = {
			"name":        TOWER_DISPLAY_NAMES.get(tower_name, tower_name),
			"description": td.get("description", ""),
			"cost":        td.get("cost",     0),
			"damage":      td.get("damage",   0),
			"range":       td.get("range",    0),
			"rof":         td.get("rof",      1.0),
			"category":    td.get("category", ""),
			"rarity":      td.get("rarity",   "common"),
		}
	else:
		return

	active_tooltip = tooltip_scene.instantiate()
	add_child(active_tooltip)
	active_tooltip.set_position(button_pos)
	active_tooltip.set_content(data)
	active_tooltip.show_tooltip()

func hide_tooltip() -> void:
	if active_tooltip:
		var tooltip_to_hide = active_tooltip
		active_tooltip = null
		tooltip_to_hide.hide_tooltip()
		await get_tree().create_timer(0.15).timeout
		if tooltip_to_hide:
			tooltip_to_hide.queue_free()

func update_tower_data(tower_name: String, new_data: Dictionary) -> void:
	if tower_name in tooltip_data:
		tooltip_data[tower_name].merge(new_data)

func get_tooltip_text(tower_name: String) -> String:
	if GameData.tower_data.has(tower_name):
		var td = GameData.tower_data[tower_name]
		return "%s\nCost: %d | Damage: %d | Range: %d\n%s" % [
			TOWER_DISPLAY_NAMES.get(tower_name, tower_name),
			td.get("cost", 0), td.get("damage", 0), td.get("range", 0),
			td.get("description", "")
		]
	if tower_name in tooltip_data:
		var d = tooltip_data[tower_name]
		return "%s\n%s" % [d.get("name", tower_name), d.get("description", "")]
	return ""
