-- ShamanAlerts: Knopf an der Minimap
--
-- Linksklick öffnet die Optionen, Rechtsklick die Seite der Totem-Leiste.
-- Sind LibDataBroker und LibDBIcon geladen (viele Addons bringen sie mit),
-- meldet sich der Knopf dort an. Dann sammeln ihn auch Minimap-Addons ein und
-- Leisten für Datenquellen zeigen ShamanAlerts als Starter. Ohne die
-- Bibliotheken zeichnet das Addon einen eigenen Knopf, der sich um die Minimap
-- ziehen lässt.
local ADDON, ns = ...
local L = ns.L

local M = {}
ns.Minimap = M

local NAME = "ShamanAlerts"
local ICON = "Interface\\AddOns\\ShamanAlerts\\Media\\icon"
ns.ICON = ICON
local DEFAULT_ANGLE = 215 -- unten links an der Minimap

local settings -- db.minimap: hide, minimapPos (Winkel in Grad), wie bei LibDBIcon
local library -- LibDBIcon, falls vorhanden
local button -- der eigene Knopf, falls nicht

local function version()
	local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	if not get then return nil end
	local ok, value = pcall(get, ADDON, "Version")
	return ok and type(value) == "string" and value ~= "" and value or nil
end
M.Version = version

local function fillTooltip(tooltip)
	if not tooltip or not tooltip.AddLine then return end
	local number = version()
	tooltip:AddLine(NAME .. (number and (" |cff999999" .. number .. "|r") or ""), 1, 0.82, 0)
	tooltip:AddLine(L["Left click: open the options"], 1, 1, 1)
	tooltip:AddLine(L["Right click: totem bar and font"], 1, 1, 1)
	if not library then tooltip:AddLine(L["Drag: move the button"], 0.7, 0.7, 0.7) end
end

local function onClick(_, mouseButton)
	if mouseButton == "RightButton" then
		if ns.ToggleTotemOptions then ns.ToggleTotemOptions() end
	elseif ns.ToggleOptions then
		ns.ToggleOptions()
	end
end

-- Stellt den eigenen Knopf auf seinen Winkel am Rand der Minimap.
local function place()
	local angle = math.rad(settings.minimapPos or DEFAULT_ANGLE)
	local x, y = math.cos(angle), math.sin(angle)
	local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
	if shape == "SQUARE" then
		-- bei einer eckigen Minimap am Rand des Quadrats entlang
		local scale = 1 / math.max(math.abs(x), math.abs(y), 0.01)
		x, y = x * scale, y * scale
	end
	local width = (Minimap:GetWidth() or 140) / 2 + 5
	local height = (Minimap:GetHeight() or 140) / 2 + 5
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x * width, y * height)
end

-- Beim Ziehen folgt der Knopf dem Mauszeiger rund um die Minimap.
local function followCursor()
	local centerX, centerY = Minimap:GetCenter()
	local cursorX, cursorY = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale() or 1
	if not centerX or not cursorX or scale == 0 then return end
	local angle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX)) % 360
	settings.minimapPos = math.floor(angle + 0.5)
	place()
end

local function createButton()
	button = CreateFrame("Button", "ShamanAlertsMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetSize(20, 20)
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetTexture(ICON)
	icon:SetTexCoord(0.06, 0.94, 0.06, 0.94)
	icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
	button.icon = icon
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
	button:SetScript("OnClick", onClick)
	button:SetScript("OnDragStart", function(self)
		if GameTooltip then GameTooltip:Hide() end
		self:SetScript("OnUpdate", followCursor)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		place()
	end)
	button:SetScript("OnEnter", function(self)
		if not GameTooltip then return end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		fillTooltip(GameTooltip)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		if GameTooltip then GameTooltip:Hide() end
	end)
	place()
end

-- Meldet den Knopf bei LibDBIcon an. Schlägt das fehl, bleibt der eigene Weg.
local function registerWithLibrary()
	if type(LibStub) ~= "table" and type(LibStub) ~= "function" then return false end
	local okBroker, broker = pcall(LibStub, "LibDataBroker-1.1", true)
	local okIcon, icons = pcall(LibStub, "LibDBIcon-1.0", true)
	if not (okBroker and broker and okIcon and icons and broker.NewDataObject and icons.Register) then return false end
	local ok, object = pcall(broker.NewDataObject, broker, NAME, {
		type = "launcher",
		text = NAME,
		icon = ICON,
		OnClick = onClick,
		OnTooltipShow = fillTooltip,
	})
	if not ok or not object then return false end
	if not pcall(icons.Register, icons, NAME, object, settings) then return false end
	library = icons
	return true
end

function M.IsShown()
	return settings ~= nil and not settings.hide
end

function M.SetShown(show)
	if not settings then return end
	settings.hide = not show
	if library then
		pcall(show and library.Show or library.Hide, library, NAME)
	else
		if show and not button and Minimap then createButton() end
		if button then button:SetShown(show) end
	end
end

function M.Init()
	if settings or not ns.db then return end
	local db = ns.db
	db.minimap = type(db.minimap) == "table" and db.minimap or {}
	settings = db.minimap
	if type(settings.hide) ~= "boolean" then settings.hide = false end
	if type(settings.minimapPos) ~= "number" then settings.minimapPos = DEFAULT_ANGLE end
	if not registerWithLibrary() and not settings.hide and Minimap then createButton() end
end

-- für Tests
M.internals = { place = function() if button then place() end end, button = function() return button end, usesLibrary = function() return library ~= nil end }
