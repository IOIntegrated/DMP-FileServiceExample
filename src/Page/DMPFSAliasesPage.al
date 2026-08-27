page 92006 "DMP FS Aliases IOI"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "DMP FS Alias IOI";
    Caption = 'DMP File System Aliases';

    layout
    {
        area(Content)
        {
            repeater(Aliases)
            {
                field(Alias; Rec.Alias)
                {
                    ApplicationArea = All;
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                }
                field("Default Path"; Rec."Default Path")
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
            action(OpenExplorer)
            {
                ApplicationArea = All;
                Caption = 'Open Explorer';
                Image = Navigate;

                trigger OnAction()
                var
                    ExplorerPage: Page "DMP FS Explorer IOI";
                begin
                    ExplorerPage.SetInitialAlias(Rec.Alias);
                    ExplorerPage.Run();
                end;
            }
        }
    }
}
