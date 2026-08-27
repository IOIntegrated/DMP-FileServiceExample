page 92002 "DMP FS Explorer IOI"
{
    PageType = Worksheet;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "DMP FS Explorer Entry IOI";
    Caption = 'DMP File System Explorer';
    InsertAllowed = false;
    DeleteAllowed = false;
    ModifyAllowed = false;

    layout
    {
        area(Content)
        {
            group(Explorer)
            {
                field(CurrentAlias; SelectedAlias)
                {
                    ApplicationArea = All;
                    Caption = 'Alias';

                    trigger OnLookup(var Text: Text): Boolean
                    begin
                        exit(LookupAlias());
                    end;

                    trigger OnValidate()
                    begin
                        RefreshCurrentFolder();
                    end;
                }
                field(CurrentPath; CurrentPathText)
                {
                    ApplicationArea = All;
                    Caption = 'Current Path';
                    Editable = false;
                }
                field(CurrentStatus; LastStatusText)
                {
                    ApplicationArea = All;
                    Caption = 'Status';
                    Editable = false;
                }
                field(LastTransaction; LastTransactionIdText)
                {
                    ApplicationArea = All;
                    Caption = 'Last Transaction';
                    Editable = false;
                }
            }

            repeater(Items)
            {
                Editable = false;

                field("Entry Type"; Rec."Entry Type")
                {
                    ApplicationArea = All;
                }
                field(Name; Rec.Name)
                {
                    ApplicationArea = All;
                }
                field("Full Path"; Rec."Full Path")
                {
                    ApplicationArea = All;
                }
                field("Size Bytes"; Rec."Size Bytes")
                {
                    ApplicationArea = All;
                }
                field("Last Modified"; Rec."Last Modified")
                {
                    ApplicationArea = All;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(SelectAlias)
            {
                ApplicationArea = All;
                Caption = 'Select Alias';
                Image = SelectEntries;

                trigger OnAction()
                begin
                    if LookupAlias() then
                        RefreshCurrentFolder();
                end;
            }
            action(ManageAliases)
            {
                ApplicationArea = All;
                Caption = 'Manage Aliases';
                Image = Setup;

                trigger OnAction()
                var
                    FSAlias: Record "DMP FS Alias IOI";
                    AliasesPage: Page "DMP FS Aliases IOI";
                begin
                    if FSAlias.Get(SelectedAlias) then
                        AliasesPage.SetRecord(FSAlias);
                    AliasesPage.RunModal();
                end;
            }
            action(UseImportAlias)
            {
                ApplicationArea = All;
                Caption = 'IMPORT';
                trigger OnAction()
                begin
                    SelectedAlias := 'IMPORT';
                    RefreshCurrentFolder();
                end;
            }
            action(UseArchiveAlias)
            {
                ApplicationArea = All;
                Caption = 'ARCHIVE';
                trigger OnAction()
                begin
                    SelectedAlias := 'ARCHIVE';
                    RefreshCurrentFolder();
                end;
            }
            action(UseExportAlias)
            {
                ApplicationArea = All;
                Caption = 'EXPORT';
                trigger OnAction()
                begin
                    SelectedAlias := 'EXPORT';
                    RefreshCurrentFolder();
                end;
            }
            action(Refresh)
            {
                ApplicationArea = All;
                Caption = 'Refresh';
                Image = Refresh;

                trigger OnAction()
                begin
                    RefreshCurrentFolder();
                end;
            }
            action(LoadFromResults)
            {
                ApplicationArea = All;
                Caption = 'Load From Results';
                Image = View;

                trigger OnAction()
                begin
                    LoadCurrentFolderFromResults();
                end;
            }
            action(CreateDirectory)
            {
                ApplicationArea = All;
                Caption = 'Create Directory';

                trigger OnAction()
                begin
                    RequireAlias();
                    DMPFSExplorerMgmt.CreateDirectory(SelectedAlias, CurrentPathText, 'NewFolder');
                    if not DMPFSExplorerMgmt.WaitForLastRequest() then
                        Message(DMPFSExplorerMgmt.GetLastStatus());
                    RefreshCurrentFolder();
                end;
            }
            action(GoToParent)
            {
                ApplicationArea = All;
                Caption = 'Go to Parent';
                Image = Navigate;

                trigger OnAction()
                begin
                    RequireAlias();
                    CurrentPathText := DMPFSExplorerMgmt.GetParentPath(CurrentPathText);
                    RefreshCurrentFolder();
                end;
            }
            action(OpenFolder)
            {
                ApplicationArea = All;
                Caption = 'Open Folder';
                Image = Navigate;

                trigger OnAction()
                begin
                    RequireAlias();
                    if Rec."Entry Type" = Rec."Entry Type"::Directory then begin
                        if CurrentPathText = '' then
                            CurrentPathText := Rec.Name
                        else
                            CurrentPathText := StrSubstNo('%1/%2', CurrentPathText, Rec.Name);

                        RefreshCurrentFolder();
                    end;
                end;
            }
            action(ReadFile)
            {
                ApplicationArea = All;
                Caption = 'Read File';
                Image = Document;

                trigger OnAction()
                begin
                    RequireAlias();
                    if Rec."Entry Type" = Rec."Entry Type"::File then begin
                        DMPFSExplorerMgmt.ReadCurrentFile(SelectedAlias, CurrentPathText, Rec.Name);
                        DMPFSExplorerMgmt.WaitForLastRequest();
                        LastStatusText := DMPFSExplorerMgmt.GetLastStatus();
                        LastTransactionIdText := Format(DMPFSExplorerMgmt.GetLastTransactionId());
                    end;
                end;
            }
            action(OpenContentViewer)
            {
                ApplicationArea = All;
                Caption = 'Open Content Viewer';

                trigger OnAction()
                var
                    ViewerPage: Page "DMP FS Content Viewer IOI";
                    ContentText: Text;
                    SizeBytes: BigInteger;
                    LastModified: DateTime;
                    StatusText: Text[250];
                begin
                    RequireAlias();
                    if Rec."Entry Type" = Rec."Entry Type"::File then begin
                        if DMPFSExplorerMgmt.TryGetFilePreview(SelectedAlias, CurrentPathText, Rec.Name, ContentText, SizeBytes, LastModified, StatusText) then begin
                            ViewerPage.SetMetadata(SelectedAlias, CurrentPathText, Rec.Name, SizeBytes, LastModified, ContentText);
                        end else begin
                            ViewerPage.SetFile(SelectedAlias, CurrentPathText, Rec.Name, 'Preview content for ' + Rec.Name + ' in alias ' + SelectedAlias + '.');
                        end;
                        ViewerPage.Run();
                    end;
                end;
            }
            action(WriteFile)
            {
                ApplicationArea = All;
                Caption = 'Write File';
                Image = ExportFile;

                trigger OnAction()
                begin
                    RequireAlias();
                    DMPFSExplorerMgmt.WriteCurrentFile(SelectedAlias, CurrentPathText, 'sample.txt', 'Demo content from DMP File Explorer');
                    if not DMPFSExplorerMgmt.WaitForLastRequest() then
                        Message(DMPFSExplorerMgmt.GetLastStatus());
                    RefreshCurrentFolder();
                end;
            }
            action(AppendFile)
            {
                ApplicationArea = All;
                Caption = 'Append File';
                Image = Add;

                trigger OnAction()
                begin
                    RequireAlias();
                    DMPFSExplorerMgmt.AppendCurrentFile(SelectedAlias, CurrentPathText, 'sample.txt', 'Appended data');
                    if not DMPFSExplorerMgmt.WaitForLastRequest() then
                        Message(DMPFSExplorerMgmt.GetLastStatus());
                    RefreshCurrentFolder();
                end;
            }
            action(CopyFile)
            {
                ApplicationArea = All;
                Caption = 'Copy File';
                Image = Copy;

                trigger OnAction()
                begin
                    RequireAlias();
                    DMPFSExplorerMgmt.CopyCurrentFile(SelectedAlias, CurrentPathText, 'sample.txt', SelectedAlias, CurrentPathText, 'sample-copy.txt');
                    if not DMPFSExplorerMgmt.WaitForLastRequest() then
                        Message(DMPFSExplorerMgmt.GetLastStatus());
                    RefreshCurrentFolder();
                end;
            }
            action(MoveFile)
            {
                ApplicationArea = All;
                Caption = 'Move File';
                Image = MoveDown;

                trigger OnAction()
                begin
                    RequireAlias();
                    DMPFSExplorerMgmt.MoveCurrentFile(SelectedAlias, CurrentPathText, 'sample-copy.txt', SelectedAlias, CurrentPathText, 'sample-moved.txt');
                    if not DMPFSExplorerMgmt.WaitForLastRequest() then
                        Message(DMPFSExplorerMgmt.GetLastStatus());
                    RefreshCurrentFolder();
                end;
            }
            action(ArchiveFile)
            {
                ApplicationArea = All;
                Caption = 'Archive File';
                Image = Archive;

                trigger OnAction()
                begin
                    RequireAlias();
                    DMPFSExplorerMgmt.ArchiveCurrentFile(SelectedAlias, CurrentPathText, 'sample.txt', SelectedAlias, StrSubstNo('%1/archive', CurrentPathText), 'sample-archived.txt');
                    if not DMPFSExplorerMgmt.WaitForLastRequest() then
                        Message(DMPFSExplorerMgmt.GetLastStatus());
                    RefreshCurrentFolder();
                end;
            }
            action(DeleteFile)
            {
                ApplicationArea = All;
                Caption = 'Delete File';
                Image = Delete;

                trigger OnAction()
                begin
                    RequireAlias();
                    if Rec."Entry Type" = Rec."Entry Type"::File then begin
                        DMPFSExplorerMgmt.DeleteCurrentFile(SelectedAlias, CurrentPathText, Rec.Name);
                        if not DMPFSExplorerMgmt.WaitForLastRequest() then
                            Message(DMPFSExplorerMgmt.GetLastStatus());
                    end;
                    RefreshCurrentFolder();
                end;
            }
            action(DeleteDirectory)
            {
                ApplicationArea = All;
                Caption = 'Delete Directory';
                Image = Delete;

                trigger OnAction()
                begin
                    RequireAlias();
                    if Rec."Entry Type" = Rec."Entry Type"::Directory then begin
                        DMPFSExplorerMgmt.DeleteDirectory(SelectedAlias, StrSubstNo('%1/%2', CurrentPathText, Rec.Name), false);
                        if not DMPFSExplorerMgmt.WaitForLastRequest() then
                            Message(DMPFSExplorerMgmt.GetLastStatus());
                    end;
                    RefreshCurrentFolder();
                end;
            }
            action(CheckFileExists)
            {
                ApplicationArea = All;
                Caption = 'Check File Exists';

                trigger OnAction()
                begin
                    RequireAlias();
                    if Rec."Entry Type" = Rec."Entry Type"::File then begin
                        DMPFSExplorerMgmt.CheckFileExists(SelectedAlias, CurrentPathText, Rec.Name);
                        DMPFSExplorerMgmt.WaitForLastRequest();
                    end;
                    LastStatusText := DMPFSExplorerMgmt.GetLastStatus();
                    LastTransactionIdText := Format(DMPFSExplorerMgmt.GetLastTransactionId());
                end;
            }
            action(CheckDirectoryExists)
            {
                ApplicationArea = All;
                Caption = 'Check Directory Exists';

                trigger OnAction()
                begin
                    RequireAlias();
                    DMPFSExplorerMgmt.CheckDirectoryExists(SelectedAlias, CurrentPathText);
                    DMPFSExplorerMgmt.WaitForLastRequest();
                    LastStatusText := DMPFSExplorerMgmt.GetLastStatus();
                    LastTransactionIdText := Format(DMPFSExplorerMgmt.GetLastTransactionId());
                end;
            }
            action(RetryLastRequest)
            {
                ApplicationArea = All;
                Caption = 'Retry Last Request';
                Image = Refresh;

                trigger OnAction()
                begin
                    DMPFSExplorerMgmt.RetryLastRequest();
                    LastStatusText := DMPFSExplorerMgmt.GetLastStatus();
                    LastTransactionIdText := Format(DMPFSExplorerMgmt.GetLastTransactionId());
                end;
            }
            action(ImportXml)
            {
                ApplicationArea = All;
                Caption = 'Import XML';

                trigger OnAction()
                begin
                    RequireAlias();
                    if Rec."Entry Type" = Rec."Entry Type"::File then begin
                        DMPFSExplorerMgmt.ImportXmlFile(SelectedAlias, CurrentPathText, Rec.Name);
                        if not DMPFSExplorerMgmt.WaitForLastRequest() then
                            Message(DMPFSExplorerMgmt.GetLastStatus());
                    end;
                    RefreshCurrentFolder();
                end;
            }
            action(ExportXml)
            {
                ApplicationArea = All;
                Caption = 'Export XML';

                trigger OnAction()
                begin
                    RequireAlias();
                    DMPFSExplorerMgmt.ExportXmlFile(SelectedAlias, CurrentPathText, 'sample.xml', '<root />');
                    if not DMPFSExplorerMgmt.WaitForLastRequest() then
                        Message(DMPFSExplorerMgmt.GetLastStatus());
                    RefreshCurrentFolder();
                end;
            }
        }
    }

    var
        SelectedAlias: Text[50];
        InitialAlias: Code[50];
        CurrentPathText: Text[250];
        LastStatusText: Text[250];
        LastTransactionIdText: Text[100];
        DMPFSExplorerMgmt: Codeunit "DMP FS Explorer Mgmt. IOI";
        NoAliasSelectedErr: Label 'Please select an alias first.';

    local procedure RequireAlias()
    var
        FSAlias: Record "DMP FS Alias IOI";
    begin
        SelectedAlias := CopyStr(UpperCase(SelectedAlias), 1, MaxStrLen(SelectedAlias));
        if (SelectedAlias = '') or (not FSAlias.Get(SelectedAlias)) then
            Error(NoAliasSelectedErr);
    end;

    local procedure RefreshCurrentFolder()
    begin
        if not EnsureValidAlias() then
            exit;

        DMPFSExplorerMgmt.RefreshCurrentFolder(SelectedAlias, CurrentPathText, Rec);
        LastStatusText := DMPFSExplorerMgmt.GetLastStatus();
        LastTransactionIdText := Format(DMPFSExplorerMgmt.GetLastTransactionId(), 0, 4);
        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    local procedure LoadCurrentFolderFromResults()
    var
        DirsJson: Text;
        FilesJson: Text;
        DirsErrorCode: Text;
        DirsErrorMessage: Text;
        FilesErrorCode: Text;
        FilesErrorMessage: Text;
        DirsLoaded: Boolean;
        FilesLoaded: Boolean;
        EntryTypeOption: Option Directory,File;
    begin
        if not EnsureValidAlias() then
            exit;

        Rec.Reset();
        Rec.DeleteAll();

        FilesLoaded := ReadLatestResultPayload(
            Enum::"DMP FS Command Type IOI"::ListFiles,
            FilesJson,
            FilesErrorCode,
            FilesErrorMessage,
            LastTransactionIdText);
        if FilesLoaded then
            DMPFSExplorerMgmt.ParseFolderJson(FilesJson, SelectedAlias, CurrentPathText, EntryTypeOption::File, Rec);

        DirsLoaded := ReadLatestResultPayload(
            Enum::"DMP FS Command Type IOI"::ListDirectories,
            DirsJson,
            DirsErrorCode,
            DirsErrorMessage,
            LastTransactionIdText);
        if DirsLoaded then
            DMPFSExplorerMgmt.ParseFolderJson(DirsJson, SelectedAlias, CurrentPathText, EntryTypeOption::Directory, Rec);

        if DirsLoaded and FilesLoaded then
            LastStatusText := CopyStr(StrSubstNo('Loaded %1 entries.', Rec.Count()), 1, MaxStrLen(LastStatusText))
        else
            LastStatusText := CopyStr(StrSubstNo('Refresh incomplete. Loaded: %1. Files: %2 %3 | Dirs: %4 %5', Rec.Count(), FilesErrorCode, FilesErrorMessage, DirsErrorCode, DirsErrorMessage), 1, MaxStrLen(LastStatusText));
        if Rec.FindFirst() then;
        CurrPage.Update(false);
    end;

    local procedure ReadLatestResultPayload(pCommand: Enum "DMP FS Command Type IOI"; var pPayload: Text; var pErrorCode: Text[100]; var pErrorMessage: Text[250]; var pTransactionIdText: Text[100]): Boolean
    var
        ResultRec: Record "DMP FS Result IOI";
        PayloadInStream: InStream;
        LineText: Text;
        LatestCompletedAt: DateTime;
        HasResult: Boolean;
    begin
        pPayload := '';
        pErrorCode := '';
        pErrorMessage := '';
        pTransactionIdText := '';

        ResultRec.SetRange("Path Alias", CopyStr(SelectedAlias, 1, MaxStrLen(ResultRec."Path Alias")));
        ResultRec.SetRange("Relative Path", CurrentPathText);
        ResultRec.SetRange(Command, pCommand);
        ResultRec.SetRange(Status, ResultRec.Status::Completed);

        if ResultRec.FindSet() then
            repeat
                if (not HasResult) or (ResultRec."Completed At" > LatestCompletedAt) then begin
                    LatestCompletedAt := ResultRec."Completed At";
                    pTransactionIdText := Format(ResultRec."Transaction Id", 0, 4);
                    HasResult := true;
                end;
            until ResultRec.Next() = 0;

        if not HasResult then begin
            pErrorCode := 'NO_RESULT';
            pErrorMessage := StrSubstNo('No completed %1 result found in DMP FS Result.', Format(pCommand));
            exit(false);
        end;

        ResultRec.Get(SelectLatestResultTransaction(ResultRec, pCommand));
        ResultRec.CalcFields("Result Payload");
        if ResultRec."Result Payload".HasValue() then begin
            ResultRec."Result Payload".CreateInStream(PayloadInStream, TextEncoding::UTF8);
            while not PayloadInStream.EOS() do begin
                PayloadInStream.ReadText(LineText);
                pPayload += LineText;
            end;
        end else
            pPayload := ResultRec."Result Json";

        if pPayload = '' then begin
            pErrorCode := 'EMPTY_PAYLOAD';
            pErrorMessage := 'The completed result has no payload.';
            exit(false);
        end;

        exit(true);
    end;

    local procedure SelectLatestResultTransaction(var pResultRec: Record "DMP FS Result IOI"; pCommand: Enum "DMP FS Command Type IOI"): Guid
    var
        CandidateRec: Record "DMP FS Result IOI";
        LatestCompletedAt: DateTime;
        TransactionId: Guid;
    begin
        CandidateRec.SetRange("Path Alias", CopyStr(SelectedAlias, 1, MaxStrLen(CandidateRec."Path Alias")));
        CandidateRec.SetRange("Relative Path", CurrentPathText);
        CandidateRec.SetRange(Command, pCommand);
        CandidateRec.SetRange(Status, CandidateRec.Status::Completed);
        if CandidateRec.FindSet() then
            repeat
                if CandidateRec."Completed At" >= LatestCompletedAt then begin
                    LatestCompletedAt := CandidateRec."Completed At";
                    TransactionId := CandidateRec."Transaction Id";
                end;
            until CandidateRec.Next() = 0;
        exit(TransactionId);
    end;

    local procedure EnsureValidAlias(): Boolean
    var
        FSAlias: Record "DMP FS Alias IOI";
    begin
        SelectedAlias := CopyStr(UpperCase(SelectedAlias), 1, MaxStrLen(SelectedAlias));
        if SelectedAlias <> '' then
            if FSAlias.Get(SelectedAlias) then
                exit(true);

        LastStatusText := 'No valid alias selected. Please configure and select an alias.';
        exit(false);
    end;

    local procedure LookupAlias(): Boolean
    var
        FSAlias: Record "DMP FS Alias IOI";
        AliasesPage: Page "DMP FS Aliases IOI";
    begin
        if FSAlias.Get(SelectedAlias) then;
        AliasesPage.SetRecord(FSAlias);
        AliasesPage.LookupMode(true);
        if AliasesPage.RunModal() = Action::LookupOK then begin
            AliasesPage.GetRecord(FSAlias);
            SelectedAlias := FSAlias.Alias;
            CurrentPathText := FSAlias."Default Path";
            exit(true);
        end;
        exit(false);
    end;

    procedure SetInitialAlias(pAlias: Code[50])
    begin
        InitialAlias := pAlias;
    end;

    trigger OnOpenPage()
    var
        FSAlias: Record "DMP FS Alias IOI";
    begin
        FSAlias.EnsureDefaults();
        if (InitialAlias <> '') and FSAlias.Get(InitialAlias) then begin
            SelectedAlias := FSAlias.Alias;
            CurrentPathText := FSAlias."Default Path";
            RefreshCurrentFolder();
        end else
            LastStatusText := 'No alias selected. Please select an alias to start.';
    end;
}
