permissionset 92000 "DMP FS EXPLORER IOI"
{
    Assignable = true;
    Caption = 'DMP File System Explorer';

    Permissions =
        tabledata "DMP FS Alias IOI" = RIMD,
        table "DMP FS Alias IOI" = X,
        table "DMP FS Explorer Entry IOI" = X,
        page "DMP FS Aliases IOI" = X,
        page "DMP FS Content Viewer IOI" = X,
        page "DMP FS Explorer IOI" = X,
        codeunit "DMP FS Explorer Actions IOI" = X,
        codeunit "DMP FS Explorer Mgmt. IOI" = X,
        codeunit "DMP FS Explorer Transport IOI" = X;
}
