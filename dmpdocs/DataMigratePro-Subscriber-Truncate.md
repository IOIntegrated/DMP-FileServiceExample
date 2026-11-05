# DataMigratePro Subscriber: Truncate Extension Hook

## Purpose

DataMigratePro exposes an integration event when the built-in truncate attempt fails.
This allows other extensions to handle table cleanup for their own tables, including tables that are not part of the current DataMigratePro permission list.

Typical use case:
- Your extension owns a table.
- The table requires direct delete permissions for truncate.
- DataMigratePro cannot declare permissions for your extension objects.
- Your extension subscribes to the event and performs cleanup with its own permissions.

## Event Overview

Publisher object:
- Page `72359583 "BC Table List IOI"`

Event name:
- `OnAfterTruncateFailed`

Event signature:

```al
[IntegrationEvent(false, false)]
local procedure OnAfterTruncateFailed(
    TableNo: Integer;
    TableName: Text[100];
    var RecRef: RecordRef;
    var Reseeded: Boolean;
    var IsHandled: Boolean)
begin
end;
```

When this event is raised:
1. DataMigratePro already tried `RecRef.Truncate(true)` and it failed.
2. Subscribers can try custom handling.
3. If no subscriber handles it, DataMigratePro falls back to `RecRef.DeleteAll(true)`.

## Contract for Subscribers

Use these parameters as follows:
- `TableNo`: Selected table ID.
- `TableName`: Selected table name.
- `RecRef`: Open `RecordRef` to the selected table.
- `Reseeded`:
  - Set to `true` if your handler completed a truncate with reseed behavior.
  - Set to `false` if your handler deleted rows without reseed.
- `IsHandled`:
  - Set to `true` if your subscriber performed the operation and DataMigratePro should stop default fallback handling.
  - Keep `false` if you do not handle the table.

Important:
- Only set `IsHandled := true` when your operation has actually succeeded.
- Keep your logic table-specific to avoid accidental handling of unrelated tables.

## Example Subscriber (Own Extension)

```al
namespace MyCompany.MyExtension;

using IOI.DataMigratePro;

codeunit 70000010 "DMP Truncate Subscriber"
{
    Permissions = tabledata "My Custom Ledger" = RIMD;

    [EventSubscriber(ObjectType::Page, Page::"BC Table List IOI", 'OnAfterTruncateFailed', '', false, false)]
    local procedure HandleAfterTruncateFailed(
        TableNo: Integer;
        TableName: Text[100];
        var RecRef: RecordRef;
        var Reseeded: Boolean;
        var IsHandled: Boolean)
    begin
        // Handle only this extension table.
        if TableNo <> Database::"My Custom Ledger" then
            exit;

        if TryTruncateOwnTable(RecRef) then begin
            Reseeded := true;
            IsHandled := true;
            exit;
        end;

        if TryDeleteOwnTable(RecRef) then begin
            Reseeded := false;
            IsHandled := true;
        end;
    end;

    [TryFunction]
    local procedure TryTruncateOwnTable(var RecRef: RecordRef)
    begin
        RecRef.Truncate(true);
    end;

    [TryFunction]
    local procedure TryDeleteOwnTable(var RecRef: RecordRef)
    begin
        RecRef.DeleteAll(true);
    end;
}
```

## Recommended Implementation Pattern

1. Filter by `TableNo` first.
2. Try `Truncate(true)` in a `TryFunction`.
3. If truncate fails, try `DeleteAll(true)` in a `TryFunction`.
4. Set `IsHandled` and `Reseeded` only on success.
5. Define `Permissions` in the subscriber codeunit for your own table data.

## Notes

- DataMigratePro cannot predeclare permissions for future or external extension tables.
- This event is the intended extension point for partner-specific table handling.
- If your table is heavily constrained by referential logic, truncate may still fail; fallback delete handling is expected in that case.
