codeunit 92004 "DMP FS Explorer Actions IOI"
{
    procedure SubmitCreateDirectory(pAlias: Text[50]; pRelativePath: Text[250])
    var
        Transport: Codeunit "DMP FS Explorer Transport IOI";
        FileSystemApi: Codeunit "DMP File System API IOI";
    begin
        BindSubscription(Transport);
        FileSystemApi.SubmitCreateDirectory(pAlias, pRelativePath);
    end;

    procedure SubmitCopyFile(pSourceAlias: Text[50]; pSourcePath: Text[250]; pTargetAlias: Text[50]; pTargetPath: Text[250])
    var
        Transport: Codeunit "DMP FS Explorer Transport IOI";
        FileSystemApi: Codeunit "DMP File System API IOI";
    begin
        BindSubscription(Transport);
        FileSystemApi.SubmitCopyFile(pSourceAlias, pSourcePath, pTargetAlias, pTargetPath);
    end;

    procedure SubmitMoveFile(pSourceAlias: Text[50]; pSourcePath: Text[250]; pTargetAlias: Text[50]; pTargetPath: Text[250])
    var
        Transport: Codeunit "DMP FS Explorer Transport IOI";
        FileSystemApi: Codeunit "DMP File System API IOI";
    begin
        BindSubscription(Transport);
        FileSystemApi.SubmitMoveFile(pSourceAlias, pSourcePath, pTargetAlias, pTargetPath);
    end;

    procedure SubmitArchiveFile(pSourceAlias: Text[50]; pSourcePath: Text[250]; pArchiveAlias: Text[50]; pArchivePath: Text[250])
    var
        Transport: Codeunit "DMP FS Explorer Transport IOI";
        FileSystemApi: Codeunit "DMP File System API IOI";
    begin
        BindSubscription(Transport);
        FileSystemApi.SubmitArchiveFile(pSourceAlias, pSourcePath, pArchiveAlias, pArchivePath);
    end;

    procedure SubmitAppendFile(pAlias: Text[50]; pRelativePath: Text[250]; pContent: Text)
    var
        Transport: Codeunit "DMP FS Explorer Transport IOI";
        FileSystemApi: Codeunit "DMP File System API IOI";
    begin
        BindSubscription(Transport);
        FileSystemApi.SubmitAppendFile(pAlias, pRelativePath, pContent);
    end;
}
