unit ccCRM.App.Frame.Contacts;

{ A customer's contacts. The main contact comes from Wave and is shown first, read-only; the
  additional contacts below it are added (+), edited (pencil) and removed (bin) here. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.StrUtils, FMX.Types,
  FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Controls.Presentation,
  FMX.ListBox, FMX.Layouts, FMX.DialogService, ccCRM.App.Types, ccCRM.App.Api, ccCRM.App.Icons,
  ccCRM.App.Rows;

type
  TContactsFrame = class(TFrame)
    Bar: TToolBar;
    BackButton: TSpeedButton;
    AddButton: TSpeedButton;
    TitleLabel: TLabel;
    List: TListBox;
    procedure BackButtonClick(Sender: TObject);
    procedure AddButtonClick(Sender: TObject);
  private
    FAlive: IAlive;
    FWaveId: string;
    FDetail: TCustomerDetail;
    FLoaded: Boolean;
    FOnBack: TProc;
    FOnEditContact: TProc<TContactRec>;
    procedure AddHeader(const AText: string);
    function AddRow(const AText, ADetail: string): TListBoxItem;
    procedure Fill;
    procedure EditButtonClick(Sender: TObject);
    procedure DeleteButtonClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Load(const AWaveId: string);
    procedure Reload;
    property OnBack: TProc read FOnBack write FOnBack;
    { Open the editor for this contact; Id = 0 means a new one. }
    property OnEditContact: TProc<TContactRec> read FOnEditContact write FOnEditContact;
  end;

implementation

{$R *.fmx}

{ Joins the non-empty parts with " - ". }
function JoinParts(const AParts: array of string): string;
begin
  Result := '';
  for var P in AParts do
    if P <> '' then
      Result := Result + IfThen(Result <> '', ' - ', '') + P;
end;

constructor TContactsFrame.Create(AOwner: TComponent);
begin
  inherited;
  FAlive := TAlive.Create;
  SetIcon(BackButton, TAppIcon.Back);
  SetIcon(AddButton, TAppIcon.Add);
  AddButton.Enabled := False;
end;

destructor TContactsFrame.Destroy;
begin
  FAlive.Kill;
  inherited;
end;

procedure TContactsFrame.Load(const AWaveId: string);
begin
  FWaveId := AWaveId;
  Reload;
end;

procedure TContactsFrame.Reload;
begin
  var Id := FWaveId;
  TAsync.Run<TCustomerDetail>(FAlive,
    function: TCustomerDetail
    begin
      Result := Crm.Customer(Id);
    end,
    procedure(ADetail: TCustomerDetail)
    begin
      FDetail := ADetail;
      FLoaded := True;
      Fill;
    end,
    procedure(AError: string)
    begin
      ShowMessage(AError);
    end);
end;

procedure TContactsFrame.AddHeader(const AText: string);
begin
  AddGroupHeader(List, AText);
end;

function TContactsFrame.AddRow(const AText, ADetail: string): TListBoxItem;
begin
  Result := TListBoxItem.Create(List);
  Result.Parent := List;
  Result.StyleLookup := 'listboxitembottomdetail';
  Result.Text := AText;
  Result.ItemData.Detail := ADetail;
  Result.Height := 52;
end;

procedure TContactsFrame.Fill;
begin
  var R := FDetail.Row;
  TitleLabel.Text := R.Name;
  AddButton.Enabled := True;

  List.BeginUpdate;
  try
    List.Clear;

    AddHeader('Main contact (from Wave)');
    var MainName := (R.FirstName + ' ' + R.LastName).Trim;
    var MainInfo := JoinParts([R.Email, R.Phone, R.Mobile]);
    AddRow(IfThen(MainName <> '', MainName, 'None in Wave'),
      IfThen(MainInfo <> '', MainInfo, 'Change it in Wave'));

    AddHeader('Other contacts');
    if Length(FDetail.Contacts) = 0 then
      AddRow('None yet', 'Tap + to add one');
    for var I := 0 to High(FDetail.Contacts) do
    begin
      var C := FDetail.Contacts[I];
      var Item := AddRow(IfThen(C.Name <> '', C.Name, '(no name)'),
        JoinParts([C.JobTitle, C.Email, C.Phone]));
      // Tag is the index into FDetail.Contacts; the bin goes rightmost, the pencil beside it
      AddRowButton(Item, TAppIcon.Delete, 'Delete', DeleteButtonClick).Tag := I;
      AddRowButton(Item, TAppIcon.Edit, 'Edit', EditButtonClick).Tag := I;
    end;
  finally
    List.EndUpdate;
  end;
end;

procedure TContactsFrame.BackButtonClick(Sender: TObject);
begin
  if Assigned(FOnBack) then
    FOnBack();
end;

procedure TContactsFrame.AddButtonClick(Sender: TObject);
begin
  if FLoaded and Assigned(FOnEditContact) then
    FOnEditContact(Default(TContactRec));
end;

procedure TContactsFrame.EditButtonClick(Sender: TObject);
begin
  var Index := (Sender as TSpeedButton).Tag;
  if (Index <= High(FDetail.Contacts)) and Assigned(FOnEditContact) then
    FOnEditContact(FDetail.Contacts[Index]);
end;

procedure TContactsFrame.DeleteButtonClick(Sender: TObject);
begin
  var Index := (Sender as TSpeedButton).Tag;
  if Index > High(FDetail.Contacts) then
    Exit;
  var C := FDetail.Contacts[Index];
  var Alive := FAlive;
  TDialogService.MessageDialog(
    Format('Delete the contact %s?', [IfThen(C.Name <> '', C.Name, '(no name)')]),
    TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0,
    procedure(const AResult: TModalResult)
    begin
      if (AResult <> mrYes) or not Alive.Alive then
        Exit;
      TAsync.Run<Boolean>(Alive,
        function: Boolean
        begin
          Crm.DeleteContact(C.Id);
          Result := True;
        end,
        procedure(ADone: Boolean)
        begin
          Reload;
        end,
        procedure(AError: string)
        begin
          ShowMessage(AError);
        end);
    end);
end;

end.
