unit ccCRM.Data;

{ ccCRM data module: Firebird connection plus the Wave -> database sync.

  Designed to move into a RAD Server package unchanged:
  - no UI units and no console I/O (progress goes through OnLog),
  - connection settings are passed in (Connect), nothing is read from files here,
  - the Wave fetch is separate (ccCRM.WaveClient); this module only receives customers.

  All SQL lives in the components on the data module (see the .dfm).

  Wave-owned columns are overwritten; your columns (type, status, AD group, user
  count, notes, logo) are never touched. Rows are never deleted: customers that
  disappear from Wave get IN_WAVE = FALSE. Wave itself is never written to. }

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.Phys.FB, FireDAC.Phys.FBDef, FireDAC.Stan.Param,
  FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client, ccCRM.Types, FireDAC.Phys.IBBase;

type
  TdmccCRM = class(TDataModule)
    Conn: TFDConnection;
    FBDriver: TFDPhysFBDriverLink;
    { sync }
    qWaveIds: TFDQuery;
    qCount: TFDQuery;
    cmdUpsert: TFDQuery;
    cmdMarkMissing: TFDQuery;
    { REST API }
    qTypes: TFDQuery;
    qStatuses: TFDQuery;
    qCustomers: TFDQuery;
    qCustomer: TFDQuery;
    qContacts: TFDQuery;
    qLog: TFDQuery;
    qEmails: TFDQuery;
    cmdUpdateCustomer: TFDQuery;
    cmdAddContact: TFDQuery;
    cmdUpdateContact: TFDQuery;
    cmdDeleteContact: TFDQuery;
    cmdAddLog: TFDQuery;
    cmdUpdateLog: TFDQuery;
    cmdDeleteLog: TFDQuery;
  private
    FOnLog: TccCRMLogEvent;
    procedure DoLog(const AMessage: string);
  public
    procedure Connect(const AConfig: TccCRMDbConfig);
    { Upserts all customers in one transaction and flags the ones Wave no longer returns. }
    function SyncCustomers(const ACustomers: TArray<TWaveCustomer>): TSyncResult;
    function CustomerCount: Integer;
    property OnLog: TccCRMLogEvent read FOnLog write FOnLog;
  end;

implementation

{%CLASSGROUP 'System.Classes.TPersistent'}

{$R *.dfm}

const
  PoolDefName = 'ccCRMPool';

var
  PoolLock: TObject;

{ Empty strings from Wave are stored as NULL. }
procedure SetText(AParam: TFDParam; const AValue: string);
begin
  if AValue = '' then
    AParam.Clear
  else
    AParam.AsString := AValue;
end;

procedure TdmccCRM.DoLog(const AMessage: string);
begin
  if Assigned(FOnLog) then
    FOnLog(AMessage);
end;

{ Registers (once per process) a named, pooled FireDAC connection definition.
  A pooled TFDConnection may carry nothing but the definition name, so the design-time
  Params are cleared in Connect when AConfig.Pooled is set. }
procedure EnsurePoolDef(const AConfig: TccCRMDbConfig);
begin
  TMonitor.Enter(PoolLock);
  try
    if FDManager.ConnectionDefs.FindConnectionDef(PoolDefName) = nil then
    begin
      var Def := FDManager.ConnectionDefs.AddConnectionDef;
      Def.Name := PoolDefName;
      Def.Params.DriverID := 'FB';
      Def.Params.Database := AConfig.Database;
      Def.Params.UserName := AConfig.UserName;
      Def.Params.Password := AConfig.Password;
      Def.Params.Values['CharacterSet'] := 'UTF8';
      if AConfig.Server <> '' then
      begin
        Def.Params.Values['Server'] := AConfig.Server;
        Def.Params.Values['Protocol'] := 'TCPIP';
        if AConfig.Port > 0 then
          Def.Params.Values['Port'] := AConfig.Port.ToString;
      end;
      Def.Params.Pooled := True;
      Def.Params.PoolMaximumItems := 25;
      Def.Apply;
    end;
  finally
    TMonitor.Exit(PoolLock);
  end;
end;

procedure TdmccCRM.Connect(const AConfig: TccCRMDbConfig);
begin
  Conn.Connected := False;
  if AConfig.VendorLib <> '' then
    FBDriver.VendorLib := AConfig.VendorLib;
  if AConfig.Pooled then
  begin
    EnsurePoolDef(AConfig);
    Conn.Params.Clear;
    Conn.ConnectionDefName := PoolDefName;
  end
  else
  begin
    Conn.Params.Values['Database'] := AConfig.Database;
    Conn.Params.Values['User_Name'] := AConfig.UserName;
    Conn.Params.Values['Password'] := AConfig.Password;
    if AConfig.Server <> '' then
    begin
      Conn.Params.Values['Server'] := AConfig.Server;
      Conn.Params.Values['Protocol'] := 'TCPIP';
      if AConfig.Port > 0 then
        Conn.Params.Values['Port'] := AConfig.Port.ToString;
    end;
  end;
  Conn.Connected := True;
end;

function TdmccCRM.CustomerCount: Integer;
begin
  qCount.Open;
  try
    Result := qCount.Fields[0].AsInteger;
  finally
    qCount.Close;
  end;
end;

function TdmccCRM.SyncCustomers(const ACustomers: TArray<TWaveCustomer>): TSyncResult;
begin
  Result := Default(TSyncResult);
  Result.Fetched := Length(ACustomers);

  { Guard: an empty answer is far more likely an API problem than "all customers gone". }
  if Result.Fetched = 0 then
    raise EccCRMError.Create('Wave returned no customers; sync aborted so nobody is marked missing.');

  { One client-side stamp for both the writes and the "missing" test (no clock skew). }
  var Stamp := Now;

  var Known := TDictionary<string, Boolean>.Create;
  try
    qWaveIds.Open;
    while not qWaveIds.Eof do
    begin
      Known.AddOrSetValue(qWaveIds.Fields[0].AsString, True);
      qWaveIds.Next;
    end;
    qWaveIds.Close;

    Conn.StartTransaction;
    try
      var P := cmdUpsert.Params;
      for var C in ACustomers do
      begin
        SetText(P.ParamByName('WAVE_ID'), C.Id);
        SetText(P.ParamByName('NAME'), C.Name);
        SetText(P.ParamByName('FIRST_NAME'), C.FirstName);
        SetText(P.ParamByName('LAST_NAME'), C.LastName);
        SetText(P.ParamByName('EMAIL'), C.Email);
        SetText(P.ParamByName('PHONE'), C.Phone);
        SetText(P.ParamByName('MOBILE'), C.Mobile);
        SetText(P.ParamByName('WEBSITE'), C.Website);
        SetText(P.ParamByName('ADDRESS1'), C.Address1);
        SetText(P.ParamByName('ADDRESS2'), C.Address2);
        SetText(P.ParamByName('CITY'), C.City);
        SetText(P.ParamByName('STATE_CODE'), C.StateCode);
        SetText(P.ParamByName('POSTAL_CODE'), C.PostalCode);
        P.ParamByName('SYNCED_AT').AsDateTime := Stamp;
        cmdUpsert.ExecSQL;

        if Known.ContainsKey(C.Id) then
          Inc(Result.Updated)
        else
          Inc(Result.Added);
      end;

      cmdMarkMissing.ParamByName('SYNCED_AT').AsDateTime := Stamp;
      cmdMarkMissing.ExecSQL;
      Result.MarkedMissing := cmdMarkMissing.RowsAffected;

      Conn.Commit;
    except
      Conn.Rollback;
      raise;
    end;
  finally
    Known.Free;
  end;

  DoLog(Format('Sync done: %d fetched, %d added, %d updated, %d marked missing.',
    [Result.Fetched, Result.Added, Result.Updated, Result.MarkedMissing]));
end;

initialization
  PoolLock := TObject.Create;

finalization
  PoolLock.Free;

end.
