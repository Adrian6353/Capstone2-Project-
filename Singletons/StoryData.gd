extends Node
## StoryData — All narrative content and per-map conditions for Story Mode.
##
## Structure:
##   SEQUENCES  — dict keyed by "{chapter}_{event}" (e.g. "ch1_intro",
##                "ch1_map1", "ch1_boss_intro", "ch1_outro", "prologue").
##                Each value is an Array of steps:
##                  ["panel", title, body]      — full-screen text panel
##                  ["dialogue", speaker, text] — character dialogue box
##
##   MAP_CONDITIONS — per-map overrides applied in GameScene._ready():
##                  {lives: int, starting_gold: int, flags: Array[String]}
##                  -1 = use default.  flags are tags for future mechanic systems.
##
##   MAP_NAMES — display name for each of the 40 story stages (10 ch × 4 maps).

# ---------------------------------------------------------------------------
# Cutscene sequence data
# ---------------------------------------------------------------------------

const SEQUENCES: Dictionary = {

	# ---- PROLOGUE (shown before Chapter 1 first run) ----------------------
	"prologue": [
		["panel",
			"Bantay ng Siyam na Hiyas",
			"Long before roads cut through the mountains, the land of Bayanihan was held together by a hidden weave of sacred force — the Habing Liwanag.\n\nIt stretched through shrines, caves, ancient trees, and hill paths. Guardians known as the Bantay-Diwa quietly tended these ward-lines. Because of them, villages slept in peace."],
		["panel",
			"A Crimson Eclipse",
			"That peace ended the night a crimson eclipse darkened the sky.\n\nFarm animals vanished without tracks. Lanterns went out in windless rooms. Shrine stones cracked. The elders whispered that the Habing Liwanag was unraveling.\n\nAt the heart of the collapse was the Ulgin Court — led by Haring Uldim, who did not want the boundary repaired. He wanted it destroyed."],
		["dialogue", "Alon",
			"The Habing Liwanag is unraveling. The Ulgin Court tears at the ward-lines from the other side. Villages lose the light. Shrines go dark."],
		["dialogue", "Amaru",
			"Why are you telling me this?"],
		["dialogue", "Alon",
			"Because your mother walked this road before you. She was Bantay-Diwa. That duty did not die with her — it waited for you."],
		["dialogue", "Amaru",
			"I am a scout. I protect one road, one village."],
		["dialogue", "Alon",
			"That is how it begins. The medallion your grandmother placed in your hands — the Sanghaya — holds nine sleeping hiyas, each bound to the old ward-lines. Awaken them, and the weave may yet be restored."],
		["dialogue", "Amaru",
			"Then I will walk it. One ward-stone at a time."],
	],

	# ---- CHAPTER 1 — Embers at the Outskirts ------------------------------
	"ch1_intro": [
		["panel",
			"Chapter 1 — Embers at the Outskirts",
			"Bayanihan's outer ward-stones have cracked. Minor creatures slip through the gaps — scattered aswang, tiyanak scouts, restless strays driven by hunger rather than strategy.\n\nAmaru is not yet a legendary warrior. He is a protector trying to hold one road, one bend, one village edge at a time.\n\nBut the cracks will widen, and what follows will be far greater than strays."],
		["dialogue", "Alon",
			"The first fractures are small — but they will grow. Each creature that passes makes the breach easier for the next."],
		["dialogue", "Amaru",
			"Then we close it here, before the next wave."],
	],
	"ch1_map1": [
		["panel",
			"First Signs",
			"Small spirits are slipping through a newly cracked ward-stone at the rice paths. Hold the path and let none reach the village."],
		["dialogue", "Alon",
			"You have one chance. Let not a single one pass through."],
		["dialogue", "Amaru",
			"Understood. Nothing gets through."],
	],
	"ch1_map2": [
		["panel",
			"Cracked Stones",
			"The breach has widened. Larger groups push through at once. You have three chances before the ward-line breaks entirely."],
		["dialogue", "Amaru",
			"Three lives. I will not waste them."],
		["dialogue", "Alon",
			"Then hold the line. Every one counts."],
	],
	"ch1_map3": [
		["panel",
			"Pushing Deeper",
			"Resources are thin at the outer ward. Gold is scarce and the creatures press forward without rest. Every tower placement must count."],
		["dialogue", "Amaru",
			"Then every placement counts. We make it work."],
		["dialogue", "Alon",
			"Spend carefully. There will be no second chance to correct a poor choice."],
	],
	"ch1_boss_intro": [
		["panel",
			"The Weave Breaker",
			"A hulking force sent by the Ulgin Court — not to destroy a village, but to tear the boundary open completely. If it reaches the heart of Bayanihan, the ward-line falls for good."],
		["dialogue", "Alon",
			"This is no stray. This thing was sent with purpose. Drive it back, Amaru — before it breaks through entirely."],
		["dialogue", "Amaru",
			"It will not pass."],
	],
	"ch1_outro": [
		["panel",
			"Hiyas ng Alab — Awakened",
			"The Weave Breaker falls. Bayanihan's outer boundary holds — for now.\n\nFor the first time, the Sanghaya pulses with living light. The Shard of the Ember has awakened."],
		["dialogue", "Amaru",
			"The medallion... it's warm."],
		["dialogue", "Alon",
			"The Hiyas ng Alab — the Shard of the Ember. One of nine. But hear this: the enemy is not testing one village. It is testing the entire world. The road ahead is long."],
		["dialogue", "Amaru",
			"Then we move before the fire spreads any further."],
	],

	# ---- CHAPTER 2 — The Balete Giant -------------------------------------
	"ch2_intro": [
		["panel",
			"Chapter 2 — The Balete Giant",
			"Following a broken ward-line into Gubat ng Talisik, Amaru enters a forest gripped by permanent dusk. Roots rise where paths should be. The air hangs heavy with unseen eyes.\n\nAt the center of the corruption stands a massive balete tree — and the twisted spirit who now rules it."],
		["dialogue", "Alon",
			"When a ward-line weakens in a place this old, the land itself begins to lean toward the Ligaw na Daigdig. This forest no longer protects life. It traps it."],
		["dialogue", "Amaru",
			"Then we cut through to the center."],
	],
	"ch2_map1": [
		["panel",
			"Into the Dark",
			"This forest swallows light. The paths ahead are hidden until creatures are nearly upon you. Position your towers with care."],
		["dialogue", "Alon",
			"You cannot see far ahead. Trust your placements."],
		["dialogue", "Amaru",
			"Build by memory. The path doesn't change just because we can't see it."],
	],
	"ch2_map2": [
		["panel",
			"Twisted Paths",
			"Root obstacles block the usual build tiles. The trees do not want you here. Work around what they have taken."],
		["dialogue", "Amaru",
			"Less space, more pressure. We adapt."],
		["dialogue", "Alon",
			"The trees do not want us here. That is precisely why we continue."],
	],
	"ch2_map3": [
		["panel",
			"Corrupted Wardens",
			"The forest's own guardian spirits have turned against the living. Armored and relentless, they will not fall easily."],
		["dialogue", "Alon",
			"Focus your fire at the chokepoints. Sustained damage is the only way through armor this dense."],
		["dialogue", "Amaru",
			"They won't hold forever. We just need to outlast them."],
	],
	"ch2_boss_intro": [
		["panel",
			"The Kapre",
			"Once a guardian of stillness and place, the great Kapre has been warped by the Ulgin Court. Now it commands the forest to trap and suffocate. As it walks, the aura around it slows everything nearby."],
		["dialogue", "Alon",
			"It carries the corruption with it. Your towers will slow — compensate for that before it reaches you."],
		["dialogue", "Amaru",
			"Bring down the one who commands this grove."],
	],
	"ch2_outro": [
		["panel",
			"Hiyas ng Ugat-Lupa — Awakened",
			"The Kapre falls. The forest's pressure lifts — slowly, like a fist unclenching.\n\nA pattern emerges. Uldim is not simply sending monsters outward. He is corrupting old protectors and turning sacred places into weapons.\n\nThe Shard of the Deep Roots awakens."],
		["dialogue", "Amaru",
			"It wasn't just a monster. It was a guardian once."],
		["dialogue", "Alon",
			"Yes. That is Uldim's cruelty — he turns what once protected us into what now destroys us. Remember that."],
	],
	# ---- CHAPTER 3 — Wings Over Dapithapon -----------------------
	"ch3_intro": [
		["panel",
			"Chapter 3 — Wings Over Dapithapon",
			"A coastal farming town lives in dread of the coming night. Roofs are lined with lanterns, but even their light cannot hold back the shadows in the air.\n\nThe enemy here does not crawl through fields or forests. It falls from above."],
		["dialogue", "Alon",
			"Flying aswang and shrieking spirits. They bypass walls, rooftops, and ordinary thinking. Your towers need reach upward, not just forward."],
		["dialogue", "Amaru",
			"Then we cover the sky."],
	],
	"ch3_map1": [
		["panel",
			"Dusk Patrol",
			"Not everything that threatens this town walks on the ground. Aerial enemies approach at dusk — only towers with the right range can touch them."],
		["dialogue", "Alon",
			"Cover the air lanes first. They will exploit every blind spot you leave."],
		["dialogue", "Amaru",
			"First time facing the sky. Let's not let it catch us unprepared."],
	],
	"ch3_map2": [
		["panel",
			"Lantern Lines",
			"Three lanterns keep watch over the sky roads tonight. Each enemy that leaks through extinguishes one. Do not let them all go dark."],
		["dialogue", "Amaru",
			"The people are counting on those lights. Three lives — we cannot afford to waste them."],
		["dialogue", "Alon",
			"Hold the air roads. Keep every lantern burning."],
	],
	"ch3_map3": [
		["panel",
			"Rooftop Rush",
			"After dusk they gain speed. Unfinished waves will overlap with the next if you fall behind. Clear each wave before they stack."],
		["dialogue", "Alon",
			"Speed and coverage — both matter now. Do not let them pile up."],
		["dialogue", "Amaru",
			"We don't fall behind. Not tonight."],
	],
	"ch3_boss_intro": [
		["panel",
			"The Manananggal",
			"The Manananggal is ruthless and unpredictable. It alternates between sky and ground — shifting whenever it takes heavy damage — to exploit the gaps you leave behind."],
		["dialogue", "Alon",
			"Watch where it moves. Ground or sky, she will find the opening you leave."],
		["dialogue", "Amaru",
			"Then we leave none."],
	],
	"ch3_outro": [
		["panel",
			"Hiyas ng Takipsilim — Awakened",
			"The Manananggal falls. Dapithapon survives the night.\n\nRumors begin spreading along the old trade roads — that a new Bantay-Diwa walks the path of the ward-lines.\n\nThe Shard of the Twilight awakens."],
		["dialogue", "Amaru",
			"People are talking about us."],
		["dialogue", "Alon",
			"Let them. Fear and hope both travel fast. Right now, the hope is more useful."],
	],
	# ---- CHAPTER 4 — The Crooked Pass ----------------------------
	"ch4_intro": [
		["panel",
			"Chapter 4 — The Crooked Pass",
			"The mountain pass ahead is ruled by illusion, fog, and deliberate confusion. Travelers walk in circles. Paths reverse themselves. Openings appear where there were none.\n\nA Tikbalang has made this ridge its playground — and now it serves the Ulgin Court."],
		["dialogue", "Alon",
			"Stop relying on certainty. Here you must trust instinct, memory, and your placements even when the path seems to shift beneath you."],
		["dialogue", "Amaru",
			"If the road won't stay still, we hold every position until it does."],
	],
	"ch4_map1": [
		["panel",
			"The Fog Rolls In",
			"Thick fog hides the path beyond a short distance. You cannot see threats until they are almost upon you. Trust your tower positions — they will see what you cannot."],
		["dialogue", "Alon",
			"Visibility is gone. Place carefully and hold your ground."],
		["dialogue", "Amaru",
			"We build where the path has to go. The fog doesn't change that."],
	],
	"ch4_map2": [
		["panel",
			"Shifting Ground",
			"The enemy path reroutes once per wave. Towers that no longer cover the path must be repositioned quickly or they go silent."],
		["dialogue", "Amaru",
			"The road is moving. Check your coverage after every shift."],
		["dialogue", "Alon",
			"The Tikbalang is warming up. This is practice for something far worse."],
	],
	"ch4_map3": [
		["panel",
			"Wrong Way",
			"Enemy entry points swap sides halfway through each wave. What was the front becomes the rear. Watch for the switch."],
		["dialogue", "Alon",
			"They found a way around. Cover both ends."],
		["dialogue", "Amaru",
			"Both ends. Nothing gets through either side."],
	],
	"ch4_boss_intro": [
		["panel",
			"The Tikbalang",
			"The Tikbalang does not simply fight — it rewrites the battlefield. During the encounter it will reroute the field three times, forcing you to adapt with every shift."],
		["dialogue", "Alon",
			"Pin him down before he rewrites everything."],
		["dialogue", "Amaru",
			"He won't confuse us twice in the same direction."],
	],
	"ch4_outro": [
		["panel",
			"Hiyas ng Ulirat — Awakened",
			"The Tikbalang falls and the mountain pass straightens. The mist thins.\n\nAmaru realizes something important: Uldim's war is not built on strength alone. It is built on disorientation.\n\nThe Shard of the Waking Mind awakens."],
		["dialogue", "Amaru",
			"He makes us doubt the ground beneath our feet. That's the real weapon."],
		["dialogue", "Alon",
			"Yes. And now you see it clearly. That is why this shard matters."],
	],
	# ---- CHAPTER 5 — The Black Swarm -----------------------------
	"ch5_intro": [
		["panel",
			"Chapter 5 — The Black Swarm",
			"At the cursed edge of Libliban, Amaru finds a village already half-defeated before the fighting begins. The people are weakened, the land feels sick, and even the defenses seem to fail for no obvious reason.\n\nSome poisons what already exists. Some turns strength into weakness, and hope into exhaustion."],
		["dialogue", "Alon",
			"The Mambabarang does not conquer through assault. She corrodes. Your towers will not perform as expected here."],
		["dialogue", "Amaru",
			"Then we work with what we have and we do not stop."],
	],
	"ch5_map1": [
		["panel",
			"Something in the Air",
			"Certain enemies carry a passive curse while they walk, slowing nearby towers just by passing. Kill them quickly before they linger too long."],
		["dialogue", "Alon",
			"Even passing near them feels wrong. Eliminate them before the aura spreads."],
		["dialogue", "Amaru",
			"Kill them fast. Don't let them slow us down just by walking past."],
	],
	"ch5_map2": [
		["panel",
			"Weakened Defenses",
			"The curse has already struck. All towers begin at half attack speed and recover incrementally after each wave. Fight through it."],
		["dialogue", "Amaru",
			"Slower, yes. But still standing. That has to be enough."],
		["dialogue", "Alon",
			"The curse hit the defenses before it hit you. Do not let it finish what it started."],
	],
	"ch5_map3": [
		["panel",
			"Sapping the Line",
			"Swarm enemies leave behind lingering zones even after they fall. These zones reduce nearby tower range for the following wave. Watch which towers lose their reach."],
		["dialogue", "Alon",
			"They poison the ground they walk on. Plan your coverage for what comes after."],
		["dialogue", "Amaru",
			"They leave a curse behind even in defeat. We build past it anyway."],
	],
	"ch5_boss_intro": [
		["panel",
			"The Mambabarang",
			"She does not face you directly. Instead she continuously silences your highest-performing tower — forcing you to build layered rather than relying on one dominant defense."],
		["dialogue", "Alon",
			"She will find your strongest tower first. Plan around it — do not let one tower carry everything."],
		["dialogue", "Amaru",
			"Then we build many strengths, not one."],
	],
	"ch5_outro": [
		["panel",
			"Hiyas ng Lunas — Awakened",
			"The Mambabarang is defeated. Libliban's curse begins to lift — slowly, unevenly, like color returning to a drained canvas.\n\nAmaru understands now: repairing the world will require more than defeating enemies. It will require healing what fear and neglect have already damaged.\n\nThe Shard of the Remedy awakens."],
		["dialogue", "Amaru",
			"We won. But it doesn't feel like a victory."],
		["dialogue", "Alon",
			"No. But the village is still here. They can heal now. Sometimes that is the best you can give."],
	],
	# ---- CHAPTER 6 — Hunt Beneath Noonday ------------------------
	"ch6_intro": [
		["panel",
			"Chapter 6 — Hunt Beneath Noonday",
			"In Sanlira, danger wears invisibility. Hidden spirits and prowling sigbin strike from blind spots. The people have grown used to fearing what they cannot see.\n\nSome evils survive not because they are stronger, but because no one has been able to name them, track them, or bring them into the light."],
		["dialogue", "Alon",
			"Your towers cannot target what they cannot detect. You must reveal the threat before you can fight it."],
		["dialogue", "Amaru",
			"Then detection comes first. We build eyes before weapons."],
	],
	"ch6_map1": [
		["panel",
			"Empty Streets",
			"Some enemies are invisible while walking. They can only be targeted inside a detection tower's range. Build detection first — then build the fire to fill it."],
		["dialogue", "Alon",
			"You cannot stop what you cannot see. Build the light before everything else."],
		["dialogue", "Amaru",
			"Eyes first. Then teeth."],
	],
	"ch6_map2": [
		["panel",
			"Blind Spots",
			"Not every section of the map can hold a detection tower. Enemies know where your eyes are — force them through the zones that are covered."],
		["dialogue", "Amaru",
			"If I can't see everywhere, I make them come through where I can see."],
		["dialogue", "Alon",
			"Correct. You cannot see everywhere — but you can choose where they must pass."],
	],
	"ch6_map3": [
		["panel",
			"Shadows at Noon",
			"Invisible enemies now outnumber visible ones. Plain daylight means nothing to something that hides inside it. Coverage and detection are no longer support — they are the primary defense."],
		["dialogue", "Alon",
			"The dark is in the light now. Do not let them through."],
		["dialogue", "Amaru",
			"An invisible army in broad daylight. Let's make it a very short war."],
	],
	"ch6_boss_intro": [
		["panel",
			"The Pugot Chieftain",
			"At half health, the Pugot Chieftain turns invisible — vanishing until it re-enters a detection zone. You cannot fight what you have not revealed."],
		["dialogue", "Alon",
			"Reveal him again the moment he disappears. Do not let him walk unchecked."],
		["dialogue", "Amaru",
			"He can't hide forever. We'll find him."],
	],
	"ch6_outro": [
		["panel",
			"Hiyas ng Aninag — Awakened",
			"The Pugot Chieftain is revealed and defeated.\n\nAmaru has changed. He is no longer simply reacting to each threat. He is beginning to read the enemy's design.\n\nThe Shard of the Silhouette awakens."],
		["dialogue", "Amaru",
			"I can see the shape of it now. Uldim doesn't just send strength — he sends doubt, confusion, invisibility. He makes us fight blind."],
		["dialogue", "Alon",
			"And yet here you are, seeing clearly. That is no small thing."],
	],
	# ---- CHAPTER 7 — The Red-Moon Siege --------------------------
	"ch7_intro": [
		["panel",
			"Chapter 7 — The Red-Moon Siege",
			"Under a blood-red moon, Bayanihan is attacked from multiple directions at once. Roads fall. Civilians flee. Shrines are threatened.\n\nThe attack is not random. Uldim wants to break Amaru by making him watch his home collapse."],
		["dialogue", "Alon",
			"This is personal. Uldim chose this village because it is yours. He wants you to fail here, where you cannot afford to."],
		["dialogue", "Amaru",
			"Then we make sure he doesn't get what he wants."],
	],
	"ch7_map1": [
		["panel",
			"The Bells Ring",
			"Two roads, one night. Both must be held. Letting either lane leak costs a life."],
		["dialogue", "Amaru",
			"Two fronts. We split our attention and hold both."],
		["dialogue", "Alon",
			"Neglecting one is the same as opening a door. Cover them equally."],
	],
	"ch7_map2": [
		["panel",
			"Civilian Crossings",
			"The people have not finished evacuating. Three groups remain in the breach. Each enemy that leaks through threatens another group."],
		["dialogue", "Alon",
			"Buy them time. Every second you hold is another step toward safety."],
		["dialogue", "Amaru",
			"They're counting on us. Not a single one gets through."],
	],
	"ch7_map3": [
		["panel",
			"The Outer Wall Falls",
			"The outer wall is gone. Three lanes breach the center at the same time. Everything is coming through now."],
		["dialogue", "Amaru",
			"All of it at once. Hold every line — there is no reserve."],
		["dialogue", "Alon",
			"This is what Uldim wanted — to overwhelm you at home. Do not give him that satisfaction."],
	],
	"ch7_boss_intro": [
		["panel",
			"The Alpha Aswang",
			"The Alpha Aswang leads the siege from within the horde. Its howl grants a speed burst to every enemy currently on the path — making an already brutal assault faster and more relentless."],
		["dialogue", "Alon",
			"Silence the Alpha. When it falls, the horde loses its momentum."],
		["dialogue", "Amaru",
			"This is for Bayanihan. It ends here."],
	],
	"ch7_outro": [
		["panel",
			"Hiyas ng Tipan — Awakened",
			"The Alpha Aswang is defeated. Bayanihan survives.\n\nIn the aftermath, an elder reveals a crucial truth: the Sanghaya was woven from the ward-lines themselves through an older pact between human keepers and benevolent spirit allies. It was never meant to dominate — only to preserve the balance.\n\nThe Shard of the Ancient Pact awakens."],
		["dialogue", "Amaru",
			"The Sanghaya isn't a weapon. It never was."],
		["dialogue", "Alon",
			"No. It is a promise. And the enemy knows that. From here, they stop testing you. They will try to end the line of keepers entirely."],
	],
	# ---- CHAPTER 8 — Gate of the Wild Realm ----------------------
	"ch8_intro": [
		["panel",
			"Chapter 8 — Gate of the Wild Realm",
			"With several ward-lines restored, Amaru and Alon reach the Broken Gateway — the threshold between the human world and the Ligaw na Daigdig.\n\nThe land itself is unstable. Paths shift. Ground changes. The boundary is no longer a line but a wound."],
		["dialogue", "Alon",
			"I have something to tell you. But not yet. There is still a gate to pass through first."],
		["dialogue", "Amaru",
			"Then we pass through it."],
	],
	"ch8_map1": [
		["panel",
			"Between Two Worlds",
			"The path shifts slightly every wave. Towers not adjacent to the new path segment go silent until repositioned. This place is neither fully here nor fully there — keep your defenses on the path."],
		["dialogue", "Alon",
			"The ground cannot decide what it is. You must decide faster."],
		["dialogue", "Amaru",
			"Moving path, moving towers. We keep up no matter where it goes."],
	],
	"ch8_map2": [
		["panel",
			"Unstable Ground",
			"Buildable tiles shift every few waves, temporarily invalidating some placements. Nothing stays fixed at the threshold. Move fast when the ground changes."],
		["dialogue", "Amaru",
			"Every time I think I've found solid ground, it moves again."],
		["dialogue", "Alon",
			"That is the nature of a wound in the world. You cannot wait for it to settle. Move with it."],
	],
	"ch8_map3": [
		["panel",
			"Spirit Overflow",
			"Certain enemies split into two weaker forms when killed. Killing one makes two more. Concentrate fire — do not spread it thin."],
		["dialogue", "Alon",
			"Do not let them divide unchecked. Focused fire. Always."],
		["dialogue", "Amaru",
			"One target at a time. All the way down."],
	],
	"ch8_boss_intro": [
		["panel",
			"Guardian of the Threshold",
			"The boundary made hostile. The gate itself has learned to resist healing.\n\nTowers directly in its path are negated as it moves. Attack from the angles it cannot silence — from the sides, the overlap zones, the positions it does not expect."],
		["dialogue", "Alon",
			"Attack from the angles it cannot silence. Do not stand in its path."],
		["dialogue", "Amaru",
			"Then we come from every direction at once."],
	],
	"ch8_outro": [
		["panel",
			"Hiyas ng Hangganan — Awakened",
			"The Guardian falls. The Broken Gateway opens.\n\nAlon finally reveals what she had kept hidden: she once maintained the Habing Liwanag from the spirit side — and stayed at the boundary after others fled, waiting for a human keeper strong enough to finish what had been left undone. She did not guide Amaru by chance.\n\nShe had been waiting for him.\n\nThe Shard of the Threshold awakens."],
		["dialogue", "Alon",
			"I should have told you sooner. I stayed at the boundary because I believed someone would come. I was waiting for you, Amaru."],
		["dialogue", "Amaru",
			"You've been here all along. How long?"],
		["dialogue", "Alon",
			"Long enough to know that you were worth the wait."],
		["dialogue", "Amaru",
			"Then let's make sure it wasn't for nothing. The way is open."],
		["panel",
			"The Shard of the Threshold — Awakened",
			"The Hiyas ng Hangganan awakens. The way into Uldim's domain now lies open.\n\nAmaru steps through — not alone."],
	],
	# ---- CHAPTER 9 — Court of Hollow Roots --------------------------------
	"ch9_intro": [
		["panel",
			"Chapter 9 — Court of Hollow Roots",
			"Inside the Ulgin Domain, Amaru finds a realm already reshaped into a disciplined stronghold. This is no chaotic spirit wilderness — it is an organized enemy state.\n\nThe Ulgin Court fights with formation, support, and layered discipline."],
		["dialogue", "Alon",
			"These are not wild spirits. They have ranks, formations, healers. They move with purpose."],
		["dialogue", "Amaru",
			"Then we learn their pattern and break it."],
	],
	"ch9_map1": [
		["panel",
			"Into Enemy Ground",
			"Enemies walk in tight column formations. Area-of-effect towers will be especially effective here. Use their discipline against them."],
		["dialogue", "Amaru",
			"They line up for us. Let's not waste it."],
	],
	"ch9_map2": [
		["panel",
			"Elite Wardens",
			"Elite armored enemies appear — heavily defended and relentless. They must be held at chokepoints long enough for sustained damage to bring them down."],
		["dialogue", "Alon",
			"The Court sends its best here. Make every shot count."],
	],
	"ch9_map3": [
		["panel",
			"Support Lines",
			"Healer enemies restore nearby units continuously. If you damage a target and ignore the healer beside it, the damage undoes itself. Kill the support first."],
		["dialogue", "Alon",
			"Do not spread fire. Kill the healer first, then what it was protecting."],
		["dialogue", "Amaru",
			"The healers first. Everything else can wait."],
	],
	"ch9_boss_intro": [
		["dialogue", "Alon",
			"The hiyas are watching. Hold the line."],
		["panel",
			"What the Records Reveal",
			"Inside the domain, Amaru uncovers old records — and what they contain changes the nature of the fight ahead.\n\nGeneral Maruk was not always the enemy's champion. He was once a spirit warden who fought on the side of the ward-lines. He defected because he came to believe the boundary between worlds had become a prison rather than a pact.\n\nHe did not join Uldim out of cruelty. He joined because he lost faith that repair was possible."],
		["panel",
			"General Maruk",
			"He is always flanked by elite guards. He takes full damage only after they are cleared.\n\nThis is not merely a physical confrontation. Maruk believes forced unity is better than maintained separation. Amaru believes the weave must be restored with care — not collapsed in desperation. Only one of them is right."],
		["dialogue", "Amaru",
			"He believed in the same things we do — and gave up on them. That's the hardest kind of enemy to face."],
		["dialogue", "Alon",
			"Yes. But giving up on the right answer does not make the wrong one correct. Tear down his guard wall — then face what he chose to become."],
	],
	"ch9_outro": [
		["panel",
			"Ang Perlas ng Silanganan — Awakened",
			"General Maruk falls.\n\nFor the first time, Amaru has faced an enemy who was not corrupted — but ideologically opposed. Maruk believed forced unity was better than maintained separation. Amaru believes the weave must be restored with care, not collapsed in desperation.\n\nThe final piece of the Sanghaya — Ang Perlas ng Silanganan, the Pearl of the Orient — awakens. All nine hiyas are now active. The Sanghaya reaches its full resonance.\n\nAmaru stands before the last door — not as a chosen child, but as a true keeper."],
		["dialogue", "Amaru",
			"He wasn't wrong to want the worlds to stop hurting each other. He was wrong about how."],
		["dialogue", "Alon",
			"That is the hardest kind of enemy to face. One who almost had the right answer. Now — the last door. And behind it, Haring Uldim."],
	],

	# ---- CHAPTER 10 — The Last Weave -------------------------------------
	"ch10_intro": [
		["panel",
			"Chapter 10 — The Last Weave",
			"At the center of the collapsing boundary between worlds, Amaru makes his final stand.\n\nOld enemies, broken terrains, warped creatures, and elite spirits gather around the widening tear. This is the point at which the world either holds — or collapses forever."],
		["dialogue", "Alon",
			"Everything you have learned, every ward-line you have held, every shard you have awakened — it has all led here."],
		["dialogue", "Amaru",
			"Then we end it here. Not with collapse. With restoration."],
	],
	"ch10_map1": [
		["panel",
			"The World Between",
			"The path layout changes completely between waves. Nothing here stays the same. You are fighting on ground that should not exist — adapt or fall."],
		["dialogue", "Alon",
			"There is no stable position. Only the one you hold until the next shift."],
	],
	"ch10_map2": [
		["panel",
			"Fragments of the Ward",
			"Two lives remain. The scattered hiyas of the Sanghaya are everywhere around you — and every enemy that passes through dims them further. Hold the line completely."],
		["dialogue", "Amaru",
			"Two chances. That's all we need. We do not fall."],
	],
	"ch10_map3": [
		["panel",
			"All Forces Converge",
			"Every enemy you have ever faced is here. Flying, armored, invisible, cursed, split, healing — all at once. Remember what you learned."],
		["dialogue", "Alon",
			"Nothing new. You have faced all of this before. Trust yourself."],
		["dialogue", "Amaru",
			"Then let them come."],
	],
	"ch10_boss_intro": [
		["panel",
			"Haring Uldim",
			"He is not afraid of you. He believes the old balance is already dead — and that merging the worlds is the only honest future left.\n\nThree phases. In the first, he speeds every enemy around him. In the second, he negates towers in his path. In the third, all lanes open and his aura expands.\n\nThis is what it was all for."],
		["dialogue", "Alon",
			"He is not a monster. He is a king who chose destruction over patience. Show him what patience built."],
		["dialogue", "Amaru",
			"The ward-lines were never meant to be a wall of fear. They were meant to be a living agreement. I will show him what that means."],
	],
	"ch10_outro": [
		["panel",
			"The Habing Liwanag — Restored",
			"Haring Uldim is defeated.\n\nAmaru does not close the rift by force. He reweaves it.\n\nThe nine hiyas of the Sanghaya resonate together — no longer nine separate sparks, but a single living weave. The Habing Liwanag is restored: not identical to what came before, but stronger, capable of bending without breaking.\n\nThe human realm and spirit realm remain distinct — yet newly balanced.\n\nA few weeks later, Amaru walks the old outskirts path with Alon — not to fight, but to see whether the new weave is holding.\n\nIt is. The land feels lighter."],
		["dialogue", "Alon",
			"The ward-lines hold."],
		["dialogue", "Amaru",
			"They always were worth protecting."],
		["dialogue", "Alon",
			"The ward-lines are never protected by strength alone. They are protected by those willing to remember, repair, and stand their ground when darkness insists that nothing can be saved."],
		["dialogue", "Amaru",
			"Then we stand. And we remember."],
	],
}

# ---------------------------------------------------------------------------
# Per-map conditions
# ---------------------------------------------------------------------------
## lives: override base_health in GameScene (-1 = use default 100)
## starting_gold: override starting_money (-1 = use player-count default)
## flags: string tags for future mechanic systems (no gameplay effect yet)

const MAP_CONDITIONS: Dictionary = {
	1: {
		1: {"lives": 1,   "starting_gold": -1,  "flags": []},
		2: {"lives": 3,   "starting_gold": -1,  "flags": []},
		3: {"lives": -1,  "starting_gold": 300, "flags": ["reduced_gold"]},
		4: {"lives": -1,  "starting_gold": -1,  "flags": ["boss"]},
	},
	2: {
		1: {"lives": -1,  "starting_gold": -1,  "flags": ["fog"]},
		2: {"lives": -1,  "starting_gold": -1,  "flags": ["blocked_tiles"]},
		3: {"lives": -1,  "starting_gold": -1,  "flags": ["armored_enemies"]},
		4: {"lives": -1,  "starting_gold": -1,  "flags": ["boss"]},
	},
	3: {
		1: {"lives": -1,  "starting_gold": -1,  "flags": ["aerial_wave"]},
		2: {"lives": 3,   "starting_gold": -1,  "flags": ["aerial_wave"]},
		3: {"lives": -1,  "starting_gold": -1,  "flags": ["aerial_wave", "wave_timer"]},
		4: {"lives": -1,  "starting_gold": -1,  "flags": ["boss", "aerial_wave"]},
	},
	4: {
		1: {"lives": -1,  "starting_gold": -1,  "flags": ["fog"]},
		2: {"lives": -1,  "starting_gold": -1,  "flags": ["path_reroute"]},
		3: {"lives": -1,  "starting_gold": -1,  "flags": ["path_reroute", "swap_entry"]},
		4: {"lives": -1,  "starting_gold": -1,  "flags": ["boss", "path_reroute"]},
	},
	5: {
		1: {"lives": -1,  "starting_gold": -1,  "flags": ["debuff_aura"]},
		2: {"lives": -1,  "starting_gold": -1,  "flags": ["half_attack_speed"]},
		3: {"lives": -1,  "starting_gold": -1,  "flags": ["lingering_zones"]},
		4: {"lives": -1,  "starting_gold": -1,  "flags": ["boss"]},
	},
	6: {
		1: {"lives": -1,  "starting_gold": -1,  "flags": ["invisible_enemies"]},
		2: {"lives": -1,  "starting_gold": -1,  "flags": ["invisible_enemies", "no_detection_zones"]},
		3: {"lives": -1,  "starting_gold": -1,  "flags": ["invisible_enemies"]},
		4: {"lives": -1,  "starting_gold": -1,  "flags": ["boss", "invisible_enemies"]},
	},
	7: {
		1: {"lives": -1,  "starting_gold": -1,  "flags": ["multi_lane"]},
		2: {"lives": 3,   "starting_gold": -1,  "flags": ["multi_lane"]},
		3: {"lives": -1,  "starting_gold": -1,  "flags": ["multi_lane"]},
		4: {"lives": -1,  "starting_gold": -1,  "flags": ["boss", "multi_lane"]},
	},
	8: {
		1: {"lives": -1,  "starting_gold": -1,  "flags": ["path_shift"]},
		2: {"lives": -1,  "starting_gold": -1,  "flags": ["tile_shift"]},
		3: {"lives": -1,  "starting_gold": -1,  "flags": ["split_on_death"]},
		4: {"lives": -1,  "starting_gold": -1,  "flags": ["boss", "tower_negation"]},
	},
	9: {
		1: {"lives": -1,  "starting_gold": -1,  "flags": ["column_formation"]},
		2: {"lives": -1,  "starting_gold": -1,  "flags": ["elite_armored"]},
		3: {"lives": -1,  "starting_gold": -1,  "flags": ["healer_enemies"]},
		4: {"lives": -1,  "starting_gold": -1,  "flags": ["boss", "elite_guard"]},
	},
	10: {
		1: {"lives": -1,  "starting_gold": -1,  "flags": ["path_change_per_wave"]},
		2: {"lives": 2,   "starting_gold": -1,  "flags": []},
		3: {"lives": -1,  "starting_gold": -1,  "flags": ["all_enemy_types"]},
		4: {"lives": -1,  "starting_gold": -1,  "flags": ["boss", "multi_phase"]},
	},
}

# ---------------------------------------------------------------------------
# Map display names (10 chapters × 4 maps)
# ---------------------------------------------------------------------------

const MAP_NAMES: Dictionary = {
	1:  {1: "First Signs",        2: "Cracked Stones",     3: "Pushing Deeper",      4: "The Weave Breaker"},
	2:  {1: "Into the Dark",      2: "Twisted Paths",      3: "Corrupted Wardens",   4: "The Kapre"},
	3:  {1: "Dusk Patrol",        2: "Lantern Lines",      3: "Rooftop Rush",        4: "The Manananggal"},
	4:  {1: "The Fog Rolls In",   2: "Shifting Ground",    3: "Wrong Way",           4: "The Tikbalang"},
	5:  {1: "Something in the Air",2: "Weakened Defenses", 3: "Sapping the Line",    4: "The Mambabarang"},
	6:  {1: "Empty Streets",      2: "Blind Spots",        3: "Shadows at Noon",     4: "The Pugot Chieftain"},
	7:  {1: "The Bells Ring",     2: "Civilian Crossings", 3: "The Outer Wall Falls",4: "The Alpha Aswang"},
	8:  {1: "Between Two Worlds", 2: "Unstable Ground",    3: "Spirit Overflow",     4: "Guardian of the Threshold"},
	9:  {1: "Into Enemy Ground",  2: "Elite Wardens",      3: "Support Lines",       4: "General Maruk"},
	10: {1: "The World Between",  2: "Fragments of the Ward",3: "All Forces Converge",4: "Haring Uldim"},
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func has_sequence(key: String) -> bool:
	return SEQUENCES.has(key)

func get_sequence(key: String) -> Array:
	return SEQUENCES.get(key, [])

## Returns per-map condition dict. Missing values default to -1 / [].
func get_map_conditions(chapter: int, map_idx: int) -> Dictionary:
	var defaults := {"lives": -1, "starting_gold": -1, "flags": []}
	var ch_data: Dictionary = MAP_CONDITIONS.get(chapter, {})
	var cond: Dictionary = ch_data.get(map_idx, {})
	if cond.is_empty():
		return defaults
	return cond

func get_map_name(chapter: int, map_idx: int) -> String:
	return MAP_NAMES.get(chapter, {}).get(map_idx, "Map %d" % map_idx)
