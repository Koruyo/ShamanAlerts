-- ShamanAlerts: Totem-Leiste
--
-- Zeigt die gestellten Totems mit ihrer Restzeit, als Symbole nebeneinander
-- oder als Balken untereinander. Die Leiste lässt sich frei platzieren.
--
-- Die Restzeit liefert Forever als "Dauer-Objekt" (GetTotemDuration). Das Addon
-- rechnet damit nicht selbst, sondern reicht es an eine Abklingzeit-Anzeige und
-- einen Balken weiter, die das Spiel herunterzählt. Das funktioniert auch im
-- Kampf.
--
-- An der Leiste hängt außerdem eine Reihe kleiner Symbole für Totems mit
-- Abklingzeit (Erdung, Erdbindung, Steinklaue ...): hell heißt bereit, grau mit
-- Zahl heißt Abklingzeit. Welche Zauber dort stehen, ist einstellbar.

local ADDON_NAME, ns = ...
local L = ns.L

local Totems = {}
ns.Totems = Totems

local ART = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Art\\"

-- Reihenfolge der Totem-Plätze im klassischen Spiel. "art" ist das gemalte
-- Totem, das einen leeren Platz und die Beispiele beim Platzieren darstellt.
local ELEMENTS = {
	{ name = L["Fire"], color = { 1, 0.42, 0.1 }, art = ART .. "totem_fire.tga" },
	{ name = L["Earth"], color = { 0.62, 0.45, 0.25 }, art = ART .. "totem_earth.tga" },
	{ name = L["Water"], color = { 0.25, 0.6, 1 }, art = ART .. "totem_water.tga" },
	{ name = L["Air"], color = { 0.75, 0.9, 1 }, art = ART .. "totem_air.tga" },
}

local DEFAULTS = {
	enabled = true,
	x = 4, y = -361, -- Mitte der Leiste, Abstand von der Bildschirmmitte
	style = "icons", -- "icons" = Symbole in einer Reihe, "bars" = Balken untereinander
	growth = "RIGHT", -- Reihenfolge der Plätze: RIGHT, LEFT, DOWN, UP
	iconSize = 36,
	fontSize = 12, -- wie die Abklingzeit-Zahlen der Aktionsleisten
	spacing = 6,
	barWidth = 120,
	showNames = false,
	showEmpty = false, -- leere Plätze als blasses, graues Totem des Elements zeigen
	alpha = 1,
	cooldowns = true, -- Abklingzeiten wichtiger Totems als kleine Symbole an der Leiste
	cdSize = 26,
	cdSide = "TOP", -- wo die Symbole an der Leiste hängen: BOTTOM, TOP, LEFT, RIGHT
	-- Namen aus dem Zauberbuch, durch Komma getrennt. Unbekannte Zauber bleiben weg.
	cdSpells = L["Grounding Totem, Earthbind Totem, Mana Tide Totem"],
	hotkeys = false, -- die Taste des Zaubers auf den Symbolen der Abklingzeit-Reihe zeigen
}

-- In anderen Sprachen als Deutsch und Englisch kommen die Namen der drei
-- Totems aus dem Spiel selbst (über ihre IDs), damit die Reihe sicher gefunden wird.
do
	local lookup = C_Spell and C_Spell.GetSpellName
	if lookup and ns.locale ~= "deDE" and ns.locale ~= "enUS" and ns.locale ~= "enGB" then
		local names = {}
		for _, id in ipairs({ 8177, 2484, 16190 }) do
			local ok, name = pcall(lookup, id)
			if ok and type(name) == "string" and name ~= "" then names[#names + 1] = name end
		end
		if #names == 3 then DEFAULTS.cdSpells = table.concat(names, ", ") end
	end
end

local GROWTH_NAMES = { RIGHT = L["to the right"], LEFT = L["to the left"], DOWN = L["downwards"], UP = L["upwards"] }
local GROWTH_ORDER = { "RIGHT", "LEFT", "DOWN", "UP" }
local STYLE_NAMES = { icons = L["Icons"], bars = L["Bars"] }
local CD_SIDE_NAMES = { BOTTOM = L["below the bar"], TOP = L["above the bar"], LEFT = L["to its left"], RIGHT = L["to its right"] }
local CD_SIDE_ORDER = { "BOTTOM", "TOP", "LEFT", "RIGHT" }
local CD_GAP = 4 -- Abstand der Symbole untereinander
local CD_OFFSET = 6 -- Abstand zur Leiste
-- Für englische Clients: die Voreinstellung nennt die deutschen Namen.
local CD_ALIASES = {
	["totem der erdung"] = "Grounding Totem",
	["totem der erdbindung"] = "Earthbind Totem",
	["totem der steinklaue"] = "Stoneclaw Totem",
	["totem der manaflut"] = "Mana Tide Totem",
}

local settings
local frame
local slots = {}
local cdIcons = {} -- die Symbole der Abklingzeit-Reihe
local cdSpells = {} -- was sie gerade zeigen: { id, name, icon } oder ein Beispiel
local unlocked = false

local function isSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) or false
end

local function slotCount()
	local count = (GetNumTotemSlots and GetNumTotemSlots()) or MAX_TOTEMS or 4
	if isSecret(count) or type(count) ~= "number" or count < 1 then count = 4 end
	return math.min(count, #ELEMENTS)
end

-------------------------------------------------------------------------------
-- Aufbau
-------------------------------------------------------------------------------

local function createSlot(index)
	local element = ELEMENTS[index]
	local slot = CreateFrame("Frame", nil, frame)
	slot:EnableMouse(false)

	-- gemaltes Totem des Elements für einen leeren Platz
	slot.empty = slot:CreateTexture(nil, "BACKGROUND")
	slot.empty:SetTexture(element.art)

	-- dünner dunkler Rahmen hinter Symbol und Balken
	slot.iconBorder = slot:CreateTexture(nil, "BACKGROUND", nil, -1)
	slot.iconBorder:SetColorTexture(0, 0, 0, 1)
	slot.icon = slot:CreateTexture(nil, "ARTWORK")
	slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	-- Die Abklingzeit-Anzeige zählt die Restzeit als Zahl herunter.
	slot.cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
	slot.cooldown:EnableMouse(false)
	slot.cooldown:SetDrawEdge(false)
	slot.cooldown:SetDrawBling(false)
	slot.cooldown:SetReverse(true)
	slot.cooldown:SetHideCountdownNumbers(false)

	slot.bar = CreateFrame("StatusBar", nil, slot)
	slot.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	slot.bar:SetStatusBarColor(element.color[1], element.color[2], element.color[3], 0.9)
	slot.bar:SetMinMaxValues(0, 1)
	slot.bar:SetValue(0)
	slot.barBackground = slot.bar:CreateTexture(nil, "BACKGROUND")
	slot.barBackground:SetPoint("TOPLEFT", slot.bar, "TOPLEFT", -1, 1)
	slot.barBackground:SetPoint("BOTTOMRIGHT", slot.bar, "BOTTOMRIGHT", 1, -1)
	slot.barBackground:SetColorTexture(0, 0, 0, 0.7)

	-- Texte liegen über Balken und Abklingzeit
	slot.textLayer = CreateFrame("Frame", nil, slot)
	slot.textLayer:SetAllPoints(slot)
	slot.textLayer:SetFrameLevel((slot:GetFrameLevel() or 0) + 5)
	slot.textLayer:EnableMouse(false)
	slot.name = slot.textLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	slot.name:SetWordWrap(false)
	slots[index] = slot
	return slot
end

-- Der Text, in den die Abklingzeit-Anzeige ihre Zahl schreibt
local function countdownText(cooldown)
	if cooldown.GetCountdownFontString then
		local text = cooldown:GetCountdownFontString()
		if text then return text end
	end
	if cooldown.GetRegions then
		for _, region in ipairs({ cooldown:GetRegions() }) do
			if region and region.GetObjectType and region:GetObjectType() == "FontString" then return region end
		end
	end
	return nil
end

-- Größe, Lage und Aussehen aller Plätze nach den Einstellungen
local function layout()
	local size, spacing = settings.iconSize, settings.spacing
	local bars = settings.style == "bars"
	local count = slotCount()
	local slotWidth = bars and (size + 4 + settings.barWidth) or size
	local slotHeight = size
	-- Balken stehen immer untereinander oder übereinander.
	local growth = settings.growth
	if bars and (growth == "RIGHT" or growth == "LEFT") then growth = "DOWN" end
	local horizontal = growth == "RIGHT" or growth == "LEFT"
	local direction = (growth == "LEFT" or growth == "DOWN") and -1 or 1
	local stepX = horizontal and (slotWidth + spacing) or 0
	local stepY = horizontal and 0 or (slotHeight + spacing)
	local totalWidth = slotWidth + stepX * (count - 1)
	local totalHeight = slotHeight + stepY * (count - 1)

	frame:SetSize(totalWidth, totalHeight)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", settings.x, settings.y)
	frame:SetAlpha(settings.alpha)

	for index = 1, #ELEMENTS do
		local slot = slots[index] or createSlot(index)
		if index > count then
			slot:Hide()
		else
			slot:Show()
			slot:SetSize(slotWidth, slotHeight)
			-- Der erste Platz liegt an dem Ende, von dem aus die Leiste wächst.
			local offsetX = (index - 1) * stepX * direction - (totalWidth - slotWidth) / 2 * direction
			local offsetY = (index - 1) * stepY * direction - (totalHeight - slotHeight) / 2 * direction
			slot:ClearAllPoints()
			slot:SetPoint("CENTER", frame, "CENTER", horizontal and offsetX or 0, horizontal and 0 or offsetY)

			slot.icon:ClearAllPoints()
			slot.icon:SetSize(size, size)
			slot.icon:SetPoint("LEFT", slot, "LEFT", 0, 0)
			slot.iconBorder:ClearAllPoints()
			slot.iconBorder:SetPoint("TOPLEFT", slot.icon, "TOPLEFT", -1, 1)
			slot.iconBorder:SetPoint("BOTTOMRIGHT", slot.icon, "BOTTOMRIGHT", 1, -1)
			slot.empty:ClearAllPoints()
			slot.empty:SetAllPoints(slot.icon)
			slot.cooldown:ClearAllPoints()
			slot.cooldown:SetAllPoints(slot.icon)
			slot.cooldown:SetDrawSwipe(not bars)

			slot.bar:SetShown(bars)
			slot.bar:ClearAllPoints()
			slot.bar:SetPoint("LEFT", slot.icon, "RIGHT", 4, 0)
			slot.bar:SetSize(settings.barWidth, size)

			slot.name:ClearAllPoints()
			if bars then
				slot.name:SetPoint("LEFT", slot.bar, "LEFT", 4, 0)
				slot.name:SetWidth(math.max(10, settings.barWidth - 44))
				slot.name:SetJustifyH("LEFT")
			else
				slot.name:SetPoint("TOP", slot.icon, "BOTTOM", 0, -2)
				slot.name:SetWidth(size + spacing + 20)
				slot.name:SetJustifyH("CENTER")
			end
			slot.name:SetShown(settings.showNames or bars)

			ns.applyFont(slot.name, math.max(6, settings.fontSize - 2))

			-- Die herunterzählende Zahl: mittig im Symbol oder rechts im Balken
			local timer = countdownText(slot.cooldown)
			if timer then
				ns.applyFont(timer, settings.fontSize)
				if timer:GetParent() ~= slot.textLayer then timer:SetParent(slot.textLayer) end
				timer:ClearAllPoints()
				if bars then
					timer:SetPoint("RIGHT", slot.bar, "RIGHT", -4, 0)
				else
					timer:SetPoint("CENTER", slot.icon, "CENTER", 0, 0)
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Abklingzeiten wichtiger Totems
-------------------------------------------------------------------------------

-- Die eingestellten Namen, ohne Leerraum und ohne Doppelte
local function cooldownNames()
	local names, seen = {}, {}
	for name in tostring(settings.cdSpells or ""):gmatch("[^,;\n]+") do
		name = name:match("^%s*(.-)%s*$")
		if name ~= "" and not seen[name:lower()] then
			seen[name:lower()] = true
			names[#names + 1] = name
		end
	end
	return names
end

-- Sucht einen Zauber über seinen Namen. Das findet nur Zauber aus dem eigenen
-- Zauberbuch, unbekannte fallen also von selbst weg. Eine Zahl gilt als ID.
local function lookupSpell(name)
	local lookup = C_Spell and C_Spell.GetSpellInfo
	if not lookup then return nil end
	for _, candidate in ipairs({ tonumber(name) or name, CD_ALIASES[name:lower()] }) do
		local ok, info = pcall(lookup, candidate)
		if ok and type(info) == "table" and type(info.spellID) == "number" and not isSecret(info.spellID) then
			return info.spellID, info.name, info.iconID
		end
	end
	return nil
end

-- Liest die Liste neu aus dem Zauberbuch. Liefert true, wenn sie sich geändert hat.
local function refreshCooldownSpells()
	local list, seen = {}, {}
	if settings.cooldowns then
		for _, name in ipairs(cooldownNames()) do
			local id, spellName, icon = lookupSpell(name)
			if id and not seen[id] then
				seen[id] = true
				list[#list + 1] = { id = id, name = (not isSecret(spellName) and spellName) or name, icon = icon }
			end
		end
		-- Beim Platzieren ohne bekannten Zauber: drei Beispiele, damit man die Reihe sieht
		if unlocked and #list == 0 then
			for index = 2, 4 do list[#list + 1] = { sample = index, name = ELEMENTS[index].name, icon = ELEMENTS[index].art } end
		end
	end
	local changed = #list ~= #cdSpells
	for index, spell in ipairs(list) do
		local old = cdSpells[index]
		if not old or old.id ~= spell.id or old.sample ~= spell.sample then changed = true end
	end
	cdSpells = list
	Totems.cdSpells = list
	return changed
end

local function createCooldownIcon(index)
	local icon = CreateFrame("Frame", nil, frame)
	icon:EnableMouse(false)
	icon.border = icon:CreateTexture(nil, "BACKGROUND")
	icon.border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
	icon.border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
	icon.border:SetColorTexture(0, 0, 0, 1)
	icon.icon = icon:CreateTexture(nil, "ARTWORK")
	icon.icon:SetAllPoints(icon)
	icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
	icon.cooldown:SetAllPoints(icon)
	icon.cooldown:EnableMouse(false)
	icon.cooldown:SetDrawEdge(false)
	icon.cooldown:SetHideCountdownNumbers(false)
	-- Läuft die Abklingzeit ab, wird das Symbol wieder hell.
	icon.cooldown:SetScript("OnCooldownDone", function() Totems.UpdateCooldowns() end)
	-- Die Taste des Zaubers steht oben rechts, über der Abklingzeit-Anzeige.
	icon.textLayer = CreateFrame("Frame", nil, icon)
	icon.textLayer:SetAllPoints(icon)
	icon.textLayer:EnableMouse(false)
	if icon.textLayer.SetFrameLevel and icon.cooldown.GetFrameLevel then icon.textLayer:SetFrameLevel((icon.cooldown:GetFrameLevel() or 1) + 2) end
	icon.hotkey = icon.textLayer:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	icon.hotkey:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 1, -1)
	cdIcons[index] = icon
	return icon
end

-- Größe und Lage der Reihe: mittig an einer Seite der Leiste
local function layoutCooldowns()
	local size, count = settings.cdSize, #cdSpells
	local side = settings.cdSide
	local total = count * size + math.max(0, count - 1) * CD_GAP
	-- Totem-Namen stehen unter den Symbolen der Leiste: Platz lassen.
	local namesBelow = settings.showNames and settings.style ~= "bars"
	for index = 1, math.max(count, #cdIcons) do
		local icon = cdIcons[index] or createCooldownIcon(index)
		if index > count then
			icon:Hide()
		else
			local along = (index - 1) * (size + CD_GAP) - (total - size) / 2
			icon:SetSize(size, size)
			icon:ClearAllPoints()
			if side == "TOP" then
				icon:SetPoint("BOTTOM", frame, "TOP", along, CD_OFFSET)
			elseif side == "LEFT" then
				icon:SetPoint("RIGHT", frame, "LEFT", -CD_OFFSET, -along)
			elseif side == "RIGHT" then
				icon:SetPoint("LEFT", frame, "RIGHT", CD_OFFSET, -along)
			else
				icon:SetPoint("TOP", frame, "BOTTOM", along, -(CD_OFFSET + (namesBelow and 14 or 0)))
			end
			local spell = cdSpells[index]
			icon.icon:SetTexture(spell.icon)
			if spell.sample then icon.icon:SetTexCoord(0, 1, 0, 1) else icon.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
			icon.border:SetShown(not spell.sample)
			local timer = countdownText(icon.cooldown)
			if timer then ns.applyFont(timer, math.max(6, math.floor(settings.fontSize * size / settings.iconSize + 0.5))) end
			ns.applyFont(icon.hotkey, math.max(6, math.floor(size * 0.4 + 0.5)))
			if icon.hotkey.SetTextColor then icon.hotkey:SetTextColor(1, 1, 1) end -- weiß wie auf den Aktionsleisten
			icon.hotkey:SetText(settings.hotkeys and not spell.sample and ns.Hotkeys and ns.Hotkeys.ForSpell(spell.id, spell.name) or "")
			icon:Show()
		end
	end
	-- Der Hinweis beim Verschieben rückt über eine Reihe, die oben hängt.
	frame.label:ClearAllPoints()
	frame.label:SetPoint("BOTTOM", frame, "TOP", 0, 6 + ((side == "TOP" and count > 0) and (size + CD_OFFSET) or 0))
end

-- Läuft für den Zauber eine echte Abklingzeit? Die globale Abklingzeit zählt
-- nicht. Liefert zusätzlich, was die Anzeige herunterzählen soll: ein
-- Dauer-Objekt oder Start und Länge. nil heißt: Das Spiel verrät es nicht.
local function cooldownState(id)
	local lookup = C_Spell and C_Spell.GetSpellCooldown
	if not lookup then return nil end
	local ok, info = pcall(lookup, id)
	if not ok then return nil end
	if info == nil then return false end
	if isSecret(info) or type(info) ~= "table" then return nil end
	local active, onGCD = info.isActive, info.isOnGCD
	if isSecret(active) or isSecret(onGCD) then return nil end
	local start, length = info.startTime, info.duration
	local readable = not isSecret(start) and not isSecret(length) and type(start) == "number" and type(length) == "number"
	if active == nil then
		-- ältere Schnittstelle: Start und Dauer als Zahlen
		if not readable then return nil end
		if length > 1.6 and start > 0 then return true, nil, start, length end
		return false
	end
	if not active or onGCD then return false end
	local getDuration = C_Spell.GetSpellCooldownDuration
	if getDuration then
		local durationOK, duration = pcall(getDuration, id)
		if durationOK and duration ~= nil then return true, duration end
	end
	if readable then return true, nil, start, length end
	return true
end

function Totems.UpdateCooldowns()
	if not frame then return end
	for index, spell in ipairs(cdSpells) do
		local icon = cdIcons[index]
		if icon then
			local running, duration, start, length
			if spell.sample then
				-- Beispiel zum Platzieren: das mittlere Symbol läuft gerade ab
				if spell.sample == 3 then running, start, length = true, GetTime() - 5, 15 else running = false end
			else
				running, duration, start, length = cooldownState(spell.id)
			end
			if running ~= nil then -- unbekannt: so lassen, wie es ist
				if running and duration then
					icon.cooldown:SetCooldownFromDurationObject(duration)
				elseif running and start then
					icon.cooldown:SetCooldown(start, length)
				else
					icon.cooldown:Clear()
				end
				icon.icon:SetDesaturated(running and true or false)
				icon.icon:SetAlpha(running and 0.6 or 1)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Zustand der Totems
-------------------------------------------------------------------------------

local function showSample(slot, index)
	-- Beispiel zum Platzieren: läuft je Platz unterschiedlich lange
	local length = 30 + index * 15
	slot.icon:SetTexture(nil)
	slot.iconBorder:Hide()
	slot.empty:Show()
	slot.empty:SetDesaturated(false)
	slot.cooldown:SetCooldown(GetTime() - 5, length)
	slot.bar:SetMinMaxValues(0, length)
	slot.bar:SetValue(length - 5)
	slot.name:SetText(ELEMENTS[index].name)
	slot:SetAlpha(1)
end

local function updateSlot(index)
	local slot = slots[index]
	if not slot then return end
	if unlocked then return showSample(slot, index) end

	local active, name, start, length, icon, duration = false
	if GetTotemDuration then
		local ok, object = pcall(GetTotemDuration, index)
		duration = ok and object or nil
		active = duration ~= nil
		if active and GetTotemInfo then
			local infoOK, _, totemName, _, _, totemIcon = pcall(GetTotemInfo, index)
			if infoOK then name, icon = totemName, totemIcon end
		end
	elseif GetTotemInfo then
		-- Ältere Schnittstelle mit gewöhnlichen Zahlen
		local ok, has, totemName, startTime, totalTime, totemIcon = pcall(GetTotemInfo, index)
		if ok and not isSecret(has) and has and not isSecret(totalTime) and not isSecret(startTime)
			and type(totalTime) == "number" and totalTime > 0 then
			active, name, start, length, icon = true, totemName, startTime, totalTime, totemIcon
		end
	end

	if active then
		slot.icon:SetTexture(icon)
		slot.iconBorder:Show()
		slot.empty:Hide()
		if duration then
			slot.cooldown:SetCooldownFromDurationObject(duration)
			if settings.style == "bars" and slot.bar.SetTimerDuration then
				local immediate = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate
				local remaining = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime
				pcall(slot.bar.SetTimerDuration, slot.bar, duration, immediate, remaining)
			end
		else
			slot.cooldown:SetCooldown(start, length)
			slot.bar:SetMinMaxValues(0, length)
			slot.bar:SetValue(math.max(0, start + length - GetTime()))
		end
		slot.name:SetText(name or "")
		slot:SetAlpha(1)
	else
		slot.icon:SetTexture(nil)
		slot.cooldown:Clear()
		slot.bar:SetMinMaxValues(0, 1)
		slot.bar:SetValue(0)
		slot.name:SetText(settings.showEmpty and ELEMENTS[index].name or "")
		slot.iconBorder:Hide()
		slot.empty:Show()
		slot.empty:SetDesaturated(true) -- grau und blass: hier steht gerade kein Totem
		slot:SetAlpha(settings.showEmpty and 0.6 or 0)
	end
end

-- Steht auf dem Platz gerade ein Totem (1 = Feuer)? nil heißt: Das verrät das
-- Spiel nicht.
function Totems.IsActive(index)
	if GetTotemDuration then
		local ok, object = pcall(GetTotemDuration, index)
		if not ok then return nil end
		return object ~= nil
	end
	if GetTotemInfo then
		local ok, has, _, _, totalTime = pcall(GetTotemInfo, index)
		if not ok or isSecret(has) then return nil end
		if not has then return false end
		if isSecret(totalTime) or type(totalTime) ~= "number" then return nil end
		return totalTime > 0
	end
	return nil
end

function Totems.Update()
	if not frame then return end
	local visible = (settings.enabled and ns.state.isShaman) or unlocked
	frame:SetShown(visible and true or false)
	if not visible then return end
	for index = 1, slotCount() do updateSlot(index) end
	Totems.UpdateCooldowns()
end

-- Nach jeder Änderung der Einstellungen
function Totems.Apply()
	if not frame then return end
	refreshCooldownSpells()
	layout()
	layoutCooldowns()
	Totems.Update()
end

-- Tastenbelegung oder Aktionsleisten haben sich geändert.
function Totems.RefreshHotkeys()
	if frame and settings and settings.hotkeys then layoutCooldowns() end
end

-------------------------------------------------------------------------------
-- Verschieben
-------------------------------------------------------------------------------

-- Entsperrt zeigt die Leiste Beispiel-Totems und lässt sich mit der Maus ziehen.
function Totems.SetUnlocked(value)
	if not frame then return end
	unlocked = value and true or false
	frame:SetMovable(unlocked)
	frame:EnableMouse(unlocked)
	frame.label:SetShown(unlocked)
	frame.backdrop:SetShown(unlocked)
	Totems.Apply()
end

function Totems.IsUnlocked() return unlocked end

-------------------------------------------------------------------------------
-- Start, Befehle
-------------------------------------------------------------------------------

function Totems.Init(db)
	db.totems = type(db.totems) == "table" and db.totems or {}
	settings = db.totems
	for key, value in pairs(DEFAULTS) do
		if settings[key] == nil or type(settings[key]) ~= type(value) then settings[key] = value end
	end
	if not GROWTH_NAMES[settings.growth] then settings.growth = DEFAULTS.growth end
	if not STYLE_NAMES[settings.style] then settings.style = DEFAULTS.style end
	if not CD_SIDE_NAMES[settings.cdSide] then settings.cdSide = DEFAULTS.cdSide end
	Totems.settings = settings

	if not frame then
		frame = CreateFrame("Frame", "ShamanAlertsTotemBar", UIParent)
		frame:SetFrameStrata("MEDIUM")
		frame:SetClampedToScreen(true)
		frame:RegisterForDrag("LeftButton")
		frame.backdrop = frame:CreateTexture(nil, "BACKGROUND")
		frame.backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
		frame.backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -4)
		frame.backdrop:SetColorTexture(1, 1, 1, 0.12)
		frame.backdrop:Hide()
		frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		frame.label:SetPoint("BOTTOM", frame, "TOP", 0, 6)
		frame.label:SetText(L["Totem bar: drag to move"])
		frame.label:Hide()
		frame:SetScript("OnDragStart", function(self)
			if unlocked then self:StartMoving() end
		end)
		frame:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			local centerX, centerY = self:GetCenter()
			local parentX, parentY = UIParent:GetCenter()
			if centerX and parentX then
				settings.x = math.floor(centerX - parentX + 0.5)
				settings.y = math.floor(centerY - parentY + 0.5)
			end
			Totems.Apply()
			if ns.RefreshTotemOptions then ns.RefreshTotemOptions() end
		end)
		frame:RegisterEvent("PLAYER_TOTEM_UPDATE")
		frame:RegisterEvent("PLAYER_ENTERING_WORLD")
		frame:RegisterEvent("SPELLS_CHANGED")
		frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		frame:SetScript("OnEvent", function(_, event)
			if event == "SPELL_UPDATE_COOLDOWN" then
				Totems.UpdateCooldowns()
			elseif event == "SPELLS_CHANGED" then
				-- neu gelernt oder verlernt: Die Reihe richtet sich nach dem Zauberbuch.
				if refreshCooldownSpells() then
					layoutCooldowns()
					if ns.RefreshTotemOptions then ns.RefreshTotemOptions() end
				end
				Totems.UpdateCooldowns()
			elseif event == "PLAYER_ENTERING_WORLD" then
				Totems.Apply() -- beim Start ist das Zauberbuch manchmal noch leer
			else
				Totems.Update()
			end
		end)
	end
	Totems.Apply()
end

-- Ersetzt alle Einstellungen der Leiste, etwa beim Laden eines Profils.
-- Fehlendes und Werte der falschen Art fallen auf die Voreinstellung zurück.
function Totems.Load(values)
	if not settings then return end
	for key in pairs(settings) do settings[key] = nil end
	for key, value in pairs(DEFAULTS) do
		local wanted
		if type(values) == "table" then wanted = values[key] end
		if wanted ~= nil and type(wanted) == type(value) then settings[key] = wanted else settings[key] = value end
	end
	if not GROWTH_NAMES[settings.growth] then settings.growth = DEFAULTS.growth end
	if not STYLE_NAMES[settings.style] then settings.style = DEFAULTS.style end
	if not CD_SIDE_NAMES[settings.cdSide] then settings.cdSide = DEFAULTS.cdSide end
	Totems.Apply()
end

function Totems.Reset()
	for key in pairs(settings) do settings[key] = nil end
	for key, value in pairs(DEFAULTS) do settings[key] = value end
	Totems.Apply()
end

local function toNumber(text)
	return tonumber(((text or ""):gsub(",", ".")))
end

local function toBoolean(text, current)
	text = (text or ""):lower()
	if text == "on" or text == "an" or text == "1" or text == "ja" then return true end
	if text == "off" or text == "aus" or text == "0" or text == "nein" then return false end
	return not current
end

local NUMBER_FIELDS = {
	size = { "iconSize", 16, 80 },
	fontsize = { "fontSize", 6, 40 },
	spacing = { "spacing", 0, 40 },
	barwidth = { "barWidth", 40, 400 },
	x = { "x", -4000, 4000 },
	y = { "y", -4000, 4000 },
	alpha = { "alpha", 0.1, 1 },
	cdsize = { "cdSize", 12, 60 },
}
local BOOLEAN_FIELDS = { enabled = "enabled", names = "showNames", empty = "showEmpty", cooldowns = "cooldowns", hotkeys = "hotkeys" }
local CD_SIDE_WORDS = { bottom = "BOTTOM", unten = "BOTTOM", top = "TOP", oben = "TOP", left = "LEFT", links = "LEFT", right = "RIGHT", rechts = "RIGHT" }

-- Setzt ein Feld aus dem Befehl /sha totem <Feld> <Wert>. Liefert false und einen Hinweis bei Fehlern.
function Totems.SetField(field, value)
	field = (field or ""):lower()
	if NUMBER_FIELDS[field] then
		local key, minimum, maximum = NUMBER_FIELDS[field][1], NUMBER_FIELDS[field][2], NUMBER_FIELDS[field][3]
		local number = toNumber(value)
		if not number or number < minimum or number > maximum then
			return false, (L["Please enter a number from %s to %s."]):format(minimum, maximum)
		end
		settings[key] = key == "alpha" and number or math.floor(number + 0.5)
	elseif BOOLEAN_FIELDS[field] then
		settings[BOOLEAN_FIELDS[field]] = toBoolean(value, settings[BOOLEAN_FIELDS[field]])
	elseif field == "style" then
		local wanted = (value or ""):lower()
		if wanted == "symbole" then wanted = "icons" elseif wanted == "balken" then wanted = "bars" end
		if not STYLE_NAMES[wanted] then return false, L["Allowed: icons or bars."] end
		settings.style = wanted
	elseif field == "growth" then
		local wanted = (value or ""):upper()
		if not GROWTH_NAMES[wanted] then return false, L["Allowed: right, left, down, up."] end
		settings.growth = wanted
	elseif field == "cdside" then
		local wanted = CD_SIDE_WORDS[(value or ""):lower()]
		if not wanted then return false, L["Allowed: bottom, top, left, right."] end
		settings.cdSide = wanted
	elseif field == "cdspells" then
		-- leer = wieder die Voreinstellung
		local list = (value or ""):match("^%s*(.-)%s*$")
		settings.cdSpells = list ~= "" and list or DEFAULTS.cdSpells
	else
		return false, L["Fields: enabled, style, growth, size, fontsize, spacing, barwidth, names, empty, alpha, x, y, cooldowns, cdsize, cdside, cdspells, hotkeys."]
	end
	Totems.Apply()
	if ns.RefreshTotemOptions then ns.RefreshTotemOptions() end
	return true
end

function Totems.Status()
	local active = {}
	for index = 1, slotCount() do
		local has = false
		if GetTotemDuration then
			local ok, object = pcall(GetTotemDuration, index)
			has = ok and object ~= nil
		end
		active[#active + 1] = ELEMENTS[index].name .. (has and L[" standing"] or L[" empty"])
	end
	ns.msg(L["Totem bar: enabled %s, style %s, position %d/%d, interface for totem duration: %s."],
		settings.enabled and L["yes"] or L["no"], STYLE_NAMES[settings.style], settings.x, settings.y,
		GetTotemDuration and L["available"] or (GetTotemInfo and L["only the older one"] or L["missing"]))
	ns.msg("  %s.", table.concat(active, ", "))
	ns.msg(L["  Cooldowns: %s."], Totems.CooldownSummary())
end

-- Welche der eingestellten Zauber das Zauberbuch kennt, als Text
function Totems.CooldownSummary()
	if not settings.cooldowns then return L["switched off"] end
	local known = {}
	for _, name in ipairs(cooldownNames()) do
		local id, spellName = lookupSpell(name)
		if id then known[#known + 1] = (not isSecret(spellName) and spellName) or name end
	end
	if #known == 0 then return L["none of the configured spells is in your spellbook"] end
	return table.concat(known, ", ")
end

Totems.slots = slots
Totems.ELEMENTS = ELEMENTS
Totems.GROWTH_NAMES = GROWTH_NAMES
Totems.GROWTH_ORDER = GROWTH_ORDER
Totems.STYLE_NAMES = STYLE_NAMES
Totems.CD_SIDE_NAMES = CD_SIDE_NAMES
Totems.CD_SIDE_ORDER = CD_SIDE_ORDER
Totems.DEFAULTS = DEFAULTS
Totems.cdIcons = cdIcons
Totems.cdSpells = cdSpells

ns.commands.totem = function(rest)
	local field, value = (rest or ""):match("^(%S*)%s*(.-)$")
	if field == "" then
		if ns.ToggleTotemOptions then return ns.ToggleTotemOptions() end
		return Totems.Status()
	end
	if field:lower() == "reset" then
		Totems.Reset()
		if ns.RefreshTotemOptions then ns.RefreshTotemOptions() end
		return ns.msg(L["Totem bar reset."])
	end
	local ok, problem = Totems.SetField(field, value)
	if ok then ns.msg(L["Totem bar: %s changed."], field:lower()) else ns.msg(problem) end
end
ns.commands.totems = ns.commands.totem
