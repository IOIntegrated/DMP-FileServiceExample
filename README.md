# DMP-FileServiceExample
Example-Implementation for FileService Actions started in BC

## Permissions

Assign the `DMP FS EXPLORER IOI` permission set to users who need the explorer.
It grants access to the extension's tables, pages, and codeunits, including
read, insert, modify, and delete permissions for file service aliases.
Users also need the appropriate permissions for the DataMigrate Pro dependency.

## Relay configuration

The explorer uses client configuration `DEFAULT` through DataMigrate Pro's
`Relay Sender IOI`. Set its Function Url, Function Key and Connection Id in the
current company. No configuration with a blank Code is required.

A manually bound `OnBeforeSendCommand` subscriber handles only explorer calls;
other callers of the DataMigrate Pro API are unchanged. The adapter stores and
commits the request before sending so listener callbacks can update it.
Payloads marked as truncated by the API are rejected before sending, rather
than sending incomplete file content. The API's `OnAfterSendCommand` event is
not raised for handled requests.
