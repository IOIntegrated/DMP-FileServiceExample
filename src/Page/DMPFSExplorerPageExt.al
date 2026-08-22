pageextension 92003 "DMP FS Explorer Ext. IOI" extends "DMP FS Request List IOI"
{
    actions
    {
        addlast(processing)
        {
            action(OpenFileExplorer)
            {
                ApplicationArea = All;
                Caption = 'Open File Explorer';
                Image = Navigate;

                trigger OnAction()
                var
                    FSExplorerPage: Page "DMP FS Explorer IOI";
                begin
                    FSExplorerPage.Run();
                end;
            }
        }
    }
}
