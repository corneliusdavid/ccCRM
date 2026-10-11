unit ccCRM.Config;

{ Settings shared by the sync tool and the RAD Server package, read from ccCRM.ini.

  By default the file is looked up beside the module this unit is compiled into
  (the exe for the console tool, the package/DLL for RAD Server), not beside the
  host process, so it works under EMS/IIS too. Pass an explicit path to override. }

interface

uses
  System.SysUtils, System.IniFiles, ccCRM.Types;

type
  TccCRMConfig = record
    WaveToken: string;
    WaveBusinessId: string;
    Db: TccCRMDbConfig;
    class function DefaultFileName: string; static;
    class function Load(const AFileName: string = ''): TccCRMConfig; static;
  end;

implementation

class function TccCRMConfig.DefaultFileName: string;
begin
  Result := ExtractFilePath(GetModuleName(HInstance)) + 'ccCRM.ini';
end;

class function TccCRMConfig.Load(const AFileName: string): TccCRMConfig;
begin
  var FileName := AFileName;
  if FileName = '' then
    FileName := DefaultFileName;
  if not FileExists(FileName) then
    raise EccCRMError.CreateFmt('Settings file not found: %s (copy ccCRM.ini.sample)', [FileName]);

  Result := Default(TccCRMConfig);
  var Ini := TIniFile.Create(FileName);
  try
    Result.WaveToken := Ini.ReadString('Wave', 'Token', '');
    Result.WaveBusinessId := Ini.ReadString('Wave', 'BusinessId', '');
    Result.Db.Server := Ini.ReadString('Database', 'Server', '');
    Result.Db.Port := Ini.ReadInteger('Database', 'Port', 0);
    Result.Db.Database := Ini.ReadString('Database', 'Database', '');
    Result.Db.UserName := Ini.ReadString('Database', 'User', 'SYSDBA');
    Result.Db.Password := Ini.ReadString('Database', 'Password', '');
    Result.Db.VendorLib := Ini.ReadString('Database', 'VendorLib', '');
  finally
    Ini.Free;
  end;
end;

end.
