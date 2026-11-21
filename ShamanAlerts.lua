-- ShamanAlerts (WoW Forever, Interface 16001)
--
-- Zeigt Texturen für Schamanen-Ereignisse. Diese Alarme sind eingebaut:
--   * Waffe des Mahlstroms hat eine einstellbare Stapelzahl erreicht.
--   * Auf dem Ziel fehlt der eigene Flammenschock.
--   * Auf dem Schamanen selbst fehlt das Schild (Blitzschlag- oder Wasserschild).
--   * Auf der Waffe fehlt die Verzauberung (Windzorn, Flammenzunge usw.). Das
--     fragt das Addon direkt ab, dafür braucht es keinen AuraContainer.
--   * Sturmschlag ist bereit. Auch das fragt das Addon direkt ab.
--   * Erdschock ist bereit und Flammenschock muss nicht erneuert werden.
--   * Feuernova ist bereit.
--   * Freizaubern oder Schlaghagel ist aktiv.
--   * Kochendes Blut (Orcs) oder Berserker (Trolle) ist bereit.
-- Die Totem-Leiste steht in Totems.lua, das Optionsfenster in Options.lua.
--
-- Im Kampf darf ein Addon auf Forever keine Auren lesen. Beide Anzeigen laufen
-- deshalb über Blizzards AuraContainer, ohne dass das Addon die Auren selbst
-- liest:
--   * Stapel: Das Spiel schreibt die Stapelzahl in eine unsichtbare Leiste. Die
--     Textur hängt am Ende der Füllung, ein Ausschnitt lässt sie erst sichtbar
--     werden, wenn die Leiste voll ist.
--   * Fehlt: Ein Container wird so breit wie die Textur, sobald der Debuff da
--     ist, und schiebt damit den sichtbaren Ausschnitt von der Textur weg.

local ADDON_NAME, ns = ...
local L = ns.L
ns = type(ns) == "table" and ns or {}
local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local TAG = "|cff4db8ffShamanAlerts|r: "

local CONTAINER_ADDON = "Blizzard_AuraContainer"
local CONTAINER_TEMPLATE = "CustomAuraContainerTemplate"
local HOST_TEMPLATE = "DisableUntrustedLayoutScriptsTemplate"
local STEP_GAP = 8 -- Sicherheitsabstand, damit unter der Schwelle nichts hereinragt

-------------------------------------------------------------------------------
-- Texturen und Sounds
-------------------------------------------------------------------------------

-- Die Grafiken des Addons: gemalte Bilder mit eigenen Farben. "colored" heißt:
-- Die Farben stecken schon in der Datei, die Vorschau wird nicht eingefärbt.
-- Ein dritter Wert im Eintrag nennt die Zahl der Teile: Dann gibt es neben dem
-- ganzen Bild die Dateien <Name>_1.tga bis <Name>_<Zahl>.tga, jede so groß wie
-- das ganze Bild und nur mit ihrem Teil gefüllt. Ein Stapel-Alarm setzt das
-- Bild daraus Stapel für Stapel zusammen.
-- Ein Eintrag mit "blend" erzwingt diese Überblendung. Wer etwas anderes zeigen
-- will, trägt im Optionsfenster den Pfad einer eigenen Datei ein.
local TEXTURES = {}
local CATEGORY_ART = { name = L["Painted"], keys = {} }
local CATEGORY_WOW = { name = L["WoW style"], keys = {} }
local TEXTURE_CATEGORIES = { CATEGORY_ART, CATEGORY_WOW, { name = L["Simple"], keys = {} }, { name = L["In parts"], keys = {} } }

local function registerTextures(category, folder, prefix, entries, colored, blend)
	for _, entry in ipairs(entries) do
		local key = prefix .. entry[1]:lower()
		TEXTURES[key] = { name = entry[2], path = MEDIA .. folder .. "\\" .. entry[1] .. ".tga", colored = colored, blend = blend }
		if entry[3] then
			TEXTURES[key].parts = entry[3]
			TEXTURES[key].partPath = MEDIA .. folder .. "\\" .. entry[1] .. "_%d.tga"
		end
		table.insert(category.keys, key)
	end
end

-- Gemalte Grafiken mit eigenen Farben. Sie werden normal deckend gezeigt.
registerTextures(CATEGORY_ART, "Art", "art_", {
	{ "orb", L["Lightning orb"] },
	{ "bolt", L["Lightning bolt"] },
	{ "storm_ring", L["Lightning ring"] },
	{ "flame", L["Flame"] },
	{ "fire_ring", L["Fire ring"] },
	{ "lightning_shield", L["Lightning Shield"] },
	{ "water_shield", L["Water Shield"] },
	{ "windfury_weapon", L["Windfury Weapon"] },
	{ "flametongue_weapon", L["Flametongue Weapon"] },
	{ "chain_lightning", L["Chain Lightning"] },
	{ "lightning_arc", L["Lightning arc"] },
	{ "lightning_burst", L["Lightning star"] },
	{ "spark", L["Spark"] },
	{ "thunder_cloud", L["Thundercloud"] },
	{ "fireball", L["Fireball"] },
	{ "lava_burst", L["Lava Burst"] },
	{ "flame_crescent", L["Flame arc"] },
	{ "ember_swirl", L["Ember swirl"] },
	{ "spirit_flame", L["Spirit flame"] },
	{ "frost_shard", L["Ice crystals"] },
	{ "earth_rock", L["Chunk of earth"] },
	{ "water_drop", L["Water drop"] },
	{ "wind_swirl", L["Wind swirl"] },
	{ "spirit_wolf", L["Ghost Wolf"] },
	{ "totem_fire", L["Fire totem"] },
	{ "totem_earth", L["Earth totem"] },
	{ "totem_water", L["Water totem"] },
	{ "totem_air", L["Air totem"] },
	-- Schamane
	{ "stormstrike", L["Stormstrike"] },
	{ "earth_shock", L["Earth Shock"] },
	{ "earth_shock_crack", L["Earth Shock: Lightning crack"] },
	{ "earth_shock_burst", L["Earth Shock: Explosion"] },
	{ "earth_shock_impact", L["Earth Shock: Shockwave"] },
	{ "earth_shock_spikes", L["Earth Shock: Rock spikes"] },
	{ "earth_shock_fist", L["Earth Shock: Stone fist"] },
	{ "flame_shock_burst", L["Flame Shock: Explosion"] },
	{ "fire_shock_ball", L["Flame Shock: Fireball"] },
	{ "fire_shock_comet", L["Flame Shock: Comet"] },
	{ "fire_shock_blast", L["Flame Shock: Impact"] },
	{ "fire_shock_core", L["Flame Shock: Lava orb"] },
	{ "fire_shock_spiral", L["Flame Shock: Fire spiral"] },
	{ "fire_shock_skull", L["Flame Shock: Fire face"] },
	{ "shock_zap", L["Shock: Lightning bolt"] },
	{ "shock_bolt", L["Shock: Lightning strike"] },
	{ "shock_strike", L["Shock: Impact"] },
	{ "shock_burst", L["Shock: Discharge"] },
	{ "shock_orb", L["Shock: Electric orb"] },
	{ "shock_ring", L["Shock: Lightning ring"] },
	{ "storm_strike_axes", L["Stormstrike: Crossed axes"] },
	{ "storm_strike_slash", L["Stormstrike: Lightning slashes"] },
	{ "storm_strike_blade", L["Stormstrike: Axe blow"] },
	{ "storm_strike_hammer", L["Stormstrike: Maces"] },
	{ "storm_strike_fist", L["Stormstrike: Lightning fist"] },
	{ "storm_strike_vortex", L["Stormstrike: Storm vortex"] },
	{ "clearcast_orb", L["Clearcasting: Mana orb"] },
	{ "clearcast_star", L["Clearcasting: Star"] },
	{ "clearcast_crystal", L["Clearcasting: Crystal"] },
	{ "clearcast_drop", L["Clearcasting: Mana drop"] },
	{ "clearcast_swirl", L["Clearcasting: Mana ring"] },
	{ "clearcast_eye", L["Clearcasting: Spirit eye"] },
	{ "flurry_slashes", L["Flurry: Slashes"] },
	{ "flurry_claws", L["Flurry: Claws"] },
	{ "flurry_whirl", L["Flurry: Blade whirl"] },
	{ "flurry_axes", L["Flurry: Axes"] },
	{ "flurry_fists", L["Flurry: Fists"] },
	{ "flurry_burst", L["Flurry: Hail of blows"] },
	{ "blood_fury_fist", L["Blood Fury: Fist"] },
	{ "blood_fury_drop", L["Blood Fury: Blood drop"] },
	{ "blood_fury_roar", L["Blood Fury: War mask"] },
	{ "blood_fury_axes", L["Blood Fury: War axes"] },
	{ "blood_fury_aura", L["Blood Fury: Flame of wrath"] },
	{ "blood_fury_sigil", L["Blood Fury: War sigil"] },
	{ "berserking_troll", L["Berserking: Troll grimace"] },
	{ "berserking_mask", L["Berserking: Voodoo mask"] },
	{ "berserking_spears", L["Berserking: Spears"] },
	{ "berserking_heart", L["Berserking: Racing heart"] },
	{ "berserking_frenzy", L["Berserking: Frenzy"] },
	{ "berserking_tusks", L["Berserking: Tusks"] },
	{ "frost_shock", L["Frost Shock"] },
	{ "healing_wave", L["Healing Wave"] },
	{ "chain_heal", L["Chain Heal"] },
	{ "bloodlust", L["Bloodlust"] },
	{ "ankh", L["Ankh"] },
	{ "rockbiter_weapon", L["Rockbiter Weapon"] },
	{ "frostbrand_weapon", L["Frostbrand Weapon"] },
	{ "earth_shield", L["Earth Shield"] },
	{ "ghost_wolf", L["Ghost Wolf, running"] },
	{ "mana_tide", L["Mana Tide"] },
	-- Bögen und Ringe zum Einrahmen
	{ "water_crescent", L["Water arc"] },
	{ "wind_crescent", L["Wind arc"] },
	{ "earth_crescent", L["Earth arc"] },
	{ "frost_ring", L["Frost ring"] },
	{ "water_ring", L["Water ring"] },
	{ "wind_ring", L["Wind ring"] },
	-- allgemeine Zeichen
	{ "warning", L["Exclamation mark"] },
	{ "skull", L["Skull"] },
	{ "heart", L["Heart"] },
	{ "hourglass", L["Hourglass"] },
	{ "eye", L["Eye"] },
	{ "crossed_swords", L["Crossed swords"] },
	-- Magieschulen
	{ "arcane_orb", L["Arcane orb"] },
	{ "shadow_orb", L["Shadow orb"] },
	{ "holy_light", L["Holy Light"] },
	{ "nature_leaf", L["Nature leaf"] },
	{ "poison_drop", L["Poison drop"] },
	{ "snowflake", L["Snowflake"] },
	-- Zorn des Scharfsehers, Schnelligkeit der Natur, Totem der Manaquelle
	{ "farseer_mask", L["Rage of the Farseer"] .. ": " .. L["Mask"] },
	{ "farseer_wolf", L["Rage of the Farseer"] .. ": " .. L["Wolf"] },
	{ "farseer_storm", L["Rage of the Farseer"] .. ": " .. L["Storm"] },
	{ "swiftness_feather", L["Nature's Swiftness"] .. ": " .. L["Feather"] },
	{ "swiftness_hourglass", L["Nature's Swiftness"] .. ": " .. L["Hourglass"] },
	{ "swiftness_bolt", L["Nature's Swiftness"] .. ": " .. L["Lightning bolt"] },
	{ "manatide_totem", L["Mana Tide Totem"] .. ": " .. L["Totem"] },
	{ "manatide_wave", L["Mana Tide Totem"] .. ": " .. L["Wave"] },
	{ "manatide_bowl", L["Mana Tide Totem"] .. ": " .. L["Bowl"] },
	-- Springflut und Wasserschild
	{ "riptide_wave", L["Riptide"] .. ": " .. L["Wave"] },
	{ "riptide_spiral", L["Riptide"] .. ": " .. L["Spiral"] },
	{ "riptide_ring", L["Riptide"] .. ": " .. L["Ring"] },
	{ "watershield_bubble", L["Water Shield"] .. ": " .. L["Bubble"] },
	{ "watershield_orbs", L["Water Shield"] .. ": " .. L["Orbs"] },
	{ "watershield_crest", L["Water Shield"] .. ": " .. L["Crest"] },
}, true, "BLEND")

-- Dieselben Motive noch einmal im Stil der Fähigkeitssymbole: mindestens drei
-- pro Alarm, in der Reihenfolge der eingebauten Alarme.
registerTextures(CATEGORY_WOW, "Wow", "wow_", {
	{ "maelstrom_vortex", L["Maelstrom: Storm vortex"] },
	{ "maelstrom_weapon", L["Maelstrom: Mace"] },
	{ "maelstrom_bolt", L["Maelstrom: Lightning bolt"] },
	{ "flame_shock_blast", L["Flame Shock: Explosion"] },
	{ "flame_shock_bolt", L["Flame Shock: Fireball"] },
	{ "flame_shock_brand", L["Flame Shock: Flame brand"] },
	{ "flame_shock_meteor", L["Flame Shock: Ember chunk"] },
	{ "flame_shock_fist", L["Flame Shock: Lava fist"] },
	{ "flame_shock_arrow", L["Flame Shock: Fire spearhead"] },
	{ "flame_shock_skull", L["Flame Shock: Flaming skull"] },
	{ "flame_shock_phoenix", L["Flame Shock: Firebird"] },
	{ "flame_shock_rune", L["Flame Shock: Shock rune"] },
	{ "flame_shock_runearrow", L["Flame Shock: Rune arrow"] },
	{ "flame_shock_runeseal", L["Flame Shock: Rune seal"] },
	{ "flame_shock_runestone", L["Flame Shock: Rune stone"] },
	{ "flame_shock_runebolt", L["Flame Shock: Rune bolt"] },
	{ "shield_lightning", L["Shield: Lightning orbs"] },
	{ "shield_water", L["Shield: Water orbs"] },
	{ "shield_ward", L["Shield: Rune ward"] },
	{ "weapon_windfury", L["Weapon: Windfury"] },
	{ "weapon_flametongue", L["Weapon: Flametongue"] },
	{ "weapon_rune", L["Weapon: Rune stone"] },
	{ "stormstrike_axe", L["Stormstrike: Axe blow"] },
	{ "stormstrike_maces", L["Stormstrike: Maces"] },
	{ "stormstrike_cloud", L["Stormstrike: Thunderstorm"] },
	{ "earth_shock_strike", L["Earth Shock: Impact"] },
	{ "earth_shock_burst", L["Earth Shock: Shockwave"] },
	{ "earth_shock_fist", L["Earth Shock: Stone fist"] },
	{ "earth_shock_runearrow", L["Earth Shock: Rune arrow"] },
	{ "earth_shock_runebolt", L["Earth Shock: Rune bolt"] },
	{ "frost_shock_runearrow", L["Frost Shock: Rune arrow"] },
	{ "frost_shock_runebolt", L["Frost Shock: Rune bolt"] },
	{ "shock_arrow", L["Shock (all three): Elemental arrow"] },
	{ "shock_burst", L["Shock (all three): Impact"] },
	{ "shock_rune", L["Shock (all three): Lightning bolt"] },
	{ "firenova_ring", L["Fire Nova: Fire ring"] },
	{ "firenova_totem", L["Fire Nova: Totem"] },
	{ "firenova_burst", L["Fire Nova: Fire star"] },
	{ "interrupt_fist", L["Interrupt: Stone fist"] },
	{ "interrupt_shatter", L["Interrupt: Shattered rune"] },
	{ "interrupt_hand", L["Interrupt: Stop"] },
	{ "clearcast_orb", L["Clearcasting: Mana orb"] },
	{ "clearcast_mind", L["Clearcasting: Eye"] },
	{ "clearcast_crystal", L["Clearcasting: Crystal"] },
	{ "flurry_blades", L["Flurry: Slashes"] },
	{ "flurry_claw", L["Flurry: Claw"] },
	{ "flurry_axes", L["Flurry: Axe whirl"] },
	{ "bloodfury_fist", L["Blood Fury: Fist"] },
	{ "bloodfury_face", L["Blood Fury: Orc"] },
	{ "bloodfury_blade", L["Blood Fury: War axe"] },
	{ "berserking_face", L["Berserking: Troll"] },
	{ "berserking_mask", L["Berserking: Voodoo mask"] },
	{ "berserking_tusks", L["Berserking: Tusks"] },
	{ "farseer_wolf", L["Rage of the Farseer"] .. ": " .. L["Wolf"] },
	{ "farseer_eye", L["Rage of the Farseer"] .. ": " .. L["Eye"] },
	{ "farseer_axes", L["Rage of the Farseer"] .. ": " .. L["Axes"] },
	{ "swiftness_leaf", L["Nature's Swiftness"] .. ": " .. L["Leaf"] },
	{ "swiftness_raven", L["Nature's Swiftness"] .. ": " .. L["Raven"] },
	{ "swiftness_vortex", L["Nature's Swiftness"] .. ": " .. L["Vortex"] },
	{ "manatide_totem", L["Mana Tide Totem"] .. ": " .. L["Totem"] },
	{ "manatide_drop", L["Mana Tide Totem"] .. ": " .. L["Water drop"] },
	{ "manatide_fountain", L["Mana Tide Totem"] .. ": " .. L["Fountain"] },
	{ "riptide_wave", L["Riptide"] .. ": " .. L["Wave"] },
	{ "riptide_vortex", L["Riptide"] .. ": " .. L["Vortex"] },
	{ "riptide_heart", L["Riptide"] .. ": " .. L["Heart"] },
	{ "watershield_bubble", L["Water Shield"] .. ": " .. L["Bubble"] },
	{ "watershield_orbs", L["Water Shield"] .. ": " .. L["Orbs"] },
	{ "watershield_crest", L["Water Shield"] .. ": " .. L["Crest"] },
}, true, "BLEND")

-- Schlichte Motive im selben gemalten Stil: je Alarm ein einzelner, klarer Gegenstand.
registerTextures(TEXTURE_CATEGORIES[3], "Simple", "simple_", {
	{ "maelstrom", L["Maelstrom Weapon"] },
	{ "flame_shock", L["Flame Shock"] },
	{ "frost_shock", L["Frost Shock"] },
	{ "earth_shock", L["Earth Shock"] },
	{ "shock", L["Shock (all three)"] },
	{ "interrupt", L["Interrupt"] },
	{ "stormstrike", L["Stormstrike"] },
	{ "shield", L["Lightning Shield"] },
	{ "weapon", L["Windfury Weapon"] },
	{ "firenova", L["Fire Nova"] },
	{ "clearcast", L["Clearcasting"] },
	{ "flurry", L["Flurry"] },
	{ "bloodfury", L["Blood Fury"] },
	{ "berserking", L["Berserking"] },
	{ "farseer", L["Rage of the Farseer"] },
	{ "farseer_eye", L["Rage of the Farseer"] .. ": " .. L["Eye"] },
	{ "swiftness", L["Nature's Swiftness"] },
	{ "swiftness_feather", L["Nature's Swiftness"] .. ": " .. L["Feather"] },
	{ "manatide", L["Mana Tide Totem"] },
	{ "manatide_drop", L["Mana Tide Totem"] .. ": " .. L["Water drop"] },
	{ "riptide", L["Riptide"] },
	{ "riptide_drop", L["Riptide"] .. ": " .. L["Water drop"] },
	{ "watershield", L["Water Shield"] },
	{ "watershield_crest", L["Water Shield"] .. ": " .. L["Crest"] },
}, true, "BLEND")

-- Bilder in fünf Teilen für die Waffe des Mahlstroms: Ein Stapel-Alarm setzt
-- sie Stapel für Stapel zusammen, bei fünf Stapeln steht das ganze Bild.
registerTextures(TEXTURE_CATEGORIES[4], "Parts", "parts_", {
	{ "orb", L["Storm orb"], 5 },
	{ "crescent", L["Crescent"], 5 },
	{ "ring", L["Ring"], 5 },
	{ "bolt", L["Lightning bolt"], 5 },
	{ "claws", L["Claws"], 5 },
	{ "vortex", L["Vortex"], 5 },
	{ "crown", L["Crown"], 5 },
	{ "star", L["Star"], 5 },
	{ "column", L["Column"], 5 },
	{ "runes", L["Runes"], 5 },
	{ "chain", L["Chain"], 5 },
	{ "wings", L["Wings"], 5 },
	-- Schlichtere Formen, von kompakt bis breit gefächert
	{ "dots", L["Dots"], 5 },
	{ "sparks", L["Sparks"], 5 },
	{ "shortbolt", L["Short bolt"], 5 },
	{ "gem", L["Gem"], 5 },
	{ "orbit", L["Orbit"], 5 },
	{ "fan", L["Fan"], 5 },
	{ "arch", L["Arch"], 5 },
	{ "chevrons", L["Chevrons"], 5 },
	{ "spiral", L["Spiral"], 5 },
	{ "compass", L["Compass star"], 5 },
	{ "arrow", L["Arrow"], 5 },
	{ "row", L["Row of bolts"], 5 },
	{ "burst", L["Starburst"], 5 },
	{ "frame", L["Frame"], 5 },
	{ "vee", L["V shape"], 5 },
	{ "roots", L["Roots"], 5 },
	-- die Form, die andere Addons für die fünf Stapel zeigen: ein Mittelstück und je zwei Schwingen
	{ "stormwing", L["Storm wing"], 5 },
	{ "widewing", L["Wide wing"], 5 },
	{ "thunderbird", L["Thunderbird"], 5 },
	{ "wingarc", L["Raised wings"], 5 },
	{ "stormcrest", L["Storm crest"], 5 },
	{ "sockets", L["Storm sockets"], 5 },
}, true, "BLEND")

local DEFAULT_SOUND = MEDIA .. "alert.ogg"
local SOUNDS = {
	{ name = L["Ding"], file = DEFAULT_SOUND },
	{ name = L["Chime"], file = MEDIA .. "chime.ogg" },
	{ name = L["Bell"], file = MEDIA .. "bell.ogg" },
	{ name = L["Gong"], file = MEDIA .. "gong.ogg" },
	{ name = L["Pop"], file = MEDIA .. "pop.ogg" },
	{ name = L["Alarm"], file = MEDIA .. "alarm.ogg" },
	{ name = L["Lightning strike"], file = MEDIA .. "zap.ogg" },
	{ name = L["Power up"], file = MEDIA .. "powerup.ogg" },
	-- thematische Effekte
	{ name = L["Thunderclap"], file = MEDIA .. "thunder.ogg" },
	{ name = L["Lightning impact"], file = MEDIA .. "zap2.ogg" },
	{ name = L["Power surge"], file = MEDIA .. "power_surge.ogg" },
	{ name = L["Fire blast"], file = MEDIA .. "fire_whoosh.ogg" },
	{ name = L["Ignite"], file = MEDIA .. "flame_ignite.ogg" },
	{ name = L["Gust of wind"], file = MEDIA .. "wind_gust.ogg" },
	{ name = L["Water splash"], file = MEDIA .. "water_splash.ogg" },
	{ name = L["Totem drum"], file = MEDIA .. "totem_drum.ogg" },
	{ name = L["Shield chime"], file = MEDIA .. "shield_chime.ogg" },
	{ name = L["War horn"], file = MEDIA .. "war_horn.ogg" },
	{ name = L["Earth thud"], file = MEDIA .. "earth_thud.ogg" },
	{ name = L["Ice crack"], file = MEDIA .. "frost_crack.ogg" },
}

-------------------------------------------------------------------------------
-- Alarme
-------------------------------------------------------------------------------

-- kind "stacks": Textur erscheint ab einer Stapelzahl eines eigenen Buffs.
-- kind "missing": Textur erscheint, solange die Aura auf der Einheit fehlt.
-- kind "active": Textur erscheint, solange die Aura auf der Einheit aktiv ist.
-- kind "weapon": Textur erscheint, solange eine Waffe keine zeitlich begrenzte Verzauberung hat.
-- kind "ready": Textur erscheint, solange ein Zauber nicht abklingt, also bereit ist.
-- Die eingebauten Alarme gelten nur für Schamanen ("class"). Eigene Alarme legt
-- der Spieler selbst an, sie gelten für jede Klasse.
local ALERT_DEFS = {
	{
		key = "maelstrom",
		class = "SHAMAN",
		title = L["Maelstrom Weapon"],
		kind = "stacks",
		unit = "player",
		filter = "HELPFUL",
		learnNames = { "Maelstrom Weapon", "Waffe des Mahlstroms" },
		talentSpell = 408498, -- das Talent heißt wie der Buff, daraus kommt der lokalisierte Name
		defaultIcon = "Interface\\Icons\\Spell_Shaman_MaelstromWeapon",
		defaults = {
			enabled = true,
			threshold = 5,
			size = 120, x = 0, y = 0, alpha = 1,
			layout = "sides", count = 1, distance = 100, spread = 5, rotate = false, angle = 0, flip = true, perStack = false,
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_maelstrom_bolt",
			textureRevision = 1,
			color = { 0.45, 0.8, 1 },
			additive = true,
			pulse = true,
			sound = "off", -- "off" | "threshold" | "stack"
			soundFile = MEDIA .. "zap2.ogg",
			icon = false,
			combatOnly = false,
			needUsable = false, -- mit vollen Stapeln kostet der Blitz kein Mana
			needAggro = false,
			minHealth = 0,
			auraName = L["Maelstrom Weapon"],
			-- Buff-IDs: Forever/SoD, Wrath, Retail. Weitere lernt das Addon selbst.
			spellIDs = { [408505] = true, [53817] = true, [344179] = true },
		},
	},
	{
		key = "flameshock",
		class = "SHAMAN",
		title = L["Flame Shock missing"],
		kind = "missing",
		unit = "target",
		filter = "HARMFUL|PLAYER", -- nur der eigene Debuff zählt
		learnNames = { "Flame Shock", "Flammenschock" },
		useSpellbook = true, -- bei Flammenschock ist die Zauber-ID auch die Debuff-ID
		requireKnown = true, -- erst warnen, wenn der Charakter den Zauber gelernt hat
		-- Ruf der Flamme verlängert den Debuff je Rang um 3 Sekunden.
		talentDuration = { base = 12, spell = 16038, node = 104770, perRank = 3 },
		defaultIcon = "Interface\\Icons\\Spell_Fire_FlameShock",
		defaults = {
			enabled = true,
			threshold = 1,
			-- Lage und Größe teilt er mit den anderen Schocks ("placeLike").
			size = 120, x = 0, y = 10, alpha = 1,
			layout = "sides", count = 1, distance = 115, spread = 26, rotate = false, angle = 0, flip = false, perStack = false,
			placeLike = "earthshock",
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_flame_shock_runearrow",
			textureRevision = 3,
			color = { 1, 1, 1 },
			additive = true,
			pulse = true,
			sound = "off", -- "off" | "removed"
			soundFile = MEDIA .. "fire_whoosh.ogg",
			icon = false,
			combatOnly = true,
			needUsable = true, -- nur warnen, wenn das Mana für Flammenschock reicht
			needAggro = false,
			noPlayer = true, -- gegen Spieler lohnt sich der Flammenschock nicht
			needReady = true, -- nicht warnen, solange die Schocks noch abklingen
			lead = 1, leadRevision = 1, -- so viele Sekunden vor "bereit" schon anzeigen
			behind = "interrupt,frostshock", -- Unterbrechen und (gegen Spieler) Frostschock gehen vor
			refresh = 2, -- schon warnen, wenn der Debuff nur noch so viele Sekunden läuft
			auraDuration = 12, -- so lange läuft der Debuff; daran misst die eigene Uhr
			talentDuration = 0, -- die Laufzeit, die zuletzt aus den Talenten gelesen wurde (0 = noch nie)
			minHealth = 35, -- nur warnen, wenn das Ziel noch so viel Prozent Leben hat
			bossAlways = true, -- bei einem Boss gilt diese Schwelle nicht: Fehlt der Flammenschock, wird er immer vorgeschlagen
			auraName = L["Flame Shock"],
			-- Alle Ränge auf Forever, dazu die Retail-ID
			spellIDs = { [8050] = true, [8052] = true, [8053] = true, [10447] = true, [10448] = true, [29228] = true, [188389] = true },
		},
	},
	{
		key = "shield",
		class = "SHAMAN",
		title = L["Lightning Shield missing"],
		kind = "missing",
		unit = "player",
		filter = "HELPFUL",
		-- Nur das Blitzschlagschild. Für das Wasserschild gibt es den eigenen Alarm "watershield".
		learnNames = { "Lightning Shield", "Blitzschlagschild" },
		useSpellbook = true, -- die Zauber-ID ist auch die Buff-ID
		requireKnown = true,
		defaultIcon = "Interface\\Icons\\Spell_Nature_LightningShield",
		defaults = {
			enabled = true,
			threshold = 1,
			size = 104, x = 0, y = 0, alpha = 1,
			layout = "top", count = 1, distance = 285, spread = 20, rotate = false, angle = 0, flip = false, perStack = false,
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_shield_lightning",
			textureRevision = 1,
			color = { 0.45, 0.8, 1 },
			additive = true,
			pulse = true,
			sound = "off", -- "off" | "removed"
			soundFile = MEDIA .. "shield_chime.ogg",
			icon = false,
			combatOnly = true,
			needUsable = true,
			needAggro = true, -- im Kampf zählt das Schild nur, wenn Gegner auf den Schamanen einschlagen
			needReady = false,
			lead = 1, leadRevision = 1,
			refresh = 0, auraDuration = 600, -- nicht schon vor dem Ablauf warnen
			minHealth = 0,
			auraName = L["Lightning Shield"],
			shieldRevision = 1, -- seit 2.47 zählt hier nur noch das Blitzschlagschild
			specs = "elemental,enhancement", -- Heiler tragen das Wasserschild, siehe den Alarm "watershield"
			-- Blitzschlagschild (alle Ränge), dazu die Retail-ID
			spellIDs = {
				[324] = true, [325] = true, [905] = true, [945] = true, [8134] = true, [10431] = true, [10432] = true,
				[192106] = true,
			},
		},
	},
	{
		key = "weapon",
		class = "SHAMAN",
		title = L["Weapon enchant missing"],
		kind = "weapon",
		unit = "player",
		learnNames = {},
		defaultIcon = "Interface\\Icons\\Spell_Nature_Cyclone", -- Symbol von Waffe des Windzorns
		defaults = {
			enabled = true,
			threshold = 1,
			size = 140, x = 0, y = 0, alpha = 1,
			layout = "top", count = 1, distance = 220, spread = 20, rotate = false, angle = 0, flip = false, perStack = false,
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_weapon_windfury",
			textureRevision = 1,
			color = { 1, 0.82, 0.3 },
			additive = true,
			pulse = true,
			sound = "off", -- "off" | "removed"
			soundFile = MEDIA .. "war_horn.ogg",
			icon = false,
			combatOnly = false,
			needUsable = false,
			needAggro = false,
			minHealth = 0,
			offhand = true, -- auch eine Waffe in der Nebenhand prüfen
			mainImbue = "", offImbue = "", -- welche Verzauberung die Hand tragen soll ("" = irgendeine)
			auraName = "",
			spellIDs = {},
		},
	},
	{
		key = "stormstrike",
		class = "SHAMAN",
		title = L["Stormstrike ready"],
		kind = "ready",
		unit = "player",
		learnNames = { "Stormstrike", "Sturmschlag" },
		useSpellbook = true,
		requireKnown = true, -- Sturmschlag ist ein Talent
		defaultIcon = "Interface\\Icons\\Ability_Shaman_Stormstrike",
		defaults = {
			enabled = true,
			threshold = 1,
			size = 120, x = 0, y = 0, alpha = 1,
			layout = "bottom", count = 1, distance = 135, spread = 26, rotate = false, angle = 0, flip = false, perStack = false,
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_stormstrike_axe",
			textureRevision = 2,
			color = { 1, 1, 1 },
			additive = true,
			pulse = false,
			sound = "off", -- "off" | "added"
			soundFile = MEDIA .. "zap2.ogg",
			icon = false,
			combatOnly = true,
			needUsable = true,
			needAggro = false,
			needTarget = true, -- nur mit einem angreifbaren Ziel
			needRange = true, -- nur wenn das Ziel in Reichweite ist
			needEnemies = false, minEnemies = 3, enemyRange = 10, -- nur bei so vielen Gegnern in diesem Umkreis (Namensplaketten)
			needFireTotem = false, -- nur solange ein Feuertotem steht
			needCasting = false, -- nur solange das Ziel etwas Unterbrechbares zaubert
			yieldTo = "",
			lead = 1, leadRevision = 1, -- so viele Sekunden vor "bereit" schon anzeigen
			minHealth = 0,
			auraName = L["Stormstrike"],
			spellIDs = { [17364] = true },
		},
	},
	{
		key = "earthshock",
		class = "SHAMAN",
		title = L["Earth Shock ready"],
		kind = "ready",
		unit = "player",
		learnNames = { "Earth Shock", "Erdschock" },
		useSpellbook = true,
		requireKnown = true,
		defaultIcon = "Interface\\Icons\\Spell_Nature_EarthShock",
		defaults = {
			enabled = true,
			threshold = 1,
			-- Gibt die Stelle für die Schocks vor: Flammenschock und Frostschock
			-- teilen Lage und Größe mit ihm, es wechselt nur das Bild.
			size = 120, x = 0, y = 10, alpha = 1,
			layout = "sides", count = 1, distance = 115, spread = 26, rotate = false, angle = 0, flip = false, perStack = false,
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_earth_shock_runearrow",
			textureRevision = 4,
			color = { 1, 1, 1 },
			additive = true,
			pulse = false,
			sound = "off", -- "off" | "added"
			soundFile = MEDIA .. "earth_thud.ogg",
			icon = false,
			combatOnly = true,
			needUsable = true,
			needAggro = false,
			needTarget = true,
			needRange = true,
			needEnemies = false, minEnemies = 3, enemyRange = 10, -- nur bei so vielen Gegnern in diesem Umkreis (Namensplaketten)
			needFireTotem = false, -- nur solange ein Feuertotem steht
			needCasting = false, -- nur solange das Ziel etwas Unterbrechbares zaubert
			castFirst = true, -- zaubert das Ziel etwas Unterbrechbares, geht der Erdschock allen Schocks vor
			yieldTo = "flameshock", -- erst zeigen, wenn Flammenschock nicht erneuert werden muss
			behind = "interrupt,frostshock", -- Unterbrechen und (gegen Spieler) Frostschock gehen vor
			lead = 1, leadRevision = 1,
			minHealth = 0,
			auraName = L["Earth Shock"],
			spellIDs = { [8042] = true, [8044] = true, [8045] = true, [8046] = true, [10412] = true, [10413] = true, [10414] = true },
		},
	},
	{
		key = "interrupt",
		class = "SHAMAN",
		title = L["Interrupt"],
		kind = "ready",
		unit = "player",
		learnNames = { "Earth Shock", "Erdschock" },
		useSpellbook = true,
		requireKnown = true,
		defaultIcon = "Interface\\Icons\\Spell_Nature_EarthShock",
		defaults = {
			enabled = false,
			threshold = 1,
			-- Dicht über dem Charakter und für sich: Das Ziel zaubert und der Erdschock
			-- ist bereit. Lage und Größe teilt er nicht mit den Schocks.
			size = 132, x = 0, y = 0, alpha = 1,
			layout = "top", count = 1, distance = 150, spread = 26, rotate = false, angle = 0, flip = true, perStack = false,
			placeRevision = 1,
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_interrupt_fist",
			textureRevision = 1,
			color = { 1, 1, 1 },
			additive = true,
			pulse = true,
			sound = "off", -- "off" | "added"
			soundFile = MEDIA .. "alarm.ogg",
			icon = false,
			combatOnly = false,
			needUsable = true,
			needAggro = false,
			needTarget = true,
			needRange = true,
			needEnemies = false, minEnemies = 3, enemyRange = 10, -- nur bei so vielen Gegnern in diesem Umkreis (Namensplaketten)
			needFireTotem = false, -- nur solange ein Feuertotem steht
			needCasting = true, -- nur solange das Ziel etwas Unterbrechbares zaubert
			yieldTo = "",
			lead = 1, leadRevision = 1,
			minHealth = 0,
			auraName = L["Earth Shock"],
			spellIDs = { [8042] = true, [8044] = true, [8045] = true, [8046] = true, [10412] = true, [10413] = true, [10414] = true },
		},
	},
	{
		key = "firenova",
		class = "SHAMAN",
		title = L["Fire Nova ready"],
		kind = "ready",
		unit = "player",
		learnNames = { "Fire Nova", "Feuernova" },
		useSpellbook = true,
		requireKnown = true, -- gibt es erst ab einer bestimmten Stufe
		strictUsable = true, -- auch ohne Feuertotem nicht wirkbar, nicht nur ohne Mana
		defaultIcon = "Interface\\Icons\\Spell_Fire_SealOfFire",
		defaults = {
			enabled = true,
			threshold = 1,
			-- Groß über dem Charakter, über dem Schild
			size = 120, x = 0, y = 0, alpha = 1,
			layout = "top", count = 1, distance = 285, spread = 26, rotate = false, angle = 0, flip = false, perStack = false,
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_firenova_totem",
			textureRevision = 2,
			color = { 1, 1, 1 },
			additive = true,
			pulse = false,
			sound = "off", -- "off" | "added"
			soundFile = MEDIA .. "flame_ignite.ogg",
			icon = false,
			combatOnly = true,
			needUsable = true, -- braucht Mana und je nach Spielversion ein Feuertotem
			needAggro = false,
			needTarget = true, -- nur mit einem angreifbaren Ziel
			needRange = true,
			needEnemies = true, minEnemies = 4, enemyRange = 10, -- nur bei so vielen Gegnern in diesem Umkreis (Namensplaketten)
			needFireTotem = false, -- nur solange ein Feuertotem steht
			needCasting = false, -- nur solange das Ziel etwas Unterbrechbares zaubert
			yieldTo = "",
			lead = 1, leadRevision = 1, -- so viele Sekunden vor "bereit" schon anzeigen
			minHealth = 0,
			auraName = L["Fire Nova"],
			spellIDs = { [1535] = true, [8498] = true, [8499] = true, [11314] = true, [11315] = true },
		},
	},
	{
		key = "clearcast",
		class = "SHAMAN",
		title = L["Clearcasting active"],
		kind = "active",
		unit = "player",
		filter = "HELPFUL",
		learnNames = { "Clearcasting", "Freizaubern" },
		defaultIcon = "Interface\\Icons\\Spell_Shadow_ManaBurn",
		defaults = {
			enabled = true,
			threshold = 1,
			-- Proc aus dem Talent Elementarfokus: unter dem Sturmschlag-Alarm
			size = 120, x = 0, y = 0, alpha = 1,
			layout = "bottom", count = 1, distance = 210, spread = 26, rotate = false, angle = 0, flip = false, perStack = false,
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_clearcast_crystal",
			textureRevision = 2,
			color = { 1, 1, 1 },
			additive = true,
			pulse = false,
			sound = "off", -- "off" | "added" | "removed"
			soundFile = MEDIA .. "chime.ogg",
			icon = false,
			combatOnly = false,
			needUsable = false,
			needAggro = false,
			minHealth = 0,
			timer = false, -- Restzeit unter der Grafik
			auraName = L["Clearcasting"],
			spellIDs = { [16246] = true },
		},
	},
	{
		key = "flurry",
		class = "SHAMAN",
		title = L["Flurry active"],
		kind = "active",
		unit = "player",
		filter = "HELPFUL",
		learnNames = { "Flurry", "Schlaghagel" },
		talentSpell = 16256, -- das Talent heißt wie der Buff, daraus kommt der lokalisierte Name
		defaultIcon = "Interface\\Icons\\Ability_GhoulFrenzy",
		defaults = {
			enabled = false,
			threshold = 1,
			-- Proc nach einem kritischen Nahkampftreffer. Von Haus aus abgeschaltet, er
			-- teilt sich den Platz mit dem Freizaubern-Alarm.
			size = 100, x = 0, y = 0, alpha = 1,
			layout = "bottom", count = 1, distance = 210, spread = 27, rotate = false, angle = 0, flip = false, perStack = false,
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_flurry_blades",
			textureRevision = 1,
			color = { 1, 1, 1 },
			additive = true,
			pulse = false,
			sound = "off", -- "off" | "added" | "removed"
			soundFile = MEDIA .. "wind_gust.ogg",
			icon = false,
			combatOnly = true,
			needUsable = false,
			needAggro = false,
			minHealth = 0,
			timer = false, -- Restzeit unter der Grafik
			auraName = L["Flurry"],
			spellIDs = { [16257] = true, [16277] = true, [16278] = true, [16279] = true, [16280] = true },
		},
	},
	{
		key = "bloodfury",
		class = "SHAMAN",
		title = L["Blood Fury ready"],
		kind = "ready",
		unit = "player",
		learnNames = { "Blood Fury", "Kochendes Blut" },
		useSpellbook = true,
		requireKnown = true, -- Volksfähigkeit der Orcs: ohne sie bleibt der Alarm still
		defaultIcon = "Interface\\Icons\\Racial_Orc_BerserkerStrength",
		defaults = {
			enabled = true,
			threshold = 1,
			-- Lange Abklingzeit: unter dem Sturmschlag-Alarm
			size = 120, x = 0, y = 0, alpha = 1,
			layout = "bottom", count = 1, distance = 230, spread = 26, rotate = false, angle = 0, flip = false, perStack = false,
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_bloodfury_face",
			textureRevision = 1,
			color = { 1, 1, 1 },
			additive = true,
			pulse = true,
			sound = "off", -- "off" | "added"
			soundFile = MEDIA .. "war_horn.ogg",
			icon = false,
			combatOnly = true,
			needUsable = false, -- kostet nichts
			needAggro = false,
			needTarget = true, -- nur mit einem angreifbaren Ziel
			needRange = false, -- wirkt auf den Schamanen selbst, eine Reichweite gibt es nicht
			needEnemies = false, minEnemies = 3, enemyRange = 10, -- nur bei so vielen Gegnern in diesem Umkreis (Namensplaketten)
			needFireTotem = false, -- nur solange ein Feuertotem steht
			needCasting = false, -- nur solange das Ziel etwas Unterbrechbares zaubert
			yieldTo = "",
			lead = 1, leadRevision = 1, -- so viele Sekunden vor "bereit" schon anzeigen
			minHealth = 0,
			auraName = L["Blood Fury"],
			-- Classic, dazu die späteren Fassungen für Nahkämpfer und Zauberer
			spellIDs = { [20572] = true, [33697] = true, [33702] = true },
		},
	},
	{
		key = "berserking",
		class = "SHAMAN",
		title = L["Berserking ready"],
		kind = "ready",
		unit = "player",
		learnNames = { "Berserking", "Berserker" },
		useSpellbook = true,
		requireKnown = true, -- Volksfähigkeit der Trolle: ohne sie bleibt der Alarm still
		defaultIcon = "Interface\\Icons\\Racial_Troll_Berserk",
		defaults = {
			enabled = false,
			threshold = 1,
			-- Derselbe Platz wie Kochendes Blut: Ein Charakter hat nur eine der beiden Fähigkeiten.
			size = 120, x = 0, y = 0, alpha = 1,
			layout = "bottom", count = 1, distance = 225, spread = 26, rotate = false, angle = 0, flip = false, perStack = false,
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_berserking_face",
			textureRevision = 1,
			color = { 1, 1, 1 },
			additive = true,
			pulse = true,
			sound = "off", -- "off" | "added"
			soundFile = MEDIA .. "war_horn.ogg",
			icon = false,
			combatOnly = true,
			needUsable = true, -- kostet in Classic etwas Mana
			needAggro = false,
			needTarget = true, -- nur mit einem angreifbaren Ziel
			needRange = false, -- wirkt auf den Schamanen selbst, eine Reichweite gibt es nicht
			needEnemies = false, minEnemies = 3, enemyRange = 10, -- nur bei so vielen Gegnern in diesem Umkreis (Namensplaketten)
			needFireTotem = false, -- nur solange ein Feuertotem steht
			needCasting = false, -- nur solange das Ziel etwas Unterbrechbares zaubert
			yieldTo = "",
			lead = 1, leadRevision = 1, -- so viele Sekunden vor "bereit" schon anzeigen
			minHealth = 0,
			auraName = L["Berserking"],
			-- Classic: je eine Fassung für Mana, Wut und Energie
			spellIDs = { [20554] = true, [26296] = true, [26297] = true },
		},
	},
	{
		key = "frostshock",
		class = "SHAMAN",
		title = L["Frost Shock missing"],
		kind = "missing",
		unit = "target",
		filter = "HARMFUL|PLAYER", -- nur die eigene Verlangsamung zählt
		learnNames = { "Frost Shock", "Frostschock" },
		useSpellbook = true, -- bei Frostschock ist die Zauber-ID auch die Debuff-ID
		requireKnown = true,
		defaultIcon = "Interface\\Icons\\Spell_Frost_FrostShock",
		defaults = {
			enabled = true,
			threshold = 1,
			size = 120, x = 0, y = 10, alpha = 1,
			layout = "sides", count = 1, distance = 115, spread = 26, rotate = false, angle = 0, flip = false, perStack = false,
			placeLike = "earthshock",
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_frost_shock_runearrow",
			textureRevision = 1,
			color = { 1, 1, 1 },
			additive = true,
			pulse = true,
			sound = "off", -- "off" | "removed"
			soundFile = MEDIA .. "alarm.ogg",
			icon = false,
			combatOnly = true,
			needUsable = true, -- nur warnen, wenn das Mana für Frostschock reicht
			needAggro = false,
			needPlayer = true, -- nur gegen Spieler: Die Verlangsamung lohnt sich im PvP
			behind = "interrupt", -- Unterbrechen geht vor
			needReady = true, -- nicht warnen, solange die Schocks noch abklingen
			lead = 1, leadRevision = 1,
			refresh = 0, auraDuration = 8, -- nicht schon vor dem Ablauf warnen
			minHealth = 0,
			auraName = L["Frost Shock"],
			-- Alle Ränge auf Forever, dazu die Retail-ID
			spellIDs = { [8056] = true, [8058] = true, [10472] = true, [10473] = true, [25464] = true, [196840] = true },
		},
	},
	{
		key = "farseer",
		class = "SHAMAN",
		title = L["Rage of the Farseer ready"],
		kind = "ready",
		unit = "player",
		learnNames = { "Rage of the Farseer", "Zorn des Scharfsehers" },
		useSpellbook = true,
		requireKnown = true, -- ein Talent: ohne es bleibt der Alarm still
		defaultIcon = "Interface\\Icons\\Spell_Nature_BloodLust",
		defaults = {
			enabled = true,
			threshold = 1,
			-- Talent auf Forever: 30 % Angriffstempo für 25 Sekunden. Links und rechts außen neben den Schocks.
			size = 110, x = 0, y = 0, alpha = 1,
			layout = "sides", count = 1, distance = 190, spread = 26, rotate = false, angle = 0, flip = false, perStack = false,
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_farseer_wolf",
			textureRevision = 1,
			color = { 1, 1, 1 },
			additive = true,
			pulse = true,
			sound = "off", -- "off" | "added"
			soundFile = MEDIA .. "war_horn.ogg",
			icon = false,
			combatOnly = true,
			needUsable = true,
			needAggro = false,
			needTarget = true, -- nur mit einem angreifbaren Ziel
			needRange = false, -- wirkt auf den Schamanen selbst
			needEnemies = false, minEnemies = 3, enemyRange = 10, -- nur bei so vielen Gegnern in diesem Umkreis (Namensplaketten)
			needFireTotem = false, -- nur solange ein Feuertotem steht
			needCasting = false, -- nur solange das Ziel etwas Unterbrechbares zaubert
			yieldTo = "",
			lead = 1, leadRevision = 1, -- so viele Sekunden vor "bereit" schon anzeigen
			minHealth = 0,
			auraName = L["Rage of the Farseer"],
			spellIDs = { [425336] = true },
		},
	},
	{
		key = "swiftness",
		class = "SHAMAN",
		title = L["Nature's Swiftness ready"],
		kind = "ready",
		unit = "player",
		learnNames = { "Nature's Swiftness", "Schnelligkeit der Natur" },
		useSpellbook = true,
		requireKnown = true, -- ein Talent: ohne es bleibt der Alarm still
		defaultIcon = "Interface\\Icons\\Spell_Nature_RavenForm",
		defaults = {
			enabled = true,
			threshold = 1,
			-- Der nächste Naturzauber ist ein Spontanzauber. Unter den anderen Alarmen am unteren Rand.
			size = 100, x = 0, y = 0, alpha = 1,
			layout = "bottom", count = 1, distance = 300, spread = 26, rotate = false, angle = 0, flip = false, perStack = false,
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_swiftness_leaf",
			textureRevision = 1,
			color = { 1, 1, 1 },
			additive = true,
			pulse = true,
			sound = "off", -- "off" | "added"
			soundFile = MEDIA .. "chime.ogg",
			icon = false,
			combatOnly = true,
			needUsable = false, -- kostet nichts
			needAggro = false,
			needTarget = false, -- auch für Heilzauber
			needRange = false, -- wirkt auf den Schamanen selbst
			needEnemies = false, minEnemies = 3, enemyRange = 10, -- nur bei so vielen Gegnern in diesem Umkreis (Namensplaketten)
			needFireTotem = false, -- nur solange ein Feuertotem steht
			needCasting = false, -- nur solange das Ziel etwas Unterbrechbares zaubert
			yieldTo = "",
			lead = 1, leadRevision = 1, -- so viele Sekunden vor "bereit" schon anzeigen
			minHealth = 0,
			auraName = L["Nature's Swiftness"],
			spellIDs = { [16188] = true },
		},
	},
	{
		key = "manatide",
		class = "SHAMAN",
		title = L["Mana Tide Totem ready"],
		kind = "ready",
		unit = "player",
		learnNames = { "Mana Tide Totem", "Totem der Manaflut" },
		useSpellbook = true,
		requireKnown = true,
		defaultIcon = "Interface\\Icons\\Spell_Frost_SummonWaterElemental",
		defaults = {
			enabled = true,
			threshold = 1,
			-- Lange Abklingzeit, lohnt sich erst bei wenig Mana: deshalb die Mana-Schwelle.
			size = 100, x = 0, y = 0, alpha = 1,
			layout = "bottom", count = 1, distance = 360, spread = 26, rotate = false, angle = 0, flip = false, perStack = false,
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_manatide_totem",
			textureRevision = 1,
			color = { 1, 1, 1 },
			additive = true,
			pulse = true,
			sound = "off", -- "off" | "added"
			soundFile = MEDIA .. "water_splash.ogg",
			icon = false,
			combatOnly = true,
			needUsable = true,
			needAggro = false,
			needTarget = false, -- wirkt auf den Schamanen und seine Gruppe
			needRange = false,
			needEnemies = false, minEnemies = 3, enemyRange = 10, -- nur bei so vielen Gegnern in diesem Umkreis (Namensplaketten)
			needFireTotem = false, -- nur solange ein Feuertotem steht
			needCasting = false, -- nur solange das Ziel etwas Unterbrechbares zaubert
			yieldTo = "",
			lead = 1, leadRevision = 1, -- so viele Sekunden vor "bereit" schon anzeigen
			maxMana = 40, -- nur zeigen, solange das eigene Mana höchstens so viel Prozent hat (0 = immer)
			minHealth = 0,
			auraName = L["Mana Tide Totem"],
			spellIDs = { [16190] = true, [17354] = true, [17359] = true, [1325256] = true },
		},
	},
	{
		key = "watershield",
		class = "SHAMAN",
		title = L["Water Shield missing"],
		kind = "missing",
		unit = "player",
		filter = "HELPFUL",
		learnNames = { "Water Shield", "Wasserschild" },
		useSpellbook = true, -- die Zauber-ID ist auch die Buff-ID
		requireKnown = true,
		defaultIcon = "Interface\\Icons\\Ability_Shaman_WaterShield",
		defaults = {
			enabled = true,
			specs = "restoration", -- wer das Blitzschlagschild trägt, braucht diesen Alarm nicht
			threshold = 1,
			size = 104, x = 0, y = 0, alpha = 1,
			layout = "top", count = 1, distance = 350, spread = 20, rotate = false, angle = 0, flip = false, perStack = false,
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_watershield_orbs",
			textureRevision = 1,
			color = { 1, 1, 1 },
			additive = true,
			pulse = true,
			sound = "off", -- "off" | "removed"
			soundFile = MEDIA .. "water_splash.ogg",
			icon = false,
			combatOnly = true,
			needUsable = true,
			needAggro = false,
			needReady = false,
			lead = 1, leadRevision = 1,
			refresh = 0, auraDuration = 600, -- nicht schon vor dem Ablauf warnen
			minHealth = 0,
			auraName = L["Water Shield"],
			-- Wasserschild auf Forever, dazu die Retail-ID
			spellIDs = { [408510] = true, [52127] = true },
		},
	},
	{
		key = "riptide",
		class = "SHAMAN",
		title = L["Riptide ready"],
		kind = "ready",
		unit = "player",
		learnNames = { "Riptide", "Springflut" },
		useSpellbook = true,
		requireKnown = true,
		defaultIcon = "Interface\\Icons\\Spell_Nature_Riptide",
		defaults = {
			enabled = false, -- kurze Abklingzeit: stünde sonst fast immer da,
			threshold = 1,
			-- Heilzauber mit kurzer Abklingzeit, links und rechts weit außen.
			size = 100, x = 0, y = 0, alpha = 1,
			layout = "sides", count = 1, distance = 250, spread = 26, rotate = false, angle = 0, flip = false, perStack = false,
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_riptide_wave",
			textureRevision = 1,
			color = { 1, 1, 1 },
			additive = true,
			pulse = true,
			sound = "off", -- "off" | "added"
			soundFile = MEDIA .. "water_splash.ogg",
			icon = false,
			combatOnly = true,
			needUsable = true,
			needAggro = false,
			needTarget = false, -- wirkt auf den Schamanen und seine Gruppe
			needRange = false,
			needEnemies = false, minEnemies = 3, enemyRange = 10, -- nur bei so vielen Gegnern in diesem Umkreis (Namensplaketten)
			needFireTotem = false, -- nur solange ein Feuertotem steht
			needCasting = false, -- nur solange das Ziel etwas Unterbrechbares zaubert
			yieldTo = "",
			lead = 1, leadRevision = 1, -- so viele Sekunden vor "bereit" schon anzeigen
			maxMana = 0, -- nur zeigen, solange das eigene Mana höchstens so viel Prozent hat (0 = immer)
			minHealth = 0,
			auraName = L["Riptide"],
			spellIDs = { [408521] = true, [1239242] = true, [1239243] = true },
		},
	},
	{
		key = "flametongue",
		class = "SHAMAN",
		title = L["Flametongue Weapon missing"],
		kind = "weapon",
		unit = "player",
		learnNames = {},
		defaultIcon = "Interface\\Icons\\Spell_Fire_FlameTounge",
		defaults = {
			enabled = true,
			specs = "restoration", -- Heiler tragen die Flammenzunge; für die übrigen gibt es den Alarm "weapon"
			threshold = 1,
			size = 140, x = 0, y = 0, alpha = 1,
			layout = "top", count = 1, distance = 220, spread = 20, rotate = false, angle = 0, flip = false, perStack = false,
			display = "texture", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
			texture = "wow_weapon_flametongue",
			textureRevision = 1,
			color = { 1, 1, 1 },
			additive = true,
			pulse = true,
			sound = "off", -- "off" | "removed"
			soundFile = MEDIA .. "war_horn.ogg",
			icon = false,
			combatOnly = false,
			needUsable = false,
			needAggro = false,
			minHealth = 0,
			offhand = false,
			mainImbue = "flametongue", offImbue = "", -- welche Verzauberung die Hand tragen soll ("" = irgendeine)
			auraName = "",
			spellIDs = {},
		},
	},
}

-- Voreinstellungen eines selbst angelegten Alarms
local CUSTOM_DEFAULTS = {
	enabled = true,
	threshold = 3,
	size = 56, x = 0, y = 0, alpha = 1,
	layout = "right", count = 1, distance = 180, spread = 26, rotate = false, angle = 0, flip = false, perStack = false,
	display = "icon", iconZoom = 8, iconBorder = 1, iconBorderColor = { 0, 0, 0 }, iconSpell = "",
	texture = "art_spark",
	color = { 1, 1, 1 },
	additive = true,
	pulse = true,
	sound = "off",
	soundFile = DEFAULT_SOUND,
	icon = false,
	combatOnly = false,
	needUsable = false,
	needAggro = false,
	needTarget = true, -- nur bei "Zauber bereit": angreifbares Ziel nötig
	needRange = false, -- nur bei "Zauber bereit": Ziel muss in Reichweite sein
	needEnemies = false, minEnemies = 3, enemyRange = 10, -- nur bei so vielen Gegnern in diesem Umkreis (Namensplaketten)
	needFireTotem = false, -- nur solange ein Feuertotem steht
	needCasting = false, -- nur solange das Ziel etwas Unterbrechbares zaubert
	castFirst = false, -- nur bei "Zauber bereit": Vorrang an seiner Stelle, solange das Ziel etwas Unterbrechbares zaubert
	maxMana = 0, -- nur zeigen, solange das eigene Mana höchstens so viel Prozent hat (0 = immer)
	specs = "", -- nur in diesen Spezialisierungen zeigen (Schlüssel durch Komma getrennt, "" = in jeder)
	needPlayer = false, -- nur solange das Ziel ein Spieler ist (PvP)
	noPlayer = false, -- nicht, solange das Ziel ein Spieler ist
	bossAlways = false, -- nur bei Alarmen auf das Ziel: Bei einem Boss gilt die Lebens-Schwelle nicht
	placeLike = "", -- Lage und Größe mit diesem Alarm teilen (Schlüssel)
	yieldTo = "", -- nur bei "Zauber bereit": hinter diesem Alarm zurückstehen
	behind = "", -- Rangfolge: hinter diesen Alarmen ganz zurückstehen (Schlüssel durch Komma getrennt)
	needReady = false, -- nur bei "fehlt": nicht anzeigen, solange der Zauber abklingt
	lead = 1, leadRevision = 1, -- Sekunden Vorlauf vor dem Ende der Abklingzeit
	refresh = 0, -- nur bei "fehlt": schon anzeigen, wenn die Aura nur noch so viele Sekunden läuft
	auraDuration = 0, -- Laufzeit der Aura in Sekunden, für die eigene Uhr (0 = unbekannt)
	minHealth = 0,
	timer = true, -- Restzeit unter der Grafik (nur bei "ist aktiv")
	auraName = "",
	spellIDs = {},
}

local CUSTOM_KINDS = { "active", "missing", "stacks", "ready" }
local KIND_NAMES = { active = L["Is active"], missing = L["Missing"], stacks = L["From X stacks"], ready = L["Spell ready"], weapon = L["Weapon"] }

-- Alarme, die das Addon mit eigenen Frames zeigt und selbst ein- und ausblendet
local PLAIN_KINDS = { weapon = true, ready = true }

-- Welche Auren zählen: eigene Buffs, alle Debuffs oder nur die selbst gewirkten
local function customFilter(spec)
	if not spec.harmful then return "HELPFUL" end
	return spec.mine and "HARMFUL|PLAYER" or "HARMFUL"
end

-- Baut aus den gespeicherten Angaben eines eigenen Alarms dessen Definition.
local function customDef(spec)
	return {
		key = spec.key,
		title = spec.title,
		kind = spec.kind,
		unit = spec.unit,
		filter = customFilter(spec),
		learnNames = {},
		useSpellbook = true, -- oft ist die Zauber-ID auch die Aura-ID
		custom = true,
		spec = spec,
		defaults = CUSTOM_DEFAULTS,
	}
end

-- Jeder Alarm lässt sich auf Spezialisierungen beschränken ("" = in jeder).
for _, def in ipairs(ALERT_DEFS) do
	if def.defaults.specs == nil then def.defaults.specs = "" end
end

local db
local alerts = {} -- Liste der Alarme in fester Reihenfolge, zusätzlich alerts[key]
local state = {
	containerOK = nil, -- nil = noch nicht geprüft
	pendingSounds = false,
	lastScan = 0,
	moving = nil, -- Alarm, dessen Vorschau gerade verschoben wird
}

local function msg(text, ...)
	if select("#", ...) > 0 then text = text:format(...) end
	print(TAG .. text)
end

local function isSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) or false
end

local function copyTable(source)
	local result = {}
	for key, value in pairs(source) do
		result[key] = type(value) == "table" and copyTable(value) or value
	end
	return result
end

local function inCombat()
	return InCombatLockdown and InCombatLockdown() or false
end

-- Gilt der Alarm für die Klasse dieses Charakters?
local function classOK(alert)
	return alert.def.class == nil or alert.def.class == state.class
end

-- Sind Auren gerade generell gesperrt (Kampf, Boss, M+ usw.)?
local function aurasRestricted()
	local check = C_Secrets and C_Secrets.ShouldAurasBeSecret
	if not check then return false end
	local ok, restricted = pcall(check)
	return ok and restricted == true
end

-- Darf diese eine Aura gerade gelesen werden? Einzelne Zauber können vom
-- Spiel freigegeben sein, auch wenn Auren sonst gesperrt sind.
local function spellReadable(spellID)
	if not aurasRestricted() then return true end
	local check = C_Secrets and C_Secrets.ShouldSpellAuraBeSecret
	if not check then return false end
	local ok, secret = pcall(check, spellID)
	return ok and secret == false
end

local function resolveTexture(settings)
	local blend = settings.additive and "ADD" or "BLEND"
	local preset = TEXTURES[settings.texture]
	if preset then return preset.path, preset.blend or blend end
	return settings.texture, blend
end

local function sortedSpellIDs(alert)
	local ids = {}
	for id in pairs(alert.s.spellIDs) do ids[#ids + 1] = id end
	table.sort(ids)
	return ids
end

-------------------------------------------------------------------------------
-- Sound
-------------------------------------------------------------------------------

local function playAlertSound(alert)
	local file = alert.s.soundFile
	if file == nil or file == "" then return end
	if PlaySoundFile then PlaySoundFile(file, "Master") end
end

-- Sounds, die das Spiel selbst abspielt. Das geht auch im Kampf, kennt aber
-- keine Stapel-Schwelle: "stack" = bei jedem neuen Stapel, "added" = wenn die
-- Aura erscheint, "removed" = wenn sie endet.
local function updateEngineSounds()
	if inCombat() or aurasRestricted() then
		state.pendingSounds = true
		return
	end
	state.pendingSounds = false
	local auras = C_UnitAuras
	local triggers = Enum and Enum.UnitAuraSoundTrigger
	local supported = auras and auras.AddAuraSound and triggers
	for _, alert in ipairs(alerts) do
		if auras and auras.RemoveAuraSound then
			for i = 1, #alert.soundRegs do pcall(auras.RemoveAuraSound, alert.soundRegs[i]) end
		end
		alert.soundRegs = {}
		local kind, sound = alert.def.kind, alert.s.sound
		local perStack = kind == "stacks" and sound == "stack"
		local onArrival = kind == "active" and sound == "added"
		local onRemoval = (kind == "missing" or kind == "active") and sound == "removed"
		local wanted = {}
		if alert.s.enabled and classOK(alert) and (perStack or onArrival or onRemoval) then
			if supported then
				wanted = perStack and { triggers.Added, triggers.ApplicationsIncreased } or onArrival and { triggers.Added } or { triggers.Removed }
			else
				msg(L["This client cannot play aura sounds, the sound for \"%s\" stays silent."], alert.def.title)
			end
		end
		for _, trigger in ipairs(wanted) do
			for id in pairs(alert.s.spellIDs) do
				local info = { unitToken = alert.def.unit, spellID = id, outputChannel = "Master" }
				local file = alert.s.soundFile
				if type(file) == "number" then info.soundFileID = file else info.soundFileName = file end
				local ok, registration = pcall(auras.AddAuraSound, trigger, info)
				if ok and registration then alert.soundRegs[#alert.soundRegs + 1] = registration end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Auren direkt lesen (nur wenn das Spiel es erlaubt)
-------------------------------------------------------------------------------

-- Liefert die Stapelzahl, 0 wenn der Buff fehlt, oder nil wenn unbekannt.
local function readStacks(alert)
	local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
	if not get or alert.def.unit ~= "player" then return nil end
	local allReadable = true
	local found
	local ok = pcall(function()
		for id in pairs(alert.s.spellIDs) do
			if spellReadable(id) then
				local aura = get(id)
				if aura then
					local count = aura.applications
					if isSecret(count) or type(count) ~= "number" then
						allReadable = false
					else
						found = count > 0 and count or 1
					end
					return
				end
			else
				allReadable = false
			end
		end
	end)
	if not ok then return nil end
	if found then return found end
	if allReadable then return 0 end
	return nil
end

-- Die Namen der eingebauten Zauber in der Sprache des Spiels, gelesen über ihre
-- IDs. So findet das Addon seine Zauber in jeder Sprache, nicht nur auf Deutsch
-- und Englisch. Das Ergebnis bleibt am Alarm gespeichert.
function ns.gameNames(def)
	if def.gameNames then return def.gameNames end
	local names, found = {}, false
	local lookup = C_Spell and C_Spell.GetSpellName
	local ids = def.defaults and def.defaults.spellIDs
	if lookup and type(ids) == "table" then
		for id in pairs(ids) do
			local ok, name = pcall(lookup, id)
			if ok and type(name) == "string" and not isSecret(name) and name ~= "" then
				names[name] = true
				found = true
			end
		end
		-- Heißt der Zauber anders als seine Aura (Totems), kommen seine Ränge dazu.
		for _, id in ipairs(def.castIDs or {}) do
			local ok, name = pcall(lookup, id)
			if ok and type(name) == "string" and not isSecret(name) and name ~= "" then names[name] = true end
		end
	end
	-- Liefert das Spiel kurz nach dem Start noch nichts, später noch einmal versuchen.
	def.gameNameTries = (def.gameNameTries or 0) + 1
	if found or def.gameNameTries >= 10 then def.gameNames = names end
	return names
end

local function auraNames(alert)
	local names = {}
	for _, name in ipairs(alert.def.learnNames) do names[name] = true end
	for name in pairs(ns.gameNames(alert.def)) do names[name] = true end
	local custom = alert.s.auraName
	if type(custom) == "string" and custom ~= "" then names[custom] = true end
	if alert.def.talentSpell and C_Spell and C_Spell.GetSpellName then
		local ok, name = pcall(C_Spell.GetSpellName, alert.def.talentSpell)
		if ok and type(name) == "string" and not isSecret(name) and name ~= "" then names[name] = true end
	end
	return names
end

local function forEachReadableAura(unit, filter, callback)
	local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if not get or aurasRestricted() then return false end
	return pcall(function()
		for index = 1, 80 do
			local aura = get(unit, index, filter)
			if not aura then break end
			local name, spellID = aura.name, aura.spellId
			if not isSecret(name) and not isSecret(spellID) and type(spellID) == "number" then
				callback(name, spellID, aura.applications, aura.duration)
			end
		end
	end)
end

local Build -- weiter unten definiert

-- Aura-IDs automatisch lernen: außerhalb des Kampfes nach dem Namen suchen.
local function learnSpellIDs()
	local now = GetTime and GetTime() or 0
	if now - state.lastScan < 1 then return end
	state.lastScan = now
	local changed = false
	for _, alert in ipairs(alerts) do
		local names = alert.def.kind ~= "weapon" and auraNames(alert) or {}
		local learned
		-- Bei "Zauber bereit" zählt nur das Zauberbuch, keine Aura mit gleichem Namen.
		if next(names) and alert.def.kind ~= "ready" then
			forEachReadableAura(alert.def.unit, alert.def.filter, function(name, spellID, _, duration)
				if names[name] and not alert.s.spellIDs[spellID] then
					alert.s.spellIDs[spellID] = true
					learned = spellID
				end
				-- Die Laufzeit der Aura für die eigene Uhr des frühen Auffrischens mitlernen
				if alert.def.kind == "missing" and (names[name] or alert.s.spellIDs[spellID]) and type(duration) == "number" and not isSecret(duration)
					and duration > 0 and math.abs(duration - (alert.s.auraDuration or 0)) > 0.05 then
					local known = (alert.s.auraDuration or 0) > 0
					alert.s.auraDuration = math.floor(duration * 10 + 0.5) / 10
					if (alert.s.refresh or 0) > 0 then
						msg(L["%s: learned an aura duration of %s s."], alert.def.title, tostring(alert.s.auraDuration))
						if not known then Build(alert) end -- erst jetzt lässt sich die Kopie zum frühen Auffrischen aufbauen
					end
					changed = true
				end
			end)
		end
		-- Den eigenen Rang aus dem Zauberbuch ergänzen
		if alert.def.useSpellbook and C_Spell and C_Spell.GetSpellInfo then
			for name in pairs(names) do
				local ok, info = pcall(C_Spell.GetSpellInfo, name)
				local spellID = ok and type(info) == "table" and info.spellID
				if type(spellID) == "number" and not isSecret(spellID) and not alert.s.spellIDs[spellID] then
					alert.s.spellIDs[spellID] = true
					learned = spellID
				end
			end
		end
		if learned then
			msg(L["%s: learned aura ID %d, rebuilding the display."], alert.def.title, learned)
			Build(alert)
			if state.moving == alert and alert.preview then ns.applyPreview(alert) end -- das Symbol kann sich geändert haben
			changed = true
		end
	end
	if changed then
		updateEngineSounds()
		if ns.RefreshOptions then ns.RefreshOptions() end
	end
end

-------------------------------------------------------------------------------
-- Anordnung: Kopien der Textur auf einem Kreis um den Charakter
-------------------------------------------------------------------------------

-- Winkel in Grad: 0 = rechts, 90 = oben, 180 = links, 270 = unten.
-- "groups" sind die Richtungen, um die sich je "Anzahl" Kopien als Bogen legen.
local LAYOUTS = {
	{ key = "center", name = L["Center"] },
	{ key = "bottom", name = L["Arc below"], groups = { 270 } },
	{ key = "top", name = L["Arc above"], groups = { 90 } },
	{ key = "left", name = L["Arc on the left"], groups = { 180 } },
	{ key = "right", name = L["Arc on the right"], groups = { 0 } },
	{ key = "sides", name = L["Left and right"], groups = { 180, 0 } },
	{ key = "topbottom", name = L["Above and below"], groups = { 90, 270 } },
	{ key = "around", name = L["All around"], ring = true },
}
for _, layout in ipairs(LAYOUTS) do LAYOUTS[layout.key] = layout end

-- Liefert die Kopien eines Alarms: Versatz zur Mitte der Anordnung, Drehung
-- (Bogenmaß) und ob die Kopie gespiegelt wird.
local function computeSpots(settings)
	local layout = LAYOUTS[settings.layout] or LAYOUTS.center
	local angles = {}
	if layout.ring then
		local count = math.max(2, settings.count)
		for index = 1, count do angles[#angles + 1] = 90 + (index - 1) * 360 / count end
	elseif layout.groups then
		for _, direction in ipairs(layout.groups) do
			for index = 1, settings.count do
				angles[#angles + 1] = direction + (index - (settings.count + 1) / 2) * settings.spread
			end
		end
	else
		return { { x = 0, y = 0, rotation = 0, mirror = false } }
	end
	local spots = {}
	for _, angle in ipairs(angles) do
		local radians = math.rad(angle)
		local cosine, sine = math.cos(radians), math.sin(radians)
		spots[#spots + 1] = {
			x = math.floor(cosine * settings.distance + 0.5),
			y = math.floor(sine * settings.distance + 0.5),
			-- Gedreht zeigt die Oberkante der Textur vom Charakter weg.
			rotation = settings.rotate and math.rad(angle - 90) or 0,
			-- Ungedreht werden die Kopien rechts gespiegelt, damit beide Seiten zueinander passen.
			mirror = not settings.rotate and cosine > 0.01,
		}
	end
	return spots
end

-- Richtet eine Textur aus: gespiegelt (von selbst auf der rechten Seite, oder
-- weil "Spiegeln" gewählt ist) und gedreht (nach außen plus die eingestellte
-- Drehung). Bei gespiegelten Kopien läuft die Drehung andersherum, damit links
-- und rechts spiegelbildlich bleiben.
local function orientTexture(texture, spot, settings)
	local mirrored = spot.mirror ~= (settings.flip == true)
	local rotation = spot.rotation + math.rad(settings.angle or 0) * (mirrored and -1 or 1)
	if mirrored then texture:SetTexCoord(1, 0, 0, 1) end
	if rotation ~= 0 and texture.SetRotation then texture:SetRotation(rotation) end
end

-- Ab wie vielen Stapeln die Kopie mit dieser Nummer erscheint.
local function spotThreshold(settings, index, total)
	if not settings.perStack then return settings.threshold end
	return math.max(1, math.ceil(index * settings.threshold / total))
end

-------------------------------------------------------------------------------
-- Schrift für Zahlen und Namen (Totem-Leiste, Restzeit, Stapelzahl)
-------------------------------------------------------------------------------

local OUTLINE_FLAGS = { none = "", outline = "OUTLINE", thick = "THICKOUTLINE" }
local OUTLINE_ORDER = { "auto", "none", "outline", "thick" }
local OUTLINE_NAMES = { auto = L["like the action bars"], none = L["shadow only"], outline = L["outline"], thick = L["thick outline"] }

local function sharedMedia()
	return LibStub and LibStub("LibSharedMedia-3.0", true) or nil
end

-- Liefert Schriftdatei, Umriss-Angabe und ob die Schrift von EllesmereUI kommt.
-- "auto" folgt der Schrift der EllesmereUI-Aktionsleisten, sonst der des Spiels.
local function resolveFont()
	local font = db.font
	local eui = _G.EllesmereUI
	local path, flags, fromEUI
	if font.face == "auto" then
		if eui and eui.GetFontPath then
			local ok, found = pcall(eui.GetFontPath, "actionBars")
			if ok and type(found) == "string" and found ~= "" then path, fromEUI = found, true end
		end
	else
		local media = sharedMedia()
		if media then
			local ok, found = pcall(media.Fetch, media, "font", font.face, true)
			if ok and type(found) == "string" and found ~= "" then path = found end
		end
		if not path and font.face:find("[\\/]") then path = font.face end
	end
	path = path or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
	if font.outline == "auto" then
		if eui and eui.GetFontOutlineFlag then
			local ok, found = pcall(eui.GetFontOutlineFlag, "actionBars")
			if ok and type(found) == "string" then flags = found end
		end
		flags = flags or "OUTLINE"
	else
		flags = OUTLINE_FLAGS[font.outline] or "OUTLINE"
	end
	return path, flags, fromEUI and font.outline == "auto"
end

-- Setzt die gewählte Schrift auf einen Text. Ohne Umriss bekommt er einen Schatten.
local function applyFont(fontString, size)
	if not (fontString and fontString.SetFont) then return end
	local path, flags, likeActionBars = resolveFont()
	local eui = _G.EllesmereUI
	-- EllesmereUI stellt Zahlen auf Symbolen selbst genau so ein wie auf den Aktionsleisten.
	if likeActionBars and eui and eui.ApplyIconTextFont and pcall(eui.ApplyIconTextFont, fontString, path, size, "actionBars") then return end
	local ok = pcall(fontString.SetFont, fontString, path, size, flags)
	if not ok or not fontString:GetFont() then
		pcall(fontString.SetFont, fontString, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "OUTLINE")
		return
	end
	if flags == "" then
		fontString:SetShadowOffset(1, -1)
		fontString:SetShadowColor(0, 0, 0, 1)
	else
		fontString:SetShadowOffset(0, 0)
	end
end

-- Auswahl im Optionsfenster: automatisch, Schrift des Spiels, dann alle bei
-- LibSharedMedia angemeldeten Schriften
local function fontChoices()
	local list = { { key = "auto", name = L["Automatic (like the action bars)"] } }
	local media = sharedMedia()
	if media then
		local ok, names = pcall(media.List, media, "font")
		if ok and type(names) == "table" then
			for _, name in ipairs(names) do list[#list + 1] = { key = name, name = name } end
		end
	end
	return list
end

-------------------------------------------------------------------------------
-- Grafik eines Alarms: Textur oder Zaubersymbol
-------------------------------------------------------------------------------

-- Welches Symbol zeigt der Alarm in der Darstellung "Zaubersymbol"? Leer heißt:
-- das übliche Symbol des Alarms. Sonst ein Texturpfad, eine Zauber-ID oder ein
-- Zaubername, dessen Symbol das Spiel liefert.
local function resolveIcon(alert)
	local custom = alert.s.iconSpell
	if type(custom) == "string" and custom ~= "" then
		if custom:find("[\\/]") then return custom end
		local lookup = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
		if lookup then
			local ok, icon = pcall(lookup, tonumber(custom) or custom)
			if ok and icon ~= nil and not isSecret(icon) then return icon end
		end
	end
	if alert.def.defaultIcon then return alert.def.defaultIcon end
	-- Eigene Alarme: das Symbol der ersten bekannten Aura
	local lookup = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
	if lookup then
		for _, id in ipairs(sortedSpellIDs(alert)) do
			local ok, icon = pcall(lookup, id)
			if ok and icon ~= nil and not isSecret(icon) then return icon end
		end
	end
	return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function addPulse(region)
	local group = region:CreateAnimationGroup()
	group:SetLooping("BOUNCE")
	local fade = group:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0.45)
	fade:SetDuration(0.45)
	fade:SetSmoothing("IN_OUT")
	group:Play()
end

-- Eine Grafik besteht aus zwei Texturen: "back" ist die Fläche, die der Aufrufer
-- platziert (in der Symbol-Darstellung der Rahmen), "main" das Bild darin.
local function newGraphic(owner)
	return { back = owner:CreateTexture(nil, "ARTWORK"), main = owner:CreateTexture(nil, "OVERLAY") }
end

-- Richtet eine Grafik nach den Einstellungen ein. Mit "animate" pulsiert sie.
-- "partPath" zeigt statt des ganzen Bildes eines seiner Teile.
local function styleGraphic(graphic, alert, spot, animate, partPath)
	local settings = alert.s
	local back, main = graphic.back, graphic.main
	main:ClearAllPoints()
	main:SetTexCoord(0, 1, 0, 1)
	if main.SetRotation then main:SetRotation(0) end
	if settings.display == "icon" then
		-- Zaubersymbol im Stil von EllesmereUI: quadratisch, herangezoomt, dünner Rahmen
		local border = settings.iconBorder
		local color = settings.iconBorderColor
		back:SetColorTexture(color[1], color[2], color[3], border > 0 and settings.alpha or 0)
		main:SetPoint("TOPLEFT", back, "TOPLEFT", border, -border)
		main:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -border, border)
		main:SetTexture(resolveIcon(alert))
		main:SetBlendMode("BLEND")
		main:SetVertexColor(1, 1, 1, settings.alpha)
		local crop = settings.iconZoom / 100
		main:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	else
		local path, blend = resolveTexture(settings)
		back:SetColorTexture(0, 0, 0, 0)
		main:SetAllPoints(back)
		main:SetTexture(partPath or path)
		main:SetBlendMode(blend)
		local preset = TEXTURES[settings.texture]
		if preset and preset.colored then
			main:SetVertexColor(1, 1, 1, settings.alpha) -- die Farben stecken in der Datei
		else
			main:SetVertexColor(settings.color[1], settings.color[2], settings.color[3], settings.alpha)
		end
		orientTexture(main, spot, settings)
	end
	if animate and settings.pulse then
		addPulse(main)
		if settings.display == "icon" then addPulse(back) end
	end
end

-------------------------------------------------------------------------------
-- Vorschau (zum Verschieben und Testen) und Notfall-Anzeige ohne AuraContainer
-------------------------------------------------------------------------------

-- Die Vorschau deckt alle Kopien ab. "offset" ist der Abstand ihrer Mitte zur
-- Mitte der Anordnung, zum Beispiel bei einem Bogen, der nur unten liegt.
local function previewBounds(settings)
	local spots = computeSpots(settings)
	local minX, maxX, minY, maxY = spots[1].x, spots[1].x, spots[1].y, spots[1].y
	for _, spot in ipairs(spots) do
		minX, maxX = math.min(minX, spot.x), math.max(maxX, spot.x)
		minY, maxY = math.min(minY, spot.y), math.max(maxY, spot.y)
	end
	return spots, (minX + maxX) / 2, (minY + maxY) / 2, maxX - minX + settings.size, maxY - minY + settings.size
end

local function getPreview(alert)
	if alert.preview then return alert.preview end
	local preview = CreateFrame("Frame", "ShamanAlertsPreview_" .. alert.key, UIParent)
	preview:Hide()
	preview:SetFrameStrata("HIGH")
	preview:SetClampedToScreen(true)
	preview.graphics = {}
	preview.textures = {} -- die Bilder der Grafiken, in derselben Reihenfolge
	preview.label = preview:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	preview.label:SetPoint("TOP", preview, "BOTTOM", 0, -4)
	preview.label:SetText(alert.def.title .. L[": drag to move"])
	preview.label:Hide()
	preview:RegisterForDrag("LeftButton")
	preview:SetScript("OnDragStart", function(self)
		if state.moving == alert then self:StartMoving() end
	end)
	preview:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local centerX, centerY = self:GetCenter()
		local parentX, parentY = UIParent:GetCenter()
		local _, offsetX, offsetY = previewBounds(alert.s)
		if centerX and parentX then
			alert.s.x = math.floor(centerX - parentX - offsetX + 0.5)
			alert.s.y = math.floor(centerY - parentY - offsetY + 0.5)
		end
		self:ClearAllPoints()
		self:SetPoint("CENTER", UIParent, "CENTER", alert.s.x + offsetX, alert.s.y + offsetY)
		if ns.RefreshOptions then ns.RefreshOptions() end
		if ns.scheduleBuild then ns.scheduleBuild(alert) end
	end)
	alert.preview = preview
	return preview
end

local function applyPreview(alert)
	local preview = getPreview(alert)
	local settings = alert.s
	local spots, offsetX, offsetY, width, height = previewBounds(settings)
	preview:SetSize(width, height)
	preview:ClearAllPoints()
	preview:SetPoint("CENTER", UIParent, "CENTER", settings.x + offsetX, settings.y + offsetY)
	for index, spot in ipairs(spots) do
		local graphic = preview.graphics[index]
		if not graphic then
			graphic = newGraphic(preview)
			preview.graphics[index] = graphic
			preview.textures[index] = graphic.main
		end
		graphic.back:ClearAllPoints()
		graphic.back:SetSize(settings.size, settings.size)
		graphic.back:SetPoint("CENTER", preview, "CENTER", spot.x - offsetX, spot.y - offsetY)
		styleGraphic(graphic, alert, spot, false)
		graphic.back:Show()
		graphic.main:Show()
	end
	for index = #spots + 1, #preview.graphics do
		preview.graphics[index].back:Hide()
		preview.graphics[index].main:Hide()
	end
	preview.texture = preview.textures[1]
end

-- Zeigt die Vorschau eines Alarms zum Verschieben. nil beendet das Verschieben.
local function setMoving(alert)
	local previous = state.moving
	state.moving = alert
	if previous and previous ~= alert and previous.preview then
		previous.preview:SetMovable(false)
		previous.preview:EnableMouse(false)
		previous.preview.label:Hide()
		previous.preview:Hide()
	end
	if alert then
		local preview = getPreview(alert)
		applyPreview(alert)
		preview:SetMovable(true)
		preview:EnableMouse(true)
		preview.label:Show()
		preview:Show()
	end
end

-------------------------------------------------------------------------------
-- Anzeige über Blizzards AuraContainer
-------------------------------------------------------------------------------

local function ensureContainerSupport()
	if state.containerOK ~= nil then return state.containerOK end
	if C_AddOns and C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded(CONTAINER_ADDON) then
		if inCombat() then return false end -- später erneut versuchen
		if C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, CONTAINER_ADDON) end
	end
	local ok, probe = pcall(CreateFrame, "AuraContainer", nil, UIParent, CONTAINER_TEMPLATE)
	local supported = ok and probe ~= nil
		and type(probe.AddAuraSlot) == "function"
		and type(probe.AddAuraGroup) == "function"
		and type(probe.SetUnit) == "function"
		and type(probe.SetEnabled) == "function"
		and type(probe.UpdateAllAuras) == "function"
	if ok and probe then
		pcall(probe.SetEnabled, probe, false)
		pcall(probe.Hide, probe)
	end
	state.containerOK = supported and true or false
	return state.containerOK
end

-- Frames, deren Lage von einem AuraButton abhängt, brauchen diese Vorlage.
local function createLayoutFrame(parent)
	local ok, frame = pcall(CreateFrame, "Frame", nil, parent, HOST_TEMPLATE)
	if not ok or not frame then frame = CreateFrame("Frame", nil, parent) end
	frame:EnableMouse(false)
	return frame
end

local function quietButton(button)
	button:EnableMouse(false)
	if button.SetMouseClickEnabled then button:SetMouseClickEnabled(false) end
	if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(false) end
end

local function spellFilter(alert)
	return { includeSpellIDs = copyTable(alert.s.spellIDs) }
end

-- Stapel-Alarm. Jede Kopie ist ein eigener AuraButton an ihrem Platz. Alles am
-- AuraButton muss im Initializer eingerichtet werden, danach sperrt das Spiel ihn.
-- Besteht das gewählte Bild aus Teilen, liegt an jedem Platz je Teil eine Ebene:
-- Teil 1 erscheint mit den ersten Stapeln, das letzte Teil an der Schwelle.
local function buildStacks(alert)
	local settings = alert.s
	local size = settings.size
	local step = size + STEP_GAP
	local spots = computeSpots(settings)

	local container = CreateFrame("AuraContainer", nil, UIParent, CONTAINER_TEMPLATE)
	alert.current = { container = container, containers = { container }, frames = {}, visuals = {} }
	container:SetAllPoints(UIParent)
	container:SetUnit(alert.def.unit)

	local preset = settings.display ~= "icon" and TEXTURES[settings.texture] or nil
	local parts = preset and preset.parts or 1
	alert.current.parts = parts
	for index, spot in ipairs(spots) do
		local host = createLayoutFrame(UIParent)
		host:SetSize(size, size)
		host:SetPoint("CENTER", UIParent, "CENTER", settings.x + spot.x, settings.y + spot.y)
		table.insert(alert.current.frames, host)

		for part = 1, parts do
		local threshold = spotThreshold(settings, index, #spots)
		local partPath = nil
		if parts > 1 then
			threshold = math.max(1, math.ceil(part * settings.threshold / parts))
			partPath = preset.partPath:format(part)
		end
		local slot = container:AddAuraSlot((index == 1 and "alert" or ("alert" .. index)) .. (part == 1 and "" or ("p" .. part)), alert.def.filter, {
			candidateFilters = spellFilter(alert),
			initializeFrame = function(button)
				local ok, err = pcall(function()
					button:ClearAllPoints()
					button:SetAllPoints(host)
					quietButton(button)

					local clip = CreateFrame("Frame", nil, button)
					clip:SetAllPoints(button)
					clip:SetClipsChildren(true)

					-- Unsichtbare Leiste, deren Füllung pro Stapel um "step" nach rechts wächst.
					-- Ihr rechtes Ende liegt genau am rechten Rand des sichtbaren Ausschnitts.
					local bar = CreateFrame("StatusBar", nil, clip)
					bar:SetSize(step * threshold, size)
					bar:SetPoint("RIGHT", clip, "RIGHT", 0, 0)
					bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
					bar:SetStatusBarColor(0, 0, 0, 0)
					bar:SetMinMaxValues(0, threshold)
					bar:SetValue(0)

					-- Die Textur hängt am Ende der Füllung. Unter der Schwelle steht sie
					-- links außerhalb des Ausschnitts, ab der Schwelle genau darin.
					local graphic = newGraphic(bar)
					graphic.back:SetSize(size, size)
					graphic.back:SetPoint("RIGHT", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
					styleGraphic(graphic, alert, spot, true, partPath)

					local immediate = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
					local set = pcall(button.SetApplicationBar, button, bar, { maxApplications = threshold, interpolation = immediate })
					if not set then button:SetApplicationBar(bar, { maxApplications = threshold }) end
				end)
				if not ok then alert.initError = tostring(err) end
			end,
		})
		if not slot then error(L["AddAuraSlot did not return a button"]) end
		end
	end

	if settings.icon then
		local iconHost = createLayoutFrame(UIParent)
		iconHost:SetSize(36, 36)
		iconHost:SetPoint("CENTER", UIParent, "CENTER", settings.x, settings.y)
		table.insert(alert.current.frames, iconHost)
		container:AddAuraSlot("icon", alert.def.filter, {
			candidateFilters = spellFilter(alert),
			initializeFrame = function(button)
				local ok, err = pcall(function()
					button:ClearAllPoints()
					button:SetAllPoints(iconHost)
					quietButton(button)
					local icon = button:CreateTexture(nil, "ARTWORK")
					icon:SetAllPoints(button)
					icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
					button:SetIcon(icon)
					local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
					count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 2)
					applyFont(count, db.font.timerSize)
					button:SetApplicationCount(count)
				end)
				if not ok then alert.initError = alert.initError or tostring(err) end
			end,
		})
	end

	container:SetEnabled(true)
	container:Show()
	container:UpdateAllAuras()
end

-- Früh auffrischen: Ein Fehlt-Alarm kann schon erscheinen, wenn die Aura nur
-- noch wenige Sekunden läuft. Die Restzeit verrät das Spiel im Kampf nicht,
-- deshalb stoppt das Addon selbst mit: Die Uhr startet, sobald der Spieler den
-- Zauber des Alarms wirkt, und läuft so lange, wie die Aura dauert.
local function refreshSeconds(alert)
	if alert.def.kind ~= "missing" then return 0 end
	local seconds, duration = alert.s.refresh or 0, alert.s.auraDuration or 0
	if seconds <= 0 or duration <= 0 then return 0 end
	return seconds
end

local function targetGUID()
	if type(UnitGUID) ~= "function" then return nil end
	local ok, guid = pcall(UnitGUID, "target")
	if not ok or guid == nil or isSecret(guid) then return nil end
	return guid
end

-- Der Spieler hat einen Zauber gewirkt: bei den passenden Alarmen die Uhr starten.
local function noteCast(spellID)
	if isSecret(spellID) or type(spellID) ~= "number" then return end
	local name
	if C_Spell and C_Spell.GetSpellName then
		local ok, found = pcall(C_Spell.GetSpellName, spellID)
		if ok and type(found) == "string" and not isSecret(found) then name = found end
	end
	for _, alert in ipairs(alerts) do
		if alert.def.kind == "missing" and (alert.s.spellIDs[spellID] or (name and auraNames(alert)[name])) then
			alert.castAt = GetTime and GetTime() or 0
			-- false heißt: Das Spiel verrät nicht, auf wen der Zauber ging.
			alert.castTarget = nil
			if alert.def.unit == "target" then alert.castTarget = targetGUID() or false end
		end
	end
end

-- Wie viele Sekunden läuft die Aura nach der eigenen Uhr noch? nil heißt: Die
-- Uhr läuft nicht, oder sie gilt einem anderen Ziel.
local function refreshRemaining(alert)
	local castAt = alert.castAt
	if not castAt then return nil end
	if alert.castTarget and targetGUID() ~= alert.castTarget then return nil end
	return castAt + (alert.s.auraDuration or 0) - (GetTime and GetTime() or 0)
end

-- Ist jetzt die Zeit zum frühen Auffrischen? Nach dem Ablauf gilt das noch
-- einen Moment weiter, bis das Spiel die Aura wirklich entfernt hat.
local function refreshDue(alert)
	local seconds = refreshSeconds(alert)
	if seconds <= 0 then return false end
	local remaining = refreshRemaining(alert)
	return remaining ~= nil and remaining <= seconds and remaining > -1
end

-- Taste unter der Grafik: Auf Wunsch steht unter jedem Alarm, auf welcher Taste
-- sein Zauber liegt. Der Text hängt an der Grafik und erscheint mit ihr.
local HOTKEY_ROOM = 30

function ns.attachHotkey(visual)
	local text = visual:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	text:SetPoint("TOP", visual, "BOTTOM", 0, -2)
	text:SetText("")
	visual.hotkey = text
	state.hotkeysDirty = true
end

-- Die Zauber, die ein Alarm zum Wirken nahelegt: Namen und IDs, oder nil.
function ns.hotkeySpells(alert)
	local kind = alert.def.kind
	if kind == "weapon" then
		local id = ns.IMBUE_SPELLS[alert.s.mainImbue or ""]
		if not id then return nil end
		return nil, { [id] = true }
	end
	if kind ~= "ready" and kind ~= "missing" then return nil end
	return auraNames(alert), alert.s.spellIDs
end

-- Schreibt die Tasten unter die Grafiken (oder leert sie, wenn ausgeschaltet).
function ns.refreshHotkeys()
	for _, alert in ipairs(alerts) do
		if alert.current and alert.current.visuals then
			local key = ""
			if db.hotkeys and ns.Hotkeys then
				local names, ids = ns.hotkeySpells(alert)
				if names or ids then key = ns.Hotkeys.ForSpells(names, ids) or "" end
			end
			alert.hotkey = key
			for _, visual in ipairs(alert.current.visuals) do
				if visual.hotkey then
					applyFont(visual.hotkey, db.font.timerSize)
					visual.hotkey:SetText(key)
				end
			end
		end
	end
	if ns.Totems and ns.Totems.RefreshHotkeys then ns.Totems.RefreshHotkeys() end
end

-- Alarme "fehlt" und "ist aktiv". Der Container enthält höchstens ein Element,
-- das so breit ist wie die Grafik, und passt seine Breite dem Inhalt an. Der
-- sichtbare Ausschnitt hängt an seiner rechten Kante:
--   fehlt:     Ohne Aura liegt der Ausschnitt über der Grafik. Ist die Aura da,
--              rutscht er um eine Grafikbreite weiter und verdeckt sie.
--   ist aktiv: Der Ausschnitt liegt eine Grafikbreite links. Erst wenn die Aura
--              da ist, rutscht er über die Grafik.
local function buildPresence(alert)
	local settings = alert.s
	local size = settings.size
	local active = alert.def.kind == "active"
	local axis = AnchorUtil and AnchorUtil.FlowLayoutAxis and AnchorUtil.FlowLayoutAxis.Horizontal
	if axis == nil then error(L["AnchorUtil.FlowLayoutAxis is missing in this client"]) end

	alert.current = { containers = {}, frames = {}, visuals = {}, leads = {} }
	local hosts = {}
	local spots = computeSpots(settings)
	for _, spot in ipairs(spots) do
		local host = createLayoutFrame(UIParent)
		host:SetSize(size, size)
		host:SetPoint("CENTER", UIParent, "CENTER", settings.x + spot.x, settings.y + spot.y)
		hosts[#hosts + 1] = host

		local container = CreateFrame("AuraContainer", nil, UIParent, CONTAINER_TEMPLATE .. "," .. HOST_TEMPLATE)
		local clip = createLayoutFrame(UIParent)
		table.insert(alert.current.containers, container)
		table.insert(alert.current.frames, host)
		table.insert(alert.current.frames, clip)
		container:SetEnabled(false)
		container:Hide()
		container:SetAlpha(0)
		container:ClearAllPoints()
		container:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)

		clip:SetClipsChildren(true)
		clip:SetSize(size, size + HOTKEY_ROOM) -- unter der Grafik bleibt Platz für die Taste
		clip:ClearAllPoints()
		clip:SetPoint("TOPLEFT", container, "TOPRIGHT", active and -(size + 1) or -1, 0)

		-- Der Inhalt hängt am festen Host, nur der Ausschnitt bewegt sich.
		local content = createLayoutFrame(clip)
		content:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
		content:SetSize(size, size)
		table.insert(alert.current.leads, content) -- trägt die Deckkraft der Vorlaufzeit

		-- Diesen Rahmen blendet das Addon selbst ein und aus (Kampf, Ziel).
		local visual = createLayoutFrame(content)
		visual:SetAllPoints(content)
		visual:Hide()
		local graphic = newGraphic(visual)
		graphic.back:SetAllPoints(visual)
		styleGraphic(graphic, alert, spot, true)
		table.insert(alert.current.visuals, visual)
		ns.attachHotkey(visual)

		container:SetFlowLayoutAxis(axis)
		container:SetFlowLayoutAnchorPoint("TOPLEFT")
		container:SetFlowLayoutGrowthDirection(1, -1)
		container:SetFlowLayoutPadding(0, 0, 0, 0)
		container:SetFlowLayoutMaximumLineSize(size + 2)
		container:AddAuraGroup("present", alert.def.filter, {
			maxFrameCount = 1,
			candidateFilters = spellFilter(alert),
			layout = { elementWidth = size + 1, elementHeight = size, elementSpacing = 0, lineSpacing = 0, groupSpacing = 0, groupLineSpacing = 0 },
			initializeFrame = function(button)
				button:SetSize(1, 1)
				button:EnableMouse(false)
			end,
		})
		if container.SetAuraGroupMaxFrameCount then pcall(container.SetAuraGroupMaxFrameCount, container, "present", 1) end

		container:SetUnit(alert.def.unit)
		container:SetEnabled(true)
		container:Show()
		container:UpdateAllAuras()
	end
	alert.current.container = alert.current.containers[1]
	alert.current.visual = alert.current.visuals[1]

	-- Früh auffrischen: je Stelle eine weitere Kopie der Grafik im Ausschnitt
	-- "Aura ist da". Das Addon blendet sie nur ein, solange seine Uhr die letzten
	-- Sekunden anzeigt. Fehlt die Aura trotzdem (verfehlt, widerstanden), bleibt
	-- sie unsichtbar und die gewöhnliche Kopie zeigt den Alarm.
	if refreshSeconds(alert) > 0 then
		alert.current.early = {}
		for index, host in ipairs(hosts) do
			local clip = createLayoutFrame(UIParent)
			table.insert(alert.current.frames, clip)
			clip:SetClipsChildren(true)
			clip:SetSize(size, size + HOTKEY_ROOM)
			clip:ClearAllPoints()
			clip:SetPoint("TOPLEFT", alert.current.containers[index], "TOPRIGHT", -(size + 1), 0)
			local content = createLayoutFrame(clip)
			content:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
			content:SetSize(size, size)
			table.insert(alert.current.leads, content)
			local visual = createLayoutFrame(content)
			visual:SetAllPoints(content)
			visual:Hide()
			local graphic = newGraphic(visual)
			graphic.back:SetAllPoints(visual)
			styleGraphic(graphic, alert, spots[index], true)
			table.insert(alert.current.visuals, visual)
			alert.current.early[visual] = true
			ns.attachHotkey(visual)
		end
	end

	-- Restzeit: Ein eigener Container mit einem AuraButton je Kopie. Das Spiel
	-- schreibt die herunterzählende Zeit selbst in den Text unter der Grafik.
	if active and settings.timer then
		local timers = CreateFrame("AuraContainer", nil, UIParent, CONTAINER_TEMPLATE)
		table.insert(alert.current.containers, timers)
		alert.current.timers = timers
		timers:SetAllPoints(UIParent)
		timers:SetUnit(alert.def.unit)
		for index, host in ipairs(hosts) do
			timers:AddAuraSlot("timer" .. index, alert.def.filter, {
				candidateFilters = spellFilter(alert),
				initializeFrame = function(button)
					local ok, err = pcall(function()
						button:ClearAllPoints()
						button:SetAllPoints(host)
						quietButton(button)
						local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
						text:SetPoint("TOP", button, "BOTTOM", 0, -2)
						applyFont(text, db.font.timerSize)
						button:SetDurationText(text)
					end)
					if not ok then alert.initError = alert.initError or tostring(err) end
				end,
			})
		end
		timers:SetEnabled(true)
		timers:Show()
		timers:UpdateAllAuras()
	end
end

-- Waffen-Alarm und "Zauber bereit": einfache eigene Frames, die das Addon
-- selbst ein- und ausblendet.
local function buildPlain(alert)
	local settings = alert.s
	alert.current = { containers = {}, frames = {}, visuals = {}, leads = {} }
	for _, spot in ipairs(computeSpots(settings)) do
		-- "lead" trägt die Deckkraft der Vorlaufzeit, "visual" wird ein- und ausgeblendet.
		local lead = CreateFrame("Frame", nil, UIParent)
		lead:SetSize(settings.size, settings.size)
		lead:SetPoint("CENTER", UIParent, "CENTER", settings.x + spot.x, settings.y + spot.y)
		lead:EnableMouse(false)
		local visual = CreateFrame("Frame", nil, lead)
		visual:SetAllPoints(lead)
		visual:EnableMouse(false)
		visual:Hide()
		local graphic = newGraphic(visual)
		graphic.back:SetAllPoints(visual)
		styleGraphic(graphic, alert, spot, true)
		table.insert(alert.current.frames, lead)
		table.insert(alert.current.leads, lead)
		table.insert(alert.current.visuals, visual)
		ns.attachHotkey(visual)
	end
	alert.current.visual = alert.current.visuals[1]
end

-- Die Waffenverzauberungen des Schamanen. Welche auf der Waffe liegt, verrät
-- die Kennung der Verzauberung (alle Ränge, dazu die Kennungen von WoW Forever).
ns.IMBUES = { "windfury", "flametongue", "rockbiter", "frostbrand" }
ns.IMBUE_NAMES = { windfury = L["Windfury Weapon"], flametongue = L["Flametongue Weapon"], rockbiter = L["Rockbiter Weapon"], frostbrand = L["Frostbrand Weapon"] }
-- der erste Rang des Zaubers, für den Namen und die Taste
ns.IMBUE_SPELLS = { windfury = 8232, flametongue = 8024, rockbiter = 8017, frostbrand = 8033 }
ns.IMBUE_IDS = {}
for family, ids in pairs({
	windfury = { 283, 284, 525, 1669, 7569 },
	flametongue = { 3, 4, 5, 523, 1665, 1666, 7567 },
	rockbiter = { 1, 6, 29, 503, 683, 1663, 1664, 7568 },
	frostbrand = { 2, 12, 524, 1667, 1668, 7566 },
}) do
	for _, id in ipairs(ids) do ns.IMBUE_IDS[id] = family end
end

-- Name der erwarteten Verzauberung für Texte.
function ns.imbueName(key)
	return ns.IMBUE_NAMES[key or ""] or L["any enchant"]
end

-- Trägt eine Hand die erwartete Verzauberung? "families" nennt, was auf der
-- Waffe liegt. true/false, oder nil, wenn es sich nicht erkennen lässt.
function ns.imbueFits(families, expected)
	if not ns.IMBUE_NAMES[expected or ""] then return true end
	if type(families) ~= "table" then return nil end
	if families[expected] then return true end
	if families.unknown then return nil end
	return false
end

-- Setzt die erwartete Verzauberung einer Hand ("mainImbue" oder "offImbue").
function ns.setImbue(alert, field, text)
	if alert.def.kind ~= "weapon" then return false, L["This exists for weapon alerts only."] end
	local word = tostring(text or ""):lower()
	if word == "" or word == "any" or word == "egal" then
		alert.s[field] = ""
		return true
	end
	for _, family in ipairs(ns.IMBUES) do
		if #word >= 3 and family:sub(1, #word) == word then
			alert.s[field] = family
			return true
		end
	end
	return false, L["Please enter any, windfury, flametongue, rockbiter or frostbrand."]
end

-- Hat die Waffe in diesem Platz eine zeitlich begrenzte Verzauberung?
-- true/false, oder nil, wenn das Spiel es gerade nicht verrät. Bei true dazu
-- die Arten, die auf der Waffe liegen: { windfury = true, other = true, unknown = true }.
local function slotImbued(invSlot)
	local slots, kinds = Enum and Enum.WeaponSlot, Enum and Enum.ItemEnchantType
	if C_Item and C_Item.GetWeaponEnchantInfo and slots and kinds then
		local ok, enchants = pcall(C_Item.GetWeaponEnchantInfo, invSlot == 16 and slots.MainHand or slots.OffHand)
		if not ok or isSecret(enchants) or type(enchants) ~= "table" then return nil end
		local unknown, found, families = false, false, {}
		for _, enchant in pairs(enchants) do
			if isSecret(enchant) or type(enchant) ~= "table" then
				unknown = true
			else
				local active, kind = enchant.hasEnchant, enchant.enchantType
				if isSecret(active) or isSecret(kind) or active == nil then
					unknown = true
				elseif active == true and (kind == kinds.Temporary or kind == kinds.Imbue) then
					found = true
					local id = enchant.enchantID
					if id == nil or isSecret(id) then families.unknown = true else families[ns.IMBUE_IDS[id] or "other"] = true end
				end
			end
		end
		if found then
			if unknown then families.unknown = true end
			return true, families
		end
		if unknown then return nil end
		return false
	end
	if GetWeaponEnchantInfo then -- ältere Schnittstelle
		local ok, hasMain, _, _, mainID, hasOff, _, _, offID = pcall(GetWeaponEnchantInfo)
		local has = invSlot == 16 and hasMain or hasOff
		if not ok or isSecret(has) then return nil end
		if not has then return false end
		local id, families = invSlot == 16 and mainID or offID, {}
		if id == nil or isSecret(id) then families.unknown = true else families[ns.IMBUE_IDS[id] or "other"] = true end
		return true, families
	end
	return nil
end

-- Steckt in diesem Platz eine Waffe (kein Schild, keine Angel)?
local function slotHasWeapon(invSlot)
	local link = GetInventoryItemLink and GetInventoryItemLink("player", invSlot)
	if not link or isSecret(link) then return false end
	local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
	if not instant then return true end
	local ok, _, _, _, _, _, classID, subclassID = pcall(instant, link)
	if not ok or classID == nil then return true end
	return classID == 2 and subclassID ~= 20
end

-- Ein Waffen-Alarm, der irgendeine Verzauberung gelten lässt, schweigt, solange
-- ein anderer gerade eine bestimmte vermisst: Der sagt genauer, was fehlt.
function ns.weaponCovered(alert)
	if (alert.s.mainImbue or "") ~= "" or (alert.s.offImbue or "") ~= "" then return false end
	for _, other in ipairs(alerts) do
		if other ~= alert and other.def.kind == "weapon" and other.s.enabled and other.current and other.weaponMissing == true
			and ((other.s.mainImbue or "") ~= "" or (other.s.offImbue or "") ~= "") and ns.internals.conditionMet(other) then
			return true
		end
	end
	return false
end

-- Aktualisiert "Verzauberung fehlt" für jeden Waffen-Alarm. Ist der Zustand
-- gerade nicht lesbar, gilt der zuletzt bekannte.
local function updateWeaponState()
	for _, alert in ipairs(alerts) do
		if alert.def.kind == "weapon" then
			local anyMissing, anyUnknown = false, false
			for _, invSlot in ipairs({ 16, 17 }) do
				if (invSlot == 16 or alert.s.offhand) and slotHasWeapon(invSlot) then
					local imbued, families = slotImbued(invSlot)
					if imbued == true then
						-- verzaubert, aber womöglich nicht mit dem, was die Hand tragen soll
						imbued = ns.imbueFits(families, invSlot == 16 and alert.s.mainImbue or alert.s.offImbue)
					end
					if imbued == false then anyMissing = true elseif imbued == nil then anyUnknown = true end
				end
			end
			local missing = alert.weaponMissing
			if anyMissing then missing = true elseif not anyUnknown then missing = false end
			if alert.weaponMissing == false and missing == true and alert.s.enabled and classOK(alert) and alert.s.sound == "removed" then
				if PlaySoundFile and alert.s.soundFile and alert.s.soundFile ~= "" then PlaySoundFile(alert.s.soundFile, "Master") end
			end
			alert.weaponMissing = missing
		end
	end
end

-- Vorrang: Ein "Zauber bereit"-Alarm kann hinter einem anderen Alarm
-- zurückstehen. Er erscheint dann nur, solange der andere nichts zeigen will.
local function partnerOf(alert)
	local key = alert.s.yieldTo
	if alert.def.kind ~= "ready" or type(key) ~= "string" or key == "" then return nil end
	local partner = alerts[key]
	if not partner or partner == alert or not partner.s.enabled or not classOK(partner) then return nil end
	if partner.def.kind ~= "missing" and not PLAIN_KINDS[partner.def.kind] then return nil end
	return partner
end

-- "Zauber bereit" mit Vorrang hinter einem Fehlt-Alarm. Ob dessen Aura fehlt,
-- darf das Addon im Kampf nicht lesen. Deshalb liegen an jeder Stelle bis zu
-- drei gleiche Grafiken, von denen höchstens eine sichtbar ist:
--   plain:   ohne Ausschnitt, für den Fall, dass der andere Alarm aus Gründen
--            schweigt, die das Addon kennt (kein Mana, kein Kampf ...)
--   present: im Ausschnitt "Aura ist da"
--   low:     im Ausschnitt "Aura fehlt", aber nur sichtbar, wenn das Ziel unter
--            der Lebens-Schwelle des anderen Alarms liegt (dann lohnt sich
--            dessen Zauber nicht mehr)
local function buildReady(alert)
	local partner = partnerOf(alert)
	if not (partner and partner.def.kind == "missing" and next(partner.s.spellIDs) ~= nil and ensureContainerSupport()) then
		return buildPlain(alert)
	end
	local settings = alert.s
	local size = settings.size
	local axis = AnchorUtil and AnchorUtil.FlowLayoutAxis and AnchorUtil.FlowLayoutAxis.Horizontal
	if axis == nil then return buildPlain(alert) end
	local withLow = partner.def.unit == "target" and partner.s.minHealth > 0

	alert.current = { containers = {}, frames = {}, visuals = {}, leads = {}, gated = { present = {}, low = {} }, unit = partner.def.unit, partner = partner }
	local function clippedVisual(container, host, offset, spot)
		local clip = createLayoutFrame(UIParent)
		clip:SetClipsChildren(true)
		clip:SetSize(size, size)
		clip:ClearAllPoints()
		clip:SetPoint("TOPLEFT", container, "TOPRIGHT", offset, 0)
		local content = createLayoutFrame(clip)
		content:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
		content:SetSize(size, size)
		table.insert(alert.current.leads, content) -- trägt die Deckkraft der Vorlaufzeit
		local visual = createLayoutFrame(content)
		visual:SetAllPoints(content)
		visual:Hide()
		local graphic = newGraphic(visual)
		graphic.back:SetAllPoints(visual)
		styleGraphic(graphic, alert, spot, true)
		table.insert(alert.current.frames, clip)
		return visual
	end
	for _, spot in ipairs(computeSpots(settings)) do
		local host = createLayoutFrame(UIParent)
		host:SetSize(size, size)
		host:SetPoint("CENTER", UIParent, "CENTER", settings.x + spot.x, settings.y + spot.y)
		table.insert(alert.current.frames, host)

		-- Ein gewöhnlicher Frame darf sich nicht an den Host hängen (das Spiel lehnt
		-- das ab), deshalb bekommt er dieselbe Lage direkt.
		local plainLead = CreateFrame("Frame", nil, UIParent)
		plainLead:SetSize(size, size)
		plainLead:SetPoint("CENTER", UIParent, "CENTER", settings.x + spot.x, settings.y + spot.y)
		plainLead:EnableMouse(false)
		local plainVisual = CreateFrame("Frame", nil, plainLead)
		plainVisual:SetAllPoints(plainLead)
		plainVisual:EnableMouse(false)
		plainVisual:Hide()
		local graphic = newGraphic(plainVisual)
		graphic.back:SetAllPoints(plainVisual)
		styleGraphic(graphic, alert, spot, true)
		table.insert(alert.current.frames, plainLead)
		table.insert(alert.current.leads, plainLead)
		table.insert(alert.current.visuals, plainVisual)

		local container = CreateFrame("AuraContainer", nil, UIParent, CONTAINER_TEMPLATE .. "," .. HOST_TEMPLATE)
		table.insert(alert.current.containers, container)
		container:SetEnabled(false)
		container:Hide()
		container:SetAlpha(0)
		container:ClearAllPoints()
		container:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
		table.insert(alert.current.gated.present, clippedVisual(container, host, -(size + 1), spot))
		if withLow then table.insert(alert.current.gated.low, clippedVisual(container, host, -1, spot)) end

		container:SetFlowLayoutAxis(axis)
		container:SetFlowLayoutAnchorPoint("TOPLEFT")
		container:SetFlowLayoutGrowthDirection(1, -1)
		container:SetFlowLayoutPadding(0, 0, 0, 0)
		container:SetFlowLayoutMaximumLineSize(size + 2)
		container:AddAuraGroup("present", partner.def.filter, {
			maxFrameCount = 1,
			candidateFilters = spellFilter(partner),
			layout = { elementWidth = size + 1, elementHeight = size, elementSpacing = 0, lineSpacing = 0, groupSpacing = 0, groupLineSpacing = 0 },
			initializeFrame = function(button)
				button:SetSize(1, 1)
				button:EnableMouse(false)
			end,
		})
		if container.SetAuraGroupMaxFrameCount then pcall(container.SetAuraGroupMaxFrameCount, container, "present", 1) end
		container:SetUnit(partner.def.unit)
		container:SetEnabled(true)
		container:Show()
		container:UpdateAllAuras()
	end
	alert.current.container = alert.current.containers[1]
	alert.current.visual = alert.current.visuals[1]
end

local function disableCurrent(alert)
	local current = alert.current
	if not current then return end
	for _, container in ipairs(current.containers or {}) do
		pcall(container.SetEnabled, container, false)
		pcall(container.Hide, container)
	end
	for _, frame in ipairs(current.frames) do frame:Hide() end
	alert.current = nil
end

-- Gilt die Bedingung eines Fehlt-Alarms? Geheime Werte zählen als "ja", damit
-- die Anzeige im Zweifel erscheint.
local function plain(value, fallback)
	if isSecret(value) then return fallback end
	return value
end

-- Kennt der Charakter einen der Zauber des Alarms? Geprüft wird über den Namen
-- (findet nur Zauber aus dem eigenen Zauberbuch) und über die Zauber-IDs. Gibt
-- es keine der Funktionen, gilt "ja".
local function spellKnown(alert)
	if not alert.def.requireKnown then return true end
	if alert.known == nil then
		local known, checked = false, false
		local lookup = C_Spell and C_Spell.GetSpellInfo
		if lookup then
			checked = true
			for name in pairs(auraNames(alert)) do
				local ok, info = pcall(lookup, name)
				if ok and info ~= nil then known = true end
			end
		end
		for _, byID in ipairs({ IsPlayerSpell, IsSpellKnown, C_SpellBook and C_SpellBook.IsSpellKnown }) do
			if type(byID) == "function" then
				checked = true
				for id in pairs(alert.s.spellIDs) do
					local ok, result = pcall(byID, id)
					if ok and not isSecret(result) and result == true then known = true end
				end
				for _, id in ipairs(alert.def.castIDs or {}) do
					local ok, result = pcall(byID, id)
					if ok and not isSecret(result) and result == true then known = true end
				end
			end
		end
		alert.known = known or not checked
	end
	return alert.known
end

-- Ist der Zauber des Alarms gerade wirkbar? false heißt: bekannt, aber das Mana
-- reicht nicht. nil heißt: unbekannt oder vom Spiel nicht verraten. Das Spiel
-- rechnet dabei selbst ein, ob der nächste Zauber gratis ist (Freizaubern).
-- Mit "strictUsable" zählt bei einem Zauber aus dem Zauberbuch jedes "nicht
-- wirkbar" als false, etwa weil das nötige Totem fehlt.
local function spellUsable(alert)
	local check = (C_Spell and C_Spell.IsSpellUsable) or IsUsableSpell
	if not check then return nil end
	local lacksMana = false
	local lookup = alert.def.strictUsable and C_Spell and C_Spell.GetSpellInfo
	for name in pairs(auraNames(alert)) do
		local ok, usable, noMana = pcall(check, name)
		if ok and usable ~= nil and not isSecret(usable) then
			if usable == true then return true end
			if not isSecret(noMana) and noMana == true then lacksMana = true end
			if lookup then
				local found, info = pcall(lookup, name)
				if found and info ~= nil then lacksMana = true end
			end
		end
	end
	if lacksMana then return false end
	return nil
end

-- Der Zauber eines "Zauber bereit"-Alarms: die ID aus dem Zauberbuch (höchster
-- bekannter Rang), sonst eine bekannte der eingetragenen IDs. nil = unbekannt.
local function readySpell(alert)
	if alert.readySpell ~= nil then return alert.readySpell or nil end
	local found = false
	local lookup = C_Spell and C_Spell.GetSpellInfo
	if lookup then
		for name in pairs(auraNames(alert)) do
			local ok, info = pcall(lookup, name)
			if ok and type(info) == "table" and type(info.spellID) == "number" and not isSecret(info.spellID) then
				found = info.spellID
				break
			end
		end
	end
	if not found then
		for _, byID in ipairs({ IsPlayerSpell, IsSpellKnown }) do
			if type(byID) == "function" and not found then
				for _, id in ipairs(sortedSpellIDs(alert)) do
					local ok, known = pcall(byID, id)
					if ok and not isSecret(known) and known == true then
						found = id
						break
					end
				end
			end
		end
	end
	alert.readySpell = found
	return found or nil
end

-- Ist der Zauber bereit, also nicht in einer echten Abklingzeit? Die globale
-- Abklingzeit zählt nicht. Das Spiel verrät dafür zwei einfache Ja/Nein-Werte,
-- auch im Kampf. Die genaue Restzeit bleibt geheim und wird nicht gebraucht.
-- nil heißt: unbekannter Zauber oder vom Spiel nicht verraten.
local function spellReady(alert)
	local id = readySpell(alert)
	local lookup = C_Spell and C_Spell.GetSpellCooldown
	if not (id and lookup) then return nil end
	local ok, info = pcall(lookup, id)
	if not ok then return nil end
	if info == nil then return true end
	if isSecret(info) or type(info) ~= "table" then return nil end
	local active, onGCD = info.isActive, info.isOnGCD
	if isSecret(active) or isSecret(onGCD) then return nil end
	if active == nil then
		-- ältere Schnittstelle: Start und Dauer als Zahlen
		local start, duration = info.startTime, info.duration
		if isSecret(start) or isSecret(duration) or type(duration) ~= "number" then return nil end
		return not (duration > 1.6 and (start or 0) > 0)
	end
	return not (active and not onGCD)
end

-- Ist das Ziel für den Zauber in Reichweite? nil heißt: verrät das Spiel nicht.
local function spellInRange(alert)
	local id = readySpell(alert)
	local check = C_Spell and C_Spell.IsSpellInRange
	if not (id and check) then return nil end
	local ok, result = pcall(check, id, "target")
	if not ok or result == nil or isSecret(result) then return nil end
	return result == true or result == 1
end

-- Hat der Spieler gerade Aggro (ein Gegner greift ihn an)? nil heißt: Das
-- verrät das Spiel gerade nicht.
local function hasAggro()
	if type(UnitThreatSituation) ~= "function" then return nil end
	local ok, status = pcall(UnitThreatSituation, "player")
	if not ok or isSecret(status) then return nil end
	return status ~= nil and status >= 2
end

-- Wie viele Gegner stehen im Umkreis? Gezählt werden die Namensplaketten
-- angreifbarer, lebender Einheiten. Den Abstand misst das Spiel über die
-- Reichweite bestimmter Gegenstände (5, 10 oder 20 Meter), das geht auch im
-- Kampf. Verrät es das nicht, dient ein Zauber als Ersatz: der Sturmschlag für
-- die Nähe, ein Schock für 20 Meter. nil heißt: nicht feststellbar, etwa weil
-- gegnerische Namensplaketten ausgeschaltet sind.
local RANGE_ITEMS = { [5] = 8149, [10] = 17626, [20] = 1191 }
local RANGE_SPELLS = {
	-- Eine Zahl ist eine Zauber-ID: Über sie kommt der Name in der Sprache des Spiels dazu.
	near = { "Stormstrike", "Sturmschlag", 17364 },
	far = { "Earth Shock", "Erdschock", "Flame Shock", "Flammenschock", "Frost Shock", "Frostschock", 8042, 8050, 8056 },
}
local MAX_NAMEPLATES = 40
local ENEMY_METHODS = { item = L["range of an item"], spell = L["range of a spell"], combat = L["combat state only"] }

local function rangeSpell(kind)
	state.rangeSpells = state.rangeSpells or {}
	if state.rangeSpells[kind] == nil then
		state.rangeSpells[kind] = false
		local lookup = C_Spell and C_Spell.GetSpellInfo
		if lookup then
			for _, name in ipairs(RANGE_SPELLS[kind]) do
				if type(name) == "number" and C_Spell.GetSpellName then
					local found, localName = pcall(C_Spell.GetSpellName, name)
					name = found and type(localName) == "string" and not isSecret(localName) and localName or name
				end
				local ok, info = pcall(lookup, name)
				if ok and type(info) == "table" and type(info.spellID) == "number" and not isSecret(info.spellID) then
					state.rangeSpells[kind] = info.spellID
					break
				end
			end
		end
	end
	return state.rangeSpells[kind] or nil
end

-- Bittet das Spiel, die Daten der Mess-Gegenstände zu laden. Ohne sie gibt die
-- Reichweiten-Abfrage nichts her.
local function loadRangeItems()
	local request = C_Item and C_Item.RequestLoadItemDataByID
	if not request then return end
	for _, item in pairs(RANGE_ITEMS) do pcall(request, item) end
end

-- Ist die Einheit näher als "yards"? Liefert zusätzlich, womit gemessen wurde.
-- nil heißt: Das Spiel verrät es nicht.
local function unitWithin(unit, yards)
	local item = RANGE_ITEMS[yards]
	if item and C_Item and C_Item.IsItemInRange then
		local cached = true
		if C_Item.IsItemDataCachedByID then
			local ok, result = pcall(C_Item.IsItemDataCachedByID, item)
			cached = ok and result == true
		end
		if cached then
			local ok, result = pcall(C_Item.IsItemInRange, item, unit)
			if ok and type(result) == "boolean" and not isSecret(result) then return result, "item" end
		elseif (state.rangeItemsAsked or 0) + 5 < (GetTime and GetTime() or 0) then
			state.rangeItemsAsked = GetTime and GetTime() or 0
			loadRangeItems()
		end
	end
	local spell, check = rangeSpell(yards >= 20 and "far" or "near"), C_Spell and C_Spell.IsSpellInRange
	if spell and check then
		local ok, result = pcall(check, spell, unit)
		if ok and result ~= nil and not isSecret(result) then return result == true or result == 1, "spell" end
	end
	return nil
end

-- Hält das Spiel etwas davon geheim, lässt sich nicht zählen: nil.
local function enemyNearby(unit, combat, yards)
	local exists = UnitExists(unit)
	if isSecret(exists) then return nil end
	if not exists then return false end
	local attackable, dead = UnitCanAttack("player", unit), UnitIsDeadOrGhost(unit)
	if isSecret(attackable) or isSecret(dead) then return nil end
	if not attackable or dead then return false end
	local fighting
	if UnitAffectingCombat then
		local ok, result = pcall(UnitAffectingCombat, unit)
		if ok and not isSecret(result) then fighting = result and true or false end
	end
	-- Im Kampf zählt nicht, wer unbeteiligt daneben steht.
	if combat and fighting == false then return false end
	local near, method = unitWithin(unit, yards)
	if near ~= nil then return near, method end
	if fighting ~= nil then return fighting, "combat" end
	return true, "combat"
end

-- yards: 5, 10 oder 20. Liefert die Zahl und womit zuletzt gemessen wurde.
local function nearbyEnemies(yards)
	yards = RANGE_ITEMS[yards] and yards or 10
	local now = GetTime and GetTime() or 0
	if state.enemiesAt ~= now then
		state.enemiesAt = now
		state.enemies = {}
	end
	local cached = state.enemies[yards]
	if cached ~= nil then return cached or nil, state.enemyMethod end
	state.enemies[yards] = false
	if not (UnitExists and UnitCanAttack and UnitIsDeadOrGhost) then return nil end
	if GetCVar then
		local ok, shown = pcall(GetCVar, "nameplateShowEnemies")
		if ok and (shown == "0" or shown == 0) then return nil end
	end
	local combat = inCombat()
	local ok, count, method = pcall(function()
		local total, used = 0
		for index = 1, MAX_NAMEPLATES do
			local near, how = enemyNearby("nameplate" .. index, combat, yards)
			if near == nil then return nil end
			if how then used = how end
			if near then total = total + 1 end
		end
		return total, used
	end)
	if not ok or count == nil then return nil end
	state.enemies[yards] = count
	state.enemyMethod = method
	return count, method
end

-- Für die Diagnose (/sha debug): was das Spiel über die Namensplaketten und
-- ihre Entfernung verrät. Geheime Werte erscheinen nur als "<geheim>".
local function enemyReport()
	local function show(value)
		if isSecret(value) then return "<geheim>" end
		return tostring(value)
	end
	local function call(fn, ...)
		if type(fn) ~= "function" then return "<fehlt>" end
		local ok, result = pcall(fn, ...)
		if not ok then return "<Fehler>" end
		return show(result)
	end
	local cached = {}
	for _, yards in ipairs({ 5, 10, 20 }) do
		cached[#cached + 1] = ("%dm=%s"):format(yards, call(C_Item and C_Item.IsItemDataCachedByID, RANGE_ITEMS[yards]))
	end
	local near, far = rangeSpell("near"), rangeSpell("far")
	local inRange = C_Spell and C_Spell.IsSpellInRange
	local lines = { ("plaketten: cvar=%s gegenstandsdaten(%s) sturmschlag=%s schock=%s gezählt 5/10/20 m=%s/%s/%s"):format(
		call(GetCVar, "nameplateShowEnemies"), table.concat(cached, " "), show(near), show(far),
		show((nearbyEnemies(5))), show((nearbyEnemies(10))), show((nearbyEnemies(20)))) }
	local listed = 0
	for index = 1, MAX_NAMEPLATES do
		local unit = "nameplate" .. index
		local ok, exists = pcall(UnitExists, unit)
		if ok and (isSecret(exists) or exists) and listed < 8 then
			listed = listed + 1
			lines[#lines + 1] = ("  %s: existiert=%s angreifbar=%s tot=%s kampf=%s item5=%s item10=%s item20=%s sturmschlag=%s schock=%s"):format(
				unit, show(exists), call(UnitCanAttack, "player", unit), call(UnitIsDeadOrGhost, unit), call(UnitAffectingCombat, unit),
				call(C_Item and C_Item.IsItemInRange, RANGE_ITEMS[5], unit), call(C_Item and C_Item.IsItemInRange, RANGE_ITEMS[10], unit),
				call(C_Item and C_Item.IsItemInRange, RANGE_ITEMS[20], unit),
				near and call(inRange, near, unit) or "-", far and call(inRange, far, unit) or "-")
		end
	end
	return lines
end

-- Zaubert das Ziel gerade etwas, das sich unterbrechen lässt? Das Spiel nennt
-- den Zauber und ob er geschützt ist. Sind diese Angaben im Kampf geheim, zählt
-- ein geheimer Name als "zaubert" und ein geheimer Schutz als "unterbrechbar",
-- damit der Alarm im Zweifel erscheint. Rückgabe je Abfrage: true (zaubert),
-- false (zaubert nicht oder geschützt), nil (Abfrage fehlt).
local CAST_QUERIES = {
	{ label = "zauber", fn = "UnitCastingInfo", shield = 8 },
	{ label = "kanal", fn = "UnitChannelInfo", shield = 7 },
}

local function castState(query)
	local fn = _G[query.fn]
	if type(fn) ~= "function" then return nil end
	local ok, name, _, _, _, _, _, seventh, eighth = pcall(fn, "target")
	if not ok then return nil end
	local shielded = eighth
	if query.shield == 7 then shielded = seventh end
	if not isSecret(name) and name == nil then return false, name, shielded end
	if not isSecret(shielded) and shielded == true then return false, name, shielded end
	return true, name, shielded
end

local function targetCasting()
	local known = false
	for _, query in ipairs(CAST_QUERIES) do
		local casting = castState(query)
		if casting then return true end
		if casting == false then known = true end
	end
	if known then return false end
	return nil
end

-- Für die Diagnose (/sha debug): was das Spiel über den Zauber des Ziels verrät.
local function castReport()
	local function show(value)
		if isSecret(value) then return "<geheim>" end
		return tostring(value)
	end
	local parts = {}
	for _, query in ipairs(CAST_QUERIES) do
		local casting, name, shielded = castState(query)
		parts[#parts + 1] = ("%s=%s name=%s geschützt=%s"):format(query.label, casting == nil and "<fehlt>" or tostring(casting),
			isSecret(name) and "<geheim>" or (name == nil and "nil" or "<lesbar>"), show(shielded))
	end
	return ("zielzauber: unterbrechbar=%s %s"):format(tostring(targetCasting()), table.concat(parts, " "))
end

-- Ist das Ziel ein Boss? Als Boss gilt, was das Spiel selbst so einstuft
-- (Rang "worldboss", Boss-Kennzeichen), was einen der Boss-Rahmen belegt und
-- was als Stufe den Totenkopf trägt. Rückgabe: true, false oder nil (das Spiel
-- verrät es gerade nicht). Ein Ja gilt, bis das Ziel wechselt. Ein Nein kann
-- noch kippen, weil die Boss-Rahmen erst mit dem Kampfbeginn belegt werden.
local BOSS_UNITS = 8

local function targetIsBoss()
	if state.targetBoss then return true end
	-- Im selben Augenblick fragen mehrere Alarme: dann genügt eine Abfrage.
	local now = GetTime and GetTime() or 0
	if state.bossAt == now then return state.bossSeen end
	state.bossAt, state.bossSeen = now, nil
	local unknown = false
	-- Fehlt eine Abfrage in diesem Client, zählt sie nicht. Scheitert sie oder
	-- ist ihr Ergebnis geheim, bleibt die Antwort offen.
	local function ask(fn, ...)
		if type(fn) ~= "function" then return nil end
		local ok, result = pcall(fn, ...)
		if not ok or isSecret(result) then
			unknown = true
			return nil
		end
		return result
	end
	local exists = ask(UnitExists, "target")
	if exists == nil then return nil end
	if not exists then
		state.bossSeen = false
		return false
	end
	local boss = ask(UnitClassification, "target") == "worldboss"
		or ask(UnitLevel, "target") == -1
		or ask(UnitIsBossMob, "target") == true
	for index = 1, BOSS_UNITS do
		if boss then break end
		local unit = "boss" .. index
		if ask(UnitExists, unit) then
			local same = ask(UnitIsUnit, "target", unit)
			boss = same == true or same == 1
		end
	end
	if boss then
		state.targetBoss = true
		return true
	end
	if unknown then return nil end
	state.bossSeen = false
	return false
end

-- Leben des Ziels: Die Prozentzahl ist im Kampf geheim. Erlaubt ist aber, sie
-- vom Spiel über eine Stufenkurve in eine Deckkraft umrechnen zu lassen (0
-- unter der Schwelle, 1 darüber) und diese direkt an den Rahmen zu geben.
local function healthCurve(alert)
	local threshold = alert.s.minHealth
	if alert.def.unit ~= "target" or threshold <= 0 then return nil end
	if not (UnitHealthPercent and C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType) then return nil end
	if alert.healthCurve == nil or alert.healthCurveAt ~= threshold then
		local ok, curve = pcall(function()
			local created = C_CurveUtil.CreateCurve()
			created:SetType(Enum.LuaCurveType.Step)
			created:AddPoint(0, 0)
			created:AddPoint(threshold / 100, 1)
			return created
		end)
		alert.healthCurve = ok and curve or false
		alert.healthCurveAt = threshold
	end
	return alert.healthCurve or nil
end

-- Mana-Schwelle: sichtbar nur, solange das eigene Mana höchstens so viel
-- Prozent hat. Der Wert ist im Kampf geheim, deshalb rechnet ihn das Spiel über
-- eine Stufenkurve selbst in eine Deckkraft um, wie bei der Lebens-Schwelle.
-- Spezialisierung. WoW Forever kennt keine wählbare Spezialisierung: Die drei
-- Talentbäume liegen als Gruppen in einem einzigen Baum, und als Spezialisierung
-- gilt hier der Baum mit den meisten Punkten (bei Gleichstand der linke).
ns.SPECS = { "elemental", "enhancement", "restoration" }
ns.SPEC_NAMES = { elemental = L["Elemental"], enhancement = L["Enhancement"], restoration = L["Restoration"] }

-- Liest die Punkte je Baum. Rückgabe: Schlüssel der Spezialisierung oder nil,
-- dazu die Punkte je Baum (Tabelle) oder der Grund, warum es nicht ging (Text).
function ns.readSpec()
	if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits and C_Traits.GetConfigInfo
		and C_Traits.GetGroupDisplayInfoByTreeID and C_Traits.GetGroupCurrencyInfo) then
		return nil, "api"
	end
	local ok, spec, points = pcall(function()
		local configID = C_ClassTalents.GetActiveConfigID()
		local config = configID and C_Traits.GetConfigInfo(configID)
		local treeID = config and config.treeIDs and config.treeIDs[1]
		if not treeID then return nil, "config" end
		local groups = C_Traits.GetGroupDisplayInfoByTreeID(treeID)
		if type(groups) ~= "table" or #groups == 0 then return nil, "groups" end
		table.sort(groups, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
		local ids = {}
		for index, group in ipairs(groups) do ids[index] = group.groupID end
		local spent = {}
		for _, group in ipairs(C_Traits.GetGroupCurrencyInfo(configID, ids) or {}) do
			local currency = group.currencyInfos and group.currencyInfos[1]
			if currency then spent[group.traitNodeGroupID] = tonumber(currency.spent) end
		end
		local best, lead, counts = 0, nil, {}
		for index, id in ipairs(ids) do
			counts[index] = spent[id] or 0
			if counts[index] > best then best, lead = counts[index], index end
		end
		return lead and ns.SPECS[lead] or nil, counts
	end)
	if not ok then return nil, "error" end
	return spec, points
end

-- Die Spezialisierung des Schamanen oder nil, wenn sie sich nicht erkennen
-- lässt. Von Hand festgelegt (/sha spec) geht vor. Gemerkt bis zum nächsten
-- Talent-Ereignis; ein Fehlschlag wird nach ein paar Sekunden neu versucht.
function ns.currentSpec()
	local forced = db and db.specOverride
	if forced and ns.SPEC_NAMES[forced] then return forced end
	local now = GetTime and GetTime() or 0
	if state.spec == nil or (state.spec == false and now - (state.specAt or 0) >= 5) then
		local spec, points = ns.readSpec()
		-- Punkte lesbar, aber noch keiner vergeben (unter Stufe 10): Dann gilt
		-- Verstärkung, der Baum, mit dem die meisten Schamanen aufsteigen.
		state.specAssumed = spec == nil and type(points) == "table"
		if state.specAssumed then spec = "enhancement" end
		state.spec, state.specPoints, state.specAt = spec or false, points, now
	end
	return state.spec or nil
end

-- Rang eines Talents. Auf WoW Forever sind Talente Knoten eines Baums; der
-- Knoten zählt nur, wenn er auch diesen Zauber trägt (ein Hotfix kann Knoten neu
-- belegen), sonst wird der Baum nach dem Zauber abgesucht. nil = nicht lesbar.
function ns.talentRank(spellID, nodeID)
	if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits and C_Traits.GetConfigInfo and C_Traits.GetNodeInfo
		and C_Traits.GetEntryInfo and C_Traits.GetDefinitionInfo) then
		return nil
	end
	local ok, rank = pcall(function()
		local configID = C_ClassTalents.GetActiveConfigID()
		local config = configID and C_Traits.GetConfigInfo(configID)
		local treeID = config and config.treeIDs and config.treeIDs[1]
		if not treeID then return nil end
		local function read(id)
			local node = id and C_Traits.GetNodeInfo(configID, id)
			if type(node) ~= "table" then return nil end
			local entryID = (node.activeEntry and node.activeEntry.entryID) or (node.entryIDs and node.entryIDs[1])
			local entry = entryID and C_Traits.GetEntryInfo(configID, entryID)
			local definition = entry and entry.definitionID and C_Traits.GetDefinitionInfo(entry.definitionID)
			if not definition or (definition.spellID ~= spellID and definition.overriddenSpellID ~= spellID) then return nil end
			return tonumber(node.activeRank or node.ranksPurchased or node.currentRank) or 0
		end
		state.talentNodes = state.talentNodes or {}
		local found = read(state.talentNodes[spellID] or nodeID)
		if found == nil and C_Traits.GetTreeNodes then
			for _, id in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
				found = read(id)
				if found ~= nil then
					state.talentNodes[spellID] = id
					break
				end
			end
		end
		return found
	end)
	if not ok then return nil end
	return rank
end

-- Verlängert ein Talent die Aura eines Alarms, stellt das Addon die Laufzeit
-- selbst nach, sobald sich der Rang ändert. Was von Hand eingestellt oder
-- außerhalb des Kampfes gelernt ist, bleibt bis zur nächsten Änderung stehen.
function ns.applyTalentDurations()
	for _, alert in ipairs(alerts) do
		local rule = alert.def.talentDuration
		if rule and (alert.def.class == nil or alert.def.class == state.class) then
			local rank = ns.talentRank(rule.spell, rule.node)
			if rank then
				local wanted = rule.base + rank * rule.perRank
				local first = (alert.s.talentDuration or 0) == 0
				if alert.s.talentDuration ~= wanted then
					alert.s.talentDuration = wanted
					-- Beim ersten Mal ohne das Talent bleibt die eingestellte Laufzeit.
					if not (first and rank == 0) and alert.s.auraDuration ~= wanted then
						alert.s.auraDuration = wanted
						msg(L["%s: aura duration set to %s s from your talents."], alert.def.title, tostring(wanted))
						if ns.RefreshOptions then pcall(ns.RefreshOptions) end
					end
				end
			end
		end
	end
end

-- Gilt der Alarm in dieser Spezialisierung? "specs" nennt die erlaubten
-- Schlüssel, "" heißt: in jeder.
function ns.specWanted(alert, key)
	local wanted = alert.s.specs
	return type(wanted) ~= "string" or wanted == "" or wanted:find(key, 1, true) ~= nil
end

-- Darf der Alarm gerade erscheinen? Lässt sich die Spezialisierung nicht
-- erkennen, gilt keine Beschränkung. In den ersten Sekunden nach der Anmeldung
-- kennt das Spiel die Talente womöglich noch nicht: Solange wartet ein
-- beschränkter Alarm, statt kurz aufzublitzen.
function ns.specAllows(alert)
	local wanted = alert.s.specs
	if type(wanted) ~= "string" or wanted == "" then return true end
	local spec = ns.currentSpec()
	if not spec then return (GetTime and GetTime() or 0) - (state.loginAt or 0) >= 10 end
	return wanted:find(spec, 1, true) ~= nil
end

-- Hakt eine Spezialisierung für den Alarm an oder ab. Mindestens eine bleibt.
function ns.setSpecWanted(alert, key, on)
	local list = {}
	for _, spec in ipairs(ns.SPECS) do
		local keep = ns.specWanted(alert, spec)
		if spec == key then keep = on and true or false end
		if keep then list[#list + 1] = spec end
	end
	if #list == 0 then return false end
	alert.s.specs = #list == #ns.SPECS and "" or table.concat(list, ",")
	return true
end

-- Die erlaubten Spezialisierungen eines Alarms als Text.
function ns.specText(alert)
	local names = {}
	for _, spec in ipairs(ns.SPECS) do
		if ns.specWanted(alert, spec) then names[#names + 1] = ns.SPEC_NAMES[spec] end
	end
	return table.concat(names, ", ")
end

function ns.manaCurve(alert)
	local threshold = alert.s.maxMana or 0
	if threshold <= 0 or threshold >= 100 then return nil end
	if not (UnitPowerPercent and C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType) then return nil end
	if alert.manaCurve == nil or alert.manaCurveAt ~= threshold then
		local ok, curve = pcall(function()
			local created = C_CurveUtil.CreateCurve()
			created:SetType(Enum.LuaCurveType.Step)
			created:AddPoint(0, 1)
			created:AddPoint(threshold / 100, 0)
			return created
		end)
		alert.manaCurve = ok and curve or false
		alert.manaCurveAt = threshold
	end
	return alert.manaCurve or nil
end

local function applyHealthGate(alert)
	local visuals = alert.current and alert.current.visuals
	if not visuals or #visuals == 0 then return end
	local curve = healthCurve(alert)
	-- Bei einem Boss gilt die Schwelle auf Wunsch nicht ("bossAlways").
	if curve and alert.s.bossAlways and targetIsBoss() then curve = nil end
	local alpha = 1
	if curve then
		local ok, value = pcall(UnitHealthPercent, "target", false, curve)
		if ok and value ~= nil then alpha = value end
	end
	-- Die Mana-Schwelle gibt es nur bei Alarmen auf den Schamanen selbst; dort
	-- gibt es keine Lebens-Schwelle, die beiden kommen sich also nicht in die Quere.
	local mana = ns.manaCurve(alert)
	if mana then
		local ok, value = pcall(UnitPowerPercent, "player", 0, true, mana) -- 0 = Mana
		if ok and value ~= nil then alpha = value end
	end
	for _, visual in ipairs(visuals) do pcall(visual.SetAlpha, visual, alpha) end
end

-- Vorlaufzeit: Ein Alarm, der an einer Abklingzeit hängt, kann schon kurz vor
-- deren Ende erscheinen. Die Restzeit ist geheim, aber das Spiel rechnet sie
-- über eine Stufenkurve in eine Deckkraft um: 1, sobald höchstens "lead"
-- Sekunden fehlen, sonst 0. Diese Zahl geht ungelesen an die Rahmen.
local function leadAlpha(alert)
	local lead = alert.s.lead or 0
	local id = readySpell(alert)
	local getDuration = C_Spell and C_Spell.GetSpellCooldownDuration
	if not (lead > 0 and id and getDuration and C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType) then return 0 end
	if alert.leadCurve == nil or alert.leadCurveAt ~= lead then
		local ok, curve = pcall(function()
			local created = C_CurveUtil.CreateCurve()
			created:SetType(Enum.LuaCurveType.Step)
			created:AddPoint(0, 1)
			created:AddPoint(lead, 0)
			return created
		end)
		alert.leadCurve = ok and curve or false
		alert.leadCurveAt = lead
	end
	if not alert.leadCurve then return 0 end
	local ok, duration = pcall(getDuration, id)
	if not ok or duration == nil then return 0 end
	local evaluated, alpha = pcall(function() return duration:EvaluateRemainingDuration(alert.leadCurve, 0) end)
	if not evaluated or alpha == nil then return 0 end
	return alpha
end

-- cooling: Der Zauber klingt noch ab, die Grafik hängt an der Vorlaufzeit.
local function setLeadAlpha(alert, cooling)
	local current = alert.current
	local leads = current and current.leads
	if not leads then return end
	if not cooling and current.leadCooling == false then return end -- steht schon auf voll sichtbar
	current.leadCooling = cooling
	local alpha = cooling and leadAlpha(alert) or 1
	for _, frame in ipairs(leads) do pcall(frame.SetAlpha, frame, alpha) end
end

local conditionMet -- weiter unten definiert

-- Will der Vorrang-Alarm gerade etwas zeigen, soweit das Addon es beurteilen
-- kann? Bei einem Fehlt-Alarm bleibt offen, ob die Aura wirklich fehlt.
local function partnerWants(partner)
	if not conditionMet(partner) then return false end
	if partner.def.kind == "weapon" then return partner.weaponMissing == true end
	if partner.def.kind == "ready" then return spellReady(partner) == true end
	-- Klingt der Zauber des Fehlt-Alarms noch ab, zeigt er höchstens in seiner Vorlaufzeit etwas.
	if partner.def.kind == "missing" and partner.s.needReady and (partner.s.lead or 0) <= 0 and spellReady(partner) == false then return false end
	return true
end

-- Rangfolge: Ein Alarm kann hinter mehreren anderen zurückstehen ("behind",
-- Schlüssel durch Komma getrennt). Anders als beim Vorrang über die Aura
-- entscheidet hier allein, was das Addon selbst weiß:
--   Zauber bereit / Waffe: ob der andere Alarm gerade etwas zeigt
--   fehlt:                 ob seine Bedingungen gelten und die eigene Uhr sagt,
--                          dass die Aura nicht (mehr) auf dem Ziel liegt
-- So lässt sich etwa festlegen: Unterbrechen vor Frostschock vor Flammenschock
-- vor dem allgemeinen Schock.
local standsBehind -- gleich darunter definiert

local function claimsPriority(other, depth)
	if not other.s.enabled or not classOK(other) or not other.current then return false end
	if not partnerWants(other) then return false end
	if other.def.kind == "missing" then
		-- Ohne bekannte Laufzeit lässt sich nicht mitstoppen: dann kein Vorrang.
		if (other.s.auraDuration or 0) <= 0 then return false end
		local remaining = refreshRemaining(other)
		if remaining ~= nil and remaining > 0 then return false end
	end
	-- Steht der andere selbst gerade zurück, zeigt er nichts und hat keinen Vorrang.
	return not standsBehind(other, depth + 1)
end

-- Vorrang beim Unterbrechen ("castFirst"): Zaubert das Ziel etwas
-- Unterbrechbares und ist der Zauber dieses Alarms bereit, erscheint er sofort.
-- Die Alarme, hinter denen er sonst zurücksteht ("behind" und "yieldTo"),
-- schweigen so lange. Das gilt unabhängig davon, wo die Alarme stehen.
function ns.castPriority(alert)
	if not alert.s.castFirst or alert.def.kind ~= "ready" then return false end
	if not alert.s.enabled or not classOK(alert) or not alert.current then return false end
	if targetCasting() ~= true then return false end
	return conditionMet(alert) and spellReady(alert) == true
end

function standsBehind(alert, depth)
	depth = depth or 0
	if depth == 0 and not alert.s.needCasting then
		for _, other in ipairs(alerts) do
			if other ~= alert and other.s.castFirst and ns.castPriority(other) then
				local leads = "," .. ((other.s.behind or ""):gsub("%s+", "")) .. "," .. (other.s.yieldTo or "") .. ","
				if leads:find("," .. alert.key .. ",", 1, true) then return true, other end
			end
		end
	end
	local list = alert.s.behind
	if depth > 3 or type(list) ~= "string" or list == "" then return false end
	for key in list:gmatch("[^,%s]+") do
		local other = alerts[key]
		if other and other ~= alert and claimsPriority(other, depth) then return true, other end
	end
	return false
end

-- Gegenstück zur Lebens-Schwelle des Vorrang-Alarms: sichtbar nur, wenn das
-- Ziel unter der Schwelle liegt.
local function applyLowGate(alert)
	local current = alert.current
	local low = current and current.gated and current.gated.low
	if not low or #low == 0 then return end
	local threshold = current.partner.s.minHealth
	if alert.lowCurve == nil or alert.lowCurveAt ~= threshold then
		local ok, curve = pcall(function()
			local created = C_CurveUtil.CreateCurve()
			created:SetType(Enum.LuaCurveType.Step)
			created:AddPoint(0, 1)
			created:AddPoint(threshold / 100, 0)
			return created
		end)
		alert.lowCurve = ok and curve or false
		alert.lowCurveAt = threshold
	end
	local alpha = 0 -- ohne Kurve bleibt diese Kopie unsichtbar
	-- Gilt die Schwelle des anderen Alarms bei einem Boss nicht ("bossAlways"),
	-- warnt er dort selbst, und diese Kopie bleibt ebenfalls unsichtbar.
	local lifted = current.partner.s.bossAlways and targetIsBoss()
	if not lifted and alert.lowCurve and UnitHealthPercent then
		local ok, value = pcall(UnitHealthPercent, "target", false, alert.lowCurve)
		if ok and value ~= nil then alpha = value end
	end
	for _, visual in ipairs(low) do pcall(visual.SetAlpha, visual, alpha) end
end

-- Ist das Ziel ein Spieler? Verrät das Spiel es nicht, gilt "ifUnknown" (ohne
-- Angabe "ja"). Jede Bedingung fragt so, dass die Anzeige im Zweifel erscheint.
local function targetIsPlayer(ifUnknown)
	if ifUnknown == nil then ifUnknown = true end
	if type(UnitIsPlayer) ~= "function" then return ifUnknown end
	local ok, result = pcall(UnitIsPlayer, "target")
	if not ok then return ifUnknown end
	return plain(result, ifUnknown) and true or false
end

function conditionMet(alert)
	local combat = inCombat()
	if alert.s.combatOnly and not combat then return false end
	if not spellKnown(alert) then return false end
	if alert.s.needUsable and spellUsable(alert) == false then return false end
	if not ns.specAllows(alert) then return false end
	-- Die Aggro-Bedingung gilt nur im Kampf. Außerhalb darf der Alarm ans Nachbuffen erinnern.
	if alert.s.needAggro and combat and hasAggro() == false then return false end
	local ready = alert.def.kind == "ready"
	if alert.def.unit == "target" or (ready and alert.s.needTarget) then
		if not plain(UnitExists("target"), true) then return false end
		if plain(UnitIsDeadOrGhost("target"), false) then return false end
		if not plain(UnitCanAttack("player", "target"), true) then return false end
	end
	-- Nur gegen Spieler: für Zauber, die sich nur im PvP lohnen (Frostschock als Bremse)
	if alert.s.needPlayer and not targetIsPlayer() then return false end
	-- Nicht gegen Spieler: für Zauber, die sich im PvP nicht lohnen (Flammenschock)
	if alert.s.noPlayer and targetIsPlayer(false) then return false end
	if ready and alert.s.needRange and spellInRange(alert) == false then return false end
	if ready and alert.s.needEnemies then
		local enemies = nearbyEnemies(alert.s.enemyRange)
		if enemies ~= nil and enemies < (alert.s.minEnemies or 3) then return false end
	end
	if ready and alert.s.needFireTotem and ns.Totems and ns.Totems.IsActive(1) == false then return false end
	-- Ohne Auskunft des Spiels bliebe der Alarm dauernd stehen, deshalb zählt nur ein klares Ja.
	if ready and alert.s.needCasting and targetCasting() ~= true then return false end
	if alert.def.unit ~= "target" then
		if plain(UnitIsDeadOrGhost("player"), false) then return false end
		-- Außerhalb des Kampfes nicht in Städten, auf dem Reittier oder im Flug nerven
		if not combat then
			if IsResting and plain(IsResting(), false) then return false end
			if IsMounted and plain(IsMounted(), false) then return false end
			if UnitOnTaxi and plain(UnitOnTaxi("player"), false) then return false end
		end
	end
	return true
end

local function updateAlert(alert)
	local visuals = alert.current and alert.current.visuals
	if visuals and #visuals > 0 then
		local kind = alert.def.kind
		-- Hängt die Anzeige an einer Abklingzeit? Immer bei "Zauber bereit",
		-- bei Fehlt-Alarmen auf Wunsch (Flammenschock während der Schock-Abklingzeit).
		local timed = kind == "ready" or (kind == "missing" and alert.s.needReady == true)
		local ready
		if timed then ready = spellReady(alert) end
		-- Mit Vorlaufzeit bleibt die Grafik auch während der Abklingzeit
		-- "eingeblendet"; sichtbar macht sie dann erst die Deckkraft.
		local cooling = timed and ready == false and (alert.s.lead or 0) > 0
		local met = conditionMet(alert)
		local show = met and (kind ~= "weapon" or (alert.weaponMissing == true and not ns.weaponCovered(alert)))
		if kind == "ready" then
			show = show and (ready == true or cooling)
		elseif timed then
			-- Verrät das Spiel die Abklingzeit nicht, warnt der Alarm wie bisher.
			show = show and (ready ~= false or cooling)
		end
		-- Vorrang beim Unterbrechen: Dann gilt für diesen Alarm keine Rangfolge,
		-- außer hinter einem Alarm, der selbst auf den Zauber des Ziels wartet
		-- (dem eigenen Unterbrechen-Alarm, falls er eingeschaltet ist).
		local first = show and ns.castPriority(alert)
		-- Rangfolge: Zeigt ein wichtigerer Alarm gerade etwas, schweigt dieser ganz.
		if show then
			local hidden, by = standsBehind(alert)
			if hidden and not (first and not (by and by.s.needCasting)) then
				show = false
				first = false
			end
		end
		-- Vorrang: Will der andere Alarm etwas zeigen, bleibt nur die Kopie, die
		-- an dessen Aura hängt.
		local wants = false
		if kind == "ready" and show and not first then
			local partner = partnerOf(alert)
			wants = partner ~= nil and partnerWants(partner)
		end
		-- Die Kopien zum frühen Auffrischen erscheinen nur in den letzten Sekunden der Aura.
		local early = alert.current.early
		local due = early ~= nil and refreshDue(alert)
		for _, visual in ipairs(visuals) do visual:SetShown(show and not wants and (due or not (early and early[visual]))) end
		local gated = alert.current.gated
		if gated then
			-- Soll der andere Alarm gerade früh auffrischen, steht dieser auch dann zurück.
			local partnerDue = wants and refreshDue(alert.current.partner)
			for _, visual in ipairs(gated.present) do visual:SetShown(show and wants and not partnerDue) end
			for _, visual in ipairs(gated.low) do visual:SetShown(show and wants) end
			if show and wants then applyLowGate(alert) end
		end
		setLeadAlpha(alert, show and cooling)
		alert.cooling = show and cooling
		if kind == "ready" then
			-- Sound in dem Moment, in dem der Zauber wirklich bereit ist
			local isReady = met and ready == true
			local now = GetTime and GetTime() or 0
			if isReady and alert.readyShown == false and alert.s.sound == "added" and now - (alert.readySoundAt or 0) > 1 then
				alert.readySoundAt = now
				playAlertSound(alert)
			end
			alert.readyShown = isReady
		end
		if show then applyHealthGate(alert) end
		-- Die Restzeit folgt derselben Bedingung wie die Grafik.
		local timers = alert.current.timers
		if timers and alert.current.timersShown ~= show then
			alert.current.timersShown = show
			pcall(timers.SetEnabled, timers, show)
			pcall(show and timers.Show or timers.Hide, timers)
		end
	end
end

-- Jeder Alarm für sich: Ein Fehler bei einem darf die übrigen nicht anhalten.
-- Er wird einmal gemeldet und steht danach in /sha status und /sha debug.
local function updateConditions()
	if state.hotkeysDirty then
		state.hotkeysDirty = nil
		pcall(ns.refreshHotkeys)
	end
	updateWeaponState()
	for _, alert in ipairs(alerts) do
		local ok, err = pcall(updateAlert, alert)
		if not ok and alert.runError == nil then
			alert.runError = tostring(err)
			msg(L["Error in \"%s\". Please record /sha debug. Reason: %s"], alert.def.title, alert.runError:sub(1, 200))
		end
	end
end

-- Gemeinsame Lage: Ein Alarm kann Lage und Größe mit einem anderen teilen
-- ("placeLike" nennt dessen Schlüssel). So stehen alle Schocks an derselben
-- Stelle und es wechselt nur das Bild. Die Werte liegen bei jedem Alarm
-- gespeichert; wird einer geändert, übernehmen ihn die übrigen der Gruppe.
local PLACE_KEYS = { "layout", "count", "distance", "spread", "size", "x", "y" }

-- Der Alarm, dessen Lage dieser teilt, oder nil.
local function placeLeader(alert)
	local key = alert.s.placeLike
	if type(key) ~= "string" or key == "" or key == alert.key then return nil end
	local leader = alerts[key]
	-- Ketten gibt es nicht: Wer selbst einem anderen folgt, gibt keine Lage vor.
	if not leader or (leader.s.placeLike or "") ~= "" then return nil end
	return leader
end

-- Alle Alarme, die ihre Lage mit diesem teilen (ohne ihn selbst), und der
-- Alarm, der die Gruppe anführt. Steht der Alarm für sich: leere Liste, nil.
local function placeMates(alert)
	local leader = placeLeader(alert)
	local mates = {}
	if not leader then
		for _, other in ipairs(alerts) do
			if other ~= alert and placeLeader(other) == alert then leader = alert end
		end
		if not leader then return mates, nil end
	end
	for _, other in ipairs(alerts) do
		if other ~= alert and (other == leader or placeLeader(other) == leader) then mates[#mates + 1] = other end
	end
	return mates, leader
end

-- Der Stand, auf den sich die Gruppe geeinigt hat. Beim ersten Mal zählt der
-- Alarm, der sie anführt.
local function sharedPlacement(leader)
	state.placement = state.placement or {}
	local shared = state.placement[leader.key]
	if not shared then
		shared = {}
		for _, key in ipairs(PLACE_KEYS) do shared[key] = leader.s[key] end
		state.placement[leader.key] = shared
	end
	return shared
end

-- Übernimmt die Lage der Gruppe, etwa beim Laden oder wenn ein Alarm dazukommt.
local function joinPlacement(alert)
	local leader = placeLeader(alert)
	if not leader then return false end
	local shared = sharedPlacement(leader)
	for _, key in ipairs(PLACE_KEYS) do alert.s[key] = shared[key] end
	return true
end

-- Vor jedem Aufbau: Weicht dieser Alarm vom Stand der Gruppe ab, wurde er
-- gerade geändert. Dann gilt sein Wert für alle, und die übrigen bauen neu.
local function sharePlacement(alert)
	local mates, leader = placeMates(alert)
	if not leader then return end
	local shared = sharedPlacement(leader)
	local differs = false
	for _, key in ipairs(PLACE_KEYS) do
		if alert.s[key] ~= shared[key] then
			shared[key] = alert.s[key]
			differs = true
		end
	end
	if not differs then return end
	for _, other in ipairs(mates) do
		for _, key in ipairs(PLACE_KEYS) do other.s[key] = shared[key] end
	end
	for _, other in ipairs(mates) do
		other.buildToken = (other.buildToken or 0) + 1 -- ein noch wartender Aufbau wäre doppelt
		other.buildScheduled = false
		Build(other)
	end
end

-- Alarme, die hinter diesem zurückstehen, hängen an dessen Aura-Filter und
-- Lebens-Schwelle und müssen deshalb mit ihm neu aufgebaut werden.
local function rebuildDependents(alert)
	if state.rebuildingDependents then return end
	state.rebuildingDependents = true
	for _, other in ipairs(alerts) do
		if other ~= alert and other.def.kind == "ready" and other.s.yieldTo == alert.key and other.s.enabled then Build(other) end
	end
	state.rebuildingDependents = false
end

function Build(alert)
	sharePlacement(alert)
	if inCombat() then
		alert.pendingBuild = true
		return false
	end
	alert.pendingBuild = false
	disableCurrent(alert)
	alert.initError = nil
	alert.runError = nil
	if not alert.s.enabled or not classOK(alert) then
		rebuildDependents(alert)
		return true
	end
	local kind = alert.def.kind
	alert.readyShown = nil
	alert.cooling = false
	if not PLAIN_KINDS[kind] then
		-- Ohne bekannte Aura-ID würde der Filter jede Aura durchlassen.
		if next(alert.s.spellIDs) == nil then
			alert.initError = L["no aura ID known yet"]
			return false
		end
		if not ensureContainerSupport() then return false end
	end

	local ok, err = pcall(kind == "ready" and buildReady or kind == "weapon" and buildPlain or kind == "stacks" and buildStacks or buildPresence, alert)
	if not ok then
		alert.initError = tostring(err)
		disableCurrent(alert)
		return false
	end
	updateConditions()
	rebuildDependents(alert)
	return true
end

-- Während eine Abklingzeit läuft, muss die Vorlauf-Deckkraft laufend neu
-- ausgewertet werden, sonst käme der Wechsel zu spät.
local leadDriver = CreateFrame("Frame")
local leadElapsed = 0
leadDriver:SetScript("OnUpdate", function(_, elapsed)
	leadElapsed = leadElapsed + (elapsed or 0)
	if leadElapsed < 0.03 then return end
	leadElapsed = 0
	for _, alert in ipairs(alerts) do
		if alert.cooling and alert.current then setLeadAlpha(alert, true) end
	end
end)

-- Für Schieberegler: erst neu aufbauen, wenn kurz nichts mehr geändert wurde.
-- Jeder Aufbau legt neue Frames an, deshalb nicht bei jedem Zwischenwert.
local function scheduleBuild(alert)
	alert.buildToken = (alert.buildToken or 0) + 1
	alert.buildScheduled = true
	local token = alert.buildToken
	C_Timer.After(0.3, function()
		if token == alert.buildToken then
			alert.buildScheduled = false
			Build(alert)
		end
	end)
end

-- Sofort aufbauen und einen noch wartenden Aufbau verwerfen.
local function flushBuild(alert)
	alert.buildToken = (alert.buildToken or 0) + 1
	alert.buildScheduled = false
	return Build(alert)
end

-- Nur aufbauen, wo noch eine Änderung wartet.
local function flushScheduledBuilds()
	for _, alert in ipairs(alerts) do
		if alert.buildScheduled then flushBuild(alert) end
	end
end

-------------------------------------------------------------------------------
-- Ereignisse
-------------------------------------------------------------------------------

local function onAuraChanged()
	if not aurasRestricted() then learnSpellIDs() end
	for _, alert in ipairs(alerts) do
		if alert.def.kind == "stacks" then
			local stacks = readStacks(alert)
			local settings = alert.s
			if stacks and alert.lastStacks and settings.enabled and classOK(alert) and settings.sound == "threshold" then
				if stacks >= settings.threshold and alert.lastStacks < settings.threshold then playAlertSound(alert) end
			end
			alert.lastStacks = stacks
			-- Notfall-Anzeige, falls der Client keinen AuraContainer hat.
			if state.containerOK == false and settings.enabled and classOK(alert) and state.moving ~= alert and not alert.testing then
				local show = stacks ~= nil and stacks >= settings.threshold
				if show then applyPreview(alert) end
				getPreview(alert):SetShown(show)
			end
		end
	end
end

-- Container, die am Ziel hängen, nach einem Zielwechsel neu einlesen.
local function onTargetChanged()
	state.targetBoss, state.bossAt = nil, nil -- ob das neue Ziel ein Boss ist, wird neu gefragt
	for _, alert in ipairs(alerts) do
		-- Ohne Kennung des Ziels gilt die Uhr nur, bis das Ziel wechselt.
		if alert.castTarget == false then alert.castAt = nil end
		local current = alert.current
		if current and (current.unit or alert.def.unit) == "target" then
			for _, container in ipairs(current.containers) do
				pcall(container.SetUnit, container, "target")
				pcall(container.UpdateAllAuras, container)
			end
		end
	end
	updateConditions()
end

-- Version 2.2 hatte andere Voreinstellungen und nur selbst erzeugte Texturen.
-- Wer diese Werte nie geändert hat, bekommt die neuen samt gemalter Grafik.
local OLD_DEFAULTS = {
	maelstrom = { size = 80, x = 0, texture = "lightning_orb" },
	flameshock = { size = 96, x = 0, texture = "flame" },
	shield = { size = 96, x = -55, texture = "lightning_shield" },
	weapon = { size = 80, x = 55, texture = "aura19" },
}

local function migrateSettings(def, stored)
	local old = OLD_DEFAULTS[def.key]
	if type(stored) ~= "table" or stored.display ~= nil or stored.layout == nil or not old then return end
	if stored.size == old.size then stored.size = def.defaults.size end
	if stored.texture == old.texture then stored.texture = def.defaults.texture end
	if stored.x == old.x then stored.x = def.defaults.x end
	if stored.distance == 190 then stored.distance = def.defaults.distance end
	if stored.spread == 32 then stored.spread = def.defaults.spread end
end

-- Voreingestellte Grafiken, die später durch eine bessere ersetzt wurden. Wer
-- die alte nie geändert hat, bekommt einmalig die neue; die Kennzahl
-- "textureRevision" in den Voreinstellungen verhindert eine Wiederholung.
local REPLACED_TEXTURES = {
	maelstrom = { revision = 1, old = { art_chain_lightning = true } },
	flameshock = { revision = 3, old = { art_flame = true, art_fire_shock_comet = true, wow_flame_shock_bolt = true } },
	shield = { revision = 1, old = { art_lightning_shield = true } },
	weapon = { revision = 1, old = { art_windfury_weapon = true } },
	stormstrike = { revision = 2, old = { art_stormstrike = true, art_storm_strike_blade = true } },
	earthshock = { revision = 4, old = { art_earth_shock = true, art_earth_shock_crack = true, art_shock_zap = true, wow_earth_shock_strike = true } },
	firenova = { revision = 2, old = { wow_firenova_ring = true } },
	clearcast = { revision = 2, old = { art_clearcast_orb = true, wow_clearcast_orb = true } },
	flurry = { revision = 1, old = { art_flurry_slashes = true } },
	bloodfury = { revision = 1, old = { art_blood_fury_fist = true } },
	berserking = { revision = 1, old = { art_berserking_troll = true } },
}

local function upgradeSettings(def, stored)
	if type(stored) ~= "table" then return end
	-- Bis 2.46 galt beim Schild-Alarm jedes Schild. Seit 2.47 heißt er
	-- "Blitzschlagschild fehlt"; Wasserschild und Erdschild zählen dort nicht mehr.
	if def.key == "shield" and stored.shieldRevision == nil and type(stored.spellIDs) == "table" then
		for _, id in ipairs({ 408510, 52127, 974 }) do stored.spellIDs[id] = nil end
	end
	local replaced = REPLACED_TEXTURES[def.key]
	if replaced and (tonumber(stored.textureRevision) or 0) < replaced.revision then
		if replaced.old[stored.texture] then stored.texture = def.defaults.texture end
		stored.textureRevision = replaced.revision
	end
	-- Seit 2.24 gibt es nur noch die gemalten Grafiken. Wer eine der entfernten
	-- gewählt hatte, bekommt die Voreinstellung. Ein eigener Dateipfad bleibt.
	local texture = stored.texture
	if type(texture) == "string" and TEXTURES[texture] == nil and not texture:find("[\\/]") then
		stored.texture = def.defaults.texture
	end
	-- 2.39 legte "Unterbrechen" an die Stelle der Schocks. Seit 2.40 steht er
	-- wieder für sich, an seinem Platz über dem Charakter.
	if def.key == "interrupt" and stored.placeRevision == nil and stored.placeLike == "earthshock" then
		stored.placeLike = ""
		for _, key in ipairs(PLACE_KEYS) do stored[key] = def.defaults[key] end
	end
	-- Die Vorlaufzeit stand anfangs auf einer halben Sekunde; gewünscht ist eine ganze.
	if stored.leadRevision == nil and stored.lead == 0.5 then stored.lead = def.defaults.lead end
end

local function initSettings(def, stored)
	local settings = type(stored) == "table" and stored or {}
	for key, value in pairs(def.defaults) do
		if settings[key] == nil or (type(settings[key]) ~= type(value) and key ~= "soundFile" and key ~= "texture") then
			settings[key] = type(value) == "table" and copyTable(value) or value
		end
	end
	if type(settings.color) ~= "table" or #settings.color < 3 then settings.color = copyTable(def.defaults.color) end
	if type(settings.iconBorderColor) ~= "table" or #settings.iconBorderColor < 3 then settings.iconBorderColor = copyTable(def.defaults.iconBorderColor) end
	if settings.display ~= "icon" and settings.display ~= "texture" then settings.display = def.defaults.display end
	if next(settings.spellIDs) == nil then settings.spellIDs = copyTable(def.defaults.spellIDs) end
	if def.custom then settings.sound = settings.sound or "off" end
	return settings
end

-- Stellt die Liste der Alarme zusammen: erst die eingebauten, dann die eigenen.
-- Bestehende Alarm-Objekte bleiben erhalten, damit ihre Anzeige weiterläuft.
local function rebuildAlertList()
	local byKey = {}
	for index = #alerts, 1, -1 do
		byKey[alerts[index].key] = alerts[index]
		alerts[index] = nil
	end
	for key in pairs(alerts) do alerts[key] = nil end
	local function add(def)
		migrateSettings(def, db.alerts[def.key])
		upgradeSettings(def, db.alerts[def.key])
		db.alerts[def.key] = initSettings(def, db.alerts[def.key])
		local alert = byKey[def.key] or { key = def.key, soundRegs = {} }
		alert.def = def
		alert.s = db.alerts[def.key]
		alerts[#alerts + 1] = alert
		alerts[def.key] = alert
	end
	for _, def in ipairs(ALERT_DEFS) do add(def) end
	for _, spec in ipairs(db.custom) do add(customDef(spec)) end
	-- Wer seine Lage mit einem anderen teilt, steht von Anfang an dort.
	for _, alert in ipairs(alerts) do joinPlacement(alert) end
end

local function initDB()
	ShamanAlertsDB = type(ShamanAlertsDB) == "table" and ShamanAlertsDB or {}
	db = ShamanAlertsDB
	db.alerts = type(db.alerts) == "table" and db.alerts or {}
	db.custom = type(db.custom) == "table" and db.custom or {}
	db.font = type(db.font) == "table" and db.font or {}
	if type(db.font.face) ~= "string" or db.font.face == "" then db.font.face = "auto" end
	if not OUTLINE_NAMES[db.font.outline] then db.font.outline = "outline" end
	if type(db.font.timerSize) ~= "number" then db.font.timerSize = 14 end
	if type(db.hotkeys) ~= "boolean" then db.hotkeys = false end -- Taste unter den Grafiken zeigen
	-- Unvollständige Einträge würden den Aufbau stören.
	for index = #db.custom, 1, -1 do
		local spec = db.custom[index]
		local valid = type(spec) == "table" and type(spec.key) == "string" and KIND_NAMES[spec.kind] and spec.kind ~= "weapon"
			and (spec.unit == "player" or spec.unit == "target")
		if valid then
			if type(spec.title) ~= "string" or spec.title == "" then spec.title = spec.key end
		else
			table.remove(db.custom, index)
		end
	end
	-- Einstellungen und Profile aus der Zeit vor 2.48 kennen keine Beschränkung auf
	-- Spezialisierungen. Sie bleiben ohne, auch wo die Voreinstellung heute eine nennt.
	if db.specsRevision == nil then
		local function keep(list)
			if type(list) ~= "table" then return end
			for _, stored in pairs(list) do
				if type(stored) == "table" and stored.specs == nil then stored.specs = "" end
			end
		end
		keep(db.alerts)
		if type(db.profiles) == "table" then
			for _, profile in pairs(db.profiles) do
				if type(profile) == "table" then keep(profile.alerts) end
			end
		end
		db.specsRevision = 1
	end
	state.placement = nil -- die gemeinsame Lage richtet sich nach den geladenen Werten
	rebuildAlertList()
	ns.db = db
end

local events = CreateFrame("Frame")
local CAST_EVENTS = {
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}
local IS_CAST_EVENT = {}
for _, name in ipairs(CAST_EVENTS) do IS_CAST_EVENT[name] = true end

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, arg1, _, arg3)
	if event == "PLAYER_LOGIN" then
		state.loginAt = GetTime and GetTime() or 0
		initDB()
		if ns.Minimap then pcall(ns.Minimap.Init) end
		-- Auf anderen Klassen bleibt das Addon still.
		local _, class = UnitClass("player")
		state.class = class
		loadRangeItems()
		state.isShaman = class == "SHAMAN"
		self:RegisterEvent("SPELLS_CHANGED")
		self:RegisterEvent("WEAPON_ENCHANT_CHANGED")
		self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
		self:RegisterUnitEvent("UNIT_AURA", "player", "target")
		self:RegisterUnitEvent("UNIT_FACTION", "target")
		self:RegisterUnitEvent("UNIT_HEALTH", "target")
		self:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", "player")
		pcall(self.RegisterUnitEvent, self, "UNIT_POWER_UPDATE", "player") -- für die Mana-Schwelle
		-- Talente geändert: für die Beschränkung auf eine Spezialisierung
		for _, name in ipairs({ "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "ACTIVE_COMBAT_CONFIG_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED" }) do
			pcall(self.RegisterEvent, self, name)
		end
		-- Zauber des Ziels: für den Unterbrechen-Alarm ohne Verzögerung
		for _, name in ipairs(CAST_EVENTS) do pcall(self.RegisterUnitEvent, self, name, "target") end
		pcall(self.RegisterUnitEvent, self, "UNIT_SPELLCAST_SUCCEEDED", "player") -- startet die Uhr zum frühen Auffrischen
		self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		self:RegisterEvent("SPELL_UPDATE_USABLE")
		self:RegisterEvent("PLAYER_TARGET_CHANGED")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		for _, alert in ipairs(alerts) do
			Build(alert)
			if alert.initError and alert.initError ~= L["no aura ID known yet"] then
				msg(L["\"%s\" could not be built. Please record /sha debug. Reason: %s"], alert.def.title, alert.initError:sub(1, 160))
			end
		end
		updateEngineSounds()
		if ns.Totems then ns.Totems.Init(db) end
		-- Ob das Ziel noch lebt und angreifbar ist, meldet kein einzelnes Ereignis
		-- zuverlässig. Auch das Ende einer Abklingzeit meldet das Spiel nicht.
		if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(0.15, updateConditions) end
	elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
		for _, alert in ipairs(alerts) do
			if alert.pendingBuild or (state.containerOK == nil and alert.s.enabled and not alert.current and not PLAIN_KINDS[alert.def.kind]) then Build(alert) end
		end
		if state.pendingSounds then updateEngineSounds() end
		if event == "PLAYER_ENTERING_WORLD" then pcall(ns.applyTalentDurations) end
		updateConditions()
		onAuraChanged()
	elseif event == "PLAYER_REGEN_DISABLED" or event == "UNIT_FACTION" or event == "WEAPON_ENCHANT_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"
		or event == "UNIT_THREAT_SITUATION_UPDATE" or event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_USABLE" or IS_CAST_EVENT[event] then
		updateConditions()
	elseif event == "SPELLS_CHANGED" then
		-- Neuer Zauber oder Rang gelernt: "bekannt" neu prüfen und die ID nachtragen
		for _, alert in ipairs(alerts) do alert.known, alert.readySpell = nil, nil end
		state.rangeSpells = nil
		state.spec = nil
		pcall(ns.applyTalentDurations)
		state.lastScan = 0
		onAuraChanged()
		updateConditions()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if arg1 == "player" then
			noteCast(arg3)
			updateConditions()
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		onTargetChanged()
	elseif event == "UNIT_HEALTH" then
		-- häufiges Ereignis: nur die Lebens-Schwelle nachführen
		for _, alert in ipairs(alerts) do
			if alert.def.unit == "target" and alert.s.minHealth > 0 then applyHealthGate(alert) end
			applyLowGate(alert)
		end
	elseif event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_COMBAT_CONFIG_CHANGED" or event == "TRAIT_TREE_CURRENCY_INFO_UPDATED" then
		-- Talente geändert: Spezialisierung neu lesen
		state.spec = nil
		pcall(ns.applyTalentDurations)
		updateConditions()
		if ns.RefreshOptions then pcall(ns.RefreshOptions) end
	elseif event == "UNIT_POWER_UPDATE" then
		-- häufiges Ereignis: nur die Mana-Schwelle nachführen
		for _, alert in ipairs(alerts) do
			if (alert.s.maxMana or 0) > 0 and alert.current then applyHealthGate(alert) end
		end
	elseif event == "UNIT_AURA" then
		onAuraChanged()
	end
end)

-------------------------------------------------------------------------------
-- Einstellungen ändern (von Befehlen und vom Optionsfenster genutzt)
-------------------------------------------------------------------------------

local function toNumber(text)
	if type(text) ~= "string" then return nil end
	return tonumber((text:gsub(",", ".")))
end

local function toBoolean(text, current)
	text = (text or ""):lower()
	if text == "on" or text == "an" or text == "1" or text == "ja" then return true end
	if text == "off" or text == "aus" or text == "0" or text == "nein" then return false end
	return not current
end

local SOUND_WORDS = {
	off = "off", aus = "off",
	threshold = "threshold", schwelle = "threshold",
	stack = "stack", stapel = "stack",
	removed = "removed", ende = "removed",
	added = "added", start = "added",
}

-- Welche Sound-Modi ein Alarm kennt
local function soundModes(alert)
	local kind = alert.def.kind
	if kind == "stacks" then return { "off", "threshold", "stack" } end
	if kind == "active" then return { "off", "added", "removed" } end
	if kind == "ready" then return { "off", "added" } end
	return { "off", "removed" }
end

local function setSoundMode(alert, mode)
	alert.s.sound = mode
	alert.lastStacks = nil
	updateEngineSounds()
end

local function setSoundFile(alert, file)
	alert.s.soundFile = file
	updateEngineSounds()
	playAlertSound(alert)
end

local function numberField(key, minimum, maximum, integer)
	return function(alert, text)
		local value = toNumber(text)
		if not value or value < minimum or value > maximum then
			return false, (L["Please enter a number from %s to %s."]):format(minimum, maximum)
		end
		alert.s[key] = integer and math.floor(value + 0.5) or value
		return true
	end
end

local function booleanField(key)
	return function(alert, text)
		alert.s[key] = toBoolean(text, alert.s[key])
		return true
	end
end

-- Feldname im Befehl -> Funktion, die den Wert prüft und setzt
local FIELDS = {
	enabled = booleanField("enabled"),
	threshold = numberField("threshold", 1, 20, true),
	size = numberField("size", 16, 1000, true),
	x = numberField("x", -4000, 4000, true),
	y = numberField("y", -4000, 4000, true),
	alpha = numberField("alpha", 0.05, 1, false),
	pulse = booleanField("pulse"),
	additive = booleanField("additive"),
	icon = booleanField("icon"),
	combatonly = booleanField("combatOnly"),
	offhand = booleanField("offhand"),
	mainimbue = function(alert, text) return ns.setImbue(alert, "mainImbue", text) end,
	offimbue = function(alert, text) return ns.setImbue(alert, "offImbue", text) end,
	timer = booleanField("timer"),
	needusable = booleanField("needUsable"),
	needaggro = booleanField("needAggro"),
	needplayer = function(alert, text)
		alert.s.needPlayer = toBoolean(text, alert.s.needPlayer)
		if alert.s.needPlayer then alert.s.noPlayer = false end -- beides zugleich ginge nie auf
		return true
	end,
	noplayer = function(alert, text)
		alert.s.noPlayer = toBoolean(text, alert.s.noPlayer)
		if alert.s.noPlayer then alert.s.needPlayer = false end
		return true
	end,
	placelike = function(alert, text)
		local wanted = text:lower():gsub("%s+", "")
		if wanted == "" or wanted == "none" or wanted == "kein" or wanted == "keiner" or wanted == "keinem" then
			alert.s.placeLike = ""
			return true
		end
		local leader = alerts[wanted]
		if not leader or leader == alert then return false, L["Please enter the key of another alert (for example earthshock), or none."] end
		if (leader.s.placeLike or "") ~= "" then
			return false, (L["\"%s\" itself shares its place with \"%s\". Please enter that key."]):format(leader.def.title, leader.s.placeLike)
		end
		for _, other in ipairs(alerts) do
			if other ~= alert and other.s.placeLike == alert.key then
				return false, (L["That does not work while \"%s\" shares its place with this alert."]):format(other.def.title)
			end
		end
		alert.s.placeLike = leader.key
		joinPlacement(alert)
		return true
	end,
	needtarget = booleanField("needTarget"),
	needrange = booleanField("needRange"),
	needenemies = function(alert, text)
		if alert.def.kind ~= "ready" then return false, L["This exists for \"spell ready\" alerts only."] end
		alert.s.needEnemies = toBoolean(text, alert.s.needEnemies)
		return true
	end,
	minenemies = numberField("minEnemies", 2, 10, true),
	needfiretotem = function(alert, text)
		if alert.def.kind ~= "ready" then return false, L["This exists for \"spell ready\" alerts only."] end
		alert.s.needFireTotem = toBoolean(text, alert.s.needFireTotem)
		return true
	end,
	needcasting = function(alert, text)
		if alert.def.kind ~= "ready" then return false, L["This exists for \"spell ready\" alerts only."] end
		alert.s.needCasting = toBoolean(text, alert.s.needCasting)
		return true
	end,
	castfirst = function(alert, text)
		if alert.def.kind ~= "ready" then return false, L["This exists for \"spell ready\" alerts only."] end
		alert.s.castFirst = toBoolean(text, alert.s.castFirst)
		return true
	end,
	enemyrange = function(alert, text)
		local yards = toNumber(text)
		if not (yards and RANGE_ITEMS[yards]) then return false, L["Allowed: 5, 10 or 20 (yards)."] end
		alert.s.enemyRange = yards
		return true
	end,
	needready = function(alert, text)
		if alert.def.kind ~= "missing" then return false, L["This exists for \"missing\" alerts only. \"Spell ready\" alerts always watch the cooldown."] end
		alert.s.needReady = toBoolean(text, alert.s.needReady)
		return true
	end,
	lead = numberField("lead", 0, 5, false),
	refresh = function(alert, text)
		if alert.def.kind ~= "missing" then return false, L["Early refresh exists for \"missing\" alerts only."] end
		local value = toNumber(text)
		if not value or value < 0 or value > 10 then return false, L["Please enter a number from 0 to 10 (seconds, 0 switches it off)."] end
		alert.s.refresh = math.floor(value * 10 + 0.5) / 10
		return true
	end,
	behind = function(alert, text)
		local wanted = text:lower():gsub("%s+", "")
		if wanted == "" or wanted == "none" or wanted == "kein" or wanted == "keiner" or wanted == "keinem" then
			alert.s.behind = ""
			return true
		end
		local keys = {}
		for key in wanted:gmatch("[^,]+") do
			local other = alerts[key]
			if not other then return false, (L["There is no alert \"%s\". Please enter keys like interrupt,frostshock, or none."]):format(key) end
			if other == alert then return false, L["An alert cannot stand behind itself."] end
			if other.def.kind ~= "missing" and not PLAIN_KINDS[other.def.kind] then
				return false, (L["That does not work behind \"%s\": stack and active alerts are drawn by the game itself."]):format(other.def.title)
			end
			keys[#keys + 1] = key
		end
		alert.s.behind = table.concat(keys, ",")
		return true
	end,
	duration = function(alert, text)
		if alert.def.kind ~= "missing" then return false, L["Only a \"missing\" alert needs the aura duration, for the early refresh."] end
		local value = toNumber(text)
		if not value or value < 0 or value > 3600 then return false, L["Please enter a number from 0 to 3600 (seconds)."] end
		alert.s.auraDuration = math.floor(value * 10 + 0.5) / 10
		return true
	end,
	yieldto = function(alert, text)
		if alert.def.kind ~= "ready" then return false, L["Priority exists for \"spell ready\" alerts only."] end
		local wanted = text:lower()
		if wanted == "" or wanted == "none" or wanted == "kein" or wanted == "keiner" then
			alert.s.yieldTo = ""
			return true
		end
		local partner = alerts[wanted]
		if not partner or partner == alert or (partner.def.kind ~= "missing" and not PLAIN_KINDS[partner.def.kind]) then
			return false, L["Please enter the key of a missing, weapon or spell-ready alert, or none."]
		end
		alert.s.yieldTo = partner.key
		return true
	end,
	minhealth = numberField("minHealth", 0, 95, true),
	maxmana = function(alert, text)
		if alert.def.unit ~= "player" or (alert.def.kind ~= "ready" and alert.def.kind ~= "missing") then
			return false, L["The mana threshold exists for spell-ready and missing alerts on yourself only."]
		end
		local value = toNumber(text)
		if not value or value < 0 or value > 100 then return false, (L["Please enter a number from %s to %s."]):format(0, 100) end
		alert.s.maxMana = math.floor(value + 0.5)
		return true
	end,
	specs = function(alert, text)
		if alert.def.kind == "stacks" then return false, L["Stack alerts cannot be limited to a specialization."] end
		local lowered = text:lower()
		if lowered == "" or lowered == "all" or lowered == "alle" then
			alert.s.specs = ""
			return true
		end
		local chosen, count = {}, 0
		for word in lowered:gmatch("[^,%s]+") do
			local match
			for _, spec in ipairs(ns.SPECS) do
				if #word >= 3 and spec:sub(1, #word) == word then match = spec end
			end
			if not match then return false, L["Please enter all, or one or more of: elemental, enhancement, restoration."] end
			if not chosen[match] then chosen[match] = true; count = count + 1 end
		end
		if count == 0 then return false, L["Please enter all, or one or more of: elemental, enhancement, restoration."] end
		local list = {}
		for _, spec in ipairs(ns.SPECS) do
			if chosen[spec] then list[#list + 1] = spec end
		end
		alert.s.specs = count == #ns.SPECS and "" or table.concat(list, ",")
		return true
	end,
	bossalways = function(alert, text)
		if alert.def.unit ~= "target" then return false, L["This exists for alerts on the target only."] end
		alert.s.bossAlways = toBoolean(text, alert.s.bossAlways)
		return true
	end,
	title = function(alert, text)
		if not alert.def.custom then return false, L["Only your own alerts can be renamed."] end
		if text == "" then return false, L["Please enter a title."] end
		alert.def.spec.title, alert.def.title = text, text
		if alert.preview then alert.preview.label:SetText(text .. L[": drag to move"]) end
		return true
	end,
	kind = function(alert, text)
		if not alert.def.custom then return false, L["The kind can only be changed for your own alerts."] end
		local wanted = text:lower()
		for _, kind in ipairs(CUSTOM_KINDS) do
			if kind == wanted or KIND_NAMES[kind]:lower() == wanted then
				alert.def.spec.kind, alert.def.kind = kind, kind
				local allowed = false
				for _, mode in ipairs(soundModes(alert)) do allowed = allowed or mode == alert.s.sound end
				if not allowed then alert.s.sound = "off" end
				alert.known, alert.readySpell = nil, nil
				if kind == "ready" then
					-- "Zauber bereit" hängt am Spieler, nicht an einer Aura auf dem Ziel.
					alert.def.spec.unit, alert.def.unit = "player", "player"
				end
				return true
			end
		end
		return false, L["Allowed: active (is active), missing (is missing), stacks (from X stacks), ready (spell ready)."]
	end,
	unit = function(alert, text)
		if not alert.def.custom then return false, L["The unit can only be changed for your own alerts."] end
		local wanted = text:lower()
		if wanted == "spieler" then wanted = "player" elseif wanted == "ziel" then wanted = "target" end
		if wanted ~= "player" and wanted ~= "target" then return false, L["Allowed: player or target."] end
		alert.def.spec.unit, alert.def.unit = wanted, wanted
		return true
	end,
	auratype = function(alert, text)
		if not alert.def.custom then return false, L["The aura type can only be changed for your own alerts."] end
		local wanted = text:lower()
		local spec = alert.def.spec
		if wanted == "buff" then
			spec.harmful, spec.mine = false, false
		elseif wanted == "debuff" then
			spec.harmful, spec.mine = true, false
		elseif wanted == "mine" or wanted == "eigener" or wanted == "eigener debuff" then
			spec.harmful, spec.mine = true, true
		else
			return false, L["Allowed: buff, debuff or mine (your own debuff only)."]
		end
		alert.def.filter = customFilter(spec)
		return true
	end,
	iconzoom = numberField("iconZoom", 0, 40, true),
	iconborder = numberField("iconBorder", 0, 8, true),
	display = function(alert, text)
		local wanted = text:lower()
		if wanted == "symbol" or wanted == "zaubersymbol" then wanted = "icon" elseif wanted == "textur" then wanted = "texture" end
		if wanted ~= "icon" and wanted ~= "texture" then return false, L["Allowed: icon (spell icon) or texture (picture)."] end
		alert.s.display = wanted
		return true
	end,
	iconspell = function(alert, text)
		alert.s.iconSpell = text:lower() == "auto" and "" or text
		return true
	end,
	bordercolor = function(alert, text)
		local r, g, b = text:match("^(%S+)%s+(%S+)%s+(%S+)$")
		r, g, b = toNumber(r), toNumber(g), toNumber(b)
		if not (r and g and b) then return false, L["Example: bordercolor 0 0 0."] end
		if r > 1 or g > 1 or b > 1 then r, g, b = r / 255, g / 255, b / 255 end
		alert.s.iconBorderColor = { math.min(1, math.max(0, r)), math.min(1, math.max(0, g)), math.min(1, math.max(0, b)) }
		return true
	end,
	count = numberField("count", 1, 8, true),
	distance = numberField("distance", 0, 1000, true),
	spread = numberField("spread", 5, 120, true),
	rotate = booleanField("rotate"),
	angle = numberField("angle", 0, 359, true),
	flip = booleanField("flip"),
	perstack = booleanField("perStack"),
	layout = function(alert, text)
		local wanted = text:lower()
		for _, layout in ipairs(LAYOUTS) do
			if layout.key == wanted or layout.name:lower() == wanted then
				alert.s.layout = layout.key
				return true
			end
		end
		local keys = {}
		for _, layout in ipairs(LAYOUTS) do keys[#keys + 1] = layout.key end
		return false, L["Allowed: "] .. table.concat(keys, ", ") .. "."
	end,
	texture = function(alert, text)
		if text == "" then return false, L["Please enter a texture name or a path."] end
		alert.s.texture = TEXTURES[text:lower()] and text:lower() or text
		return true
	end,
	color = function(alert, text)
		local r, g, b = text:match("^(%S+)%s+(%S+)%s+(%S+)$")
		r, g, b = toNumber(r), toNumber(g), toNumber(b)
		if not (r and g and b) then return false, L["Example: color 115 204 255."] end
		if r > 1 or g > 1 or b > 1 then r, g, b = r / 255, g / 255, b / 255 end
		alert.s.color = { math.min(1, math.max(0, r)), math.min(1, math.max(0, g)), math.min(1, math.max(0, b)) }
		return true
	end,
	sound = function(alert, text)
		local mode = SOUND_WORDS[text:lower()]
		local allowed = false
		for _, known in ipairs(soundModes(alert)) do allowed = allowed or known == mode end
		if not allowed then return false, L["Allowed: "] .. table.concat(soundModes(alert), ", ") .. "." end
		setSoundMode(alert, mode)
		return true
	end,
	soundfile = function(alert, text)
		if text == "" then return false, L["Please enter a path, a file ID or default."] end
		setSoundFile(alert, text:lower() == "default" and alert.def.defaults.soundFile or tonumber(text) or text)
		return true
	end,
	name = function(alert, text)
		if text == "" then return false, L["Please enter an aura name."] end
		alert.s.auraName = text
		alert.known, alert.readySpell = nil, nil
		state.lastScan = 0
		return true
	end,
}

local function afterChange(alert)
	alert.lastStacks = nil
	if state.moving == alert then applyPreview(alert) end
	updateEngineSounds()
	if ns.RefreshOptions then ns.RefreshOptions(true) end
	return flushBuild(alert)
end

local function resetAlert(alert)
	local settings = alert.s
	local shared = placeLeader(alert) ~= nil
	for key in pairs(settings) do settings[key] = nil end
	initSettings(alert.def, settings)
	-- Teilte der Alarm seine Lage schon, setzt er sie für die ganze Gruppe
	-- zurück. Kommt er erst durch das Zurücksetzen wieder dazu, übernimmt er ihre.
	if not shared then joinPlacement(alert) end
end

-- Legt einen eigenen Alarm an. Er erscheint erst, wenn eine Aura-ID bekannt ist.
local function createCustomAlert(title)
	local number = 1
	while db.alerts["custom" .. number] or alerts["custom" .. number] do number = number + 1 end
	local key = "custom" .. number
	if type(title) ~= "string" or title == "" then title = L["Custom alert "] .. number end
	table.insert(db.custom, { key = key, title = title, kind = "active", unit = "player", harmful = false, mine = false })
	rebuildAlertList()
	local alert = alerts[key]
	Build(alert)
	return alert
end

local function deleteCustomAlert(alert)
	if not alert.def.custom then return false end
	if state.moving == alert then setMoving(nil) end
	disableCurrent(alert)
	alert.buildToken = (alert.buildToken or 0) + 1 -- verwirft einen noch wartenden Aufbau
	alert.buildScheduled, alert.pendingBuild = false, false
	if alert.preview then alert.preview:Hide() end
	if C_UnitAuras and C_UnitAuras.RemoveAuraSound then
		for i = 1, #alert.soundRegs do pcall(C_UnitAuras.RemoveAuraSound, alert.soundRegs[i]) end
	end
	alert.soundRegs = {}
	for index, spec in ipairs(db.custom) do
		if spec.key == alert.key then
			table.remove(db.custom, index)
			break
		end
	end
	db.alerts[alert.key] = nil
	rebuildAlertList()
	return true
end

-------------------------------------------------------------------------------
-- Befehle
-------------------------------------------------------------------------------

local function yesNo(value) return value and L["yes"] or L["no"] end

local function findAlert(text)
	text = (text or ""):lower()
	if alerts[text] then return alerts[text] end
	for _, alert in ipairs(alerts) do
		if alert.key:sub(1, #text) == text and text ~= "" then return alert end
	end
	return nil
end

local function alertKeys()
	local keys = {}
	for _, alert in ipairs(alerts) do keys[#keys + 1] = alert.key end
	return table.concat(keys, ", ")
end

-- /sha status [alarm]: mit einem Schlüssel nur die Zeilen dieses einen Alarms
local function printStatus(rest)
	local only = alerts[tostring(rest or ""):lower():match("^%s*(%a[%w_]*)") or ""]
	if not only then
		local _, _, _, interface = GetBuildInfo()
		msg(L["Client interface %s, AuraContainer: %s, auras restricted right now: %s."],
			tostring(interface), state.containerOK == nil and L["not checked"] or yesNo(state.containerOK), yesNo(aurasRestricted()))
		if not state.isShaman then msg(L["This character is not a shaman: the built-in alerts and the totem bar stay silent, your own alerts work."]) end
		if ns.Totems then ns.Totems.Status() end
	end
	for _, alert in ipairs(only and { only } or alerts) do
		local settings = alert.s
		msg(L["%s (%s): enabled %s, display built %s, size %d, %s, sound %s."],
			alert.def.title, alert.key, yesNo(settings.enabled), yesNo(alert.current ~= nil), settings.size,
			settings.display == "icon" and (L["spell icon "] .. tostring(resolveIcon(alert))) or (L["texture "] .. tostring(settings.texture)), settings.sound)
		msg(L["  Layout %s, %d copies, distance %d, center %d/%d."],
			(LAYOUTS[settings.layout] or LAYOUTS.center).name, #computeSpots(settings), settings.distance, settings.x, settings.y)
		local mates = placeMates(alert)
		if #mates > 0 then
			local names = {}
			for _, other in ipairs(mates) do names[#names + 1] = other.def.title end
			msg(L["  Place and size shared with: %s."], table.concat(names, ", "))
		end
		if alert.initError then msg(L["  Error while building: %s"], alert.initError) end
		if alert.runError then msg(L["  Error while running: %s"], alert.runError) end
		local ids = {}
		for _, id in ipairs(sortedSpellIDs(alert)) do
			ids[#ids + 1] = ("%d%s"):format(id, spellReadable(id) and "" or L[" (restricted)"])
		end
		if alert.def.kind == "weapon" then
			local function describe(invSlot)
				if not slotHasWeapon(invSlot) then return L["no weapon"] end
				local imbued, families = slotImbued(invSlot)
				if imbued == nil then return L["not readable"] end
				if not imbued then return L["not enchanted"] end
				local names = {}
				for _, family in ipairs(ns.IMBUES) do
					if families and families[family] then names[#names + 1] = ns.IMBUE_NAMES[family] end
				end
				if families and families.other then names[#names + 1] = L["another enchant"] end
				return L["enchanted"] .. (#names > 0 and (" (" .. table.concat(names, ", ") .. ")") or "")
			end
			msg(L["  Main hand: %s, off hand: %s (checked: %s), condition met right now: %s."],
				describe(16), describe(17), yesNo(settings.offhand), yesNo(conditionMet(alert)))
			if (settings.mainImbue or "") ~= "" or (settings.offImbue or "") ~= "" then
				msg(L["  Expected: main hand %s, off hand %s."], ns.imbueName(settings.mainImbue), ns.imbueName(settings.offImbue))
			end
		else
			msg(L["  Aura IDs: %s"], table.concat(ids, ", "))
		end
		if alert.def.custom then
			msg(L["  Custom alert: kind %s, unit %s, filter %s, aura name \"%s\"."],
				KIND_NAMES[alert.def.kind], alert.def.unit == "player" and L["Player"] or L["Target"], alert.def.filter, tostring(settings.auraName))
		end
		if alert.def.kind == "ready" then
			local id, ready, range = readySpell(alert), spellReady(alert), spellInRange(alert)
			msg(L["  Spell ID %s, ready: %s, in range: %s, target needed: %s, range needed: %s."],
				tostring(id or L["unknown"]), ready == nil and L["unknown"] or yesNo(ready), range == nil and L["unknown"] or yesNo(range),
				yesNo(settings.needTarget), yesNo(settings.needRange))
			msg(L["  Lead time: %.1f s (%s)."], settings.lead or 0,
				(C_Spell and C_Spell.GetSpellCooldownDuration) and L["supported by the game"] or L["not possible in this client"])
			local partner = partnerOf(alert)
			if partner then
				msg(L["  Stands behind \"%s\" (wants to show right now: %s)."], partner.def.title, yesNo(partnerWants(partner)))
			end
		end
		if (settings.specs or "") ~= "" then
			local spec = ns.currentSpec()
			msg(L["  Only as: %s (your specialization right now: %s)."], ns.specText(alert), spec and ns.SPEC_NAMES[spec] or L["unknown"])
		end
		if alert.def.kind == "weapon" then
			-- schon oben ausgegeben
		elseif alert.def.kind == "stacks" then
			local stacks = readStacks(alert)
			msg(L["  Threshold %d, stacks read directly: %s."], settings.threshold, stacks and tostring(stacks) or L["unknown"])
		else
			msg(L["  In combat only: %s, spell known: %s, condition met right now: %s."],
				yesNo(settings.combatOnly), yesNo(spellKnown(alert)), yesNo(conditionMet(alert)))
			local usable = spellUsable(alert)
			local aggro = hasAggro()
			if (settings.behind or "") ~= "" then
				local hidden, by = standsBehind(alert)
				msg(L["  Order: stands behind %s (right now: %s)."], settings.behind, hidden and (L["yes, behind \""] .. by.def.title .. "\"") or L["no"])
			end
			msg(L["  In combat only with aggro: %s (aggro right now: %s)."], yesNo(settings.needAggro), aggro == nil and L["unknown"] or yesNo(aggro))
			if settings.needPlayer then msg(L["  Only against players: yes (target is a player right now: %s)."], yesNo(targetIsPlayer())) end
			if settings.noPlayer then msg(L["  Not against players: yes (target is a player right now: %s)."], yesNo(targetIsPlayer(false))) end
			if alert.def.kind == "ready" then
				local enemies, method = nearbyEnemies(settings.enemyRange)
				msg(L["  Only with %d or more enemies within %d yd: %s (counted right now: %s%s)."], settings.minEnemies or 3, settings.enemyRange or 10, yesNo(settings.needEnemies),
					enemies == nil and L["cannot be determined, enemy nameplates must be switched on"] or tostring(enemies),
					method and (L[", measured by: "] .. ENEMY_METHODS[method]) or "")
				local fireTotem = ns.Totems and ns.Totems.IsActive(1)
				msg(L["  Only while a fire totem stands: %s (right now: %s)."], yesNo(settings.needFireTotem), fireTotem == nil and L["unknown"] or (fireTotem and L["standing"] or L["none"]))
				local casting = targetCasting()
				msg(L["  Only while the target casts: %s (right now: %s)."], yesNo(settings.needCasting), casting == nil and L["the game does not tell"] or (casting and L["casting"] or L["not casting"]))
				if settings.castFirst then msg(L["  Priority while the target casts: %s (right now: %s)."], yesNo(true), yesNo(ns.castPriority(alert))) end
				if (settings.maxMana or 0) > 0 then msg(L["  Only with at most %d %% mana: %s."], settings.maxMana, ns.manaCurve(alert) and L["supported by the game"] or L["not possible in this client"]) end
			end
			if alert.def.kind == "missing" then
				local ready = spellReady(alert)
				msg(L["  Not during the cooldown: %s (ready right now: %s), lead time %.1f s."],
					yesNo(settings.needReady), ready == nil and L["unknown"] or yesNo(ready), settings.lead or 0)
				local refresh, duration = settings.refresh or 0, settings.auraDuration or 0
				if alert.def.talentDuration then
					local rank = ns.talentRank(alert.def.talentDuration.spell, alert.def.talentDuration.node)
					msg(L["  Aura duration %s s; talent that extends it: rank %s."], tostring(duration), rank and tostring(rank) or L["unknown"])
				end
				if refresh <= 0 then
					msg(L["  Early refresh: off."])
				elseif duration <= 0 then
					msg(L["  Early refresh: from %.1f s remaining, but the aura duration is unknown (/sha set %s duration 12)."], refresh, alert.key)
				else
					local remaining = refreshRemaining(alert)
					msg(L["  Early refresh: from %.1f s remaining, aura duration %.1f s, own clock: %s."], refresh, duration,
						remaining == nil and L["not running"] or remaining > 0 and (L["%.1f s left"]):format(remaining) or L["expired"])
				end
			end
			msg(L["  Only with enough mana: %s (usable right now: %s), target health at least: %s."],
				yesNo(settings.needUsable), usable == nil and L["unknown"] or yesNo(usable),
				settings.minHealth > 0 and (settings.minHealth .. " %" .. (healthCurve(alert) and "" or L[", not possible in this client"])) or L["off"])
			if settings.bossAlways and alert.def.unit == "target" then
				local boss = targetIsBoss()
				msg(L["  Always against bosses: %s (target is a boss right now: %s)."], yesNo(true), boss == nil and L["unknown"] or yesNo(boss))
			end
		end
	end
end

local function printHelp()
	msg(L["Commands (alerts: %s):"], alertKeys())
	print(L["  /sha - open or close the options window"])
	print(L["  /sha test [alert] - preview for 3 seconds, with the sound"])
	print(L["  /sha set <alert> <field> <value> - e.g. /sha set maelstrom threshold 4"])
	print(L["     Fields: enabled, threshold, size, alpha, texture, color, additive, pulse, icon, combatonly, needusable, needaggro, needplayer, noplayer, needtarget, needrange, needenemies, minenemies, enemyrange, needfiretotem, needcasting, castfirst, needready, lead, refresh, duration, yieldto, behind, placelike, minhealth, maxmana, bossalways, specs, offhand, mainimbue, offimbue, sound, soundfile, name"])
	print(L["     Display: display (icon, texture), iconzoom, iconborder, bordercolor, iconspell (spell ID, name, path or auto)"])
	print(L["     Layout: layout (center, bottom, top, left, right, sides, topbottom, around), count, distance, spread, rotate, angle, flip, perstack, x, y"])
	print(L["  /sha id <alert> <aura ID|reset> - add an aura ID or reset the IDs"])
	print(L["  /sha new [title] - create your own alert; /sha delete <alert> - delete one of your own alerts"])
	print(L["     Custom alerts: title, kind (active, missing, stacks, ready), unit (player, target), auratype (buff, debuff, mine), timer"])
	print(L["  /sha scan - list your buffs and your debuffs on the target with their IDs"])
	print(L["  /sha minimap [on|off] - show or hide the minimap button"])
	print(L["  /sha hotkeys [on|off] - show the key of the spell under the graphics; /sha totem hotkeys on for the cooldown icons"])
	print(L["  /sha spec [auto|elemental|enhancement|restoration] - show your specialization or set it by hand"])
	print(L["  /sha profile - page for profiles and sharing; /sha profile save|load|delete <name>, /sha profile list"])
	print(L["  /sha export - the settings as text to pass on"])
	print(L["  /sha totem - settings of the totem bar; /sha totem <field> <value> or /sha totem reset"])
	print(L["  /sha font <auto|font name>, /sha font outline <auto|none|outline|thick>, /sha font timersize <number>"])
	print(L["  /sha status, /sha reset [alert]"])
	print(L["  /sha debug - record 30 seconds of diagnostics (then /reload), /sha debug clear deletes them"])
end

local commands = {}

commands.set = function(rest)
	local alertText, field, value = rest:match("^(%S+)%s+(%S+)%s*(.-)$")
	local alert = findAlert(alertText)
	local setter = field and FIELDS[field:lower()]
	if not alert then return msg(L["Unknown alert. Available: %s."], alertKeys()) end
	if not setter then return msg(L["Unknown field. /sha help shows the list."]) end
	local ok, problem = setter(alert, value or "")
	if not ok then return msg(problem) end
	local built = afterChange(alert)
	msg(L["%s: %s changed."], alert.def.title, field:lower())
	if alert.pendingBuild then
		msg(L["You are in combat, the change takes effect after combat."])
	elseif not built then
		msg(L["The display could not be built: %s"], tostring(alert.initError or L["no AuraContainer in this client"]))
	end
end

commands.id = function(rest)
	local alertText, value = rest:match("^(%S+)%s+(%S+)$")
	local alert = findAlert(alertText)
	if not alert then return msg(L["Example: /sha id flameshock 8050. Alerts: %s."], alertKeys()) end
	if value:lower() == "reset" then
		alert.s.spellIDs = copyTable(alert.def.defaults.spellIDs)
	else
		local id = tonumber(value)
		if not id or id < 1 then return msg(L["Please enter an aura ID or reset."]) end
		alert.s.spellIDs[math.floor(id)] = true
	end
	afterChange(alert)
	msg(L["%s: aura IDs %s."], alert.def.title, table.concat(sortedSpellIDs(alert), ", "))
end

commands.scan = function()
	if aurasRestricted() then return msg(L["Auras are restricted right now (combat). Please scan out of combat."]) end
	local function tracked(spellID)
		for _, alert in ipairs(alerts) do
			if alert.s.spellIDs[spellID] then return "  <- " .. alert.def.title end
		end
		return ""
	end
	local function list(title, unit, filter)
		msg(title)
		local ok = forEachReadableAura(unit, filter, function(name, spellID, count)
			local stacks = (not isSecret(count) and type(count) == "number" and count > 0) and (" x" .. count) or ""
			print(("  %d  %s%s%s"):format(spellID, tostring(name), stacks, tracked(spellID)))
		end)
		if not ok then print(L["  not readable"]) end
	end
	list(L["Your buffs:"], "player", "HELPFUL")
	list(L["Your debuffs on the target:"], "target", "HARMFUL|PLAYER")
end

commands.test = function(rest)
	local alert = findAlert(rest) or alerts[1]
	if state.moving ~= alert then
		alert.testing = true
		applyPreview(alert)
		getPreview(alert):Show()
		C_Timer.After(3, function()
			alert.testing = false
			if state.moving ~= alert then getPreview(alert):Hide() end
		end)
	end
	playAlertSound(alert)
	msg(L["Test for \"%s\": this is what the display looks like (3 seconds), with the sound."], alert.def.title)
end

commands.status = printStatus

commands.reset = function(rest)
	local only = findAlert(rest)
	for _, alert in ipairs(alerts) do
		if not only or only == alert then
			resetAlert(alert)
			afterChange(alert)
		end
	end
	if not only and ns.Totems then
		ns.Totems.Reset()
		if ns.RefreshTotemOptions then ns.RefreshTotemOptions() end
	end
	msg(only and (L["Settings for \""] .. only.def.title .. L["\" reset."]) or L["All settings reset."])
end

commands.new = function(rest)
	local alert = createCustomAlert(rest)
	updateEngineSounds()
	if ns.SelectAlert then ns.SelectAlert(alert) end
	msg(L["Custom alert \"%s\" created (key %s). Enter the name of the aura in the options window."], alert.def.title, alert.key)
end

commands.delete = function(rest)
	local alert = findAlert(rest)
	if not alert then return msg(L["Unknown alert. Available: %s."], alertKeys()) end
	if not alert.def.custom then return msg(L["\"%s\" is built in and can only be switched off, not deleted."], alert.def.title) end
	local title = alert.def.title
	deleteCustomAlert(alert)
	if ns.SelectAlert then ns.SelectAlert(alerts[1]) end
	msg(L["Custom alert \"%s\" deleted."], title)
end

-- Baut alles neu auf, was Text zeigt: Totem-Leiste, Restzeit, Stapelzahl.
local function refreshTexts()
	for _, alert in ipairs(alerts) do
		local shows = (alert.def.kind == "active" and alert.s.timer) or (alert.def.kind == "stacks" and alert.s.icon)
		if shows and alert.current then flushBuild(alert) end
	end
	if ns.Totems then ns.Totems.Apply() end
	if ns.RefreshTotemOptions then ns.RefreshTotemOptions() end
	state.hotkeysDirty = true
end

-- /sha font <auto|Schriftname>, /sha font outline <auto|none|outline|thick>, /sha font timersize <Zahl>
commands.font = function(rest)
	local first, value = rest:match("^(%S*)%s*(.-)$")
	if first:lower() == "outline" then
		if not OUTLINE_NAMES[value:lower()] then return msg(L["Allowed: auto, none, outline, thick."]) end
		db.font.outline = value:lower()
	elseif first:lower() == "timersize" then
		local size = toNumber(value)
		if not size or size < 6 or size > 40 then return msg(L["Please enter a size from 6 to 40."]) end
		db.font.timerSize = math.floor(size + 0.5)
	elseif rest == "" then
		local path, flags = resolveFont()
		return msg(L["Font: %s (%s), outline: %s, timer size %d."], db.font.face, path, flags == "" and L["none (shadow)"] or flags, db.font.timerSize)
	else
		db.font.face = rest:lower() == "auto" and "auto" or rest
	end
	refreshTexts()
	msg(L["Font changed."])
end

commands.help = printHelp
commands.hilfe = printHelp

commands.options = function()
	if ns.ToggleOptions then ns.ToggleOptions() else printHelp() end
end
commands.config = commands.options

-- /sha hotkeys [on|off]: die Taste des Zaubers unter den Grafiken zeigen
commands.hotkeys = function(rest)
	db.hotkeys = toBoolean(rest, db.hotkeys)
	if ns.Hotkeys then ns.Hotkeys.Invalidate() end
	ns.refreshHotkeys()
	state.hotkeysDirty = nil
	msg(L["Hotkeys under the graphics: %s."], db.hotkeys and L["visible"] or L["hidden"])
	if ns.RefreshOptions then ns.RefreshOptions() end
end
commands.tasten = commands.hotkeys

-- /sha minimap [on|off]: Knopf an der Minimap zeigen oder verbergen
commands.minimap = function(rest)
	if not ns.Minimap then return end
	ns.Minimap.SetShown(toBoolean(rest, ns.Minimap.IsShown()))
	msg(L["Minimap button: %s."], ns.Minimap.IsShown() and L["visible"] or L["hidden"])
	if ns.RefreshOptions then ns.RefreshOptions(true) end
end

-- /sha spec [auto|elemental|enhancement|restoration]: Spezialisierung zeigen
-- oder von Hand festlegen, falls das Spiel sie nicht verrät.
commands.spec = function(rest)
	local word = (rest or ""):lower():match("^%s*(%S*)")
	if word ~= "" then
		local match
		for _, spec in ipairs(ns.SPECS) do
			if #word >= 3 and spec:sub(1, #word) == word then match = spec end
		end
		if word == "auto" then
			db.specOverride = nil
		elseif match then
			db.specOverride = match
		else
			msg(L["Please enter auto, elemental, enhancement or restoration."])
			return
		end
		state.spec = nil
		updateConditions()
		if ns.RefreshOptions then ns.RefreshOptions() end
	end
	if db.specOverride and ns.SPEC_NAMES[db.specOverride] then
		msg(L["Specialization set by hand: %s. /sha spec auto reads it from your talents again."], ns.SPEC_NAMES[db.specOverride])
		return
	end
	state.spec = nil
	local spec = ns.currentSpec()
	local points = state.specPoints
	local detail
	if type(points) == "table" then
		local parts = {}
		for index, count in ipairs(points) do
			parts[#parts + 1] = (ns.SPEC_NAMES[ns.SPECS[index] or ""] or ("#" .. index)) .. " " .. tostring(count)
		end
		detail = table.concat(parts, ", ")
	else
		detail = tostring(points)
	end
	if spec and state.specAssumed then
		msg(L["Specialization: no talent points spent yet, so %s is assumed."], ns.SPEC_NAMES[spec])
	elseif spec then
		msg(L["Specialization: %s (talent points: %s)."], ns.SPEC_NAMES[spec], detail)
	else
		msg(L["Specialization: not recognizable (%s). Alerts limited to a specialization show in every one then. /sha spec enhancement sets it by hand."], detail)
	end
end
commands.spezialisierung = commands.spec
commands.optionen = commands.options

-------------------------------------------------------------------------------
-- Der ganze Stand der Einstellungen, für Profile und den Austausch (Profiles.lua)
-------------------------------------------------------------------------------

function ns.takeSnapshot()
	return {
		alerts = copyTable(db.alerts),
		custom = copyTable(db.custom),
		totems = copyTable(db.totems or {}),
		font = copyTable(db.font),
	}
end

-- Übernimmt aus fremden Daten nur, was ein Alarm kennt und was von der
-- richtigen Art ist. Alles andere füllt später die Voreinstellung.
local function cleanSettings(def, source)
	local result = {}
	if type(source) ~= "table" then return result end
	local function take(key, value)
		local wanted = source[key]
		if wanted == nil then
			-- fehlt: Voreinstellung
		elseif key == "spellIDs" then
			if type(wanted) == "table" then
				result.spellIDs = {}
				for id, on in pairs(wanted) do
					if type(id) == "number" and on == true then result.spellIDs[id] = true end
				end
			end
		elseif key == "color" or key == "iconBorderColor" then
			if type(wanted) == "table" and type(wanted[1]) == "number" and type(wanted[2]) == "number" and type(wanted[3]) == "number" then
				result[key] = { wanted[1], wanted[2], wanted[3] }
			end
		elseif key == "soundFile" then
			if type(wanted) == "string" or type(wanted) == "number" then result[key] = wanted end
		elseif type(wanted) == type(value) and type(wanted) ~= "table" then
			result[key] = wanted
		end
	end
	for key, value in pairs(def.defaults) do take(key, value) end
	-- Felder, die ein eingebauter Alarm nicht von sich aus hat, die sich aber
	-- per Befehl setzen lassen (Rangfolge, gemeinsame Lage, Spieler-Bedingung ...)
	for key, value in pairs(CUSTOM_DEFAULTS) do
		if def.defaults[key] == nil then take(key, value) end
	end
	return result
end

-- Ersetzt alle Einstellungen durch den Stand aus "snapshot". Die Tabellen der
-- eingebauten Alarme bleiben dieselben, damit jeder Verweis gültig bleibt.
function ns.applySnapshot(snapshot)
	if inCombat() then return false, L["That does not work in combat. Please try again after combat."] end
	if type(snapshot) ~= "table" or type(snapshot.alerts) ~= "table" then return false, L["There are no ShamanAlerts settings in it."] end
	setMoving(nil)
	for index = #alerts, 1, -1 do
		if alerts[index].def.custom then deleteCustomAlert(alerts[index]) end
	end
	for _, def in ipairs(ALERT_DEFS) do
		local stored = db.alerts[def.key]
		for key in pairs(stored) do stored[key] = nil end
		for key, value in pairs(cleanSettings(def, snapshot.alerts[def.key])) do stored[key] = value end
	end
	if type(snapshot.custom) == "table" then
		for _, spec in ipairs(snapshot.custom) do
			local valid = type(spec) == "table" and type(spec.key) == "string" and spec.key:find("^custom%d+$") and not db.alerts[spec.key]
				and KIND_NAMES[spec.kind] and spec.kind ~= "weapon" and (spec.unit == "player" or spec.unit == "target")
			if valid and #db.custom < 40 then
				local copy = { key = spec.key, kind = spec.kind, unit = spec.unit, harmful = spec.harmful == true, mine = spec.mine == true,
					title = type(spec.title) == "string" and spec.title ~= "" and spec.title:sub(1, 60) or spec.key }
				table.insert(db.custom, copy)
				db.alerts[spec.key] = cleanSettings(customDef(copy), snapshot.alerts[spec.key])
			end
		end
	end
	if type(snapshot.font) == "table" then
		local font = snapshot.font
		db.font.face = type(font.face) == "string" and font.face ~= "" and font.face or "auto"
		db.font.outline = OUTLINE_NAMES[font.outline] and font.outline or "outline"
		db.font.timerSize = type(font.timerSize) == "number" and math.min(40, math.max(6, font.timerSize)) or 14
	end
	state.placement = nil -- die gemeinsame Lage richtet sich nach den neuen Werten
	rebuildAlertList()
	if ns.Totems and ns.Totems.Load and type(snapshot.totems) == "table" then ns.Totems.Load(snapshot.totems) end
	updateEngineSounds()
	for _, alert in ipairs(alerts) do
		alert.lastStacks, alert.castAt, alert.castTarget = nil, nil, nil
		flushBuild(alert)
	end
	if ns.RefreshTotemOptions then ns.RefreshTotemOptions() end
	if ns.RefreshOptions then ns.RefreshOptions(true) end
	return true
end

-- Schnittstelle für Options.lua
ns.alerts = alerts
ns.state = state
ns.msg = msg
ns.TEXTURES = TEXTURES
ns.TEXTURE_CATEGORIES = TEXTURE_CATEGORIES
ns.LAYOUTS = LAYOUTS
-- für Debug.lua
ns.ALERT_DEFS = ALERT_DEFS
ns.internals = {
	conditionMet = conditionMet, spellKnown = spellKnown, spellUsable = spellUsable, hasAggro = hasAggro,
	readySpell = readySpell, spellReady = spellReady, spellInRange = spellInRange, nearbyEnemies = nearbyEnemies, enemyReport = enemyReport, targetCasting = targetCasting, castReport = castReport,
	partnerOf = partnerOf, partnerWants = partnerWants, standsBehind = standsBehind, targetIsPlayer = targetIsPlayer, targetIsBoss = targetIsBoss, placeLeader = placeLeader, placeMates = placeMates, joinPlacement = joinPlacement, refreshRemaining = refreshRemaining, refreshDue = refreshDue, noteCast = noteCast,
}
ns.CUSTOM_KINDS = CUSTOM_KINDS
ns.PLAIN_KINDS = PLAIN_KINDS
ns.KIND_NAMES = KIND_NAMES
ns.resolveIcon = resolveIcon
ns.computeSpots = computeSpots
ns.SOUNDS = SOUNDS
ns.applyPreview = applyPreview
ns.setMoving = setMoving
ns.scheduleBuild = scheduleBuild
ns.flushBuild = flushBuild
ns.flushScheduledBuilds = flushScheduledBuilds
ns.playAlertSound = playAlertSound
ns.soundModes = soundModes
ns.setSoundMode = setSoundMode
ns.setSoundFile = setSoundFile
ns.updateEngineSounds = updateEngineSounds
ns.onAuraChanged = onAuraChanged
ns.sortedSpellIDs = sortedSpellIDs
ns.commands = commands
ns.FIELDS = FIELDS
ns.afterChange = afterChange
ns.applyFont = applyFont
ns.resolveFont = resolveFont
ns.fontChoices = fontChoices
ns.refreshTexts = refreshTexts
ns.OUTLINE_ORDER = OUTLINE_ORDER
ns.OUTLINE_NAMES = OUTLINE_NAMES

SLASH_SHAMANALERTS1 = "/sha"
SLASH_SHAMANALERTS2 = "/shamanalerts"
SLASH_SHAMANALERTS3 = "/mwa"
SlashCmdList.SHAMANALERTS = function(input)
	if not db then return end
	local command, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
	command = (command or ""):lower()
	local handler = commands[command]
	if handler then
		handler(rest or "")
	elseif command == "" and ns.ToggleOptions then
		ns.ToggleOptions()
	else
		printHelp()
	end
end
