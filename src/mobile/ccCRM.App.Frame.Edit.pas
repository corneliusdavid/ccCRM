unit ccCRM.App.Frame.Edit;

{ Edits your own columns of one customer: type, status, AD group, user count and notes.
  Name, email, phone and address belong to Wave and are changed there. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, FMX.Types, FMX.Controls,
  FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Controls.Presentation, FMX.Edit,
  FMX.ListBox, FMX.Layouts, FMX.Memo, FMX.Memo.Types, FMX.ScrollBox, FMX.SpinBox,
  ccCRM.App.Types, ccCRM.App.Api;

type
  TEditFrame = class(TFrame)
    Bar: TToolBar;
    CancelButton: TSpeedButton;
    SaveButton: TSpeedButton;
    TitleLabel: TLabel;
    Form: TLayout;
    TypeLabel: TLabel;
    TypeCombo: TComboBox;
    StatusLabel: TLabel;
    StatusCombo: TComboBox;
    AdLabel: TLabel;
    AdEdit: TEdit;
    UsersLabel: TLabel;
    UsersSpin: TSpinBox;
    NotesLabel: TLabel;
    NotesMemo: TMemo;
    procedure CancelButtonClick(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
  private
    FAlive: IAlive;
    FWaveId: string;
    FTypes: TArray<TLookup>;
    FStatuses: TArray<TLookup>;
    FOnCancel: TProc;
    FOnSaved: TProc;
    function SelectedId(ACombo: TComboBox; const AItems: TArray<TLookup>): Integer;
    procedure Select(ACombo: TComboBox; const AItems: TArray<TLookup>; AId: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadFrom(const ADetail: TCustomerDetail);
    property OnCancel: TProc read FOnCancel write FOnCancel;
    property OnSaved: TProc read FOnSaved write FOnSaved;
  end;

implementation

{$R *.fmx}

constructor TEditFrame.Create(AOwner: TComponent);
begin
  inherited;
  FAlive := TAlive.Create;
end;

destructor TEditFrame.Destroy;
begin
  FAlive.Kill;
  inherited;
end;

function TEditFrame.SelectedId(ACombo: TComboBox; const AItems: TArray<TLookup>): Integer;
begin
  Result := 0;
  var Index := ACombo.ItemIndex - 1;  // item 0 is "(none)"
  if (Index >= 0) and (Index < Length(AItems)) then
    Result := AItems[Index].Id;
end;

procedure TEditFrame.Select(ACombo: TComboBox; const AItems: TArray<TLookup>; AId: Integer);
begin
  ACombo.ItemIndex := 0;
  for var I := 0 to High(AItems) do
    if AItems[I].Id = AId then
      ACombo.ItemIndex := I + 1;
end;

procedure TEditFrame.LoadFrom(const ADetail: TCustomerDetail);
begin
  FWaveId := ADetail.Row.WaveId;
  TitleLabel.Text := ADetail.Row.Name;
  AdEdit.Text := ADetail.AdGroup;
  UsersSpin.Value := ADetail.Row.UserCount;
  NotesMemo.Text := ADetail.Notes;

  var L := Crm.Lookups;  // cached by the customer list; already loaded in practice
  FTypes := L.Types;
  FStatuses := L.Statuses;
  TypeCombo.Items.Clear;
  TypeCombo.Items.Add('(none)');
  for var T in FTypes do
    TypeCombo.Items.Add(T.Name);
  StatusCombo.Items.Clear;
  StatusCombo.Items.Add('(none)');
  for var S in FStatuses do
    StatusCombo.Items.Add(S.Name);
  Select(TypeCombo, FTypes, ADetail.Row.TypeId);
  Select(StatusCombo, FStatuses, ADetail.Row.StatusId);
end;

procedure TEditFrame.CancelButtonClick(Sender: TObject);
begin
  if Assigned(FOnCancel) then
    FOnCancel();
end;

procedure TEditFrame.SaveButtonClick(Sender: TObject);
begin
  SaveButton.Enabled := False;
  var Id := FWaveId;
  var TypeId := SelectedId(TypeCombo, FTypes);
  var StatusId := SelectedId(StatusCombo, FStatuses);
  var AdGroup := AdEdit.Text;
  var Users := Round(UsersSpin.Value);
  var Notes := NotesMemo.Text;
  TAsync.Run<Boolean>(FAlive,
    function: Boolean
    begin
      Crm.UpdateCustomer(Id, TypeId, StatusId, AdGroup, Users, Notes);
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
