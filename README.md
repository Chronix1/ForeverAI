# ForeverAI

ForeverAI ist ein experimenteller deutsch- und englischsprachiger Spielassistent für **World of Warcraft: Forever** (Interface 16001). Das Addon verbindet lokale Spiel- und Addondaten mit einer optionalen Windows-Begleit-App für Online-KI. Fragen, Ergebnisse und Navigation werden im Spiel bedient.

> **Alpha:** Daten und Wegführung sind nicht vollständig. Community-Standorte und KI-Vorschläge können falsch sein. Der Charakter wird nicht automatisch bewegt. Die Ingame-Prüfung aller Routen steht noch aus.

## Funktionen

- Lokale Suche nach Quests, NPCs, Gegenständen und bekannten Kartenorten; QuestieDB wird schrittweise indiziert.
- Navigation zu eindeutigen Zielen, aktiven Quests und hinterlegten Dungeon-Zugängen. Nach Questabschluss kann die Führung zum bekannten Abgabeort wechseln.
- Wegberechnung über Shortest Path Forever, inklusive unterstützter Verkehrsmittel. Ohne berechnete Route zeigt ForeverAI eine ausdrücklich gekennzeichnete Luftlinie.
- Optionale Online-KI, wenn lokal keine passende Antwort vorliegt. KI-Koordinaten sind ungeprüfte Vorschläge und starten nur nach einem Klick eine Führung.
- Ein Fenster für Chat, Navigation und Einstellungen. Deutsch und Englisch werden unterstützt.

## Addons und Dienste

| Komponente | Status | Verwendung |
| --- | --- | --- |
| [QuestieDB](https://github.com/Questie/QuestieDB) | Optional; für umfangreiche lokale Spieldaten empfohlen | Quests, NPCs, Objekte, Gegenstände und deren Beziehungen. Getestete Installation: Forever-Version 1.0.13. |
| [Questie](https://github.com/Questie/Questie) | Optional | Quest-Hilfe; ForeverAI nutzt die öffentliche Benachrichtigung über Queständerungen, sofern vorhanden. Das Questlog funktioniert auch ohne Questie. |
| [Shortest Path Forever](https://github.com/cjber/shortest-path-forever) | Optional; für berechnete Wege empfohlen | Berechnet Reiseabschnitte und steuert den Pfeil. Getestete Integration: v1.25.2. Ohne das Addon nur Zielrichtung/Luftlinie. |
| ForeverAI-Begleit-App | Optional für lokale Funktionen; erforderlich für Live-KI | Windows-Dienst für Anbieteranmeldung und die experimentelle Brücke ins Spiel. |
| [Node.js](https://nodejs.org/en/download) | Für die Begleit-App erforderlich | Version 22.16 oder neuer. |
| [OpenRouter](https://openrouter.ai/) oder anderer unterstützter Anbieter | Optional | Online-KI. Gratis-Modus und Anbieterlimits beachten. |

Die externen Addons sind **nicht** in diesem Repository enthalten. Installiere ihre für WoW Forever geeigneten Versionen separat und beachte ihre jeweiligen Lizenzen. Mehr Details: [Abhängigkeiten und Datenquellen](docs/ABHAENGIGKEITEN.md).

## Installation unter Windows

1. WoW vollständig schließen. Das Repository herunterladen und nach `<WoW-Verzeichnis>\_forever_\_Extra-App\ForeverAI\` entpacken oder klonen.
2. `Addon\ForeverAI` nach `<WoW-Verzeichnis>\_forever_\Interface\AddOns\ForeverAI` kopieren. QuestieDB, Questie und Shortest Path Forever bei Bedarf separat unter `Interface\AddOns` installieren.
3. Für Live-KI [Node.js](https://nodejs.org/en/download) installieren und bei weiterhin geschlossenem WoW `START-WINDOWS.cmd` starten. Das Fenster geöffnet lassen. Die App richtet die Antwortmodule beim ersten Start ein.
4. Auf der lokalen Anmeldeseite den Anbieter verbinden. Für OpenRouter den Gratis-Modus eingeschaltet lassen und beim Anbieter für den verwendeten Schlüssel ein Ausgabenlimit von **0 USD** setzen und prüfen. Kostenlose Modelle und deren Limits können sich ändern.
5. WoW vollständig neu starten, die installierten Addons aktivieren und `/fai` eingeben. Für Live-KI im Addon unter **Einstellungen** die Verbindung aktivieren; das Modell kann im Spiel gewählt werden.

Bei späteren Addon-Änderungen ist üblicherweise `/reload` nötig. Bei der ersten Einrichtung der Antwortmodule muss WoW vollständig neu gestartet werden. Details und Fehlerbehebung stehen in [INSTALLATION.md](docs/INSTALLATION.md).

## Datenschutz und Technik

Die Begleit-App läuft lokal. Die experimentelle Live-Brücke liest einen kleinen Pixelstreifen im WoW-Fenster und übermittelt Antworten über vorher eingerichtete Daten-Addons; sie greift nicht auf den Spielprozess-Speicher zu und steuert keine Spielfigur. Windows-Fenster- oder randloser Modus wird benötigt. Der Streifen kann zeitweise sichtbar sein.

Zugangsdaten werden unter Windows mit DPAPI im Benutzerkonto geschützt und gehören weder ins Addon noch in dieses Repository. Bei eingeschalteter Kontextfreigabe können relevante Charakter- und Spieldaten an den gewählten KI-Anbieter übertragen werden; sie lässt sich im Addon abschalten. Die Online-KI durchsucht nicht eigenständig das Web. Ein kostenloser Modellname garantiert keine unbegrenzte Verfügbarkeit.

## Entwicklung und Tests

```powershell
cd Begleit-App
npm test
```

Die Addon-Prüfungen liegen in `Addon/ForeverAI/Tests/test_foreverai.lua` und verwenden simulierte WoW-APIs. Die automatisierten Tests ersetzen keine Prüfung im Spiel. Informationen zu Quellen: [Orte](LOCATION_SOURCES.md), [Spielwissen](KNOWLEDGE_SOURCES.md), [Beute](LOOT_SOURCES.md).

ForeverAI ist ein unabhängiges Community-Projekt und steht in keiner Verbindung zu Blizzard Entertainment oder den genannten Addon- und KI-Anbietern. Lizenz für den ForeverAI-Code: [MIT](LICENSE.txt); Hinweise zu Dritten: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
