extends Node

var selected_map = "res://Scenes/Maps/Map1_v2.tscn"
var game_mode = "normal"
var dev_mode_enabled: bool = false  # Session-only; never saved to disk or Firebase
var selected_player_count = 1  # 1 or 2 players
var selected_wave_count = 3  # 3, 5, or 10 waves
var _cached_waves: Array = []       # Cache for retrieve_wave_data()
var _cached_waves_key: String = ""  # "player_count:wave_count" — invalidated when either changes
var selected_chapter = -1   # Chapter selection (set by map_selection.gd)
var selected_map_index = -1 # Map within chapter 1-5 (set by map_selection.gd)

## Story mode map registry — 10 chapters × 4 maps each (maps 1-3 regular, map 4 boss).
## All entries point to MapTemplate until the real scene is ready.
## To add a finished map: replace the corresponding path here.
const STORY_MAP_SCENES: Dictionary = {
	1:  {1: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 2: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 3: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 4: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn"},
	2:  {1: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 2: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 3: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 4: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn"},
	3:  {1: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 2: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 3: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 4: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn"},
	4:  {1: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 2: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 3: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 4: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn"},
	5:  {1: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 2: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 3: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 4: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn"},
	6:  {1: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 2: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 3: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 4: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn"},
	7:  {1: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 2: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 3: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 4: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn"},
	8:  {1: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 2: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 3: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 4: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn"},
	9:  {1: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 2: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 3: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 4: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn"},
	10: {1: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 2: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 3: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn",
		 4: "res://Scenes/Maps/MainQuests/Map_Template/MapTemplate.tscn"},
}

# Current game session tracking (for ranking)
var current_session_map = ""
var current_session_best_waves = 0
var current_wave = 1

const SETTINGS_DIR = "user://tower_defense_data"
const SETTINGS_FILE_PATH = SETTINGS_DIR + "/settings.cfg"

func save_audio_settings(settings: Dictionary) -> void:
	_ensure_settings_dir()

	var config = ConfigFile.new()
	if FileAccess.file_exists(SETTINGS_FILE_PATH):
		config.load(SETTINGS_FILE_PATH)

	config.set_value("audio", "master_volume", settings.get("master_volume", 1.0))
	config.set_value("audio", "sfx_volume", settings.get("sfx_volume", 1.0))
	config.set_value("audio", "music_volume", settings.get("music_volume", 0.8))
	config.set_value("audio", "ui_volume", settings.get("ui_volume", 0.9))
	config.set_value("audio", "sounds_enabled", settings.get("sounds_enabled", true))
	config.save(SETTINGS_FILE_PATH)

func load_audio_settings() -> Dictionary:
	var defaults = {
		"master_volume": 1.0,
		"sfx_volume": 1.0,
		"music_volume": 0.8,
		"ui_volume": 0.9,
		"sounds_enabled": true,
	}

	if not FileAccess.file_exists(SETTINGS_FILE_PATH):
		return defaults

	var config = ConfigFile.new()
	if config.load(SETTINGS_FILE_PATH) != OK:
		return defaults

	return {
		"master_volume": config.get_value("audio", "master_volume", defaults["master_volume"]),
		"sfx_volume": config.get_value("audio", "sfx_volume", defaults["sfx_volume"]),
		"music_volume": config.get_value("audio", "music_volume", defaults["music_volume"]),
		"ui_volume": config.get_value("audio", "ui_volume", defaults["ui_volume"]),
		"sounds_enabled": config.get_value("audio", "sounds_enabled", defaults["sounds_enabled"]),
	}

func _ensure_settings_dir() -> void:
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("tower_defense_data"):
		dir.make_dir("tower_defense_data")

# Economy system variables
const REFUND_PERCENTAGE: float = 0.75  # Fraction of cost refunded when selling a tower
var starting_money = 500
var current_money = 500

# Co-op mode state
var is_coop: bool = false
## Per-player gold pools when is_coop is true.  Key 1 = host (P1), 2 = client (P2).
var player_gold: Dictionary = {1: 500, 2: 500}
## Gold belonging to the remote partner (read-only display, updated via RPC).
var partner_gold: int = 500

# Tower family registry. Families are permanently unlocked through lootboxes.
var tower_families = {
	# Family Name: {"towers": [level1, level2, level3], "rarity": "common|rare|legendary"}
	"PitikKawayan": {"towers": ["PitikKawayan", "SharpenedBamboo", "TwinShooters"], "rarity": "common"},
	"KampilanDefender": {"towers": ["KampilanDefender", "HeatedBlade", "WideSweep"], "rarity": "common"},
	"BawangBallista": {"towers": ["BawangBallista", "HeavyCloves", "SaltTreatedWood"], "rarity": "common"},
	"MutyaFocus": {"towers": ["MutyaFocus", "RefractedLight", "Intensify"], "rarity": "rare"},
	"AgimatMortar": {"towers": ["AgimatMortar", "GuidedTalismans", "ShrapnelBurst"], "rarity": "rare"},
	"ParolNgLiwanag": {"towers": ["ParolNgLiwanag", "BrightOil", "SearingLight"], "rarity": "rare"},
	"BaleteRootSnare": {"towers": ["BaleteRootSnare", "DeepRoots", "ThornyVines"], "rarity": "rare"},
	"KidlatWeaver": {"towers": ["KidlatWeaver", "StaticCharge", "HighVoltage"], "rarity": "legendary"},
	"SibatPiercer": {"towers": ["SibatPiercer", "IronTipped", "WeightedShafts"], "rarity": "legendary"},
	"HabingLiwanagShrine": {"towers": ["HabingLiwanagShrine", "WovenThreads", "SanghayasBlessing"], "rarity": "legendary"}
}

# Card Hunt Mode variables
var collected_cards = {}  # {"TowerT1": 2, "TowerT2": 1, etc}

# Card rarity system (now mirrors tower family rarity, not individual levels)
var card_rarities = {
	# Common towers (available from wave 1)
	"PitikKawayan": "common",
	"SharpenedBamboo": "common",
	"TwinShooters": "common",
	"KampilanDefender": "common",
	"HeatedBlade": "common",
	"WideSweep": "common",
	"BawangBallista": "common",
	"HeavyCloves": "common",
	"SaltTreatedWood": "common",
	# Rare towers (available from wave 4)
	"MutyaFocus": "rare",
	"RefractedLight": "rare",
	"Intensify": "rare",
	"AgimatMortar": "rare",
	"GuidedTalismans": "rare",
	"ShrapnelBurst": "rare",
	"ParolNgLiwanag": "rare",
	"BrightOil": "rare",
	"SearingLight": "rare",
	"BaleteRootSnare": "rare",
	"DeepRoots": "rare",
	"ThornyVines": "rare",
	# Legendary towers (available from wave 8)
	"KidlatWeaver": "legendary",
	"StaticCharge": "legendary",
	"HighVoltage": "legendary",
	"SibatPiercer": "legendary",
	"IronTipped": "legendary",
	"WeightedShafts": "legendary",
	"HabingLiwanagShrine": "legendary",
	"WovenThreads": "legendary",
	"SanghayasBlessing": "legendary",
	"BambooTower": "common"
}

var rarity_colors = {
	"common": Color.GREEN,
	"rare": Color.BLUE,
	"epic": Color.GOLD,
	"legendary": Color.GOLD
}

# Cards required to build each tower in card hunt mode
var cards_required_to_build = {
	"PitikKawayan": 0,
	"SharpenedBamboo": 2,
	"TwinShooters": 2,
	"KampilanDefender": 0,
	"HeatedBlade": 2,
	"WideSweep": 2,
	"BawangBallista": 0,
	"HeavyCloves": 2,
	"SaltTreatedWood": 2,
	"MutyaFocus": 0,
	"RefractedLight": 2,
	"Intensify": 2,
	"AgimatMortar": 0,
	"GuidedTalismans": 2,
	"ShrapnelBurst": 2,
	"ParolNgLiwanag": 0,
	"BrightOil": 2,
	"SearingLight": 2,
	"BaleteRootSnare": 0,
	"DeepRoots": 2,
	"ThornyVines": 2,
	"KidlatWeaver": 0,
	"StaticCharge": 2,
	"HighVoltage": 2,
	"SibatPiercer": 0,
	"IronTipped": 2,
	"WeightedShafts": 2,
	"HabingLiwanagShrine": 0,
	"WovenThreads": 2,
	"SanghayasBlessing": 2,
	"BambooTower": 0
}

# Enemy-specific card drop rates (all towers available from all enemies)
var enemy_drop_rates = {
	"Dwende": {
		"PitikKawayan": 1.0, "SharpenedBamboo": 0.3, "TwinShooters": 0.3,
		"KampilanDefender": 0.8, "HeatedBlade": 0.2, "WideSweep": 0.2,
		"BawangBallista": 0.6, "HeavyCloves": 0.15, "SaltTreatedWood": 0.15,
		"MutyaFocus": 0.4, "RefractedLight": 0.1, "Intensify": 0.1,
		"AgimatMortar": 0.3, "GuidedTalismans": 0.08, "ShrapnelBurst": 0.08,
		"ParolNgLiwanag": 0.5, "BrightOil": 0.12, "SearingLight": 0.12,
		"BaleteRootSnare": 0.5, "DeepRoots": 0.1, "ThornyVines": 0.1,
		"KidlatWeaver": 0.4, "StaticCharge": 0.08, "HighVoltage": 0.08,
		"SibatPiercer": 0.3, "IronTipped": 0.08, "WeightedShafts": 0.08, "HabingLiwanagShrine": 0.2, "WovenThreads": 0.05, "SanghayasBlessing": 0.05,
		"BambooTower": 1.0
	},
	"Manananggal": {
		"PitikKawayan": 1.0, "SharpenedBamboo": 0.35, "TwinShooters": 0.35,
		"KampilanDefender": 0.85, "HeatedBlade": 0.25, "WideSweep": 0.25,
		"BawangBallista": 1.2, "HeavyCloves": 0.4, "SaltTreatedWood": 0.4,
		"MutyaFocus": 0.5, "RefractedLight": 0.15, "Intensify": 0.15,
		"AgimatMortar": 0.4, "GuidedTalismans": 0.1, "ShrapnelBurst": 0.1,
		"ParolNgLiwanag": 0.6, "BrightOil": 0.15, "SearingLight": 0.15,
		"BaleteRootSnare": 0.5, "DeepRoots": 0.1, "ThornyVines": 0.1,
		"KidlatWeaver": 0.5, "StaticCharge": 0.1, "HighVoltage": 0.1,
		"SibatPiercer": 0.4, "IronTipped": 0.1, "WeightedShafts": 0.1, "HabingLiwanagShrine": 0.2, "WovenThreads": 0.05, "SanghayasBlessing": 0.05,
		"BambooTower": 1.0
	},
	"Batibat": {
		"PitikKawayan": 1.0, "SharpenedBamboo": 0.25, "TwinShooters": 0.25,
		"KampilanDefender": 0.7, "HeatedBlade": 0.15, "WideSweep": 0.15,
		"BawangBallista": 0.4, "HeavyCloves": 0.1, "SaltTreatedWood": 0.1,
		"MutyaFocus": 0.3, "RefractedLight": 0.08, "Intensify": 0.08,
		"AgimatMortar": 0.2, "GuidedTalismans": 0.05, "ShrapnelBurst": 0.05,
		"ParolNgLiwanag": 0.4, "BrightOil": 0.1, "SearingLight": 0.1,
		"BaleteRootSnare": 0.4, "DeepRoots": 0.08, "ThornyVines": 0.08,
		"KidlatWeaver": 0.3, "StaticCharge": 0.05, "HighVoltage": 0.05,
		"SibatPiercer": 0.2, "IronTipped": 0.05, "WeightedShafts": 0.05, "HabingLiwanagShrine": 0.15, "WovenThreads": 0.03, "SanghayasBlessing": 0.03,
		"BambooTower": 1.0
	},
	"CursedVillager": {
		"PitikKawayan": 1.0, "SharpenedBamboo": 0.3, "TwinShooters": 0.3,
		"KampilanDefender": 0.8, "HeatedBlade": 0.2, "WideSweep": 0.2,
		"BawangBallista": 0.5, "HeavyCloves": 0.12, "SaltTreatedWood": 0.12,
		"MutyaFocus": 0.35, "RefractedLight": 0.1, "Intensify": 0.1,
		"AgimatMortar": 0.25, "GuidedTalismans": 0.07, "ShrapnelBurst": 0.07,
		"ParolNgLiwanag": 0.45, "BrightOil": 0.1, "SearingLight": 0.1,
		"BaleteRootSnare": 0.45, "DeepRoots": 0.1, "ThornyVines": 0.1,
		"KidlatWeaver": 0.35, "StaticCharge": 0.07, "HighVoltage": 0.07,
		"SibatPiercer": 0.25, "IronTipped": 0.07, "WeightedShafts": 0.07, "HabingLiwanagShrine": 0.18, "WovenThreads": 0.04, "SanghayasBlessing": 0.04,
		"BambooTower": 1.0
	},
	"NunoSaPunso": {
		"PitikKawayan": 1.0, "SharpenedBamboo": 0.28, "TwinShooters": 0.28,
		"KampilanDefender": 0.75, "HeatedBlade": 0.18, "WideSweep": 0.18,
		"BawangBallista": 0.45, "HeavyCloves": 0.1, "SaltTreatedWood": 0.1,
		"MutyaFocus": 0.3, "RefractedLight": 0.08, "Intensify": 0.08,
		"AgimatMortar": 0.22, "GuidedTalismans": 0.06, "ShrapnelBurst": 0.06,
		"ParolNgLiwanag": 0.4, "BrightOil": 0.09, "SearingLight": 0.09,
		"BaleteRootSnare": 0.42, "DeepRoots": 0.09, "ThornyVines": 0.09,
		"KidlatWeaver": 0.3, "StaticCharge": 0.06, "HighVoltage": 0.06,
		"SibatPiercer": 0.22, "IronTipped": 0.06, "WeightedShafts": 0.06, "HabingLiwanagShrine": 0.16, "WovenThreads": 0.04, "SanghayasBlessing": 0.04,
		"BambooTower": 1.0
	},
	"InsectController": {
		"PitikKawayan": 1.0, "SharpenedBamboo": 0.3, "TwinShooters": 0.3,
		"KampilanDefender": 0.78, "HeatedBlade": 0.19, "WideSweep": 0.19,
		"BawangBallista": 0.52, "HeavyCloves": 0.13, "SaltTreatedWood": 0.13,
		"MutyaFocus": 0.32, "RefractedLight": 0.09, "Intensify": 0.09,
		"AgimatMortar": 0.24, "GuidedTalismans": 0.065, "ShrapnelBurst": 0.065,
		"ParolNgLiwanag": 0.42, "BrightOil": 0.11, "SearingLight": 0.11,
		"BaleteRootSnare": 0.44, "DeepRoots": 0.095, "ThornyVines": 0.095,
		"KidlatWeaver": 0.32, "StaticCharge": 0.065, "HighVoltage": 0.065,
		"SibatPiercer": 0.24, "IronTipped": 0.065, "WeightedShafts": 0.065, "HabingLiwanagShrine": 0.17, "WovenThreads": 0.045, "SanghayasBlessing": 0.045,
		"BambooTower": 1.0
	},
	"Kapre": {
		"PitikKawayan": 0.8, "SharpenedBamboo": 0.4, "TwinShooters": 0.4,
		"KampilanDefender": 1.0, "HeatedBlade": 0.35, "WideSweep": 0.35,
		"BawangBallista": 0.6, "HeavyCloves": 0.2, "SaltTreatedWood": 0.2,
		"MutyaFocus": 0.5, "RefractedLight": 0.15, "Intensify": 0.15,
		"AgimatMortar": 0.45, "GuidedTalismans": 0.12, "ShrapnelBurst": 0.12,
		"ParolNgLiwanag": 0.55, "BrightOil": 0.15, "SearingLight": 0.15,
		"BaleteRootSnare": 0.6, "DeepRoots": 0.15, "ThornyVines": 0.15,
		"KidlatWeaver": 0.5, "StaticCharge": 0.12, "HighVoltage": 0.12,
		"SibatPiercer": 0.45, "IronTipped": 0.12, "WeightedShafts": 0.12, "HabingLiwanagShrine": 0.3, "WovenThreads": 0.08, "SanghayasBlessing": 0.08,
		"BambooTower": 0.8
	},
	"Sigben": {
		"PitikKawayan": 0.75, "SharpenedBamboo": 0.42, "TwinShooters": 0.42,
		"KampilanDefender": 1.05, "HeatedBlade": 0.37, "WideSweep": 0.37,
		"BawangBallista": 0.65, "HeavyCloves": 0.22, "SaltTreatedWood": 0.22,
		"MutyaFocus": 0.55, "RefractedLight": 0.17, "Intensify": 0.17,
		"AgimatMortar": 0.5, "GuidedTalismans": 0.13, "ShrapnelBurst": 0.13,
		"ParolNgLiwanag": 0.6, "BrightOil": 0.16, "SearingLight": 0.16,
		"BaleteRootSnare": 0.65, "DeepRoots": 0.17, "ThornyVines": 0.17,
		"KidlatWeaver": 0.55, "StaticCharge": 0.13, "HighVoltage": 0.13,
		"SibatPiercer": 0.5, "IronTipped": 0.13, "WeightedShafts": 0.13, "HabingLiwanagShrine": 0.32, "WovenThreads": 0.09, "SanghayasBlessing": 0.09,
		"BambooTower": 0.75
	},
	"Trickster": {
		"PitikKawayan": 0.7, "SharpenedBamboo": 0.45, "TwinShooters": 0.45,
		"KampilanDefender": 1.1, "HeatedBlade": 0.4, "WideSweep": 0.4,
		"BawangBallista": 0.7, "HeavyCloves": 0.25, "SaltTreatedWood": 0.25,
		"MutyaFocus": 0.6, "RefractedLight": 0.2, "Intensify": 0.2,
		"AgimatMortar": 0.55, "GuidedTalismans": 0.15, "ShrapnelBurst": 0.15,
		"ParolNgLiwanag": 0.65, "BrightOil": 0.18, "SearingLight": 0.18,
		"BaleteRootSnare": 0.7, "DeepRoots": 0.2, "ThornyVines": 0.2,
		"KidlatWeaver": 0.6, "StaticCharge": 0.15, "HighVoltage": 0.15,
		"SibatPiercer": 0.55, "IronTipped": 0.15, "WeightedShafts": 0.15, "HabingLiwanagShrine": 0.35, "WovenThreads": 0.1, "SanghayasBlessing": 0.1,
		"BambooTower": 0.7
	},
	"DarkCreature": {
		"PitikKawayan": 0.65, "SharpenedBamboo": 0.48, "TwinShooters": 0.48,
		"KampilanDefender": 1.15, "HeatedBlade": 0.42, "WideSweep": 0.42,
		"BawangBallista": 0.75, "HeavyCloves": 0.28, "SaltTreatedWood": 0.28,
		"MutyaFocus": 0.65, "RefractedLight": 0.22, "Intensify": 0.22,
		"AgimatMortar": 0.6, "GuidedTalismans": 0.17, "ShrapnelBurst": 0.17,
		"ParolNgLiwanag": 0.7, "BrightOil": 0.2, "SearingLight": 0.2,
		"BaleteRootSnare": 0.75, "DeepRoots": 0.22, "ThornyVines": 0.22,
		"KidlatWeaver": 0.65, "StaticCharge": 0.17, "HighVoltage": 0.17,
		"SibatPiercer": 0.6, "IronTipped": 0.17, "WeightedShafts": 0.17, "HabingLiwanagShrine": 0.38, "WovenThreads": 0.11, "SanghayasBlessing": 0.11,
		"BambooTower": 0.65
	},
	"Ghoul": {
		"PitikKawayan": 0.6, "SharpenedBamboo": 0.5, "TwinShooters": 0.5,
		"KampilanDefender": 1.2, "HeatedBlade": 0.44, "WideSweep": 0.44,
		"BawangBallista": 0.8, "HeavyCloves": 0.3, "SaltTreatedWood": 0.3,
		"MutyaFocus": 0.7, "RefractedLight": 0.24, "Intensify": 0.24,
		"AgimatMortar": 0.65, "GuidedTalismans": 0.19, "ShrapnelBurst": 0.19,
		"ParolNgLiwanag": 0.75, "BrightOil": 0.22, "SearingLight": 0.22,
		"BaleteRootSnare": 0.8, "DeepRoots": 0.24, "ThornyVines": 0.24,
		"KidlatWeaver": 0.7, "StaticCharge": 0.19, "HighVoltage": 0.19,
		"SibatPiercer": 0.65, "IronTipped": 0.19, "WeightedShafts": 0.19, "HabingLiwanagShrine": 0.4, "WovenThreads": 0.12, "SanghayasBlessing": 0.12,
		"BambooTower": 0.6
	},
	"Mambabarang": {
		"PitikKawayan": 0.5, "SharpenedBamboo": 0.55, "TwinShooters": 0.55,
		"KampilanDefender": 1.25, "HeatedBlade": 0.5, "WideSweep": 0.5,
		"BawangBallista": 0.85, "HeavyCloves": 0.35, "SaltTreatedWood": 0.35,
		"MutyaFocus": 0.75, "RefractedLight": 0.28, "Intensify": 0.28,
		"AgimatMortar": 1.0, "GuidedTalismans": 0.3, "ShrapnelBurst": 0.3,
		"ParolNgLiwanag": 0.4, "BrightOil": 0.1, "SearingLight": 0.1,
		"BaleteRootSnare": 0.85, "DeepRoots": 0.3, "ThornyVines": 0.3,
		"KidlatWeaver": 0.75, "StaticCharge": 0.25, "HighVoltage": 0.25,
		"SibatPiercer": 0.7, "IronTipped": 0.22, "WeightedShafts": 0.22, "HabingLiwanagShrine": 0.42, "WovenThreads": 0.13, "SanghayasBlessing": 0.13,
		"BambooTower": 0.5
	},
	"DarkEngkanto": {
		"PitikKawayan": 0.45, "SharpenedBamboo": 0.58, "TwinShooters": 0.58,
		"KampilanDefender": 1.3, "HeatedBlade": 0.55, "WideSweep": 0.55,
		"BawangBallista": 0.9, "HeavyCloves": 0.38, "SaltTreatedWood": 0.38,
		"MutyaFocus": 0.8, "RefractedLight": 0.3, "Intensify": 0.3,
		"AgimatMortar": 1.05, "GuidedTalismans": 0.32, "ShrapnelBurst": 0.32,
		"ParolNgLiwanag": 0.35, "BrightOil": 0.08, "SearingLight": 0.08,
		"BaleteRootSnare": 0.9, "DeepRoots": 0.35, "ThornyVines": 0.35,
		"KidlatWeaver": 0.8, "StaticCharge": 0.28, "HighVoltage": 0.28,
		"SibatPiercer": 0.75, "IronTipped": 0.25, "WeightedShafts": 0.25, "HabingLiwanagShrine": 0.45, "WovenThreads": 0.14, "SanghayasBlessing": 0.14,
		"BambooTower": 0.45
	},
	"CorruptedSpirit": {
		"PitikKawayan": 0.4, "SharpenedBamboo": 0.6, "TwinShooters": 0.6,
		"KampilanDefender": 1.35, "HeatedBlade": 0.58, "WideSweep": 0.58,
		"BawangBallista": 0.95, "HeavyCloves": 0.4, "SaltTreatedWood": 0.4,
		"MutyaFocus": 0.85, "RefractedLight": 0.32, "Intensify": 0.32,
		"AgimatMortar": 1.1, "GuidedTalismans": 0.35, "ShrapnelBurst": 0.35,
		"ParolNgLiwanag": 0.3, "BrightOil": 0.07, "SearingLight": 0.07,
		"BaleteRootSnare": 0.95, "DeepRoots": 0.38, "ThornyVines": 0.38,
		"KidlatWeaver": 0.85, "StaticCharge": 0.3, "HighVoltage": 0.3,
		"SibatPiercer": 0.8, "IronTipped": 0.28, "WeightedShafts": 0.28, "HabingLiwanagShrine": 0.48, "WovenThreads": 0.15, "SanghayasBlessing": 0.15,
		"BambooTower": 0.4
	},
	"ElemSpirit": {
		"PitikKawayan": 0.35, "SharpenedBamboo": 0.62, "TwinShooters": 0.62,
		"KampilanDefender": 1.4, "HeatedBlade": 0.6, "WideSweep": 0.6,
		"BawangBallista": 1.0, "HeavyCloves": 0.42, "SaltTreatedWood": 0.42,
		"MutyaFocus": 0.9, "RefractedLight": 0.35, "Intensify": 0.35,
		"AgimatMortar": 1.15, "GuidedTalismans": 0.37, "ShrapnelBurst": 0.37,
		"ParolNgLiwanag": 0.25, "BrightOil": 0.05, "SearingLight": 0.05,
		"BaleteRootSnare": 1.0, "DeepRoots": 0.4, "ThornyVines": 0.4,
		"KidlatWeaver": 1.0, "StaticCharge": 0.35, "HighVoltage": 0.35,
		"SibatPiercer": 0.85, "IronTipped": 0.3, "WeightedShafts": 0.3, "HabingLiwanagShrine": 0.5, "WovenThreads": 0.16, "SanghayasBlessing": 0.16,
		"BambooTower": 0.35
	},
	"Tikbalang": {
		"PitikKawayan": 0.3, "SharpenedBamboo": 0.65, "TwinShooters": 0.65,
		"KampilanDefender": 1.45, "HeatedBlade": 0.65, "WideSweep": 0.65,
		"BawangBallista": 0.5, "HeavyCloves": 0.2, "SaltTreatedWood": 0.2,
		"MutyaFocus": 1.2, "RefractedLight": 0.5, "Intensify": 0.5,
		"AgimatMortar": 1.2, "GuidedTalismans": 0.4, "ShrapnelBurst": 0.4,
		"ParolNgLiwanag": 0.5, "BrightOil": 0.15, "SearingLight": 0.15,
		"BaleteRootSnare": 0.6, "DeepRoots": 0.2, "ThornyVines": 0.2,
		"KidlatWeaver": 0.9, "StaticCharge": 0.35, "HighVoltage": 0.35,
		"SibatPiercer": 0.9, "IronTipped": 0.35, "WeightedShafts": 0.35, "HabingLiwanagShrine": 0.55, "WovenThreads": 0.18, "SanghayasBlessing": 0.18,
		"BambooTower": 0.3
	},
	"Wakwak": {
		"PitikKawayan": 0.25, "SharpenedBamboo": 0.7, "TwinShooters": 0.7,
		"KampilanDefender": 1.5, "HeatedBlade": 0.7, "WideSweep": 0.7,
		"BawangBallista": 0.4, "HeavyCloves": 0.15, "SaltTreatedWood": 0.15,
		"MutyaFocus": 1.25, "RefractedLight": 0.52, "Intensify": 0.52,
		"AgimatMortar": 1.25, "GuidedTalismans": 0.42, "ShrapnelBurst": 0.42,
		"ParolNgLiwanag": 0.55, "BrightOil": 0.18, "SearingLight": 0.18,
		"BaleteRootSnare": 0.55, "DeepRoots": 0.18, "ThornyVines": 0.18,
		"KidlatWeaver": 0.95, "StaticCharge": 0.38, "HighVoltage": 0.38,
		"SibatPiercer": 0.95, "IronTipped": 0.38, "WeightedShafts": 0.38, "HabingLiwanagShrine": 0.58, "WovenThreads": 0.2, "SanghayasBlessing": 0.2,
		"BambooTower": 0.25
	},
	"Mandurugo": {
		"PitikKawayan": 0.28, "SharpenedBamboo": 0.68, "TwinShooters": 0.68,
		"KampilanDefender": 1.48, "HeatedBlade": 0.68, "WideSweep": 0.68,
		"BawangBallista": 0.38, "HeavyCloves": 0.13, "SaltTreatedWood": 0.13,
		"MutyaFocus": 1.23, "RefractedLight": 0.51, "Intensify": 0.51,
		"AgimatMortar": 1.23, "GuidedTalismans": 0.41, "ShrapnelBurst": 0.41,
		"ParolNgLiwanag": 0.53, "BrightOil": 0.17, "SearingLight": 0.17,
		"BaleteRootSnare": 0.57, "DeepRoots": 0.19, "ThornyVines": 0.19,
		"KidlatWeaver": 0.93, "StaticCharge": 0.37, "HighVoltage": 0.37,
		"SibatPiercer": 0.93, "IronTipped": 0.37, "WeightedShafts": 0.37, "HabingLiwanagShrine": 0.56, "WovenThreads": 0.19, "SanghayasBlessing": 0.19,
		"BambooTower": 0.28
	},
	"Tiyanak": {
		"PitikKawayan": 0.22, "SharpenedBamboo": 0.72, "TwinShooters": 0.72,
		"KampilanDefender": 1.52, "HeatedBlade": 0.72, "WideSweep": 0.72,
		"BawangBallista": 0.32, "HeavyCloves": 0.1, "SaltTreatedWood": 0.1,
		"MutyaFocus": 1.27, "RefractedLight": 0.54, "Intensify": 0.54,
		"AgimatMortar": 1.27, "GuidedTalismans": 0.43, "ShrapnelBurst": 0.43,
		"ParolNgLiwanag": 0.57, "BrightOil": 0.19, "SearingLight": 0.19,
		"BaleteRootSnare": 0.53, "DeepRoots": 0.17, "ThornyVines": 0.17,
		"KidlatWeaver": 0.97, "StaticCharge": 0.39, "HighVoltage": 0.39,
		"SibatPiercer": 0.97, "IronTipped": 0.39, "WeightedShafts": 0.39, "HabingLiwanagShrine": 0.6, "WovenThreads": 0.21, "SanghayasBlessing": 0.21,
		"BambooTower": 0.22
	},
	"EliteDeleketnon": {
		"PitikKawayan": 0.2, "SharpenedBamboo": 0.74, "TwinShooters": 0.74,
		"KampilanDefender": 1.54, "HeatedBlade": 0.74, "WideSweep": 0.74,
		"BawangBallista": 0.3, "HeavyCloves": 0.09, "SaltTreatedWood": 0.09,
		"MutyaFocus": 1.29, "RefractedLight": 0.55, "Intensify": 0.55,
		"AgimatMortar": 1.29, "GuidedTalismans": 0.44, "ShrapnelBurst": 0.44,
		"ParolNgLiwanag": 0.59, "BrightOil": 0.2, "SearingLight": 0.2,
		"BaleteRootSnare": 0.51, "DeepRoots": 0.16, "ThornyVines": 0.16,
		"KidlatWeaver": 0.99, "StaticCharge": 0.4, "HighVoltage": 0.4,
		"SibatPiercer": 0.99, "IronTipped": 0.4, "WeightedShafts": 0.4, "HabingLiwanagShrine": 0.62, "WovenThreads": 0.22, "SanghayasBlessing": 0.22,
		"BambooTower": 0.2
	},
	"Aswang": {
		"PitikKawayan": 0.24, "SharpenedBamboo": 0.71, "TwinShooters": 0.71,
		"KampilanDefender": 1.51, "HeatedBlade": 0.71, "WideSweep": 0.71,
		"BawangBallista": 0.34, "HeavyCloves": 0.11, "SaltTreatedWood": 0.11,
		"MutyaFocus": 1.28, "RefractedLight": 0.545, "Intensify": 0.545,
		"AgimatMortar": 1.28, "GuidedTalismans": 0.435, "ShrapnelBurst": 0.435,
		"ParolNgLiwanag": 0.58, "BrightOil": 0.195, "SearingLight": 0.195,
		"BaleteRootSnare": 0.52, "DeepRoots": 0.165, "ThornyVines": 0.165,
		"KidlatWeaver": 0.98, "StaticCharge": 0.395, "HighVoltage": 0.395,
		"SibatPiercer": 0.98, "IronTipped": 0.395, "WeightedShafts": 0.395, "HabingLiwanagShrine": 0.61, "WovenThreads": 0.215, "SanghayasBlessing": 0.215,
		"BambooTower": 0.24
	},
	"PugotBoss": {
		"PitikKawayan": 0.15, "SharpenedBamboo": 0.8, "TwinShooters": 0.8,
		"KampilanDefender": 1.6, "HeatedBlade": 0.8, "WideSweep": 0.8,
		"BawangBallista": 0.2, "HeavyCloves": 0.05, "SaltTreatedWood": 0.05,
		"MutyaFocus": 1.35, "RefractedLight": 0.6, "Intensify": 0.6,
		"AgimatMortar": 1.5, "GuidedTalismans": 0.5, "ShrapnelBurst": 0.5,
		"ParolNgLiwanag": 0.65, "BrightOil": 0.22, "SearingLight": 0.22,
		"BaleteRootSnare": 0.45, "DeepRoots": 0.12, "ThornyVines": 0.12,
		"KidlatWeaver": 1.05, "StaticCharge": 0.42, "HighVoltage": 0.42,
		"SibatPiercer": 1.05, "IronTipped": 0.42, "WeightedShafts": 0.42, "HabingLiwanagShrine": 0.7, "WovenThreads": 0.25, "SanghayasBlessing": 0.25,
		"BambooTower": 0.15
	},
	"BossSpiritGuardian": {
		"PitikKawayan": 0.12, "SharpenedBamboo": 0.82, "TwinShooters": 0.82,
		"KampilanDefender": 1.62, "HeatedBlade": 0.82, "WideSweep": 0.82,
		"BawangBallista": 0.18, "HeavyCloves": 0.045, "SaltTreatedWood": 0.045,
		"MutyaFocus": 1.37, "RefractedLight": 0.62, "Intensify": 0.62,
		"AgimatMortar": 1.52, "GuidedTalismans": 0.52, "ShrapnelBurst": 0.52,
		"ParolNgLiwanag": 0.67, "BrightOil": 0.225, "SearingLight": 0.225,
		"BaleteRootSnare": 0.43, "DeepRoots": 0.11, "ThornyVines": 0.11,
		"KidlatWeaver": 1.07, "StaticCharge": 0.43, "HighVoltage": 0.43,
		"SibatPiercer": 1.07, "IronTipped": 0.43, "WeightedShafts": 0.43, "HabingLiwanagShrine": 0.72, "WovenThreads": 0.26, "SanghayasBlessing": 0.26,
		"BambooTower": 0.12
	},
	"GuardianOfThreshold": {
		"PitikKawayan": 0.1, "SharpenedBamboo": 0.85, "TwinShooters": 0.85,
		"KampilanDefender": 1.65, "HeatedBlade": 0.85, "WideSweep": 0.85,
		"BawangBallista": 0.15, "HeavyCloves": 0.04, "SaltTreatedWood": 0.04,
		"MutyaFocus": 1.4, "RefractedLight": 0.65, "Intensify": 0.65,
		"AgimatMortar": 1.55, "GuidedTalismans": 0.55, "ShrapnelBurst": 0.55,
		"ParolNgLiwanag": 0.7, "BrightOil": 0.24, "SearingLight": 0.24,
		"BaleteRootSnare": 0.4, "DeepRoots": 0.1, "ThornyVines": 0.1,
		"KidlatWeaver": 1.1, "StaticCharge": 0.45, "HighVoltage": 0.45,
		"SibatPiercer": 1.1, "IronTipped": 0.45, "WeightedShafts": 0.45, "HabingLiwanagShrine": 0.75, "WovenThreads": 0.28, "SanghayasBlessing": 0.28,
		"BambooTower": 0.1
	},
	"WeakAswang": {
		"PitikKawayan": 0.05, "SharpenedBamboo": 0.9, "TwinShooters": 0.9,
		"KampilanDefender": 1.7, "HeatedBlade": 0.9, "WideSweep": 0.9,
		"BawangBallista": 0.1, "HeavyCloves": 0.02, "SaltTreatedWood": 0.02,
		"MutyaFocus": 1.45, "RefractedLight": 0.7, "Intensify": 0.7,
		"AgimatMortar": 1.6, "GuidedTalismans": 0.6, "ShrapnelBurst": 0.6,
		"ParolNgLiwanag": 0.75, "BrightOil": 0.26, "SearingLight": 0.26,
		"BaleteRootSnare": 0.35, "DeepRoots": 0.08, "ThornyVines": 0.08,
		"KidlatWeaver": 1.15, "StaticCharge": 0.48, "HighVoltage": 0.48,
		"SibatPiercer": 1.15, "IronTipped": 0.48, "WeightedShafts": 0.48, "HabingLiwanagShrine": 0.78, "WovenThreads": 0.3, "SanghayasBlessing": 0.3,
		"BambooTower": 0.05
	}
}

# Tower data with stats (damage, rof, range, cost, category, rarity, description)
var tower_data = {
	"PitikKawayan": {
		"damage": 12,
		"rof": 0.4,
		"range": 185,
		"cost": 100,
		"category": "Projectile",
		"rarity": "common",
		"description": "Basic rapid-fire tower. Solid starting choice with good range."
	},
	"SharpenedBamboo": {
		"damage": 13,
		"rof": 0.6,
		"range": 210,
		"cost": 110,
		"category": "Projectile",
		"rarity": "common",
		"description": "Improved range and accuracy. Steadier, more reliable damage output."
	},
	"TwinShooters": {
		"damage": 18,
		"rof": 0.85,
		"range": 235,
		"cost": 120,
		"category": "Projectile",
		"rarity": "common",
		"description": "Dual projectiles per volley. Excellent against grouped enemies."
	},
	
	# Chapter 2: Kampilan Defender (Melee / Armor-Shredder) - COMMON family
	"KampilanDefender": {
		"damage": 42,
		"rof": 1.2,
		"range": 110,
		"cost": 150,
		"category": "Melee",
		"rarity": "common",
		"description": "Very short range. Swings a wide blade dealing high damage."
	},
	"HeatedBlade": {
		"damage": 48,
		"rof": 1.1,
		"range": 115,
		"cost": 200,
		"category": "Melee",
		"rarity": "common",
		"description": "Attacks melt armor, reducing target defense by 5% per hit."
	},
	"WideSweep": {
		"damage": 45,
		"rof": 1.0,
		"range": 130,
		"cost": 250,
		"category": "Melee",
		"rarity": "common",
		"description": "Increases attack arc, hitting up to 3 closely packed enemies."
	},
	
	# Chapter 3: Bawang Ballista (Garlic Slinger) - COMMON family
	"BawangBallista": {
		"damage": 40,
		"rof": 1.3,
		"range": 90,
		"cost": 110,
		"category": "Air",
		"targeting": "AirOnly",
		"rarity": "common",
		"description": "High damage to flying units only. Medium fire rate."
	},
	"HeavyCloves": {
		"damage": 45,
		"rof": 1.2,
		"range": 105,
		"cost": 140,
		"category": "Air",
		"targeting": "AirOnly",
		"rarity": "common",
		"description": "Projectiles deal minor splash damage upon hitting aerial target."
	},
	"SaltTreatedWood": {
		"damage": 48,
		"rof": 1.1,
		"range": 120,
		"cost": 180,
		"category": "Air",
		"targeting": "AirOnly",
		"rarity": "common",
		"description": "Increases attack range and projectile speed."
	},
	
	# Chapter 4: Mutya Focus (Omnidirectional / Flanking) - RARE family
	"MutyaFocus": {
		"damage": 25,
		"rof": 0.5,
		"range": 300,
		"cost": 200,
		"category": "Beam",
		"rarity": "rare",
		"description": "Fires a continuous beam. Does not rotate to face targets."
	},
	"RefractedLight": {
		"damage": 28,
		"rof": 0.5,
		"range": 340,
		"cost": 260,
		"category": "Beam",
		"rarity": "rare",
		"description": "Beam range is increased to account for shifting path segments."
	},
	"Intensify": {
		"damage": 32,
		"rof": 0.5,
		"range": 380,
		"cost": 320,
		"category": "Beam",
		"rarity": "rare",
		"description": "Damage scales up the longer the beam is locked onto a single target."
	},
	
	# Chapter 5: Agimat Mortar (Artillery / Target-Priority) - RARE family
	"AgimatMortar": {
		"damage": 50,
		"rof": 2.0,
		"range": 520,
		"cost": 220,
		"category": "Artillery",
		"rarity": "rare",
		"description": "Massive range but has a minimum firing distance. Lobs explosives."
	},
	"GuidedTalismans": {
		"damage": 55,
		"rof": 1.8,
		"range": 580,
		"cost": 280,
		"category": "Artillery",
		"rarity": "rare",
		"description": "Unlocks custom targeting logic (First, Last, Strongest, Weakest)."
	},
	"ShrapnelBurst": {
		"damage": 60,
		"rof": 1.6,
		"range": 640,
		"cost": 340,
		"category": "Artillery",
		"rarity": "rare",
		"description": "Increases the splash damage radius upon impact."
	},
	
	# Chapter 6: Parol ng Liwanag (Detection / Reveal Support) - RARE family
	"ParolNgLiwanag": {
		"damage": 0,
		"rof": 1.0,
		"range": 90,
		"cost": 90,
		"category": "Support",
		"rarity": "rare",
		"description": "Emits a radius that reveals invisible units and boosts nearby towers by +15% damage. Deals no damage."
	},
	"BrightOil": {
		"damage": 0,
		"rof": 1.0,
		"range": 110,
		"cost": 130,
		"category": "Support",
		"rarity": "rare",
		"description": "Expands the reveal radius by 20%."
	},
	"SearingLight": {
		"damage": 5,
		"rof": 1.0,
		"range": 125,
		"cost": 170,
		"category": "Support",
		"rarity": "rare",
		"description": "Revealed enemies have their armor slightly reduced inside radius."
	},
	
	# Chapter 7: Balete Root-Snare (Crowd Control / Slow) - RARE family
	"BaleteRootSnare": {
		"damage": 8,
		"rof": 1.0,
		"range": 220,
		"cost": 130,
		"category": "Control",
		"rarity": "rare",
		"description": "Roots grab at enemies, slowing movement speed by 30% in radius."
	},
	"DeepRoots": {
		"damage": 12,
		"rof": 0.9,
		"range": 250,
		"cost": 180,
		"category": "Control",
		"rarity": "rare",
		"description": "Increases the slow effect to 45%."
	},
	"ThornyVines": {
		"damage": 16,
		"rof": 0.8,
		"range": 280,
		"cost": 230,
		"category": "Control",
		"rarity": "rare",
		"description": "Enemies afflicted by slow also take damage over time."
	},
	
	# Chapter 8: Kidlat Weaver (Chain-Lightning) - LEGENDARY family
	"KidlatWeaver": {
		"damage": 28,
		"rof": 1.2,
		"range": 150,
		"cost": 180,
		"category": "Lightning",
		"rarity": "legendary",
		"description": "Fires a bolt of lightning that bounces to 1 additional nearby enemy."
	},
	"StaticCharge": {
		"damage": 32,
		"rof": 1.1,
		"range": 175,
		"cost": 240,
		"category": "Lightning",
		"rarity": "legendary",
		"description": "Increases bounces to 3 total targets."
	},
	"HighVoltage": {
		"damage": 36,
		"rof": 1.0,
		"range": 200,
		"cost": 300,
		"category": "Lightning",
		"rarity": "legendary",
		"description": "Damage drops off less between bounces."
	},
	
	# Chapter 9: Sibat Piercer (Line-Piercing / Anti-Formation) - LEGENDARY family
	"SibatPiercer": {
		"damage": 32,
		"rof": 1.5,
		"range": 280,
		"cost": 160,
		"category": "Piercing",
		"rarity": "legendary",
		"description": "Slow attack speed. Throws a heavy spear that pierces up to 3 enemies."
	},
	"IronTipped": {
		"damage": 38,
		"rof": 1.4,
		"range": 320,
		"cost": 210,
		"category": "Piercing",
		"rarity": "legendary",
		"description": "Increases damage and allows piercing of up to 5 enemies."
	},
	"WeightedShafts": {
		"damage": 42,
		"rof": 1.3,
		"range": 360,
		"cost": 260,
		"category": "Piercing",
		"rarity": "legendary",
		"description": "Spears slightly knock back the first enemy they hit."
	},
	
	# Chapter 10: Habing Liwanag Shrine (Ultimate Cleanser / Support) - LEGENDARY family
	"HabingLiwanagShrine": {
		"damage": 0,
		"rof": 1.0,
		"range": 220,
		"cost": 250,
		"category": "Aura",
		"rarity": "legendary",
		"description": "Deals no damage. Boosts attack speed and damage of adjacent towers by 12%."
	},
	"WovenThreads": {
		"damage": 0,
		"rof": 1.0,
		"range": 260,
		"cost": 320,
		"category": "Aura",
		"rarity": "legendary",
		"description": "Increases the buff radius to cover more towers."
	},
	"SanghayasBlessing": {
		"damage": 0,
		"rof": 1.0,
		"range": 300,
		"cost": 400,
		"category": "Aura",
		"rarity": "legendary",
		"description": "Also boosts the attack damage of affected towers by 18%."
	},
	
	# Old BambooTower for backward compatibility
	"BambooTower": {
		"damage": 20,
		"rof": 1.0,
		"range": 185,
		"category": "Projectile",
		"cost": 100,
		"rarity": "common",
		"description": "Classic bamboo projectile tower."
	}
}

# Chapter-specific enemy pools.
# Enemies in "regular" spawn throughout the chapter's waves.
# Enemies in "boss" are injected as the first spawn of the final/boss wave.
var chapter_enemy_pools = {
	1: {  # Embers at the Outskirts – Village Outskirts and Rice Paths
		"name": "Embers at the Outskirts",
		"regular": ["Dwende", "Tiyanak", "Aswang"],
		"boss": ["BossSpiritGuardian"]          # The Weave Breaker
	},
	2: {  # The Balete Giant – Ancient Forest
		"name": "The Balete Giant",
		"regular": ["CorruptedSpirit", "DarkEngkanto", "ElemSpirit", "NunoSaPunso"],
		"boss": ["Kapre"]
	},
	3: {  # Wings Over Dapithapon – Coastal Rural Town
		"name": "Wings Over Dapithapon",
		"regular": ["Manananggal", "Wakwak", "Mandurugo", "Batibat"],
		"boss": ["Manananggal"]                 # Elite variant used as boss
	},
	4: {  # The Crooked Pass – Fogbound Mountain Pass
		"name": "The Crooked Pass",
		"regular": ["Trickster", "DarkCreature", "Sigben"],
		"boss": ["Tikbalang"]
	},
	5: {  # The Black Swarm – Cursed Village Edge
		"name": "The Black Swarm",
		"regular": ["CursedVillager", "InsectController", "Ghoul"],
		"boss": ["Mambabarang"]
	},
	6: {  # Hunt Beneath Noonday – Stone Streets District
		"name": "Hunt Beneath Noonday",
		"regular": ["Sigben", "Batibat", "NunoSaPunso", "DarkCreature"],
		"boss": ["PugotBoss"]
	},
	7: {  # The Red-Moon Siege – Bayanihan
		"name": "The Red-Moon Siege",
		"regular": ["Aswang", "Tiyanak", "Ghoul", "DarkCreature"],
		"boss": ["Aswang"]                      # Alpha Aswang (boosted by wave scaling)
	},
	8: {  # Gate of the Wild Realm – Spirit Threshold
		"name": "Gate of the Wild Realm",
		"regular": ["BossSpiritGuardian", "ElemSpirit", "CorruptedSpirit", "EliteDeleketnon"],
		"boss": ["GuardianOfThreshold"]
	},
	9: {  # Court of Hollow Roots – Ulgin Domain
		"name": "Court of Hollow Roots",
		"regular": ["DarkEngkanto", "CorruptedSpirit", "EliteDeleketnon", "DarkCreature"],
		"boss": ["GeneralMaruk"]
	},
	10: { # The Last Weave – Final Rift
		"name": "The Last Weave",
		"regular": ["Aswang", "DarkEngkanto", "Mandurugo", "EliteDeleketnon", "Manananggal", "Tiyanak", "ElemSpirit", "Trickster"],
		"boss": ["HaringUldim"]
	}
}

var enemy_data = {
	# Chapter 1 – Village Outskirts
	"Aswang": {
		"hp": 120, "speed": 100, "damage": 21, "reward": 30},
	"Tiyanak": {
		"hp": 80, "speed": 135, "damage": 12, "reward": 20},
	"Dwende": {
		"hp": 100, "speed": 115, "damage": 15, "reward": 25},
	"BossSpiritGuardian": {
		"hp": 480, "speed": 65, "damage": 80, "reward": 200},
	# Chapter 2 – Ancient Forest
	"DarkCreature": {
		"hp": 150, "speed": 95, "damage": 26, "reward": 36},
	"DarkEngkanto": {
		"hp": 145, "speed": 100, "damage": 24, "reward": 34},
	"CorruptedSpirit": {
		"hp": 140, "speed": 108, "damage": 22, "reward": 32},
	"Kapre": {
		"hp": 580, "speed": 55, "damage": 95, "reward": 220},
	# Chapter 3 – Coastal Rural Town
	"Manananggal": {
		"hp": 185, "speed": 88, "damage": 35, "reward": 45},
	"Wakwak": {
		"hp": 155, "speed": 120, "damage": 28, "reward": 40},
	"Batibat": {
		"hp": 170, "speed": 92, "damage": 30, "reward": 42},
	# Chapter 4 – Fogbound Mountain Pass
	"Trickster": {
		"hp": 210, "speed": 110, "damage": 38, "reward": 50},
	"Ghoul": {
		"hp": 200, "speed": 97, "damage": 36, "reward": 48},
	"Sigben": {
		"hp": 220, "speed": 103, "damage": 42, "reward": 52},
	"Tikbalang": {
		"hp": 660, "speed": 60, "damage": 110, "reward": 240},
	# Chapter 5 – Cursed Village Edge
	"CursedVillager": {
		"hp": 230, "speed": 115, "damage": 42, "reward": 55},
	"InsectController": {
		"hp": 240, "speed": 108, "damage": 44, "reward": 57},
	"NunoSaPunso": {
		"hp": 225, "speed": 112, "damage": 40, "reward": 53},
	"Mambabarang": {
		"hp": 715, "speed": 58, "damage": 120, "reward": 260},
	# Chapter 6 – Stone Streets District
	"PugotBoss": {
		"hp": 770, "speed": 62, "damage": 130, "reward": 280},
	# Chapters 7–8 – Spirit Threshold
	"ElemSpirit": {
		"hp": 290, "speed": 112, "damage": 55, "reward": 68},
	"EliteDeleketnon": {
		"hp": 340, "speed": 105, "damage": 62, "reward": 72},
	"Mandurugo": {
		"hp": 270, "speed": 118, "damage": 50, "reward": 62},
	"GuardianOfThreshold": {
		"hp": 960, "speed": 55, "damage": 150, "reward": 350},
	# Chapter 9 – Ulgin Domain
	"GeneralMaruk": {
		"hp": 880, "speed": 68, "damage": 140, "reward": 320},
	# Chapter 10 – Final Rift
	"HaringUldim": {
		"hp": 1200, "speed": 50, "damage": 180, "reward": 500}
}

func reset_economy() -> void:
	if is_coop:
		player_gold = {1: starting_money, 2: starting_money}
		current_money = starting_money
		partner_gold  = starting_money
	else:
		current_money = starting_money

func add_money(amount: int) -> void:
	if is_coop:
		var pid: int = CoopManager.get_local_player_id()
		player_gold[pid] = player_gold.get(pid, 0) + amount
		current_money    = player_gold[pid]
		return
	current_money += amount

func spend_money(amount: int) -> bool:
	if is_coop:
		var pid: int = CoopManager.get_local_player_id()
		if player_gold.get(pid, 0) >= amount:
			player_gold[pid] -= amount
			current_money     = player_gold[pid]
			return true
		return false
	if current_money >= amount:
		current_money -= amount
		return true
	return false

func collect_card(tower_type: String) -> void:
	if tower_type not in collected_cards:
		collected_cards[tower_type] = 0
	collected_cards[tower_type] += 1

func get_collected_card_count(tower_type: String) -> int:
	return collected_cards.get(tower_type, 0)

func get_card_rarity(tower_type: String) -> String:
	return card_rarities.get(tower_type, "common")

func get_rarity_color(rarity: String) -> Color:
	return rarity_colors.get(rarity, Color.WHITE)

# Map tower type names to their scene file names (after Lv reorganization)
func get_tower_scene_path(tower_type: String) -> String:
	# Mapping of tower names to their base family name and level
	var tower_to_scene = {
		# PitikKawayan family
		"PitikKawayan": "PitikKawayan_Lv1.tscn",
		"SharpenedBamboo": "PitikKawayan_Lv2.tscn",
		"TwinShooters": "PitikKawayan_Lv3.tscn",
		# KampilanDefender family
		"KampilanDefender": "KampilanDefender_Lv1.tscn",
		"HeatedBlade": "KampilanDefender_Lv2.tscn",
		"WideSweep": "KampilanDefender_Lv3.tscn",
		# BawangBallista family
		"BawangBallista": "BawangBallista_Lv1.tscn",
		"HeavyCloves": "BawangBallista_Lv2.tscn",
		"SaltTreatedWood": "BawangBallista_Lv3.tscn",
		# MutyaFocus family
		"MutyaFocus": "MutyaFocus_Lv1.tscn",
		"RefractedLight": "MutyaFocus_Lv2.tscn",
		"Intensify": "MutyaFocus_Lv3.tscn",
		# AgimatMortar family
		"AgimatMortar": "AgimatMortar_Lv1.tscn",
		"GuidedTalismans": "AgimatMortar_Lv2.tscn",
		"ShrapnelBurst": "AgimatMortar_Lv3.tscn",
		# ParolNgLiwanag family
		"ParolNgLiwanag": "ParolNgLiwanag_Lv1.tscn",
		"BrightOil": "ParolNgLiwanag_Lv2.tscn",
		"SearingLight": "ParolNgLiwanag_Lv3.tscn",
		# BaleteRootSnare family
		"BaleteRootSnare": "BaleteRootSnare_Lv1.tscn",
		"DeepRoots": "BaleteRootSnare_Lv2.tscn",
		"ThornyVines": "BaleteRootSnare_Lv3.tscn",
		# KidlatWeaver family
		"KidlatWeaver": "KidlatWeaver_Lv1.tscn",
		"StaticCharge": "KidlatWeaver_Lv2.tscn",
		"HighVoltage": "KidlatWeaver_Lv3.tscn",
		# SibatPiercer family
		"SibatPiercer": "SibatPiercer_Lv1.tscn",
		"IronTipped": "SibatPiercer_Lv2.tscn",
		"WeightedShafts": "SibatPiercer_Lv3.tscn",
		# LiwanagShrine family
		"HabingLiwanagShrine": "HabingLiwanagShrine_Lv1.tscn",
		"WovenThreads": "HabingLiwanagShrine_Lv2.tscn",
		"SanghayasBlessing": "HabingLiwanagShrine_Lv3.tscn",
	}
	
	return tower_to_scene.get(tower_type, tower_type + ".tscn")

# --- Upgrade helpers -------------------------------------------------------- #

func get_tower_family_name(tower_type: String) -> String:
	for family_key in tower_families:
		if tower_type in tower_families[family_key]["towers"]:
			return family_key
	return ""

func get_tower_level(tower_type: String) -> int:
	var family_key = get_tower_family_name(tower_type)
	if family_key == "":
		return 1
	return tower_families[family_key]["towers"].find(tower_type) + 1

func get_next_tower_type(tower_type: String) -> String:
	var family_key = get_tower_family_name(tower_type)
	if family_key == "":
		return ""
	var towers_arr: Array = tower_families[family_key]["towers"]
	var idx = towers_arr.find(tower_type)
	if idx < 0 or idx >= towers_arr.size() - 1:
		return ""
	return towers_arr[idx + 1]

func get_upgrade_cost(tower_type: String) -> int:
	if get_next_tower_type(tower_type) == "":
		return -1
	var current_cost: int = tower_data[tower_type].get("cost", 0)
	return ceili(current_cost * 1.5)

# ---------------------------------------------------------------------------- #

func is_boss_wave(wave_number: int) -> bool:
	var total_waves = selected_wave_count
	if total_waves <= 0:
		return false
	return wave_number == total_waves - 1

func retrieve_wave_data(player_count: int = 1, wave_number: int = 0):
	# Cache by (player_count × selected_wave_count) so the same random seed
	# is used for every wave in a single game session.
	var cache_key = "%d:%d" % [player_count, selected_wave_count]
	if _cached_waves.is_empty() or _cached_waves_key != cache_key:
		_cached_waves = _generate_all_waves(player_count, selected_wave_count)
		_cached_waves_key = cache_key

	var wave_data = []
	if wave_number < _cached_waves.size():
		wave_data = _cached_waves[wave_number]
	return wave_data

func _generate_all_waves(player_count: int, total_waves: int) -> Array:
	# Use chapter-specific pools when a chapter has been selected
	var use_chapter_mode = selected_chapter >= 1 and chapter_enemy_pools.has(selected_chapter)
	
	# Chapter-mode pool references
	var chapter_regular: Array = []
	var chapter_boss: Array = []
	if use_chapter_mode:
		chapter_regular = chapter_enemy_pools[selected_chapter]["regular"]
		chapter_boss    = chapter_enemy_pools[selected_chapter]["boss"]
	
	# Fallback tier pools (used when no chapter is selected)
	var tier1_enemies = ["Batibat", "CursedVillager", "NunoSaPunso", "InsectController", "Dwende"]
	var tier2_enemies = ["Kapre", "Sigben", "Trickster", "DarkCreature", "Ghoul", "Mambabarang",
						"DarkEngkanto", "CorruptedSpirit", "ElemSpirit", "Manananggal"]
	var tier3_enemies = ["Tikbalang", "Wakwak", "Mandurugo", "Tiyanak", "EliteDeleketnon", "Aswang"]
	var tier4_enemies = ["PugotBoss", "BossSpiritGuardian", "GuardianOfThreshold"]

	var waves = []
	var scale = 1.5

	for wave_idx in range(total_waves):
		var progress = float(wave_idx) / float(total_waves)  # 0.0 to 1.0
		var boss_wave_flag = (wave_idx == total_waves - 1)

		var base_count = 2.0 + (wave_idx * 0.7)
		var enemy_count = int(ceil(base_count * scale))
		if player_count == 2:
			enemy_count = int(ceil(enemy_count * 1.3))

		var wave_enemies = []
		var spawn_delay = 0.0
		var spawn_interval = 0.4

		for i in range(enemy_count):
			var enemy_type = ""

			if use_chapter_mode:
				# Chapter mode: first enemy in the boss wave is always the chapter boss
				if boss_wave_flag and i == 0 and chapter_boss.size() > 0:
					enemy_type = chapter_boss[randi() % chapter_boss.size()]
				elif chapter_regular.size() > 0:
					enemy_type = chapter_regular[randi() % chapter_regular.size()]
				else:
					enemy_type = tier1_enemies[randi() % tier1_enemies.size()]
			else:
				# Tier-based fallback (no chapter selected)
				var tier_roll = randf()
				if progress < 0.3:
					if tier_roll < 0.6:
						enemy_type = tier1_enemies[randi() % tier1_enemies.size()]
					else:
						enemy_type = tier2_enemies[randi() % tier2_enemies.size()]
				elif progress < 0.6:
					if tier_roll < 0.4:
						enemy_type = tier1_enemies[randi() % tier1_enemies.size()]
					elif tier_roll < 0.7:
						enemy_type = tier2_enemies[randi() % tier2_enemies.size()]
					else:
						enemy_type = tier3_enemies[randi() % tier3_enemies.size()]
				elif progress < 0.85:
					if tier_roll < 0.2:
						enemy_type = tier2_enemies[randi() % tier2_enemies.size()]
					elif tier_roll < 0.65:
						enemy_type = tier3_enemies[randi() % tier3_enemies.size()]
					else:
						enemy_type = tier4_enemies[randi() % tier4_enemies.size()]
				else:
					if tier_roll < 0.3:
						enemy_type = tier3_enemies[randi() % tier3_enemies.size()]
					else:
						enemy_type = tier4_enemies[randi() % tier4_enemies.size()]

			wave_enemies.append([enemy_type, spawn_delay])
			spawn_delay += spawn_interval

		waves.append(wave_enemies)

	return waves
## A tower can only be used after its family has been obtained from a lootbox.
func is_tower_family_unlocked(tower_name: String) -> bool:
	var family_name := get_tower_family_name(tower_name)
	if family_name.is_empty():
		return false
	return LootboxManager.is_family_unlocked(family_name)

## Get lootbox-owned Level 1 towers available in normal mode.
## player_role: 0 = all (solo), 1 = Mandirigma/Warrior (Host/P1), 2 = Babaylan/Shaman (Client/P2)
const ROLE_A_TOWERS: Array = [
	"PitikKawayan", "KampilanDefender", "AgimatMortar", "KidlatWeaver", "SibatPiercer"
]
const ROLE_B_TOWERS: Array = [
	"BawangBallista", "MutyaFocus", "ParolNgLiwanag", "BaleteRootSnare", "HabingLiwanagShrine"
]

func get_available_towers_normal_mode(player_role: int = 0) -> Array:
	"""Returns only Level 1 towers for normal mode"""
	var available = []
	
	# Level 1 towers (first in each family)
	var level1_towers = [
		"PitikKawayan",
		"KampilanDefender", 
		"BawangBallista",
		"MutyaFocus",
		"AgimatMortar",
		"ParolNgLiwanag",
		"BaleteRootSnare",
		"KidlatWeaver",
		"SibatPiercer",
		"HabingLiwanagShrine"
	]
	
	for tower in level1_towers:
		if is_tower_family_unlocked(tower):
			if player_role == 1 and tower not in ROLE_A_TOWERS:
				continue
			if player_role == 2 and tower not in ROLE_B_TOWERS:
				continue
			available.append(tower)

	return available

## Return the family name that a tower type belongs to
func get_tower_family(tower_type: String) -> String:
	for fam_name in tower_families.keys():
		if tower_type in tower_families[fam_name]["towers"]:
			return fam_name
	return ""

## Return audio key, impact audio key, impact VFX type, and impact scene for a tower family
func get_tower_audio_and_effects(family_name: String) -> Dictionary:
	var audio_map: Dictionary = {
		# The old pitik_fire clip duplicates wave_start and overlaps at Pitik's
		# rapid fire rate. Use its distinct impact sound only.
		"PitikKawayan": {"audio_key": "", "impact_audio_key": "pitik_impact", "impact_vfx": "hit", "impact_scene": "res://Scenes/SupportScenes/projectile_impact.tscn"},
		"KampilanDefender": {"audio_key": "kampilan_fire", "impact_audio_key": "kampilan_impact", "impact_vfx": "hit", "impact_scene": "res://Scenes/SupportScenes/kampihan_impact.tscn"},
		"BawangBallista": {"audio_key": "bawang_fire", "impact_audio_key": "bawang_impact", "impact_vfx": "hit", "impact_scene": "res://Scenes/SupportScenes/projectile_impact.tscn"},
		"MutyaFocus": {"audio_key": "mutya_fire", "impact_audio_key": "mutya_impact", "impact_vfx": "hit", "impact_scene": "res://Scenes/SupportScenes/mutya_impact.tscn"},
		"AgimatMortar": {"audio_key": "agimat_fire", "impact_audio_key": "agimat_impact", "impact_vfx": "explosion", "impact_scene": "res://Scenes/SupportScenes/agimat_impact.tscn"},
		"ParolNgLiwanag": {"audio_key": "parol_fire", "impact_audio_key": "parol_impact", "impact_vfx": "hit", "impact_scene": "res://Scenes/SupportScenes/projectile_impact.tscn"},
		"BaleteRootSnare": {"audio_key": "balete_fire", "impact_audio_key": "balete_impact", "impact_vfx": "slow", "impact_scene": "res://Scenes/SupportScenes/extra_effect.tscn"},
		"KidlatWeaver": {"audio_key": "kidlat_fire", "impact_audio_key": "kidlat_impact", "impact_vfx": "chain", "impact_scene": "res://Scenes/SupportScenes/lightning_impact.tscn"},
		"SibatPiercer": {"audio_key": "sibat_fire", "impact_audio_key": "sibat_impact", "impact_vfx": "pierce", "impact_scene": "res://Scenes/SupportScenes/extra_effect2.tscn"},
		"HabingLiwanagShrine": {"audio_key": "habing_fire", "impact_audio_key": "habing_impact", "impact_vfx": "buff", "impact_scene": "res://Scenes/SupportScenes/extra_effect3.tscn"},
	}
	return audio_map.get(family_name, {})
