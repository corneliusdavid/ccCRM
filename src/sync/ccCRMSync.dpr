program ccCRMSync;

{ Console tool: pulls customers from Wave and syncs them into the ccCRM Firebird database.

    ccCRMSync.exe                 sync Wave -> database
    ccCRMSync.exe --dry-run       fetch from Wave and list customers; no database access
    ccCRMSync.exe --businesses    list your Wave business ids (to fill in ccCRM.ini)

  Settings come from ccCRM.ini next to the exe (see ccCRM.ini.sample in the repo root).
  Exit code 0 = ok, 1 = error. }

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  FireDAC.ConsoleUI.Wait,
  ccCRM.Types in '..\shared\ccCRM.Types.pas',
  ccCRM.Config in '..\shared\ccCRM.Config.pas',
  ccCRM.WaveClient in '..\shared\ccCRM.WaveClient.pas',
  ccCRM.Data in '..\shared\ccCRM.Data.pas' {dmccCRM: TDataModule};

function HasArg(const AName: string): Boolean;
begin
  for var I := 1 to ParamCount do
    if SameText(ParamStr(I), AName) then
      Exit(True);
  Result := False;
end;

procedure Run;
begin
  var Cfg := TccCRMConfig.Load;
  var Wave := TWaveClient.Create(Cfg.WaveToken, Cfg.WaveBusinessId);
  try
    if HasArg('--businesses') then
    begin
      for var Biz in Wave.ListBusinesses do
        Writeln(Biz.Name, #9, Biz.Id);
      Exit;
    end;

    Writeln('Fetching customers from Wave...');
    var Customers := Wave.FetchCustomers;
    Writeln(Format('Wave returned %d customers.', [Length(Customers)]));

    if HasArg('--dry-run') then
    begin
      for var C in Customers do
        Writeln(Format('  %-40s %s', [C.Name, C.Email]));
      Exit;
    end;

    var Data := TdmccCRM.Create(nil);
    try
      Data.OnLog := procedure(const AMessage: string)
        begin
          Writeln(AMessage);
        end;
      Data.Connect(Cfg.Db);
      Data.SyncCustomers(Customers);
      Writeln(Format('Database now holds %d customers.', [Data.CustomerCount]));
    finally
      Data.Free;
    end;
  finally
    Wave.Free;
  end;
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
