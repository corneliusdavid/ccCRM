unit ccCRM.App.Frame.Log;

{ Adds a manual entry to a customer's log, or changes or deletes an existing manual entry.
  A new entry's date defaults to today; set it earlier to record history ("signed up
  04-29-2020"). }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.StrUtils, FMX.Types,
  FMX.Controls, FMX.DialogService,
  FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Controls.Presentation,
  FMX.Layouts, FMX.Memo, FMX.Memo.Types, FMX.ScrollBox, FMX.DateTimeCtrls,
  ccCRM.App.Types, ccCRM.App.Api, ccCRM.App.Icons;

type
  TLogFrame = class(TFrame)
    Bar: TToolBar;
    CancelButton: TSpeedButton;
    SaveButton: TSpeedButton;
    DeleteButton: TSpeedButton;
    TitleLabel: TLabel;
    Form: TLayout;
    DateLabel: TLabel;
    DateEdit: TDateEdit;
    SummaryLabel: TLabel;
    SummaryMemo: TMemo;
    procedure CancelButtonClick(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
    procedure DeleteButtonClick(Sender: TObject);
  private
    FAlive: IAlive;
    FWaveId: string;
    FLogId: Integer;
    FOnCancel: TProc;
    FOnSaved: TProc;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { AEntry.Id = 0 adds a new entry to the customer with this Wave id. }
    procedure Start(const AWaveId: string; const AEntry: TLogEntry);
    property OnCancel: TProc read FOnCancel write FOnCancel;
    { The entry was added, changed or deleted. }
    property OnSaved: TProc read FOnSaved write FOnSaved;
  end;

implementation

{$R *.fmx}

constructor TLogFrame.Create(AOwner: TComponent);
begin
  inherited;
  FAlive := TAlive.Create;
  SetIcon(CancelButton, TAppIcon.Cancel);
  SetIcon(SaveButton, TAppIcon.Save);
  SetIcon(DeleteButton, TAppIcon.Delete);
  DateEdit.Date := Date;
end;

destructor TLogFrame.Destroy;
begin
  FAlive.Kill;
  inherited;
end;

{ yyyy-mm-dd as sent by the server; today if it can't be read. }
function ParseIsoDate(const AText: string): TDate;
begin
  var D: TDateTime;
  if TryEncodeDate(StrToIntDef(Copy(AText, 1, 4), 0), StrToIntDef(Copy(AText, 6, 2), 0),
    StrToIntDef(Copy(AText, 9, 2), 0), D) then
    Result := D
  else
    Result := Date;
end;

procedure TLogFrame.Start(const AWaveId: string; const AEntry: TLogEntry);
begin
  FWaveId := AWaveId;
  FLogId := AEntry.Id;
  if FLogId = 0 then
    Exit;  // new entry: today's date and an empty summary

  TitleLabel.Text := 'Edit log entry';
  DateEdit.Date := ParseIsoDate(AEntry.EventDate);
  SummaryMemo.Text := AEntry.Summary;
  DeleteButton.Visible := True;
  // keep Delete left of Save (right-aligned controls are ordered by position), and the title
  // centred between Cancel on the left and the two buttons on the right
  DeleteButton.Position.X := 0;
  SaveButton.Position.X := Bar.Width;
  TitleLabel.Margins.Left := DeleteButton.Width;
end;

procedure TLogFrame.CancelButtonClick(Sender: TObject);
begin
  if Assigned(FOnCancel) then
    FOnCancel();
end;

procedure TLogFrame.SaveButtonClick(Sender: TObject);
begin
  var Summary := Trim(SummaryMemo.Text);
  if Summary = '' then
  begin
    ShowMessage('Write what happened first.');
    Exit;
  end;
  SaveButton.Enabled := False;
  var Id := FWaveId;
  var LogId := FLogId;
  var When := DateEdit.Date;
  TAsync.Run<Boolean>(FAlive,
    function: Boolean
    begin
      if LogId = 0 then
        Crm.AddLog(Id, When, Summary)
      else
        Crm.UpdateLog(LogId, When, Summary);
      Result := True;
    end,
    procedure(AOk: Boolean)
    begin
      if Assigned(FOnSaved) then
        FOnSaved();
    end,
    procedure(AError: string)
    begin
      SaveButton.Enabled := True;
      ShowMessage(AError);
    end);
end;

procedure TLogFrame.DeleteButtonClick(Sender: TObject);
begin
  var LogId := FLogId;
  var Alive := FAlive;
  TDialogService.MessageDialog('Delete this log entry?', TMsgDlgType.mtConfirmation,
    [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0,
    procedure(const AResult: TModalResult)
    begin
      if (AResult <> mrYes) or not Alive.Alive then
        Exit;
      DeleteButton.Enabled := False;
      SaveButton.Enabled := False;
      TAsync.Run<Boolean>(Alive,
        function: Boolean
        begin
          Crm.DeleteLog(LogId);
          Result := True;
        end,
        procedure(AOk: Boolean)
        begin
          if Assigned(FOnSaved) then
            FOnSaved();
        end,
        procedure(AError: string)
        begin
          DeleteButton.Enabled := True;
          SaveButton.Enabled := True;
          ShowMessage(AError);
        end);
    end);
end;

end.
