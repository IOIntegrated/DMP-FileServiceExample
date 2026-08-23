# Plan: FileService – „OK" erst nach BC-Commit senden + Polling im Example entfernen

Status: abgestimmt, umsetzungsreif. Erstellt 2026-08-22.

## Ziel

1. **Client (C#, `DataMigratePro-PC`)**: Für `filesystem`-Nachrichten die Service-Bus-Reply
   („OK"/Accepted) erst senden, **nachdem** das Ergebnis erfolgreich an BC committet wurde.
   Den Queue-Eintrag erst dann als „erfolgreich gelesen" markieren (`Complete`); schlägt der
   BC-Commit fehl → `Abandon` (Redelivery, kein „gelesen").
2. **Example (AL, `DMP-FileServiceExample`)**: Die Polling-Schleife
   (`WaitForResult`, `Sleep(500)` bis Ergebnis da ist) entfernen. Da `Submit*` nach der
   Client-Änderung bis nach dem Commit blockiert, genügt ein **einmaliger** Direktlesevorgang.

## Bestätigte Rahmenbedingungen

- `AzureRelaySender.SendMessage` ist ein **synchroner** HTTP-POST an die Azure Function
  (`.../api/SendToDMP`, Timeout 180 s) und blockiert bis zur Function-Antwort.
- Die Azure Function macht **Request/Reply**: sie wartet auf die Service-Bus-Reply des Clients,
  bevor sie den HTTP-Response zurückgibt. (Vom User bestätigt.)
- Daher: Sobald der Client die Reply erst nach dem Commit sendet, blockiert `Submit*` in BC
  bis nach dem Commit → das Ergebnis liegt beim Rücksprung bereits in `DMP FS Result IOI`.

## Kritischer Blocker (Deadlock) und dessen Auflösung

`SubmitCommand` fügt eine Zeile in `DMP FS Request IOI` ein **ohne Commit** und hält damit einen
Schreib-Lock, solange `SendMessage` blockiert. `CommitFsResult` (separate OData-Session) schreibt
**dieselbe** Request-Zeile → Lock-Wartezeit → Deadlock/Lock-Timeout, sobald die Reply verzögert wird.

**Auflösung (vom User freigegeben):** In `SubmitCommand` die Request-Zeile **vor** dem
blockierenden `SendMessage` committen und Status vorab auf `Sent` setzen.

---

## Phase 1 — Client (C#, `DataMigratePro-PC`)

Dateien:
- `DataMigratePro.Core/FileSystemService.cs`
- `DataMigratePro.Core/ServiceBusListener.cs`

### 1.1 `FileSystemResultCommitter.TryCommitAsync` → `Task<bool>`

`Task` → `Task<bool>`; an allen Ausgängen `return true/false` (true = BC hat das Ergebnis erhalten):

```csharp
public static async Task<bool> TryCommitAsync(FileSystemCommandResult result, CancellationToken cancellationToken = default)
{
    if (result == null || string.IsNullOrWhiteSpace(result.TransactionId))
        return false;

    // ... commitUrl-Ermittlung unverändert ...
    if (string.IsNullOrWhiteSpace(commitUrl))
    {
        Logger.LogLocalWarning($"[FileSystem] Result commit skipped ... no commit endpoint URL configured.");
        return false;
    }

    for (var attempt = 1; attempt <= maxAttempts; attempt++)
    {
        try
        {
            // ...
            if (response.IsSuccessStatusCode)
            {
                Logger.LogLocalInformation($"[FileSystem] Result committed ...");
                return true;      // BC hat das Ergebnis
            }
            // ...
        }
        // ... catch unverändert ...
    }

    Logger.LogLocalWarning($"[FileSystem] Result commit GIVEN UP ... BC will never receive this result.");
    return false;                 // BC hat NICHTS bekommen
}
```

Hinweis: Der interne `CreateAccepted`-Vorab-Commit in `FileSystemService.ExecuteAsync` bleibt
unverändert (`await …;` verwirft den bool problemlos).

### 1.2 `ProcessFileSystemActionAsync` → `Task<bool>`

In allen Zweigen das Commit-Ergebnis zurückgeben statt `throw`:

```csharp
private async Task<bool> ProcessFileSystemActionAsync(string base64Data, string transactionId, CancellationToken cancellationToken)
{
    int fileSystemExtension = DataConnectionManager.Extension;
    if (fileSystemExtension != (int)ExtensionType.DataMigrateProFileService)
    {
        string licenseMessage = $"FileSystem commands are not permitted ...";
        Logger.LogError(licenseMessage, 0, "filesystem", "worker");
        return await FileSystemResultCommitter.TryCommitAsync(
            FileSystemCommandResult.CreateFailed(transactionId, "LICENSE_NOT_PERMITTED", licenseMessage),
            cancellationToken);
    }

    try
    {
        var result = await FileSystemService.ExecuteAsync(base64Data, transactionId, _settings.connectionId, cancellationToken);
        Logger.LogLocalInformation($"[FileSystem] Command '{result.Command}' executed ...");
        return await FileSystemResultCommitter.TryCommitAsync(result, cancellationToken);
    }
    catch (Exception ex)
    {
        Logger.LogError($"FileSystem command failed: {ex.Message}", 0, "filesystem", "worker");
        return await FileSystemResultCommitter.TryCommitAsync(
            FileSystemCommandResult.CreateFailed(transactionId, "PROCESSING_ERROR", ex.Message),
            cancellationToken);
    }
}
```

Ein fachlich fehlgeschlagenes, aber an BC **geliefertes** Ergebnis (z. B. `FILE_NOT_FOUND`)
zählt als geliefert → Message wird completed. Nur wenn der **Transport zu BC** scheitert → Abandon.

### 1.3 `HandleFileSystemMessageInlineAsync` umbauen

Complete/Response ans Ende, abhängig vom BC-Commit:

```csharp
private async Task HandleFileSystemMessageInlineAsync(
    ServiceBusClient client,
    ServiceBusSessionReceiver sessionReceiver,
    ServiceBusReceivedMessage message,
    ListenerQueuedMessage queuedMessage)
{
    AddHistory($"processing {queuedMessage.Action}");
    UpdateStatus("Processing", ConsoleColor.DarkYellow, $"{queuedMessage.Action} {queuedMessage.InstructionSummary}".Trim());

    bool resultDeliveredToBc = false;
    try
    {
        resultDeliveredToBc = await ProcessFileSystemActionAsync(queuedMessage.Base64Data, queuedMessage.OriginalTransactionId, _cancellationToken);
        AddHistory($"finished {queuedMessage.Action}");
        Logger.LogLocalInformation($"[FileSystem] Inline processing finished for transaction '{queuedMessage.OriginalTransactionId}', deliveredToBc={resultDeliveredToBc}");
    }
    catch (OperationCanceledException) when (_cancellationToken.IsCancellationRequested)
    {
        AddHistory($"canceled {queuedMessage.Action}");
        Logger.LogLocalWarning($"[FileSystem] Inline processing canceled during shutdown for transaction '{queuedMessage.OriginalTransactionId}'");
        return; // Im Shutdown nichts setteln → Redelivery beim nächsten Start
    }
    catch (Exception ex)
    {
        AddHistory($"error {queuedMessage.Action}");
        Logger.LogError($"Inline filesystem processing failed: {ex.Message}", 0, "filesystem", "inline");
        resultDeliveredToBc = false;
    }
    finally
    {
        UpdateStatus("Listening", ConsoleColor.DarkGreen, string.Empty);
    }

    if (resultDeliveredToBc)
    {
        // OK erst jetzt: BC hat das Ergebnis bereits erhalten.
        try
        {
            await SendResponseAsync(client, sessionReceiver.SessionId, BuildAcceptedResponseJson(queuedMessage), _cancellationToken);
        }
        catch (Exception responseEx)
        {
            Logger.LogWarning($"Listener committed filesystem result to BC but failed to publish response: {responseEx.Message}");
        }

        await sessionReceiver.CompleteMessageAsync(message, _cancellationToken);
    }
    else
    {
        // BC hat kein Ergebnis bekommen → Eintrag NICHT als gelesen markieren, Redelivery erzwingen.
        try
        {
            await sessionReceiver.AbandonMessageAsync(message, cancellationToken: _cancellationToken);
        }
        catch (Exception abandonEx)
        {
            Logger.LogWarning($"Listener failed to abandon filesystem message after BC commit failure: {abandonEx.Message}");
        }
    }
}
```

Poison-Schutz: `Abandon` erhöht den DeliveryCount → nach `MaxDeliveryCount` automatisches
Dead-Letter, kein Endlos-Loop.

---

## Phase 2 — DMP-App (AL, `DMP-AppSource`) — verhindert Deadlock, blockiert Phase 3

Datei: `DataMigratePro/src/FileSystem/Codeunits/DMPFileSystemApiIOI.Codeunit.al`, Prozedur `SubmitCommand`.

Änderung: Status `Sent` **vor** dem Send setzen, `Commit()` **vor** `AzureRelaySender.SendMessage`,
nachgelagerte `Modify(Status=Sent)` **entfernen** (sonst überschreibt sie den vom Client via
`CommitFsResult` gesetzten Completed/Failed-Status).

Vorher (Ausschnitt):
```al
    RequestRec.Insert(true);
    // ... RequestJson/EnvelopeJson bauen ...
    OuterMessage := Base64Convert.ToBase64(EnvelopeText);
    SendResult := AzureRelaySender.SendMessage(OuterMessage);

    RequestRec.Status := RequestRec.Status::Sent;
    RequestRec."Last Updated At" := CurrentDateTime();
    RequestRec.Modify(true);
```

Nachher (Ausschnitt):
```al
    RequestRec.Status := RequestRec.Status::Sent;
    RequestRec."Last Updated At" := CurrentDateTime();
    RequestRec.Insert(true);

    // Request-Zeile freigeben, bevor der blockierende Send auf die Client-Reply wartet,
    // damit CommitFsResult (separate Session) sie ohne Lock-Konflikt aktualisieren kann.
    Commit();

    // ... RequestJson/EnvelopeJson bauen ...
    OuterMessage := Base64Convert.ToBase64(EnvelopeText);
    SendResult := AzureRelaySender.SendMessage(OuterMessage);
    // KEIN Modify(Status=Sent) mehr nach dem Send.
```

Danach DMP-App neu kompilieren und die `.app` ins Example-`.alpackages` übernehmen
(siehe Build-Kommando unten).

---

## Phase 3 — Example (AL, `DMP-FileServiceExample`) — nach Phase 2

Datei: `src/Codeunit/DMPFSExplorerMgmt.al`.

### 3.1 Lokale `WaitForResultJson` auf Einmal-Lesen umstellen (Signatur unverändert)

`RefreshCurrentFolder` (3-Param) und `TryGetFilePreview` bleiben dadurch unverändert.

```al
local procedure WaitForResultJson(pTransactionId: Guid; var pResultJson: Text; var pStatusText: Text[100]; var pErrorCode: Text[100]; var pErrorMessage: Text[250]): Boolean
var
    FileSystemApi: Codeunit "DMP File System API IOI";
    ResultRec: Record "DMP FS Result IOI";
begin
    pResultJson := '';
    pStatusText := '';
    pErrorCode := '';
    pErrorMessage := '';

    // Antwort/Ergebnis liegt nach dem blockierenden Submit bereits vor; nur Snapshot auffrischen.
    SelectLatestVersion();
    if not ResultRec.Get(pTransactionId) then begin
        pStatusText := 'Failed';
        pErrorCode := 'NO_RESULT';
        pErrorMessage := CopyStr(StrSubstNo('No result found for transaction %1.', pTransactionId), 1, MaxStrLen(pErrorMessage));
        exit(false);
    end;

    if not (ResultRec.Status in [ResultRec.Status::Completed, ResultRec.Status::Failed]) then begin
        pStatusText := 'Pending';
        pErrorCode := 'PENDING';
        pErrorMessage := CopyStr(StrSubstNo('Result for transaction %1 not finalized (status %2).', pTransactionId, Format(ResultRec.Status)), 1, MaxStrLen(pErrorMessage));
        exit(false);
    end;

    pResultJson := FileSystemApi.GetResultPayload(pTransactionId);
    pErrorCode := CopyStr(ResultRec."Error Code", 1, MaxStrLen(pErrorCode));
    pErrorMessage := CopyStr(ResultRec.Message, 1, MaxStrLen(pErrorMessage));

    if ResultRec.Status = ResultRec.Status::Completed then begin
        pStatusText := 'Completed';
        exit(true);
    end;

    pStatusText := 'Failed';
    exit(false);
end;
```

### 3.2 `WaitForLastRequest` auf den Einmal-Lese-Helper umstellen

Methodenname beibehalten → die 13 Page-Actions und `DMPFSExplorerPage.al` bleiben unangetastet.

```al
procedure WaitForLastRequest(): Boolean
var
    ResultJson: Text;
    StatusText: Text[100];
    ErrorCode: Text[100];
    ErrorMessage: Text[250];
begin
    if IsNullGuid(LastTransactionId) then begin
        LastStatusText := 'No last request available to wait for.';
        exit(false);
    end;

    if WaitForResultJson(LastTransactionId, ResultJson, StatusText, ErrorCode, ErrorMessage) then begin
        LastStatusText := CopyStr(StrSubstNo('Request %1 completed. %2', Format(LastTransactionId), CopyStr(ResultJson, 1, 120)), 1, MaxStrLen(LastStatusText));
        exit(true);
    end;

    LastStatusText := CopyStr(StrSubstNo('Request %1 failed: %2 %3', Format(LastTransactionId), ErrorCode, ErrorMessage), 1, MaxStrLen(LastStatusText));
    exit(false);
end;
```

Damit ist `FileSystemApi.WaitForResult` (die Polling-Schleife) aus dem Example vollständig entfernt.

---

## Build / Verifikation

Kombinierter Build (DMP-App → `.app` ins Example kopieren → Example bauen):

```powershell
$alc = 'C:\Users\Shadow\.vscode\extensions\ms-dynamics-smb.al-17.0.2273547\bin\win32\alc.exe'
& $alc /project:'C:\Users\Shadow\source\repos\DMP-AppSource\DataMigratePro' /packagecachepath:'C:\Users\Shadow\source\repos\DMP-AppSource\DataMigratePro\.alpackages' /out:'C:\Users\Shadow\source\repos\DMP-AppSource\DataMigratePro\out.app' 2>&1 | Select-Object -Last 6
if ($LASTEXITCODE -eq 0) {
  Copy-Item 'C:\Users\Shadow\source\repos\DMP-AppSource\DataMigratePro\out.app' 'C:\Users\Shadow\source\repos\DMP-FileServiceExample\.alpackages\IO Integrated_DataMigrate Pro_27.1.228.0.app' -Force
  Remove-Item 'C:\Users\Shadow\source\repos\DMP-AppSource\DataMigratePro\out.app'
  & $alc /project:'C:\Users\Shadow\source\repos\DMP-FileServiceExample' /packagecachepath:'C:\Users\Shadow\source\repos\DMP-FileServiceExample\.alpackages' 2>&1 | Select-Object -Last 6
}
```

Prüfungen:
1. **Client** baut; Filesystem-Op: lokales Log zeigt `Result committed …` **vor** `SendResponseAsync`.
   Bei simuliertem BC-Ausfall (Commit schlägt fehl) → `AbandonMessageAsync`, Redelivery,
   kein „successfully read".
2. **DMP-App/BC**: `RefreshCurrentFolder` füllt die Entry-Tabelle sofort **ohne** 15-s-Warteschleife;
   keine Lock-Timeouts/Deadlocks im Session-Log; Request-Zeile endet auf Completed/Failed.
3. **Example**: `alc.exe` kompiliert fehlerfrei; Ordner-Refresh und Datei-Preview liefern
   unmittelbar Daten.

## Reihenfolge

1. Phase 1 (Client) — unabhängig.
2. Phase 2 (DMP-App) — erforderlich vor Phase 3, App neu deployen/`.app` aktualisieren.
3. Phase 3 (Example) — baut auf der aktualisierten `.app` auf.
