# Installation und Fehlerbehebung

## Grundinstallation

1. WoW Forever schließen und das Repository vollständig nach `<WoW-Verzeichnis>\_forever_\_Extra-App\ForeverAI\` herunterladen. Dieser Ort wird vom Windows-Starter zur Erkennung der Spielinstallation verwendet.
2. Den Ordner `Addon\ForeverAI` nach `<WoW-Verzeichnis>\_forever_\Interface\AddOns\ForeverAI` kopieren.
3. Gewünschte externe Addons separat installieren: [QuestieDB](https://github.com/Questie/QuestieDB), optional [Questie](https://github.com/Questie/Questie), sowie [Shortest Path Forever](https://github.com/cjber/shortest-path-forever) für berechnete Routen. Auf Forever-Kompatibilität achten. Bestehende Addon-Ordner bei Updates vorher sichern; `WTF` mit persönlichen Spielständen nicht löschen.
4. WoW starten, benötigte Addons aktivieren und `/fai` eingeben. Ohne Begleit-App ist die lokale Suche verfügbar.

## Optionale Online-KI

1. Windows 10/11 und [Node.js 22.16 oder neuer](https://nodejs.org/en/download) verwenden. WoW und eine eventuell ältere ForeverAI-Begleit-App vollständig schließen.
2. Im heruntergeladenen Projekt `START-WINDOWS.cmd` ausführen und das Fenster geöffnet lassen. Die Begleit-App richtet beim ersten Start Datenmodule im Addon-Verzeichnis ein.
3. Auf der lokalen Anmeldeseite OpenRouter auswählen, den Gratis-Modus aktiviert lassen und die Verbindung autorisieren. Ein Ausgabenlimit von 0 USD beim Anbieter festlegen und prüfen. Rate-Limits und die Verfügbarkeit kostenloser Modelle bleiben möglich.
4. WoW **vollständig neu starten**, nicht nur `/reload`. Fenstermodus oder randlosen Modus verwenden. In ForeverAI unter **Einstellungen** die Live-KI einschalten und gegebenenfalls ein Modell laden.

## Bedienung

- Eine Frage in den Chat schreiben. Bei einer eindeutigen Ortsfrage kann die Wegführung automatisch starten; mehrdeutige Ergebnisse erfordern eine Auswahl.
- Unter **Navigation** sind aktive Quests sowie hinterlegte Dungeon-Zugänge für das aktuelle Level auswählbar. Die Auswahl startet eine verfügbare Führung.
- Nach Abschluss einer geführten Quest wird bei eindeutigem QuestieDB-Abgabeort die Abgabeführung gestartet. Im Kampf wartet die Umschaltung; Stopp beendet auch die Überwachung.
- Durch Klick auf einen als ungeprüft markierten KI-Koordinatenvorschlag startet die Führung. Die Existenz der Karten-ID beweist nicht die Richtigkeit des Vorschlags.

## Fehlerbehebung

- **Keine KI-Antwort:** Begleit-App laufen lassen, Anbieteranmeldung und Live-KI prüfen; nach der Einrichtung der Antwortmodule WoW vollständig neu starten.
- **Antwort-Slots erschöpft:** `/reload` ausführen. Die Brücke hat pro UI-Sitzung eine begrenzte Anzahl von Antwort-Slots.
- **Nur Luftlinie:** Shortest Path Forever muss installiert und aktiviert sein; auch damit kann eine Route nicht immer berechnet werden.
- **Kein Quest-/NPC-Standort:** Die Indizierung abwarten und prüfen, ob QuestieDB für Forever geladen ist. Manche Positionen sind nicht enthalten oder nicht eindeutig einer Karte zugeordnet.
- **Nicht alle Gegenstände oder Orte gefunden:** Umfang und Qualität richten sich nach den vorhandenen Addondaten. Die KI hat keinen direkten Internet-Browser und kann keine aktuellen Quellen selbstständig nachschlagen.
