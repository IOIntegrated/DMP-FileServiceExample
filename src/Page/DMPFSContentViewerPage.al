page 92001 "DMP FS Content Viewer IOI"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Tasks;
    Caption = 'DMP File Content Viewer';

    layout
    {
        area(Content)
        {
            group(General)
            {
                field(AliasValue; AliasValue)
                {
                    ApplicationArea = All;
                    Caption = 'Alias';
                    Editable = false;
                }
                field(PathValue; PathValue)
                {
                    ApplicationArea = All;
                    Caption = 'Path';
                    Editable = false;
                }
                field(FileNameValue; FileNameValue)
                {
                    ApplicationArea = All;
                    Caption = 'File';
                    Editable = false;
                }
                field(FileSizeValue; FileSizeValue)
                {
                    ApplicationArea = All;
                    Caption = 'Size';
                    Editable = false;
                }
                field(LastModifiedValue; LastModifiedValue)
                {
                    ApplicationArea = All;
                    Caption = 'Last Modified';
                    Editable = false;
                }
                field(FileContent; FileContent)
                {
                    ApplicationArea = All;
                    MultiLine = true;
                    Caption = 'Content';
                    Editable = false;
                    Width = 120;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RefreshContent)
            {
                ApplicationArea = All;
                Caption = 'Refresh Content';
                Image = Refresh;

                trigger OnAction()
                var
                    ExplorerMgmt: Codeunit "DMP FS Explorer Mgmt. IOI";
                begin
                    ExplorerMgmt.ReadCurrentFile(AliasValue, PathValue, FileNameValue);
                end;
            }
            action(LoadFromResults)
            {
                ApplicationArea = All;
                Caption = 'Load From Results';
                Image = View;

                trigger OnAction()
                var
                    ExplorerMgmt: Codeunit "DMP FS Explorer Mgmt. IOI";
                    ContentText: Text;
                    SizeBytes: BigInteger;
                    LastModified: DateTime;
                    StatusText: Text[250];
                begin
                    if ExplorerMgmt.TryGetFilePreviewFromResults(AliasValue, PathValue, FileNameValue, ContentText, SizeBytes, LastModified, StatusText) then
                        SetMetadata(AliasValue, PathValue, FileNameValue, SizeBytes, LastModified, ContentText)
                    else
                        Message(StatusText);
                end;
            }
        }
    }

    var
        AliasValue: Text[50];
        PathValue: Text[250];
        FileNameValue: Text[250];
        FileSizeValue: Text[50];
        LastModifiedValue: Text[50];
        FileContent: Text;

    procedure SetFile(pAlias: Text[50]; pPath: Text[250]; pFileName: Text[250]; pContent: Text)
    begin
        AliasValue := pAlias;
        PathValue := pPath;
        FileNameValue := pFileName;
        FileSizeValue := Format(StrLen(pContent));
        LastModifiedValue := Format(CurrentDateTime());
        FileContent := pContent;
    end;

    procedure SetMetadata(pAlias: Text[50]; pPath: Text[250]; pFileName: Text[250]; pSizeBytes: BigInteger; pLastModified: DateTime; pContent: Text)
    begin
        AliasValue := pAlias;
        PathValue := pPath;
        FileNameValue := pFileName;
        FileSizeValue := Format(pSizeBytes);
        LastModifiedValue := Format(pLastModified);
        FileContent := pContent;
    end;
}
