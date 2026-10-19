unit ccCRM.App.Frame.Detail;

{ One customer: contact details (tap to call / email), classification, notes, extra contacts
  and the dated log, all in a single scrolling list.

  For a customer that is no longer in Wave the "+ Log" button becomes "Delete", which removes
  this app's copy of the obsolete record. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.StrUtils, FMX.Types,
  FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Controls.Presentation,
  FMX.ListBox, FMX.Layouts, FMX.TextLayout, FMX.DialogService, System.Math, ccCRM.App.Types, ccCRM.App.Api, ccCRM.App.Platform, ccCRM.App.Icons;

type
  TDetailFrame = class(TFrame)
    Bar: TToolBar;
    BackButton: TSpeedButton;
    LogButton: TSpeedButton;
    EditButton: TSpeedButton;
    TitleLabel: TLabel;
    List: TListBox;
    procedure BackButtonClick(Sender: TObject);
    procedure EditButtonClick(Sender: TObject);
    procedure LogButtonClick(Sender: TObject);
    procedure ListItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
    procedure ListResize(Sender: TObject);
  private
    FAlive: IAlive;
    FWaveId: string;
    FDetail: TCustomerDetail;
    FLoaded: Boolean;
    FOnBack: TProc;
    FOnEdit: TProc<TCustomerDetail>;
    FOnAddLog: TProc<string>;
    FOnDeleted: TProc;
    procedure AddHeader(const AText: string);
    procedure AddRow(const AText, ADetail: string; const AAction: string = ''; AWrap: Boolean = False);
    procedure SizeWrappedRow(AItem: TListBoxItem);
    procedure Fill;
    procedure DeleteCustomer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Load(const AWaveId: string);
    procedure Reload;
    property OnBack: TProc read FOnBack write FOnBack;
    property OnEdit: TProc<TCustomerDetail> read FOnEdit write FOnEdit;
    property OnAddLog: TProc<string> read FOnAddLog write FOnAddLog;
    { The customer was deleted; the frame should be closed. }
    property OnDeleted: TProc read FOnDeleted write FOnDeleted;
  end;

implementation

{$R *.fmx}

const
  WrapTag = 1;  // Tag of rows whose height follows their word-wrapped text

constructor TDetailFrame.Create(AOwner: TComponent);
begin
  inherited;
  FAlive := TAlive.Create;
  SetIcon(BackButton, TAppIcon.Back);
  SetIcon(EditButton, TAppIcon.Edit);
  EditButton.Enabled := False;
  LogButton.Enabled := False;
  List.OnResize := ListResize;
end;

destructor TDetailFrame.Destroy;
begin
  FAlive.Kill;
  inherited;
end;

procedure TDetailFrame.Load(const AWaveId: string);
begin
  FWaveId := AWaveId;
  Reload;
end;

procedure TDetailFrame.Reload;
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

procedure TDetailFrame.AddHeader(const AText: string);
begin
  var H := TListBoxGroupHeader.Create(List);
  H.Parent := List;
  H.Text := AText;
end;

{ AAction is "tel:..." or "mailto:..." and is opened when the row is tapped. }
procedure TDetailFrame.AddRow(const AText, ADetail, AAction: string; AWrap: Boolean);
begin
  var Item := TListBoxItem.Create(List);
  Item.Parent := List;
  Item.StyleLookup := 'listboxitembottomdetail';
  Item.Text := AText;
  Item.ItemData.Detail := ADetail;
  Item.TagString := AAction;
  Item.Height := 52;
  if AWrap then
  begin
    Item.WordWrap := True;
    Item.Tag := WrapTag;
    SizeWrappedRow(Item);
  end;
end;

{ Sets a word-wrapped row's height to fit its text, including line breaks, at the list's
  current width. }
procedure TDetailFrame.SizeWrappedRow(AItem: TListBoxItem);
const
  SidePadding = 32;  // item padding plus room for a scroll bar
  ExtraHeight = 34;  // the detail line under the text, plus top and bottom padding
begin
  AItem.ApplyStyleLookup;  // so the font is the style's, not the default
  var Layout := TTextLayoutManager.DefaultTextLayout.Create;
  try
    Layout.BeginUpdate;
    try
      Layout.Font := AItem.ResultingTextSettings.Font;
      Layout.WordWrap := True;
      Layout.MaxSize := TPointF.Create(Max(List.Width - SidePadding, 100), 100000);
      Layout.Text := AItem.Text;
    finally
      Layout.EndUpdate;
    end;
    AItem.Height := Ceil(Layout.Height) + ExtraHeight;
  finally
    Layout.Free;
  end;
end;

{ Rotating the phone or resizing the window changes how the long rows wrap. }
procedure TDetailFrame.ListResize(Sender: TObject);
begin
  for var I := 0 to List.Count - 1 do
    if List.ListItems[I].Tag = WrapTag then
      SizeWrappedRow(List.ListItems[I]);
end;

procedure TDetailFrame.Fill;
begin
  var R := FDetail.Row;
  TitleLabel.Text := R.Name;
  EditButton.Enabled := True;
  LogButton.Enabled := True;
  LogButton.Text := IfThen(R.InWave, '+ Log', 'Delete');

  List.BeginUpdate;
  try
    List.Clear;

    AddHeader('Contact');
    if (R.FirstName <> '') or (R.LastName <> '') then
      AddRow((R.FirstName + ' ' + R.LastName).Trim, 'Main contact');
    if R.Email <> '' then
      AddRow(R.Email, 'Email', 'mailto:' + R.Email);
    if R.Phone <> '' then
      AddRow(R.Phone, 'Phone', 'tel:' + R.Phone);
    if R.Mobile <> '' then
      AddRow(R.Mobile, 'Mobile', 'tel:' + R.Mobile);
    if FDetail.Website <> '' then
      AddRow(FDetail.Website, 'Website', IfThen(FDetail.Website.StartsWith('http'), '', 'http://') + FDetail.Website);
    var Address := (FDetail.Address1 + ' ' + FDetail.Address2).Trim;
    var CityLine := (R.City + ' ' + R.StateCode + ' ' + FDetail.PostalCode).Trim;
    if (Address <> '') or (CityLine <> '') then
      AddRow(IfThen(Address <> '', Address, CityLine), IfThen(Address <> '', CityLine, 'Address'));

    AddHeader('Account');
    AddRow(IfThen(R.TypeName <> '', R.TypeName, 'Unclassified'), 'Type');
    AddRow(IfThen(R.StatusName <> '', R.StatusName, 'Unclassified'), 'Status');
    AddRow(R.UserCount.ToString, 'Users');
    if FDetail.AdGroup <> '' then
      AddRow(FDetail.AdGroup, 'AD group');
    if not R.InWave then
      AddRow('No longer in Wave', 'Wave');

    if FDetail.Notes <> '' then
    begin
      AddHeader('Notes');
      AddRow(FDetail.Notes, '', '', True);
    end;

    if Length(FDetail.Contacts) > 0 then
    begin
      AddHeader('People');
      for var C in FDetail.Contacts do
      begin
        var Info := C.JobTitle;
        if C.Email <> '' then
          Info := Info + IfThen(Info <> '', ' - ', '') + C.Email;
        if C.Phone <> '' then
          Info := Info + IfThen(Info <> '', ' - ', '') + C.Phone;
        var Action := '';
        if C.Phone <> '' then
          Action := 'tel:' + C.Phone
        else if C.Email <> '' then
          Action := 'mailto:' + C.Email;
        AddRow(C.Name, Info, Action);
      end;
    end;

    AddHeader('Log');
    for var L in FDetail.Log do
      AddRow(L.Summary, L.EventDate + IfThen(L.Manual, '', ' - automatic'), '', True);
  finally
    List.EndUpdate;
  end;
end;

procedure TDetailFrame.ListItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
begin
  if Item.TagString <> '' then
    OpenUrl(Item.TagString);
end;

procedure TDetailFrame.BackButtonClick(Sender: TObject);
begin
  if Assigned(FOnBack) then
    FOnBack();
end;

procedure TDetailFrame.EditButtonClick(Sender: TObject);
begin
  if FLoaded and Assigned(FOnEdit) then
    FOnEdit(FDetail);
end;

procedure TDetailFrame.LogButtonClick(Sender: TObject);
begin
  if not FLoaded then
    Exit;
  if not FDetail.Row.InWave then
    DeleteCustomer
  else if Assigned(FOnAddLog) then
    FOnAddLog(FWaveId);
end;

{ Asks first: the customer's notes, contacts and log go with it. }
procedure TDetailFrame.DeleteCustomer;
begin
  var Id := FWaveId;
  var Alive := FAlive;
  TDialogService.MessageDialog(
    Format('Delete %s? It is no longer in Wave; its notes, contacts and log will be removed too.',
      [FDetail.Row.Name]),
    TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0,
    procedure(const AResult: TModalResult)
    begin
      if (AResult <> mrYes) or not Alive.Alive then
        Exit;
      LogButton.Enabled := False;
      EditButton.Enabled := False;
      TAsync.Run<Boolean>(Alive,
        function: Boolean
        begin
          Crm.DeleteCustomer(Id);
          Result := True;
        end,
        procedure(ADone: Boolean)
        begin
          if Assigned(FOnDeleted) then
            FOnDeleted();
        end,
        procedure(AError: string)
        begin
          LogButton.Enabled := True;
          EditButton.Enabled := True;
          ShowMessage(AError);
        end);
    end);
end;

end.
