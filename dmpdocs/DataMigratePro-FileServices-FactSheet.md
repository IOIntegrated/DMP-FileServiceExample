# DataMigratePro File Services (Enduser)

## Zweck

Die File-Services Funktion ermöglicht es, Datei- und Verzeichnisoperationen kontrolliert über DataMigratePro auszuführen.

Typische Einsatzfälle:
- Austausch von XML- oder JSON-Dateien zwischen Prozessen
- Vor- und Nachbereitung von Migrationsdateien
- Überwachung von Dateiaktionen inklusive Status und Fehlern

## Voraussetzungen

- Der DataMigratePro Listener läuft im Service-Bus Modus (`-t listen`).
- File-System Aliases sind in `settings.json` konfiguriert.
- Das Zielsystem hat die nötigen Berechtigungen auf den Alias-Ordnern.
- In Business Central ist die Extension mit den File-System Seiten aktiv.

## Was kann ausgeführt werden

Unterstützte Aktionen:
- `ListFiles`
- `ListDirectories`
- `CreateDirectory`
- `DeleteDirectory`
- `DirectoryExists`
- `ReadFile`
- `WriteFile`
- `AppendFile`
- `DeleteFile`
- `MoveFile`
- `CopyFile`
- `FileExists`
- `GetFileInfo`
- `ArchiveFile`
- `ImportXmlPortSource`
- `ExportXmlPortTarget`

## Bedienung in Business Central

### 1. Requests beobachten

- Öffne die Seite **DMP FS Request List IOI**.
- Relevante Felder:
  - `Transaction Id`
  - `Command`
  - `Status`
  - `Path Alias`
  - `Relative Path`
  - `Payload Length`
  - `Payload Truncated`

Status in Requests:
- `Created`: Request wurde angelegt.
- `Sent`: Request wurde an den Listener übergeben.
- `Completed`: Aktion erfolgreich abgeschlossen.
- `Failed`: Aktion mit Fehler beendet.

### 2. Ergebnisse prüfen

- Öffne die Seite **DMP FS Result List IOI**.
- Relevante Felder:
  - `Status`
  - `Error Code`
  - `Message`
  - `Result Length`
  - `Result Truncated`

Status in Results:
- `Accepted`: Request wurde akzeptiert.
- `Running`: Verarbeitung läuft oder Zwischenstatus.
- `Completed`: Ergebnis erfolgreich.
- `Failed`: Fehler bei Verarbeitung.

### 3. Fehlerhafte Requests erneut starten

- Markiere einen oder mehrere fehlerhafte Einträge in **DMP FS Request List IOI**.
- Führe die Aktion **Retry Selected Failed Requests** aus.
- Nicht-fehlerhafte Einträge werden automatisch übersprungen.

### 4. Request aus Result öffnen

- In **DMP FS Result List IOI**: Aktion **Open Request** verwenden, um direkt zum zugehörigen Request zu springen.

## Enduser-Beispiel (XML Export)

Ziel: XML-Datei in einen Zielordner schreiben.

1. Die Business-Logik startet `ExportXmlPortTarget`.
2. Request geht mit `Path Alias` + `Relative Path` an den Listener.
3. Listener schreibt die Datei in den Alias-Ordner.
4. Rückmeldung erscheint in der Result-Liste mit `Completed` oder `Failed`.
5. Bei `Failed`: Request markieren und mit Retry erneut senden.

## Häufige Fehler und Bedeutung

- `PATH_NOT_FOUND`: Alias oder Pfad existiert nicht.
- `FILE_NOT_FOUND`: Datei wurde nicht gefunden.
- `ACCESS_DENIED`: Zugriff nicht erlaubt (Berechtigung oder Policy).
- `INVALID_OPERATION`: Ungültiger Zustand, z. B. nicht konfigurierter Alias.
- `IO_ERROR`: Technischer Datei-I/O Fehler.
- `PROCESSING_ERROR`: Allgemeiner Verarbeitungsfehler.

## Best Practices für Enduser

- Nur freigegebene Alias-Pfade verwenden.
- Bei großen Inhalten auf `Payload Truncated`/`Result Truncated` achten.
- Vor Retry zuerst `Message` und `Error Code` prüfen.
- In produktiven Szenarien Dateioperationen mit klaren Namenskonventionen ausführen (z. B. Zeitstempel im Dateinamen).
