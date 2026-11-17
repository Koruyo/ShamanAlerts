# Changelog

## 2.42.0
- When your target casts something you can interrupt and the shocks are ready, Earth Shock is
  now always suggested: the general shock alert takes the place of Flame Shock and Frost Shock
  for that time. New checkbox "Priority while the target casts" on the conditions tab
  (`/sha set earthshock castfirst off` switches it off)

## 2.41.1
- Releases are now uploaded to CurseForge as well; no change to the addon itself

## 2.41.0
- Localized for every client language: English, Deutsch, Français, Español, Italiano,
  Português (BR), Русский, 한국어, 简体中文, 繁體中文. English is the base language; all texts,
  picture names and chat messages follow the language of the game client
- Spells are found in every client language: the addon reads their names from the game instead
  of relying on German and English names

## 2.40.0
- New defaults: size 120 for most alerts, rune arrows for Flame Shock and Earth Shock, Fire Nova
  from 4 enemies, Interrupt and Berserking switched off
- The Interrupt alert no longer shares its place with the shocks
- Minimap button (left click: options, right click: totem bar), `/sha minimap`
- The entry under Options > AddOns shows icon and version and leads to every page
- Profiles and sharing: save, load and delete profiles; export and import the settings as a
  short text (`/sha profile`, `/sha export`)
- The addon has its own icon

## 2.39.0
- Flame Shock, Frost Shock and the general shock share one place, only the picture changes
- New condition "Not against players (PvP)", switched on for Flame Shock

## 2.38.0
- New alert "Frost Shock missing" against players, new condition "Only against players (PvP)"
- Order of the shocks, so only the most important one is shown: Interrupt, Frost Shock, Flame
  Shock, general shock
- New rune-style pictures for Earth Shock and Frost Shock

## 2.33.0 to 2.37.0
- Early refresh: Flame Shock is suggested two seconds before it runs out, timed by the addon's
  own clock
- Pictures that stand for all three shocks, and rune-style pictures for Flame Shock
- An error in one alert no longer stops the others

## 2.32.0
- New options window: list of alerts on the left, five tabs per alert, pages for the totem bar
  and for help and diagnostics

## 2.31.0
- New alert "Interrupt": appears when your target casts something you can stop

## 2.26.0 to 2.30.0
- New alert "Fire Nova ready" with an enemy count and a fire totem condition
- Row of totem cooldowns at the totem bar
- More Flame Shock pictures in the style of WoW ability icons

## 2.24.0 and 2.25.0
- New alert "Berserking ready" for trolls
- 30 pictures in the style of WoW ability icons; they are the default for all alerts

The detailed history up to 2.40.0 is kept in German in `docs/AENDERUNGEN.md` of the repository.
