# DataMigratePro - Extended Switches and BuildMapping Entry Points

This document complements the quick overview in docs/DataMigratePro-Parameters-Quick-Overview.md.
It focuses on additional switches and advanced entry points that are not fully covered there.

## 1) Additional root entry switches

These switches can start workflows without using -t.

| Switch | Purpose | Notes |
|--------|---------|-------|
| --mappingfromazure | Pull mapping/config fields from Azure into migration tables | Optional: -o export file, -i import file |
| --mappingtoazure | Push migration mapping/config to Azure | Upload mode requires --clientid and --clientsecret |
| --buildmapping | Full buildmapping workflow (build + enrich + publish) | Main end-to-end mapping pipeline |
| --buildlocalmapping | Local/BC preparation pipeline without final publish+recordcount send | Useful for staged operations |
| --buildquickautomapping | Run quick auto-mapping only | Can be scoped and dry-run |
| --applyconfigurationchanges | Apply ConfigurationChangeApplier | Standalone step |
| --sendrecordcounts | Send table record counts to BC | Standalone step |
| --checkgetstructurefield | Execute structure-field consistency checks | Maintenance/diagnostics |
| --refreshbcstructurestrict | Force strict BC structure refresh | Maintenance/diagnostics |
| --applytransformations | Run mapping transformation orchestrator only | No rebuild, no publish |
| --analyzetransformations | Analyze transformations/report | Diagnostics |
| --comparestructureperformance | Compare old/new structure-resolution performance | Supports --iterations |
| --maintaintransfer | Maintain $Transfer tables and related SQL artifacts | Maintenance |
| --queuehandling | Run queue handling once | Returns immediately after processing |
| --editmode | Open the dedicated mapping editor GUI | Starts desktop UI mode for mapping/config editing |

## 2) BuildMapping-related sub switches

These switches are used with buildmapping-related entry points.

| Switch | Used with | Purpose |
|--------|-----------|---------|
| --dryrun | --buildquickautomapping | Preview affected rows, no write |
| --scope <t:f,t:f> | --buildquickautomapping | Limit auto-mapping to source table/field pairs |
| --mapall | --buildquickautomapping | Recalculate all rows (not only missing/invalid) |

## 2.1) Mapping editor startup mode

The `--editmode` switch starts the dedicated mapping editor GUI and does not require `-t`.

```powershell
DataMigratePro.exe --editmode
```

Behavior summary:

- Opens the mapping maintenance UI with navigation for migration tables, destination tables, value mappings, and configuration.
- Keeps all existing non-UI startup paths unchanged when the switch is not provided.
- Requires valid data-source connectivity; startup failures are surfaced in the UI to prevent invalid edits.

For detailed functional requirements, see `docs/Requirement-editmode-UI.md`.

## 3) Additional operational switches

These are valid command-line switches parsed by runtime, beyond the quick overview.

### 3.1 Performance and runtime behavior

| Switch | Purpose | Typical context |
|--------|---------|-----------------|
| --benchmark / --bm | Enable benchmark run output | putdata, putalldata |
| --benchmarkjson | Force benchmark JSON output mode | Benchmark automation |
| --benchmarkmode <label> | Tag benchmark mode label | Benchmark comparison |
| --skipscan | Skip pre-scan record metrics | putalldata startup acceleration |
| --mappingparallel <n> | Mapping prebuild parallelism | putalldata |
| --putdataretries <n> | Override retry attempts for putdata chunk send | unstable networks/endpoints |
| --nobr / --nobrotli | Disable Brotli content encoding preference | troubleshooting HTTP compression |
| --parallel <n> | Internal putdata parallelism parameter | advanced/internal |

Note: If `ForceSequentialPutDataChunks` is set to `true` in `settings.json`, effective putdata chunk parallelism is always `1` (sequential), regardless of `--parallel`.

### 3.2 Mapping behavior

| Switch | Purpose | Typical context |
|--------|---------|-----------------|
| --usemapping | Force use of -m mapping file even when automapping default would apply | putdata |
| --newpayload | Prefer new putdata payload format | compatibility rollout |
| --prefernewpayload | Alias for new payload preference | compatibility rollout |
| --putdatanew | Alias for new payload preference | compatibility rollout |

### 3.3 Data target and transport tuning

| Switch | Purpose | Typical context |
|--------|---------|-----------------|
| -ndb <Database> | Target database name when getdata writes to SQL table via -n | getdata |
| --batchsize <n> | DeleteData batch size | deletedata |
| --connectionid <id> | Explicit service bus/connection context override | listener/service scenarios |
| --sqlconnectionmigration <str> | Dedicated migration SQL connection string | split SQL topologies |
| --sourcedbtableprefix <str> | Explicit NAV table prefix override | special source naming |
| --blobmagicsignature <bytes> | Override blob magic signature bytes | advanced blob staging compatibility |

### 3.4 Legacy compatibility aliases (still accepted)

| Switch | Purpose | Recommended replacement |
|--------|---------|------------------------|
| --azuresqlchunksize | Legacy alias for blob staging chunk size | --azureblobchunksize |
| --azuresqlcodeunitid | Legacy alias for blob transfer codeunit | --azureblobcodeunitid |
| --subscriptionid | Alias for Azure subscription | --subscription |

## 4) Listener-only control switches

Use with -t listen.

| Switch | Purpose |
|--------|---------|
| --killpendingtasks | Delete pending listener tasks before startup |
| --finishincompleteasfinished | Mark incomplete listener activities as finished at startup |

## 5) BuildMapping phase model

The effective buildmapping pipeline in runtime is composed of these phases:

1. Validate migration setup (BC Migration Tables/Mapping not empty)
2. Local mapping build (MappingBuilder.BuildMappingAsync)
3. Local source structure scan
4. BC structure phase:
   - Ensure BC structure for buildmapping
   - Run quick auto-mapping
5. Transformation phase:
   - ApplyAllTransformations
   - ApplyDimensionSetIdFieldPolicy
   - PromoteSynchronizationTypesForEligibleTables
   - ApplyNoMappingConfigurationSynchronizationPolicy
6. Publish phase:
   - HandleSaveConfigurationAsync
   - SendRecordCountsForAllTablesAsync (for full --buildmapping path)

## 6) Entry points that reuse buildmapping parts

This is the requested mapping of entry points to buildmapping parts.

| Entry point | Reuses local build | Reuses BC structure + quick automap | Reuses transformation phase | Reuses publish to BC |
|------------------|-------------------|----------------------------------------|---------------------------|----------------------|
| --buildmapping | yes | yes | yes | yes |
| --buildlocalmapping | yes | yes | yes | no |
| --buildquickautomapping | no | quick automapping only | no | no |
| Listener action: buildmapping | yes | yes | yes | yes |
| Listener action: buildlocalmapping | yes | yes | yes | no |

## 7) Practical examples

### Quick automapping dry run on selected fields

```powershell
DataMigratePro.exe --buildquickautomapping --dryrun --scope "23:11000,39:5005396"
```

### Full buildmapping via dedicated root switch

```powershell
DataMigratePro.exe --buildmapping
```

Important:
- This includes a publish step to BC configuration tables.
- During publish, BC Migration Tables and BC Migration Mapping are cleared first and then reloaded from the local mapping database.
- This is an overwrite workflow (replace), not a merge workflow.

### Local buildmapping only (no publish)

```powershell
DataMigratePro.exe --buildlocalmapping
```

### Refresh and rebuild BC structure data (strict)

```powershell
DataMigratePro.exe --refreshbcstructurestrict
```

This command reloads BC structure metadata with strict validation before downstream mapping/build steps.

### Build local mapping pipeline including BC structure load

```powershell
DataMigratePro.exe --buildlocalmapping
```

This runs the local build pipeline and includes BC structure loading plus quick auto-mapping.

### Safe sequence when BC structure changed (with backup before overwrite)

#### 1) Backup current BC configuration
```powershell
DataMigratePro.exe -t loadconfiguration -o config-backup.zip
```

#### 2) Refresh BC structure metadata strictly
```powershell
DataMigratePro.exe --refreshbcstructurestrict
```

#### 3) Rebuild local mapping (no publish yet)
```powershell
DataMigratePro.exe --buildlocalmapping
```

#### 4) Publish to BC only when validated
```powershell
DataMigratePro.exe -t saveconfiguration
```

This keeps a restore point and avoids unintended data loss if the new structure or mapping needs review first.

### PutAllData with benchmark and reduced startup latency

```powershell
DataMigratePro.exe -t putalldata --tablegroup "1,2" --benchmark --benchmarkmode "full-master" --skipscan
```

### Listener startup cleanup mode

```powershell
DataMigratePro.exe -t listen --killpendingtasks
```

## 8) Stability guidance

- Preferred for production automation: switches listed in ParameterHelper/CommandMetadata and used in CommandLineProcessor routing.
- Advanced/internal flags in DataHandler are supported but may evolve faster (for example payload compatibility flags).
- For scripts, pin executable version and validate against this document after upgrades.
