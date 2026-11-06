codeunit 92007 "DMP FS Explorer Transport IOI"
{
    EventSubscriberInstance = Manual;

    var
        DefaultConfigurationCodeLbl: Label 'DEFAULT', Locked = true;
        TruncatedPayloadErr: Label 'The file service payload exceeds the size supported by the explorer relay adapter. No request was sent.';
        InvalidPayloadErr: Label 'The file service request payload is invalid. No request was sent.';
        RelayFailedErr: Label 'The file service relay could not send the request: %1', Comment = '%1 = relay error';

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"DMP File System API IOI", 'OnBeforeSendCommand', '', false, false)]
    local procedure SendCommand(var RequestRec: Record "DMP FS Request IOI"; var Handled: Boolean)
    var
        ClientConfiguration: Record "Client Configuration IOI";
        RelaySender: Codeunit "Relay Sender IOI";
        FileSystemApi: Codeunit "DMP File System API IOI";
        Base64Convert: Codeunit "Base64 Convert";
        Payload: JsonObject;
        Request: JsonObject;
        Envelope: JsonObject;
        CommandToken: JsonToken;
        ContentToken: JsonToken;
        RequestText: Text;
        EnvelopeText: Text;
        ResponseText: Text;
    begin
        if Handled then
            exit;

        ClientConfiguration.Get(DefaultConfigurationCodeLbl);
        ClientConfiguration.TestField("Function Url");
        ClientConfiguration.TestField("Function Key");
        ClientConfiguration.TestField("Connection Id");
        if RequestRec."Payload Truncated" then
            Error(TruncatedPayloadErr);
        if not Payload.ReadFrom(RequestRec."Payload Json") then
            Error(InvalidPayloadErr);
        if not Payload.Get('command', CommandToken) then
            Error(InvalidPayloadErr);

        RequestRec."Connection Id" := ClientConfiguration."Connection Id";
        Request.Add('interfaceVersion', '1.0');
        Request.Add('transactionId', RequestRec."Transaction Id");
        Request.Add('connectionId', ClientConfiguration."Connection Id");
        Request.Add('command', CommandToken.AsValue().AsText());
        Request.Add('pathAlias', RequestRec."Path Alias");
        Request.Add('relativePath', RequestRec."Relative Path");
        Request.Add('requestedBy', RequestRec."Requested By");
        Request.Add('createdAt', Format(RequestRec."Created At", 0, 9));
        Request.Add('payload', Payload);
        Request.WriteTo(RequestText);
        Envelope.Add('action', 'filesystem');
        Envelope.Add('transactionId', Format(RequestRec."Transaction Id", 0, 4));
        Envelope.Add('data', Base64Convert.ToBase64(RequestText));
        Envelope.WriteTo(EnvelopeText);

        Handled := true;
        RequestRec.Insert(true);
        // The listener callback must be able to update this request during the relay call.
        Commit();
        ResponseText := RelaySender.SendMessage(Base64Convert.ToBase64(EnvelopeText));
        if (ResponseText = '') or (StrPos(ResponseText, 'ERROR:') = 1) then begin
            RequestRec.Get(RequestRec."Transaction Id");
            if RequestRec.Status = RequestRec.Status::Sent then begin
                RequestRec.Status := RequestRec.Status::Failed;
                RequestRec."Last Updated At" := CurrentDateTime();
                RequestRec.Modify(true);
                Commit();
            end;
            Error(RelayFailedErr, ResponseText);
        end;

        if RequestRec.Command = RequestRec.Command::ExportXmlPortTarget then begin
            if not Payload.Get('contentText', ContentToken) then
                Error(InvalidPayloadErr);
            FileSystemApi.CompleteXmlExportContent(ContentToken.AsValue().AsText(), RequestRec."Transaction Id");
        end;
    end;
}
