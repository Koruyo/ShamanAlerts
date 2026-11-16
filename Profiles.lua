-- ShamanAlerts: Profile und Austausch der Einstellungen
--
-- Ein Profil ist ein gespeicherter Stand aller Einstellungen: Alarme, eigene
-- Alarme, Totem-Leiste und Schrift. Speichern legt eine Kopie ab, Laden
-- ersetzt die jetzigen Einstellungen durch diese Kopie.
--
-- Der Austausch schreibt denselben Stand als Text, den man kopieren und bei
-- jemand anderem einfügen kann. Im Text steht nur, was von den
-- Voreinstellungen abweicht; deshalb bleibt er kurz. Beim Einlesen wird nichts
-- ausgeführt: Der Text wird Zeichen für Zeichen gelesen, und übernommen wird
-- nur, was das Addon kennt.
local _, ns = ...
local L = ns.L

local P = {}
ns.Profiles = P

local PREFIX = "!SHA1!"
local MAX_TEXT = 200000 -- längere Texte sind sicher kein Export dieses Addons
local MAX_NAME = 32
local MAX_PROFILES = 30
-- Diese Felder stehen immer im Text. Fehlten sie, hielte das Addon den Stand
-- für einen aus einer alten Version und würde Werte umstellen.
local ALWAYS = { display = true, textureRevision = true, leadRevision = true, placeRevision = true }

-------------------------------------------------------------------------------
-- Text aus Tabellen und zurück
-------------------------------------------------------------------------------

local function sameValue(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for key, value in pairs(a) do
		if not sameValue(value, b[key]) then return false end
	end
	for key in pairs(b) do
		if a[key] == nil then return false end
	end
	return true
end

local function quote(text)
	return '"' .. text:gsub('[%c"\\]', function(char)
		if char == '"' or char == "\\" then return "\\" .. char end
		return ("\\%03d"):format(char:byte())
	end) .. '"'
end

local function serialize(value, out)
	local kind = type(value)
	if kind == "table" then
		local keys = {}
		for key in pairs(value) do
			if type(key) == "number" or type(key) == "string" then keys[#keys + 1] = key end
		end
		table.sort(keys, function(a, b)
			if type(a) ~= type(b) then return type(a) == "number" end
			return a < b
		end)
		out[#out + 1] = "{"
		for _, key in ipairs(keys) do
			local item = value[key]
			local itemKind = type(item)
			if itemKind == "table" or itemKind == "string" or itemKind == "number" or itemKind == "boolean" then
				if type(key) == "number" then
					out[#out + 1] = "[" .. ("%.14g"):format(key) .. "]="
				elseif key:find("^[%a_][%w_]*$") then
					out[#out + 1] = key .. "="
				else
					out[#out + 1] = "[" .. quote(key) .. "]="
				end
				serialize(item, out)
				out[#out + 1] = ";"
			end
		end
		out[#out + 1] = "}"
	elseif kind == "string" then
		out[#out + 1] = quote(value)
	elseif kind == "number" then
		out[#out + 1] = ("%.14g"):format(value)
	else
		out[#out + 1] = value and "true" or "false"
	end
end

-- Liest einen Wert ab "position" und gibt ihn mit der nächsten Position zurück.
-- Bei einem Fehler: nil und der Grund.
local parseValue

local function parseString(text, position)
	local parts = {}
	local index = position + 1
	while true do
		local char = text:sub(index, index)
		if char == "" then return nil, L["text ends in the middle of a value"] end
		if char == '"' then return table.concat(parts), index + 1 end
		if char == "\\" then
			local digits = text:match("^%d%d%d", index + 1)
			if digits then
				parts[#parts + 1] = string.char(math.min(255, tonumber(digits)))
				index = index + 4
			else
				parts[#parts + 1] = text:sub(index + 1, index + 1)
				index = index + 2
			end
		else
			local plain = text:match('^[^"\\]+', index)
			parts[#parts + 1] = plain
			index = index + #plain
		end
	end
end

local function parseTable(text, position, depth)
	if depth > 6 then return nil, L["nested too deeply"] end
	local result = {}
	local index = position + 1
	while true do
		local char = text:sub(index, index)
		if char == "}" then return result, index + 1 end
		local key
		if char == "[" then
			local value, after = parseValue(text, index + 1, depth)
			if value == nil then return nil, after end
			if text:sub(after, after + 1) ~= "]=" then return nil, L["key not closed"] end
			key, index = value, after + 2
		else
			local name = text:match("^[%a_][%w_]*", index)
			if not name or text:sub(index + #name, index + #name) ~= "=" then return nil, L["unexpected character at position "] .. index end
			key, index = name, index + #name + 1
		end
		if type(key) ~= "string" and type(key) ~= "number" then return nil, L["invalid key"] end
		local value, after = parseValue(text, index, depth)
		if value == nil then return nil, after end
		result[key] = value
		if text:sub(after, after) ~= ";" then return nil, L["separator missing at position "] .. after end
		index = after + 1
	end
end

function parseValue(text, position, depth)
	local char = text:sub(position, position)
	if char == "{" then return parseTable(text, position, depth + 1) end
	if char == '"' then return parseString(text, position) end
	if text:sub(position, position + 3) == "true" then return true, position + 4 end
	if text:sub(position, position + 4) == "false" then return false, position + 5 end
	local number = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", position)
	if number and tonumber(number) then return tonumber(number), position + #number end
	return nil, L["unexpected character at position "] .. position
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_VALUE = {}
for index = 1, #B64 do B64_VALUE[B64:byte(index)] = index - 1 end

local function encode64(text)
	local out = {}
	for index = 1, #text, 3 do
		local a, b, c = text:byte(index, index + 2)
		local number = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1 = math.floor(number / 262144)
		local c2 = math.floor(number / 4096) % 64
		local c3 = math.floor(number / 64) % 64
		local c4 = number % 64
		out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
			.. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
	end
	return table.concat(out)
end

local function decode64(text)
	text = text:gsub("=+$", "")
	local out = {}
	for index = 1, #text, 4 do
		local v1, v2, v3, v4 = B64_VALUE[text:byte(index)], B64_VALUE[text:byte(index + 1) or 0], B64_VALUE[text:byte(index + 2) or 0], B64_VALUE[text:byte(index + 3) or 0]
		if not v1 or not v2 then return nil end
		if (text:byte(index + 2) and not v3) or (text:byte(index + 3) and not v4) then return nil end
		local number = v1 * 262144 + v2 * 4096 + (v3 or 0) * 64 + (v4 or 0)
		out[#out + 1] = string.char(math.floor(number / 65536))
		if v3 then out[#out + 1] = string.char(math.floor(number / 256) % 256) end
		if v4 then out[#out + 1] = string.char(number % 256) end
	end
	return table.concat(out)
end

-------------------------------------------------------------------------------
-- Der Stand, auf das Nötige gekürzt
-------------------------------------------------------------------------------

-- Lässt bei den eingebauten Alarmen und der Totem-Leiste weg, was der
-- Voreinstellung entspricht.
local function compact(snapshot)
	local result = { alerts = {}, custom = snapshot.custom, font = snapshot.font, totems = {} }
	local builtIn = {}
	for _, def in ipairs(ns.ALERT_DEFS) do
		builtIn[def.key] = true
		local stored, kept = snapshot.alerts[def.key], {}
		if type(stored) == "table" then
			for key, value in pairs(stored) do
				if ALWAYS[key] or not sameValue(value, def.defaults[key]) then kept[key] = value end
			end
		end
		result.alerts[def.key] = kept
	end
	for key, stored in pairs(snapshot.alerts) do
		if not builtIn[key] then result.alerts[key] = stored end
	end
	local defaults = ns.Totems and ns.Totems.DEFAULTS or {}
	for key, value in pairs(snapshot.totems or {}) do
		if not sameValue(value, defaults[key]) then result.totems[key] = value end
	end
	return result
end

function P.Export()
	local out = {}
	serialize(compact(ns.takeSnapshot()), out)
	return PREFIX .. encode64(table.concat(out))
end

-- Liest einen Export und gibt den Stand zurück, ohne ihn zu übernehmen.
function P.Read(text)
	if type(text) ~= "string" then return nil, L["No text."] end
	text = text:gsub("%s+", "")
	if text == "" then return nil, L["The field is empty. Paste an export with Ctrl+V first."] end
	if #text > MAX_TEXT then return nil, L["The text is too long for a ShamanAlerts export."] end
	if text:sub(1, #PREFIX) ~= PREFIX then return nil, L["This is not a ShamanAlerts export. An export starts with "] .. PREFIX end
	local raw = decode64(text:sub(#PREFIX + 1))
	if not raw then return nil, L["The text is damaged or was not copied completely."] end
	local value, after = parseValue(raw, 1, 0)
	if type(value) ~= "table" then return nil, L["The text is damaged ("] .. tostring(after) .. ")." end
	if after ~= #raw + 1 then return nil, L["The text is damaged or was not copied completely."] end
	if type(value.alerts) ~= "table" then return nil, L["There are no ShamanAlerts settings in it."] end
	return value
end

function P.Import(text)
	local snapshot, problem = P.Read(text)
	if not snapshot then return false, problem end
	local ok, reason = ns.applySnapshot(snapshot)
	if not ok then return false, reason end
	ns.db.profileName = nil
	return true
end

-------------------------------------------------------------------------------
-- Profile
-------------------------------------------------------------------------------

local function store()
	local db = ns.db
	db.profiles = type(db.profiles) == "table" and db.profiles or {}
	return db.profiles
end

local function cleanName(name)
	name = tostring(name or ""):gsub("[%c|]", ""):match("^%s*(.-)%s*$")
	return name:sub(1, MAX_NAME)
end

function P.List()
	local names = {}
	for name, saved in pairs(store()) do
		if type(name) == "string" and type(saved) == "table" then names[#names + 1] = name end
	end
	table.sort(names, function(a, b) return a:lower() < b:lower() end)
	return names
end

function P.Current() return ns.db and ns.db.profileName or nil end

function P.Save(name)
	name = cleanName(name)
	if name == "" then return false, L["Please enter a name for the profile."] end
	local profiles = store()
	if not profiles[name] and #P.List() >= MAX_PROFILES then return false, (L["More than %d profiles are not possible. Please delete one first."]):format(MAX_PROFILES) end
	local existed = profiles[name] ~= nil
	profiles[name] = ns.takeSnapshot()
	ns.db.profileName = name
	return true, existed and (L["Profile \"%s\" overwritten."]):format(name) or (L["Profile \"%s\" saved."]):format(name)
end

function P.Load(name)
	name = cleanName(name)
	local saved = store()[name]
	if type(saved) ~= "table" then return false, (L["There is no profile \"%s\"."]):format(name) end
	local ok, reason = ns.applySnapshot(saved)
	if not ok then return false, reason end
	ns.db.profileName = name
	return true, (L["Profile \"%s\" loaded."]):format(name)
end

function P.Delete(name)
	name = cleanName(name)
	local profiles = store()
	if profiles[name] == nil then return false, (L["There is no profile \"%s\"."]):format(name) end
	profiles[name] = nil
	if ns.db.profileName == name then ns.db.profileName = nil end
	return true, (L["Profile \"%s\" deleted."]):format(name)
end

-- /sha profile [save|load|delete <Name>] oder /sha profile list
ns.commands.profile = function(rest)
	local action, name = (rest or ""):match("^(%S*)%s*(.-)$")
	action = action:lower()
	local run = (action == "save" or action == "speichern") and P.Save
		or (action == "load" or action == "laden") and P.Load
		or (action == "delete" or action == "löschen" or action == "loeschen") and P.Delete
	if run then
		local _, message = run(name)
		ns.msg(message)
		if ns.RefreshOptions then ns.RefreshOptions(true) end
	elseif action == "list" or action == "liste" then
		local names = P.List()
		ns.msg(#names == 0 and L["No profile saved yet."] or (L["Profiles: "] .. table.concat(names, ", ") .. "."))
	elseif ns.ShowOptionsPage then
		ns.ShowOptionsPage("profiles")
	end
end
ns.commands.profil = ns.commands.profile
ns.commands.export = function() if ns.ShowOptionsPage then ns.ShowOptionsPage("profiles", "export") end end
ns.commands.import = function() if ns.ShowOptionsPage then ns.ShowOptionsPage("profiles") end end

-- für Tests
P.internals = { serialize = serialize, parseValue = parseValue, encode64 = encode64, decode64 = decode64, compact = compact, PREFIX = PREFIX }
