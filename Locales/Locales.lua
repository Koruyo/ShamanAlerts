-- ShamanAlerts: Sprachen
--
-- Die Texte im Code sind Englisch und dienen zugleich als Schlüssel. Die
-- Dateien in diesem Ordner tragen für ihre Sprache die Übersetzungen ein.
-- Fehlt eine, erscheint der englische Text.
local _, ns = ...

ns.L = setmetatable({}, { __index = function(_, key) return key end })
ns.locale = GetLocale and GetLocale() or "enUS"
