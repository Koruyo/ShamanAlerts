# Veröffentlichen auf CurseForge

Das Repo ist öffentlich: <https://github.com/Koruyo/ShamanAlerts>. Ein Tag wie `v2.41.0` baut
über GitHub Actions das Zip und legt es unter *Releases* ab.

## 1. CurseForge-Projekt anlegen

1. Auf <https://authors.curseforge.com> → **Create Project** → *World of Warcraft* → *Addons*.
2. Diese Felder ausfüllen:

| Feld | Inhalt |
|---|---|
| Name | `ShamanAlerts` |
| Summary | Text aus [`curseforge-summary.txt`](curseforge-summary.txt) |
| Description | Inhalt von [`curseforge-description.md`](curseforge-description.md) (Editor auf **Markdown** stellen) |
| Logo / Avatar | [`assets/logo.png`](../assets/logo.png) (512×512) oder [`assets/logo-400.png`](../assets/logo-400.png) |
| Primary Category | Combat |
| Weitere Kategorien | Class, Buffs & Debuffs |
| License | MIT |
| Source | `https://github.com/Koruyo/ShamanAlerts` |
| Issues | `https://github.com/Koruyo/ShamanAlerts/issues` |

3. **Banner:** Die Beschreibung bindet das Banner direkt von GitHub ein. Zusätzlich kannst du
   [`assets/banner.png`](../assets/banner.png) unter *Images* hochladen.
4. **Screenshots** unter *Images* hochladen. Empfohlen: ein Kampf mit sichtbaren Alarmen, das
   Optionsfenster mit der Bildauswahl und die Totem-Leiste. Die musst du im Spiel machen
   (Druck-Taste, landen in `Screenshots/`).

## 2. Automatische Uploads einrichten (optional, empfohlen)

1. Die **Project ID** steht rechts auf der CurseForge-Projektseite. Trag sie in
   `ShamanAlerts.toc` ein:
   ```
   ## X-Curse-Project-ID: 123456
   ```
2. Auf <https://authors.curseforge.com/account/api-tokens> einen **API-Token** erstellen (der
   von StartAttackMacros geht auch).
3. Auf GitHub: Repo → *Settings* → *Secrets and variables* → *Actions* → **New secret**
   Name: `CF_API_KEY`, Wert: der Token.
4. Neue Version veröffentlichen:
   ```bash
   git tag v2.41.0
   git push --tags
   ```
   GitHub baut dann das Zip und lädt es auf CurseForge und unter GitHub *Releases* hoch.

> **Hinweis WoW Forever:** Der Packager leitet die Spielversion aus `## Interface:` ab. Falls
> CurseForge die Forever-Version (16001) noch nicht kennt, schlägt der Upload dorthin fehl. Dann
> lade das Zip aus GitHub *Releases* von Hand auf CurseForge hoch und wähl die Version dort aus.

## Neue Version

1. Änderungen oben in `CHANGELOG.md` eintragen (Englisch), die Version in `ShamanAlerts.toc`
   anheben.
2. Committen, dann `git tag vX.Y.Z` und `git push --tags`.

## Sprachen

Die Texte im Code sind Englisch und dienen zugleich als Schlüssel. Jede Sprache hat eine Datei in
`Locales/`. Fehlt dort ein Eintrag, erscheint der englische Text. Ein neuer Text braucht also
nur `L["English text"]` im Code und je eine Zeile in den Sprachdateien.
