unit ccCRM.App.Frame.Detail;

{ One customer: contact details (tap to call / email), classification, notes, extra contacts
  and the dated log, all in a single scrolling list. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.StrUtils, FMX.Types,
  FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Controls.Presentation,
  FMX.ListBox, FMX.Layouts, ccCRM.App.Types, ccCRM.App.Api, ccCRM.App.Platform;

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
  private
    FAlive: IAlive;
    FWaveId: string;
    FDetail: TCustomerDetail;
    FLoaded: Boolean;
    FOnBack: TProc;
    FOnEdit: TProc<TCustomerDetail>;
    FOnAddLog: TProc<string>;
    procedure AddHeader(const AText: string);
    procedure AddRow(const AText, ADetail: string; const AAction: string = ''; AWrap: Boolean = False);
    procedure Fill;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Load(const AWaveId: string);
    procedure Reload;
    property OnBack: TProc read FOnBack write FOnBack;
    property OnEdit: TProc<TCustomerDetail> read FOnEdit write FOnEdit;
    property OnAddLog: TProc<string> read FOnAddLog write FOnAddLog;
  end;

implementation

{$R *.fmx}

constructor TDetailFrame.Create(AOwner: TComponent);
begin
  inherited;
  FAlive := TAlive.Create;
  EditButton.Enabled := False;
  LogButton.Enabled := False;
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
    Item.Height := 36 + 20 * (Length(AText) div 34 + 1);
  end;
end;

procedure TDetailFrame.Fill;
begin
  var R := FDetail.Row;
  TitleLabel.Text := R.Name;
  EditButton.Enabled := True;
  LogButton.Enabled := True;

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
  if FLoaded and Assigned(FOnAddLog) then
    FOnAddLog(FWaveId);
end;

end.
