codeunit 92005 "DMP FS Explorer Mgmt. IOI"
{
    var
        LastStatusText: Text[250];
        LastTransactionId: Guid;

    procedure RefreshCurrentFolder(pAlias: Text[50]; pRelativePath: Text[250])
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        ListDirectoriesTx: Guid;
        ListFilesTx: Guid;
    begin
        ListDirectoriesTx := FileSystemApi.SubmitListDirectories(pAlias, pRelativePath);
        ListFilesTx := FileSystemApi.SubmitListFiles(pAlias, pRelativePath);
        LastTransactionId := ListFilesTx;
        LastStatusText := StrSubstNo('Refresh started for alias %1 in path %2. Directory transaction: %3 | File transaction: %4', pAlias, pRelativePath, Format(ListDirectoriesTx), Format(ListFilesTx));
        Message(LastStatusText);
    end;

    procedure RefreshCurrentFolder(pAlias: Text[50]; pRelativePath: Text[250]; var pEntryTable: Record "DMP FS Explorer Entry IOI")
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        ListDirectoriesTx: Guid;
        ListFilesTx: Guid;
        DirsJson: Text;
        FilesJson: Text;
        DirsStatus: Text[100];
        FilesStatus: Text[100];
        DirsErrorCode: Text[100];
        DirsErrorMessage: Text[250];
        FilesErrorCode: Text[100];
        FilesErrorMessage: Text[250];
        DirsLoaded: Boolean;
        FilesLoaded: Boolean;
        EntryTypeOption: Option Directory,File;
    begin
        ListDirectoriesTx := FileSystemApi.SubmitListDirectories(pAlias, pRelativePath);
        ListFilesTx := FileSystemApi.SubmitListFiles(pAlias, pRelativePath);
        LastTransactionId := ListFilesTx;

        DirsLoaded := WaitForResultJson(ListDirectoriesTx, DirsJson, DirsStatus, DirsErrorCode, DirsErrorMessage);
        FilesLoaded := WaitForResultJson(ListFilesTx, FilesJson, FilesStatus, FilesErrorCode, FilesErrorMessage);

        pEntryTable.Reset();
        pEntryTable.DeleteAll();

        if DirsLoaded then
            ParseFolderJson(DirsJson, pAlias, pRelativePath, EntryTypeOption::Directory, pEntryTable);
        if FilesLoaded then
            ParseFolderJson(FilesJson, pAlias, pRelativePath, EntryTypeOption::File, pEntryTable);

        if DirsLoaded and FilesLoaded then
            LastStatusText := CopyStr(StrSubstNo('Loaded %1 entries for alias %2 in path %3.', pEntryTable.Count(), pAlias, pRelativePath), 1, MaxStrLen(LastStatusText))
        else
            LastStatusText := CopyStr(StrSubstNo('Refresh incomplete. Loaded: %1. Dirs (%2): %3 %4 %5 | Files (%6): %7 %8 %9', pEntryTable.Count(), Format(ListDirectoriesTx, 0, 4), DirsStatus, DirsErrorCode, DirsErrorMessage, Format(ListFilesTx, 0, 4), FilesStatus, FilesErrorCode, FilesErrorMessage), 1, MaxStrLen(LastStatusText));
    end;

    procedure GetLastStatus(): Text[250]
    begin
        exit(LastStatusText);
    end;

    procedure GetLastTransactionId(): Guid
    begin
        exit(LastTransactionId);
    end;

    procedure RetryLastRequest()
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
    begin
        if IsNullGuid(LastTransactionId) then begin
            LastStatusText := 'No last request available for retry.';
            exit;
        end;

        FileSystemApi.RetryRequest(LastTransactionId);
        LastStatusText := StrSubstNo('Retry submitted for transaction %1.', Format(LastTransactionId));
    end;

    // Optional wait on top of the fire-and-forget submit procedures.
    procedure WaitForLastRequest(): Boolean
    var
        ResultJson: Text;
        StatusText: Text[100];
        ErrorCode: Text[100];
        ErrorMessage: Text[250];
    begin
        if IsNullGuid(LastTransactionId) then begin
            LastStatusText := 'No last request available to wait for.';
            exit(false);
        end;

        if WaitForResultJson(LastTransactionId, ResultJson, StatusText, ErrorCode, ErrorMessage) then begin
            LastStatusText := CopyStr(StrSubstNo('Request %1 completed. %2', Format(LastTransactionId), CopyStr(ResultJson, 1, 120)), 1, MaxStrLen(LastStatusText));
            exit(true);
        end;

        LastStatusText := CopyStr(StrSubstNo('Request %1 failed: %2 %3', Format(LastTransactionId), ErrorCode, ErrorMessage), 1, MaxStrLen(LastStatusText));
        exit(false);
    end;

    procedure CreateDirectory(pAlias: Text[50]; pRelativePath: Text[250]; pDirectoryName: Text[250])
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        TargetPath: Text[250];
        Tx: Guid;
    begin
        TargetPath := BuildRelativePath(pRelativePath, pDirectoryName);
        Tx := FileSystemApi.SubmitCreateDirectory(pAlias, TargetPath);
        LastTransactionId := Tx;
        LastStatusText := StrSubstNo('Create directory request submitted for %1. Transaction: %2', TargetPath, Format(Tx));
        Message(LastStatusText);
    end;

    procedure AppendCurrentFile(pAlias: Text[50]; pRelativePath: Text[250]; pFileName: Text[250]; pContent: Text)
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        FilePath: Text[250];
        Tx: Guid;
    begin
        FilePath := BuildRelativePath(pRelativePath, pFileName);
        Tx := FileSystemApi.SubmitAppendFile(pAlias, FilePath, pContent);
        LastTransactionId := Tx;
        LastStatusText := StrSubstNo('Append request submitted for %1. Transaction: %2', FilePath, Format(Tx));
        Message(LastStatusText);
    end;

    procedure DeleteDirectory(pAlias: Text[50]; pRelativePath: Text[250]; pRecursive: Boolean)
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        NormalizedPath: Text[250];
        Tx: Guid;
    begin
        NormalizedPath := NormalizeRelativePath(pRelativePath);
        Tx := FileSystemApi.SubmitDeleteDirectory(pAlias, NormalizedPath, pRecursive);
        LastTransactionId := Tx;
        LastStatusText := StrSubstNo('Delete directory request submitted for %1. Transaction: %2', NormalizedPath, Format(Tx));
        Message(LastStatusText);
    end;

    procedure CheckFileExists(pAlias: Text[50]; pRelativePath: Text[250]; pFileName: Text[250])
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        FilePath: Text[250];
        Tx: Guid;
    begin
        FilePath := BuildRelativePath(pRelativePath, pFileName);
        Tx := FileSystemApi.SubmitFileExists(pAlias, FilePath);
        LastTransactionId := Tx;
        LastStatusText := StrSubstNo('File existence request submitted for %1. Transaction: %2', FilePath, Format(Tx));
        Message(LastStatusText);
    end;

    procedure CheckDirectoryExists(pAlias: Text[50]; pRelativePath: Text[250])
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        NormalizedPath: Text[250];
        Tx: Guid;
    begin
        NormalizedPath := NormalizeRelativePath(pRelativePath);
        Tx := FileSystemApi.SubmitDirectoryExists(pAlias, NormalizedPath);
        LastTransactionId := Tx;
        LastStatusText := StrSubstNo('Directory existence request submitted for %1. Transaction: %2', NormalizedPath, Format(Tx));
        Message(LastStatusText);
    end;

    procedure ImportXmlFile(pAlias: Text[50]; pRelativePath: Text[250]; pFileName: Text[250])
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        FilePath: Text[250];
        Tx: Guid;
    begin
        FilePath := BuildRelativePath(pRelativePath, pFileName);
        Tx := FileSystemApi.SubmitImportXmlPortSource(pAlias, FilePath);
        LastTransactionId := Tx;
        LastStatusText := StrSubstNo('XML import request submitted for %1. Transaction: %2', FilePath, Format(Tx));
        Message(LastStatusText);
    end;

    procedure ExportXmlFile(pAlias: Text[50]; pRelativePath: Text[250]; pFileName: Text[250]; pXmlContent: Text)
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        FilePath: Text[250];
        Tx: Guid;
    begin
        FilePath := BuildRelativePath(pRelativePath, pFileName);
        Tx := FileSystemApi.SubmitExportXmlPortTarget(pAlias, FilePath, pXmlContent);
        LastTransactionId := Tx;
        LastStatusText := StrSubstNo('XML export request submitted for %1. Transaction: %2', FilePath, Format(Tx));
        Message(LastStatusText);
    end;

    procedure WriteCurrentFile(pAlias: Text[50]; pRelativePath: Text[250]; pFileName: Text[250]; pContent: Text)
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        FilePath: Text[250];
        Tx: Guid;
    begin
        FilePath := BuildRelativePath(pRelativePath, pFileName);
        Tx := FileSystemApi.SubmitWriteFile(pAlias, FilePath, pContent);
        LastTransactionId := Tx;
        LastStatusText := StrSubstNo('Write request submitted for %1. Transaction: %2', FilePath, Format(Tx));
        Message(LastStatusText);
    end;

    procedure CopyCurrentFile(pSourceAlias: Text[50]; pSourceRelativePath: Text[250]; pSourceFileName: Text[250]; pTargetAlias: Text[50]; pTargetRelativePath: Text[250]; pTargetFileName: Text[250])
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        SourcePath: Text[250];
        TargetPath: Text[250];
        Tx: Guid;
    begin
        SourcePath := BuildRelativePath(pSourceRelativePath, pSourceFileName);
        TargetPath := BuildRelativePath(pTargetRelativePath, pTargetFileName);
        Tx := FileSystemApi.SubmitCopyFile(pSourceAlias, SourcePath, pTargetAlias, TargetPath);
        LastTransactionId := Tx;
        LastStatusText := StrSubstNo('Copy request submitted: %1 -> %2. Transaction: %3', SourcePath, TargetPath, Format(Tx));
        Message(LastStatusText);
    end;

    procedure MoveCurrentFile(pSourceAlias: Text[50]; pSourceRelativePath: Text[250]; pSourceFileName: Text[250]; pTargetAlias: Text[50]; pTargetRelativePath: Text[250]; pTargetFileName: Text[250])
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        SourcePath: Text[250];
        TargetPath: Text[250];
        Tx: Guid;
    begin
        SourcePath := BuildRelativePath(pSourceRelativePath, pSourceFileName);
        TargetPath := BuildRelativePath(pTargetRelativePath, pTargetFileName);
        Tx := FileSystemApi.SubmitMoveFile(pSourceAlias, SourcePath, pTargetAlias, TargetPath);
        LastTransactionId := Tx;
        LastStatusText := StrSubstNo('Move request submitted: %1 -> %2. Transaction: %3', SourcePath, TargetPath, Format(Tx));
        Message(LastStatusText);
    end;

    procedure ArchiveCurrentFile(pSourceAlias: Text[50]; pSourceRelativePath: Text[250]; pSourceFileName: Text[250]; pArchiveAlias: Text[50]; pArchiveRelativePath: Text[250]; pArchiveFileName: Text[250])
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        SourcePath: Text[250];
        TargetPath: Text[250];
        Tx: Guid;
    begin
        SourcePath := BuildRelativePath(pSourceRelativePath, pSourceFileName);
        TargetPath := BuildRelativePath(pArchiveRelativePath, pArchiveFileName);
        Tx := FileSystemApi.SubmitArchiveFile(pSourceAlias, SourcePath, pArchiveAlias, TargetPath);
        LastTransactionId := Tx;
        LastStatusText := StrSubstNo('Archive request submitted: %1 -> %2. Transaction: %3', SourcePath, TargetPath, Format(Tx));
        Message(LastStatusText);
    end;

    procedure GetParentPath(pRelativePath: Text[250]): Text[250]
    var
        NormalizedPath: Text[250];
        LastSlashPosition: Integer;
    begin
        NormalizedPath := NormalizeRelativePath(pRelativePath);
        if NormalizedPath = '' then
            exit('');

        LastSlashPosition := StrLen(NormalizedPath);
        while LastSlashPosition > 0 do begin
            if CopyStr(NormalizedPath, LastSlashPosition, 1) = '/' then
                break;
            LastSlashPosition -= 1;
        end;

        if LastSlashPosition = 0 then
            exit('');

        exit(CopyStr(NormalizedPath, 1, LastSlashPosition - 1));
    end;

    local procedure BuildRelativePath(pBasePath: Text[250]; pName: Text[250]): Text[250]
    var
        NormalizedBasePath: Text[250];
        NormalizedName: Text[250];
    begin
        NormalizedBasePath := NormalizeRelativePath(pBasePath);
        NormalizedName := NormalizeRelativePath(pName);

        if StrPos(NormalizedName, '..') = 1 then
            Error('Relative paths cannot contain parent traversal.');

        if NormalizedBasePath = '' then
            exit(CopyStr(NormalizedName, 1, 250));

        if NormalizedName = '' then
            exit(NormalizedBasePath);

        exit(CopyStr(StrSubstNo('%1/%2', NormalizedBasePath, NormalizedName), 1, 250));
    end;

    local procedure NormalizeRelativePath(pRelativePath: Text[250]): Text[250]
    var
        NormalizedPath: Text[250];
    begin
        NormalizedPath := pRelativePath;
        while StrPos(NormalizedPath, '//') > 0 do
            NormalizedPath := DelChr(NormalizedPath, '=', '/');

        // AL does not short-circuit "and"; guard StrLen separately before indexing with CopyStr.
        while StrLen(NormalizedPath) > 0 do begin
            if CopyStr(NormalizedPath, 1, 1) <> '/' then
                break;
            NormalizedPath := CopyStr(NormalizedPath, 2);
        end;

        while StrLen(NormalizedPath) > 0 do begin
            if CopyStr(NormalizedPath, StrLen(NormalizedPath), 1) <> '/' then
                break;
            NormalizedPath := CopyStr(NormalizedPath, 1, StrLen(NormalizedPath) - 1);
        end;

        exit(CopyStr(NormalizedPath, 1, 250));
    end;

    procedure ReadCurrentFile(pAlias: Text[50]; pRelativePath: Text[250]; pFileName: Text[250])
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        ReadTx: Guid;
        InfoTx: Guid;
        FilePath: Text[250];
    begin
        FilePath := BuildRelativePath(pRelativePath, pFileName);
        ReadTx := FileSystemApi.SubmitReadFile(pAlias, FilePath);
        InfoTx := FileSystemApi.SubmitGetFileInfo(pAlias, FilePath);
        LastTransactionId := ReadTx;
        LastStatusText := StrSubstNo('Read request submitted for %1. Read transaction: %2 | Info transaction: %3', FilePath, Format(ReadTx), Format(InfoTx));
        Message(LastStatusText);
    end;

    procedure TryGetFilePreview(pAlias: Text[50]; pRelativePath: Text[250]; pFileName: Text[250]; var pContentText: Text; var pSizeBytes: BigInteger; var pLastModified: DateTime; var pStatusText: Text[250]): Boolean
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        ReadTx: Guid;
        InfoTx: Guid;
        FilePath: Text[250];
        ResultJson: Text;
        ResultStatus: Text[100];
        ErrorCode: Text[100];
        ErrorMessage: Text[250];
        ParsedContentText: Text;
        ParsedSizeBytes: BigInteger;
        ParsedLastModified: DateTime;
    begin
        pContentText := '';
        pSizeBytes := 0;
        pLastModified := 0DT;
        pStatusText := '';

        FilePath := BuildRelativePath(pRelativePath, pFileName);
        ReadTx := FileSystemApi.SubmitReadFile(pAlias, FilePath);
        InfoTx := FileSystemApi.SubmitGetFileInfo(pAlias, FilePath);
        LastTransactionId := ReadTx;
        LastStatusText := StrSubstNo('Read request submitted for %1. Read transaction: %2 | Info transaction: %3', FilePath, Format(ReadTx), Format(InfoTx));

        if WaitForResultJson(ReadTx, ResultJson, ResultStatus, ErrorCode, ErrorMessage) then begin
            if TryParseFileContentJson(ResultJson, ParsedContentText, ParsedSizeBytes, ParsedLastModified) then begin
                pContentText := ParsedContentText;
                pSizeBytes := ParsedSizeBytes;
                pLastModified := ParsedLastModified;
                pStatusText := ResultStatus;
                LastStatusText := StrSubstNo('File preview loaded for %1. Status: %2', FilePath, ResultStatus);
                exit(true);
            end;
        end;

        if WaitForResultJson(InfoTx, ResultJson, ResultStatus, ErrorCode, ErrorMessage) then begin
            if TryParseFileInfoJson(ResultJson, ParsedSizeBytes, ParsedLastModified) then begin
                pSizeBytes := ParsedSizeBytes;
                pLastModified := ParsedLastModified;
                pStatusText := ResultStatus;
                LastStatusText := StrSubstNo('File metadata loaded for %1. Status: %2', FilePath, ResultStatus);
                exit(true);
            end;
        end;

        exit(false);
    end;

    procedure TryGetFilePreviewFromResults(pAlias: Text[50]; pRelativePath: Text[250]; pFileName: Text[250]; var pContentText: Text; var pSizeBytes: BigInteger; var pLastModified: DateTime; var pStatusText: Text[250]): Boolean
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        FilePath: Text[250];
        ResultJson: Text;
        ParsedContentText: Text;
        ParsedSizeBytes: BigInteger;
        ParsedLastModified: DateTime;
        LatestTransactionId: Guid;
    begin
        pContentText := '';
        pSizeBytes := 0;
        pLastModified := 0DT;
        pStatusText := '';

        FilePath := BuildRelativePath(pRelativePath, pFileName);

        if not FindLatestCompletedResult(pAlias, FilePath, Enum::"DMP FS Command Type IOI"::ReadFile, LatestTransactionId) then begin
            pStatusText := CopyStr(StrSubstNo('No completed ReadFile result found for %1.', FilePath), 1, MaxStrLen(pStatusText));
            LastStatusText := pStatusText;
            exit(false);
        end;

        LastTransactionId := LatestTransactionId;
        ResultJson := FileSystemApi.GetResultPayload(LatestTransactionId);
        if TryParseFileContentJson(ResultJson, ParsedContentText, ParsedSizeBytes, ParsedLastModified) then begin
            pContentText := ParsedContentText;
            pSizeBytes := ParsedSizeBytes;
            pLastModified := ParsedLastModified;
            pStatusText := CopyStr(StrSubstNo('Loaded from result %1.', Format(LatestTransactionId, 0, 4)), 1, MaxStrLen(pStatusText));
            LastStatusText := pStatusText;
            exit(true);
        end;

        pStatusText := CopyStr(StrSubstNo('Result payload for %1 could not be parsed.', FilePath), 1, MaxStrLen(pStatusText));
        LastStatusText := pStatusText;
        exit(false);
    end;

    local procedure FindLatestCompletedResult(pAlias: Text[50]; pRelativePath: Text[250]; pCommand: Enum "DMP FS Command Type IOI"; var pTransactionId: Guid): Boolean
    var
        ResultRec: Record "DMP FS Result IOI";
        LatestCompletedAt: DateTime;
        HasResult: Boolean;
    begin
        Clear(pTransactionId);
        ResultRec.SetRange("Path Alias", CopyStr(pAlias, 1, MaxStrLen(ResultRec."Path Alias")));
        ResultRec.SetRange("Relative Path", pRelativePath);
        ResultRec.SetRange(Command, pCommand);
        ResultRec.SetRange(Status, ResultRec.Status::Completed);
        if ResultRec.FindSet() then
            repeat
                if (not HasResult) or (ResultRec."Completed At" >= LatestCompletedAt) then begin
                    LatestCompletedAt := ResultRec."Completed At";
                    pTransactionId := ResultRec."Transaction Id";
                    HasResult := true;
                end;
            until ResultRec.Next() = 0;
        exit(HasResult);
    end;

    local procedure TryParseFileInfoJson(pJsonText: Text; var pSizeBytes: BigInteger; var pLastModified: DateTime): Boolean
    var
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        DataObject: JsonObject;
        SizeToken: JsonToken;
        LastModifiedToken: JsonToken;
    begin
        pSizeBytes := 0;
        pLastModified := 0DT;

        if pJsonText = '' then
            exit(false);

        if not JsonObject.ReadFrom(pJsonText) then
            exit(false);

        DataObject := JsonObject;
        if JsonObject.Get('data', JsonToken) then
            if JsonToken.IsObject() then
                DataObject := JsonToken.AsObject();

        if DataObject.Get('sizeBytes', SizeToken) then
            Evaluate(pSizeBytes, SizeToken.AsValue().AsText());

        if DataObject.Get('lastModified', LastModifiedToken) then
            Evaluate(pLastModified, LastModifiedToken.AsValue().AsText());

        if (pLastModified = 0DT) and DataObject.Get('modifiedAt', LastModifiedToken) then
            Evaluate(pLastModified, LastModifiedToken.AsValue().AsText());

        exit((pSizeBytes <> 0) or (pLastModified <> 0DT));
    end;

    local procedure TryParseFileContentJson(pJsonText: Text; var pContentText: Text; var pSizeBytes: BigInteger; var pLastModified: DateTime): Boolean
    var
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        DataObject: JsonObject;
        ContentObject: JsonObject;
    begin
        pContentText := '';
        pSizeBytes := 0;
        pLastModified := 0DT;

        if pJsonText = '' then
            exit(false);

        if not JsonObject.ReadFrom(pJsonText) then
            exit(false);

        DataObject := JsonObject;
        if JsonObject.Get('data', JsonToken) then
            if JsonToken.IsObject() then
                DataObject := JsonToken.AsObject();

        if DataObject.Get('contentText', JsonToken) then
            pContentText := JsonToken.AsValue().AsText();

        if pContentText = '' then
            if DataObject.Get('content', JsonToken) then begin
                if JsonToken.IsObject() then begin
                    ContentObject := JsonToken.AsObject();
                    if ContentObject.Get('text', JsonToken) then
                        pContentText := JsonToken.AsValue().AsText();
                    if (pContentText = '') and ContentObject.Get('value', JsonToken) then
                        pContentText := JsonToken.AsValue().AsText();
                end;
                if (not JsonToken.IsObject()) and (pContentText = '') then
                    pContentText := JsonToken.AsValue().AsText();
            end;

        if DataObject.Get('sizeBytes', JsonToken) then
            Evaluate(pSizeBytes, JsonToken.AsValue().AsText());

        if DataObject.Get('lastModified', JsonToken) then
            Evaluate(pLastModified, JsonToken.AsValue().AsText());

        if (pLastModified = 0DT) and DataObject.Get('modifiedAt', JsonToken) then
            Evaluate(pLastModified, JsonToken.AsValue().AsText());

        exit((pContentText <> '') or (pSizeBytes <> 0) or (pLastModified <> 0DT));
    end;

    local procedure WaitForResultJson(pTransactionId: Guid; var pResultJson: Text; var pStatusText: Text[100]; var pErrorCode: Text[100]; var pErrorMessage: Text[250]): Boolean
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        ResultRec: Record "DMP FS Result IOI";
    begin
        pResultJson := '';
        pStatusText := '';
        pErrorCode := '';
        pErrorMessage := '';

        SelectLatestVersion();
        if not ResultRec.Get(pTransactionId) then begin
            pStatusText := 'Failed';
            pErrorCode := 'NO_RESULT';
            pErrorMessage := CopyStr(StrSubstNo('No result found for transaction %1.', pTransactionId), 1, MaxStrLen(pErrorMessage));
            exit(false);
        end;

        if not (ResultRec.Status in [ResultRec.Status::Completed, ResultRec.Status::Failed]) then begin
            pStatusText := 'Pending';
            pErrorCode := 'PENDING';
            pErrorMessage := CopyStr(StrSubstNo('Result for transaction %1 not finalized (status %2).', pTransactionId, Format(ResultRec.Status)), 1, MaxStrLen(pErrorMessage));
            exit(false);
        end;

        pResultJson := FileSystemApi.GetResultPayload(pTransactionId);
        pErrorCode := CopyStr(ResultRec."Error Code", 1, MaxStrLen(pErrorCode));
        pErrorMessage := CopyStr(ResultRec.Message, 1, MaxStrLen(pErrorMessage));

        if ResultRec.Status = ResultRec.Status::Completed then begin
            pStatusText := 'Completed';
            exit(true);
        end;

        pStatusText := 'Failed';
        exit(false);
    end;

    procedure ParseFolderJson(pJsonText: Text; pAlias: Text[50]; pRelativePath: Text[250]; pDefaultEntryType: Option Directory,File; var pEntryTable: Record "DMP FS Explorer Entry IOI")
    var
        JsonObject: JsonObject;
        JsonToken: JsonToken;
        JsonArray: JsonArray;
        DataObject: JsonObject;
        ItemObject: JsonObject;
        ItemToken: JsonToken;
        i: Integer;
        EntryTypeText: Text;
        NameText: Text;
        FullPathText: Text;
        SizeBytes: BigInteger;
        LastModifiedText: Text;
        LastModifiedValue: DateTime;
        EntryTypeOption: Option Directory,File;
    begin
        if pJsonText = '' then
            exit;

        if not JsonObject.ReadFrom(pJsonText) then
            exit;

        if JsonObject.Get('data', JsonToken) then begin
            DataObject := JsonToken.AsObject();
            if DataObject.Get('items', JsonToken) then begin
                JsonArray := JsonToken.AsArray();
            end else begin
                if DataObject.Get('entries', JsonToken) then begin
                    JsonArray := JsonToken.AsArray();
                end;
            end;
        end else begin
            if JsonObject.Get('items', JsonToken) then begin
                JsonArray := JsonToken.AsArray();
            end else begin
                if JsonObject.Get('entries', JsonToken) then begin
                    JsonArray := JsonToken.AsArray();
                end;
            end;
        end;

        if JsonArray.Count() = 0 then
            exit;

        for i := 0 to JsonArray.Count() - 1 do begin
            JsonArray.Get(i, ItemToken);
            ItemObject := ItemToken.AsObject();

            EntryTypeText := '';
            NameText := '';
            FullPathText := '';
            SizeBytes := 0;
            LastModifiedText := '';

            if ItemObject.Get('entryType', JsonToken) then
                EntryTypeText := JsonToken.AsValue().AsText();
            if ItemObject.Get('type', JsonToken) then
                if EntryTypeText = '' then
                    EntryTypeText := JsonToken.AsValue().AsText();
            if ItemObject.Get('name', JsonToken) then
                NameText := JsonToken.AsValue().AsText();
            if ItemObject.Get('fullPath', JsonToken) then
                FullPathText := JsonToken.AsValue().AsText();
            if ItemObject.Get('path', JsonToken) then
                if FullPathText = '' then
                    FullPathText := JsonToken.AsValue().AsText();
            if ItemObject.Get('sizeBytes', JsonToken) then
                Evaluate(SizeBytes, JsonToken.AsValue().AsText());
            if ItemObject.Get('size', JsonToken) then
                if SizeBytes = 0 then
                    Evaluate(SizeBytes, JsonToken.AsValue().AsText());
            if ItemObject.Get('lastModified', JsonToken) then
                LastModifiedText := JsonToken.AsValue().AsText();
            if ItemObject.Get('modifiedAt', JsonToken) then
                if LastModifiedText = '' then
                    LastModifiedText := JsonToken.AsValue().AsText();
            if ItemObject.Get('lastWriteAtUtc', JsonToken) then
                if LastModifiedText = '' then
                    LastModifiedText := JsonToken.AsValue().AsText();
            if ItemObject.Get('createdAtUtc', JsonToken) then
                if LastModifiedText = '' then
                    LastModifiedText := JsonToken.AsValue().AsText();

            case UpperCase(EntryTypeText) of
                'DIRECTORY':
                    EntryTypeOption := EntryTypeOption::Directory;
                'FILE':
                    EntryTypeOption := EntryTypeOption::File;
                else
                    EntryTypeOption := pDefaultEntryType;
            end;

            LastModifiedValue := 0DT;
            if LastModifiedText <> '' then
                if not Evaluate(LastModifiedValue, LastModifiedText, 9) then
                    if not Evaluate(LastModifiedValue, LastModifiedText) then
                        LastModifiedValue := 0DT;

            if NameText = '' then
                NameText := CopyStr(FullPathText, StrLen(FullPathText) - StrPos(FullPathText, '/') + 2, 250);

            // PK is Name; skip duplicates when merging directory and file listings
            if not pEntryTable.Get(CopyStr(NameText, 1, MaxStrLen(pEntryTable.Name))) then
                pEntryTable.SetEntry(pAlias, CopyStr(FullPathText, 1, 250), EntryTypeOption, CopyStr(NameText, 1, 250), SizeBytes, LastModifiedValue);
        end;
    end;

    procedure DeleteCurrentFile(pAlias: Text[50]; pRelativePath: Text[250]; pFileName: Text[250])
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        DeleteTx: Guid;
        FilePath: Text[250];
    begin
        FilePath := BuildRelativePath(pRelativePath, pFileName);
        DeleteTx := FileSystemApi.SubmitDeleteFile(pAlias, FilePath);
        LastTransactionId := DeleteTx;
        LastStatusText := StrSubstNo('Delete request submitted for %1. Transaction: %2', FilePath, Format(DeleteTx));
        Message(LastStatusText);
    end;
}
