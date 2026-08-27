table 92000 "DMP FS Explorer Entry IOI"
{
    DataClassification = ToBeClassified;
    TableType = Temporary;

    fields
    {
        field(1; "Entry Type"; Option)
        {
            Caption = 'Entry Type';
            OptionMembers = Directory,File;
        }
        field(2; Name; Text[250])
        {
            Caption = 'Name';
        }
        field(3; "Full Path"; Text[250])
        {
            Caption = 'Full Path';
        }
        field(4; "Size Bytes"; BigInteger)
        {
            Caption = 'Size Bytes';
        }
        field(5; "Last Modified"; DateTime)
        {
            Caption = 'Last Modified';
        }
        field(6; Alias; Text[50])
        {
            Caption = 'Alias';
        }
    }

    keys
    {
        key(PK; Name)
        {
            Clustered = true;
        }
    }

    procedure SetEntry(pAlias: Text[50]; pPath: Text[250]; pEntryType: Option Directory,File; pName: Text[250]; pSizeBytes: BigInteger; pLastModified: DateTime)
    begin
        Init();
        Alias := pAlias;
        "Full Path" := pPath;
        "Entry Type" := pEntryType;
        Name := pName;
        "Size Bytes" := pSizeBytes;
        "Last Modified" := pLastModified;
        Insert();
    end;
}
