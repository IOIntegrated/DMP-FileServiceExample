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
        ResultJson: Text;
        ResultStatus: Text[100];
        ErrorCode: Text[100];
        ErrorMessage: Text[250];
    begin
        ListDirectoriesTx := FileSystemApi.SubmitListDirectories(pAlias, pRelativePath);
        ListFilesTx := FileSystemApi.SubmitListFiles(pAlias, pRelativePath);
        LastTransactionId := ListFilesTx;
        LastStatusText := StrSubstNo('Refresh started for alias %1 in path %2. Directory transaction: %3 | File transaction: %4', pAlias, pRelativePath, Format(ListDirectoriesTx), Format(ListFilesTx));

        if TryReadResultJsonForTransaction(ListFilesTx, ResultJson, ResultStatus, ErrorCode, ErrorMessage) then begin
            LastStatusText := StrSubstNo('Result for %1 loaded: %2', Format(ListFilesTx), ResultStatus);
            ParseFolderJson(ResultJson, pAlias, pRelativePath, pEntryTable);
            exit;
        end;

        if TryReadResultJsonForTransaction(ListDirectoriesTx, ResultJson, ResultStatus, ErrorCode, ErrorMessage) then begin
            LastStatusText := StrSubstNo('Result for %1 loaded: %2', Format(ListDirectoriesTx), ResultStatus);
            ParseFolderJson(ResultJson, pAlias, pRelativePath, pEntryTable);
            exit;
        end;

        ParseFolderJson(BuildSampleFolderJson(pAlias, pRelativePath), pAlias, pRelativePath, pEntryTable);
        LastStatusText := StrSubstNo('Using fallback sample data for alias %1 in path %2. No async result was available yet.', pAlias, pRelativePath);
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
        while (LastSlashPosition > 0) and (CopyStr(NormalizedPath, LastSlashPosition, 1) <> '/') do
            LastSlashPosition -= 1;

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

        while (StrLen(NormalizedPath) > 0) and (CopyStr(NormalizedPath, 1, 1) = '/') do
            NormalizedPath := CopyStr(NormalizedPath, 2);

        while (StrLen(NormalizedPath) > 0) and (CopyStr(NormalizedPath, StrLen(NormalizedPath), 1) = '/') do
            NormalizedPath := CopyStr(NormalizedPath, 1, StrLen(NormalizedPath) - 1);

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

    procedure TryGetFilePreview(pAlias: Text[50]; pRelativePath: Text[250]; pFileName: Text[250]; var pContentText: Text; var pSizeBytes: Integer; var pLastModified: DateTime; var pStatusText: Text[250]): Boolean
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
        ParsedSizeBytes: Integer;
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

        if TryReadResultJsonForTransaction(ReadTx, ResultJson, ResultStatus, ErrorCode, ErrorMessage) then begin
            if TryParseFileContentJson(ResultJson, ParsedContentText, ParsedSizeBytes, ParsedLastModified) then begin
                pContentText := ParsedContentText;
                pSizeBytes := ParsedSizeBytes;
                pLastModified := ParsedLastModified;
                pStatusText := ResultStatus;
                LastStatusText := StrSubstNo('File preview loaded for %1. Status: %2', FilePath, ResultStatus);
                exit(true);
            end;
        end;

        if TryReadResultJsonForTransaction(InfoTx, ResultJson, ResultStatus, ErrorCode, ErrorMessage) then begin
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

    local procedure TryParseFileInfoJson(pJsonText: Text; var pSizeBytes: Integer; var pLastModified: DateTime): Boolean
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
            pSizeBytes := SizeToken.AsValue().AsInteger();

        if DataObject.Get('lastModified', LastModifiedToken) then
            Evaluate(pLastModified, LastModifiedToken.AsValue().AsText());

        if (pLastModified = 0DT) and DataObject.Get('modifiedAt', LastModifiedToken) then
            Evaluate(pLastModified, LastModifiedToken.AsValue().AsText());

        exit((pSizeBytes <> 0) or (pLastModified <> 0DT));
    end;

    local procedure TryParseFileContentJson(pJsonText: Text; var pContentText: Text; var pSizeBytes: Integer; var pLastModified: DateTime): Boolean
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
            pSizeBytes := JsonToken.AsValue().AsInteger();

        if DataObject.Get('lastModified', JsonToken) then
            Evaluate(pLastModified, JsonToken.AsValue().AsText());

        if (pLastModified = 0DT) and DataObject.Get('modifiedAt', JsonToken) then
            Evaluate(pLastModified, JsonToken.AsValue().AsText());

        exit((pContentText <> '') or (pSizeBytes <> 0) or (pLastModified <> 0DT));
    end;

    local procedure TryReadResultJsonForTransaction(pTransactionId: Guid; var pResultJson: Text; var pStatusText: Text[100]; var pErrorCode: Text[100]; var pErrorMessage: Text[250]): Boolean
    var
        ResultRec: Record "DMP FS Result IOI";
    begin
        pResultJson := '';
        pStatusText := '';
        pErrorCode := '';
        pErrorMessage := '';

        if not ResultRec.Get(pTransactionId) then
            exit(false);

        pResultJson := ResultRec."Result Json";
        pStatusText := Format(ResultRec.Status);
        pErrorCode := ResultRec."Error Code";
        pErrorMessage := ResultRec.Message;

        exit(pResultJson <> '');
    end;

    local procedure BuildSampleFolderJson(pAlias: Text[50]; pRelativePath: Text[250]): Text
    var
        JsonText: Text;
    begin
        JsonText := '{"items":[{"entryType":"directory","name":"archive","fullPath":"' + pRelativePath + '/archive","sizeBytes":0,"lastModified":"2026-08-21T12:00:00Z"},{"entryType":"file","name":"sample.txt","fullPath":"' + pRelativePath + '/sample.txt","sizeBytes":128,"lastModified":"2026-08-21T12:00:00Z"}]}';
        if pAlias = '' then
            JsonText := '{"items":[{"entryType":"directory","name":"root","fullPath":"/","sizeBytes":0,"lastModified":"2026-08-21T12:00:00Z"}]}';
        exit(JsonText);
    end;

    local procedure ParseFolderJson(pJsonText: Text; pAlias: Text[50]; pRelativePath: Text[250]; var pEntryTable: Record "DMP FS Explorer Entry IOI")
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
        SizeBytes: Integer;
        LastModifiedText: Text;
        LastModifiedValue: DateTime;
        EntryTypeOption: Option Directory,File;
    begin
        pEntryTable.Reset();
        pEntryTable.DeleteAll();

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
                SizeBytes := JsonToken.AsValue().AsInteger();
            if ItemObject.Get('size', JsonToken) then
                if SizeBytes = 0 then
                    SizeBytes := JsonToken.AsValue().AsInteger();
            if ItemObject.Get('lastModified', JsonToken) then
                LastModifiedText := JsonToken.AsValue().AsText();
            if ItemObject.Get('modifiedAt', JsonToken) then
                if LastModifiedText = '' then
                    LastModifiedText := JsonToken.AsValue().AsText();

            if UpperCase(EntryTypeText) = 'DIRECTORY' then
                EntryTypeOption := EntryTypeOption::Directory
            else
                EntryTypeOption := EntryTypeOption::File;

            if LastModifiedText <> '' then
                Evaluate(LastModifiedValue, LastModifiedText)
            else
                LastModifiedValue := CurrentDateTime();

            if NameText = '' then
                NameText := CopyStr(FullPathText, StrLen(FullPathText) - StrPos(FullPathText, '/') + 2, 250);

            pEntryTable.SetEntry(pAlias, FullPathText, EntryTypeOption, NameText, SizeBytes, LastModifiedValue);
        end;
    end;

    procedure DeleteCurrentFile(pAlias: Text[50]; pRelativePath: Text[250]; pFileName: Text[250])
    var
        FileSystemApi: Codeunit "DMP File System API IOI";
        DeleteTx: Guid;
        FilePath: Text[250];
    begin
        FilePath := StrSubstNo('%1/%2', pRelativePath, pFileName);
        DeleteTx := FileSystemApi.SubmitDeleteFile(pAlias, FilePath);
        LastTransactionId := DeleteTx;
        LastStatusText := StrSubstNo('Delete request submitted for %1. Transaction: %2', FilePath, Format(DeleteTx));
        Message(LastStatusText);
    end;
}
