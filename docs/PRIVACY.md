# Form — Datenschutzinformationen

Stand: 7. November 2026

Form wird von **FDMwerk** bereitgestellt. Support und Datenschutzanfragen: **support@fdmwerk.de**. Die aktuellen Herausgeberangaben stehen im [Impressum von FDMwerk](https://fdmwerk.de/impressum/). Der dort genannte Anbieter ist Christoph Kielhorn unter der Bezeichnung FDMwerk.

## Verarbeitung von 3D-Dateien

Form liest Dateien, die Sie ausdrücklich über den Öffnen-Dialog, Finder oder per Drag-and-drop auswählen. Modelle werden lokal auf Ihrem Mac verarbeitet. Originaldateien werden nicht verändert. Die App enthält keine Funktion zum Hochladen Ihrer Modelle, kein Benutzerkonto, keine Werbung und keine Analyse- oder Tracking-Dienste.

Geometrie, Messungen und Änderungen an der Anordnung liegen während der Sitzung im Arbeitsspeicher. Sie werden beim Beenden der App verworfen. Das Referenzmodell ist im App-Paket enthalten; in der App findet keine KI-Generierung oder Verbindung zu Tripo statt.

## Bildschirmaufnahmen

Auf Ihren ausdrücklichen Befehl kann Form die Modellansicht als PNG-Bild speichern. Sie wählen den Speicherort über den macOS-Sichern-Dialog. Das Bild bleibt an diesem Ort, bis Sie es selbst entfernen. Es wird nicht an FDMwerk gesendet. Diese Funktion benötigt Schreibzugriff auf die von Ihnen ausgewählte Zieldatei; importierte Modelldateien werden weiterhin nur gelesen.

## Lokale Einstellungen und macOS

Sprache, Steuerungsprofil, Geschwindigkeiten, Zoomrichtung, Trackpad-Modus, Standardfarbe und Darstellungsoptionen werden in den app-eigenen macOS-Einstellungen gespeichert. Diese Werte werden nicht an FDMwerk übermittelt. Die Schaltfläche „Auf Standard zurücksetzen“ stellt die Standardwerte wieder her. Das Entfernen der App allein löscht möglicherweise nicht alle von macOS verwalteten Einstellungen.

macOS kann die Namen und Speicherorte erfolgreich geöffneter Dateien in der systemeigenen Liste zuletzt verwendeter Dokumente speichern. Ihre Verwaltung richtet sich nach macOS. Betriebssystem- oder App-Store-Diagnosen unterliegen Ihren Apple-Einstellungen und den Informationen von Apple. Form verwendet eine nicht persistente WebKit-Datensitzung und betreibt keinen eigenen Netzwerkdienst.

## Öffnen in einer anderen App

„Öffnen mit“ ermittelt erst beim Anklicken lokal registrierte bzw. bekannte installierte Apps für das ausgewählte Dateiformat. Form verwendet deren lokal verfügbare Namen und Programmsymbole. Die Liste wird nicht an FDMwerk gesendet. Bei Ihrer Auswahl übergibt Form die ursprüngliche Datei an diese App; Messungen, Schnitte und Anordnungen aus der Form-Sitzung werden dabei nicht übertragen. Externe Apps können eigene Onlinedienste verwenden. Dafür gelten deren Einstellungen und Datenschutzinformationen.

Für Blender schreibt Form ein festes lokales Importskript in seinen Anwendungsdatenordner und startet eine neue Blender-Instanz. Der ursprüngliche Dateipfad wird als separates Startargument übergeben. Dateiinhalte werden dabei nicht in das Skript eingebettet. Diese Funktion steht für Dateien zur Verfügung, deren Speicherort Form über den nativen Öffnen-Dialog oder Finder erhalten hat; für reine Web-Drag-and-drop-Importe ohne ursprünglichen Dateipfad ist sie deaktiviert.

## Lokale Druckzeitberechnung

Die Anzeige einer geometrischen Druckzeitschätzung verarbeitet nur die lokal geladene Darstellungsgeometrie und Ihre Eingaben. Wenn Bambu Studio installiert ist und Sie dessen separate Berechnung ausdrücklich starten, wird die ausgewählte ursprüngliche STL-Datei in einen temporären lokalen Arbeitsordner kopiert. Form verwendet feste mit Bambu gelieferte Drucker-/Materialprofile, keine privaten Slicer-Voreinstellungen, und einen getrennten temporären Einstellungsordner. Ergebnisdateien und Arbeitskopie werden nach dem Job entfernt. Ein Abbruch oder Zeitlimit beendet den Berechnungsprozess. Form sendet dabei keine Druckaufträge. Es gelten zusätzlich die Bedingungen der gewählten externen Software; deren Nutzung und mögliche eigene Dienste sind von der Modellansicht in Form zu unterscheiden.

## Externe Links und Support

Externe Dokumentations-, Lizenz- oder Support-Seiten werden erst nach einem Klick im Standardbrowser geöffnet. Für die Nutzung von GitHub, Apple oder anderen externen Seiten gelten deren jeweilige Datenschutzinformationen.

Form versendet keine Support-Anfragen automatisch. Wenn Sie FDMwerk per E-Mail kontaktieren, werden die von Ihnen mitgeteilten Angaben zur Bearbeitung Ihrer Anfrage verwendet. Erforderliche Korrespondenz wird nur für diesen Zweck sowie zur Erfüllung einschlägiger Aufbewahrungspflichten gespeichert; danach wird sie gelöscht. Sie können Auskunft, Berichtigung oder Löschung der von Ihnen übermittelten Angaben über support@fdmwerk.de anfragen. Die konkrete Rechtsgrundlage und anwendbare Aufbewahrungsfristen richten sich nach Inhalt und Zusammenhang der Anfrage.

[GitHub-Issues](https://github.com/FDMwerk/Form/issues) sind öffentlich. Stellen Sie dort keine vertraulichen Kundenmodelle, Zugangsdaten oder personenbezogenen Unterlagen ein. Für Support genügt zunächst eine Beschreibung des Problems und des Dateiformats; teilen Sie Dateien nur, wenn Sie dazu berechtigt sind.

## Keine Datenübermittlung durch die Modellansicht

Die lokale Modellansicht übermittelt Ihre Modelle und Nutzung nicht an FDMwerk oder Dritte. Es gibt deshalb keine vom Herausgeber gespeicherte Modell- oder Nutzungshistorie, die Sie bei uns löschen lassen müssten. Die oben beschriebenen freiwilligen Support-Anfragen und externen Dienste sind davon getrennte Vorgänge.
