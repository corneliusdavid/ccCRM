unit ccCRM.Server.Resources;

{ RAD Server (EMS) resources for ccCRM. One instance of each resource class is created per
  request; each owns a TdmccCRM that borrows a pooled Firebird connection and returns it
  when the request ends.

  Resources
    customers      GET (q, type_id, status_id) | GET /item | PUT /item | DELETE /item
                                                         (DELETE: only if no longer in Wave)
    contacts       POST | PUT /item | DELETE /item
    customerlog    POST | PUT /item | DELETE /item       (manual entries only)
    lookups        GET                                   (types + statuses)
    emails         GET (type, status names)              (email list + BCC string)
    sync           POST                                  (pull from Wave now)

  "item" is the Wave id for customers and the numeric id for contacts / customerlog. }

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  EMS.Services, EMS.ResourceAPI, EMS.ResourceTypes,
  ccCRM.Types, ccCRM.Config, ccCRM.WaveClient, ccCRM.Data, ccCRM.Server.Json;

type
  { Base: lazily creates and connects the data module for this request. }
  TccResource = class(TComponent)
  strict private
    FData: TdmccCRM;
  protected
    function Data: TdmccCRM;
    { Customer with its contacts and log; nil if the Wave id is unknown. }
    function CustomerJson(const AWaveId: string): TJSONObject;
  public
    destructor Destroy; override;
  end;

  [ResourceName('customers')]
  TCustomersResource = class(TccResource)
  published
    procedure Get(const AContext: TEndpointContext; const ARequest: TEndpointRequest;
      const AResponse: TEndpointResponse);
    [ResourceSuffix('{item}')]
    procedure GetItem(const AContext: TEndpointContext; const ARequest: TEndpointRequest;
      const AResponse: TEndpointResponse);
    [ResourceSuffix('{item}')]
    procedure PutItem(const AContext: TEndpointContext; const ARequest: TEndpointRequest;
      const AResponse: TEndpointResponse);
    [ResourceSuffix('{item}')]
    procedure DeleteItem(const AContext: TEndpointContext; const ARequest: TEndpointRequest;
      const AResponse: TEndpointResponse);
  end;

  [ResourceName('contacts')]
  TContactsResource = class(TccResource)
  published
    procedure Post(const AContext: TEndpointContext; const ARequest: TEndpointRequest;
      const AResponse: TEndpointResponse);
    [ResourceSuffix('{item}')]
    procedure PutItem(const AContext: TEndpointContext; const ARequest: TEndpointRequest;
      const AResponse: TEndpointResponse);
    [ResourceSuffix('{item}')]
    procedure DeleteItem(const AContext: TEndpointContext; const ARequest: TEndpointRequest;
      const AResponse: TEndpointResponse);
  end;

  [ResourceName('customerlog')]
  TCustomerLogResource = class(TccResource)
  published
    procedure Post(const AContext: TEndpointContext; const ARequest: TEndpointRequest;
      const AResponse: TEndpointResponse);
    [ResourceSuffix('{item}')]
    procedure PutItem(const AContext: TEndpointContext; const ARequest: TEndpointRequest;
      const AResponse: TEndpointResponse);
    [ResourceSuffix('{item}')]
    procedure DeleteItem(const AContext: TEndpointContext; const ARequest: TEndpointRequest;
      const AResponse: TEndpointResponse);
  end;

  [ResourceName('lookups')]
  TLookupsResource = class(TccResource)
  published
    procedure Get(const AContext: TEndpointContext; const ARequest: TEndpointRequest;
      const AResponse: TEndpointResponse);
  end;

  [ResourceName('emails')]
  TEmailsResource = class(TccResource)
  published
    procedure Get(const AContext: TEndpointContext; const ARequest: TEndpointRequest;
      const AResponse: TEndpointResponse);
  end;

  [ResourceName('sync')]
  TSyncResource = class(TccResource)
  published
    procedure Post(const AContext: TEndpointContext; const ARequest: TEndpointRequest;
      const AResponse: TEndpointResponse);
  end;

implementation

uses
  Data.DB, FireDAC.Stan.Param, FireDAC.Comp.Client;

var
  GConfig: TccCRMConfig;
  GConfigLoaded: Boolean;
  GConfigLock: TObject;

{ Settings are read once per process from ccCRM.ini beside the package. }
function ServerConfig: TccCRMConfig;
begin
  TMonitor.Enter(GConfigLock);
  try
    if not GConfigLoaded then
    begin
      GConfig := TccCRMConfig.Load;
      GConfig.Db.Pooled := True;
      GConfigLoaded := True;
    end;
    Result := GConfig;
  finally
    TMonitor.Exit(GConfigLock);
  end;
end;

{ ---- request helpers ---- }

function QueryValue(const ARequest: TEndpointRequest; const AName: string): string;
begin
  if not ARequest.Params.TryGetValue(AName, Result) then
    Result := '';
end;

function BodyObject(const ARequest: TEndpointRequest): TJSONObject;
begin
  if not ARequest.Body.TryGetObject(Result) then
    EEMSHTTPError.RaiseBadRequest('bad_request', 'A JSON object body is required.');
end;

function ItemId(const ARequest: TEndpointRequest): Integer;
begin
  if not TryStrToInt(QueryValue(ARequest, 'item'), Result) then
    EEMSHTTPError.RaiseBadRequest('bad_request', 'The id in the URL must be a number.');
end;

{ Optional filter value: empty means "no filter" (NULL). }
procedure SetFilter(AParam: TFDParam; const AValue: string);
begin
  if AValue = '' then
    AParam.Clear
  else if AParam.DataType in [ftSmallint, ftInteger, ftLargeint] then
  begin
    var N: Integer;
    if not TryStrToInt(AValue, N) then
      EEMSHTTPError.RaiseBadRequest('bad_request', AParam.Name + ' must be a number.');
    AParam.AsInteger := N;
  end
  else
    AParam.AsString := AValue;
end;

{ Copies a (possibly missing) JSON key into a parameter; bad values become HTTP 400. }
procedure SetFromBody(AParam: TFDParam; ABody: TJSONObject; const AKey: string);
begin
  try
    ParamFromJson(AParam, ABody.GetValue(AKey));
  except
    on EConvertError do
      EEMSHTTPError.RaiseBadRequest('bad_request', 'Invalid value for ' + AKey + '.');
  end;
end;

function RequiredString(ABody: TJSONObject; const AKey: string): string;
begin
  var V := ABody.GetValue(AKey);
  if (V = nil) or (V is TJSONNull) or (Trim(V.Value) = '') then
    EEMSHTTPError.RaiseBadRequest('bad_request', AKey + ' is required.');
  Result := V.Value;
end;

procedure RespondRows(const AResponse: TEndpointResponse; ARows: Integer);
begin
  if ARows = 0 then
    EEMSHTTPError.RaiseNotFound('not_found', 'Nothing matched that id.');
  var Obj := TJSONObject.Create;
  Obj.AddPair('rows', TJSONNumber.Create(ARows));
  AResponse.Body.SetValue(Obj, True);
end;

{ TccResource }

destructor TccResource.Destroy;
begin
  FData.Free;
  inherited;
end;

function TccResource.Data: TdmccCRM;
begin
  if FData = nil then
  begin
    FData := TdmccCRM.Create(nil);
    FData.Connect(ServerConfig.Db);
  end;
  Result := FData;
end;

function TccResource.CustomerJson(const AWaveId: string): TJSONObject;
begin
  Result := nil;
  Data.qCustomer.ParamByName('WAVE_ID').AsString := AWaveId;
  Data.qCustomer.Open;
  try
    if Data.qCustomer.Eof then
      Exit;
    Result := RowToJson(Data.qCustomer);
  finally
    Data.qCustomer.Close;
  end;

  try
    Data.qContacts.ParamByName('WAVE_ID').AsString := AWaveId;
    Result.AddPair('contacts', QueryToJson(Data.qContacts));
    Data.qLog.ParamByName('WAVE_ID').AsString := AWaveId;
    Result.AddPair('log', QueryToJson(Data.qLog));
  except
    Result.Free;
    raise;
  end;
end;

{ TCustomersResource }

procedure TCustomersResource.Get(const AContext: TEndpointContext;
  const ARequest: TEndpointRequest; const AResponse: TEndpointResponse);
begin
  var Q := Data.qCustomers;
  SetFilter(Q.ParamByName('Q'), Trim(QueryValue(ARequest, 'q')));
  SetFilter(Q.ParamByName('TYPE_ID'), QueryValue(ARequest, 'type_id'));
  SetFilter(Q.ParamByName('STATUS_ID'), QueryValue(ARequest, 'status_id'));
  Q.Open;
  try
    AResponse.Body.SetValue(RowsToJson(Q), True);
  finally
    Q.Close;
  end;
end;

procedure TCustomersResource.GetItem(const AContext: TEndpointContext;
  const ARequest: TEndpointRequest; const AResponse: TEndpointResponse);
begin
  var Obj := CustomerJson(QueryValue(ARequest, 'item'));
  if Obj = nil then
    EEMSHTTPError.RaiseNotFound('not_found', 'Unknown customer.');
  AResponse.Body.SetValue(Obj, True);
end;

{ Updates only your own columns (type_id, status_id, ad_group, user_count, notes).
  Keys missing from the body keep their value; a JSON null clears the column. }
procedure TCustomersResource.PutItem(const AContext: TEndpointContext;
  const ARequest: TEndpointRequest; const AResponse: TEndpointResponse);
begin
  var Id := QueryValue(ARequest, 'item');
  var Body := BodyObject(ARequest);
  var Cmd := Data.cmdUpdateCustomer;
  Cmd.ParamByName('WAVE_ID').AsString := Id;

  var Cur := Data.qCustomer;
  Cur.ParamByName('WAVE_ID').AsString := Id;
  Cur.Open;
  try
    if Cur.Eof then
      EEMSHTTPError.RaiseNotFound('not_found', 'Unknown customer.');
    for var Col in ['TYPE_ID', 'STATUS_ID', 'AD_GROUP', 'USER_COUNT', 'NOTES'] do
      Cmd.ParamByName(Col).Value := Cur.FieldByName(Col).Value;
  finally
    Cur.Close;
  end;

  for var Col in ['TYPE_ID', 'STATUS_ID', 'AD_GROUP', 'USER_COUNT', 'NOTES'] do
    if Body.GetValue(LowerCase(Col)) <> nil then
      SetFromBody(Cmd.ParamByName(Col), Body, LowerCase(Col));
  Cmd.ExecSQL;

  AResponse.Body.SetValue(CustomerJson(Id), True);
end;

{ Removes an obsolete customer (deleted in Wave) with its contacts and log. Customers still in
  Wave answer 409: the next sync would only bring them back. }
procedure TCustomersResource.DeleteItem(const AContext: TEndpointContext;
  const ARequest: TEndpointRequest; const AResponse: TEndpointResponse);
begin
  var Id := QueryValue(ARequest, 'item');
  var Cur := Data.qCustomer;
  Cur.ParamByName('WAVE_ID').AsString := Id;
  Cur.Open;
  try
    if Cur.Eof then
      EEMSHTTPError.RaiseNotFound('not_found', 'Unknown customer.');
    if Cur.FieldByName('IN_WAVE').AsBoolean then
      EEMSHTTPError.RaiseError(409, 'conflict', 'This customer is still in Wave.');
  finally
    Cur.Close;
  end;

  if not Data.DeleteMissingCustomer(Id) then
    EEMSHTTPError.RaiseError(409, 'conflict', 'This customer is still in Wave.');
  RespondRows(AResponse, 1);
end;

{ TContactsResource }

procedure TContactsResource.Post(const AContext: TEndpointContext;
  const ARequest: TEndpointRequest; const AResponse: TEndpointResponse);
begin
  var Body := BodyObject(ARequest);
  var Cmd := Data.cmdAddContact;
  Cmd.ParamByName('WAVE_ID').AsString := RequiredString(Body, 'wave_id');
  for var Col in ['NAME', 'EMAIL', 'PHONE', 'JOB_TITLE'] do
    SetFromBody(Cmd.ParamByName(Col), Body, LowerCase(Col));
  Cmd.ExecSQL;
  AResponse.StatusCode := 201;
  RespondRows(AResponse, Cmd.RowsAffected);
end;

{ PUT replaces name, email, phone and job_title (missing keys become NULL). }
procedure TContactsResource.PutItem(const AContext: TEndpointContext;
  const ARequest: TEndpointRequest; const AResponse: TEndpointResponse);
begin
  var Body := BodyObject(ARequest);
  var Cmd := Data.cmdUpdateContact;
  Cmd.ParamByName('CONTACT_ID').AsInteger := ItemId(ARequest);
  for var Col in ['NAME', 'EMAIL', 'PHONE', 'JOB_TITLE'] do
    SetFromBody(Cmd.ParamByName(Col), Body, LowerCase(Col));
  Cmd.ExecSQL;
  RespondRows(AResponse, Cmd.RowsAffected);
end;

procedure TContactsResource.DeleteItem(const AContext: TEndpointContext;
  const ARequest: TEndpointRequest; const AResponse: TEndpointResponse);
begin
  var Cmd := Data.cmdDeleteContact;
  Cmd.ParamByName('CONTACT_ID').AsInteger := ItemId(ARequest);
  Cmd.ExecSQL;
  RespondRows(AResponse, Cmd.RowsAffected);
end;

{ TCustomerLogResource }

procedure TCustomerLogResource.Post(const AContext: TEndpointContext;
  const ARequest: TEndpointRequest; const AResponse: TEndpointResponse);
begin
  var Body := BodyObject(ARequest);
  var Cmd := Data.cmdAddLog;
  Cmd.ParamByName('WAVE_ID').AsString := RequiredString(Body, 'wave_id');
  Cmd.ParamByName('SUMMARY').AsString := RequiredString(Body, 'summary');
  if Body.GetValue('event_date') = nil then
    Cmd.ParamByName('EVENT_DATE').AsDateTime := Date  // default: today
  else
    SetFromBody(Cmd.ParamByName('EVENT_DATE'), Body, 'event_date');
  Cmd.ExecSQL;
  AResponse.StatusCode := 201;
  RespondRows(AResponse, Cmd.RowsAffected);
end;

procedure TCustomerLogResource.PutItem(const AContext: TEndpointContext;
  const ARequest: TEndpointRequest; const AResponse: TEndpointResponse);
begin
  var Body := BodyObject(ARequest);
  var Cmd := Data.cmdUpdateLog;
  Cmd.ParamByName('LOG_ID').AsInteger := ItemId(ARequest);
  Cmd.ParamByName('SUMMARY').AsString := RequiredString(Body, 'summary');
  SetFromBody(Cmd.ParamByName('EVENT_DATE'), Body, 'event_date');
  if Cmd.ParamByName('EVENT_DATE').IsNull then
    EEMSHTTPError.RaiseBadRequest('bad_request', 'event_date is required.');
  Cmd.ExecSQL;
  RespondRows(AResponse, Cmd.RowsAffected);  // 404 for automatic entries: they can't be edited
end;

procedure TCustomerLogResource.DeleteItem(const AContext: TEndpointContext;
  const ARequest: TEndpointRequest; const AResponse: TEndpointResponse);
begin
  var Cmd := Data.cmdDeleteLog;
  Cmd.ParamByName('LOG_ID').AsInteger := ItemId(ARequest);
  Cmd.ExecSQL;
  RespondRows(AResponse, Cmd.RowsAffected);  // 404 for automatic entries: they can't be deleted
end;

{ TLookupsResource }

procedure TLookupsResource.Get(const AContext: TEndpointContext;
  const ARequest: TEndpointRequest; const AResponse: TEndpointResponse);
begin
  var Obj := TJSONObject.Create;
  try
    Obj.AddPair('types', QueryToJson(Data.qTypes));
    Obj.AddPair('statuses', QueryToJson(Data.qStatuses));
  except
    Obj.Free;
    raise;
  end;
  AResponse.Body.SetValue(Obj, True);
end;

{ TEmailsResource }

{ ?type=ABS Cloud&status=Active (names from /lookups; both optional). }
procedure TEmailsResource.Get(const AContext: TEndpointContext;
  const ARequest: TEndpointRequest; const AResponse: TEndpointResponse);
begin
  var Q := Data.qEmails;
  SetFilter(Q.ParamByName('TYPE_NAME'), QueryValue(ARequest, 'type'));
  SetFilter(Q.ParamByName('STATUS_NAME'), QueryValue(ARequest, 'status'));

  var Emails := TJSONArray.Create;
  var Bcc := '';
  try
    Q.Open;
    try
      while not Q.Eof do
      begin
        var Email := Q.Fields[0].AsString;
        Emails.Add(Email);
        if Bcc <> '' then
          Bcc := Bcc + '; ';
        Bcc := Bcc + Email;
        Q.Next;
      end;
    finally
      Q.Close;
    end;
  except
    Emails.Free;
    raise;
  end;

  var Obj := TJSONObject.Create;
  Obj.AddPair('count', TJSONNumber.Create(Emails.Count));
  Obj.AddPair('bcc', Bcc);
  Obj.AddPair('emails', Emails);
  AResponse.Body.SetValue(Obj, True);
end;

{ TSyncResource }

procedure TSyncResource.Post(const AContext: TEndpointContext;
  const ARequest: TEndpointRequest; const AResponse: TEndpointResponse);
begin
  var Cfg := ServerConfig;
  var Wave := TWaveClient.Create(Cfg.WaveToken, Cfg.WaveBusinessId);
  try
    var R := Data.SyncCustomers(Wave.FetchCustomers);
    var Obj := TJSONObject.Create;
    Obj.AddPair('fetched', TJSONNumber.Create(R.Fetched));
    Obj.AddPair('added', TJSONNumber.Create(R.Added));
    Obj.AddPair('updated', TJSONNumber.Create(R.Updated));
    Obj.AddPair('marked_missing', TJSONNumber.Create(R.MarkedMissing));
    AResponse.Body.SetValue(Obj, True);
  finally
    Wave.Free;
  end;
end;

procedure Register;
begin
  RegisterResource(TypeInfo(TCustomersResource));
  RegisterResource(TypeInfo(TContactsResource));
  RegisterResource(TypeInfo(TCustomerLogResource));
  RegisterResource(TypeInfo(TLookupsResource));
  RegisterResource(TypeInfo(TEmailsResource));
  RegisterResource(TypeInfo(TSyncResource));
end;

initialization
  GConfigLock := TObject.Create;
  Register;

finalization
  GConfigLock.Free;

end.
