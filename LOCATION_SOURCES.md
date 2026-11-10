# ForeverAI 0.7 – Quellen und Abweichungen bei Wegpunkten

Stand: 10.11.2026, WoW Forever 1.60.1 / Build 70862, Interface 16001.

Die eingebauten Punkte sind eine **unvollständige Auswahl** aus öffentlich
verfügbaren Forever-Karten. Die Dateien werden **nicht automatisch über das
Internet aktualisiert**. Es handelt sich bei allen Community-Pins lediglich
um die ungefähre Außenannäherung, **nicht** um einen begehbaren Pfad, das
Portal im Inneren oder einen sicheren Weg. Bei voneinander abweichenden
Quellen wird ein außenliegender Orientierungspunkt ausdrücklich bevorzugt.

| Ziel / Zone | In ForeverAI hinterlegte X/Y | Beleg / Kommentar |
| --- | --- | --- |
| Goldhain / Wald von Elwynn | 42.4 / 66.6 | [WoW Forever DB: Elwynn-Karte](https://wowfdb.com/zones/elwynn-forest/map/), ungefährer Ortsmittelpunkt; nicht der Standort eines bestimmten NPCs. |
| Todesminen / Westfall | 38.2 / 77.5 | [Nerdsquare Eingangsbereich](https://forever.nerdsquare.eu/guides/dungeons/dungeoneingange/), Beta Build 70425. [Questing.wiki](https://questing.wiki/wow-forever/dungeons/deadmines/) meldet abweichenden Quest-Anreisepunkt 42.5 / 71.7; nicht als identisch behandelt. |
| Burg Schattenfang / Silberwald | 44.7 / 67.8 | [Azeroth.wiki Forever-Karte](https://azeroth.wiki/forever/map/silverpine-forest/shadowfang-keep), mit leicht abweichendem [Nerdsquare-Pin](https://forever.nerdsquare.eu/guides/dungeons/dungeoneingange/) 44.5 / 68.0. |
| Höhlen des Wehklagens / Brachland | 46.0 / 36.5 | [Questing.wiki](https://questing.wiki/wow-forever/dungeons/wailing-caverns/) – Quest-Anreisepunkt, nicht Instanzportal; Nerdsquare: 46 / 36.4. |
| Gnomeregan / Dun Morogh | 24.3 / 39.8 | [Questing.wiki](https://questing.wiki/wow-forever/dungeons/gnomeregan/) – Anreisepunkt, nicht Instanzportal. |
| Das Verlies / Sturmwind | 52.41 / 70.01 | [Questing.wiki](https://questing.wiki/wow-forever/dungeons/stockades/) – Anreisepunkt. |
| Flammenschlund / Orgrimmar | 52.8 / 49.6 | [Nerdsquare](https://forever.nerdsquare.eu/guides/dungeons/dungeoneingange/) – ungefähre Eingangsregion. |
| Halle der Thanen / Eisenschmiede | 43.5 / 52.0 | [Nerdsquare](https://forever.nerdsquare.eu/guides/dungeons/dungeoneingange/) – ungefähre Eingangsregion. |

## NPCs, Lehrer und Questziele

- Wenn ein **separat installiertes QuestieDB für WoW Forever** geladen ist,
  fragt ForeverAI dessen [dokumentierte öffentliche Lua-API](https://github.com/Questie/QuestieDB/blob/master/docs/api.md)
  `LibQuestieDB.Npc.GetAllIds`, `.name`, `.subName`, `.spawns` ab. Addon-intern
  verwendete `AreaID` werden **nur für ausdrücklich bekannte Zonen** auf
  `uiMapID` abgebildet. Spawnkoordinaten können veraltet, phasenbedingt oder
  im Inneren eines Gebäudes sein. Die NPC-Abfrage kann abhängig von der
  Datenbankgröße auf älterer Hardware einen kurzen Hänger verursachen.
- Ohne QuestieDB ist keine allgemeine, automatisch nachgeladene NPC-Datenbank
  enthalten. Vorhandene **Questlog-Ziele** können stattdessen über die
  Clientfunktion `C_QuestLog.GetNextWaypoint` markiert werden, sofern sie
  Koordinaten liefert. Alles Weitere erfordert eigene/übertragene Wegpunkte.
- **Keine** ungeprüften Namen oder KI-Texte werden automatisch zu einem Marker
  gemacht. Ein Klick auf einen Treffer zeigt zunächst nur eine Zielvorschau.

## Gegenstände

- Der Client liefert die vom Spieler angelegten Item-Links über
  `GetInventoryItemLink`; Gegenstandsdaten und ausgewählte Attribute stammen
  aus `C_Item.GetItemInfo` / `C_Item.GetItemStats` (beziehungsweise verfügbaren
  Classic-Fallbacks). Bei nicht geladenem Tooltip/Cache können Werte fehlen.
- Taschen werden **nur nach ausdrücklichem `/fai taschen`** aus den sichtbaren
  Containerdaten gelesen; optional nach einer entsprechenden Frage und
  bewusstem `KI-Export`. Es wird nichts automatisch an Internetdienste gesendet.
- Gegenstandskandidaten stammen derzeit aus dem **kleinen, kuratierten
  Loot-Katalog** in `Loot.lua`, nicht aus einer vollständigen Forever-DB.
  Spielseitiger DPS, Verzauberungen, Setboni, Talentänderungen, Waffenfertigkeit
  und tatsächlich erreichbare Quellen können das Ranking ändern. Es werden
  **keine automatischen Best-in-Slot-Behauptungen** gemacht.

Weitere manuell durchsuchbare Datenquellen:
[GearInsight Forever](https://gearinsight.app/wow/en/forever/db),
[Eternadex](https://eternadex.com/de/datenbank/) und
[Icy Veins Forever](https://db.icy-veins.com/wow-forever/).
Ihre Webseiten sind **nicht** als Live-Datenquelle ins WoW-Addon eingebunden.
