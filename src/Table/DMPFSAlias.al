table 92001 "DMP FS Alias IOI"
{
    Caption = 'DMP FS Alias';
    DataClassification = CustomerContent;
    LookupPageId = "DMP FS Aliases IOI";
    DrillDownPageId = "DMP FS Aliases IOI";

    fields
    {
        field(1; Alias; Code[50])
        {
            Caption = 'Alias';
            NotBlank = true;
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
        }
        field(3; "Default Path"; Text[250])
        {
            Caption = 'Default Path';
        }
    }

    keys
    {
        key(PK; Alias)
        {
            Clustered = true;
        }
    }

    procedure EnsureDefaults()
    var
        FSAlias: Record "DMP FS Alias IOI";
    begin
        if not FSAlias.IsEmpty() then
            exit;

        InsertDefault('IMPORT', 'Import file share');
        InsertDefault('ARCHIVE', 'Archive file share');
        InsertDefault('EXPORT', 'Export file share');
    end;

    local procedure InsertDefault(pAlias: Code[50]; pDescription: Text[100])
    var
        FSAlias: Record "DMP FS Alias IOI";
    begin
        FSAlias.Init();
        FSAlias.Alias := pAlias;
        FSAlias.Description := pDescription;
        FSAlias.Insert();
    end;
}
