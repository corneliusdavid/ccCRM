unit ccCRM.Server.Json;

{ Dataset <-> JSON helpers for the REST resources. Field names become lower-case keys. }

interface

uses
  System.SysUtils, System.JSON, System.DateUtils, Data.DB, FireDAC.Stan.Param,
  FireDAC.Comp.Client;

{ The current row as an object. }
function RowToJson(ADataSet: TDataSet): TJSONObject;
{ All rows from the current position to the end, as an array of objects. }
function RowsToJson(ADataSet: TDataSet): TJSONArray;
{ Opens the query (parameters already set), returns all rows as an array, and closes it. }
function QueryToJson(AQuery: TFDQuery): TJSONArray;
{ Sets a parameter from a JSON value; JSON null (or nil) clears it. Raises EConvertError on bad data. }
procedure ParamFromJson(AParam: TFDParam; AValue: TJSONValue);

implementation

function RowToJson(ADataSet: TDataSet): TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    for var F in ADataSet.Fields do
    begin
      var Key := LowerCase(F.FieldName);
      if F.IsNull then
        Result.AddPair(Key, TJSONNull.Create)
      else
        case F.DataType of
          ftSmallint, ftInteger, ftWord, ftShortint, ftByte, ftLargeint, ftAutoInc:
            Result.AddPair(Key, TJSONNumber.Create(F.AsLargeInt));
          ftBoolean:
            Result.AddPair(Key, TJSONBool.Create(F.AsBoolean));
          ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftExtended, ftSingle:
            Result.AddPair(Key, TJSONNumber.Create(F.AsFloat));
          ftDate:
            Result.AddPair(Key, FormatDateTime('yyyy-mm-dd', F.AsDateTime));
          ftDateTime, ftTimeStamp:
            Result.AddPair(Key, DateToISO8601(F.AsDateTime, False));
        else
          Result.AddPair(Key, F.AsString);
        end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function RowsToJson(ADataSet: TDataSet): TJSONArray;
begin
  Result := TJSONArray.Create;
  try
    while not ADataSet.Eof do
    begin
      Result.AddElement(RowToJson(ADataSet));
      ADataSet.Next;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function QueryToJson(AQuery: TFDQuery): TJSONArray;
begin
  AQuery.Open;
  try
    Result := RowsToJson(AQuery);
  finally
    AQuery.Close;
  end;
end;

procedure ParamFromJson(AParam: TFDParam; AValue: TJSONValue);
begin
  if (AValue = nil) or (AValue is TJSONNull) then
  begin
    AParam.Clear;
    Exit;
  end;
  case AParam.DataType of
    ftSmallint, ftInteger, ftLargeint:
      AParam.AsLargeInt := StrToInt64(AValue.Value);
    ftDate:
      AParam.AsDateTime := Trunc(ISO8601ToDate(AValue.Value, False));
    ftDateTime:
      AParam.AsDateTime := ISO8601ToDate(AValue.Value, False);
  else
    AParam.AsString := AValue.Value;
  end;
end;

end.
