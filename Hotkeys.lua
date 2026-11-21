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

-- Die Zauber, die im Text eines Makros stehen: aus #showtooltip, /cast, /use
-- und /castsequence, ohne Bedingungen in eckigen Klammern.
function H.MacroSpells(body)
	local names = {}
	if type(body) ~= "string" then return names end
	for line in body:gmatch("[^\r\n]+") do
		local command, rest = line:match("^%s*([#/]%a+)%s+(.+)$")
		command = command and command:lower()
		if command == "#showtooltip" or command == "#show" or command == "/cast" or command == "/use" or command == "/castsequence" or command == "/wirken" or command == "/zauber" then
			for piece in rest:gmatch("[^;]+") do
				piece = piece:gsub("%b[]", "")
				if command == "/castsequence" then piece = piece:gsub("reset=%S+", "") end
				for name in piece:gmatch("[^,]+") do
					name = name:gsub("%(.-%)%s*$", ""):gsub("^[%s!]+", ""):gsub("%s+$", "")
					if name ~= "" then names[#names + 1] = name end
				end
			end
		end
	end
	return names
end

-- Der Text des Makros auf einem Platz. Der Client nennt je nach Version die
-- Nummer des Makros oder nur seinen Namen.
local function macroBody(slot, id)
	if type(GetMacroBody) ~= "function" then return nil end
	local index
	if type(GetMacroInfo) == "function" then
		local ok, name = pcall(GetMacroInfo, id)
		if ok and type(name) == "string" and not isSecret(name) then index = id end
	end
	if not index and type(GetActionText) == "function" and type(GetMacroIndexByName) == "function" then
		local ok, name = pcall(GetActionText, slot)
		if ok and type(name) == "string" and not isSecret(name) and name ~= "" then
			local found, byName = pcall(GetMacroIndexByName, name)
			if found and type(byName) == "number" and byName > 0 then index = byName end
		end
	end
	if not index then return nil end
	local ok, body = pcall(GetMacroBody, index)
	if ok and type(body) == "string" and not isSecret(body) then return body end
	return nil
end

-- Was ein Platz der Aktionsleiste auslöst: die Zauber-ID (oder nil) und, bei
-- einem Makro, die Zaubernamen aus seinem Text.
local function slotSpell(slot)
	local ok, kind, id, subType = pcall(GetActionInfo, slot)
	if not ok or isSecret(kind) or isSecret(id) or type(id) ~= "number" then return nil end
	if kind == "spell" then return id end
	if kind == "macro" then
		local spell
		if subType == "spell" then
			spell = id -- neuere Clients nennen gleich den Zauber des Makros
		elseif type(GetMacroSpell) == "function" then
			local found, result = pcall(GetMacroSpell, id)
			if found and type(result) == "number" and not isSecret(result) then spell = result end
		end
		return spell, H.MacroSpells(macroBody(slot, id))
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
				local id, names = slotSpell(first + index)
				if id then
					if cache.ids[id] == nil then cache.ids[id] = text end
					local name = spellName(id)
					if name and cache.names[name] == nil then cache.names[name] = text end
				end
				for _, name in ipairs(names or {}) do
					if cache.names[name] == nil then cache.names[name] = text end
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
