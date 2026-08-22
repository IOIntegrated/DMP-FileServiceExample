page 92002 "DMP FS Explorer IOI"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "DMP FS Explorer Entry IOI";
    Caption = 'DMP File System Explorer';

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
            action(CreateDirectory)
            {
                ApplicationArea = All;
                Caption = 'Create Directory';

                trigger OnAction()
                begin
                    DMPFSExplorerMgmt.CreateDirectory(SelectedAlias, CurrentPathText, 'NewFolder');
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
                    if Rec."Entry Type" = Rec."Entry Type"::File then begin
                        DMPFSExplorerMgmt.ReadCurrentFile(SelectedAlias, CurrentPathText, Rec.Name);
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
                    SizeBytes: Integer;
                    LastModified: DateTime;
                    StatusText: Text[250];
                begin
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
                    DMPFSExplorerMgmt.WriteCurrentFile(SelectedAlias, CurrentPathText, 'sample.txt', 'Demo content from DMP File Explorer');
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
                    DMPFSExplorerMgmt.AppendCurrentFile(SelectedAlias, CurrentPathText, 'sample.txt', 'Appended data');
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
                    DMPFSExplorerMgmt.CopyCurrentFile(SelectedAlias, CurrentPathText, 'sample.txt', SelectedAlias, CurrentPathText, 'sample-copy.txt');
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
                    DMPFSExplorerMgmt.MoveCurrentFile(SelectedAlias, CurrentPathText, 'sample-copy.txt', SelectedAlias, CurrentPathText, 'sample-moved.txt');
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
                    DMPFSExplorerMgmt.ArchiveCurrentFile(SelectedAlias, CurrentPathText, 'sample.txt', SelectedAlias, StrSubstNo('%1/archive', CurrentPathText), 'sample-archived.txt');
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
                    if Rec."Entry Type" = Rec."Entry Type"::File then
                        DMPFSExplorerMgmt.DeleteCurrentFile(SelectedAlias, CurrentPathText, Rec.Name);
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
                    if Rec."Entry Type" = Rec."Entry Type"::Directory then
                        DMPFSExplorerMgmt.DeleteDirectory(SelectedAlias, StrSubstNo('%1/%2', CurrentPathText, Rec.Name), false);
                    RefreshCurrentFolder();
                end;
            }
            action(CheckFileExists)
            {
                ApplicationArea = All;
                Caption = 'Check File Exists';

                trigger OnAction()
                begin
                    if Rec."Entry Type" = Rec."Entry Type"::File then
                        DMPFSExplorerMgmt.CheckFileExists(SelectedAlias, CurrentPathText, Rec.Name);
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
                    DMPFSExplorerMgmt.CheckDirectoryExists(SelectedAlias, CurrentPathText);
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
                    if Rec."Entry Type" = Rec."Entry Type"::File then
                        DMPFSExplorerMgmt.ImportXmlFile(SelectedAlias, CurrentPathText, Rec.Name);
                    RefreshCurrentFolder();
                end;
            }
            action(ExportXml)
            {
                ApplicationArea = All;
                Caption = 'Export XML';

                trigger OnAction()
                begin
                    DMPFSExplorerMgmt.ExportXmlFile(SelectedAlias, CurrentPathText, 'sample.xml', '<root />');
                    RefreshCurrentFolder();
                end;
            }
        }
    }

    var
        SelectedAlias: Text[50];
        CurrentPathText: Text[250];
        LastStatusText: Text[250];
        LastTransactionIdText: Text[100];
        DMPFSExplorerMgmt: Codeunit "DMP FS Explorer Mgmt. IOI";

    local procedure RefreshCurrentFolder()
    begin
        DMPFSExplorerMgmt.RefreshCurrentFolder(SelectedAlias, CurrentPathText);
        LastStatusText := DMPFSExplorerMgmt.GetLastStatus();
        LastTransactionIdText := Format(DMPFSExplorerMgmt.GetLastTransactionId());
    end;

    trigger OnOpenPage()
    begin
        SelectedAlias := 'IMPORT';
        CurrentPathText := '';
        RefreshCurrentFolder();
    end;
}
