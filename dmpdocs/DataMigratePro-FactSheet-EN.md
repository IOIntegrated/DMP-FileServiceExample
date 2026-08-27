---
title: DataMigratePro — Fact Sheet
date: 2026-06
version: 2026-06
---

**One-line:** Direct, repeatable migration and live synchronization from Microsoft Dynamics NAV/Navision/Business Central into Dynamics 365 Business Central (Cloud or On-Premise) — no jump versions, no downtime.

---

## What it does

- **Direct migration** to BC without expensive intermediate "jump" upgrades.
- **Parallel operation:** source and target stay live during migration — no hard cutoff.
- **Live, bi-directional sync** of customers, vendors, items, assets, custom tables and files.
- **Repeatable deltas:** run a full migration once, then sync only changed records in catch-up cycles (`--changesonly 1`).

## How it is delivered

| Component | Role |
|---|---|
| **DataMigratePro client** (`DataMigratePro.exe`) | Windows CLI / interactive tool that reads source SQL and uploads to BC via OData. |
| **Synch-Service (Launcher)** | Runs the client as a Windows service / Azure Service Bus listener for unattended, continuous sync. |
| **BC AppSource extension** | Receiver inside Business Central: setup wizard, mapping tables, upload endpoint, change logging. |
| **Azure Function + Service Bus** | Relay between BC and the on-prem listener (request/response queues). |

## Architecture flow

```
NAV/BC SQL ──► DataMigratePro client ──OData──► BC AppSource extension
                      ▲                                  │
                      └── Azure Service Bus ◄── Azure Function ◄── BC (trigger)
```

## Core concepts

- **Tasks** (`-t`): `putdata` / `putalldata` (send), `getdata` (export BC→SQL), `deletedata`, `generate*query`, `countrecords`, `loadconfiguration` / `saveconfiguration`, `createazuresql` / `removeazuresql`, `listen` (service), `execute` (call BC codeunit).
- **Mapping**: source↔destination table & field mappings stored in the mapping DB. Supports SQL **Calculation** expressions, **Where Clause** row filters, **Join Clause** with `{Company}` / `{FieldName}` placeholders.
- **Table groups**: filter what gets processed (master data, setup, entries, documents) via `--tablegroup`.
- **Transfer modes**: API/OData upload or Azure SQL staging per table; streaming by default, optional `--buffered`.
- **Benchmark**: `--benchmark` writes phase-based JSON timing metrics.

## Receiver side (Business Central extension)

- **Setup Wizard** (≈10 steps): registration → cloud auth gate → connection → (NAV 2009 C/AL objects) → download listener → build mapping → initial transfer → progress → schedule recurring updates.
- **Data Processing Handler** with subscription events (`OnBeforeInsertModifyRecord`, `OnBeforeDeleteRecord`, `OnAfterRecordProcessed`, `OnRecordOperationError`) so partners add custom logic without touching the core.
- **Manual Change Logging**: user edits in synced tables are logged and transmitted (direct or bulk job) back through the Azure Function. API-driven writes are suppressed to avoid feedback loops.
- **Retry & Dead-Letter**: failed transmissions retry automatically; after 3 failures an entry is dead-lettered for operator requeue.
- **Periodic GetAllData**: scheduled `getalldata --changesonly 1` for recurring delta pulls.

## Prerequisites (short)

- Windows machine, TLS 1.2+, ~2 GB disk, 4–16 GB RAM.
- SQL Server 2016+ / Azure SQL read access to the source DB.
- BC SaaS: Tenant ID, Client ID, Client Secret, OData `Upload_LoadData` endpoint, AppSource app installed. On-Prem: BC instance URL/port + service account.
- All secrets stored in `settings.json` (restricted permissions) — never on the command line.

## Sources supported

Dynamics NAV 2009–2018, Business Central v14–v27, Azure SQL.

## Security notes

- Least-privilege model: table permissions granted in event subscribers, not the core handler.
- Credentials kept out of CLI args; stored in a permission-restricted `settings.json`.

---
*Summary fact sheet. For details see the full guides in `docs/` (Getting Started, Parameters, Mapping, Synch-Service, Benchmark, Azure SQL) and the receiver docs in `DMP-AppSource/DataMigratePro/docs/`.*
