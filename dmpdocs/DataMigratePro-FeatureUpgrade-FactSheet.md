# DataMigratePro Feature Upgrade — Fact Sheet

## What it is

A **feature-based migration mode** for DataMigratePro that migrates a complete Business Central
"feature area" in one command instead of table-by-table. The first supported feature is
**`SalesPrice`** (the legacy price/discount tables → the new Price List model).

```powershell
# Perform the migration
DMP.exe -t putalldata -feature "SalesPrice"

# Perform the migration and also migrate customer extension columns (optional)
DMP.exe -t putalldata -feature "SalesPrice" -featurefieldmap "C:\path\to\salesprice-fieldmap.json"

# Undo the migration
DMP.exe -t deletealldata -feature "SalesPrice"
```

Further features can be added later without changing the command surface.

## What `-feature "SalesPrice"` does

| Step | Action |
|------|--------|
| 1 | Loads the legacy pricing data with prepared staging queries (no per-table mapping needed). |
| 2 | Builds the mapping **in memory** — nothing is written to `BC Migration Tables` / `BC Migration Mapping`. |
| 3 | Sends **Price List Header** and **Price List Line** to Business Central. |
| 4 | Creates the required **No. Series** and **No. Series Line** records (`S-PL`, `P-PL`, `J-PL`). |
| 5 | Sets the **`Price List Nos.`** field on the Sales, Purchase and Jobs setup tables. |
| 6 | Marks the BC **feature data upgrade as done** (`Feature Data Update Status = Complete` + an upgrade tag). |
| 7 | Records the run in the **`DMP Feature Migration Log`** table of the migration database. |

`-t deletealldata -feature "SalesPrice"` reverses all of the above.

## Optional: extending the field map

Customers who extended the legacy source tables (e.g. added `Group Code`, `Vendor No.` or `Weight` to
`Sales Price`/`Purchase Price`) and mirrored those dimensions onto `Price List Line` via a
`tableextension` can migrate those extra columns too — **without any code change** — by supplying an
external JSON file:

```powershell
DMP.exe -t putalldata -feature "SalesPrice" -featurefieldmap "C:\path\to\salesprice-fieldmap.json"
```

The file declares, per feature, which physical source columns (`extensions`) are carried through the
staging query and which target fields they populate (`fieldMaps`). It is validated up front (unknown
feature/source/type, duplicate columns, unmapped or colliding target fields are all rejected) and is
never persisted — the extra maps live only for the duration of the run and leave the built-in field set
unchanged. Omitting `-featurefieldmap` produces byte-for-byte the same behavior as before.

## Source → target coverage (SalesPrice)

| Legacy source table | Target |
|---------------------|--------|
| Sales Price | Price List Line + Header |
| Sales Line Discount | Price List Line + Header |
| Purchase Price | Price List Line + Header |
| Purchase Line Discount | Price List Line + Header |
| Job Item Price | Price List Line + Header |
| Job G/L Account Price | Price List Line + Header |
| Job Resource Price | Price List Line + Header |
| Resource Cost | Price List Line + Header |
| Resource Price | Price List Line + Header |

Headers are derived deterministically (code prefix **`MIG-HDR-`**) so the reversal can find and remove
exactly what was created.

## Key characteristics

- **Non-invasive to the standard flow** — the regular `putalldata`/`deletealldata` table-group logic is
  untouched; the feature path is only taken when `-feature` is supplied.
- **In-memory mapping** — the feature mapping is never persisted, so it cannot pollute the normal
  migration configuration.
- **Documented runs** — every fill/empty is logged with status, record count, timestamps and message.
- **Extensible** — new features are added as new entries in the feature catalog.

## Business Central endpoint

A new Business Central endpoint action performs the BC-side steps that cannot be done safely from the
tool (partial updates of singleton setup records and marking the feature complete):

- `featureupgrade` — fills setup number series, marks the feature complete, sets the upgrade tag.
- `featurerevert` — removes the migrated price lists, clears the setup fields, resets the feature status.

## Related documents

- [DataMigratePro-FeatureUpgrade-Implementation.md](DataMigratePro-FeatureUpgrade-Implementation.md) — technical implementation details.
- [DataMigratePro-FeatureFieldMap-Extension-Plan.md](DataMigratePro-FeatureFieldMap-Extension-Plan.md) — the `-featurefieldmap` extension design (JSON schema, validation rules, extension points).
- [new-price-calulation-sql/](new-price-calulation-sql/) — the prepared staging queries used as the data source.
