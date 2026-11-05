# DataMigratePro Listener Print Service - Fact Sheet

## Summary

The print service adds local printer discovery and local printing to the existing DataMigratePro listener architecture.

It enables Business Central to:
- discover locally installed printers
- persist printer inventory and capabilities in BC
- route print jobs to a selected local printer transparently
- support Zebra/raw printers as well as normal Windows driver-based printers
- submit single jobs, batch jobs, and job-queue driven print jobs
- receive structured callbacks with status, metadata, and errors

The user experience is intended to feel like classic local NAV printing, even though BC runs in the cloud.

## Business Value

- Makes local printing available to cloud-based Business Central users.
- Removes the need for manual file downloads before printing.
- Supports label printers, office printers, and mixed printer landscapes from one extension model.
- Keeps BC responsive by moving printer access into the listener process.
- Enables both synchronous and asynchronous printing workflows.
- Provides transaction-based traceability for queued and completed print jobs.

## End-to-End Flow

1. BC creates a print or discovery transaction.
2. BC sends a listener command through the existing relay and Service Bus path.
3. Listener accepts the request immediately.
4. Listener discovers printers or resolves the target printer locally.
5. Listener prints using either raw pass-through or Windows driver/spooler mode.
6. Listener returns result metadata to BC through a callback action.
7. BC updates printer inventory, print job status, and result details.

## Implemented Components

### PC listener side

- [DataMigratePro.Core/PrinterService.cs](DataMigratePro.Core/PrinterService.cs)
  - printer discovery request/result DTOs
  - print job request/result DTOs
  - printer enumeration
  - raw printer writer
  - callback result committers

- [DataMigratePro.Core/ServiceBusListener.cs](DataMigratePro.Core/ServiceBusListener.cs)
  - `printerdiscovery` listener action
  - `printjob` listener action
  - result callbacks for discovery and print jobs

- [DataMigratePro.Core/CommandLineProcessor.cs](DataMigratePro.Core/CommandLineProcessor.cs)
  - CLI entry point for `printerdiscovery`
  - scheduled-service compatible discovery execution

- [DataMigratePro.Core/CommandMetadata.cs](DataMigratePro.Core/CommandMetadata.cs)
  - registers `printerdiscovery` as a known task

- [DataMigratePro.Tests/UnitTests/PrinterServiceTests.cs](DataMigratePro.Tests/UnitTests/PrinterServiceTests.cs)
  - discovery contract checks
  - raw payload preservation checks
  - printer error-path checks

### BC extension side

- [DMP-AppSource/DataMigratePro/src/Printing/](../DMP-AppSource/DataMigratePro/src/Printing/)
  - printer inventory tables
  - printer mapping tables
  - print job transaction table
  - print service management codeunit
  - pages for printer inventory and print jobs

## Message Contract

### Discovery request

- Action: `printerdiscovery`
- Payload: base64 UTF-8 JSON
- Fields:
  - `transactionId`
  - `listenerConnectionId`
  - `companyName`
  - `requestedBy`
  - `createdAtUtc`

### Discovery result

- Action: `printerdiscoveryresult`
- Payload: base64 UTF-8 JSON
- Result fields:
  - `transactionId`
  - `status`
  - `printers`
  - `resultMessage`
  - `listenerActivityId`
  - `listenerConnectionId`

### Print job request

- Action: `printjob`
- Payload: base64 UTF-8 JSON
- Fields:
  - `transactionId`
  - `printerName`
  - `printMode`
  - `contentType`
  - `payloadBase64`
  - `copies`
  - `requestedBy`
  - `companyName`
  - `createdAtUtc`

### Print job result

- Action: `printjobresult`
- Payload: base64 UTF-8 JSON
- Result fields:
  - `transactionId`
  - `status`
  - `resultMessage`
  - `spoolerJobId`
  - `listenerActivityId`
  - `listenerConnectionId`

## Supported Printing Scenarios

- Zebra labels using raw ZPL or EPL streams.
- Office documents using installed Windows printer drivers.
- Transparent printer selection through logical printer mapping.
- Batch printing from BC job queues or background processes.
- Scheduled discovery refresh through the planned `serviceSchedule` mode.

## Status Semantics

- `Accepted`: request has been received by the listener transport.
- `Succeeded`: discovery or print job finished successfully.
- `Failed`: printer resolution, spooler operation, or callback processing failed.
- `TimedOut`: execution took too long or the operation was canceled.
- `Queued`: a job was accepted for later processing in BC.

## Technical Notes

- Zebra/raw printing is passed through without unnecessary transformation.
- Windows driver printing uses the local spooler and installed printer definitions.
- Discovery results can be refreshed periodically without manual BC interaction.
- The print service reuses the existing callback and transaction model.
- Batch printing is best implemented as multiple queued transactions rather than one monolithic payload.

## Verification Checklist

- Discover local printers and confirm inventory entries in BC.
- Print a Zebra label using raw ZPL and verify byte preservation.
- Print a normal document to a Windows driver printer.
- Run multiple jobs from a queue and verify each transaction updates independently.
- Verify that the listener returns structured errors for missing printers and unsupported modes.