# Addons, Schnittstellen und Quellen

ForeverAI läuft mit den Grundfunktionen und den mitgelieferten kleinen lokalen Datenbeständen allein. Die folgenden externen Addons sind separat zu installieren; sie werden nicht von diesem Repository mitverteilt.

## QuestieDB

- Projekt: https://github.com/Questie/QuestieDB
- Öffentliche Schnittstelle: https://github.com/Questie/QuestieDB/blob/master/docs/api.md
- Getestete lokale Installation: Version 1.0.13, Forever-Variante, Interface 16001.
- Nutzung: lokalisierte Quest-, NPC-, Objekt- und Gegenstandsnamen, Questziele und Questgeber/-abgaben, NPC- und Objekt-Spawnpunkte, Gegenstandsbeziehungen und Gebietskartenzuordnungen.
- Ohne QuestieDB funktionieren die vorhandenen Client-Daten und kuratierten Daten weiter. Nicht jede Datenbankposition ist aktuell, eindeutig oder auf einer direkt verwendbaren Karte verfügbar. Einige Gebietsnamen liefern keine Koordinaten.
- Die Indizierung erfolgt schrittweise nach dem Einloggen; bis zum Abschluss können Treffer fehlen.

## Questie

- Projekt: https://github.com/Questie/Questie
- Optional: erweitert die Questverwaltung und stellt Queständerungsbenachrichtigungen über `Questie.API` bereit. ForeverAI prüft den Abschlussstatus weiterhin über das Questlog des Clients.
- Questie ist nicht mit QuestieDB gleichzusetzen. Die jeweiligen Abhängigkeiten und Installationshinweise der gewählten Forever-Version beachten.

## Shortest Path Forever

- Projekt und Version: https://github.com/cjber/shortest-path-forever/tree/v1.25.2
- API: https://github.com/cjber/shortest-path-forever/blob/v1.25.2/docs/api.md
- Getestete Integration: v1.25.2. Übergabe und Status über die öffentliche API, Eigentümerkennung `ForeverAI`.
- Das Addon plant verfügbare Fuß- und Reiseabschnitte. Eine berechnete Strecke ist keine Garantie für eine sichere oder vollständige Innenraumroute. Bei fehlender oder fehlgeschlagener Berechnung zeigt ForeverAI nur die Luftlinie.
- Andere Addons werden nicht mitgeliefert. Deren Upstream-Lizenzen gelten unabhängig von der Lizenz für ForeverAI.

## Weitere Datenquellen

- Der WoW-Client liefert unter anderem aktuelles Questlog, Charakterinformationen und öffentlich zugängliche Karteninformationen.
- [Forever Companion](https://forevercompanion.io/developers) kann durch die Begleit-App einen begrenzten öffentlichen Datenbestand synchronisieren. Stand und Umfang stehen im Spiel; das Addon aktualisiert Daten nicht unmittelbar per Netzwerk.
- Kuratierte Standorte und weitere Nachweise: [LOCATION_SOURCES.md](../LOCATION_SOURCES.md), [KNOWLEDGE_SOURCES.md](../KNOWLEDGE_SOURCES.md), [LOOT_SOURCES.md).
- Die optionale Online-KI erhält nur die durch die Einstellungen freigegebenen Kontextdaten. KI-Angaben sind nicht automatisch überprüft und kein Ersatz für fehlende Spieldaten.
