# Enhance Listener: PowerShell Execution from Business Central

## Goal

Business Central must be able to send PowerShell script execution requests to the local DataMigratePro listener through the existing Azure Function / ServiceBus architecture.

The listener must acknowledge receipt immediately, execute the script asynchronously, capture execution status and console output, and return the final result to Business Central through a BC Webservice/API. Business Central stores every execution in a dedicated transaction table and marks it as succeeded or failed with the execution output.

## Decisions

- Business Central sends free PowerShell script text.
- The listener executes only PowerShell, not arbitrary shell commands.
- The final result is returned to Business Central through a BC Webservice/API.
- Result data is stored in a new Business Central execution transaction table.
- The existing ServiceBus response is only an acceptance acknowledgement, not the final execution result.

## Workflow

1. Business Central creates a PowerShell execution transaction with a GUID transaction id.
2. Business Central stores script text, timeout, optional working directory, requested-by metadata, and status `Created`.
3. Business Central sends the request via the existing `Relay Sender IOI` / Azure Function path.
4. The listener receives the ServiceBus message and enqueues it in the existing listener activity table.
5. The listener immediately returns an accepted response with the transaction id.
6. Business Central marks the transaction as `Accepted` or `Send Failed`.
7. The listener worker executes the script asynchronously in PowerShell.
8. The listener captures stdout, stderr, exit code, start/end time, duration, and infrastructure errors.
9. The listener posts the final result back to Business Central using action `powershellresult`.
10. Business Central updates the transaction to `Succeeded`, `Failed`, `Timed Out`, `Canceled`, or `Callback Failed`.
11. Business Central stores stdout, stderr, result message, exit code, listener activity id, and timestamps.

## Message Contract

### BC to Listener

Action: `executepowershell`

The ServiceBus payload uses the existing envelope and contains a base64 UTF-8 JSON `data` payload.

Request fields:

- `transactionId`: GUID text
- `script`: PowerShell script text
- `timeoutSeconds`: integer
- `workingDirectory`: optional text
- `requestedBy`: BC user/security id text
- `companyName`: optional BC company name
- `createdAtUtc`: ISO timestamp

### Listener to BC

Action: `powershellresult`

Result fields:

- `transactionId`: GUID text
- `status`: `Succeeded`, `Failed`, `TimedOut`, `Canceled`, or `InfrastructureError`
- `exitCode`: integer or null
- `startedAtUtc`: ISO timestamp
- `finishedAtUtc`: ISO timestamp
- `durationMs`: integer
- `stdout`: captured standard output
- `stderr`: captured standard error
- `resultMessage`: short summary
- `listenerActivityId`: GUID
- `listenerConnectionId`: listener connection/session id

## Required PC Listener Changes

- Add action `executepowershell` to `ServiceBusListener.ProcessActionAsync`.
- Add PowerShell execution DTOs.
- Add a PowerShell executor that runs `powershell.exe` with `-NoProfile` and `-NonInteractive`.
- Capture stdout and stderr asynchronously.
- Enforce timeout and cancellation.
- Kill the process tree on timeout.
- Treat non-zero exit code as execution failure, not listener infrastructure failure.
- Post final result back to BC using action `powershellresult`.
- Record callback failures clearly in listener activity/logs.

## Required Business Central Changes

- Add a new PowerShell execution status enum.
- Add a new execution transaction table with BLOB fields for script, stdout, and stderr.
- Add pages for viewing and sending executions.
- Add a management codeunit to create/send execution transactions.
- Reuse `Relay Sender IOI` for transport.
- Extend `Upload IOI.LoadData` with action `powershellresult`.
- Update permissions for new objects.

## Guardrails

- Free script text is allowed by requirement, but execution must still be audited.
- Listener execution must be PowerShell-only.
- Scripts must run non-interactively.
- A timeout is required.
- Console output must be stored in BLOB fields or chunked/truncated if transport limits require it.
- Callback failure must be distinguishable from script failure.
- Existing `putdata`, `getdata`, `getstructure`, and AL `execute` behavior must remain unchanged.

## Verification

- Successful script: `Write-Output "Hello from BC"; exit 0`
- Failure script: write to stderr and `exit 1`
- Timeout script: sleep longer than configured timeout
- Confirm listener activity lifecycle for `executepowershell`.
- Confirm BC transaction status and output fields are updated correctly.
- Confirm existing BC/listener actions still work.