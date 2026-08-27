# DataMigratePro Feature Field Map Extension — Implementation Plan

## 1. Problem

The `SalesPrice` feature migration (`-t putalldata/-deletealldata -feature "SalesPrice"`) maps a fixed,
hard-coded column set from the legacy price/discount tables (7002, 7004, 7012, 7014, 1013, 1014, 1012,
201, 202) into `Price List Header`/`Price List Line`. Both the source SQL (`FeatureSqlComposer.cs`) and
the target field list (`FeatureCatalog.cs`) are C# literals.

Customers who extended the legacy source tables (e.g. `Group Code`, `Weight`, `Vendor No.` on `Sales
Price`; `Group Code`, `Customer No.`, `Weight` on `Purchase Price`) and mirrored those dimensions onto
`Price List Line` via a `tableextension` currently get **no data at all** for those columns — the
feature migration only knows the standard field set.

Goal: let such extra source→target mappings be supplied as an **external JSON file** at runtime, without
adding any per-customer column knowledge to the C# code base.

## 2. Non-goals

- No change to the standard field set migrated by `SalesPrice` today (must keep working unmodified when
  no extension file is supplied).
- No schema introspection/auto-discovery of extension fields — mappings must be declared explicitly.
- No change to the BC-side `Price List Line` extension itself; DMP only writes to fields that already
  exist on the target table.

## 3. JSON schema

New file, loaded via a CLI parameter (see §4). One file per feature.

```json
{
  "feature": "SalesPrice",
  "extensions": [
    { "source": "SalesPrice", "sourceColumn": "Group Code", "column": "GroupCode", "type": "code20" },
    { "source": "SalesPrice", "sourceColumn": "Vendor No_", "column": "VendorNo", "type": "code20" },
    { "source": "SalesPrice", "sourceColumn": "Weight", "column": "Weight", "type": "decimal" },
    { "source": "PurchasePrice", "sourceColumn": "Group Code", "column": "GroupCode", "type": "code20" },
    { "source": "PurchasePrice", "sourceColumn": "Customer No_", "column": "CustomerNo", "type": "code20" },
    { "source": "PurchasePrice", "sourceColumn": "Weight", "column": "Weight", "type": "decimal" }
  ],
  "fieldMaps": [
    { "column": "GroupCode", "targetTableId": 7001, "targetFieldNo": 7250, "validate": false },
    { "column": "VendorNo", "targetTableId": 7001, "targetFieldNo": 7251, "validate": false },
    { "column": "CustomerNo", "targetTableId": 7001, "targetFieldNo": 7252, "validate": false },
    { "column": "Weight", "targetTableId": 7001, "targetFieldNo": 7253, "validate": false }
  ]
}
```

### Field reference

| Path | Meaning |
|---|---|
| `feature` | Must match a name in `FeatureCatalog.KnownFeatureNames`; the file is rejected otherwise. |
| `extensions[].source` | Must match a `FeatureSourceTable` enum name (`SalesPrice`, `SalesLineDiscount`, `PurchasePrice`, `PurchaseLineDiscount`, `JobItemPrice`, `JobGLAccountPrice`, `JobResourcePrice`, `ResourceCost`, `ResourcePrice`). |
| `extensions[].sourceColumn` | Physical NAV column name as used in the existing `NormalizedLineSelect` blocks (including `<Field>` prefix where the composer already uses it for a field). |
| `extensions[].column` | Logical alias the value is carried under through `normalized` → `lines_with_header` → final SELECT. Must be unique per file. |
| `extensions[].type` | One of `code10`, `code20`, `code30`, `text250`, `decimal`, `date`, `boolean`, `integer` — controls the `NULL AS [column]` cast used for sources that don't define this column, so `UNION ALL` stays type-consistent. |
| `fieldMaps[].column` | Must reference an `extensions[].column` value. |
| `fieldMaps[].targetTableId` | Must match a `TargetTableId` of an existing `FeatureDataTransfer` in the feature (7000 or 7001 for `SalesPrice`). |
| `fieldMaps[].targetFieldNo` | BC field number on the target table/extension. |
| `fieldMaps[].validate` | Same meaning as `FeatureFieldMap.Validate` today. |

### Validation rules (fail fast, reject the whole file on any violation)

1. `feature` known.
2. Every `extensions[].source` is a valid `FeatureSourceTable` name.
3. Every `extensions[].type` is a supported cast keyword.
4. `column` values unique within `extensions`.
5. Every `fieldMaps[].column` exists in `extensions`.
6. Every `fieldMaps[].targetTableId` matches an existing transfer for the feature.
7. No duplicate `(targetTableId, targetFieldNo)` pair across the merged (built-in + extension) field list.

## 4. CLI surface

New optional value flag, valid for `putalldata` and `deletealldata` alongside `-feature`:

```
DMP.exe -t putalldata -feature "SalesPrice" -featurefieldmap "C:\path\to\salesprice-fieldmap.json"
```

Changes:

- `CommandMetadata.cs` — add `--featurefieldmap` to the option list of `putalldata`/`deletealldata`
  (alongside `--feature`), plus help text in `ParameterHelper.cs`.
- `CommandLineProcessor.cs` — read `-featurefieldmap` the same way `-feature` is read today and pass the
  path through to `HandleFeaturePutAllDataAsync` / `HandleFeatureDeleteAllDataAsync`.
- Absent parameter → behavior is byte-for-byte identical to today (no extension file, no extra columns).

## 5. Code changes (`DataMigratePro.Core/FeatureMigration`)

### 5.1 New model + loader (`FeatureFieldMapExtension.cs`)

- POCOs mirroring §3 (`FeatureFieldMapDocument`, `FeatureFieldMapExtensionEntry`, `FeatureFieldMapEntry`).
- `FeatureFieldMapLoader.Load(string path, string featureName)` — deserializes, runs the validation rules
  from §3, throws a descriptive exception (with file path + rule) on any violation, returns a parsed
  document.
- No dependency on `FeatureCatalog`/`FeatureSqlComposer` internals beyond the public enums/constants
  needed for validation (`FeatureSourceTable`, `FeatureCatalog.TryGet`).

### 5.2 `FeatureSqlComposer.cs` — make the per-source column list extensible

Today `NormalizedLineSelect` returns a fixed string per `FeatureSourceTable`. Refactor:

- `Compose(sources, projection, extraColumns)` gains an `IReadOnlyList<FeatureExtraColumn> extraColumns`
  parameter (empty by default), where `FeatureExtraColumn` = `(FeatureSourceTable Source, string
  SourceColumnExpr, string Column, string SqlCastForNull)`.
- For each source's `NormalizedLineSelect` block, append one line per extra column that applies to that
  source (`, sp.[Group Code] AS [GroupCode]`) and one `NULL` line, correctly cast, for every extra column
  that does **not** apply to that source (`, CAST(NULL AS nvarchar(20)) AS [GroupCode]`), so the
  `UNION ALL` keeps a consistent column list/types across all sources.
- Thread the extra column names through `canonical_headers`/`numbered_headers` is **not** required — the
  header identity stays the built-in one (§7 explains why). Only `lines_with_header` and the final line
  SELECT need the extra columns appended.
- Existing hard-coded call sites (no extra columns) keep working unchanged because the new parameter
  defaults to empty.

### 5.3 `FeatureCatalog.cs` — merge external field maps

- `BuildSalesPriceFeature()` (and future feature builders) stay unchanged as the *base* definition.
- New method `FeatureCatalog.ApplyFieldMapExtensions(FeatureDefinition feature, FeatureFieldMapDocument doc)`
  that, per `fieldMaps` entry, finds the matching `FeatureDataTransfer` by `TargetTableId` and appends a
  `FeatureFieldMap { FieldNo = targetFieldNo, SourceColumn = column, Validate = validate, PrimaryKey =
  false }`. Primary-key extension is intentionally not supported (target PK is `Price List Code` + the
  auto-increment `Line No.`; extra dimensions are informational only, matching how they already behave in
  8/12/13).

### 5.4 `DataHandler.FeatureMigration.cs` — wire it together

- `HandleFeaturePutAllDataAsync`/`HandleFeatureDeleteAllDataAsync` accept the optional
  `-featurefieldmap` path, call `FeatureFieldMapLoader.Load`, then `FeatureCatalog.ApplyFieldMapExtensions`
  on the in-memory `FeatureDefinition` before the existing transfer loop runs.
- `TransferFeatureDataAsync` passes the document's `extensions` (filtered to the sources actually used by
  that transfer) into `FeatureSqlComposer.Compose(...)` instead of calling it with no extra columns.
- No persistence anywhere — the merged definition lives only for the duration of the run, consistent with
  the existing "in-memory mapping" design principle (`FeatureMappingCleanup.cs` remains unaffected since
  nothing is written to `BC Migration Mapping`/`BC Migration Tables`).

## 6. Testing plan

- Unit tests for `FeatureFieldMapLoader` covering: valid file, unknown feature, unknown source, duplicate
  column, unmapped `fieldMaps.column`, unknown `targetTableId`, duplicate `(targetTableId, targetFieldNo)`.
- Unit test for `FeatureSqlComposer.Compose` with a synthetic extra column applied to one source only,
  asserting the generated SQL contains the value column for that source and a correctly typed `NULL` for
  the others.
- Integration-style test (existing `DataMigratePro.Tests` harness) running `HandleFeaturePutAllDataAsync`
  with and without `-featurefieldmap` against a test database, verifying:
  - Without the parameter: identical behavior/row counts to the current baseline.
  - With the parameter: extra columns appear with correct values in the transformed rows sent to BC.

## 7. Why this does not reintroduce the 7002/7012 key-collision problem

`Price List Line."Line No."` is `AutoIncrement = true` and is deliberately **not** part of the
`FeatureFieldMap` list (`FieldNo = 1` / `PriceListCode` is the only field marked `PrimaryKey = true` for
the line transfer). Every source row therefore becomes its own line under its header instead of matching
an existing record by a reduced key — the n:1 overwrite problem described for direct 7002/7012 migration
does not apply to the `Price List Line` path, with or without the new extension columns. The extension
columns only add descriptive dimensions to each line; they never participate in insert/modify matching.

## 8. Documentation updates required

Both are living technical documents for this feature and must be updated once the code above lands:

### `docs/DataMigratePro-FeatureUpgrade-Implementation.md`

- Add a new "§4 Field map extensions" section describing the JSON schema, the `-featurefieldmap`
  parameter, `FeatureFieldMapLoader`, and the `FeatureSqlComposer`/`FeatureCatalog` extension points from
  §5 of this plan.
- Extend the "Command flow" Mermaid diagram with the optional `-featurefieldmap` branch.
- Extend the `CommandMetadata.cs` row in the "Components" table to mention `--featurefieldmap`.
- Add `FeatureFieldMapExtension.cs` (loader/model) as a new row in the "Components" table.
- Note in the "Target field maps (SalesPrice)" section that the listed field maps are the **built-in
  base set**; externally supplied maps are appended at runtime and are not shown here (they are
  data-driven, not code-driven).

### `docs/DataMigratePro-FeatureUpgrade-FactSheet.md`

- Add a short "Optional: extending the field map" section under "What `-feature "SalesPrice"` does"
  explaining that customers who extended the legacy source tables and the target `Price List Line` via a
  `tableextension` can supply `-featurefieldmap <path.json>` to migrate those dimensions too, without any
  code change.
- Add the `-featurefieldmap` example to the PowerShell snippet at the top.
- Add `DataMigratePro-FeatureFieldMap-Extension-Plan.md` (this document) to "Related documents" — replace
  with a link to the finished implementation section once merged into
  `DataMigratePro-FeatureUpgrade-Implementation.md`, keeping only one canonical technical reference.

## 9. Rollout

1. Implement §5 (loader, composer change, catalog merge, CLI wiring).
2. Add tests per §6.
3. Update both docs per §8.
4. Dry-run with `-testrun` (existing flag) against a copy of the customer's source DB using a real
   `-featurefieldmap` file before any production `putalldata`.
