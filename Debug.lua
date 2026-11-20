-- ShamanAlerts: Diagnose-Aufzeichnung (/sha debug)
--
-- Schreibt eine halbe Minute lang zweimal pro Sekunde auf, wie das Addon jeden
-- Alarm gerade bewertet und was das Spiel dabei verrät. Die Aufzeichnung landet
-- in den gespeicherten Einstellungen und lässt sich nach einem /reload von
-- außen lesen. Geheime Werte werden nur als "<geheim>" vermerkt, nie benutzt.

local ADDON_NAME, ns = ...
local L = ns.L

local DURATION, INTERVAL = 30, 0.5
local recording

local function isSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) or false
end

local function show(value)
	if isSecret(value) then return "<geheim>" end
	local kind = type(value)
	if kind == "nil" then return "nil" end
	if kind == "number" then
		if value == math.floor(value) then return ("%d"):format(value) end
		return ("%.1f"):format(value)
	end
	if kind == "boolean" or kind == "string" then return tostring(value) end
	return "<" .. kind .. ">"
end

-- Ruft eine Funktion geschützt auf und liefert das erste Ergebnis als Text.
local function try(fn, ...)
	if type(fn) ~= "function" then return "<fehlt>" end
	local ok, result = pcall(fn, ...)
	if not ok then return "<Fehler: " .. tostring(result):sub(1, 70) .. ">" end
	return show(result)
end

local function frameInfo(frame)
	return ("shown=%s visible=%s alpha=%s left=%s width=%s"):format(
		try(frame.IsShown, frame), try(frame.IsVisible, frame), try(frame.GetAlpha, frame), try(frame.GetLeft, frame), try(frame.GetWidth, frame))
end

local function describe(alert)
	local internals = ns.internals
	local settings, def, current = alert.s, alert.def, alert.current
	local parts = { ("%s [%s] aktiv=%s gebaut=%s"):format(alert.key, def.kind, tostring(settings.enabled), tostring(current ~= nil)) }
	if alert.initError then parts[#parts + 1] = "FEHLER=" .. tostring(alert.initError) end
	if alert.runError then parts[#parts + 1] = "LAUFFEHLER=" .. tostring(alert.runError) end
	if not settings.enabled then return table.concat(parts, " ") end

	parts[#parts + 1] = "bedingung=" .. try(internals.conditionMet, alert)
	parts[#parts + 1] = "bekannt=" .. try(internals.spellKnown, alert)
	if settings.needUsable then parts[#parts + 1] = "wirkbar=" .. try(internals.spellUsable, alert) end
	if settings.needPlayer then parts[#parts + 1] = "spieler=" .. try(internals.targetIsPlayer) end
	if settings.noPlayer then parts[#parts + 1] = "nichtspieler=" .. try(internals.targetIsPlayer, false) end
	if settings.bossAlways then parts[#parts + 1] = "boss=" .. try(internals.targetIsBoss) end
	if (settings.placeLike or "") ~= "" then parts[#parts + 1] = "lage=" .. tostring(settings.placeLike) end
	if (settings.behind or "") ~= "" then parts[#parts + 1] = ("hinter=%s zurück=%s"):format(settings.behind, try(internals.standsBehind, alert)) end
	if settings.needAggro then parts[#parts + 1] = "aggro=" .. try(internals.hasAggro) end
	if def.kind == "ready" then parts[#parts + 1] = ("gegnerbedingung=%s ab=%s umkreis=%s feuertotem-bedingung=%s"):format(show(settings.needEnemies), show(settings.minEnemies), show(settings.enemyRange), show(settings.needFireTotem)) end
	if settings.needEnemies then parts[#parts + 1] = "gegner=" .. try(internals.nearbyEnemies, settings.enemyRange) end
	if settings.needFireTotem then parts[#parts + 1] = "feuertotem=" .. try(ns.Totems and ns.Totems.IsActive, 1) end
	if settings.needCasting then parts[#parts + 1] = "zielzaubert=" .. try(internals.targetCasting) end
	if settings.castFirst then parts[#parts + 1] = ("zaubervorrang=%s zielzaubert=%s"):format(try(ns.castPriority, alert), try(internals.targetCasting)) end

	if def.kind == "ready" then
		local id = internals.readySpell(alert)
		parts[#parts + 1] = "zauber=" .. show(id)
		if id and C_Spell and C_Spell.GetSpellCooldown then
			local ok, info = pcall(C_Spell.GetSpellCooldown, id)
			if not ok then
				parts[#parts + 1] = "cd=<Fehler>"
			elseif isSecret(info) or type(info) ~= "table" then
				parts[#parts + 1] = "cd=" .. show(info)
			else
				parts[#parts + 1] = ("cd.isActive=%s cd.isOnGCD=%s cd.duration=%s"):format(show(info.isActive), show(info.isOnGCD), show(info.duration))
			end
		end
		parts[#parts + 1] = "bereit=" .. try(internals.spellReady, alert)
		parts[#parts + 1] = "reichweite=" .. try(internals.spellInRange, alert)
		local partner = internals.partnerOf(alert)
		if partner then
			parts[#parts + 1] = ("vorrang=%s will=%s"):format(partner.key, try(internals.partnerWants, partner))
		end
	elseif def.kind == "missing" and settings.needReady then
		parts[#parts + 1] = ("zauber=%s bereit=%s vorlauf=%s"):format(show(internals.readySpell(alert)), try(internals.spellReady, alert), show(settings.lead))
	elseif def.kind == "weapon" then
		parts[#parts + 1] = "fehlt=" .. show(alert.weaponMissing)
	end
	-- Früh auffrischen: Stand der eigenen Uhr, beim Fehlt-Alarm und bei dem Alarm, der hinter ihm zurücksteht
	local refreshSource = def.kind == "missing" and alert or (def.kind == "ready" and internals.partnerOf(alert)) or nil
	if refreshSource and refreshSource.def.kind == "missing" and (refreshSource.s.refresh or 0) > 0 then
		parts[#parts + 1] = ("auffrischen=%s laufzeit=%s uhr=%s fällig=%s"):format(show(refreshSource.s.refresh), show(refreshSource.s.auraDuration),
			try(internals.refreshRemaining, refreshSource), try(internals.refreshDue, refreshSource))
	end

	if current then
		for index, container in ipairs(current.containers or {}) do
			if index <= 2 then
				parts[#parts + 1] = ("container%d: shown=%s width=%s gruppe=%s"):format(index,
					try(container.IsShown, container), try(container.GetWidth, container),
					try(container.GetAuraGroupFrameCount, container, "present"))
			end
		end
		for index, frame in ipairs(current.frames or {}) do
			if index <= 4 then parts[#parts + 1] = ("frame%d: %s"):format(index, frameInfo(frame)) end
		end
		if current.visuals and current.visuals[1] then parts[#parts + 1] = "grafik: " .. frameInfo(current.visuals[1]) end
		if current.gated then
			if current.gated.present[1] then parts[#parts + 1] = "grafik(aura da): " .. frameInfo(current.gated.present[1]) end
			if current.gated.low[1] then parts[#parts + 1] = "grafik(ziel schwach): " .. frameInfo(current.gated.low[1]) end
		end
	end
	return table.concat(parts, " ")
end

local function snapshot()
	local lines = {}
	lines[#lines + 1] = ("t=%.1f kampf=%s ziel=%s angreifbar=%s tot=%s auren_gesperrt=%s"):format(
		GetTime() - recording.startedAt, tostring(InCombatLockdown and InCombatLockdown() or false),
		try(UnitExists, "target"), try(UnitCanAttack, "player", "target"), try(UnitIsDeadOrGhost, "target"),
		try(C_Secrets and C_Secrets.ShouldAurasBeSecret))
	for _, alert in ipairs(ns.alerts) do
		local ok, text = pcall(describe, alert)
		lines[#lines + 1] = ok and text or (alert.key .. " <Fehler beim Beschreiben: " .. tostring(text):sub(1, 120) .. ">")
	end
	-- Zauber des Ziels: was das Spiel für den Unterbrechen-Alarm verrät
	local casts, castLine = pcall(ns.internals.castReport)
	lines[#lines + 1] = casts and castLine or ("zielzauber: <Fehler: " .. tostring(castLine):sub(1, 120) .. ">")
	-- Gegner im Umkreis: was das Spiel über die Namensplaketten verrät
	local ok, report = pcall(ns.internals.enemyReport)
	if ok and type(report) == "table" then
		for _, line in ipairs(report) do lines[#lines + 1] = line end
	else
		lines[#lines + 1] = "plaketten: <Fehler: " .. tostring(report):sub(1, 120) .. ">"
	end
	return lines
end

local function stop()
	if not recording then return end
	if recording.ticker and recording.ticker.Cancel then recording.ticker:Cancel() end
	local count = #recording.log.samples
	recording = nil
	ns.msg(L["Diagnostics done: %d samples stored. Type /reload now, then they can be read."], count)
end

ns.commands.debug = function(rest)
	if (rest or ""):lower() == "clear" then
		ns.db.debug = nil
		return ns.msg(L["Diagnostics recording deleted."])
	end
	if recording then return stop() end
	local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
	local _, build, _, interface = GetBuildInfo()
	local log = {
		version = tostring(version),
		client = tostring(interface) .. " / " .. tostring(build),
		started = date and date("%Y-%m-%d %H:%M:%S") or "?",
		samples = {},
	}
	ns.db.debug = log
	recording = { log = log, startedAt = GetTime() }
	local function sample()
		if not recording then return end
		log.samples[#log.samples + 1] = snapshot()
		if GetTime() - recording.startedAt >= DURATION then stop() end
	end
	sample()
	if C_Timer and C_Timer.NewTicker then
		recording.ticker = C_Timer.NewTicker(INTERVAL, sample)
	end
	ns.msg(L["Diagnostics run for %d seconds. Fight as usual now (apply Flame Shock, wait until Earth Shock is ready). Then /reload."], DURATION)
end
