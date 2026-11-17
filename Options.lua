-- ShamanAlerts: Optionsfenster (/sha)
--
-- Links steht die Liste aller Alarme, darunter die Seiten für die Totem-Leiste
-- und die Hilfe. Rechts gehört alles zum gewählten Alarm: oben Name,
-- Beschreibung und der Schalter "Aktiv", darunter fünf Reiter (Grafik,
-- Anordnung, Bedingungen, Sound, Zauber & Aura). Solange die Alarm-Seite offen
-- ist, zeigt eine Vorschau die Grafik des gewählten Alarms an ihrer Position.
-- Sie lässt sich mit der Maus verschieben. Änderungen wirken sofort auf die
-- Vorschau, die echte Anzeige wird kurz danach neu aufgebaut.

local ADDON_NAME, ns = ...
local L = ns.L

local FRAME_NAME = "ShamanAlertsOptionsFrame"
local WIDTH, HEIGHT = 1000, 700
local SIDE_X, SIDE_W = 14, 200 -- Liste links
local ROW_H, MAX_ROWS = 22, 18
local CONTENT_X = SIDE_X + SIDE_W + 20 -- Seite rechts
local CONTENT_W = WIDTH - CONTENT_X - 20
local PAGE_H = HEIGHT - 38
local BROWSER_W = 414
local THUMB, THUMB_GAP = 42, 4
local COLUMNS, ROWS = 9, 8
local PER_PAGE = COLUMNS * ROWS

local SOUND_MODE_TEXT = {
	off = L["Off"],
	threshold = L["At the threshold"],
	stack = L["On every stack"],
	removed = L["When it ends"],
	added = L["When it appears"],
}
local SOUND_MODE_TEXT_READY = { off = L["Off"], added = L["When ready"] }
local SOUND_HINT = {
	stacks = L["\"At the threshold\" only works if the game keeps the buff readable in combat. If it stays silent in combat, take \"On every stack\": the game plays that itself."],
	missing = L["\"When it ends\" is played by the game itself as soon as the spell ends. This also works in combat."],
	weapon = L["\"When it ends\" plays a sound as soon as a checked weapon loses its enchant."],
	active = L["Both sounds are played by the game itself: as soon as the aura appears or as soon as it ends. This also works in combat."],
	ready = L["\"When ready\" plays the sound at the moment the spell is really ready and all conditions are met. The lead time does not bring the sound forward."],
}

local frame
local widgets = {}
local browser = { category = 1, page = 1 }
local selected -- der Alarm, dessen Einstellungen das Fenster zeigt
local activePage, activeTab = "alerts", "look"
local pages = {} -- Name der Seite -> Frame
local view = {} -- Teile des Fensters, die beim Auffrischen gebraucht werden
local totemFrame, createTotemFrame -- weiter unten

local function cur() return selected.s end

local function changed()
	ns.applyPreview(selected)
	ns.scheduleBuild(selected)
end

-- Die Bausteine tragen ihre Widgets in die Liste des Fensters ein, das gerade
-- gebaut wird, und melden Änderungen an dessen Funktion.
local sink = { list = widgets, changed = changed }

-------------------------------------------------------------------------------
-- Bausteine
-------------------------------------------------------------------------------

local function addText(parent, text, font, x, y, width)
	local fontString = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
	fontString:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	fontString:SetJustifyH("LEFT")
	if width then
		fontString:SetWidth(width)
		if fontString.SetWordWrap then fontString:SetWordWrap(true) end
	end
	fontString:SetText(text)
	return fontString
end

local function addHeader(parent, text, x, y, width)
	local header = addText(parent, text, "GameFontNormal", x, y)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 0.82, 0, 0.35)
	line:SetSize(width, 1)
	line:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 16)
	header.line = line
	return header
end

local function addButton(parent, text, width, x, y, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	return button
end

-- kind: nur für diese Alarm-Art sichtbar (nil = immer). Ein Widget mit "hideFor"
-- ist bei genau dieser Alarm-Art ausgeblendet.
local function addSlider(parent, key, labelText, x, y, minimum, maximum, step, formatValue, get, set, kind)
	local name = FRAME_NAME .. key
	local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	slider:SetSize(170, 17)
	slider:SetMinMaxValues(minimum, maximum)
	slider:SetValueStep(step)
	if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
	-- Die Beschriftungen der Vorlage leeren, wir nutzen eine eigene Zeile.
	for _, part in ipairs({ "Low", "High", "Text" }) do
		local region = slider[part] or _G[name .. part]
		if type(region) == "table" and region.SetText then region:SetText("") end
	end
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 3)
	slider.label = label
	slider.tipTitle = labelText
	slider.kind = kind
	local list, onChanged = sink.list, sink.changed

	local function show(value) label:SetText(labelText .. ": " .. formatValue(value)) end
	slider:SetScript("OnValueChanged", function(self, value)
		if self.refreshing then return end
		value = math.floor(value / step + 0.5) * step
		if value == get() then return end
		set(value)
		show(value)
		onChanged()
	end)
	slider.Refresh = function(self)
		self.refreshing = true
		self:SetValue(get())
		self.refreshing = false
		show(get())
	end
	list[#list + 1] = slider
	return slider
end

local function addCheck(parent, text, x, y, get, set, kind)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	label:SetPoint("LEFT", check, "RIGHT", 2, 0)
	label:SetText(text)
	check.label = label
	check.kind = kind
	check:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
	end)
	check.Refresh = function(self) self:SetChecked(get() and true or false) end
	sink.list[#sink.list + 1] = check
	return check
end

local function addEditBox(parent, width, x, y, onEnter)
	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	box:SetSize(width, 20)
	box:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 4, y)
	box:SetAutoFocus(false)
	box:SetScript("OnEnterPressed", function(self)
		onEnter(self, (self:GetText() or ""):match("^%s*(.-)%s*$"))
		self:ClearFocus()
	end)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	return box
end

local function hideTooltip()
	if GameTooltip then GameTooltip:Hide() end
end

-- Erklärung, die erscheint, wenn die Maus über einem Bedienelement steht. Als
-- Überschrift dient "title", sonst die Beschriftung des Elements.
local function tip(region, body, title)
	region.tipBody = body
	region.tipTitle = title or region.tipTitle
	region:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		local heading = self.tipTitle or (self.label and self.label:GetText()) or (self.GetText and self:GetText()) or ""
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(heading, 1, 0.82, 0)
		GameTooltip:AddLine(self.tipBody, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	region:SetScript("OnLeave", hideTooltip)
	return region
end

-------------------------------------------------------------------------------
-- Textur-Auswahl: Kategorien, Seiten und ein Raster aus Vorschaubildern
-------------------------------------------------------------------------------

local function pageCount(categoryIndex)
	return math.max(1, math.ceil(#ns.TEXTURE_CATEGORIES[categoryIndex].keys / PER_PAGE))
end

-- Kategorie und Seite aufschlagen, auf der die gewählte Textur liegt.
local function locateSelection()
	for categoryIndex, category in ipairs(ns.TEXTURE_CATEGORIES) do
		for position, key in ipairs(category.keys) do
			if key == cur().texture then
				browser.category = categoryIndex
				browser.page = math.ceil(position / PER_PAGE)
				return
			end
		end
	end
end

local function addTextureBrowser(parent, x, y)
	local categoryButtons = {}
	local count = #ns.TEXTURE_CATEGORIES
	local buttonWidth = math.floor((BROWSER_W - (count - 1) * 4) / count)
	for index, category in ipairs(ns.TEXTURE_CATEGORIES) do
		categoryButtons[index] = addButton(parent, category.name, buttonWidth, x + (index - 1) * (buttonWidth + 4), y, function()
			browser.category, browser.page = index, 1
			ns.RefreshOptions()
		end)
	end

	local gridY = y - 30
	local thumbs = {}
	for slot = 1, PER_PAGE do
		local column, row = (slot - 1) % COLUMNS, math.floor((slot - 1) / COLUMNS)
		local thumb = CreateFrame("Button", nil, parent)
		thumb:SetSize(THUMB, THUMB)
		thumb:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 2 + column * (THUMB + THUMB_GAP), gridY - row * (THUMB + THUMB_GAP))

		thumb.selected = thumb:CreateTexture(nil, "BACKGROUND")
		thumb.selected:SetPoint("TOPLEFT", thumb, "TOPLEFT", -2, 2)
		thumb.selected:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", 2, -2)
		thumb.selected:SetColorTexture(1, 0.82, 0, 1)

		local background = thumb:CreateTexture(nil, "BORDER")
		background:SetAllPoints(thumb)
		background:SetColorTexture(0.04, 0.05, 0.08, 1)

		thumb.texture = thumb:CreateTexture(nil, "ARTWORK")
		thumb.texture:SetPoint("TOPLEFT", thumb, "TOPLEFT", 2, -2)
		thumb.texture:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", -2, 2)

		thumb:SetScript("OnClick", function(self)
			if not self.key then return end
			cur().texture = self.key
			ns.RefreshOptions()
			changed()
		end)
		thumb:SetScript("OnEnter", function(self)
			local preset = self.key and ns.TEXTURES[self.key]
			if not (GameTooltip and preset) then return end
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(preset.name)
			GameTooltip:Show()
		end)
		thumb:SetScript("OnLeave", function()
			if GameTooltip then GameTooltip:Hide() end
		end)
		thumbs[slot] = thumb
	end

	local navY = gridY - ROWS * (THUMB + THUMB_GAP) - 4
	local previous = addButton(parent, "<", 24, x, navY, function()
		browser.page = math.max(1, browser.page - 1)
		ns.RefreshOptions()
	end)
	local pageText = addText(parent, "", nil, x + 30, navY - 5)
	local following = addButton(parent, ">", 24, x + 104, navY, function()
		browser.page = math.min(pageCount(browser.category), browser.page + 1)
		ns.RefreshOptions()
	end)
	local selection = addText(parent, "", nil, x + 140, navY - 5, BROWSER_W - 140)
	previous.pager, following.pager = -1, 1

	local view = { thumbs = thumbs, regions = { previous, pageText, following, selection } }
	for _, button in ipairs(categoryButtons) do view.regions[#view.regions + 1] = button end
	view.Refresh = function()
		local settings = cur()
		local pages = pageCount(browser.category)
		browser.page = math.min(math.max(1, browser.page), pages)
		local keys = ns.TEXTURE_CATEGORIES[browser.category].keys
		local color = settings.color
		for slot, thumb in ipairs(thumbs) do
			local key = keys[(browser.page - 1) * PER_PAGE + slot]
			local preset = key and ns.TEXTURES[key]
			thumb.key = key
			if preset then
				thumb.texture:SetTexture(preset.path)
				thumb.texture:SetBlendMode(preset.blend or (settings.additive and "ADD" or "BLEND"))
				if preset.colored then
					thumb.texture:SetVertexColor(1, 1, 1, 1) -- die Farben stecken in der Datei
				else
					thumb.texture:SetVertexColor(color[1], color[2], color[3], 1)
				end
				thumb.selected:SetShown(settings.texture == key)
				thumb:Show()
			else
				thumb:Hide()
			end
		end
		for index, button in ipairs(categoryButtons) do
			button:SetEnabled(index ~= browser.category) -- die aktive Kategorie ist ausgegraut
		end
		pageText:SetText((L["Page %d/%d"]):format(browser.page, pages))
		previous:SetEnabled(browser.page > 1)
		following:SetEnabled(browser.page < pages)
		local preset = ns.TEXTURES[settings.texture]
		selection:SetText(L["Selected: "] .. (preset and preset.name or L["custom path"]))
	end
	widgets[#widgets + 1] = view
	return view
end

local function openColorPicker(field)
	if not (ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then
		return ns.msg(L["This client has no color picker. Use /sha set %s color 115 204 255."], selected.key)
	end
	local alert = selected
	local color = alert.s[field]
	local previous = { color[1], color[2], color[3] }
	local function apply(r, g, b)
		alert.s[field] = { r, g, b }
		ns.RefreshOptions()
		ns.applyPreview(alert)
		ns.scheduleBuild(alert)
	end
	ColorPickerFrame:SetupColorPickerAndShow({
		r = color[1], g = color[2], b = color[3],
		hasOpacity = false,
		swatchFunc = function()
			apply(ColorPickerFrame:GetColorRGB())
		end,
		cancelFunc = function()
			apply(previous[1], previous[2], previous[3])
		end,
	})
end

-- Farbfeld zum Anklicken. "fill" ist die farbige Fläche.
local function addSwatch(parent, x, y, field, fillKey)
	local swatch = CreateFrame("Button", nil, parent)
	swatch:SetSize(22, 22)
	swatch:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	local edge = swatch:CreateTexture(nil, "BACKGROUND")
	edge:SetPoint("TOPLEFT", swatch, "TOPLEFT", -1, 1)
	edge:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", 1, -1)
	edge:SetColorTexture(1, 1, 1, 0.8)
	local fill = swatch:CreateTexture(nil, "ARTWORK")
	fill:SetAllPoints(swatch)
	swatch[fillKey] = fill
	swatch:SetScript("OnClick", function() openColorPicker(field) end)
	swatch.Refresh = function()
		local color = cur()[field]
		fill:SetColorTexture(color[1], color[2], color[3], 1)
	end
	widgets[#widgets + 1] = swatch
	return swatch
end

-------------------------------------------------------------------------------
-- Sound-Auswahl
-------------------------------------------------------------------------------

-- Eigene Sounds plus alles, was andere Addons bei LibSharedMedia angemeldet haben.
local function soundChoices()
	local list, seen = {}, {}
	for _, sound in ipairs(ns.SOUNDS) do
		list[#list + 1] = sound
		seen[sound.file] = true
	end
	local media = LibStub and LibStub("LibSharedMedia-3.0", true)
	if media then
		local ok, names = pcall(media.List, media, "sound")
		if ok and type(names) == "table" then
			for _, name in ipairs(names) do
				local fetched, file = pcall(media.Fetch, media, "sound", name, true)
				local usable = fetched and (type(file) == "string" and file ~= "" or type(file) == "number" and file > 1)
				if usable and name ~= "None" and not seen[file] then
					list[#list + 1] = { name = name, file = file }
					seen[file] = true
				end
			end
		end
	end
	return list
end

local function currentSoundIndex(list)
	for index, sound in ipairs(list) do
		if sound.file == cur().soundFile then return index end
	end
	return nil
end

local function selectSound(file)
	ns.setSoundFile(selected, file) -- spielt den Sound auch gleich ab
	ns.RefreshOptions()
end

local function stepSound(direction)
	local list = soundChoices()
	local index = currentSoundIndex(list) or (direction > 0 and 0 or 1)
	index = (index - 1 + direction) % #list + 1
	selectSound(list[index].file)
end

local function openSoundMenu(owner)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return stepSound(1) end
	local list = soundChoices()
	local ok = pcall(MenuUtil.CreateContextMenu, owner, function(_, root)
		if root.SetScrollMode then root:SetScrollMode(360) end
		for _, sound in ipairs(list) do
			root:CreateRadio(sound.name,
				function() return cur().soundFile == sound.file end,
				function() selectSound(sound.file) end)
		end
	end)
	if not ok then stepSound(1) end
end

-------------------------------------------------------------------------------
-- Fenster
-------------------------------------------------------------------------------

local TABS = {
	{ key = "look", name = L["Graphics"] },
	{ key = "layout", name = L["Layout"] },
	{ key = "rules", name = L["Conditions"] },
	{ key = "sound", name = L["Sound"] },
	{ key = "aura", name = L["Spell & aura"] },
}
local PAGES = {
	{ key = "totems", name = L["Totem bar & font"] },
	{ key = "profiles", name = L["Profiles & sharing"] },
	{ key = "help", name = L["Help & diagnostics"] },
}

-- Ein Satz je eingebautem Alarm, er steht im Kopf der Seite.
local DESCRIPTIONS = {
	maelstrom = L["Shows lightning around your character as soon as Maelstrom Weapon reaches the set number of stacks."],
	flameshock = L["Reminds you to put Flame Shock on your target while it is missing there. Against players it stays off."],
	shield = L["Warns while your shield is missing."],
	weapon = L["Warns while a weapon is missing its enchant."],
	stormstrike = L["Appears as soon as Stormstrike is ready."],
	earthshock = L["The general shock: appears as soon as the shocks are ready and no particular shock has priority (Interrupt, Frost Shock against players, Flame Shock)."],
	interrupt = L["Appears as soon as your target casts something that can be interrupted and Earth Shock is ready."],
	firenova = L["Appears as soon as Fire Nova is ready, optionally only with a fire totem and with several enemies nearby."],
	clearcast = L["Appears while Clearcasting is active: your next spell costs no mana."],
	flurry = L["Appears while Flurry is active."],
	frostshock = L["In combat against players, reminds you to put Frost Shock on your target while the slow is missing there."],
	bloodfury = L["Appears as soon as Blood Fury (orc) is ready."],
	berserking = L["Appears as soon as Berserking (troll) is ready."],
}
local KIND_DESCRIPTIONS = {
	active = L["Custom alert: appears while the aura is active."],
	missing = L["Custom alert: appears while the aura is missing."],
	stacks = L["Custom alert: appears from the set number of stacks."],
	ready = L["Custom alert: appears as soon as the spell is ready."],
}

-- Zustand eines Alarms für den Punkt in der Liste
local STATE_COLORS = {
	on = { 0.25, 0.9, 0.35 },
	unknown = { 0.95, 0.75, 0.2 },
	off = { 0.4, 0.4, 0.4 },
	class = { 0.4, 0.4, 0.4 },
}
local STATE_TEXT = {
	on = L["Switched on."],
	unknown = L["Switched on, but the spell is not in your spellbook. The alert therefore stays invisible."],
	off = L["Switched off."],
	class = L["For shamans only. On this character the alert stays invisible."],
}

local function alertState(alert)
	if alert.def.class ~= nil and alert.def.class ~= ns.state.class then return "class" end
	if not alert.s.enabled then return "off" end
	if ns.internals.spellKnown(alert) == false then return "unknown" end
	return "on"
end

-- Fragt nach, bevor etwas verloren geht. Ohne Dialog des Spiels geht es sofort.
local function confirm(text, action)
	if not (StaticPopupDialogs and StaticPopup_Show) then return action() end
	StaticPopupDialogs.SHAMANALERTS_CONFIRM = StaticPopupDialogs.SHAMANALERTS_CONFIRM or {
		text = "%s",
		button1 = YES or L["Yes"],
		button2 = NO or L["No"],
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		OnAccept = function(_, run)
			if type(run) == "function" then run() end
		end,
	}
	StaticPopup_Show("SHAMANALERTS_CONFIRM", text, nil, action)
end

-- Zeigt die gewählte Seite: die Alarme, die Totem-Leiste oder die Hilfe.
local function showPage(key)
	if key then activePage = key end
	if not (frame and frame:IsShown()) then return end
	if activePage == "totems" and not pages.totems then
		if ns.Totems and ns.Totems.settings then
			totemFrame = createTotemFrame(frame)
			pages.totems = totemFrame
		else
			activePage = "alerts"
		end
	end
	for name, page in pairs(pages) do
		if name ~= activePage then page:Hide() end
	end
	pages[activePage]:Show()
	-- Die verschiebbare Vorschau gehört zur Alarm-Seite.
	ns.setMoving(activePage == "alerts" and selected or nil)
	ns.RefreshOptions(true)
	if activePage == "totems" then ns.RefreshTotemOptions() end
end

local function selectAlert(alert)
	selected = alert
	activePage = "alerts"
	-- Liste so weit rollen, dass der Alarm zu sehen ist
	for index, candidate in ipairs(ns.alerts) do
		if candidate == alert then
			local offset = view.offset or 0
			if index <= offset then
				view.offset = index - 1
			elseif index > offset + MAX_ROWS then
				view.offset = index - MAX_ROWS
			end
		end
	end
	if frame and frame:IsShown() then
		showPage()
	else
		ns.RefreshOptions(true)
	end
end

-- Zeile der Liste links: Punkt für den Zustand, Name, Markierung der Auswahl
local function addRow(parent, y, onClick)
	local row = CreateFrame("Button", nil, parent)
	row:SetSize(SIDE_W, ROW_H)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", SIDE_X, y)
	row.mark = row:CreateTexture(nil, "BACKGROUND")
	row.mark:SetAllPoints(row)
	row.mark:SetColorTexture(1, 0.82, 0, 0.16)
	local hover = row:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints(row)
	hover:SetColorTexture(1, 1, 1, 0.07)
	row.dot = row:CreateTexture(nil, "ARTWORK")
	row.dot:SetSize(8, 8)
	row.dot:SetPoint("LEFT", row, "LEFT", 6, 0)
	row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.label:SetPoint("LEFT", row, "LEFT", 20, 0)
	row.label:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.label:SetJustifyH("LEFT")
	if row.label.SetWordWrap then row.label:SetWordWrap(false) end
	row:SetScript("OnClick", onClick)
	return row
end

local function refreshSidebar()
	local list = ns.alerts
	local maxOffset = math.max(0, #list - MAX_ROWS)
	view.offset = math.min(math.max(0, view.offset or 0), maxOffset)
	for index, row in ipairs(view.rows) do
		local alert = list[index + view.offset]
		row.alert = alert
		if alert then
			local state = alertState(alert)
			local color = STATE_COLORS[state]
			local chosen = activePage == "alerts" and alert == selected
			row.state = state
			row.dot:SetColorTexture(color[1], color[2], color[3], 1)
			row.label:SetText(alert.def.title)
			row.mark:SetShown(chosen)
			if chosen then
				row.label:SetTextColor(1, 0.82, 0)
			elseif state == "on" then
				row.label:SetTextColor(1, 1, 1)
			else
				row.label:SetTextColor(0.6, 0.6, 0.6)
			end
			row:Show()
		else
			row:Hide()
		end
	end
	view.scrollHint:SetShown(maxOffset > 0)
	for _, row in ipairs(view.pageRows) do
		local chosen = activePage == row.page
		row.mark:SetShown(chosen)
		if chosen then row.label:SetTextColor(1, 0.82, 0) else row.label:SetTextColor(1, 1, 1) end
	end
end

local function createFrame()
	local ok, window = pcall(CreateFrame, "Frame", FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
	if not ok or not window then
		window = CreateFrame("Frame", FRAME_NAME, UIParent)
		local background = window:CreateTexture(nil, "BACKGROUND")
		background:SetAllPoints(window)
		background:SetColorTexture(0.05, 0.05, 0.07, 0.95)
		local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
	end
	window:Hide()
	window:SetSize(WIDTH, HEIGHT)
	window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -60)
	window:SetFrameStrata("DIALOG")
	window:SetToplevel(true)
	window:SetClampedToScreen(true)
	window:EnableMouse(true)
	window:SetMovable(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", window.StopMovingOrSizing)
	if UISpecialFrames then tinsert(UISpecialFrames, FRAME_NAME) end -- schließt mit Escape

	local title = window.TitleText or (window.TitleContainer and window.TitleContainer.TitleText)
	if type(title) ~= "table" or not title.SetText then
		title = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		title:SetPoint("TOP", window, "TOP", 0, -5)
	end
	title:SetText("ShamanAlerts")
	-- Die Innenfläche der Vorlage reicht je nach Spielversion verschieden weit.
	-- Hier füllt sie das ganze Fenster unter der Titelzeile.
	if type(window.Inset) == "table" and window.Inset.ClearAllPoints then
		window.Inset:ClearAllPoints()
		window.Inset:SetPoint("TOPLEFT", window, "TOPLEFT", 4, -24)
		window.Inset:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -6, 4)
	end

	-- Links: Liste der Alarme und der übrigen Seiten ---------------------------
	local shade = window:CreateTexture(nil, "BORDER")
	shade:SetColorTexture(0, 0, 0, 0.28)
	shade:SetPoint("TOPLEFT", window, "TOPLEFT", SIDE_X - 6, -28)
	shade:SetSize(SIDE_W + 12, HEIGHT - 38)
	local divider = window:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(1, 1, 1, 0.12)
	divider:SetSize(1, HEIGHT - 38)
	divider:SetPoint("TOPLEFT", window, "TOPLEFT", SIDE_X + SIDE_W + 7, -28)

	addHeader(window, L["Alerts"], SIDE_X, -36, SIDE_W)
	view.rows = {}
	for index = 1, MAX_ROWS do
		local row = addRow(window, -58 - (index - 1) * ROW_H, function(self)
			if self.alert then selectAlert(self.alert) end
		end)
		row:SetScript("OnEnter", function(self)
			if not (GameTooltip and self.alert) then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.alert.def.title, 1, 0.82, 0)
			GameTooltip:AddLine(STATE_TEXT[self.state] or "", 1, 1, 1, true)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", hideTooltip)
		-- Mausrad: bei mehr Alarmen, als Zeilen da sind, durch die Liste rollen
		if row.EnableMouseWheel then row:EnableMouseWheel(true) end
		row:SetScript("OnMouseWheel", function(_, delta)
			view.offset = (view.offset or 0) - (delta or 0)
			refreshSidebar()
		end)
		view.rows[index] = row
	end
	local listEnd = -58 - MAX_ROWS * ROW_H
	view.scrollHint = addText(window, L["Mouse wheel: more alerts"], "GameFontDisableSmall", SIDE_X + 6, listEnd - 2)
	tip(addButton(window, L["+ New alert"], SIDE_W, SIDE_X, listEnd - 18, function() ns.commands.new("") end),
		L["Creates your own alert for any buff, debuff or spell. Kind, name and looks are set on the right afterwards."])

	addHeader(window, L["More pages"], SIDE_X, listEnd - 56, SIDE_W)
	view.pageRows = {}
	for index, page in ipairs(PAGES) do
		local row = addRow(window, listEnd - 78 - (index - 1) * ROW_H, function(self) showPage(self.page) end)
		row.page = page.key
		row.dot:Hide()
		row.label:SetText(page.name)
		view.pageRows[index] = row
	end
	local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
	addText(window, L["Version "] .. tostring(version or "?"), "GameFontDisableSmall", SIDE_X + 6, -HEIGHT + 24)

	-- Rechts: Seite des gewählten Alarms ---------------------------------------
	local page = CreateFrame("Frame", nil, window)
	page:SetPoint("TOPLEFT", window, "TOPLEFT", CONTENT_X, -28)
	page:SetSize(CONTENT_W, PAGE_H)
	pages.alerts = page

	view.title = addText(page, "", "GameFontNormalLarge", 0, -8)
	view.kind = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	view.kind:SetPoint("BOTTOMLEFT", view.title, "BOTTOMRIGHT", 10, 1)
	view.desc = addText(page, "", "GameFontHighlightSmall", 0, -32, CONTENT_W - 120)
	view.desc:SetJustifyV("TOP")
	tip(addCheck(page, L["Enabled"], CONTENT_W - 70, -4,
		function() return cur().enabled end,
		function(value)
			cur().enabled = value
			ns.updateEngineSounds()
			changed()
			ns.RefreshOptions()
		end), L["Switches this alert on or off. The other settings are kept."])

	-- Reiter
	local tabFrames = {}
	view.tabs = {}
	local tabWidth = math.floor((CONTENT_W - (#TABS - 1) * 4) / #TABS)
	for index, tab in ipairs(TABS) do
		local button = addButton(page, tab.name, tabWidth, (index - 1) * (tabWidth + 4), -66, function()
			activeTab = tab.key
			ns.RefreshOptions()
		end)
		button.tabKey = tab.key
		button.underline = button:CreateTexture(nil, "OVERLAY")
		button.underline:SetColorTexture(1, 0.82, 0, 1)
		button.underline:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 4, -1)
		button.underline:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", -4, -1)
		button.underline:SetHeight(2)
		view.tabs[index] = button
		local content = CreateFrame("Frame", nil, page)
		content:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -104)
		content:SetSize(CONTENT_W, PAGE_H - 104 - 46)
		tabFrames[tab.key] = content
	end
	view.tabFrames = tabFrames
	local tabLine = page:CreateTexture(nil, "ARTWORK")
	tabLine:SetColorTexture(1, 0.82, 0, 0.35)
	tabLine:SetSize(CONTENT_W, 1)
	tabLine:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -92)

	-- Reiter "Grafik" -----------------------------------------------------------
	local look = tabFrames.look
	addHeader(look, L["Appearance"], 0, 0, 292)
	tip(addSlider(look, "Size", L["Size"], 4, -44, 32, 600, 4,
		function(value) return ("%d"):format(value) end,
		function() return cur().size end,
		function(value) cur().size = value end), L["Edge length of the graphic in pixels."])
	tip(addSlider(look, "Alpha", L["Opacity"], 4, -90, 10, 100, 5,
		function(value) return ("%d %%"):format(value) end,
		function() return math.floor(cur().alpha * 100 + 0.5) end,
		function(value) cur().alpha = value / 100 end), L["100 % is fully visible, lower values let the game shine through."])
	tip(addCheck(look, L["Pulse"], 0, -112,
		function() return cur().pulse end,
		function(value)
			cur().pulse = value
			changed()
		end), L["The graphic gets a little brighter and darker in a steady rhythm so that it stands out."])
	tip(addCheck(look, L["Buff icon with stack count"], 0, -136,
		function() return cur().icon end,
		function(value)
			cur().icon = value
			changed()
		end, "stacks"), L["Also shows the icon of the buff with the number of stacks."])
	tip(addCheck(look, L["Time left below the graphic"], 0, -136,
		function() return cur().timer end,
		function(value)
			cur().timer = value
			changed()
		end, "active"), L["Shows below the graphic how long the aura still lasts."])

	local displayButton = tip(addButton(look, "", 292, 0, -172, function()
		cur().display = cur().display == "icon" and "texture" or "icon"
		ns.RefreshOptions(true)
		changed()
	end), L["Switches between a painted picture and the icon of the spell as it appears on the action bars."])
	displayButton.Refresh = function(self)
		self:SetText(L["Display: "] .. (cur().display == "icon" and L["Spell icon"] or L["Texture"]))
	end
	widgets[#widgets + 1] = displayButton

	-- Textur: Auswahl, Farbe, Überblendung, eigener Pfad
	local textureGroup = {}
	local function inTextureGroup(region)
		textureGroup[#textureGroup + 1] = region
		if region.label then textureGroup[#textureGroup + 1] = region.label end
		return region
	end
	addHeader(look, L["Picture"], 320, 0, BROWSER_W)
	local browserView = addTextureBrowser(look, 320, -24)
	for _, region in ipairs(browserView.regions) do inTextureGroup(region) end

	inTextureGroup(addText(look, L["Color:"], nil, 0, -212))
	inTextureGroup(tip(addSwatch(look, 44, -207, "color", "color"), L["Tints single-colored pictures. Colorful pictures keep their colors."], L["Color"]))
	inTextureGroup(addButton(look, L["White"], 54, 74, -207, function()
		cur().color = { 1, 1, 1 }
		ns.RefreshOptions()
		changed()
	end))
	inTextureGroup(tip(addCheck(look, L["Glowing (additive)"], 0, -234,
		function() return cur().additive end,
		function(value)
			cur().additive = value
			ns.RefreshOptions()
			changed()
		end), L["The picture brightens the game behind it instead of covering it. Dark parts of the picture become transparent."]))

	inTextureGroup(addText(look, L["Custom path (Enter applies):"], nil, 0, -268))
	local pathBox = inTextureGroup(addEditBox(look, 284, 0, -284, function(_, text)
		if text == "" then return end
		cur().texture = ns.TEXTURES[text:lower()] and text:lower() or text
		ns.RefreshOptions(true)
		changed()
	end))
	pathBox.field = "path"
	pathBox.Refresh = function(self)
		self:SetText(ns.TEXTURES[cur().texture] and "" or tostring(cur().texture))
	end
	widgets[#widgets + 1] = pathBox

	-- Zaubersymbol: Vorschau, Zoom, Rahmen, Symbolwahl
	local iconGroup = {}
	local function inIconGroup(region)
		iconGroup[#iconGroup + 1] = region
		if region.label then iconGroup[#iconGroup + 1] = region.label end
		return region
	end
	inIconGroup(addText(look,
		L["Shows the icon of the spell: square, slightly zoomed in, with a thin border, as in EllesmereUI. Size, opacity and layout apply as for a texture."],
		"GameFontDisableSmall", 320, -26, BROWSER_W))
	local sample = CreateFrame("Frame", nil, look)
	sample:SetSize(72, 72)
	sample:SetPoint("TOPLEFT", look, "TOPLEFT", 322, -76)
	sample.border = sample:CreateTexture(nil, "BACKGROUND")
	sample.border:SetAllPoints(sample)
	sample.icon = sample:CreateTexture(nil, "ARTWORK")
	sample.Refresh = function(self)
		local settings = cur()
		-- Rahmen im Verhältnis zur Alarmgröße, damit das Muster dem Original entspricht
		local border = settings.iconBorder * 72 / math.max(1, settings.size)
		local color = settings.iconBorderColor
		self.border:SetColorTexture(color[1], color[2], color[3], settings.iconBorder > 0 and 1 or 0)
		self.icon:ClearAllPoints()
		self.icon:SetPoint("TOPLEFT", self, "TOPLEFT", border, -border)
		self.icon:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -border, border)
		self.icon:SetTexture(ns.resolveIcon(selected))
		local crop = settings.iconZoom / 100
		self.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	end
	widgets[#widgets + 1] = sample
	inIconGroup(sample)

	inIconGroup(addSlider(look, "IconZoom", L["Zoom"], 420, -88, 0, 40, 1,
		function(value) return ("%d %%"):format(value) end,
		function() return cur().iconZoom end,
		function(value)
			cur().iconZoom = value
			sample:Refresh()
		end))
	inIconGroup(addSlider(look, "IconBorder", L["Border width"], 420, -134, 0, 8, 1,
		function(value) return ("%d"):format(value) end,
		function() return cur().iconBorder end,
		function(value)
			cur().iconBorder = value
			sample:Refresh()
		end))
	inIconGroup(addText(look, L["Border color:"], nil, 320, -174))
	inIconGroup(addSwatch(look, 404, -169, "iconBorderColor", "fill"))
	inIconGroup(addButton(look, L["Black"], 70, 434, -169, function()
		cur().iconBorderColor = { 0, 0, 0 }
		ns.RefreshOptions()
		changed()
	end))
	inIconGroup(addText(look, L["Other icon (spell ID, spell name or texture path). Leave empty for the usual icon:"], nil, 320, -208, BROWSER_W))
	local iconBox = inIconGroup(addEditBox(look, 300, 320, -238, function(_, text)
		cur().iconSpell = text
		ns.RefreshOptions()
		changed()
	end))
	iconBox.field = "iconSpell"
	iconBox.Refresh = function(self) self:SetText(tostring(cur().iconSpell or "")) end
	widgets[#widgets + 1] = iconBox

	-- Blendet je nach Darstellung die eine oder die andere Gruppe ein.
	local displayToggle = {}
	displayToggle.Refresh = function()
		local icon = cur().display == "icon"
		for _, region in ipairs(textureGroup) do region:SetShown(not icon) end
		for _, region in ipairs(iconGroup) do region:SetShown(icon) end
		if icon then
			for _, thumb in ipairs(browserView.thumbs) do thumb:Hide() end
		end
	end
	widgets[#widgets + 1] = displayToggle

	-- Reiter "Anordnung" --------------------------------------------------------
	local place = tabFrames.layout
	addHeader(place, L["Layout around the character"], 0, 0, CONTENT_W)
	local function setLayout(key)
		cur().layout = key
		ns.RefreshOptions()
		changed()
	end
	local function stepLayout()
		local index = 1
		for position, layout in ipairs(ns.LAYOUTS) do
			if layout.key == cur().layout then index = position end
		end
		setLayout(ns.LAYOUTS[index % #ns.LAYOUTS + 1].key)
	end
	local layoutButton = tip(addButton(place, "", 200, 0, -24, function(self)
		if not (MenuUtil and MenuUtil.CreateContextMenu) then return stepLayout() end
		local ok = pcall(MenuUtil.CreateContextMenu, self, function(_, root)
			for _, layout in ipairs(ns.LAYOUTS) do
				root:CreateRadio(layout.name,
					function() return cur().layout == layout.key end,
					function() setLayout(layout.key) end)
			end
		end)
		if not ok then stepLayout() end
	end), L["Where the copies of the graphic stand: in the center, as an arc on one side, on two sides or all around."], L["Layout"])
	layoutButton.Refresh = function(self)
		self:SetText((ns.LAYOUTS[cur().layout] or ns.LAYOUTS.center).name)
	end
	widgets[#widgets + 1] = layoutButton
	tip(addCheck(place, L["Rotate outwards"], 220, -23,
		function() return cur().rotate end,
		function(value)
			cur().rotate = value
			changed()
		end), L["Rotates each copy so that its top edge points away from the character."]).visibleIf = function() return cur().display ~= "icon" end
	tip(addSlider(place, "Count", L["Copies per arc"], 4, -76, 1, 8, 1,
		function(value) return ("%d"):format(value) end,
		function() return cur().count end,
		function(value) cur().count = value end), L["This many copies of the graphic stand side by side on each arc."])
	tip(addSlider(place, "Distance", L["Distance from the center"], 224, -76, 0, 500, 5,
		function(value) return ("%d"):format(value) end,
		function() return cur().distance end,
		function(value) cur().distance = value end), L["Distance of the graphic from the character in pixels."])
	tip(addSlider(place, "Spread", L["Angle between copies"], 4, -122, 5, 120, 1,
		function(value) return ("%d°"):format(value) end,
		function() return cur().spread end,
		function(value) cur().spread = value end), L["How far apart several copies stand on the arc."])
	tip(addCheck(place, L["One more copy per stack"], 220, -114,
		function() return cur().perStack end,
		function(value)
			cur().perStack = value
			changed()
		end, "stacks"), L["With every further stack one more copy appears, up to the set number."])
	-- Drehen und Spiegeln wirken nur auf Texturen, nicht auf Zaubersymbole.
	local function textureMode() return cur().display ~= "icon" end
	tip(addSlider(place, "Angle", L["Rotation of the texture"], 4, -168, 0, 345, 15,
		function(value) return ("%d°"):format(value) end,
		function() return cur().angle end,
		function(value) cur().angle = value end), L["Rotates the picture in steps of 15 degrees. Mirrored copies rotate the other way."]).visibleIf = textureMode
	tip(addCheck(place, L["Mirror"], 220, -160,
		function() return cur().flip end,
		function(value)
			cur().flip = value
			changed()
		end), L["Mirrors the picture horizontally."]).visibleIf = textureMode

	addHeader(place, L["Position"], 0, -206, CONTENT_W)
	local position = addText(place, "", nil, 0, -230, 520)
	position.Refresh = function(self)
		self:SetText((L["Center X %d, Y %d. Drag the preview with the mouse."]):format(cur().x, cur().y))
	end
	widgets[#widgets + 1] = position
	local function coordinateBox(field, label, x)
		addText(place, label, nil, x, -260)
		local box = addEditBox(place, 60, x + 16, -256, function(_, text)
			local done, problem = ns.FIELDS[field](selected, text)
			if not done and problem then ns.msg(problem) end
			ns.RefreshOptions()
			changed()
		end)
		box.field = field
		box.Refresh = function(self) self:SetText(tostring(cur()[field])) end
		widgets[#widgets + 1] = box
		return box
	end
	coordinateBox("x", "X:", 0)
	coordinateBox("y", "Y:", 100)
	-- Gemeinsame Lage: Wer sie teilt, bekommt ein Häkchen; wer sie vorgibt, eine Zeile mit den Namen.
	local function shareTitle()
		local key = selected.def.defaults.placeLike
		local leader = type(key) == "string" and key ~= "" and ns.alerts[key] or nil
		return leader and leader.def.title or nil
	end
	local shareCheck = tip(addCheck(place, "", 384, -254,
		function() return ns.internals.placeLeader(selected) ~= nil end,
		function(value)
			if value then
				cur().placeLike = selected.def.defaults.placeLike
				ns.internals.joinPlacement(selected)
			else
				cur().placeLike = ""
			end
			ns.RefreshOptions()
			changed()
		end), L["Place and size apply to all alerts with this checkbox together, only the picture changes. Moving or resizing one of them changes all. Without the checkbox this alert stands on its own."], L["Shared place"])
	shareCheck.visibleIf = function() return shareTitle() ~= nil end
	local shareRefresh = shareCheck.Refresh
	shareCheck.Refresh = function(self)
		self.label:SetText(L["Same place as \""] .. (shareTitle() or "") .. "\"")
		shareRefresh(self)
	end
	local function mateNames()
		local names = {}
		if shareTitle() == nil then
			for _, other in ipairs((ns.internals.placeMates(selected))) do names[#names + 1] = other.def.title end
		end
		return names
	end
	local shareText = addText(place, "", "GameFontHighlightSmall", 384, -250, 340)
	shareText.visibleIf = function() return #mateNames() > 0 end
	shareText.Refresh = function(self)
		self:SetText(L["Place and size also apply to: "] .. table.concat(mateNames(), ", ") .. ".")
	end
	widgets[#widgets + 1] = shareText
	addButton(place, L["Reset to center"], 170, 200, -255, function()
		cur().x, cur().y = 0, 0
		ns.RefreshOptions()
		changed()
	end)
	addText(place, L["While this window is open, a preview stands in the place of the alert. Drag it with the mouse or enter the values here (Enter applies). X and Y move the center around which the copies are arranged."],
		"GameFontDisableSmall", 0, -290, 620)

	-- Reiter "Bedingungen" ------------------------------------------------------
	-- Bei Stapel-Alarmen zeichnet das Spiel die Grafik selbst, dort kann das
	-- Addon sie nicht nach Mana oder Ziel-Leben ausblenden.
	local rules = tabFrames.rules
	addHeader(rules, L["When the alert appears"], 0, 0, 356)
	tip(addSlider(rules, "Threshold", L["Appears from stacks"], 4, -44, 1, 10, 1,
		function(value) return ("%d"):format(value) end,
		function() return cur().threshold end,
		function(value)
			cur().threshold = value
			selected.lastStacks = nil
		end, "stacks"), L["From this many stacks of the buff the graphic appears."])
	local stackNote = addText(rules, L["For stack alerts the game draws the graphic itself. Further conditions are not possible there."], "GameFontDisableSmall", 0, -76, 350)
	stackNote.kind = "stacks"
	widgets[#widgets + 1] = stackNote
	tip(addCheck(rules, L["Show in combat only"], 0, -24,
		function() return cur().combatOnly end,
		function(value)
			cur().combatOnly = value
			changed()
		end), L["Out of combat the alert stays invisible."]).hideFor = "stacks"
	tip(addCheck(rules, L["Show only with enough mana"], 0, -48,
		function() return cur().needUsable end,
		function(value)
			cur().needUsable = value
			changed()
		end), L["Hides the alert while the game reports the spell as not usable, for example because mana is missing."]).hideFor = "stacks"
	tip(addCheck(rules, L["In combat only with aggro"], 0, -72,
		function() return cur().needAggro end,
		function(value)
			cur().needAggro = value
			changed()
		end), L["In combat the alert only appears while an enemy is attacking you. Out of combat the condition does not apply."]).hideFor = "stacks"
	tip(addCheck(rules, L["Check the off hand too"], 0, -96,
		function() return cur().offhand end,
		function(value)
			cur().offhand = value
			changed()
		end, "weapon"), L["Also warns if only the off-hand weapon is missing its enchant."])
	tip(addCheck(rules, L["Not during the cooldown of the spell"], 0, -96,
		function() return cur().needReady end,
		function(value)
			cur().needReady = value
			changed()
			ns.RefreshOptions() -- der Regler "Früher anzeigen" kommt und geht damit
		end, "missing"), L["While the spell is on cooldown the aura cannot be renewed anyway. The alert then waits until shortly before the cooldown ends."])
	tip(addCheck(rules, L["Only against players (PvP)"], 0, -120,
		function() return cur().needPlayer end,
		function(value)
			cur().needPlayer = value
			if value then cur().noPlayer = false end -- beides zugleich ginge nie auf
			ns.RefreshOptions()
			changed()
		end), L["The alert only appears while your target is a player. Against ordinary enemies it stays invisible."]).visibleIf = function()
			return selected.def.kind == "missing" and selected.def.unit == "target"
		end
	tip(addCheck(rules, L["Not against players (PvP)"], 0, -144,
		function() return cur().noPlayer end,
		function(value)
			cur().noPlayer = value
			if value then cur().needPlayer = false end
			ns.RefreshOptions()
			changed()
		end), L["While your target is a player, the alert stays invisible. Against ordinary enemies it appears as usual."]).visibleIf = function()
			return selected.def.kind == "missing" and selected.def.unit == "target"
		end
	tip(addCheck(rules, L["Only with an attackable target"], 0, -96,
		function() return cur().needTarget end,
		function(value)
			cur().needTarget = value
			changed()
		end, "ready"), L["Without a living, attackable target the alert stays invisible."])
	tip(addCheck(rules, L["Only in range"], 0, -120,
		function() return cur().needRange end,
		function(value)
			cur().needRange = value
			changed()
		end, "ready"), L["The alert only appears if the target is close enough for this spell."])
	tip(addCheck(rules, L["Only while the target casts"], 0, -144,
		function() return cur().needCasting end,
		function(value)
			cur().needCasting = value
			changed()
		end, "ready"), L["The alert only appears while the target casts or channels something that can be interrupted."])
	tip(addCheck(rules, L["Only with a fire totem"], 0, -168,
		function() return cur().needFireTotem end,
		function(value)
			cur().needFireTotem = value
			changed()
		end, "ready"), L["The alert only appears while one of your fire totems stands."])
	tip(addCheck(rules, L["Priority while the target casts"], 0, -272,
		function() return cur().castFirst end,
		function(value)
			cur().castFirst = value
			changed()
		end, "ready"), L["While your target casts something that can be interrupted and this spell is ready, this alert is shown and the other alerts in the same place stay hidden."])
	local enemiesCheck = tip(addCheck(rules, "", 0, -192,
		function() return cur().needEnemies end,
		function(value)
			cur().needEnemies = value
			changed()
		end, "ready"), L["The nameplates of attackable enemies in range are counted, in combat only those that are fighting themselves. Enemy nameplates must be switched on for this."])
	enemiesCheck.isEnemiesCheck = true
	local refreshEnemiesCheck = enemiesCheck.Refresh
	enemiesCheck.Refresh = function(self)
		self.label:SetText((L["Only with %d+ enemies within %d yd"]):format(cur().minEnemies or 3, cur().enemyRange or 10))
		refreshEnemiesCheck(self)
	end
	tip(addSlider(rules, "MinEnemies", L["Enemies at least"], 28, -240, 2, 10, 1,
		function(value) return ("%d"):format(value) end,
		function() return cur().minEnemies or 3 end,
		function(value)
			cur().minEnemies = value
			enemiesCheck:Refresh()
		end, "ready"), L["This many enemies must stand in range for the alert to appear."])
	local rangeButton = tip(addButton(rules, "", 130, 214, -238, function()
		local order = { 5, 10, 20 }
		local index = 2
		for position, yards in ipairs(order) do
			if yards == cur().enemyRange then index = position end
		end
		ns.FIELDS.enemyrange(selected, tostring(order[index % #order + 1]))
		ns.RefreshOptions()
		changed()
	end), L["Radius in which enemies are counted: 5, 10 or 20 yards."], L["Counting radius"])
	rangeButton.kind = "ready"
	rangeButton.Refresh = function(self) self:SetText((L["Radius: %d yd"]):format(cur().enemyRange or 10)) end
	widgets[#widgets + 1] = rangeButton

	local timingHeader = addHeader(rules, L["Timing and priority"], 390, 0, 356)
	tip(addSlider(rules, "Lead", L["Show earlier"], 394, -44, 0, 3, 0.1,
		function(value) return value == 0 and L["(off)"] or (("%.1f s"):format(value):gsub("%.", L["."])) end,
		function() return math.floor((cur().lead or 0) * 10 + 0.5) / 10 end,
		function(value) cur().lead = math.floor(value * 10 + 0.5) / 10 end),
		L["The alert already appears this many seconds before the cooldown ends."]).visibleIf = function()
			local kind = selected.def.kind
			return kind == "ready" or (kind == "missing" and cur().needReady == true)
		end
	tip(addSlider(rules, "MinHealth", L["Target has at least"], 394, -90, 0, 90, 5,
		function(value) return value == 0 and L["(off)"] or (L["%d %% health"]):format(value) end,
		function() return cur().minHealth end,
		function(value) cur().minHealth = value end),
		L["Below this health threshold of the target the alert stays invisible, because the spell is no longer worth it then."]).visibleIf = function()
			return selected.def.unit == "target" and selected.def.kind ~= "stacks"
		end
	tip(addSlider(rules, "Refresh", L["Early refresh"], 394, -136, 0, 5, 0.5,
		function(value) return value == 0 and L["(off)"] or ((L["from %.1f s remaining"]):format(value):gsub("%.", L["."])) end,
		function() return cur().refresh or 0 end,
		function(value)
			cur().refresh = math.floor(value * 10 + 0.5) / 10
			ns.RefreshOptions() -- der Regler für die Laufzeit erscheint nur, wenn das hier an ist
		end),
		L["The alert already appears when the aura only has this many seconds left. That way it can be renewed before it runs out. The addon keeps its own time for this from the moment you cast the spell."]).visibleIf = function()
			return selected.def.kind == "missing"
		end
	tip(addSlider(rules, "AuraDuration", L["Aura duration"], 394, -182, 1, 60, 1,
		function(value) return value <= 0 and L["unknown"] or (("%.1f s"):format(value):gsub("%.", L["."])) end,
		function() return cur().auraDuration or 0 end,
		function(value) cur().auraDuration = value end),
		L["This is how long the aura lasts after casting. The addon's own clock for the early refresh measures against it. Out of combat the addon learns the value itself as soon as it sees the aura."]).visibleIf = function()
			return selected.def.kind == "missing" and (cur().refresh or 0) > 0
		end
	-- Vorrang: hinter welchem Alarm dieser zurücksteht
	local function yieldChoices()
		local list = { "" }
		for _, alert in ipairs(ns.alerts) do
			if alert ~= selected and (alert.def.kind == "missing" or ns.PLAIN_KINDS[alert.def.kind]) then list[#list + 1] = alert.key end
		end
		return list
	end
	local yieldButton = tip(addButton(rules, "", 340, 390, -124, function()
		local list = yieldChoices()
		local index = 1
		for position, key in ipairs(list) do
			if key == cur().yieldTo then index = position end
		end
		ns.FIELDS.yieldto(selected, list[index % #list + 1])
		ns.afterChange(selected)
	end), L["While the chosen other alert wants to show something, this one stays invisible. Each click picks the next alert."], L["Priority"])
	yieldButton.Refresh = function(self)
		local partner = ns.alerts[cur().yieldTo or ""]
		self:SetText(L["Stands behind: "] .. (partner and partner.def.title or L["(none)"]))
	end
	yieldButton.kind = "ready"
	widgets[#widgets + 1] = yieldButton
	-- Rangfolge: nur zum Nachlesen, geändert wird sie mit /sha set <alarm> behind ...
	local function behindNames()
		local names = {}
		for key in tostring(cur().behind or ""):gmatch("[^,%s]+") do
			local other = ns.alerts[key]
			if other then names[#names + 1] = other.def.title end
		end
		return names
	end
	local behindText = addText(rules, "", "GameFontHighlightSmall", 390, -226, 350)
	behindText.visibleIf = function() return selected.def.kind ~= "stacks" and #behindNames() > 0 end
	behindText.Refresh = function(self)
		self:SetText(L["Order: if one of these alerts shows something, this one stays invisible: "] .. table.concat(behindNames(), ", ") .. ".")
	end
	widgets[#widgets + 1] = behindText
	-- Die Überschrift steht nur da, wenn darunter etwas zu sehen ist.
	local timingToggle = {}
	timingToggle.Refresh = function()
		local shown = yieldButton:IsShown() or _G[FRAME_NAME .. "Lead"]:IsShown() or _G[FRAME_NAME .. "MinHealth"]:IsShown() or _G[FRAME_NAME .. "Refresh"]:IsShown() or behindText:IsShown()
		timingHeader:SetShown(shown)
		timingHeader.line:SetShown(shown)
	end
	widgets[#widgets + 1] = timingToggle

	-- Reiter "Sound" ------------------------------------------------------------
	local sound = tabFrames.sound
	addHeader(sound, L["Sound"], 0, 0, CONTENT_W)
	for index = 1, 3 do
		local check = addCheck(sound, "", (index - 1) * 170, -24,
			function() return cur().sound == ns.soundModes(selected)[index] end,
			function()
				ns.setSoundMode(selected, ns.soundModes(selected)[index])
				if ns.state.pendingSounds then ns.msg(L["You are in combat, the sound mode takes effect after combat."]) end
				ns.RefreshOptions()
			end)
		check:SetSize(22, 22)
		check.soundMode = index
		local refreshChecked = check.Refresh
		check.Refresh = function(self)
			local mode = ns.soundModes(selected)[index]
			self:SetShown(mode ~= nil)
			self.label:SetShown(mode ~= nil)
			local texts = selected.def.kind == "ready" and SOUND_MODE_TEXT_READY or SOUND_MODE_TEXT
			self.label:SetText(mode and texts[mode] or "")
			refreshChecked(self)
		end
	end

	addButton(sound, "<", 24, 0, -58, function() stepSound(-1) end).soundStep = -1
	local soundButton = addButton(sound, "", 240, 28, -58, function(self) openSoundMenu(self) end)
	soundButton.Refresh = function(self)
		local list = soundChoices()
		local index = currentSoundIndex(list)
		self:SetText(index and list[index].name or tostring(cur().soundFile))
	end
	widgets[#widgets + 1] = soundButton
	addButton(sound, ">", 24, 272, -58, function() stepSound(1) end).soundStep = 1
	addButton(sound, L["Listen"], 90, 304, -58, function() ns.playAlertSound(selected) end)

	local hint = addText(sound, "", "GameFontDisableSmall", 0, -92, 640)
	hint:SetJustifyV("TOP")
	hint.Refresh = function(self) self:SetText(SOUND_HINT[selected.def.kind]) end
	widgets[#widgets + 1] = hint

	-- Reiter "Zauber & Aura" ----------------------------------------------------
	local aura = tabFrames.aura
	local auraSection = {}
	local function inAuraSection(region)
		auraSection[#auraSection + 1] = region
		return region
	end
	addHeader(aura, L["Spell or aura"], 0, 0, CONTENT_W)
	inAuraSection(addText(aura, L["Name:"], nil, 0, -30))
	local nameBox = addEditBox(aura, 200, 42, -26, function(_, text)
		if text == "" then return end
		cur().auraName = text
		ns.state.lastScan = 0
		ns.onAuraChanged()
		ns.msg(L["Aura name: %s. The ID is learned as soon as the aura is readable out of combat."], text)
	end)
	nameBox.field = "auraName"
	nameBox.Refresh = function(self) self:SetText(tostring(cur().auraName or "")) end
	widgets[#widgets + 1] = nameBox

	inAuraSection(addText(aura, "ID:", nil, 266, -30))
	local function addID(box)
		local text = (box:GetText() or ""):match("^%s*(.-)%s*$")
		if text == "" then return end
		ns.commands.id(selected.key .. " " .. text)
		box:SetText("")
	end
	local idBox = addEditBox(aura, 70, 286, -26, function(self) addID(self) end)
	idBox.field = "id"
	inAuraSection(addButton(aura, "+", 24, 370, -25, function() addID(idBox) end))
	inAuraSection(tip(addButton(aura, L["List auras"], 130, CONTENT_W - 130, -25, function() ns.commands.scan() end),
		L["Writes your buffs and your debuffs on the target with their IDs into the chat. This only works out of combat."]))

	local ids = addText(aura, "", "GameFontDisableSmall", 0, -58, 620)
	ids.Refresh = function(self)
		local list = ns.sortedSpellIDs(selected)
		if selected.def.kind == "ready" then
			self:SetText(#list == 0 and L["Enter the name of the spell above. It must be in your spellbook."]
				or (L["Spell IDs: "] .. table.concat(list, ", ")))
		elseif #list == 0 then
			self:SetText(L["No aura ID known yet. The alert only appears once you have had the aura out of combat or enter an ID."])
		else
			self:SetText(L["Tracked IDs: "] .. table.concat(list, ", "))
		end
	end
	widgets[#widgets + 1] = ids
	inAuraSection(nameBox)
	inAuraSection(idBox)
	inAuraSection(ids)
	local auraNote = addText(aura, L["This alert checks the weapons directly and needs no aura."], "GameFontDisableSmall", 0, -30, 620)

	-- Nur bei eigenen Alarmen: Titel, Art, Einheit und Aura-Typ
	local customHeader = addHeader(aura, L["Custom alert"], 0, -116, CONTENT_W)
	local titleLabel = addText(aura, L["Title:"], nil, 0, -146)
	local titleBox = addEditBox(aura, 240, 42, -142, function(_, text)
		if text == "" then return end
		ns.FIELDS.title(selected, text)
		ns.afterChange(selected)
	end)
	titleBox.field = "title"
	titleBox.Refresh = function(self) self:SetText(selected.def.title) end
	widgets[#widgets + 1] = titleBox
	local function nextOf(list, current)
		for index, value in ipairs(list) do
			if value == current then return list[index % #list + 1] end
		end
		return list[1]
	end
	local function customButton(x, width, describe, advance)
		local button = addButton(aura, "", width, x, -174, function()
			advance()
			ns.afterChange(selected)
		end)
		button.Refresh = function(self)
			if selected.def.custom then self:SetText(describe()) end
		end
		widgets[#widgets + 1] = button
		return button
	end
	local AURA_TYPES = { "buff", "debuff", "mine" }
	local AURA_TYPE_NAMES = { buff = L["Buff"], debuff = L["Debuff"], mine = L["Own debuff"] }
	local function auraType()
		local spec = selected.def.spec
		return not spec.harmful and "buff" or (spec.mine and "mine" or "debuff")
	end

	-- Fußzeile der Alarm-Seite
	tip(addButton(page, L["Test"], 100, 0, -PAGE_H + 30, function() ns.commands.test(selected.key) end),
		L["Shows the alert in its place for three seconds and plays its sound."])
	tip(addButton(page, L["Status"], 100, 108, -PAGE_H + 30, function() ns.commands.status() end),
		L["Writes into the chat how the addon currently rates each alert."])
	local deleteButton = addButton(page, L["Delete"], 90, CONTENT_W - 120 - 98, -PAGE_H + 30, function()
		local alert = selected
		confirm((L["Delete the custom alert \"%s\"?"]):format(alert.def.title), function() ns.commands.delete(alert.key) end)
	end)
	addButton(page, L["Reset"], 120, CONTENT_W - 120, -PAGE_H + 30, function()
		local alert = selected
		confirm((L["Reset all settings of \"%s\" to the defaults?"]):format(alert.def.title), function() ns.commands.reset(alert.key) end)
	end)

	local customGroup = {
		customHeader, customHeader.line, titleLabel, titleBox, deleteButton,
		tip(customButton(0, 150, function() return L["Kind: "] .. ns.KIND_NAMES[selected.def.kind] end,
			function() ns.FIELDS.kind(selected, nextOf(ns.CUSTOM_KINDS, selected.def.kind)) end),
			L["When the alert appears: while the aura is active, while it is missing, from a number of stacks or as soon as a spell is ready."], L["Kind of alert"]),
	}
	-- Einheit und Aura-Typ gibt es nur bei Aura-Alarmen, nicht bei "Zauber bereit".
	local auraOnly = {
		customButton(154, 130, function() return L["Unit: "] .. (selected.def.unit == "player" and L["Player"] or L["Target"]) end,
			function() ns.FIELDS.unit(selected, selected.def.unit == "player" and "target" or "player") end),
		customButton(288, 150, function() return L["Type: "] .. AURA_TYPE_NAMES[auraType()] end,
			function() ns.FIELDS.auratype(selected, nextOf(AURA_TYPES, auraType())) end),
	}
	local customToggle = {}
	customToggle.Refresh = function()
		local custom = selected.def.custom == true
		for _, region in ipairs(customGroup) do region:SetShown(custom) end
		for _, region in ipairs(auraOnly) do region:SetShown(custom and selected.def.kind ~= "ready") end
	end
	local auraToggle = {}
	auraToggle.Refresh = function()
		local usesAura = selected.def.kind ~= "weapon"
		for _, region in ipairs(auraSection) do region:SetShown(usesAura) end
		auraNote:SetShown(not usesAura)
	end
	widgets[#widgets + 1] = auraToggle
	widgets[#widgets + 1] = customToggle

	-- Seite "Hilfe & Diagnose" --------------------------------------------------
	local help = CreateFrame("Frame", nil, window)
	help:SetPoint("TOPLEFT", window, "TOPLEFT", CONTENT_X, -28)
	help:SetSize(CONTENT_W, PAGE_H)
	help:Hide()
	pages.help = help
	addText(help, L["Help & diagnostics"], "GameFontNormalLarge", 0, -8)
	addHeader(help, L["Commands"], 0, -44, CONTENT_W)
	addText(help, table.concat({
		L["/sha – open or close this window"],
		L["/sha test [alert] – preview for three seconds, with the sound"],
		L["/sha status – write the state of all alerts into the chat"],
		L["/sha set <alert> <field> <value> – change a setting by command"],
		L["/sha new [title] and /sha delete <alert> – create and delete your own alerts"],
		L["/sha scan – list your buffs and your debuffs on the target with their IDs"],
		L["/sha totem – the page of the totem bar"],
		L["/sha profile – save and load profiles, share settings"],
		L["/sha minimap – show or hide the minimap button"],
		L["/sha reset [alert] – reset one alert or everything"],
		L["/sha debug – record diagnostics"],
		L["/sha help – all commands and fields"],
	}, "\n"), nil, 0, -68, CONTENT_W)

	addHeader(help, L["Diagnostics"], 0, -234, CONTENT_W)
	addText(help, L["If an alert does not appear as expected: get into the situation where it goes wrong and click \"Record diagnostics\". For 30 seconds the addon writes down how it rates each alert. As soon as the chat says \"Diagnostics done\", type /reload. Only the /reload puts the recording on disk."],
		nil, 0, -258, CONTENT_W)
	addButton(help, L["Record diagnostics"], 190, 0, -316, function() ns.commands.debug("") end)
	addButton(help, L["Status to chat"], 190, 198, -316, function() ns.commands.status() end)

	addHeader(help, L["Reset everything"], 0, -362, CONTENT_W)
	addText(help, L["Resets all alerts and the totem bar to the defaults. Your own alerts stay but lose their settings. Saved profiles stay."], nil, 0, -386, CONTENT_W)
	addButton(help, L["Reset everything"], 190, 0, -420, function()
		confirm(L["Really reset all ShamanAlerts settings?"], function() ns.commands.reset("") end)
	end)

	addHeader(help, L["Minimap"], 0, -466, CONTENT_W)
	tip(addCheck(help, L["Show minimap button"], 0, -488,
		function() return ns.Minimap ~= nil and ns.Minimap.IsShown() end,
		function(value)
			if ns.Minimap then ns.Minimap.SetShown(value) end
		end), L["A left click on the button opens this window, a right click the page of the totem bar. The addon is also listed in the addon menu of the minimap and under Options > AddOns."])

	-- Seite "Profile & Austausch" -----------------------------------------------
	local prof = CreateFrame("Frame", nil, window)
	prof:SetPoint("TOPLEFT", window, "TOPLEFT", CONTENT_X, -28)
	prof:SetSize(CONTENT_W, PAGE_H)
	prof:Hide()
	pages.profiles = prof
	addText(prof, L["Profiles & sharing"], "GameFontNormalLarge", 0, -8)
	addHeader(prof, L["Profiles"], 0, -44, CONTENT_W)
	addText(prof, L["A profile is a saved state of all settings: alerts, your own alerts, totem bar and font. \"Save\" stores the current state under the name. \"Load\" replaces the current settings with the profile. Later changes only reach the profile with the next \"Save\"."],
		nil, 0, -68, CONTENT_W)
	local chosenProfile
	local profileNote = addText(prof, "", "GameFontNormalSmall", 0, -186, CONTENT_W)
	local pickProfile, loadProfile, deleteProfile
	local function refreshProfiles()
		local names = ns.Profiles.List()
		local known = {}
		for _, name in ipairs(names) do known[name] = true end
		if not known[chosenProfile] then chosenProfile = known[ns.Profiles.Current()] and ns.Profiles.Current() or names[1] end
		pickProfile:SetText(chosenProfile and (L["Profile: "] .. chosenProfile) or L["No profile saved yet"])
		pickProfile:SetEnabled(#names > 0)
		loadProfile:SetEnabled(chosenProfile ~= nil)
		deleteProfile:SetEnabled(chosenProfile ~= nil)
	end
	local function report(note, ok, message)
		note:SetText(message or "")
		note:SetTextColor(ok and 0.4 or 1, ok and 1 or 0.35, 0.35)
		refreshProfiles()
	end
	addText(prof, L["Name:"], nil, 0, -122)
	local nameBox
	local function saveProfile()
		local name = (nameBox:GetText() or ""):match("^%s*(.-)%s*$")
		local ok, message = ns.Profiles.Save(name)
		if ok then chosenProfile = ns.Profiles.Current() end
		report(profileNote, ok, message)
	end
	nameBox = addEditBox(prof, 200, 44, -118, saveProfile)
	view.profileName = nameBox
	tip(addButton(prof, L["Save"], 110, 262, -118, saveProfile), L["Stores the current state under this name. If the profile already exists, it is overwritten."])
	local function stepProfile()
		local names = ns.Profiles.List()
		local index = 0
		for position, name in ipairs(names) do
			if name == chosenProfile then index = position end
		end
		chosenProfile = names[index % math.max(1, #names) + 1]
		refreshProfiles()
	end
	pickProfile = tip(addButton(prof, "", 250, 0, -150, function(self)
		if not (MenuUtil and MenuUtil.CreateContextMenu) then return stepProfile() end
		local ok = pcall(MenuUtil.CreateContextMenu, self, function(_, root)
			for _, name in ipairs(ns.Profiles.List()) do
				root:CreateRadio(name,
					function() return chosenProfile == name end,
					function()
						chosenProfile = name
						refreshProfiles()
					end)
			end
		end)
		if not ok then stepProfile() end
	end), L["Picks the profile to be loaded or deleted."], L["Profile"])
	loadProfile = tip(addButton(prof, L["Load"], 110, 262, -150, function()
		local name = chosenProfile
		confirm((L["Load profile \"%s\"? This replaces the current settings."]):format(tostring(name)), function()
			report(profileNote, ns.Profiles.Load(name))
		end)
	end), L["Replaces all current settings with the chosen profile. This does not work in combat."])
	deleteProfile = tip(addButton(prof, L["Delete"], 110, 378, -150, function()
		local name = chosenProfile
		confirm((L["Delete profile \"%s\"?"]):format(tostring(name)), function()
			report(profileNote, ns.Profiles.Delete(name))
		end)
	end), L["Deletes the chosen profile. The current settings stay as they are."])
	view.profileButtons = { pick = pickProfile, load = loadProfile, delete = deleteProfile }
	view.profileNote = profileNote

	addHeader(prof, L["Sharing"], 0, -220, CONTENT_W)
	addText(prof, L["\"Export\" writes the current settings as text into the field. Copy it with Ctrl+C and pass it on. To import, paste such a text with Ctrl+V and click \"Import\". This replaces the current settings. Saved profiles stay."],
		nil, 0, -244, CONTENT_W)
	local scroll = CreateFrame("ScrollFrame", FRAME_NAME .. "ExchangeScroll", prof, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", prof, "TOPLEFT", 6, -296)
	scroll:SetSize(CONTENT_W - 38, 236)
	local scrollBack = prof:CreateTexture(nil, "BACKGROUND")
	scrollBack:SetColorTexture(0, 0, 0, 0.45)
	scrollBack:SetPoint("TOPLEFT", scroll, "TOPLEFT", -6, 6)
	scrollBack:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 6, -6)
	local exchange = CreateFrame("EditBox", nil, scroll)
	exchange:SetMultiLine(true)
	exchange:SetAutoFocus(false)
	exchange:SetFontObject(ChatFontNormal or GameFontHighlightSmall)
	exchange:SetWidth(CONTENT_W - 44)
	if exchange.SetMaxLetters then exchange:SetMaxLetters(0) end
	exchange:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	scroll:SetScrollChild(exchange)
	-- Ein Klick irgendwo ins Feld setzt die Schreibmarke, auch wenn es leer ist.
	if scroll.EnableMouse then scroll:EnableMouse(true) end
	scroll:SetScript("OnMouseDown", function() exchange:SetFocus() end)
	view.exchange = exchange
	local exchangeNote = addText(prof, "", "GameFontNormalSmall", 0, -582, CONTENT_W)
	view.exchangeNote = exchangeNote
	local function exportNow()
		local text = ns.Profiles.Export()
		exchange:SetText(text)
		exchange:SetFocus()
		if exchange.HighlightText then exchange:HighlightText() end
		report(exchangeNote, true, (L["Export done, %d characters. The text is selected: Ctrl+C copies it."]):format(#text))
	end
	view.exportNow = exportNow
	tip(addButton(prof, L["Export"], 120, 0, -550, exportNow), L["Writes the current settings as text into the field and selects it."])
	tip(addButton(prof, L["Import"], 120, 126, -550, function()
		local text = exchange:GetText() or ""
		local snapshot, problem = ns.Profiles.Read(text)
		if not snapshot then return report(exchangeNote, false, problem) end
		confirm(L["Take over the settings from the text? This replaces the current settings."], function()
			local ok, reason = ns.Profiles.Import(text)
			report(exchangeNote, ok, ok and L["Import done. The settings from the text apply now."] or reason)
		end)
	end), L["Reads the text in the field and replaces all current settings with it. Only what the addon knows is taken over. This does not work in combat."])
	tip(addButton(prof, L["Clear field"], 120, 252, -550, function()
		exchange:SetText("")
		report(exchangeNote, true, "")
	end), L["Clears the field."])
	view.refreshProfiles = refreshProfiles

	window.view = view
	window:SetScript("OnShow", function(self)
		self:Raise()
		showPage()
	end)
	window:SetScript("OnHide", function()
		ns.setMoving(nil)
		ns.flushScheduledBuilds()
		-- gibt die Totem-Leiste wieder frei, falls ihre Seite offen war
		if totemFrame and totemFrame:IsShown() then totemFrame:Hide() end
	end)
	return window
end

-- relocate: Textur-Auswahl auf die Seite mit der gewählten Textur blättern
function ns.RefreshOptions(relocate)
	if not frame then return end
	-- Nach dem Laden eines Profils kann der gewählte eigene Alarm verschwunden sein.
	if selected and ns.alerts[selected.key] ~= selected then selected = ns.alerts[1] end
	if view.refreshProfiles then view.refreshProfiles() end
	if relocate then locateSelection() end
	refreshSidebar()
	local kind = selected.def.kind
	view.title:SetText(selected.def.title)
	view.kind:SetText(ns.KIND_NAMES[kind] or "")
	view.desc:SetText(DESCRIPTIONS[selected.key] or KIND_DESCRIPTIONS[kind] or "")
	for _, button in ipairs(view.tabs) do
		local chosen = button.tabKey == activeTab
		button:SetEnabled(not chosen) -- der offene Reiter ist ausgegraut und unterstrichen
		button.underline:SetShown(chosen)
		view.tabFrames[button.tabKey]:SetShown(chosen)
	end
	for _, widget in ipairs(widgets) do
		local visible = (widget.kind == nil or widget.kind == kind) and widget.hideFor ~= kind
			and (widget.visibleIf == nil or widget.visibleIf())
		if widget.kind ~= nil or widget.hideFor ~= nil or widget.visibleIf ~= nil then
			widget:SetShown(visible)
			if widget.label then widget.label:SetShown(visible) end
		end
		if visible and widget.Refresh then widget:Refresh() end
	end
end

-- Wählt einen Alarm im Fenster aus, zum Beispiel nach dem Anlegen oder Löschen.
function ns.SelectAlert(alert)
	if selected ~= nil or frame then selectAlert(alert) end
end

function ns.ToggleOptions(forceShow)
	if not ns.db then return end
	selected = selected or ns.alerts[1]
	frame = frame or createFrame()
	if forceShow or not frame:IsShown() then
		activePage = "alerts"
		if frame:IsShown() then showPage() else frame:Show() end
	else
		frame:Hide()
	end
end

-------------------------------------------------------------------------------
-- Seite für die Totem-Leiste und die Schrift
-------------------------------------------------------------------------------

local TOTEM_FRAME_NAME = "ShamanAlertsTotemOptionsFrame"
local totemWidgets = {}

function createTotemFrame(parent)
	local totems = ns.Totems
	local function t() return totems.settings end
	local window = CreateFrame("Frame", TOTEM_FRAME_NAME, parent)
	window:Hide()
	window:SetSize(690, 600) -- links Leiste und Schrift, rechts die Abklingzeiten
	window:SetPoint("TOPLEFT", parent, "TOPLEFT", CONTENT_X - 16, -26)
	addText(window, L["Totem bar and font"], "GameFontNormalLarge", 16, -10)

	local previous = sink
	sink = { list = totemWidgets, changed = totems.Apply }

	addCheck(window, L["Show totem bar"], 16, -32,
		function() return t().enabled end,
		function(value)
			t().enabled = value
			totems.Apply()
		end)

	local styleButton = addButton(window, "", 156, 16, -64, function()
		t().style = t().style == "icons" and "bars" or "icons"
		totems.Apply()
		ns.RefreshTotemOptions()
	end)
	styleButton.Refresh = function(self) self:SetText(L["Display: "] .. totems.STYLE_NAMES[t().style]) end
	totemWidgets[#totemWidgets + 1] = styleButton

	local growthButton = addButton(window, "", 156, 178, -64, function()
		local index = 1
		for position, key in ipairs(totems.GROWTH_ORDER) do
			if key == t().growth then index = position end
		end
		t().growth = totems.GROWTH_ORDER[index % #totems.GROWTH_ORDER + 1]
		totems.Apply()
		ns.RefreshTotemOptions()
	end)
	growthButton.Refresh = function(self) self:SetText(L["Direction: "] .. totems.GROWTH_NAMES[t().growth]) end
	totemWidgets[#totemWidgets + 1] = growthButton

	addSlider(window, "TotemSize", L["Icon size"], 20, -116, 16, 80, 2,
		function(value) return ("%d"):format(value) end,
		function() return t().iconSize end,
		function(value) t().iconSize = value end)
	addSlider(window, "TotemSpacing", L["Spacing of the slots"], 20, -162, 0, 40, 1,
		function(value) return ("%d"):format(value) end,
		function() return t().spacing end,
		function(value) t().spacing = value end)
	addSlider(window, "TotemBarWidth", L["Bar width"], 20, -208, 40, 400, 10,
		function(value) return ("%d"):format(value) end,
		function() return t().barWidth end,
		function(value) t().barWidth = value end)
	addSlider(window, "TotemAlpha", L["Opacity"], 20, -254, 10, 100, 5,
		function(value) return ("%d %%"):format(value) end,
		function() return math.floor(t().alpha * 100 + 0.5) end,
		function(value) t().alpha = value / 100 end)

	addCheck(window, L["Show totem names"], 16, -282,
		function() return t().showNames end,
		function(value)
			t().showNames = value
			totems.Apply()
		end)
	addCheck(window, L["Show empty slots"], 16, -306,
		function() return t().showEmpty end,
		function(value)
			t().showEmpty = value
			totems.Apply()
		end)

	-- Schrift: gilt für die Totem-Leiste und für die Restzeit der Alarme
	addHeader(window, L["Font"], 16, -340, 318)
	local function setFace(key)
		ns.db.font.face = key
		ns.refreshTexts()
	end
	local function stepFace()
		local choices = ns.fontChoices()
		local index = 1
		for position, choice in ipairs(choices) do
			if choice.key == ns.db.font.face then index = position end
		end
		setFace(choices[index % #choices + 1].key)
	end
	local fontButton = addButton(window, "", 318, 16, -364, function(self)
		if not (MenuUtil and MenuUtil.CreateContextMenu) then return stepFace() end
		local choices = ns.fontChoices()
		local ok = pcall(MenuUtil.CreateContextMenu, self, function(_, root)
			if root.SetScrollMode then root:SetScrollMode(360) end
			for _, choice in ipairs(choices) do
				root:CreateRadio(choice.name,
					function() return ns.db.font.face == choice.key end,
					function() setFace(choice.key) end)
			end
		end)
		if not ok then stepFace() end
	end)
	fontButton.Refresh = function(self)
		local face = ns.db.font.face
		self:SetText(face == "auto" and L["Automatic (like the action bars)"] or face)
	end
	totemWidgets[#totemWidgets + 1] = fontButton

	local outlineButton = addButton(window, "", 318, 16, -390, function()
		local order = ns.OUTLINE_ORDER
		local index = 1
		for position, key in ipairs(order) do
			if key == ns.db.font.outline then index = position end
		end
		ns.db.font.outline = order[index % #order + 1]
		ns.refreshTexts()
	end)
	outlineButton.Refresh = function(self) self:SetText(L["Outline: "] .. ns.OUTLINE_NAMES[ns.db.font.outline]) end
	totemWidgets[#totemWidgets + 1] = outlineButton

	addSlider(window, "TotemFontSize", L["Font size of the totem bar"], 20, -442, 6, 32, 1,
		function(value) return ("%d"):format(value) end,
		function() return t().fontSize end,
		function(value) t().fontSize = value end)
	sink.changed = ns.refreshTexts
	addSlider(window, "TimerFontSize", L["Font size of the time left on alerts"], 20, -488, 6, 32, 1,
		function(value) return ("%d"):format(value) end,
		function() return ns.db.font.timerSize end,
		function(value) ns.db.font.timerSize = value end)
	sink.changed = totems.Apply

	local position = addText(window, "", nil, 18, -520, 310)
	position.Refresh = function(self)
		self:SetText((L["Position X %d, Y %d. While this page is open the bar shows examples and can be dragged with the mouse."]):format(t().x, t().y))
	end
	totemWidgets[#totemWidgets + 1] = position

	addButton(window, L["Reset"], 120, 350 - 16 - 120, -564, function()
		totems.Reset()
		ns.RefreshTotemOptions()
	end)

	-- Rechte Spalte: Abklingzeiten wichtiger Totems als Symbole an der Leiste
	local COLUMN = 356
	addHeader(window, L["Cooldowns at the bar"], COLUMN, -36, 318)
	addCheck(window, L["Show cooldowns of important totems"], COLUMN, -58,
		function() return t().cooldowns end,
		function(value)
			t().cooldowns = value
			totems.Apply()
			ns.RefreshTotemOptions()
		end)
	local sideButton = addButton(window, "", 318, COLUMN, -88, function()
		local index = 1
		for position, key in ipairs(totems.CD_SIDE_ORDER) do
			if key == t().cdSide then index = position end
		end
		t().cdSide = totems.CD_SIDE_ORDER[index % #totems.CD_SIDE_ORDER + 1]
		totems.Apply()
		ns.RefreshTotemOptions()
	end)
	sideButton.Refresh = function(self) self:SetText(L["Place: "] .. totems.CD_SIDE_NAMES[t().cdSide]) end
	totemWidgets[#totemWidgets + 1] = sideButton
	addSlider(window, "TotemCooldownSize", L["Size of the icons"], COLUMN + 4, -140, 12, 60, 2,
		function(value) return ("%d"):format(value) end,
		function() return t().cdSize end,
		function(value) t().cdSize = value end)

	addText(window, L["Spells, separated by commas (Enter applies):"], nil, COLUMN + 2, -172, 316)
	local spellBox = addEditBox(window, 308, COLUMN + 2, -188, function(_, text)
		totems.SetField("cdspells", text) -- leer = wieder die Voreinstellung
	end)
	spellBox.Refresh = function(self) self:SetText(tostring(t().cdSpells or "")) end
	totemWidgets[#totemWidgets + 1] = spellBox
	local known = addText(window, "", nil, COLUMN + 2, -216, 316)
	known.Refresh = function(self) self:SetText(L["Found in your spellbook: "] .. totems.CooldownSummary() .. ".") end
	totemWidgets[#totemWidgets + 1] = known
	addText(window, L["Only spells your character knows are shown. A bright icon means ready, a gray one with a number is still cooling down. The row hangs on the totem bar and moves with it."], nil, COLUMN + 2, -272, 316)

	sink = previous
	window:SetScript("OnShow", function()
		ns.RefreshTotemOptions()
		totems.SetUnlocked(true)
	end)
	window:SetScript("OnHide", function() totems.SetUnlocked(false) end)
	return window
end

function ns.RefreshTotemOptions()
	if not totemFrame then return end
	for _, widget in ipairs(totemWidgets) do
		if widget.Refresh then widget:Refresh() end
	end
end

-- Öffnet das Fenster auf der Seite der Totem-Leiste. Steht sie schon offen,
-- schließt der Aufruf das Fenster.
function ns.ToggleTotemOptions(forceShow)
	if not (ns.db and ns.Totems and ns.Totems.settings) then return end
	local open = frame and frame:IsShown() and activePage == "totems" and totemFrame and totemFrame:IsShown()
	if open and not forceShow then return frame:Hide() end
	selected = selected or ns.alerts[1]
	frame = frame or createFrame()
	activePage = "totems"
	if frame:IsShown() then showPage() else frame:Show() end
end

-- Öffnet das Fenster auf einer bestimmten Seite: "alerts", "totems",
-- "profiles" oder "help". action "export" füllt dort gleich das Austausch-Feld.
function ns.ShowOptionsPage(key, action)
	if not ns.db then return end
	if key == "totems" then return ns.ToggleTotemOptions(true) end
	selected = selected or ns.alerts[1]
	frame = frame or createFrame()
	activePage = pages[key] and key or "alerts"
	if frame:IsShown() then showPage() else frame:Show() end
	if action == "export" and activePage == "profiles" and view.exportNow then view.exportNow() end
end

-- Symbol im Addon-Menü an der Minimap (siehe .toc)
function ShamanAlerts_OnAddonCompartmentClick()
	ns.ToggleOptions()
end

-- Eintrag unter Optionen > AddOns, der das Fenster öffnet
do
	local panel = CreateFrame("Frame")
	panel.name = "ShamanAlerts"
	local logo = panel:CreateTexture(nil, "ARTWORK")
	logo:SetSize(48, 48)
	logo:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
	logo:SetTexture("Interface\\AddOns\\ShamanAlerts\\Media\\icon")
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -4)
	title:SetText("ShamanAlerts")
	local versionText = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	versionText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	local number = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
	versionText:SetText(L["Version "] .. tostring(number or "?") .. "  ·  /sha")
	local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -14)
	text:SetJustifyH("LEFT")
	text:SetWidth(560)
	if text.SetWordWrap then text:SetWordWrap(true) end
	text:SetText(L["Alerts around your character for shamans: Maelstrom Weapon, the shocks, Stormstrike, shield, weapon enchant and more, plus a totem bar and your own alerts. Everything else is set in the window of the addon."])
	local panelButtons = {}
	local function panelButton(label, x, y, onClick)
		local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		button:SetSize(200, 24)
		button:SetPoint("TOPLEFT", text, "BOTTOMLEFT", x, y)
		button:SetText(label)
		button:SetScript("OnClick", onClick)
		panelButtons[#panelButtons + 1] = button
		return button
	end
	local open = panelButton(L["Set up alerts"], 0, -16, function() ns.ToggleOptions(true) end)
	panelButton(L["Totem bar & font"], 208, -16, function() ns.ShowOptionsPage("totems") end)
	panelButton(L["Profiles & sharing"], 0, -46, function() ns.ShowOptionsPage("profiles") end)
	panelButton(L["Help & diagnostics"], 208, -46, function() ns.ShowOptionsPage("help") end)
	local minimapCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	minimapCheck:SetSize(24, 24)
	minimapCheck:SetPoint("TOPLEFT", text, "BOTTOMLEFT", -2, -84)
	local minimapLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	minimapLabel:SetPoint("LEFT", minimapCheck, "RIGHT", 2, 0)
	minimapLabel:SetText(L["Show minimap button"])
	minimapCheck:SetScript("OnClick", function(self)
		if ns.Minimap then ns.Minimap.SetShown(self:GetChecked() and true or false) end
		ns.RefreshOptions()
	end)
	panel:SetScript("OnShow", function()
		minimapCheck:SetChecked(ns.Minimap ~= nil and ns.Minimap.IsShown())
	end)
	ns.settingsPanel = { panel = panel, open = open, buttons = panelButtons, minimap = minimapCheck }

	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "ShamanAlerts")
		if ok and category then pcall(Settings.RegisterAddOnCategory, category) end
	end
end
