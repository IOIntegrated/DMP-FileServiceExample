# DataMigratePro Listener Enhancement - Fact Sheet

## Summary

The listener enhancement adds asynchronous PowerShell execution for Business Central-driven commands over the existing Azure Function / Service Bus architecture.

The listener now supports:
- immediate acceptance acknowledgement
- asynchronous PowerShell execution
- stdout/stderr capture
- timeout handling and process-tree termination
- callback of final execution result to Business Central

## Business Value

- Replaces legacy C/AL shell execution with a controlled listener-based runtime.
- Keeps BC responsive by decoupling request acceptance from script completion.
- Adds auditability through transaction-based status and output tracking.
- Enables extension developers to reuse the same listener capability via a stable action contract.

## End-to-End Flow

1. BC extension creates a transaction and sends `action = executepowershell`.
2. Message is routed through existing Azure Function / Service Bus.
3. Listener accepts and queues the request (existing queue/activity model).
4. Worker executes script with PowerShell (`powershell.exe -NoProfile -NonInteractive`).
5. Listener captures stdout/stderr, duration, exit code, and timeout state.
6. Listener posts final callback to BC as `action = powershellresult`.
7. BC transaction is updated to final status and stores execution output.

## Implemented Components

### PC listener (DataMigratePro-PC)

- [DataMigratePro.Core/ServiceBusListener.cs](DataMigratePro.Core/ServiceBusListener.cs)
  - Added `executepowershell` action branch in `ProcessActionAsync`.
  - Preserves existing acceptance and queue behavior.

- [DataMigratePro.Core/PowerShellExecutionService.cs](DataMigratePro.Core/PowerShellExecutionService.cs)
  - `PowerShellExecutionRequest` DTO
  - `PowerShellExecutionResult` DTO
  - `PowerShellExecutionService.ParseRequest(...)`
  - `PowerShellExecutionService.ExecuteAsync(...)`
  - `PowerShellResultCommitter.CommitAsync(...)`

- [DataMigratePro.Core/ListenerActivityScope.cs](DataMigratePro.Core/ListenerActivityScope.cs)
  - Exposes current activity id to enrich callback payload.

- [DataMigratePro.Tests/UnitTests/PowerShellExecutionServiceTests.cs](DataMigratePro.Tests/UnitTests/PowerShellExecutionServiceTests.cs)
  - success path
  - non-zero exit code path
  - timeout path

### BC extension side (DMP-AppSource)

- New status enum, transaction table, management codeunit, and page under `DataMigratePro/src/PowerShell/`.
- [DMP-AppSource/DataMigratePro/src/endpoint/UploadIOI.Codeunit.al](../DMP-AppSource/DataMigratePro/src/endpoint/UploadIOI.Codeunit.al)
  - extended with `powershellresult` callback action.

## Message Contract

### Request to listener

- Action: `executepowershell`
- `data`: base64 UTF-8 JSON
- Payload fields:
  - `script`
  - `timeoutSeconds`
  - `workingDirectory` (optional)
  - `requestedBy`
  - `companyName` (optional)
  - `createdAtUtc`

### Result callback to BC

- Action: `powershellresult`
- `data`: base64 UTF-8 JSON
- Result fields:
  - `transactionId`
  - `status` (`Succeeded`, `Failed`, `TimedOut`, `Canceled`)
  - `exitCode`
  - `stdout`, `stderr`
  - `resultMessage`
  - `startedAtUtc`, `endedAtUtc`, `durationMs`
  - `listenerActivityId`, `listenerConnectionId`

## Status Semantics

- `Accepted`: message accepted by transport/listener queue.
- `Succeeded`: process finished with exit code `0`.
- `Failed`: process finished with non-zero exit code.
- `TimedOut`: timeout reached and process tree terminated.
- `Callback Failed`: script execution completed, but result callback/update in BC failed.

## Technical Notes

- Non-zero exit code is treated as business execution failure, not listener crash.
- Timeout uses cancellation and explicit process-tree kill.
- Callback retries are built into the committer.
- The listener callback uses the existing BC endpoint base configured in `DataConnectionManager.dataEndpointUrl`.

## Security and Operations

- Execution runtime is limited to PowerShell process invocation.
- Scripts are non-interactive (`-NonInteractive`) and profile-independent (`-NoProfile`).
- Extension-side permissions and auditing are required on BC side.
- Recommended operational controls:
  - short default timeout
  - output size policies
  - request source authorization
  - monitored callback failures

## Verification Checklist

- Send script: `Write-Output "Hello from BC"; exit 0` -> `Succeeded`.
- Send script: `Write-Error "x"; exit 1` -> `Failed`.
- Send script longer than timeout -> `TimedOut`.
- Confirm callback updates transaction record and stores stdout/stderr.
- Confirm existing listener actions still work (`putdata`, `getdata`, `filesystem`, etc.).
