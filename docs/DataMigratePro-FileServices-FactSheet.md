# DataMigratePro File Services (Enduser)

## Purpose

The File Services function enables controlled execution of file and directory operations through DataMigratePro.

Typical use cases:
- Exchange of XML or JSON files between processes
- Preparation and post-processing of migration files
- Monitoring of file actions including status and errors

## Prerequisites

- The DataMigratePro listener runs in Service Bus mode (`-t listen`).
- File system aliases are configured in `settings.json`.
- The target system has the required permissions for the alias folders.
- In Business Central, the extension with the file system pages is active.

## Available Operations

Supported actions:
- `ListFiles`
- `ListDirectories`
- `CreateDirectory`
- `DeleteDirectory`
- `DirectoryExists`
- `ReadFile`
- `WriteFile`
- `AppendFile`
- `DeleteFile`
- `MoveFile`
- `CopyFile`
- `FileExists`
- `GetFileInfo`
- `ArchiveFile`
- `ImportXmlPortSource`
- `ExportXmlPortTarget`

## Using Business Central

### 1. Monitor Requests

- Open the **DMP FS Request List IOI** page.
- Relevant fields:
  - `Transaction Id`
  - `Command`
  - `Status`
  - `Path Alias`
  - `Relative Path`
  - `Payload Length`
  - `Payload Truncated`

Status in requests:
- `Created`: Request was created.
- `Sent`: Request was handed over to the listener.
- `Completed`: Action completed successfully.
- `Failed`: Action ended with an error.

### 2. Check Results

- Open the **DMP FS Result List IOI** page.
- Relevant fields:
  - `Status`
  - `Error Code`
  - `Message`
  - `Result Length`
  - `Result Truncated`

Status in results:
- `Accepted`: Request was accepted.
- `Running`: Processing is in progress or is an intermediate status.
- `Completed`: Result was successful.
- `Failed`: Processing error.

### 3. Retry Failed Requests

- Select one or more failed entries in **DMP FS Request List IOI**.
- Run the **Retry Selected Failed Requests** action.
- Non-failed entries are skipped automatically.

### 4. Open Request from Result

- In **DMP FS Result List IOI**, use the **Open Request** action to jump directly to the related request.

## End-user Example (XML Export)

Objective: Write an XML file to a target folder.

1. The business logic starts `ExportXmlPortTarget`.
2. The request is sent to the listener with `Path Alias` + `Relative Path`.
3. The listener writes the file to the alias folder.
4. Feedback appears in the result list with `Completed` or `Failed`.
5. For `Failed`: select the request and send it again with retry.

## Common Errors and Meaning

- `PATH_NOT_FOUND`: Alias or path does not exist.
- `FILE_NOT_FOUND`: File was not found.
- `ACCESS_DENIED`: Access not permitted (permission or policy).
- `INVALID_OPERATION`: Invalid state, e.g. unconfigured alias.
- `IO_ERROR`: Technical file I/O error.
- `PROCESSING_ERROR`: General processing error.

## End-user Best Practices

- Use only approved alias paths.
- For large content, watch for `Payload Truncated`/`Result Truncated`.
- Before retrying, check `Message` and `Error Code` first.
- In production scenarios, perform file operations with clear naming conventions (e.g. a timestamp in the file name).
