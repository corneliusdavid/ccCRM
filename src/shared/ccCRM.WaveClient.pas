unit ccCRM.WaveClient;

{ Minimal read-only client for Wave's GraphQL API.
  Only queries are sent; there are no mutations here by design (the app never writes to Wave).
  No UI and no database dependencies, so this unit can live in a RAD Server package. }

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.JSON,
  System.Net.HttpClient, System.Net.URLClient, ccCRM.Types;

type
  EWaveError = class(EccCRMError);

  TWaveClient = class
  private
    FToken: string;
    FBusinessId: string;
    FPageSize: Integer;
    function Execute(const AQuery: string; AVariables: TJSONObject): TJSONObject;
  public
    constructor Create(const AToken, ABusinessId: string);
    function ListBusinesses: TArray<TWaveBusiness>;
    function FetchCustomers: TArray<TWaveCustomer>;
    property PageSize: Integer read FPageSize write FPageSize;
  end;

implementation

const
  WaveUrl = 'https://gql.waveapps.com/graphql/public';

  BusinessesQuery =
    'query { businesses { edges { node { id name } } } }';

  CustomersQuery =
    'query Customers($businessId: ID!, $page: Int!, $pageSize: Int!) { ' +
    'business(id: $businessId) { ' +
    'customers(page: $page, pageSize: $pageSize, sort: [NAME_ASC]) { ' +
    'pageInfo { currentPage totalPages totalCount } ' +
    'edges { node { id name firstName lastName email phone mobile website ' +
    'address { addressLine1 addressLine2 city province { code name } postalCode } ' +
    '} } } } }';

{ ---- JSON helpers: tolerate missing keys and JSON null ---- }

function ChildObj(AObj: TJSONObject; const AName: string): TJSONObject;
begin
  Result := nil;
  if AObj = nil then
    Exit;
  var V := AObj.GetValue(AName);
  if V is TJSONObject then
    Result := TJSONObject(V);
end;

function ChildArr(AObj: TJSONObject; const AName: string): TJSONArray;
begin
  Result := nil;
  if AObj = nil then
    Exit;
  var V := AObj.GetValue(AName);
  if V is TJSONArray then
    Result := TJSONArray(V);
end;

function Str(AObj: TJSONObject; const AName: string): string;
begin
  Result := '';
  if AObj = nil then
    Exit;
  var V := AObj.GetValue(AName);
  if (V <> nil) and not (V is TJSONNull) then
    Result := V.Value;
end;

function Int(AObj: TJSONObject; const AName: string; ADefault: Integer): Integer;
begin
  Result := ADefault;
  if AObj = nil then
    Exit;
  var V := AObj.GetValue(AName);
  if V is TJSONNumber then
    Result := TJSONNumber(V).AsInt;
end;

{ TWaveClient }

constructor TWaveClient.Create(const AToken, ABusinessId: string);
begin
  inherited Create;
  FToken := AToken;
  FBusinessId := ABusinessId;
  FPageSize := 50;
end;

{ Posts a GraphQL request. Takes ownership of AVariables. Returns the parsed
  response root; the caller frees it. }
function TWaveClient.Execute(const AQuery: string; AVariables: TJSONObject): TJSONObject;
begin
  if FToken = '' then
  begin
    AVariables.Free;
    raise EWaveError.Create('No Wave access token configured.');
  end;

  var RequestJson: string;
  var Body := TJSONObject.Create;
  try
    Body.AddPair('query', AQuery);
    if AVariables <> nil then
    begin
      Body.AddPair('variables', AVariables);
      AVariables := nil;  // now owned by Body
    end;
    RequestJson := Body.ToJSON;
  finally
    Body.Free;
    AVariables.Free;  // only non-nil if AddPair was never reached
  end;

  var Content: string;
  var Status: Integer;
  var Source := TStringStream.Create(RequestJson, TEncoding.UTF8);
  try
    var Http := THTTPClient.Create;
    try
      var Resp := Http.Post(WaveUrl, Source, nil, [
        TNameValuePair.Create('Authorization', 'Bearer ' + FToken),
        TNameValuePair.Create('Content-Type', 'application/json'),
        TNameValuePair.Create('Accept', 'application/json')]);
      Content := Resp.ContentAsString(TEncoding.UTF8);
      Status := Resp.StatusCode;
    finally
      Http.Free;
    end;
  finally
    Source.Free;
  end;

  var Root := TJSONObject.ParseJSONValue(Content);
  if not (Root is TJSONObject) then
  begin
    Root.Free;
    raise EWaveError.CreateFmt('Wave returned HTTP %d with an unreadable response: %s',
      [Status, Copy(Content, 1, 300)]);
  end;
  Result := TJSONObject(Root);
  try
    var Errors := ChildArr(Result, 'errors');
    if (Errors <> nil) and (Errors.Count > 0) then
      raise EWaveError.CreateFmt('Wave API error (HTTP %d): %s',
        [Status, Str(Errors.Items[0] as TJSONObject, 'message')]);
    if Status <> 200 then
      raise EWaveError.CreateFmt('Wave returned HTTP %d: %s', [Status, Copy(Content, 1, 300)]);
  except
    Result.Free;
    raise;
  end;
end;

function TWaveClient.ListBusinesses: TArray<TWaveBusiness>;
begin
  var Root := Execute(BusinessesQuery, nil);
  try
    var Edges := ChildArr(ChildObj(ChildObj(Root, 'data'), 'businesses'), 'edges');
    if Edges = nil then
      Exit(nil);
    SetLength(Result, Edges.Count);
    for var I := 0 to Edges.Count - 1 do
    begin
      var Node := ChildObj(Edges.Items[I] as TJSONObject, 'node');
      Result[I].Id := Str(Node, 'id');
      Result[I].Name := Str(Node, 'name');
    end;
  finally
    Root.Free;
  end;
end;

function TWaveClient.FetchCustomers: TArray<TWaveCustomer>;
begin
  if FBusinessId = '' then
    raise EWaveError.Create('No Wave business id configured (run with --businesses to list them).');

  var List := TList<TWaveCustomer>.Create;
  try
    var Page := 1;
    var TotalPages := 1;
    while Page <= TotalPages do
    begin
      var Vars := TJSONObject.Create;
      Vars.AddPair('businessId', FBusinessId);
      Vars.AddPair('page', TJSONNumber.Create(Page));
      Vars.AddPair('pageSize', TJSONNumber.Create(FPageSize));
      var Root := Execute(CustomersQuery, Vars);
      try
        var Customers := ChildObj(ChildObj(ChildObj(Root, 'data'), 'business'), 'customers');
        if Customers = nil then
          raise EWaveError.Create('Wave returned no customer data. Check the business id.');
        TotalPages := Int(ChildObj(Customers, 'pageInfo'), 'totalPages', 1);
        var Edges := ChildArr(Customers, 'edges');
        if Edges <> nil then
          for var I := 0 to Edges.Count - 1 do
          begin
            var Node := ChildObj(Edges.Items[I] as TJSONObject, 'node');
            var Addr := ChildObj(Node, 'address');
            var C := Default(TWaveCustomer);
            C.Id := Str(Node, 'id');
            C.Name := Str(Node, 'name');
            C.FirstName := Str(Node, 'firstName');
            C.LastName := Str(Node, 'lastName');
            C.Email := Str(Node, 'email');
            C.Phone := Str(Node, 'phone');
            C.Mobile := Str(Node, 'mobile');
            C.Website := Str(Node, 'website');
            C.Address1 := Str(Addr, 'addressLine1');
            C.Address2 := Str(Addr, 'addressLine2');
            C.City := Str(Addr, 'city');
            C.StateCode := Str(ChildObj(Addr, 'province'), 'code');
            C.PostalCode := Str(Addr, 'postalCode');
            if C.Id <> '' then
              List.Add(C);
          end;
      finally
        Root.Free;
      end;
      Inc(Page);
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

end.
