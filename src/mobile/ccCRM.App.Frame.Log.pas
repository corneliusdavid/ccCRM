unit ccCRM.App.Frame.Log;

{ Adds a manual entry to a customer's log. The date defaults to today; set it earlier
  to record history ("signed up 04-29-2020"). }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, FMX.Types, FMX.Controls,
  FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Controls.Presentation,
  FMX.Layouts, FMX.Memo, FMX.Memo.Types, FMX.ScrollBox, FMX.DateTimeCtrls,
  ccCRM.App.Types, ccCRM.App.Api;

type
  TLogFrame = class(TFrame)
    Bar: TToolBar;
    CancelButton: TSpeedButton;
    SaveButton: TSpeedButton;
    TitleLabel: TLabel;
    Form: TLayout;
    DateLabel: TLabel;
    DateEdit: TDateEdit;
    SummaryLabel: TLabel;
    SummaryMemo: TMemo;
    procedure CancelButtonClick(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
  private
    FAlive: IAlive;
    FWaveId: string;
    FOnCancel: TProc;
    FOnSaved: TProc;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Start(const AWaveId: string);
    property OnCancel: TProc read FOnCancel write FOnCancel;
    property OnSaved: TProc read FOnSaved write FOnSaved;
  end;

implementation

{$R *.fmx}

constructor TLogFrame.Create(AOwner: TComponent);
begin
  inherited;
  FAlive := TAlive.Create;
  DateEdit.Date := Date;
end;

destructor TLogFrame.Destroy;
begin
  FAlive.Kill;
  inherited;
end;

procedure TLogFrame.Start(const AWaveId: string);
begin
  FWaveId := AWaveId;
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
  var When := DateEdit.Date;
  TAsync.Run<Boolean>(FAlive,
    function: Boolean
    begin
      Crm.AddLog(Id, When, Summary);
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

end.
