unit ccCRM.App.Api;

{ REST client for the ccCRM RAD Server package, app settings, and the small helper that runs
  calls on a background thread and delivers the result on the UI thread.

  All HTTP calls here are blocking; always go through TAsync.Run from UI code. }

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Threading, System.IOUtils,
  System.IniFiles, System.NetEncoding, System.Net.HttpClient, System.Net.URLClient,
  ccCRM.App.Types;

type
  ECrmApiError = class(Exception);

const
  AllIds = -1;          // list filter: any type / status
  UnclassifiedId = 0;   // list filter: type / status not set

type

  TAppSettings = record
    BaseUrl: string;       // e.g. https://server/radserver
    AppId: string;         // RAD Server application id
    AppSecret: string;     // RAD Server application secret (optional)
    function IsConfigured: Boolean;
  end;

  { Lets a callback find out that its frame has been closed in the meantime. }
  IAlive = interface
    ['{6E0B1C3F-7B1A-4C52-9D55-3A4F2D1C8E10}']
    function Alive: Boolean;
    procedure Kill;
  end;

  TAlive = class(TInterfacedObject, IAlive)
  strict private
    FAlive: Boolean;
  public
    constructor Create;
    function Alive: Boolean;
    procedure Kill;
  end;

  TAsync = class
  public
    { Runs AWork on a pool thread; calls ADone (or AFail with the message) on the UI thread,
      unless AAlive says the caller has gone away. }
    class procedure Run<T>(const AAlive: IAlive; const AWork: TFunc<T>;
      const ADone: TProc<T>; const AFail: TProc<string>); static;
  end;

  TCrmApi = class
  strict private
    FSettings: TAppSettings;
    FLookups: TLookups;
    FLookupsLoaded: Boolean;
    function Request(const AMethod, APath: string; ABody: TJSONValue = nil): TJSONValue;
    class function SettingsFile: string; static;
  public
    constructor Create;
    procedure LoadSettings;
    procedure SaveSettings(const ASettings: TAppSettings);
    property Settings: TAppSettings read FSettings;

    function Lookups(ARefresh: Boolean = False): TLookups;
    { ATypeId / AStatusId: AllIds for no filter, UnclassifiedId for customers without one. }
    function Customers(const AQuery: string; ATypeId, AStatusId: Integer): TArray<TCustomerRow>;
    function Customer(const AWaveId: string): TCustomerDetail;
    { Updates only your own columns; returns the refreshed customer. TypeId/StatusId 0 clears. }
    function UpdateCustomer(const AWaveId: string; ATypeId, AStatusId: Integer;
      const AAdGroup: string; AUserCount: Integer; const ANotes: string): TCustomerDetail;
    { Removes a customer that is no longer in Wave (the server refuses others). }
    procedure DeleteCustomer(const AWaveId: string);
    procedure AddLog(const AWaveId: string; AEventDate: TDate; const ASummary: string);
    { Additional contacts (the main contact comes from Wave and isn't edited here). }
    procedure AddContact(const AWaveId: string; const AContact: TContactRec);
    procedure UpdateContact(const AContact: TContactRec);
    procedure DeleteContact(AContactId: Integer);
    function Emails(const ATypeName, AStatusName: string): TEmailList;
    function SyncNow: string;
  end;

function Crm: TCrmApi;

implementation

uses
  System.Generics.Collections;

var
  GCrm: TCrmApi;

{ Created and loaded once at start-up (see initialization), on the main thread, so background
  requests never see a half-initialised object. }
function Crm: TCrmApi;
begin
  Result := GCrm;
end;

{ TAppSettings }

function TAppSettings.IsConfigured: Boolean;
begin
  // RAD Server allows a blank application id, so only the address is required
  Result := Trim(BaseUrl) <> '';
end;

{ TAlive }

constructor TAlive.Create;
begin
  inherited;
  FAlive := True;
end;

function TAlive.Alive: Boolean;
begin
  Result := FAlive;
end;

procedure TAlive.Kill;
begin
  FAlive := False;
end;

{ TAsync }

class procedure TAsync.Run<T>(const AAlive: IAlive; const AWork: TFunc<T>;
  const ADone: TProc<T>; const AFail: TProc<string>);
begin
  TTask.Run(
    procedure
    begin
      var Result: T;
      var Error := '';
      var Ok := False;
      try
        Result := AWork();
        Ok := True;
      except
        on E: Exception do
          Error := E.Message;
      end;
      TThread.Queue(nil,
        procedure
        begin
          if (AAlive <> nil) and not AAlive.Alive then
            Exit;
          if Ok then
          begin
            if Assigned(ADone) then
              ADone(Result);
          end
          else if Assigned(AFail) then
            AFail(Error);
        end);
    end);
end;

{ TCrmApi }

constructor TCrmApi.Create;
begin
  inherited;
  FLookups := Default(TLookups);
end;

{ Windows (dev builds): beside the exe, like the sync tool and the package. Phones: the app's
  private documents folder, the only place those platforms let an app write. }
class function TCrmApi.SettingsFile: string;
begin
{$IFDEF MSWINDOWS}
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)), 'ccCRM.ini');
{$ELSE}
  Result := TPath.Combine(TPath.GetDocumentsPath, 'ccCRM.ini');
{$ENDIF}
end;

procedure TCrmApi.LoadSettings;
begin
  var Ini := TIniFile.Create(SettingsFile);
  try
    FSettings.BaseUrl := Ini.ReadString('Server', 'BaseUrl', '');
    FSettings.AppId := Ini.ReadString('Server', 'AppId', '');
    FSettings.AppSecret := Ini.ReadString('Server', 'AppSecret', '');
  finally
    Ini.Free;
  end;
end;

procedure TCrmApi.SaveSettings(const ASettings: TAppSettings);
begin
  FSettings := ASettings;
  FLookupsLoaded := False;
  var Ini := TIniFile.Create(SettingsFile);
  try
    Ini.WriteString('Server', 'BaseUrl', ASettings.BaseUrl);
    Ini.WriteString('Server', 'AppId', ASettings.AppId);
    Ini.WriteString('Server', 'AppSecret', ASettings.AppSecret);
  finally
    Ini.Free;
  end;
end;

{ Sends one request. Returns the parsed JSON (owned by the caller) or nil for an empty body. }
function TCrmApi.Request(const AMethod, APath: string; ABody: TJSONValue): TJSONValue;
begin
  var S := FSettings;  // snapshot: Setup may save new values while a request is running
  if not S.IsConfigured then
    raise ECrmApiError.Create('Open Setup and enter the server address.');

  var Url := S.BaseUrl.Trim.TrimRight(['/']) + APath;
  var Headers: TNetHeaders := [
    TNameValuePair.Create('Accept', 'application/json'),
    TNameValuePair.Create('Content-Type', 'application/json')];
  if S.AppId <> '' then
    Headers := Headers + [TNameValuePair.Create('X-Embarcadero-Application-Id', S.AppId)];
  if S.AppSecret <> '' then
    Headers := Headers + [TNameValuePair.Create('X-Embarcadero-App-Secret', S.AppSecret)];

  var Content: string;
  var Status: Integer;
  var Http := THTTPClient.Create;
  try
    Http.ConnectionTimeout := 15000;
    Http.ResponseTimeout := 60000;
    var Source: TStringStream := nil;
    try
      if ABody <> nil then
        Source := TStringStream.Create(ABody.ToJSON, TEncoding.UTF8);
      var Resp: IHTTPResponse;
      if SameText(AMethod, 'GET') then
        Resp := Http.Get(Url, nil, Headers)
      else if SameText(AMethod, 'POST') then
        Resp := Http.Post(Url, Source, nil, Headers)
      else if SameText(AMethod, 'PUT') then
        Resp := Http.Put(Url, Source, nil, Headers)
      else
        Resp := Http.Delete(Url, nil, Headers);
      Content := Resp.ContentAsString(TEncoding.UTF8);
      Status := Resp.StatusCode;
    finally
      Source.Free;
    end;
  finally
    Http.Free;
  end;

  if Status >= 400 then
  begin
    var Msg := '';
    var Err := TJSONObject.ParseJSONValue(Content);
    try
      if Err is TJSONObject then
      begin
        Msg := JStr(TJSONObject(Err), 'error');
        var Desc := JStr(TJSONObject(Err), 'description');
        if Desc <> '' then
          Msg := Msg + ': ' + Desc;
      end;
    finally
      Err.Free;
    end;
    if Msg = '' then
      Msg := 'The server returned an error';
    raise ECrmApiError.CreateFmt('%s (HTTP %d)', [Msg, Status]);
  end;

  if Trim(Content) = '' then
    Exit(nil);
  Result := TJSONObject.ParseJSONValue(Content);
  if Result = nil then
    raise ECrmApiError.Create('The server sent something that is not JSON. Check the server address.');
end;

function TCrmApi.Lookups(ARefresh: Boolean): TLookups;
begin
  if ARefresh or not FLookupsLoaded then
  begin
    var Json := Request('GET', '/lookups');
    try
      var Obj := Json as TJSONObject;
      FLookups.Types := ParseLookupArray(Obj.GetValue('types') as TJSONArray, 'type_id');
      FLookups.Statuses := ParseLookupArray(Obj.GetValue('statuses') as TJSONArray, 'status_id');
      FLookupsLoaded := True;
    finally
      Json.Free;
    end;
  end;
  Result := FLookups;
end;

function TCrmApi.Customers(const AQuery: string; ATypeId, AStatusId: Integer): TArray<TCustomerRow>;
begin
  var Qs := '';
  if Trim(AQuery) <> '' then
    Qs := Qs + '&q=' + TNetEncoding.URL.EncodeQuery(Trim(AQuery));
  if ATypeId <> AllIds then
    Qs := Qs + '&type_id=' + ATypeId.ToString;
  if AStatusId <> AllIds then
    Qs := Qs + '&status_id=' + AStatusId.ToString;
  if Qs <> '' then
    Qs := '?' + Qs.Substring(1);

  var Json := Request('GET', '/customers' + Qs);
  try
    var Arr := Json as TJSONArray;
    SetLength(Result, Arr.Count);
    for var I := 0 to Arr.Count - 1 do
      Result[I] := ParseCustomerRow(Arr.Items[I] as TJSONObject);
  finally
    Json.Free;
  end;
end;

function TCrmApi.Customer(const AWaveId: string): TCustomerDetail;
begin
  var Json := Request('GET', '/customers/' + TNetEncoding.URL.EncodePath(AWaveId));
  try
    Result := ParseCustomerDetail(Json as TJSONObject);
  finally
    Json.Free;
  end;
end;

function TCrmApi.UpdateCustomer(const AWaveId: string; ATypeId, AStatusId: Integer;
  const AAdGroup: string; AUserCount: Integer; const ANotes: string): TCustomerDetail;
begin
  var Body := TJSONObject.Create;
  try
    if ATypeId > 0 then
      Body.AddPair('type_id', TJSONNumber.Create(ATypeId))
    else
      Body.AddPair('type_id', TJSONNull.Create);
    if AStatusId > 0 then
      Body.AddPair('status_id', TJSONNumber.Create(AStatusId))
    else
      Body.AddPair('status_id', TJSONNull.Create);
    if Trim(AAdGroup) <> '' then
      Body.AddPair('ad_group', Trim(AAdGroup))
    else
      Body.AddPair('ad_group', TJSONNull.Create);
    Body.AddPair('user_count', TJSONNumber.Create(AUserCount));
    if ANotes <> '' then
      Body.AddPair('notes', ANotes)
    else
      Body.AddPair('notes', TJSONNull.Create);

    var Json := Request('PUT', '/customers/' + TNetEncoding.URL.EncodePath(AWaveId), Body);
    try
      Result := ParseCustomerDetail(Json as TJSONObject);
    finally
      Json.Free;
    end;
  finally
    Body.Free;
  end;
end;

procedure TCrmApi.DeleteCustomer(const AWaveId: string);
begin
  Request('DELETE', '/customers/' + TNetEncoding.URL.EncodePath(AWaveId)).Free;
end;

procedure TCrmApi.AddLog(const AWaveId: string; AEventDate: TDate; const ASummary: string);
begin
  var Body := TJSONObject.Create;
  try
    Body.AddPair('wave_id', AWaveId);
    Body.AddPair('event_date', FormatDateTime('yyyy-mm-dd', AEventDate));
    Body.AddPair('summary', ASummary);
    Request('POST', '/customerlog', Body).Free;
  finally
    Body.Free;
  end;
end;

{ Empty fields are sent as JSON null, so the database stores NULL rather than ''. }
function ContactBody(const AContact: TContactRec): TJSONObject;

  procedure Put(const AKey, AValue: string);
  begin
    if Trim(AValue) <> '' then
      Result.AddPair(AKey, Trim(AValue))
    else
      Result.AddPair(AKey, TJSONNull.Create);
  end;

begin
  Result := TJSONObject.Create;
  Put('name', AContact.Name);
  Put('email', AContact.Email);
  Put('phone', AContact.Phone);
  Put('job_title', AContact.JobTitle);
end;

procedure TCrmApi.AddContact(const AWaveId: string; const AContact: TContactRec);
begin
  var Body := ContactBody(AContact);
  try
    Body.AddPair('wave_id', AWaveId);
    Request('POST', '/contacts', Body).Free;
  finally
    Body.Free;
  end;
end;

procedure TCrmApi.UpdateContact(const AContact: TContactRec);
begin
  var Body := ContactBody(AContact);
  try
    Request('PUT', '/contacts/' + AContact.Id.ToString, Body).Free;
  finally
    Body.Free;
  end;
end;

procedure TCrmApi.DeleteContact(AContactId: Integer);
begin
  Request('DELETE', '/contacts/' + AContactId.ToString).Free;
end;

function TCrmApi.Emails(const ATypeName, AStatusName: string): TEmailList;
begin
  var Qs := '';
  if ATypeName <> '' then
    Qs := Qs + '&type=' + TNetEncoding.URL.EncodeQuery(ATypeName);
  if AStatusName <> '' then
    Qs := Qs + '&status=' + TNetEncoding.URL.EncodeQuery(AStatusName);
  if Qs <> '' then
    Qs := '?' + Qs.Substring(1);

  var Json := Request('GET', '/emails' + Qs);
  try
    Result.Count := JInt(Json as TJSONObject, 'count');
    Result.Bcc := JStr(Json as TJSONObject, 'bcc');
  finally
    Json.Free;
  end;
end;

function TCrmApi.SyncNow: string;
begin
  var Json := Request('POST', '/sync');
  try
    var O := Json as TJSONObject;
    Result := Format('%d fetched, %d added, %d updated, %d marked missing',
      [JInt(O, 'fetched'), JInt(O, 'added'), JInt(O, 'updated'), JInt(O, 'marked_missing')]);
  finally
    Json.Free;
  end;
end;

initialization
  GCrm := TCrmApi.Create;
  GCrm.LoadSettings;

finalization
  GCrm.Free;

end.
