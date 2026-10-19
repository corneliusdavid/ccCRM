unit ccCRM.App.Frame.Detail;

{ One customer: contact details, classification, notes, extra contacts and the dated log,
  all in a single scrolling list. Calling, emailing and opening the website go through small
  icon buttons at the right of a row; tapping the row itself does nothing, so a stray tap
  never starts a call.

  For a customer that is no longer in Wave the "+ Log" button becomes "Delete", which removes
  this app's copy of the obsolete record. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.StrUtils, FMX.Types,
  FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Controls.Presentation,
  FMX.ListBox, FMX.Layouts, FMX.Objects, FMX.TextLayout, FMX.DialogService, System.Math, ccCRM.App.Types, ccCRM.App.Api, ccCRM.App.Platform, ccCRM.App.Icons;

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
    function AddRow(const AText, ADetail: string; AWrap: Boolean = False): TListBoxItem;
    procedure AddLink(AItem: TListBoxItem; AIcon: TAppIcon; const AUrl: string);
    procedure LinkButtonClick(Sender: TObject);
    procedure RowApplyStyleLookup(Sender: TObject);
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
  AdTypeName = 'ABS Cloud';  // the only type with an AD group and user count

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

function TDetailFrame.AddRow(const AText, ADetail: string; AWrap: Boolean): TListBoxItem;
begin
  var Item := TListBoxItem.Create(List);
  Result := Item;
  Item.Parent := List;
  Item.StyleLookup := 'listboxitembottomdetail';
  Item.Text := AText;
  Item.ItemData.Detail := ADetail;
  Item.Height := 52;
  Item.OnApplyStyleLookup := RowApplyStyleLookup;
  if AWrap then
  begin
    Item.Tag := WrapTag;
    SizeWrappedRow(Item);  // applies the style, so RowApplyStyleLookup turns wrapping on first
  end;
end;

{ Adds an icon button at the right of AItem that opens AUrl ("tel:...", "mailto:...", "http...").
  Each new button goes to the left of the ones already there. }
procedure TDetailFrame.AddLink(AItem: TListBoxItem; AIcon: TAppIcon; const AUrl: string);
begin
  var Count := 0;
  for var I := 0 to AItem.ChildrenCount - 1 do
    if AItem.Children[I] is TSpeedButton then
      Inc(Count);

  var Button := TSpeedButton.Create(AItem);
  Button.Parent := AItem;
  Button.Align := TAlignLayout.Right;
  Button.Position.X := 10000 - 100 * Count;  // right-aligned controls are ordered by position
  Button.TagString := AUrl;
  Button.OnClick := LinkButtonClick;
  case AIcon of
    TAppIcon.Phone: Button.Text := 'Call';
    TAppIcon.Email: Button.Text := 'Email';
  else
    Button.Text := 'Open';
  end;
  SetIcon(Button, AIcon);

  RowApplyStyleLookup(AItem);  // make room for the new button now if the style is already applied
end;

procedure TDetailFrame.LinkButtonClick(Sender: TObject);
begin
  OpenUrl((Sender as TSpeedButton).TagString);
end;

{ Adjusts the row's copy of its style, so other rows are unaffected. Runs whenever the row
  (re)applies its style.
  - Wrapped rows: the style's "text" object has WordWrap off and Character trimming of its own,
    and those win over Item.WordWrap while StyledSettings includes Other, so they are switched
    on the text object itself.
  - Rows with link buttons: the text is kept clear of them, so a long email address isn't drawn
    under them. }
procedure TDetailFrame.RowApplyStyleLookup(Sender: TObject);
begin
  var Item := Sender as TListBoxItem;
  if Item.Tag = WrapTag then
  begin
    var Text := Item.FindStyleResource('text');
    if Text is TText then
    begin
      TText(Text).WordWrap := True;
      TText(Text).Trimming := TTextTrimming.None;
      TText(Text).VertTextAlign := TTextAlign.Leading;
    end;
  end;

  var Room: Single := 0;
  for var I := 0 to Item.ChildrenCount - 1 do
    if Item.Children[I] is TSpeedButton then
      Room := Room + TSpeedButton(Item.Children[I]).Width;
  for var Name in ['text', 'detail'] do
  begin
    var Part := Item.FindStyleResource(Name);
    if Part is TControl then
      TControl(Part).Margins.Right := Room;
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
      AddLink(AddRow(R.Email, 'Email'), TAppIcon.Email, 'mailto:' + R.Email);
    if R.Phone <> '' then
      AddLink(AddRow(R.Phone, 'Phone'), TAppIcon.Phone, 'tel:' + R.Phone);
    if R.Mobile <> '' then
      AddLink(AddRow(R.Mobile, 'Mobile'), TAppIcon.Phone, 'tel:' + R.Mobile);
    if FDetail.Website <> '' then
      AddLink(AddRow(FDetail.Website, 'Website'), TAppIcon.Web,
        IfThen(FDetail.Website.StartsWith('http'), '', 'http://') + FDetail.Website);
    var Address := (FDetail.Address1 + ' ' + FDetail.Address2).Trim;
    var CityLine := (R.City + ' ' + R.StateCode + ' ' + FDetail.PostalCode).Trim;
    if (Address <> '') or (CityLine <> '') then
      AddRow(IfThen(Address <> '', Address, CityLine), IfThen(Address <> '', CityLine, 'Address'));

    AddHeader('Account');
    var Account := IfThen(R.TypeName <> '', R.TypeName, 'Unclassified');
    if R.StatusName <> '' then
      Account := Account + ' - ' + R.StatusName;
    var AccountRow := AddRow(Account, 'Type and status');
    if SameText(R.StatusName, 'Active') then
      AddBadge(AccountRow, TBadge.Star)
    else if SameText(R.StatusName, 'Inactive') then
      AddBadge(AccountRow, TBadge.Frown);

    if SameText(R.TypeName, AdTypeName) then
    begin
      var AdRow := AddRow(IfThen(FDetail.AdGroup <> '', FDetail.AdGroup, 'undefined'), 'AD group');
      var Users := TLabel.Create(AdRow);
      Users.Parent := AdRow;
      Users.Align := TAlignLayout.Right;
      Users.Width := 90;
      Users.Margins.Right := 12;
      Users.HitTest := False;
      Users.TextSettings.HorzAlign := TTextAlign.Trailing;
      Users.Text := R.UserCount.ToString + IfThen(R.UserCount = 1, ' user', ' users');
    end;
    if not R.InWave then
      AddRow('No longer in Wave', 'Wave');

    if FDetail.Notes <> '' then
    begin
      AddHeader('Notes');
      AddRow(FDetail.Notes, '', True);
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
        var Row := AddRow(C.Name, Info);
        if C.Phone <> '' then
          AddLink(Row, TAppIcon.Phone, 'tel:' + C.Phone);
        if C.Email <> '' then
          AddLink(Row, TAppIcon.Email, 'mailto:' + C.Email);
      end;
    end;

    AddHeader('Log');
    for var L in FDetail.Log do
      AddRow(L.Summary, L.EventDate + IfThen(L.Manual, '', ' - automatic'), True);
  finally
    List.EndUpdate;
  end;
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
