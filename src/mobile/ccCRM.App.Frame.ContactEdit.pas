unit ccCRM.App.Frame.ContactEdit;

{ Adds or edits one additional contact of a customer. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.StrUtils, FMX.Types, FMX.Controls,
  FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Controls.Presentation,
  FMX.Layouts, FMX.Edit, ccCRM.App.Types, ccCRM.App.Api, ccCRM.App.Icons;

type
  TContactEditFrame = class(TFrame)
    Bar: TToolBar;
    CancelButton: TSpeedButton;
    SaveButton: TSpeedButton;
    TitleLabel: TLabel;
    Form: TLayout;
    NameLabel: TLabel;
    NameEdit: TEdit;
    JobLabel: TLabel;
    JobEdit: TEdit;
    EmailLabel: TLabel;
    EmailEdit: TEdit;
    PhoneLabel: TLabel;
    PhoneEdit: TEdit;
    procedure CancelButtonClick(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
  private
    FAlive: IAlive;
    FWaveId: string;
    FContactId: Integer;
    FOnCancel: TProc;
    FOnSaved: TProc;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { AContact.Id = 0 adds a new contact to the customer with this Wave id. }
    procedure Start(const AWaveId: string; const AContact: TContactRec);
    property OnCancel: TProc read FOnCancel write FOnCancel;
    property OnSaved: TProc read FOnSaved write FOnSaved;
  end;

implementation

{$R *.fmx}

constructor TContactEditFrame.Create(AOwner: TComponent);
begin
  inherited;
  FAlive := TAlive.Create;
  SetIcon(CancelButton, TAppIcon.Cancel);
  SetIcon(SaveButton, TAppIcon.Save);
end;

destructor TContactEditFrame.Destroy;
begin
  FAlive.Kill;
  inherited;
end;

procedure TContactEditFrame.Start(const AWaveId: string; const AContact: TContactRec);
begin
  FWaveId := AWaveId;
  FContactId := AContact.Id;
  TitleLabel.Text := IfThen(FContactId = 0, 'New contact', 'Edit contact');
  NameEdit.Text := AContact.Name;
  JobEdit.Text := AContact.JobTitle;
  EmailEdit.Text := AContact.Email;
  PhoneEdit.Text := AContact.Phone;
end;

procedure TContactEditFrame.CancelButtonClick(Sender: TObject);
begin
  if Assigned(FOnCancel) then
    FOnCancel();
end;

procedure TContactEditFrame.SaveButtonClick(Sender: TObject);
begin
  var C := Default(TContactRec);
  C.Id := FContactId;
  C.Name := Trim(NameEdit.Text);
  C.JobTitle := Trim(JobEdit.Text);
  C.Email := Trim(EmailEdit.Text);
  C.Phone := Trim(PhoneEdit.Text);
  if C.Name = '' then
  begin
    ShowMessage('Enter a name first.');
    Exit;
  end;
  SaveButton.Enabled := False;
  var Id := FWaveId;
  TAsync.Run<Boolean>(FAlive,
    function: Boolean
    begin
      if C.Id = 0 then
        Crm.AddContact(Id, C)
      else
        Crm.UpdateContact(C);
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
