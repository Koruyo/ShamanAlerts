-- ShamanAlerts: Tasten zu Zaubern
--
-- Sucht auf den Aktionsleisten, auf welcher Taste ein Zauber liegt, auch wenn
-- er in einem Makro steckt. Die Alarme zeigen die Taste auf Wunsch unter ihrer
-- Grafik, die Abklingzeit-Reihe der Totem-Leiste auf ihren Symbolen.
local ADDON, ns = ...

local H = {}
ns.Hotkeys = H

-- Leisten mit eigener Tastenbelegung: Befehl der Belegung, Platz vor dem
-- ersten Knopf. Die Hauptleiste richtet sich nach ihrer Seite.
local BARS = {
	{ "ACTIONBUTTON", 0, main = true },
	{ "MULTIACTIONBAR1BUTTON", 60 },
	{ "MULTIACTIONBAR2BUTTON", 48 },
	{ "MULTIACTIONBAR3BUTTON", 24 },
	{ "MULTIACTIONBAR4BUTTON", 36 },
	{ "MULTIACTIONBAR5BUTTON", 144 },
	{ "MULTIACTIONBAR6BUTTON", 156 },
	{ "MULTIACTIONBAR7BUTTON", 168 },
}

local cache -- { names = { [Name] = Taste }, ids = { [Zauber-ID] = Taste } }

local function isSecret(value)
	return type(issecretvalue) == "function" and issecretvalue(value) == true
end

local WORDS = {
	{ "MOUSEWHEELUP", "MWU" }, { "MOUSEWHEELDOWN", "MWD" }, { "BUTTON", "M" }, { "NUMPADDIVIDE", "N/" }, { "NUMPADMULTIPLY", "N*" },
	{ "NUMPADMINUS", "N-" }, { "NUMPADPLUS", "N+" }, { "NUMPADDECIMAL", "N." }, { "NUMPAD", "N" }, { "SPACE", "Spc" },
	{ "BACKSPACE", "Bks" }, { "DELETE", "Del" }, { "INSERT", "Ins" }, { "PAGEUP", "PgU" }, { "PAGEDOWN", "PgD" },
	{ "CAPSLOCK", "Cap" }, { "ESCAPE", "Esc" }, { "ENTER", "Ent" },
}

-- Kürzt eine Belegung für die Anzeige: "SHIFT-BUTTON4" wird "S-M4".
function H.Shorten(key)
	if type(key) ~= "string" or key == "" then return nil end
	local prefix = ""
	local rest = key:upper()
	for _, modifier in ipairs({ { "ALT%-", "A" }, { "CTRL%-", "C" }, { "SHIFT%-", "S" }, { "META%-", "M" } }) do
		local found
		rest, found = rest:gsub(modifier[1], "")
		if found > 0 then prefix = prefix .. modifier[2] end
	end
	for _, word in ipairs(WORDS) do
		if rest:sub(1, #word[1]) == word[1] then
			rest = word[2] .. rest:sub(#word[1] + 1)
			break
		end
	end
	if rest == "" then return nil end
	return prefix ~= "" and (prefix .. "-" .. rest) or rest
end

local function spellName(id)
	if not (C_Spell and C_Spell.GetSpellName) then return nil end
	local ok, name = pcall(C_Spell.GetSpellName, id)
	if ok and type(name) == "string" and not isSecret(name) and name ~= "" then return name end
	return nil
end

-- Platz vor dem ersten Knopf der Hauptleiste: ihre Seite, oder die Leiste einer Haltung.
local function mainOffset()
	local page = type(GetActionBarPage) == "function" and tonumber(GetActionBarPage()) or 1
	local bonus = type(GetBonusBarOffset) == "function" and tonumber(GetBonusBarOffset()) or 0
	if page == 1 and bonus > 0 then return (5 + bonus) * 12 end
	return (math.max(1, page) - 1) * 12
end

-- Der Zauber, den ein Platz der Aktionsleiste auslöst, auch über ein Makro.
local function slotSpell(slot)
	local ok, kind, id, subType = pcall(GetActionInfo, slot)
	if not ok or isSecret(kind) or isSecret(id) or type(id) ~= "number" then return nil end
	if kind == "spell" then return id end
	if kind == "macro" then
		if subType == "spell" then return id end -- neuere Clients nennen gleich den Zauber des Makros
		if type(GetMacroSpell) == "function" then
			local found, spell = pcall(GetMacroSpell, id)
			if found and type(spell) == "number" and not isSecret(spell) then return spell end
		end
	end
	return nil
end

local function scan()
	cache = { names = {}, ids = {} }
	if type(GetActionInfo) ~= "function" or type(GetBindingKey) ~= "function" then return end
	for _, bar in ipairs(BARS) do
		local first = bar.main and mainOffset() or bar[2]
		for index = 1, 12 do
			local ok, key = pcall(GetBindingKey, bar[1] .. index)
			local text = ok and not isSecret(key) and H.Shorten(key) or nil
			if text then
				local id = slotSpell(first + index)
				if id then
					if cache.ids[id] == nil then cache.ids[id] = text end
					local name = spellName(id)
					if name and cache.names[name] == nil then cache.names[name] = text end
				end
			end
		end
	end
end

-- Beim nächsten Nachfragen neu suchen und die Anzeigen auffrischen.
function H.Invalidate()
	cache = nil
	if ns.state then ns.state.hotkeysDirty = true end
end

-- Die Taste eines Zaubers, nach ID oder Namen. nil: liegt auf keiner Taste.
function H.ForSpell(id, name)
	if not cache then scan() end
	if id and cache.ids[id] then return cache.ids[id] end
	name = name or (id and spellName(id))
	return name and cache.names[name] or nil
end

-- Die Taste zu einer Menge von Namen und IDs (ein Alarm kennt oft mehrere Ränge).
function H.ForSpells(names, ids)
	if not cache then scan() end
	for id in pairs(ids or {}) do
		if cache.ids[id] then return cache.ids[id] end
	end
	for name in pairs(names or {}) do
		if cache.names[name] then return cache.names[name] end
	end
	for id in pairs(ids or {}) do
		local name = spellName(id)
		if name and cache.names[name] then return cache.names[name] end
	end
	return nil
end

local events = CreateFrame("Frame")
for _, name in ipairs({ "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_MACROS", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED" }) do
	pcall(events.RegisterEvent, events, name)
end
events:SetScript("OnEvent", H.Invalidate)
