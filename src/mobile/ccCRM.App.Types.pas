unit ccCRM.App.Types;

{ Records mirroring the RAD Server JSON, plus null-tolerant JSON readers.
  Keys are the lower-case column names the server sends (see README, RAD Server section). }

interface

uses
  System.SysUtils, System.JSON;

type
  TLookup = record
    Id: Integer;
    Name: string;
  end;

  TLookups = record
    Types: TArray<TLookup>;
    Statuses: TArray<TLookup>;
  end;

  TCustomerRow = record
    WaveId: string;
    Name: string;
    FirstName: string;
    LastName: string;
    Email: string;
    Phone: string;
    Mobile: string;
    City: string;
    StateCode: string;
    TypeId: Integer;       // 0 = unclassified
    TypeName: string;
    StatusId: Integer;     // 0 = unclassified
    StatusName: string;
    UserCount: Integer;
    InWave: Boolean;
  end;

  TContactRec = record
    Id: Integer;
    Name: string;
    Email: string;
    Phone: string;
    JobTitle: string;
  end;

  TLogEntry = record
    Id: Integer;
    EventDate: string;     // yyyy-mm-dd
    Summary: string;
    Manual: Boolean;       // automatic entries can't be edited or deleted
  end;

  TCustomerDetail = record
    Row: TCustomerRow;
    Website: string;
    Address1: string;
    Address2: string;
    PostalCode: string;
    AdGroup: string;
    Notes: string;
    Contacts: TArray<TContactRec>;
    Log: TArray<TLogEntry>;
  end;

  TEmailList = record
    Count: Integer;
    Bcc: string;           // "a@x; b@y"
  end;

function JStr(AObj: TJSONObject; const AName: string): string;
function JInt(AObj: TJSONObject; const AName: string): Integer;
function JBool(AObj: TJSONObject; const AName: string): Boolean;

function ParseCustomerRow(AObj: TJSONObject): TCustomerRow;
function ParseCustomerDetail(AObj: TJSONObject): TCustomerDetail;
function ParseLookupArray(AArr: TJSONArray; const AIdKey: string): TArray<TLookup>;

implementation

uses
  System.Generics.Collections;

function JStr(AObj: TJSONObject; const AName: string): string;
begin
  Result := '';
  if AObj = nil then
    Exit;
  var V := AObj.GetValue(AName);
  if (V <> nil) and not (V is TJSONNull) then
    Result := V.Value;
end;

function JInt(AObj: TJSONObject; const AName: string): Integer;
begin
  Result := StrToIntDef(JStr(AObj, AName), 0);
end;

function JBool(AObj: TJSONObject; const AName: string): Boolean;
begin
  Result := False;
  if AObj = nil then
    Exit;
  var V := AObj.GetValue(AName);
  if V is TJSONBool then
    Result := TJSONBool(V).AsBoolean;
end;

function ParseCustomerRow(AObj: TJSONObject): TCustomerRow;
begin
  Result := Default(TCustomerRow);
  Result.WaveId := JStr(AObj, 'wave_id');
  Result.Name := JStr(AObj, 'name');
  Result.FirstName := JStr(AObj, 'first_name');
  Result.LastName := JStr(AObj, 'last_name');
  Result.Email := JStr(AObj, 'email');
  Result.Phone := JStr(AObj, 'phone');
  Result.Mobile := JStr(AObj, 'mobile');
  Result.City := JStr(AObj, 'city');
  Result.StateCode := JStr(AObj, 'state_code');
  Result.TypeId := JInt(AObj, 'type_id');
  Result.TypeName := JStr(AObj, 'type_name');
  Result.StatusId := JInt(AObj, 'status_id');
  Result.StatusName := JStr(AObj, 'status_name');
  Result.UserCount := JInt(AObj, 'user_count');
  Result.InWave := JBool(AObj, 'in_wave');
end;

function ParseCustomerDetail(AObj: TJSONObject): TCustomerDetail;
begin
  Result := Default(TCustomerDetail);
  Result.Row := ParseCustomerRow(AObj);
  Result.Website := JStr(AObj, 'website');
  Result.Address1 := JStr(AObj, 'address1');
  Result.Address2 := JStr(AObj, 'address2');
  Result.PostalCode := JStr(AObj, 'postal_code');
  Result.AdGroup := JStr(AObj, 'ad_group');
  Result.Notes := JStr(AObj, 'notes');

  var Contacts := AObj.GetValue('contacts');
  if Contacts is TJSONArray then
  begin
    SetLength(Result.Contacts, TJSONArray(Contacts).Count);
    for var I := 0 to High(Result.Contacts) do
    begin
      var O := TJSONArray(Contacts).Items[I] as TJSONObject;
      Result.Contacts[I].Id := JInt(O, 'contact_id');
      Result.Contacts[I].Name := JStr(O, 'name');
      Result.Contacts[I].Email := JStr(O, 'email');
      Result.Contacts[I].Phone := JStr(O, 'phone');
      Result.Contacts[I].JobTitle := JStr(O, 'job_title');
    end;
  end;

  var Log := AObj.GetValue('log');
  if Log is TJSONArray then
  begin
    SetLength(Result.Log, TJSONArray(Log).Count);
    for var I := 0 to High(Result.Log) do
    begin
      var O := TJSONArray(Log).Items[I] as TJSONObject;
      Result.Log[I].Id := JInt(O, 'log_id');
      Result.Log[I].EventDate := JStr(O, 'event_date');
      Result.Log[I].Summary := JStr(O, 'summary');
      Result.Log[I].Manual := JStr(O, 'entry_source') = 'M';
    end;
  end;
end;

function ParseLookupArray(AArr: TJSONArray; const AIdKey: string): TArray<TLookup>;
begin
  SetLength(Result, 0);
  if AArr = nil then
    Exit;
  SetLength(Result, AArr.Count);
  for var I := 0 to AArr.Count - 1 do
  begin
    var O := AArr.Items[I] as TJSONObject;
    Result[I].Id := JInt(O, AIdKey);
    Result[I].Name := JStr(O, 'name');
  end;
end;

end.
