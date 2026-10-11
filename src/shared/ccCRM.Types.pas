unit ccCRM.Types;

{ Plain types shared by the Wave client, the data module and the console app.
  No UI and no database dependencies, so this unit can live in a RAD Server package. }

interface

uses
  System.SysUtils;

type
  EccCRMError = class(Exception);

  { One customer as returned by Wave (only the fields we cache). }
  TWaveCustomer = record
    Id: string;
    Name: string;
    FirstName: string;
    LastName: string;
    Email: string;
    Phone: string;
    Mobile: string;
    Website: string;
    Address1: string;
    Address2: string;
    City: string;
    StateCode: string;   // Wave province.code, e.g. US-CA
    PostalCode: string;
  end;

  TWaveBusiness = record
    Id: string;
    Name: string;
  end;

  TSyncResult = record
    Fetched: Integer;        // customers received from Wave
    Added: Integer;          // new rows
    Updated: Integer;        // existing rows (re)written; unchanged rows log nothing
    MarkedMissing: Integer;  // rows no longer returned by Wave (IN_WAVE set to FALSE)
  end;

  TccCRMDbConfig = record
    Server: string;          // empty = local/embedded
    Port: Integer;           // 0 = default (3050)
    Database: string;
    UserName: string;
    Password: string;
    VendorLib: string;       // optional path to fbclient.dll (match Delphi's bitness)
  end;

  TccCRMLogEvent = reference to procedure(const AMessage: string);

implementation

end.
