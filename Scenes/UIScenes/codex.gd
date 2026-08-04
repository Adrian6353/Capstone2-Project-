extends Control

# ─────────────────────────────────────────────────
#  CODEX  –  Pokédex-style tower & enemy reference
# ─────────────────────────────────────────────────

var GameData
var AudioManager

# ── Tab state ──────────────────────────────────────
var current_tab: String = "towers"   # "towers" | "enemies"
var selected_family_id: String = ""
var selected_enemy_id: String  = ""
var selected_level: int = 0          # 0/1/2 for tower Lv1/Lv2/Lv3

# ── UI node references (created at runtime) ────────
var list_container:   VBoxContainer
var detail_portrait:  TextureRect
var detail_name:      Label
var detail_badge:     Label
var detail_type_label: Label
var detail_chapter_label: Label
var detail_stats:     Label
var detail_desc:      Label
var level_bar:        HBoxContainer
var level_btns:       Array = []
var tab_towers:       Button
var tab_enemies:      Button
var tab_characters:   Button
var selected_char_id: String = ""

# ══════════════════════════════════════════════════
#  DATA TABLES
# ══════════════════════════════════════════════════

var tower_families = [
	{"id": "PitikKawayan",      "upgrades": ["PitikKawayan",      "SharpenedBamboo",  "TwinShooters"],        "chapter": 1},
	{"id": "KampilanDefender",  "upgrades": ["KampilanDefender",  "HeatedBlade",      "WideSweep"],           "chapter": 2},
	{"id": "BawangBallista",    "upgrades": ["BawangBallista",    "HeavyCloves",      "SaltTreatedWood"],     "chapter": 3},
	{"id": "MutyaFocus",        "upgrades": ["MutyaFocus",        "RefractedLight",   "Intensify"],           "chapter": 4},
	{"id": "AgimatMortar",      "upgrades": ["AgimatMortar",      "GuidedTalismans",  "ShrapnelBurst"],       "chapter": 5},
	{"id": "ParolNgLiwanag",    "upgrades": ["ParolNgLiwanag",    "BrightOil",        "SearingLight"],        "chapter": 6},
	{"id": "BaleteRootSnare",   "upgrades": ["BaleteRootSnare",   "DeepRoots",        "ThornyVines"],         "chapter": 7},
	{"id": "KidlatWeaver",      "upgrades": ["KidlatWeaver",      "StaticCharge",     "HighVoltage"],         "chapter": 8},
	{"id": "SibatPiercer",      "upgrades": ["SibatPiercer",      "IronTipped",       "WeightedShafts"],      "chapter": 9},
	{"id": "HabingLiwanagShrine","upgrades": ["HabingLiwanagShrine","WovenThreads",   "SanghayasBlessing"],   "chapter": 10},
]

var enemy_chapters = [
	{"chapter": 1,  "name": "Embers at the Outskirts",  "enemies": ["Dwende", "Tiyanak", "Aswang", "BossSpiritGuardian"]},
	{"chapter": 2,  "name": "The Balete Giant",          "enemies": ["CorruptedSpirit", "ElemSpirit", "DarkEngkanto", "NunoSaPunso", "Kapre"]},
	{"chapter": 3,  "name": "Wings Over Dapithapon",     "enemies": ["Wakwak", "Batibat", "Manananggal", "Mandurugo"]},
	{"chapter": 4,  "name": "The Crooked Pass",          "enemies": ["DarkCreature", "Trickster", "Sigben", "Tikbalang"]},
	{"chapter": 5,  "name": "The Black Swarm",           "enemies": ["CursedVillager", "InsectController", "Ghoul", "Mambabarang"]},
	{"chapter": 6,  "name": "Hunt Beneath Noonday",      "enemies": ["PugotBoss"]},
	{"chapter": 8,  "name": "Gate of the Wild Realm",    "enemies": ["EliteDeleketnon", "GuardianOfThreshold"]},
	{"chapter": 9,  "name": "Court of Hollow Roots",     "enemies": ["GeneralMaruk"]},
	{"chapter": 10, "name": "The Last Weave",            "enemies": ["HaringUldim"]},
]

var tower_display_names = {
	"PitikKawayan": "Pitik Kawayan",          "SharpenedBamboo": "Sharpened Bamboo",   "TwinShooters": "Twin Shooters",
	"KampilanDefender": "Kampilan Defender",  "HeatedBlade": "Heated Blade",           "WideSweep": "Wide Sweep",
	"BawangBallista": "Bawang Ballista",      "HeavyCloves": "Heavy Cloves",           "SaltTreatedWood": "Salt-Treated Wood",
	"MutyaFocus": "Mutya Focus",              "RefractedLight": "Refracted Light",     "Intensify": "Intensify",
	"AgimatMortar": "Agimat Mortar",          "GuidedTalismans": "Guided Talismans",   "ShrapnelBurst": "Shrapnel Burst",
	"ParolNgLiwanag": "Parol ng Liwanag",     "BrightOil": "Bright Oil",               "SearingLight": "Searing Light",
	"BaleteRootSnare": "Balete Root-Snare",   "DeepRoots": "Deep Roots",               "ThornyVines": "Thorny Vines",
	"KidlatWeaver": "Kidlat Weaver",          "StaticCharge": "Static Charge",         "HighVoltage": "High Voltage",
	"SibatPiercer": "Sibat Piercer",          "IronTipped": "Iron Tipped",             "WeightedShafts": "Weighted Shafts",
	"HabingLiwanagShrine": "Habing Liwanag Shrine", "WovenThreads": "Woven Threads",   "SanghayasBlessing": "Sanghaya's Blessing",
}

var enemy_display_names = {
	"Aswang": "Aswang",                       "Tiyanak": "Tiyanak",
	"Dwende": "Dwende",                        "BossSpiritGuardian": "Spirit Guardian",
	"DarkCreature": "Dark Creature",           "DarkEngkanto": "Dark Engkanto",
	"CorruptedSpirit": "Corrupted Spirit",     "ElemSpirit": "Elemental Spirit",
	"NunoSaPunso": "Nuno sa Punso",            "Kapre": "Kapre",
	"Manananggal": "Manananggal",              "Wakwak": "Wakwak",
	"Batibat": "Batibat",                      "Mandurugo": "Mandurugo",
	"Trickster": "Trickster",                  "Ghoul": "Ghoul",
	"Sigben": "Sigben",                        "Tikbalang": "Tikbalang",
	"CursedVillager": "Cursed Villager",       "InsectController": "Insect Controller",
	"Mambabarang": "Mambabarang",              "PugotBoss": "Pugot",
	"EliteDeleketnon": "Elite Deleketnon",     "GuardianOfThreshold": "Guardian of the Threshold",
	"GeneralMaruk": "General Maruk",           "HaringUldim": "Haring Uldim",
}

var tower_images = {
	"PitikKawayan":      "res://Assets/Towers/PitikKawayan_Lv1.png",
	"SharpenedBamboo":   "res://Assets/Towers/PitikKawayan_Lv2.png",
	"TwinShooters":      "res://Assets/Towers/PitikKawayan_Lv3.png",
	"KampilanDefender":  "res://Assets/Towers/Kampilan Defender Lv.1.png",
	"HeatedBlade":       "res://Assets/Towers/Kampilan Defender Lv.2.png",
	"WideSweep":         "res://Assets/Towers/Kampilan Defender Lv.3.png",
	"BawangBallista":    "res://Assets/Towers/Lv1 Bawang Ballista.png",
	"HeavyCloves":       "res://Assets/Towers/Lvl2 Bawang Ballista.png",
	"SaltTreatedWood":   "res://Assets/Towers/Lvl3 Bawang Ballista.png",
	"MutyaFocus":        "res://Assets/Towers/Mutya Focus Lv.1.png",
	"RefractedLight":    "res://Assets/Towers/Mutya Focus Lv.2.png",
	"Intensify":         "res://Assets/Towers/Mutya Focus Lv.3.png",
	"AgimatMortar":      "res://Assets/Towers/Agimat Mortar Lv.1.png",
	"GuidedTalismans":   "res://Assets/Towers/Agimat Mortar Lv.2.png",
	"ShrapnelBurst":     "res://Assets/Towers/Agimat Mortar Lv.3.png",
	"ParolNgLiwanag":    "res://Assets/Towers/Lvl1 Parol ng Liwanag.png",
	"BrightOil":         "res://Assets/Towers/Lvl2 Parol ng liwanag.png",
	"SearingLight":      "res://Assets/Towers/Lvl 3 Parol Ng Liwanag.png",
	"BaleteRootSnare":   "res://Assets/Towers/Lv.1 Balete Root-Snare.png",
	"DeepRoots":         "res://Assets/Towers/Lv.2 Balete Root-Snare.png",
	"ThornyVines":       "res://Assets/Towers/Lv.3 Balete Root-Snare.png",
	"KidlatWeaver":      "res://Assets/Towers/Kidlat Weaver Lv1.png",
	"StaticCharge":      "res://Assets/Towers/Kidlat Weaver Lv2.png",
	"HighVoltage":       "res://Assets/Towers/Kidlat Weaver Lv3.png",
	"SibatPiercer":      "res://Assets/Towers/Sibat Piercer Lv.1.png",
	"IronTipped":        "res://Assets/Towers/Sibat Piercer Lv.2.png",
	"WeightedShafts":    "res://Assets/Towers/Sibat Piercer Lv.3.png",
	"HabingLiwanagShrine":"res://Assets/Towers/HabingLiwanagShrine Lv.1.png",
	"WovenThreads":      "res://Assets/Towers/HabingLiwanagShrine Lv.2.png",
	"SanghayasBlessing": "res://Assets/Towers/HabingLiwanagShrine Lv.3.png",
}

var enemy_images = {
	"Aswang":              "res://Assets/Enemies/WeakAswang.png",
	"Tiyanak":             "res://Assets/Enemies/Tiyanak.png",
	"Dwende":              "res://Assets/Enemies/Duwende.png",
	"BossSpiritGuardian":  "res://Assets/Enemies/The_Weave_Breaker.png",
	"DarkCreature":        "res://Assets/Enemies/DarkCreature.png",
	"DarkEngkanto":        "res://Assets/Enemies/Dark_Engkanto.png",
	"CorruptedSpirit":     "res://Assets/Enemies/Corrupted_Spirit.png",
	"ElemSpirit":          "res://Assets/Enemies/ElemSpirit.Png",
	"NunoSaPunso":         "res://Assets/Enemies/NunoSaPunso.png",
	"Kapre":               "res://Assets/Enemies/Kapre.png",
	"Manananggal":         "res://Assets/Enemies/Manananggal.png",
	"Wakwak":              "res://Assets/Enemies/Wakwak_Bat_Like_Creature.png",
	"Batibat":             "res://Assets/Enemies/Batibat.png",
	"Mandurugo":           "res://Assets/Enemies/Mandurugo_Bat_Like_Creatures.png",
	"Trickster":           "res://Assets/Enemies/Trickster.png",
	"Ghoul":               "res://Assets/Enemies/Ghoul.png",
	"Sigben":              "res://Assets/Enemies/Sigben.png",
	"Tikbalang":           "res://Assets/Enemies/Tikbalang.png",
	"CursedVillager":      "res://Assets/Enemies/Cursed_Villager.png",
	"InsectController":    "res://Assets/Enemies/Insect_Controller_New.png",
	"Mambabarang":         "res://Assets/Enemies/Mambabarang.png",
	"PugotBoss":           "res://Assets/Enemies/Pugot_BossVariant_NoGore.png",
	"EliteDeleketnon":     "res://Assets/Enemies/Elite_Deleketnon.png",
	"GuardianOfThreshold": "res://Assets/Enemies/GuardianOfThreshold.png",
	"GeneralMaruk":        "res://Assets/Enemies/DeleketnonGeneral.png",
	"HaringUldim":         "res://Assets/Enemies/DeleketnonKing.png",
}

var enemy_descriptions = {
	"Aswang":
		"A shape-shifting creature of Philippine folklore. Moderate speed, moderate health — a reliable early threat.",
	"Tiyanak":
		"A demon disguised as a helpless infant. Deceptively fast and surprisingly fragile.",
	"Dwende":
		"A dwarf spirit that guards anthills and forest paths. Steady and determined.",
	"BossSpiritGuardian":
		"The Weave Breaker. A colossal spirit warden bound to the first threshold. Immense health and crushing power.",
	"DarkCreature":
		"A beast born from the shadows of the ancient forest. Harder, faster, and more aggressive than early foes.",
	"DarkEngkanto":
		"A forest spirit twisted by corruption. Balances raw strength with supernatural resilience.",
	"CorruptedSpirit":
		"Once a benevolent guardian spirit, now twisted by dark influence. Quick and relentless.",
	"ElemSpirit":
		"Pure elemental energy given form. High movement speed and dangerous contact damage.",
	"NunoSaPunso":
		"An angered ancestral dwarf spirit from a disturbed mound. Deceptively swift and spiteful.",
	"Kapre":
		"A towering tree-demon wreathed in smoke. Massive health and bone-crushing base damage.",
	"Manananggal":
		"A winged monster that splits its body at night. Airborne threat with fearsome attack power.",
	"Wakwak":
		"A bird-like vampiric spirit that hunts from the sky. Fast-flying predator with solid combat power.",
	"Batibat":
		"A malevolent nightmare spirit that inhabits old trees. Deceptively dangerous despite its heavy, lumbering form.",
	"Mandurugo":
		"A blood-drinking flying creature cloaked in bat-like wings. Combines aerial mobility with vampiric lethality.",
	"Trickster":
		"A cunning spirit of pure deception. Uses speed and misdirection to weave past defenses.",
	"Ghoul":
		"A ravenous undead scavenger haunting the cursed mountain pass. Tough and utterly relentless.",
	"Sigben":
		"A grotesque two-headed creature that moves with an unsettling gait. Resilient and oddly fast.",
	"Tikbalang":
		"A horse-headed demon of the fogbound passes. Immense strength and frightening speed for its towering size.",
	"CursedVillager":
		"A once-innocent soul consumed by dark sorcery. Frenzied movement and reckless ferocity.",
	"InsectController":
		"A warlock commanding a swarm of cursed insects. Controls the battlefield and amplifies nearby threats.",
	"Mambabarang":
		"A powerful witch who weaves insect curses. Boss-tier threat with devastating assault potential.",
	"PugotBoss":
		"The Headless One. A terrifying headless entity of near-unstoppable power and supernatural resilience.",
	"EliteDeleketnon":
		"An elite warrior of the Deleketnon clan. Faster and deadlier than any common footsoldier.",
	"GuardianOfThreshold":
		"The ancient gate guardian of the spirit realm boundary. Near-indestructible with catastrophic damage.",
	"GeneralMaruk":
		"The commanding general of the Deleketnon forces. Strategic, powerful, and completely relentless.",
	"HaringUldim":
		"The Deleketnon King — the ultimate enemy. Unmatched health and the most devastating base damage in existence.",
}

# ── Characters data ───────────────────────────────
var character_list = [
	{"id": "Amaru",          "role": "Protagonist / New Keeper"},
	{"id": "Alon",           "role": "Guide / Diwata Messenger"},
	{"id": "Lola Mutya",     "role": "Healer / Tradition Bearer"},
	{"id": "LateMother",     "role": "Legacy Keeper / Absent Lineage Figure"},
	{"id": "HaringUldim",   "role": "Primary Antagonist / Ruler of the Ulgin Court"},
	{"id": "GeneralMaruk",  "role": "Fallen Warden / Ideological Rival"},
]

var character_display_names = {
	"Amaru":        "Amaru",
	"Alon":         "Alon",
	"Lola Mutya":   "Lola Mutya",
	"LateMother":   "Amaru's Late Mother",
	"HaringUldim":  "Haring Uldim",
	"GeneralMaruk": "General Maruk",
}

var character_portrait_paths = {
	"Amaru":     "res://Assets/Portraits/Amaru_portrait.png",
	"Alon":      "res://Assets/Portraits/Alon_portrait.png",
	"Lola Mutya": "res://Assets/Portraits/ApungMutya_portrait.png",
}

var character_backstories = {
	"Amaru":
		"Amaru is a young scout from Bayanihan who grows up under the care of his grandmother, a respected healer and keeper of old protective traditions. When the village ward-lines begin to fail, he learns that his late mother once served the Bantay-Diwa, and that the unfinished duty of that line has now passed to him.",
	"Alon":
		"Alon first appears as the spirit guide who leads Amaru beyond the safe edge of home and into the broken paths between worlds. She teaches him how to read spirit routes, understand the old balance, and recognize that the crisis is larger than scattered monster attacks.",
	"Lola Mutya":
		"Amaru's grandmother is a respected herbal healer who preserves old prayers, rituals, and spirit knowledge that most of Bayanihan has already forgotten. She raises Amaru quietly, but when the outer wards begin to shatter, she reveals that his family line is linked to the guardianship of the ward-lines.",
	"LateMother":
		"Although she does not appear directly in the campaign, Amaru's late mother is one of the most important unseen figures in his backstory. She once served the Bantay-Diwa, and her unfinished responsibility becomes the reason Amaru is drawn into the struggle when the realms begin to tear apart again.",
	"HaringUldim":
		"Haring Uldim leads the corrupted spirit nobles who form the Ulgin Court. He rises as the central force behind the collapse of the ward-lines, spreading fear, disorder, and deliberate corruption through sacred places and borderlands.",
	"GeneralMaruk":
		"General Maruk is first encountered as Uldim's disciplined military champion, but later revelations show that he was once a spirit warden who fought for the ward-lines. He defected after losing faith in the old system and came to see the boundary between realms as a prison instead of a pact worth preserving.",
}

var character_lore = {
	"Amaru":
		"His story is tied to the Sanghaya, an ancient medallion that carries nine sleeping hiyas. As each hiya awakens, Amaru moves from ordinary village protector to the rightful rebirth of a Bantay-Diwa, making him the human figure through whom the Habing Liwanag can be restored.",
	"Alon":
		"Later lore reveals that Alon once helped maintain the Habing Liwanag from the spirit side and remained at the wounded boundary after others fled. She is not merely a guide — she is a surviving witness to the old order and a bridge between the human realm and the Ligaw na Daigdig.",
	"Lola Mutya":
		"She entrusts the Sanghaya to Amaru before the village's last protections fail. In the wider lore, she represents ancestral memory and the human side of the old pact, proving that sacred knowledge survived not through armies, but through elders who kept the traditions alive.",
	"LateMother":
		"Her place in the lore gives Amaru's journey inheritance, not accident. She stands for the broken but unextinguished line of keepers, and her absence deepens the sense that Amaru is not beginning a new story from nothing, but continuing one that was interrupted.",
	"HaringUldim":
		"His lore is rooted in rejection of balance. He believes the boundary between worlds should not be repaired, but destroyed, so that the human realm and spirit realm can be forced into one broken kingdom under his rule. He turns the conflict from scattered haunting into a war over the structure of reality itself.",
	"GeneralMaruk":
		"This makes Maruk one of the richest figures in the lore. He is not a simple villain, but a fallen defender whose beliefs directly challenge Amaru's mission. Through him, the story raises a deeper question: whether restoration is still possible, or whether the old order had already failed long before the war began.",
}

# ── Rarity colours ─────────────────────────────────
# ── Colours (mirroring UIThemeHelper for consistency) ──────────────────────
const RARITY_COLORS = {
	"common":    Color(0.75, 0.75, 0.75),
	"rare":      Color(0.20, 0.60, 1.00),
	"legendary": Color(1.00, 0.72, 0.10),
}
const BOSS_COLOR   = Color(0.90, 0.20, 0.20)
const PANEL_BG     = Color(0.10, 0.06, 0.02, 0.96)   # UIThemeHelper.COL_PANEL_BG
const PANEL_DETAIL = Color(0.13, 0.08, 0.04, 0.92)
const ACCENT_GOLD  = Color(0.95, 0.78, 0.32, 1.0)    # UIThemeHelper.COL_TEXT_GOLD
const TEXT_LIGHT   = Color(1.00, 0.95, 0.85, 1.0)    # UIThemeHelper.COL_TEXT_CREAM
const TEXT_DIM     = Color(0.68, 0.55, 0.36, 1.0)    # UIThemeHelper.COL_TEXT_MUTED

# ══════════════════════════════════════════════════
#  ENTRY POINT
# ══════════════════════════════════════════════════

func _ready() -> void:
	GameData    = get_node("/root/GameData")
	AudioManager = get_node("/root/AudioManager")
	AudioManager.play_music("main_menu", 1.0)

	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_switch_tab("towers")

# ══════════════════════════════════════════════════
#  UI CONSTRUCTION
# ══════════════════════════════════════════════════

func _build_ui() -> void:
	# ── Background ──────────────────────────────────
	var bg = TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	var bg_tex = load("res://Assets/UI/Art/rm218-bb-07.jpg")
	if bg_tex:
		bg.texture = bg_tex
	bg.modulate = Color(0.4, 0.35, 0.3, 1.0)
	add_child(bg)

	# ── Dark overlay ────────────────────────────────
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	add_child(overlay)

	# ── Root layout (margin container) ──────────────
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   20)
	margin.add_theme_constant_override("margin_right",  20)
	margin.add_theme_constant_override("margin_top",    16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	# ── Header row ──────────────────────────────────
	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 60)
	root_vbox.add_child(header)

	var back_btn = _make_button("◀  Back", 130, 60)
	back_btn.pressed.connect(_on_back_pressed)
	header.add_child(back_btn)

	var spacer1 = Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer1)

	var title = Label.new()
	title.text = "📖  CODEX"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", ACCENT_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)

	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer2)

	# placeholder to balance back button
	var ph = Control.new()
	ph.custom_minimum_size = Vector2(130, 0)
	header.add_child(ph)

	# ── Tab buttons ─────────────────────────────────
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	root_vbox.add_child(tab_row)

	tab_towers     = _make_tab_button("⚔  Towers",     200, 52)
	tab_enemies    = _make_tab_button("💀  Enemies",    200, 52)
	tab_characters = _make_tab_button("👤  Characters", 200, 52)
	tab_towers.pressed.connect(func(): _switch_tab("towers"))
	tab_enemies.pressed.connect(func(): _switch_tab("enemies"))
	tab_characters.pressed.connect(func(): _switch_tab("characters"))
	tab_row.add_child(tab_towers)
	tab_row.add_child(tab_enemies)
	tab_row.add_child(tab_characters)

	# ── Main split ──────────────────────────────────
	var split = HBoxContainer.new()
	split.add_theme_constant_override("separation", 12)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(split)

	# Left list panel
	var list_panel = _make_panel(PANEL_BG)
	list_panel.custom_minimum_size = Vector2(260, 0)
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(list_panel)

	var list_scroll = ScrollContainer.new()
	list_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_child(list_scroll)

	list_container = VBoxContainer.new()
	list_container.add_theme_constant_override("separation", 4)
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list_container)

	# Right detail panel
	var detail_panel = _make_panel(PANEL_DETAIL)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	split.add_child(detail_panel)

	_build_detail_panel(detail_panel)

func _build_detail_panel(panel: PanelContainer) -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left","margin_right","margin_top","margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Top section: portrait + name/badge column
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 20)
	top_row.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(top_row)

	# Portrait frame
	var portrait_frame = PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(200, 200)
	var portrait_style = StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.05, 0.04, 0.03, 1.0)
	portrait_style.border_width_left   = 2
	portrait_style.border_width_right  = 2
	portrait_style.border_width_top    = 2
	portrait_style.border_width_bottom = 2
	portrait_style.border_color = ACCENT_GOLD
	portrait_style.corner_radius_top_left     = 8
	portrait_style.corner_radius_top_right    = 8
	portrait_style.corner_radius_bottom_left  = 8
	portrait_style.corner_radius_bottom_right = 8
	portrait_frame.add_theme_stylebox_override("panel", portrait_style)
	top_row.add_child(portrait_frame)

	detail_portrait = TextureRect.new()
	detail_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_portrait.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	portrait_frame.add_child(detail_portrait)

	# Name / badges column
	var name_col = VBoxContainer.new()
	name_col.add_theme_constant_override("separation", 8)
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_col)

	detail_name = Label.new()
	detail_name.add_theme_font_size_override("font_size", 32)
	detail_name.add_theme_color_override("font_color", TEXT_LIGHT)
	detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_col.add_child(detail_name)

	var badge_row = HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 8)
	name_col.add_child(badge_row)

	detail_badge = Label.new()
	detail_badge.add_theme_font_size_override("font_size", 16)
	badge_row.add_child(detail_badge)

	detail_type_label = Label.new()
	detail_type_label.add_theme_font_size_override("font_size", 16)
	detail_type_label.add_theme_color_override("font_color", TEXT_DIM)
	badge_row.add_child(detail_type_label)

	detail_chapter_label = Label.new()
	detail_chapter_label.add_theme_font_size_override("font_size", 15)
	detail_chapter_label.add_theme_color_override("font_color", TEXT_DIM)
	name_col.add_child(detail_chapter_label)

	# Level selector (towers only)
	level_bar = HBoxContainer.new()
	level_bar.add_theme_constant_override("separation", 8)
	name_col.add_child(level_bar)

	var lv_label = Label.new()
	lv_label.text = "Level:"
	lv_label.add_theme_font_size_override("font_size", 15)
	lv_label.add_theme_color_override("font_color", TEXT_DIM)
	level_bar.add_child(lv_label)

	level_btns.clear()
	for i in range(3):
		var btn = _make_small_button("Lv.%d" % (i + 1))
		btn.pressed.connect(func(lvl = i): _on_level_selected(lvl))
		level_bar.add_child(btn)
		level_btns.append(btn)

	# Stats block
	detail_stats = Label.new()
	detail_stats.add_theme_font_size_override("font_size", 17)
	detail_stats.add_theme_color_override("font_color", TEXT_LIGHT)
	detail_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(detail_stats)

	# Divider
	var sep = HSeparator.new()
	sep.add_theme_color_override("color", ACCENT_GOLD)
	sep.modulate = Color(1, 1, 1, 0.4)
	vbox.add_child(sep)

	# Description
	detail_desc = Label.new()
	detail_desc.add_theme_font_size_override("font_size", 16)
	detail_desc.add_theme_color_override("font_color", TEXT_DIM)
	detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(detail_desc)

	# Placeholder
	var placeholder = Label.new()
	placeholder.name = "Placeholder"
	placeholder.text = "Select an entry from the list."
	placeholder.add_theme_font_size_override("font_size", 22)
	placeholder.add_theme_color_override("font_color", TEXT_DIM)
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
	placeholder.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(placeholder)

# ══════════════════════════════════════════════════
#  TAB SWITCHING & LIST POPULATION
# ══════════════════════════════════════════════════

func _switch_tab(tab: String) -> void:
	current_tab = tab
	selected_family_id = ""
	selected_enemy_id  = ""
	selected_char_id   = ""

	# Style active tab
	_style_tab_active(tab_towers,     tab == "towers")
	_style_tab_active(tab_enemies,    tab == "enemies")
	_style_tab_active(tab_characters, tab == "characters")

	# Clear list
	for child in list_container.get_children():
		child.queue_free()

	if tab == "towers":
		_populate_tower_list()
	elif tab == "enemies":
		_populate_enemy_list()
	else:
		_populate_character_list()

	_clear_detail()

func _populate_tower_list() -> void:
	for family in tower_families:
		var btn = _make_list_button(
			_get_tower_display_name(family.id),
			""
		)
		btn.pressed.connect(func(fid = family.id): _on_tower_family_selected(fid))
		list_container.add_child(btn)

func _populate_character_list() -> void:
	var ally_header = Label.new()
	ally_header.text = "  Allies"
	ally_header.add_theme_font_size_override("font_size", 13)
	ally_header.add_theme_color_override("font_color", ACCENT_GOLD)
	ally_header.custom_minimum_size = Vector2(0, 28)
	list_container.add_child(ally_header)

	var ally_ids = ["Amaru", "Alon", "Lola Mutya", "LateMother"]
	for char_id in ally_ids:
		var btn = _make_list_button(character_display_names.get(char_id, char_id), "")
		btn.pressed.connect(func(cid = char_id): _on_character_selected(cid))
		list_container.add_child(btn)

	var villain_header = Label.new()
	villain_header.text = "  Antagonists"
	villain_header.add_theme_font_size_override("font_size", 13)
	villain_header.add_theme_color_override("font_color", BOSS_COLOR)
	villain_header.custom_minimum_size = Vector2(0, 28)
	list_container.add_child(villain_header)

	var villain_ids = ["HaringUldim", "GeneralMaruk"]
	for char_id in villain_ids:
		var btn = _make_list_button(character_display_names.get(char_id, char_id), "")
		btn.add_theme_color_override("font_color", BOSS_COLOR)
		btn.pressed.connect(func(cid = char_id): _on_character_selected(cid))
		list_container.add_child(btn)

func _populate_enemy_list() -> void:
	for chapter_data in enemy_chapters:
		# Chapter header
		var header = Label.new()
		header.text = "  Chapter %d — %s" % [chapter_data.chapter, chapter_data.name]
		header.add_theme_font_size_override("font_size", 13)
		header.add_theme_color_override("font_color", ACCENT_GOLD)
		header.custom_minimum_size = Vector2(0, 28)
		list_container.add_child(header)

		for enemy_id in chapter_data.enemies:
			var is_boss = _is_boss_enemy(enemy_id)
			var display  = enemy_display_names.get(enemy_id, enemy_id)
			var tag      = "  [BOSS]" if is_boss else ""
			var btn = _make_list_button(display, tag)
			if is_boss:
				btn.add_theme_color_override("font_color", BOSS_COLOR)
			btn.pressed.connect(func(eid = enemy_id): _on_enemy_selected(eid))
			list_container.add_child(btn)

# ══════════════════════════════════════════════════
#  SELECTION HANDLERS
# ══════════════════════════════════════════════════

func _on_tower_family_selected(family_id: String) -> void:
	AudioManager.play_ui_sound("button_click")
	selected_family_id = family_id
	selected_level = 0
	_show_tower_detail(family_id, 0)
	_highlight_list_button(family_id)

func _on_level_selected(level: int) -> void:
	if selected_family_id.is_empty():
		return
	selected_level = level
	_show_tower_detail(selected_family_id, level)
	_update_level_buttons(level)

func _on_character_selected(char_id: String) -> void:
	AudioManager.play_ui_sound("button_click")
	selected_char_id = char_id
	_show_character_detail(char_id)
	_highlight_list_button(char_id)

func _on_enemy_selected(enemy_id: String) -> void:
	AudioManager.play_ui_sound("button_click")
	selected_enemy_id = enemy_id
	_show_enemy_detail(enemy_id)
	_highlight_list_button(enemy_id)

# ══════════════════════════════════════════════════
#  DETAIL VIEWS
# ══════════════════════════════════════════════════

func _show_tower_detail(family_id: String, level: int) -> void:
	var family = _get_family(family_id)
	if family.is_empty():
		return
	var tower_key = family.upgrades[level]
	var data = GameData.tower_data.get(tower_key, {})
	if data.is_empty():
		return

	_set_placeholder_visible(false)

	# Portrait
	var img_path = tower_images.get(tower_key, "")
	_load_portrait(img_path)

	# Name
	detail_name.text = tower_display_names.get(tower_key, tower_key)

	# Rarity badge
	var rarity = data.get("rarity", "common")
	detail_badge.text = " ★ %s " % rarity.to_upper()
	detail_badge.add_theme_color_override("font_color", RARITY_COLORS.get(rarity, TEXT_LIGHT))

	# Type
	detail_type_label.text = " | %s" % data.get("category", "")

	# Chapter
	detail_chapter_label.text = "Chapter %d  ·  Tower %d of 10" % [family.chapter, family.chapter]

	# Level bar
	level_bar.visible = true
	_update_level_buttons(level)

	# Stats
	var dmg   = data.get("damage", 0)
	var rof   = data.get("rof", 1.0)
	var range_ = data.get("range", 0)
	var cost  = data.get("cost", 0)
	var dps   = 0.0
	if rof > 0.0:
		dps = dmg / rof
	detail_stats.text = (
		"⚔  Damage:     %d\n" % dmg +
		"🎯  Range:      %d\n" % range_ +
		"⏱  Fire Rate:  %.1fs  (%.1f DPS)\n" % [rof, dps] +
		"💰  Cost:       %d gold" % cost
	)

	# Description
	detail_desc.text = data.get("description", "No description available.")

func _show_enemy_detail(enemy_id: String) -> void:
	var data = GameData.enemy_data.get(enemy_id, {})
	if data.is_empty():
		return

	_set_placeholder_visible(false)

	# Portrait
	var img_path = enemy_images.get(enemy_id, "")
	_load_portrait(img_path)

	# Name
	detail_name.text = enemy_display_names.get(enemy_id, enemy_id)

	# Boss badge or tier
	var is_boss = _is_boss_enemy(enemy_id)
	if is_boss:
		detail_badge.text = " ☠  BOSS "
		detail_badge.add_theme_color_override("font_color", BOSS_COLOR)
	else:
		detail_badge.text = ""

	# Chapter info
	detail_type_label.text = ""
	var chap_name = _get_enemy_chapter_name(enemy_id)
	detail_chapter_label.text = chap_name

	# No level bar for enemies
	level_bar.visible = false

	# Stats
	var hp      = data.get("hp", 0)
	var speed   = data.get("speed", 0)
	var dmg     = data.get("damage", 0)
	var reward  = data.get("reward", 0)
	detail_stats.text = (
		"❤  Health:    %d\n" % hp +
		"💨  Speed:    %d\n" % speed +
		"⚔  Damage:   %d  (on base reach)\n" % dmg +
		"💰  Reward:   %d gold" % reward
	)

	# Description
	detail_desc.text = enemy_descriptions.get(enemy_id, "A creature of Philippine mythology.")

func _show_character_detail(char_id: String) -> void:
	_set_placeholder_visible(false)

	_load_portrait(character_portrait_paths.get(char_id, ""))

	# Name
	detail_name.text = character_display_names.get(char_id, char_id)

	# Role badge
	var char_data = character_list.filter(func(c): return c.id == char_id)
	var role = char_data[0].role if char_data.size() > 0 else ""
	detail_badge.text = ""
	detail_type_label.text = role
	detail_type_label.add_theme_color_override("font_color", ACCENT_GOLD if char_id not in ["HaringUldim", "GeneralMaruk"] else BOSS_COLOR)

	detail_chapter_label.text = ""

	# No level bar
	level_bar.visible = false

	# Backstory as "stats" block, lore as description
	detail_stats.text = character_backstories.get(char_id, "")
	detail_desc.text  = character_lore.get(char_id, "")

func _clear_detail() -> void:
	_set_placeholder_visible(true)
	detail_name.text    = ""
	detail_badge.text   = ""
	detail_type_label.text  = ""
	detail_chapter_label.text = ""
	detail_stats.text   = ""
	detail_desc.text    = ""
	detail_portrait.texture = null
	level_bar.visible   = false

# ══════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════

func _load_portrait(path: String) -> void:
	if path.is_empty():
		detail_portrait.texture = null
		return
	var tex = load(path)
	detail_portrait.texture = tex if tex else null

func _get_family(family_id: String) -> Dictionary:
	for f in tower_families:
		if f.id == family_id:
			return f
	return {}

func _get_tower_display_name(family_id: String) -> String:
	return tower_display_names.get(family_id, family_id)

func _is_boss_enemy(enemy_id: String) -> bool:
	var boss_ids = ["BossSpiritGuardian", "Kapre", "Manananggal", "Tikbalang", "Mambabarang",
	                "PugotBoss", "GuardianOfThreshold", "GeneralMaruk", "HaringUldim"]
	return enemy_id in boss_ids

func _get_enemy_chapter_name(enemy_id: String) -> String:
	for chapter_data in enemy_chapters:
		if enemy_id in chapter_data.enemies:
			return "Chapter %d — %s" % [chapter_data.chapter, chapter_data.name]
	return ""

func _update_level_buttons(active_level: int) -> void:
	for i in range(level_btns.size()):
		var btn: Button = level_btns[i]
		if i == active_level:
			_style_btn_active(btn)
		else:
			_style_btn_normal(btn)

func _highlight_list_button(entry_id: String) -> void:
	# Visual feedback: bold the matching button
	for child in list_container.get_children():
		if child is Button:
			var meta = child.get_meta("entry_id", "")
			if meta == entry_id:
				child.add_theme_color_override("font_color", ACCENT_GOLD)
			else:
				child.remove_theme_color_override("font_color")

func _set_placeholder_visible(visible_: bool) -> void:
	var ph = get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/PanelContainer2/Placeholder")
	if not ph:
		# Walk children to find it
		for child in get_children():
			var found = child.find_child("Placeholder", true, false)
			if found:
				found.visible = visible_
				return

# ══════════════════════════════════════════════════
#  WIDGET FACTORIES
# ══════════════════════════════════════════════════

func _make_panel(bg_color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left     = 10
	style.corner_radius_top_right    = 10
	style.corner_radius_bottom_left  = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = Color(ACCENT_GOLD.r, ACCENT_GOLD.g, ACCENT_GOLD.b, 0.35)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_button(text: String, min_w: int, min_h: int) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_w, min_h)
	btn.add_theme_font_size_override("font_size", 16)
	_apply_std_stylebox(btn)
	return btn

func _make_tab_button(text: String, min_w: int, min_h: int) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_w, min_h)
	btn.add_theme_font_size_override("font_size", 18)
	_apply_std_stylebox(btn)
	return btn

func _make_small_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(80, 52)
	btn.add_theme_font_size_override("font_size", 14)
	_style_btn_normal(btn)
	return btn

func _make_list_button(label: String, sub: String) -> Button:
	var btn = Button.new()
	btn.text = label + ("  " + sub if sub else "")
	btn.set_meta("entry_id", label)
	btn.custom_minimum_size = Vector2(0, 44)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 15)

	var normal_sb = StyleBoxFlat.new()
	normal_sb.bg_color = Color(0, 0, 0, 0)
	normal_sb.content_margin_left = 12
	btn.add_theme_stylebox_override("normal", normal_sb)

	var hover_sb = StyleBoxFlat.new()
	hover_sb.bg_color = Color(ACCENT_GOLD.r, ACCENT_GOLD.g, ACCENT_GOLD.b, 0.15)
	hover_sb.corner_radius_top_left     = 6
	hover_sb.corner_radius_top_right    = 6
	hover_sb.corner_radius_bottom_left  = 6
	hover_sb.corner_radius_bottom_right = 6
	hover_sb.content_margin_left = 12
	btn.add_theme_stylebox_override("hover", hover_sb)

	var pressed_sb = hover_sb.duplicate()
	pressed_sb.bg_color = Color(ACCENT_GOLD.r, ACCENT_GOLD.g, ACCENT_GOLD.b, 0.28)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	btn.add_theme_color_override("font_color",          TEXT_LIGHT)
	btn.add_theme_color_override("font_hover_color",    ACCENT_GOLD)
	btn.add_theme_color_override("font_pressed_color",  ACCENT_GOLD)
	btn.mouse_entered.connect(func(): AudioManager.play_ui_sound("button_hover"))
	return btn

func _apply_std_stylebox(btn: Button) -> void:
	var n = StyleBoxFlat.new()
	n.bg_color     = Color(0.5, 0.25, 0.08, 1.0)
	n.border_color = Color(1.0, 0.8, 0.35, 1.0)
	for k in ["border_width_left","border_width_right","border_width_top","border_width_bottom"]:
		n.set(k, 2)
	for k in ["corner_radius_top_left","corner_radius_top_right","corner_radius_bottom_left","corner_radius_bottom_right"]:
		n.set(k, 8)

	var h = n.duplicate()
	h.bg_color = Color(0.65, 0.40, 0.15, 1.0)

	var p = n.duplicate()
	p.bg_color = Color(0.30, 0.15, 0.05, 1.0)

	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",         Color(1.0, 0.95, 0.75))
	btn.add_theme_color_override("font_hover_color",   Color(1.0, 1.00, 0.90))
	btn.add_theme_color_override("font_pressed_color", Color(0.9, 0.80, 0.60))
	btn.mouse_entered.connect(func(): AudioManager.play_ui_sound("button_hover"))

func _style_tab_active(btn: Button, active: bool) -> void:
	var n = StyleBoxFlat.new()
	if active:
		n.bg_color = Color(0.65, 0.40, 0.15, 1.0)
	else:
		n.bg_color = Color(0.30, 0.15, 0.05, 0.85)
	n.border_color = ACCENT_GOLD
	for k in ["border_width_left","border_width_right","border_width_top","border_width_bottom"]:
		n.set(k, 2)
	for k in ["corner_radius_top_left","corner_radius_top_right","corner_radius_bottom_left","corner_radius_bottom_right"]:
		n.set(k, 8)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover",  n)
	btn.add_theme_color_override("font_color", ACCENT_GOLD if active else TEXT_DIM)

func _style_btn_active(btn: Button) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = ACCENT_GOLD
	for k in ["corner_radius_top_left","corner_radius_top_right","corner_radius_bottom_left","corner_radius_bottom_right"]:
		s.set(k, 6)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("hover",   s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_color_override("font_color", Color(0.1, 0.05, 0.0))

func _style_btn_normal(btn: Button) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.25, 0.18, 0.08, 1.0)
	s.border_color = Color(ACCENT_GOLD.r, ACCENT_GOLD.g, ACCENT_GOLD.b, 0.5)
	for k in ["border_width_left","border_width_right","border_width_top","border_width_bottom"]:
		s.set(k, 1)
	for k in ["corner_radius_top_left","corner_radius_top_right","corner_radius_bottom_left","corner_radius_bottom_right"]:
		s.set(k, 6)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("hover",   s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_color_override("font_color", TEXT_DIM)

# ══════════════════════════════════════════════════
#  NAVIGATION
# ══════════════════════════════════════════════════

func _on_back_pressed() -> void:
	AudioManager.play_ui_sound("button_click")
	get_tree().change_scene_to_file("res://Scenes/UIScenes/main_menu.tscn")
