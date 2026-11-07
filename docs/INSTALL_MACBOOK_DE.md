> Verteilung: Auf GitHub werden keine Preview- oder App-Store-Installationspakete angeboten. Die folgenden Hinweise beziehen sich ausschließlich auf lokal bereitgestellte Testpakete bzw. selbst erstellte Builds. Der vorbereitete Mac-App-Store-Eintrag ist https://apps.apple.com/app/id6831972349; bis zur Freigabe besteht darüber noch keine zugesagte Downloadmöglichkeit.

# Form auf einem MacBook testen

Diese Anleitung beschreibt ausschließlich lokale Testbuilds bzw. selbst erstellte Builds. Sie sind kein produktiv freigegebener oder im App Store veröffentlichter Build. Die DMG-Datei ist nicht signiert; das Paket ist nicht von Apple notarisiert. Eine vorhandene lokale Codesignatur ersetzt diese Prüfung nicht. macOS kann den Start deshalb blockieren.

## Voraussetzungen

- macOS 14 oder neuer.
- Ein Mac mit Apple Silicon oder Intel-Prozessor. Das Universal-Paket enthält beide Architekturen.
- Für den Viewer selbst ist kein Konto erforderlich. Dateien werden lokal verarbeitet.
- Externe CAD-Programme und Slicer sind optional. Ihre Installation und Eignung für das jeweilige Dateiformat sind unabhängig von Form.

## Installieren

1. Verwende ausschließlich ein lokal für diesen Test bereitgestelltes Paket oder einen selbst erstellten Build. Auf GitHub gibt es keinen autorisierten Download eines Form-Installationspakets. Prüfe den lokalen Dateinamen, die Version und die Herkunft; diese Anleitung veröffentlicht oder verteilt kein Paket.
2. Bei einer DMG: Öffne das Abbild und ziehe **Form.app** auf den darin enthaltenen **Applications**-Verweis. Bei einer ZIP: Entpacke sie und kopiere **Form.app** aus dem entpackten Ordner nach **Programme**. Eine ältere Form-Version vorher beenden.
3. Starte Form aus **Programme**, nicht aus dem eingebundenen Abbild. Das Abbild kannst du nach dem Kopieren auswerfen.
4. Falls macOS den Start blockiert: Verwende nur den von macOS angebotenen Weg für diese einzelne App, etwa **Rechtsklick → Öffnen** oder **Systemeinstellungen → Datenschutz & Sicherheit → Dennoch öffnen**, sofern dieser angeboten wird. Bestätige nur, wenn Quelle und Datei vertrauenswürdig sind.
5. Falls kein solcher Weg angeboten wird oder macOS die App als beschädigt meldet: Stoppe den Versuch und melde Version, macOS-Version und den genauen Wortlaut. Sicherheitsfunktionen müssen für den Test nicht systemweit ausgeschaltet werden.

Die Vorschau enthält keine Anweisung zum Entfernen von Quarantänekennzeichnungen oder zum Abschalten von Gatekeeper.

## Prüfsummen

`SHA256SUMS.txt` nennt ausschließlich die beiden Vorschau-Archive und die zugehörige deutsche Testanleitung. Eine passende SHA-256-Prüfsumme zeigt, dass die heruntergeladene Datei dem ausdrücklich lokal bereitgestellten Paket entspricht; sie ersetzt weder eine vertrauenswürdige Quelle noch eine Apple-Notarisierung. Ein reines Quellpaket gehört nicht zu diesem lokalen Installations-Prüfsummenmanifest.

## Sinnvoller Kurztest

Öffne zuerst ein unkritisches eigenes Testmodell. Prüfe Drehen, Zoomen, Seitenleiste, Ein-/Ausblenden und Dateiinformationen. Lade danach eine zweite Datei und teste Auswahl, Ansichten und Rückgängig. Bei Volumen und Druckzeiten die angezeigten Einschränkungen beachten: Eine geometrische Schätzung ist kein verbindliches Slicer- oder Druckergebnis.

Szenenänderungen und dateispezifische Darstellungsüberschreibungen gelten für die laufende Sitzung. Die Ursprungsdatei wird dadurch nicht überschrieben. Vorschauen mit unbekannten Dateiformaten oder sehr großen Modellen können Fehler enthalten. Für den ersten Test keine vertraulichen Kundendaten verwenden.

Bitte Rückmeldungen mit Form-Version und Build aus `BUILD_INFO.txt`, Mac-Prozessor, macOS-Version, Dateiformat, reproduzierbaren Schritten und Fehlermeldung senden. Screenshots sollten keine privaten Dateinamen oder Kundendaten zeigen. Kontakt: support@fdmwerk.de.

## Paket für die interne Vorschau erzeugen

Nach abgeschlossenem Build und UI-Test führt die Veröffentlichungsperson `scripts/package-preview.sh` aus. Das Skript baut oder signiert nichts neu und veröffentlicht nichts. Es prüft Version, Bundle-Kennung, Codesignatur und beide Prozessorarchitekturen, kopiert ausschließlich die fertige App in eine saubere temporäre Ablage und erzeugt ZIP, unsignierte DMG und ein explizites Prüfsummenmanifest. Die Version stammt aus `package.json`; bei vorhandenen Ausgabedateien stoppt es.

Die vollständige Quellfreigabe wird separat nach dem endgültigen Commit mit dem bestehenden `npm run package:source` vorbereitet. App-Store-Signierung, Notarisierung und eine produktive Freigabe sind eigene Schritte.
