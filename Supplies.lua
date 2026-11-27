-- ShamanAlerts: Vorräte
--
-- Warnt mit großem Text und eigenem Klang, wenn etwas zur Neige geht, das man
-- beim Händler oder aus der Bank mitnehmen sollte: Wasser, Ankh, Tränke, Essen,
-- Verbände, Totems, Ruhestein; dazu Reparieren und volle Taschen.
--
-- Getränke, Tränke und Essen kennt das Addon für jeden Levelbereich selbst.
-- Gezählt wird, was zur Stufe passt: alles ab der Stufe, ab der es die
-- aktuelle Sorte beim Händler gibt. Mit Stufe 47 zählt also Trichterwindentau
-- (ab 45), aber nicht mehr Mondbeerensaft (ab 35).
--
-- Voreingestellt warnt das Addon nur außerhalb des Kampfes und nie in Dungeons,
-- Schlachtzügen, Schlachtfeldern oder Arenen. Beides lässt sich je Vorrat ändern.

local ADDON_NAME, ns = ...
local L = ns.L

local Supplies = {}
ns.Supplies = Supplies

local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"

-------------------------------------------------------------------------------
-- Was gezählt wird: { Item-ID, benötigte Stufe }
-------------------------------------------------------------------------------

-- Getränke und Speisen, die Mana wiederherstellen
local DRINKS = {
	{ 159, 1 }, { 5350, 1 }, { 3448, 1 }, -- Erfrischendes Quellwasser, Herbeigezaubertes Wasser, Sengginwurzel
	{ 19997, 1 }, { 20388, 1 }, { 20389, 1 }, { 20390, 1 }, { 21241, 1 }, { 21537, 1 }, -- Festtags-Leckereien (Prozent je Sekunde)
	{ 1401, 4 }, -- Grünteeblatt
	{ 1179, 5 }, { 2288, 5 }, { 2682, 5 }, { 17404, 5 }, -- Eiskalte Milch, Herbeigezaubertes frisches Wasser, Gekochte Krebsschere, Bohnengebräu
	{ 21072, 10 }, -- Geräucherter Weisenfisch
	{ 1205, 15 }, { 2136, 15 }, { 9451, 15 }, { 19299, 15 }, -- Melonensaft, Herbeigezaubertes geläutertes Wasser, Blubberwasser, Prickelndes Marktgetränk
	{ 1708, 25 }, { 3772, 25 }, { 4791, 25 }, { 10841, 25 }, { 17405, 25 }, -- Süßer Nektar, Herbeigezaubertes Quellwasser, Verzaubertes Wasser, Golddorntee, Grüner Gartentee
	{ 21217, 30 }, -- Weisenfisch Supreme
	{ 1645, 35 }, { 8077, 35 }, { 19300, 35 }, -- Mondbeerensaft, Herbeigezaubertes Mineralwasser, Winterspring-Flaschenwasser
	{ 21215, 40 }, -- Graccus hausgemachte Früchtepastete
	{ 8766, 45 }, { 8078, 45 }, { 23161, 45 }, { 13724, 45 }, { 13813, 45 }, -- Trichterwindentau, Herbeigezaubertes Sprudelwasser, Frisch gepresste Limonade, Angereicherter Manakeks, Gesegneter Sonnenfruchtsaft
	{ 221444, 50 }, -- Dschungeldurian (Season of Discovery)
	{ 19301, 51 }, -- Alterac Manakeks
	{ 8079, 55 }, { 19318, 55 }, { 20031, 55 }, -- Herbeigezaubertes Kristallwasser, Abgefülltes Alteracquellwasser, Essenzmango
	{ 227813, 55 }, { 231778, 55 }, -- Trinkbares Weihwasser von Stratholme, Bergquellwasser (Season of Discovery)
	-- Nicht gezählt: Rationen der Schlachtfelder (wirken nur dort) und Hyjalnektar (in Classic nicht erhältlich).
}

-- Heiltränke
local HEALING = {
	{ 118, 1 }, -- Schwacher Heiltrank
	{ 858, 3 }, -- Geringer Heiltrank
	{ 2456, 5 }, { 4596, 5 }, -- Schwacher Verjüngungstrank, Verfärbter Heiltrank
	{ 929, 12 }, -- Heiltrank
	{ 1710, 21 }, -- Großer Heiltrank
	{ 3928, 35 }, { 9144, 35 }, { 18839, 35 }, -- Überragender Heiltrank, Wildrankentrank, Gefechtsheiltrank
	{ 11951, 45 }, { 11952, 45 }, { 13446, 45 }, -- Peitscherwurzelknollen, Nachtdrachenodem, Erheblicher Heiltrank
	{ 18253, 50 }, -- Erheblicher Verjüngungstrank
	-- Nicht gezählt: Heilgebräue der Schlachtfelder (wirken nur dort).
}

-- Manatränke
local MANA = {
	{ 2455, 5 }, { 2456, 5 }, -- Schwacher Manatrank, Schwacher Verjüngungstrank
	{ 3385, 14 }, -- Geringer Manatrank
	{ 3827, 22 }, -- Manatrank
	{ 6149, 31 }, -- Großer Manatrank
	{ 9144, 35 }, -- Wildrankentrank
	{ 13443, 41 }, { 18841, 41 }, -- Überragender Manatrank, Gefechtsmanatrank
	{ 11952, 45 }, -- Nachtdrachenodem
	{ 13444, 49 }, -- Erheblicher Manatrank
	{ 18253, 50 }, -- Erheblicher Verjüngungstrank
	-- Nicht gezählt: Managebräue der Schlachtfelder (wirken nur dort).
}

-- Essen, das Leben wiederherstellt: Händler, Magier, Feste und einfache Kochrezepte
local FOOD = {
	{ 117, 1 }, { 787, 1 }, { 2070, 1 }, { 2679, 1 }, { 2681, 1 }, { 3448, 1 }, { 4536, 1 }, { 4540, 1 }, { 4604, 1 }, { 5349, 1 }, { 6290, 1 }, { 16166, 1 }, { 19223, 1 }, -- Zähes Stockfleisch, Glitschhautmakrele, Darnassischer Blauschimmelkäse, Verkohltes Wolfsfleisch, Geröstetes Eberfleisch, Sengginwurzel, Glänzender roter Apfel, Zäher Brocken Brot, Waldpilzkappe, Herbeigezauberter Muffin, Glänzender Kleinfisch, Bohnensuppe, Dunkelmond-Zipferl
	{ 414, 5 }, { 733, 5 }, { 1113, 5 }, { 2287, 5 }, { 2682, 5 }, { 4537, 5 }, { 4541, 5 }, { 4592, 5 }, { 4605, 5 }, { 5095, 5 }, { 6316, 5 }, { 6890, 5 }, { 16167, 5 }, { 17119, 5 }, { 17406, 5 }, { 19304, 5 }, -- Pikanter Dalarankäse, Westfall-Eintopf, Herbeigezaubertes Brot, Fleischschenkel, Gekochte Krebsschere, Tel'Abim-Banane, Frisch gebackenes Brot, Langzahniger Matschschnapper, Rotgetupfter Pilz, Regenbogenflossenthunfisch, Lochfrenzy Supreme, Geräuchertes Bärenfleisch, Versifarben-Leckerei, Untergrundratten-Kebab, Festtagskäserad, Gewürztes Rinderstockfleisch
	{ 2685, 10 }, { 5478, 10 }, { 5526, 10 }, -- Saftige Schweinerippchen, Grubenratteneintopf, Muschelsuppe
	{ 422, 15 }, { 1114, 15 }, { 3770, 15 }, { 4538, 15 }, { 4542, 15 }, { 4593, 15 }, { 4606, 15 }, { 7228, 15 }, { 16170, 15 }, { 19305, 15 }, -- Zwergenmild, Herbeigezaubertes Roggenbrot, Hammelkoteletts, Schnappranken-Wassermelone, Saftiges Maisbrot, Stoppelfühlerwels, Schwammerl, Skippis Eiscreme, Gedünsteter Mandu, Gepökelter Kodofuß
	{ 1487, 25 }, { 1707, 25 }, { 3771, 25 }, { 4539, 25 }, { 4544, 25 }, { 4594, 25 }, { 4607, 25 }, { 8364, 25 }, { 16169, 25 }, { 17407, 25 }, { 18632, 25 }, { 19224, 25 }, -- Herbeigezauberter Pumpernickel, Brie aus Stormwind, Wildschweinschenkel, Goldrindenapfel, Gewürzbrot aus Mulgore, Steinschuppenkabeljau, Köstlicher Höhlenschimmel, Mithrilkopfforelle, Wilder Reiskuchen, Graccus hausgemachte Fleischpastete, Moonbrook Tumult-Toffee, Würzige Hähnchenschlegel
	{ 3927, 35 }, { 4599, 35 }, { 4601, 35 }, { 4602, 35 }, { 4608, 35 }, { 6887, 35 }, { 8075, 35 }, { 13930, 35 }, { 16168, 35 }, { 16766, 35 }, { 17408, 35 }, { 18635, 35 }, { 19306, 35 }, { 21030, 35 }, { 21552, 35 }, -- Feiner alter Cheddar, Räucherschinkensteak, Weiches Bananenbrot, Monderntekürbis, Roher schwarzer Trüffel, Tüpfelgelbschwanz, Herbeigezauberter Sauerteig, Rotkiemenfilet, Himmlischer Pfirsich, Undermine-Muschelsuppe, Brachländer Würstchen, Bellaras Nussriegel, Knusperfrosch, Darnassischer Kimchikuchen, Streifengelbschwanz
	{ 8076, 45 }, { 8932, 45 }, { 8948, 45 }, { 8950, 45 }, { 8952, 45 }, { 8953, 45 }, { 8957, 45 }, { 11444, 45 }, { 13724, 45 }, { 13933, 45 }, { 13935, 45 }, { 19225, 45 }, { 21031, 45 }, { 21033, 45 }, { 22324, 45 }, { 23160, 45 }, -- Herbeigezaubertes Milchbrötchen, Alteraclochkäse, Getrockneter Königsboletus, Hausgemachter Kirschkuchen, Geröstete Wachtel, Frittierte Kochbanane, Rückenflossenheilbutt, Fleisch aus dem 'Grimmigen Säufer', Angereicherter Manakeks, Hummereintopf, Gebackener Lachs, Frittierter Schokoriegel, Weißkohlkimchi, Rettichkimchi, Winterkimchi, Freundschaftsbrot
	{ 19301, 51 }, -- Alterac Manakeks
	{ 20031, 55 }, { 22895, 55 }, -- Essenzmango, Herbeigezauberte Zimtschnecke
	-- Nicht gezählt: Essen, das vor allem einen Buff gibt, und Rationen der Schlachtfelder.
}

-- Verbände: ohne Stufe, jeder zählt
local BANDAGES = {
	{ 1251, 1 }, { 2581, 1 }, { 3530, 1 }, { 3531, 1 }, { 6450, 1 }, { 6451, 1 }, { 8544, 1 }, { 8545, 1 }, { 14529, 1 }, { 14530, 1 },
}

-- Ab welcher Stufe es die nächste Sorte beim Händler gibt
local LADDER = {
	water = { 1, 5, 15, 25, 35, 45 },
	healing = { 1, 3, 12, 21, 35, 45 },
	mana = { 5, 14, 22, 31, 41, 49 },
	food = { 1, 5, 15, 25, 35, 45 },
}

local ANKH = 17030
local REINCARNATION_LEVEL = 30 -- ab hier lernen Schamanen die Wiedergeburt
local HEARTHSTONE = 6948

-- Totem-Gegenstände: Ohne sie lassen sich die Totems ihres Elements nicht
-- stellen. Gebraucht wird einer, sobald ein Totem des Elements bekannt ist.
local TOTEMS = {
	{ item = 5175, name = L["Earth"], level = 4, spells = { 8071, 2484, 8075, 5730, 8143 } },
	{ item = 5176, name = L["Fire"], level = 10, spells = { 3599, 1535, 8190, 8181, 8227 } },
	{ item = 5177, name = L["Water"], level = 20, spells = { 5394, 5675, 8166, 8170, 8184 } },
	{ item = 5178, name = L["Air"], level = 30, spells = { 8177, 8512, 8835, 10595, 15107, 6495, 25908 } },
}

-------------------------------------------------------------------------------
-- Abfragen beim Spiel
-------------------------------------------------------------------------------

local function plainNumber(value)
	if type(value) ~= "number" then return nil end
	if issecretvalue and issecretvalue(value) then return nil end
	return value
end

local function itemCount(id)
	local lookup = (C_Item and C_Item.GetItemCount) or GetItemCount
	if not lookup then return 0 end
	local ok, count = pcall(lookup, id)
	return ok and plainNumber(count) or 0
end

local function playerLevel()
	return plainNumber(UnitLevel and UnitLevel("player")) or 1
end

local function knowsSpell(id)
	if type(IsPlayerSpell) ~= "function" then return nil end
	local ok, known = pcall(IsPlayerSpell, id)
	if not ok or type(known) ~= "boolean" then return nil end
	return known
end

-- Ab welcher Stufe zählt, was im Gepäck ist? nil: Für diese Stufe gibt es noch nichts.
local function ladderFloor(ladder, level)
	local floor
	for _, step in ipairs(ladder) do
		if step <= level then floor = step end
	end
	return floor
end
Supplies.ladderFloor = ladderFloor

-- Wie viel von der Liste passt zur Stufe? Dazu, wie viel von einer
-- schwächeren, älteren Sorte im Gepäck ist, die man auch noch nutzen kann.
local function countFor(list, ladder, level)
	local floor = 1
	if ladder then
		floor = ladderFloor(ladder, level)
		if not floor then return nil end
	end
	local total, older = 0, 0
	for _, entry in ipairs(list) do
		if entry[2] <= level then
			if entry[2] >= floor then
				total = total + itemCount(entry[1])
			else
				older = older + itemCount(entry[1])
			end
		end
	end
	return total, nil, older
end

-- Die niedrigste Haltbarkeit der angelegten Ausrüstung in Prozent
local function lowestDurability()
	if not GetInventoryItemDurability then return nil end
	local lowest
	for slot = 1, 18 do
		local ok, current, maximum = pcall(GetInventoryItemDurability, slot)
		current, maximum = plainNumber(current), plainNumber(maximum)
		if ok and current and maximum and maximum > 0 then
			local percent = math.floor(current / maximum * 100)
			if not lowest or percent < lowest then lowest = percent end
		end
	end
	return lowest
end

-- Freie Plätze in den gewöhnlichen Taschen (keine Spezialtaschen wie Köcher)
local function freeSlots()
	local api = C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots
	if not api then return nil end
	local total, any = 0, false
	for bag = 0, 4 do
		local ok, free, family = pcall(api, bag)
		free, family = plainNumber(free), plainNumber(family)
		if ok and free and (family == nil or family == 0) then
			total = total + free
			any = true
		end
	end
	return any and total or nil
end

-------------------------------------------------------------------------------
-- Die Vorräte
-------------------------------------------------------------------------------

-- measure(level) liefert den Stand und ob der Vorrat für diesen Charakter gilt,
-- dazu auf Wunsch einen Text und die Menge einer schwächeren Sorte.
-- Gewarnt wird, sobald der Stand höchstens die eingestellte Grenze erreicht.
-- Reicht die schwächere Sorte noch über die Grenze, gibt es nur einen Hinweis:
-- kleiner, ohne Pulsieren und mit nur einem Klang.
-- Bei "missing" gibt es keine Grenze: gewarnt wird, wenn etwas fehlt.
Supplies.KINDS = {
	{
		key = "water", icon = 159, label = L["Water"], text = L["Buy water!"], sound = "water_buy.ogg", color = { 0.35, 0.75, 1 },
		enabled = true, at = 20, max = 100, step = 1,
		measure = function(level) return countFor(DRINKS, LADDER.water, level) end,
	},
	{
		key = "ankh", icon = 17030, label = L["Ankh"], text = L["Buy ankh!"], sound = "ankh_buy.ogg", color = { 1, 0.8, 0.25 },
		enabled = true, at = 1, max = 10, step = 1,
		measure = function(level)
			if level < REINCARNATION_LEVEL then return nil end
			return itemCount(ANKH)
		end,
	},
	{
		key = "healing", icon = 929, label = L["Healing potions"], text = L["Buy healing potions!"], sound = "healing_buy.ogg", color = { 1, 0.3, 0.3 },
		enabled = false, at = 3, max = 20, step = 1,
		measure = function(level) return countFor(HEALING, LADDER.healing, level) end,
	},
	{
		key = "mana", icon = 3827, label = L["Mana potions"], text = L["Buy mana potions!"], sound = "mana_buy.ogg", color = { 0.45, 0.55, 1 },
		enabled = false, at = 3, max = 20, step = 1,
		measure = function(level) return countFor(MANA, LADDER.mana, level) end,
	},
	{
		key = "food", icon = 4540, label = L["Food"], text = L["Buy food!"], sound = "food_buy.ogg", color = { 1, 0.6, 0.2 },
		enabled = false, at = 10, max = 100, step = 1,
		measure = function(level) return countFor(FOOD, LADDER.food, level) end,
	},
	{
		key = "bandage", icon = 1251, label = L["Bandages"], text = L["Take bandages along!"], sound = "bandage_buy.ogg", color = { 0.95, 0.92, 0.85 },
		enabled = false, at = 5, max = 40, step = 1,
		measure = function() return countFor(BANDAGES, nil, 60) end,
	},
	{
		key = "totems", icon = 5175, label = L["Totems"], text = L["Totems missing!"], sound = "totems_missing.ogg", color = { 0.45, 1, 0.45 },
		enabled = false, missing = true,
		measure = function(level)
			local absent, needed = {}, false
			for _, totem in ipairs(TOTEMS) do
				local known
				for _, id in ipairs(totem.spells) do
					local result = knowsSpell(id)
					if result then known = true break end
					if result == false then known = known or false end
				end
				-- Verrät das Spiel das Zauberbuch nicht, entscheidet die Stufe.
				if known == nil then known = level >= totem.level end
				if known then
					needed = true
					if itemCount(totem.item) == 0 then absent[#absent + 1] = totem.name end
				end
			end
			if not needed then return nil end
			return #absent, table.concat(absent, ", ")
		end,
	},
	{
		key = "hearth", icon = 6948, label = L["Hearthstone"], text = L["Hearthstone missing!"], sound = "hearth_missing.ogg", color = { 0.6, 0.8, 1 },
		enabled = false, missing = true,
		measure = function()
			local count = itemCount(HEARTHSTONE)
			return count == 0 and 1 or 0
		end,
	},
	{
		key = "repair", icon = "Interface\\Icons\\Trade_BlackSmithing", label = L["Repair"], text = L["Repair your gear!"], sound = "repair_needed.ogg", color = { 1, 0.85, 0.3 },
		enabled = false, at = 20, max = 60, step = 5, percent = true,
		measure = function() return lowestDurability() end,
	},
	{
		key = "bags", icon = "Interface\\Icons\\INV_Misc_Bag_08", label = L["Bag space"], text = L["Bags almost full!"], sound = "bags_full.ogg", color = { 0.85, 0.6, 1 },
		enabled = false, at = 2, max = 20, step = 1,
		measure = function() return freeSlots() end,
	},
}
for _, kind in ipairs(Supplies.KINDS) do Supplies.KINDS[kind.key] = kind end

local DEFAULTS = {
	sound = true, -- Klänge überhaupt abspielen
	pulse = true, -- Warnungen pulsieren lassen
	size = 56,
	icons = true, -- Symbol des Gegenstands vor dem Text
	x = 0, y = -60, -- oben in der Mitte
}
Supplies.DEFAULTS = DEFAULTS

local settings
local frame, detail
local lines = {}
local ready = false -- erst nach dem Laden des Gepäcks zählen, sonst gäbe es Fehlalarm
local unlocked, testUntil = false, nil
local lastAny -- wann zuletzt ein Klang kam, damit sich zwei nicht überlagern
local warning = {} -- Vorräte, die gerade warnen
local wasLow = {} -- je Vorrat: "low" (Warnung), "weak" (Hinweis) oder nil
local played, lastPlayed = {}, {} -- je Vorrat: wie oft und wann zuletzt sein Klang kam
local active = false -- steht gerade etwas an? Dann rechnet die Anzeige jede Sekunde nach.
-- Beim Ladebildschirm stimmen Kampf und Instanz kurz nicht: Wer im Kampf in einen
-- Dungeon geht, ist schon "außer Kampf", aber noch nicht "in der Instanz".
-- So lange und ein paar Sekunden danach bleibt alles still.
local loading, quietUntil = false, 0
local QUIET_AFTER_LOADING = 3
local SOUND_GAP = 2.5 -- Sekunden zwischen den Klängen verschiedener Vorräte

local BUILT_IN = #Supplies.KINDS
Supplies.BUILT_IN = BUILT_IN
Supplies.MAX_CUSTOM = 6 -- so viele eigene Vorräte passen in die Liste

-------------------------------------------------------------------------------
-- Eigene Vorräte: Text und Gegenstände selbst gewählt, gezählt ohne Stufen
-------------------------------------------------------------------------------

local function itemName(id)
	local lookup = (C_Item and C_Item.GetItemNameByID) or GetItemInfo
	if lookup then
		local ok, name = pcall(lookup, id)
		if ok and type(name) == "string" and name ~= "" then return name end
	end
	return nil
end

-- "Name (ID)" je Gegenstand, durch Komma getrennt: so steht es im Eingabefeld.
function Supplies.ItemsText(kind)
	local parts = {}
	for _, id in ipairs(kind.spec and kind.spec.items or {}) do
		local name = itemName(id)
		parts[#parts + 1] = name and ("%s (%d)"):format(name, id) or tostring(id)
	end
	return table.concat(parts, ", ")
end

-- Ein Eintrag aus dem Eingabefeld: Link, "Name (ID)", reine ID oder Name.
local function resolveItem(text)
	text = text:match("^%s*(.-)%s*$")
	if text == "" then return nil end
	local id = tonumber(text:match("|Hitem:(%d+)") or text:match("item:(%d+)") or text:match("%((%d+)%)%s*$") or text:match("^(%d+)$"))
	if id then return id end
	local lookup = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
	if lookup then
		local ok, found = pcall(lookup, text)
		if ok and type(found) == "number" and found > 0 and itemName(found) and itemName(found):lower() == text:lower() then return found end
	end
	return nil
end

local function customKind(spec)
	local kind = {
		key = spec.key, custom = true, spec = spec, label = spec.text, text = spec.text,
		sound = "alarm.ogg", color = { 1, 0.3, 0.3 }, enabled = true, at = 5, max = 200, step = 1,
	}
	kind.icon = spec.items[1] or "Interface\\Icons\\INV_Misc_QuestionMark"
	kind.measure = function()
		if #spec.items == 0 then return nil end -- ohne Gegenstände gibt es nichts zu zählen
		local total = 0
		for _, id in ipairs(spec.items) do total = total + itemCount(id) end
		return total
	end
	return kind
end

-- Hängt die eigenen Vorräte hinter die eingebauten. Ein schon bekannter
-- Vorrat behält seinen Eintrag, damit Auswahl und Zähler an ihm hängen bleiben.
local customKinds = setmetatable({}, { __mode = "k" })
local function rebuildKinds()
	for index = #Supplies.KINDS, BUILT_IN + 1, -1 do
		Supplies.KINDS[Supplies.KINDS[index].key] = nil
		Supplies.KINDS[index] = nil
	end
	for index = #settings.custom, 1, -1 do
		local spec = settings.custom[index]
		local valid = type(spec) == "table" and type(spec.key) == "string" and spec.key:match("^custom%d+$")
		if not valid then table.remove(settings.custom, index) end
	end
	for _, spec in ipairs(settings.custom) do
		if type(spec.text) ~= "string" or spec.text == "" then spec.text = L["Buy supplies!"] end
		if type(spec.items) ~= "table" then spec.items = {} end
		local kind = customKinds[spec] or customKind(spec)
		customKinds[spec] = kind
		kind.text, kind.label = spec.text, spec.text
		Supplies.KINDS[#Supplies.KINDS + 1] = kind
		Supplies.KINDS[kind.key] = kind
	end
end

-- Legt einen eigenen Vorrat an. nil, wenn schon so viele da sind, wie in die Liste passen.
function Supplies.AddCustom(text)
	if #settings.custom >= Supplies.MAX_CUSTOM then return nil end
	local number = 1
	while Supplies.KINDS["custom" .. number] do number = number + 1 end
	local spec = { key = "custom" .. number, text = (text and text ~= "") and text or L["Buy supplies!"], items = {} }
	settings.custom[#settings.custom + 1] = spec
	rebuildKinds()
	local kind = Supplies.KINDS[spec.key]
	Supplies.kindSettings(kind)
	Supplies.Update()
	return kind
end

function Supplies.DeleteCustom(kind)
	if not (kind and kind.custom) then return false end
	for index, spec in ipairs(settings.custom) do
		if spec.key == kind.key then table.remove(settings.custom, index) end
	end
	settings.kinds[kind.key] = nil
	wasLow[kind.key], played[kind.key], lastPlayed[kind.key] = nil, nil, nil
	rebuildKinds()
	Supplies.Update()
	return true
end

function Supplies.SetCustomText(kind, text)
	if not (kind and kind.custom) then return end
	text = (text or ""):match("^%s*(.-)%s*$")
	kind.spec.text = text ~= "" and text or L["Buy supplies!"]
	kind.text, kind.label = kind.spec.text, kind.spec.text
	Supplies.Update()
end

-- Übernimmt die Gegenstände aus dem Eingabefeld. Liefert, was nicht zu finden war.
function Supplies.SetCustomItems(kind, text)
	if not (kind and kind.custom) then return {} end
	local items, seen, missing = {}, {}, {}
	for piece in tostring(text or ""):gmatch("[^,;\n]+") do
		local id = resolveItem(piece)
		if id and not seen[id] then
			seen[id] = true
			items[#items + 1] = id
		elseif not id and piece:match("%S") then
			missing[#missing + 1] = piece:match("^%s*(.-)%s*$")
		end
	end
	kind.spec.items = items
	kind.icon = items[1] or "Interface\\Icons\\INV_Misc_QuestionMark"
	Supplies.Update()
	return missing
end

-- Fügt einen Gegenstand hinzu, etwa beim Hineinziehen aus der Tasche.
function Supplies.AddCustomItem(kind, id)
	if not (kind and kind.custom and type(id) == "number") then return end
	for _, known in ipairs(kind.spec.items) do
		if known == id then return end
	end
	kind.spec.items[#kind.spec.items + 1] = id
	kind.icon = kind.spec.items[1]
	Supplies.Update()
end

local function kindSettings(kind)
	local stored = settings.kinds[kind.key]
	if type(stored) ~= "table" then
		stored = {}
		settings.kinds[kind.key] = stored
	end
	if type(stored.enabled) ~= "boolean" then stored.enabled = kind.enabled end
	-- je Vorrat: nur außerhalb des Kampfes, nie in Dungeons, Schlachtzügen, Schlachtfeldern und Arenen
	-- (aus 2.57.0 gilt der gemeinsame Schalter weiter, bis er je Vorrat geändert wird)
	if type(stored.combatHide) ~= "boolean" then stored.combatHide = settings.combatHide ~= false end
	if type(stored.instanceHide) ~= "boolean" then stored.instanceHide = settings.instanceHide ~= false end
	-- Wie oft der Klang kommt (0 = immer wieder, bis es behoben ist), in welchem
	-- Abstand, und ob der Text nach dem letzten Klang verschwindet
	if type(stored.repeats) ~= "number" or stored.repeats < 0 or stored.repeats > 20 then stored.repeats = 0 end
	if type(stored.interval) ~= "number" or stored.interval < 5 or stored.interval > 120 then
		local old = settings.interval -- gemeinsamer Abstand aus 2.57
		stored.interval = (type(old) == "number" and old >= 5 and old <= 120) and old or 10
	end
	if type(stored.hideAfter) ~= "boolean" then stored.hideAfter = false end
	if not kind.missing then
		if type(stored.at) ~= "number" or stored.at < 0 or stored.at > kind.max then stored.at = kind.at end
	end
	return stored
end
Supplies.kindSettings = kindSettings

-- Stand eines Vorrats: { kind, value, detail, applies, low }
function Supplies.Check(kind)
	local level = playerLevel()
	local value, extra, older = kind.measure(level)
	local stored = kindSettings(kind)
	local entry = { kind = kind, value = value, detail = extra, older = older, applies = value ~= nil }
	if value ~= nil and stored.enabled then
		if kind.missing then
			entry.low = value > 0
		else
			entry.low = value <= stored.at
			-- genug von einer schwächeren Sorte: nur ein Hinweis, kein Alarm
			if entry.low and (older or 0) > 0 and value + older > stored.at then
				entry.low, entry.weak = false, true
			end
		end
	end
	return entry
end

local function isShaman()
	if not UnitClass then return false end
	local _, class = UnitClass("player")
	return class == "SHAMAN"
end

local HIDDEN_INSTANCES = { party = true, raid = true, pvp = true, arena = true, scenario = true }
local function inGroupContent()
	if not IsInInstance then return false end
	local ok, inside, kind = pcall(IsInInstance)
	return ok and inside and HIDDEN_INSTANCES[kind] or false
end

local function inCombat()
	if InCombatLockdown and InCombatLockdown() then return true end
	if UnitAffectingCombat then
		local ok, fighting = pcall(UnitAffectingCombat, "player")
		if ok and fighting == true then return true end
	end
	return false
end

-- Darf gerade gewarnt werden? Ohne "kind" nur das, was für alle Vorräte gilt.
function Supplies.Allowed(kind)
	if not (settings and ready and isShaman()) then return false end
	if UnitIsDeadOrGhost then
		local ok, dead = pcall(UnitIsDeadOrGhost, "player")
		if ok and dead == true then return false end
	end
	if kind then
		local stored = kindSettings(kind)
		if stored.combatHide and inCombat() then return false end
		if stored.instanceHide and inGroupContent() then return false end
	end
	return true
end

local function detailText(entry)
	local kind, stored = entry.kind, kindSettings(entry.kind)
	if kind.missing then
		if entry.detail and entry.detail ~= "" then return kind.label .. ": " .. entry.detail end
		return kind.label
	end
	local value = entry.value or 0
	if kind.percent then return ("%s: %d %%"):format(kind.label, value) end
	local text = ("%s: %d / %d"):format(kind.label, value, stored.at)
	if (entry.older or 0) > 0 then text = text .. (" (+%d %s)"):format(entry.older, L["weaker"]) end
	return text
end

-- Der Klang eines Vorrats: der eigene oder der ausgewählte (auch aus anderen Addons)
function Supplies.SoundFile(kind)
	local chosen = settings and settings.kinds[kind.key] and settings.kinds[kind.key].sound
	if chosen ~= nil and chosen ~= "" then return chosen end
	return MEDIA .. kind.sound
end

local function playKind(kind)
	lastAny = GetTime and GetTime() or 0
	if PlaySoundFile then pcall(PlaySoundFile, Supplies.SoundFile(kind), "Master") end
end
Supplies.PlayKind = playKind

-- Bild des Vorrats: das Symbol eines passenden Gegenstands aus dem Spiel
function Supplies.Icon(kind)
	if type(kind.icon) == "number" then
		local lookup = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
		if lookup then
			local ok, icon = pcall(lookup, kind.icon)
			if ok and icon then return icon end
		end
		return "Interface\\Icons\\INV_Misc_QuestionMark"
	end
	return kind.icon
end

local function sharedMedia()
	if not LibStub then return nil end
	local ok, media = pcall(LibStub, "LibSharedMedia-3.0", true)
	return ok and media or nil
end

-- Zur Auswahl: die Klänge der Vorräte, die übrigen Klänge des Addons und
-- alles, was andere Addons bei LibSharedMedia angemeldet haben.
function Supplies.SoundChoices()
	local list, seen = {}, {}
	local function add(name, file)
		if file ~= nil and file ~= "" and not seen[file] then
			list[#list + 1] = { name = name, file = file }
			seen[file] = true
		end
	end
	for _, kind in ipairs(Supplies.KINDS) do add(kind.label, MEDIA .. kind.sound) end
	for _, sound in ipairs(ns.SOUNDS or {}) do add(sound.name, sound.file) end
	local media = sharedMedia()
	if media then
		local ok, names = pcall(media.List, media, "sound")
		if ok and type(names) == "table" then
			for _, name in ipairs(names) do
				local fetched, file = pcall(media.Fetch, media, "sound", name, true)
				local usable = fetched and (type(file) == "string" and file ~= "" or type(file) == "number" and file > 1)
				if usable and name ~= "None" then add(name, file) end
			end
		end
	end
	return list
end

-- Die eigenen Klänge bei LibSharedMedia anmelden, damit andere Addons sie auch anbieten können.
local function registerSounds()
	local media = sharedMedia()
	if not (media and media.Register) then return end
	for _, kind in ipairs(Supplies.KINDS) do
		pcall(media.Register, media, "sound", "ShamanAlerts: " .. kind.text, MEDIA .. kind.sound)
	end
	for _, sound in ipairs(ns.SOUNDS or {}) do
		if type(sound.file) == "string" and sound.file:find(ADDON_NAME, 1, true) then
			pcall(media.Register, media, "sound", "ShamanAlerts: " .. sound.name, sound.file)
		end
	end
end

-------------------------------------------------------------------------------
-- Anzeige
-------------------------------------------------------------------------------

local function fontPath()
	if ns.resolveFont then
		local ok, path = pcall(ns.resolveFont)
		if ok and type(path) == "string" and path ~= "" then return path end
	end
	return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function setFont(fontString, size)
	local ok = pcall(fontString.SetFont, fontString, fontPath(), size, "THICKOUTLINE")
	if not ok or not fontString:GetFont() then
		pcall(fontString.SetFont, fontString, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "THICKOUTLINE")
	end
end

local function line(index)
	local fontString = lines[index]
	if not fontString then
		fontString = frame:CreateFontString(nil, "OVERLAY")
		fontString:SetPoint("TOP", index == 1 and frame or lines[index - 1], index == 1 and "TOP" or "BOTTOM", 0, index == 1 and 0 or -4)
		fontString.icon = frame:CreateTexture(nil, "ARTWORK")
		fontString.icon:SetPoint("RIGHT", fontString, "LEFT", -8, 0)
		if fontString.icon.SetTexCoord then fontString.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
		lines[index] = fontString
	end
	setFont(fontString, settings.size)
	fontString.icon:SetSize(settings.size, settings.size)
	return fontString
end

local function position()
	frame:ClearAllPoints()
	frame:SetPoint("TOP", UIParent, "TOP", settings.x, settings.y)
end

function Supplies.Update()
	if not (settings and frame) then return end
	local now = GetTime and GetTime() or 0
	if (loading or now < quietUntil) and not (unlocked or (testUntil and now < testUntil)) then return end
	local shown, due = {}, nil
	local pulsing = false
	warning = {}
	for _, kind in ipairs(Supplies.KINDS) do
		local entry = Supplies.Check(kind)
		local stored = kindSettings(kind)
		local allowed = (entry.low or entry.weak) and Supplies.Allowed(kind)
		local state = allowed and (entry.low and "low" or "weak") or nil
		if wasLow[kind.key] ~= state then
			played[kind.key], lastPlayed[kind.key] = 0, nil -- neu aufgetaucht: Klänge zählen von vorn
		end
		wasLow[kind.key] = state
		if state then
			-- Ein Hinweis auf eine schwächere Sorte klingt nur einmal.
			local limit = state == "weak" and 1 or stored.repeats
			local count, last = played[kind.key] or 0, lastPlayed[kind.key]
			local done = limit > 0 and count >= limit
			if state == "low" then warning[#warning + 1] = entry end
			-- Auf Wunsch verschwindet der Text, wenn nach dem letzten Klang der Abstand um ist.
			local hidden = done and stored.hideAfter and (not settings.sound or last == nil or now - last >= stored.interval)
			if not hidden then
				shown[#shown + 1] = entry
				if state == "low" then pulsing = true end
			end
			if not done and not due and (last == nil or now - last >= stored.interval) then due = kind end
		end
	end
	active = next(wasLow) ~= nil
	local preview = unlocked or (testUntil and now < testUntil)
	if preview and #shown == 0 then
		for _, kind in ipairs(Supplies.KINDS) do
			if kindSettings(kind).enabled then shown[#shown + 1] = Supplies.Check(kind) end
		end
		if #shown == 0 then shown[1] = Supplies.Check(Supplies.KINDS[1]) end
	end

	local width = 200
	for index, entry in ipairs(shown) do
		local fontString = line(index)
		local color = entry.kind.color
		if entry.weak then
			-- nur ein Hinweis: kleiner und blasser
			local size = math.max(14, math.floor(settings.size * 0.55 + 0.5))
			setFont(fontString, size)
			fontString.icon:SetSize(size, size)
			fontString:SetTextColor(color[1] * 0.8, color[2] * 0.8, color[3] * 0.8)
			fontString:SetText(L["%s: only a weaker kind left (%d)"]:format(entry.kind.label, entry.older or 0))
		else
			fontString:SetTextColor(color[1], color[2], color[3])
			fontString:SetText(entry.kind.text)
		end
		fontString:Show()
		fontString.icon:SetTexture(Supplies.Icon(entry.kind))
		fontString.icon:SetShown(settings.icons)
		width = math.max(width, fontString:GetStringWidth() or 0)
	end
	for index = #shown + 1, #lines do
		lines[index]:Hide()
		lines[index].icon:Hide()
	end

	local parts = {}
	for _, entry in ipairs(shown) do parts[#parts + 1] = detailText(entry) end
	local subSize = math.max(12, math.floor(settings.size / 3 + 0.5))
	setFont(detail, subSize)
	detail:ClearAllPoints()
	detail:SetPoint("TOP", lines[#shown] or frame, #shown > 0 and "BOTTOM" or "TOP", 0, -6)
	detail:SetText(unlocked and L["Drag to move, then click \"Place\" again"] or table.concat(parts, "   ·   "))
	frame:SetSize(width, math.max(1, #shown) * (settings.size + 4) + subSize + 16)
	frame.backdrop:SetShown(unlocked)
	frame:EnableMouse(unlocked)
	frame:SetShown(#shown > 0)

	-- Pulsieren nur bei echten Warnungen, nicht bei Hinweisen
	if frame.pulse then
		pcall(function()
			if settings.pulse and (pulsing or preview) then
				if not frame.pulse:IsPlaying() then frame.pulse:Play() end
			else
				frame.pulse:Stop()
				frame:SetAlpha(1)
			end
		end)
	end

	-- Klang: sofort, wenn etwas neu knapp wird, danach im Abstand des Vorrats,
	-- so oft wie eingestellt. Zwei Vorräte klingen nicht gleichzeitig.
	if settings.sound and due and (lastAny == nil or now - lastAny >= SOUND_GAP) then
		played[due.key] = (played[due.key] or 0) + 1
		lastPlayed[due.key] = now
		playKind(due)
	end
	if ns.RefreshSupplyOptions then ns.RefreshSupplyOptions() end
end

function Supplies.Warnings() return warning end

function Supplies.SetUnlocked(value)
	unlocked = value and true or false
	if frame then frame:SetMovable(unlocked) end
	Supplies.Update()
end

function Supplies.IsUnlocked() return unlocked end

-- Zeigt die eingeschalteten Warnungen sechs Sekunden lang, mit dem Klang der ersten.
-- Für einen Vorrat allein: nur sein Klang.
function Supplies.Test()
	testUntil = (GetTime and GetTime() or 0) + 6
	Supplies.Update()
	for _, kind in ipairs(Supplies.KINDS) do
		if kindSettings(kind).enabled then
			playKind(kind)
			break
		end
	end
	if C_Timer and C_Timer.After then C_Timer.After(6.1, Supplies.Update) end
end

function Supplies.Reset()
	if not settings then return end
	local custom = type(settings.custom) == "table" and settings.custom or {}
	for key in pairs(settings) do settings[key] = nil end
	for key, value in pairs(DEFAULTS) do settings[key] = value end
	settings.kinds = {}
	settings.custom = custom -- eigene Vorräte bleiben, nur ihre Einstellungen gehen zurück
	rebuildKinds()
	for _, kind in ipairs(Supplies.KINDS) do kindSettings(kind) end
	if frame then position() end
	Supplies.Update()
end

-------------------------------------------------------------------------------
-- Start
-------------------------------------------------------------------------------

function Supplies.Init(db)
	db.supplies = type(db.supplies) == "table" and db.supplies or {}
	settings = db.supplies
	for key, value in pairs(DEFAULTS) do
		if type(settings[key]) ~= type(value) then settings[key] = value end
	end
	if type(settings.kinds) ~= "table" then settings.kinds = {} end
	if type(settings.custom) ~= "table" then settings.custom = {} end
	rebuildKinds()
	for _, kind in ipairs(Supplies.KINDS) do kindSettings(kind) end
	settings.combatHide, settings.instanceHide, settings.interval = nil, nil, nil -- steht jetzt je Vorrat
	Supplies.settings = settings

	if not frame then
		registerSounds()
		frame = CreateFrame("Frame", "ShamanAlertsSupplies", UIParent)
		frame:SetFrameStrata("HIGH")
		frame:SetClampedToScreen(true)
		frame:RegisterForDrag("LeftButton")
		frame:Hide()
		frame.backdrop = frame:CreateTexture(nil, "BACKGROUND")
		frame.backdrop:SetAllPoints(frame)
		frame.backdrop:SetColorTexture(0.2, 0.6, 1, 0.25)
		frame.backdrop:Hide()
		detail = frame:CreateFontString(nil, "OVERLAY")
		detail:SetTextColor(1, 0.85, 0.2)
		frame:SetScript("OnDragStart", function(self)
			if unlocked then self:StartMoving() end
		end)
		frame:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			local centerX = self:GetCenter()
			local parentX = UIParent:GetCenter()
			local top, parentTop = self:GetTop(), UIParent:GetTop()
			if centerX and parentX and top and parentTop then
				settings.x = math.floor(centerX - parentX + 0.5)
				settings.y = math.floor(top - parentTop + 0.5)
			end
			position()
		end)
		-- Pulsieren wie ein Alarm
		local ok, pulse = pcall(frame.CreateAnimationGroup, frame)
		if ok and pulse then
			pcall(function()
				pulse:SetLooping("BOUNCE")
				local fade = pulse:CreateAnimation("Alpha")
				fade:SetFromAlpha(1)
				fade:SetToAlpha(0.35)
				fade:SetDuration(0.6)
				fade:SetSmoothing("IN_OUT")
				frame:SetScript("OnHide", function() pulse:Stop() end)
				frame.pulse = pulse
			end)
		end
		-- Solange gewarnt wird, kommt der Klang im eingestellten Abstand wieder.
		local elapsedSum = 0
		frame:SetScript("OnUpdate", function(_, elapsed)
			elapsedSum = elapsedSum + (elapsed or 0)
			if elapsedSum < 1 then return end
			elapsedSum = 0
			if active then Supplies.Update() end
		end)
		local events = CreateFrame("Frame")
		for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
			"UPDATE_INVENTORY_DURABILITY", "SPELLS_CHANGED", "ZONE_CHANGED_NEW_AREA", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
			"PLAYER_LEAVING_WORLD", "LOADING_SCREEN_ENABLED", "LOADING_SCREEN_DISABLED" }) do
			pcall(events.RegisterEvent, events, event)
		end
		events:SetScript("OnEvent", function(_, event)
			if event == "PLAYER_LEAVING_WORLD" or event == "LOADING_SCREEN_ENABLED" then
				loading = true
				return
			end
			if event == "PLAYER_ENTERING_WORLD" or event == "LOADING_SCREEN_DISABLED" then
				loading = false
				quietUntil = (GetTime and GetTime() or 0) + QUIET_AFTER_LOADING
				if ready and C_Timer and C_Timer.After then C_Timer.After(QUIET_AFTER_LOADING + 0.1, Supplies.Update) end
			end
			if event == "PLAYER_REGEN_ENABLED" and C_Timer and C_Timer.After then
				-- Kampfende kommt beim Betreten eines Dungeons oft vor dem Ladebildschirm:
				-- kurz warten, ob einer folgt.
				C_Timer.After(1.5, Supplies.Update)
				return
			end
			if event == "PLAYER_ENTERING_WORLD" and not ready then
				-- Das Gepäck ist beim Betreten der Welt noch nicht ganz geladen.
				if C_Timer and C_Timer.After then
					C_Timer.After(QUIET_AFTER_LOADING + 0.1, function()
						ready = true
						Supplies.Update()
					end)
				else
					ready = true
				end
				return
			end
			if event == "PLAYER_LEVEL_UP" and C_Timer and C_Timer.After then
				C_Timer.After(1, Supplies.Update) -- die neue Stufe steht erst einen Moment später fest
				return
			end
			Supplies.Update()
		end)
		Supplies.frame = frame
	end
	position()
	Supplies.Update()
end

-- Für die Tests: als wäre das Gepäck geladen
function Supplies.MarkReady()
	ready = true
end

-------------------------------------------------------------------------------
-- Befehle: /sha supplies
-------------------------------------------------------------------------------

local function onOff(word)
	word = (word or ""):lower()
	if word == "on" or word == "an" or word == "1" or word == "true" then return true end
	if word == "off" or word == "aus" or word == "0" or word == "false" then return false end
	return nil
end

-- "immer wieder alle 10 s" oder "3× alle 10 s"
function Supplies.RepeatText(stored)
	local times = stored.repeats == 0 and L["again and again"] or ("%d×"):format(stored.repeats)
	return L["sound %s, every %d s"]:format(times, stored.interval)
end

local function printStatus()
	local msg = ns.msg or print
	msg(L["Supplies: sounds %s, pulsing %s."], settings.sound and L["on"] or L["off"], settings.pulse and L["on"] or L["off"])
	for _, kind in ipairs(Supplies.KINDS) do
		local entry, stored = Supplies.Check(kind), kindSettings(kind)
		local state
		if not stored.enabled then
			state = L["off"]
		elseif not entry.applies then
			state = L["not for this character or level"]
		elseif entry.low then
			state = L["warns now"]
		elseif entry.weak then
			state = L["only a weaker kind"]
		else
			state = L["enough"]
		end
		local limit = kind.missing and "" or (kind.percent and (" (" .. L["at most"] .. " " .. stored.at .. " %)") or (" (" .. L["at most"] .. " " .. stored.at .. ")"))
		local places = {}
		if stored.combatHide then places[#places + 1] = L["Only out of combat"] end
		if stored.instanceHide then places[#places + 1] = L["Not in instances"] end
		places[#places + 1] = Supplies.RepeatText(stored)
		if stored.hideAfter then places[#places + 1] = L["text hides after the last sound"] end
		state = state .. " (" .. table.concat(places, ", ") .. ")"
		msg("  %s [%s]%s: %s – %s", kind.text, kind.key, limit, entry.applies and detailText(entry) or "-", state)
	end
end

local function supplyCommand(rest)
	if not settings then return end
	local msg = ns.msg or print
	local word, value = (rest or ""):match("^%s*(%S*)%s*(.-)%s*$")
	word = (word or ""):lower()
	if word == "" or word == "status" then
		return printStatus()
	elseif word == "test" then
		return Supplies.Test()
	elseif word == "move" or word == "place" then
		Supplies.SetUnlocked(not unlocked)
		return msg(unlocked and L["Supplies warning unlocked: drag it with the mouse, then /sha supplies move again."] or L["Supplies warning locked."])
	elseif word == "sound" or word == "pulse" or word == "combat" or word == "instances" then
		local flag = onOff(value)
		if flag == nil then return msg(L["Please enter on or off."]) end
		if word == "sound" or word == "pulse" then
			settings[word] = flag
		else
			-- ohne Vorrat: für alle auf einmal
			for _, kind in ipairs(Supplies.KINDS) do
				kindSettings(kind)[word == "combat" and "combatHide" or "instanceHide"] = not flag
			end
		end
		Supplies.Update()
		return printStatus()
	end
	if word == "new" then
		local kind = Supplies.AddCustom(value)
		if not kind then return msg(L["At most %d own supplies."], Supplies.MAX_CUSTOM) end
		msg(L["Own supply \"%s\" created (key %s). Add its items with /sha supplies %s items <names, IDs or links>."], kind.text, kind.key, kind.key)
		if ns.RefreshOptions then ns.RefreshOptions() end
		return
	elseif word == "delete" then
		local kind = Supplies.KINDS[(value or ""):lower()]
		if not (kind and kind.custom) then return msg(L["Only own supplies can be deleted."]) end
		Supplies.DeleteCustom(kind)
		if ns.RefreshOptions then ns.RefreshOptions() end
		return msg(L["Own supply \"%s\" deleted."], kind.text)
	end
	local kind = Supplies.KINDS[word]
	if not kind then
		local keys = {}
		for _, entry in ipairs(Supplies.KINDS) do keys[#keys + 1] = entry.key end
		return msg(L["Unknown supply. Available: %s."], table.concat(keys, ", "))
	end
	local stored = kindSettings(kind)
	local textOption, textValue = (value or ""):match("^(%a+)%s+(.+)$")
	if kind.custom and textOption and (textOption:lower() == "items" or textOption:lower() == "text") then
		if textOption:lower() == "text" then
			Supplies.SetCustomText(kind, textValue)
		else
			local missing = Supplies.SetCustomItems(kind, textValue)
			if #missing > 0 then msg(L["Not found: %s. Enter an ID or a link instead (shift-click the item)."], table.concat(missing, ", ")) end
		end
		if ns.RefreshOptions then ns.RefreshOptions() end
		return printStatus()
	end
	local option, optionValue = (value or ""):lower():match("^(%a+)%s+(%S+)$")
	if option == "combat" or option == "instances" or option == "hide" then
		local flag = onOff(optionValue)
		if flag == nil then return msg(L["Please enter on or off."]) end
		if option == "hide" then
			stored.hideAfter = flag
		else
			stored[option == "combat" and "combatHide" or "instanceHide"] = not flag
		end
		Supplies.Update()
		return printStatus()
	elseif option == "repeat" or option == "interval" then
		local number = tonumber(optionValue)
		local low, high = option == "repeat" and 0 or 5, option == "repeat" and 20 or 120
		if not number or number < low or number > high then return msg(L["Please enter a number from %d to %d."], low, high) end
		stored[option == "repeat" and "repeats" or "interval"] = math.floor(number)
		Supplies.Update()
		return printStatus()
	end
	local flag, number = onOff(value), tonumber((value or ""):gsub(",", "."), 10)
	if flag ~= nil then
		stored.enabled = flag
	elseif number and not kind.missing and number >= 0 and number <= kind.max then
		stored.at = math.floor(number)
		stored.enabled = true
	else
		return msg(kind.missing and L["Please enter on or off."] or (L["Please enter on, off or a number from 0 to %d."]):format(kind.max))
	end
	Supplies.Update()
	printStatus()
end

if ns.commands then
	ns.commands.supplies = supplyCommand
	ns.commands.vorrat = supplyCommand
	ns.commands["vorräte"] = supplyCommand
end

Supplies.internals = { DRINKS = DRINKS, HEALING = HEALING, MANA = MANA, FOOD = FOOD, BANDAGES = BANDAGES, LADDER = LADDER, TOTEMS = TOTEMS, countFor = countFor }
