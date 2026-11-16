# ShamanAlerts – Änderungen im Einzelnen (Deutsch, bis 2.40.0)

## 2.40.0
- Neue Standardwerte aus der laufenden Einrichtung: Größe 120 für die meisten
  Alarme, die Schocks zehn Punkte höher, Runenpfeile für Flammen- und
  Erdschock, Feuernova ab 4 Gegnern und ohne Feuertotem-Bedingung,
  „Unterbrechen" und „Berserker bereit" ausgeschaltet, „Zorn des
  Scharfsehers" in der Abklingzeit-Reihe der Totem-Leiste.
- „Unterbrechen" teilt Lage und Größe nicht mehr mit den Schocks und steht
  wieder an seinem Platz über dem Charakter. Die drei Schocks (Flammenschock,
  Frostschock, Erdschock) teilen sich ihre Stelle weiter.
- Neuer Knopf an der Minimap: Linksklick öffnet die Optionen, Rechtsklick die
  Seite der Totem-Leiste. Ein- und ausschalten mit `/sha minimap` oder auf
  der Seite „Hilfe & Diagnose". Bringt ein anderes Addon LibDBIcon mit,
  meldet sich der Knopf dort an und landet auch in Sammlern für
  Minimap-Knöpfe.
- Der Eintrag unter Optionen > AddOns zeigt jetzt Symbol und Version und führt
  direkt zu Alarmen, Totem-Leiste, Profilen und Hilfe.
- Neue Seite „Profile & Austausch": Einstellungen als Profil speichern, laden
  und löschen; Einstellungen als kurzen Text exportieren und importieren.
  Befehle: `/sha profile`, `/sha profile save|load|delete <Name>`,
  `/sha profile list`, `/sha export`. Beim Import wird nichts ausgeführt,
  übernommen wird nur, was das Addon kennt.
- Das Addon hat ein eigenes Symbol (Addon-Liste, Minimap, Einstellungen).

## 2.39.0
- Die vier Schock-Alarme stehen an derselben Stelle, es wechselt nur das Bild:
  „Flammenschock fehlt", „Frostschock fehlt" und „Unterbrechen" teilen Lage
  und Größe mit „Erdschock bereit". Wer einen davon verschiebt oder in der
  Größe ändert, ändert alle vier. Eigene Werte für Lage und Größe der drei
  werden dabei durch die von „Erdschock bereit" ersetzt; Bild, Drehung und
  Spiegelung bleiben je Alarm.
- Im Reiter „Anordnung" steht dafür das Häkchen „Gleiche Stelle wie
  „Erdschock bereit"". Ohne Häkchen steht der Alarm wieder für sich
  (`/sha set frostshock placelike none`).
- Neue Bedingung „Nicht gegen Spieler (PvP)" für alle „fehlt"-Alarme auf dem
  Ziel. Bei „Flammenschock fehlt" ist sie eingeschaltet: Gegen Spieler
  erscheint er nicht mehr (`/sha set flameshock noplayer off` schaltet das ab).
  Im PvP gilt damit: Unterbrechen, dann Frostschock fehlt, dann der
  allgemeine Schock.

## 2.38.0
- Neuer Alarm „Frostschock fehlt": erscheint im Kampf gegen Spieler, solange
  deine Verlangsamung auf dem Ziel fehlt. Neue Bedingung „Nur gegen Spieler
  (PvP)" für alle „fehlt"-Alarme auf dem Ziel.
- Rangfolge der Schocks, damit immer nur der wichtigste erscheint:
  1. Unterbrechen (das Ziel zaubert etwas Unterbrechbares)
  2. Frostschock fehlt (nur gegen Spieler)
  3. Flammenschock fehlt
  4. der allgemeine Schock („Erdschock bereit" mit dem Bild für alle drei)
  Ob der Frostschock auf dem Ziel liegt, entscheidet dabei die eigene Uhr des
  Addons. Ändern lässt sich die Rangfolge je Alarm mit
  `/sha set flameshock behind interrupt,frostshock` (oder `none`).
- Drei neue Bilder im WoW-Stil: „Erdschock: Runenblitz", „Frostschock:
  Runenpfeil" und „Frostschock: Runenblitz".

## 2.37.0
- Zwei neue Bilder im WoW-Stil: „Flammenschock: Runenblitz" (der Blitz der
  dreifachen Schock-Bilder, ganz in Feuer) und „Erdschock: Runenpfeil" (der
  Runenpfeil des Flammenschocks in Fels und grünen Blitzen).

## 2.36.0
- Drei neue Flammenschock-Bilder im Runen-Stil: Runenpfeil, Runensiegel,
  Runenstein. Sie stehen in der Liste unter „WoW-Stil".

## 2.35.1
- Erdschock bereit: Der Elementpfeil ist das neue Standardbild und ersetzt
  den Einschlag, wenn er nicht selbst geändert wurde.

## 2.35.0
- Drei neue Bilder im WoW-Stil, die für alle drei Schocks zugleich stehen
  (Feuer, Erde und Frost in einem Bild): Elementpfeil, Einschlag, Blitz. Sie
  stehen in der Liste unter „Schock (alle drei)" und lassen sich bei jedem
  Alarm wählen.

## 2.34.0
- Früh auffrischen arbeitet jetzt mit einer eigenen Uhr: Sie startet, sobald
  du den Flammenschock wirkst, und der Alarm erscheint, wenn nach ihr noch
  2 Sekunden bleiben. Der Weg über das Restzeit-Textfeld des Spiels aus 2.33
  ist wieder ausgebaut, weil er im Spiel nicht funktioniert hat.
- Die Uhr gilt für das Ziel, auf das der Zauber ging. Verfehlt der
  Flammenschock oder läuft er vorher ab, zeigt wie bisher der gewöhnliche
  Alarm, dass er fehlt.
- Neue Einstellung „Laufzeit der Aura" (Flammenschock: 12 Sekunden,
  `/sha set flameshock duration 12`). Außerhalb des Kampfes lernt das Addon
  den Wert selbst, sobald es den Debuff sieht.
- `/sha status` und `/sha debug` zeigen den Stand der Uhr.

## 2.33.1
- Fehler behoben: „calling 'SetShown' on bad self (Attempt to access forbidden
  object ...)" in jedem Takt, sobald „Flammenschock fehlt" mit dem frühen
  Auffrischen aufgebaut war. Das Spiel sperrt die Grafik-Kopie, sobald sie am
  Restzeit-Textfeld hängt. Das Addon schaltet jetzt nur noch einen eigenen
  Rahmen darüber. Durch den Fehler blieben auch alle Alarme stehen, die in der
  Liste nach dem Flammenschock kommen.
- Ein Fehler bei einem Alarm hält die übrigen nicht mehr an. Er wird einmal im
  Chat gemeldet und steht danach in `/sha status` und `/sha debug`.

## 2.33.0
- Flammenschock fehlt: Der Alarm erscheint schon, wenn der Flammenschock nur
  noch 2 Sekunden auf dem Ziel läuft. So lässt er sich erneuern, bevor er
  abläuft. Die übrigen Bedingungen (Kampf, Mana, Abklingzeit der Schocks,
  Leben des Ziels) gelten dabei weiter.
- „Erdschock bereit" steht in diesen 2 Sekunden hinter dem Flammenschock
  zurück.
- Neuer Regler „Früh auffrischen" für alle „fehlt"-Alarme, 0 bis 5 Sekunden
  (`/sha set flameshock refresh 3`, 0 schaltet es aus).
- `/sha status` und `/sha debug` melden, ob das Spiel das frühe Auffrischen
  zulässt.

## 2.32.0
- Das Optionsfenster ist neu aufgebaut. Links steht die Liste aller Alarme mit
  einem Punkt für den Zustand (grün: an, gelb: an, aber der Zauber ist nicht
  gelernt, grau: aus). Rechts stehen Name, Art, eine kurze Beschreibung und der
  Schalter „Aktiv", darunter fünf Reiter: Grafik, Anordnung, Bedingungen,
  Sound, Zauber & Aura.
- Totem-Leiste und Schrift sind eine Seite im selben Fenster statt eines
  zweiten Fensters. Neu ist die Seite „Hilfe & Diagnose" mit den Befehlen, dem
  Knopf für die Diagnose und „Alles zurücksetzen".
- Neu im Fenster einstellbar: „Nur wenn das Ziel zaubert", Zahl und Umkreis
  der Gegnerzählung sowie die Position als X- und Y-Wert.
- Bedienelemente erklären sich, wenn die Maus darüber steht.
- Löschen und Zurücksetzen fragen vorher nach.

## 2.31.0
- Neuer Alarm „Unterbrechen": erscheint dicht über dem Charakter, sobald das
  Ziel etwas Unterbrechbares zaubert oder kanalisiert und der Erdschock bereit,
  bezahlbar und in Reichweite ist. Drei Bilder: Steinfaust, Zersprungene Rune,
  Halt.
- Die Bedingung „nur wenn das Ziel zaubert" gibt es für jeden „Zauber
  bereit"-Alarm (`/sha set earthshock needcasting on`).
- `/sha debug` zeichnet zusätzlich auf, was das Spiel über den Zauber des Ziels
  verrät.

## 2.30.0
- Neue Standardwerte für alle Alarme, die Totem-Leiste und die Schrift.
- Feuernova bereit: groß über dem Charakter, mit dem Totem-Bild, nur in
  Reichweite, nur mit Feuertotem und nur bei 3+ Gegnern näher als 10 m.
- Schild fehlt: nur noch im Kampf, weiter oben.
- Freizaubern aktiv: Kristall statt Manakugel.
- Totem-Leiste: neue Position, Abklingzeiten über der Leiste, Steinklaue ist
  aus der Liste genommen.
- Schrift: Umriss statt „wie Aktionsleisten".

## 2.29.1
- Flammenschock fehlt: Die Feuerspitze ist das neue Standardbild und ersetzt
  den Feuerball, wenn er nicht selbst geändert wurde.

## 2.29.0
- Sechs neue Flammenschock-Bilder im WoW-Stil: Glutbrocken, Lavafaust,
  Feuerspitze, Flammenschädel, Feuervogel, Schockrune.
- `/sha debug` zeichnet zusätzlich auf, was das Spiel über die gegnerischen
  Namensplaketten und ihre Entfernung verrät.

## 2.28.0
- „Zauber bereit"-Alarme: neues Häkchen „Nur mit Feuertotem".
- Das Optionsfenster ist etwas höher.

## 2.27.1
- Gegnerzählung: Umkreis 10 m statt 20 m, umstellbar auf 5, 10 oder 20 m
  (`/sha set firenova enemyrange 5`). Gemessen wird über die Reichweite von
  Gegenständen, ersatzweise über Sturmschlag oder einen Schock.

## 2.27.0
- „Zauber bereit"-Alarme: neues Häkchen „Nur bei 3+ Gegnern in der Nähe".
  Gezählt werden die Namensplaketten angreifbarer Gegner im Kampf. Die Zahl
  lässt sich ändern (`/sha set firenova minenemies 4`).

## 2.26.0
- Neuer Alarm „Feuernova bereit" mit drei Bildern (Feuerring, Totem,
  Feuerstern). Er bleibt aus, solange das Spiel den Zauber als nicht wirkbar
  meldet.
- Totem-Leiste: Reihe kleiner Symbole für die Abklingzeiten wichtiger Totems
  (Erdung, Erdbindung, Manaflut ...). Hell heißt bereit, grau mit Zahl heißt
  Abklingzeit. Lage, Größe und die Liste der Zauber sind einstellbar.

## 2.25.1
- Standardwerte nachgezogen: Mahlstrom Größe 116, Flammenschock Größe 96,
  Erdschock ohne Drehung.

## 2.25.0
- Die Bilder im WoW-Stil sind Standard für alle Alarme.
- Größen und Positionen aller Alarme neu voreingestellt.
- „Schlaghagel aktiv" ist standardmäßig ausgeschaltet.

## 2.24.0
- Neuer Alarm „Berserker bereit" für Trolle, mit sechs gemalten Bildern.
- 30 neue Bilder im Stil der Fähigkeitssymbole, drei pro Alarm, als eigene
  Kategorie „WoW-Stil".
- Alle übrigen Grafiken (Power Auras, Formen, berechnete Blitze und Flammen,
  Blizzard-Texturen) sind entfernt. Wer eine davon gewählt hatte, bekommt das
  Standardbild; eigene Dateipfade bleiben erhalten.
