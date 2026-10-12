unit ccCRM.App.Frame.Customers;

{ Home screen: search box, type/status filters and the customer list. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.StrUtils, FMX.Types,
  FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Controls.Presentation,
  FMX.Edit,
  FMX.ListBox, FMX.Layouts, ccCRM.App.Types, ccCRM.App.Api;

type
  TCustomersFrame = class(TFrame)
    SearchEdit: TEdit;
    FilterLayout: TLayout;
    TypeCombo: TComboBox;
    StatusCombo: TComboBox;
    CountLabel: TLabel;
    List: TListBox;
    SearchTimer: TTimer;
    procedure SearchEditChangeTracking(Sender: TObject);
    procedure SearchTimerTimer(Sender: TObject);
    procedure FilterChange(Sender: TObject);
    procedure OpenButtonClick(Sender: TObject);
  private
    FAlive: IAlive;
    FLoadingFilters: Boolean;
    FLookupsLoaded: Boolean;
    FTypes: TArray<TLookup>;
    FStatuses: TArray<TLookup>;
    FOnOpen: TProc<string>;
    procedure FillList(const ARows: TArray<TCustomerRow>);
    procedure LoadLookups;
    function SelectedId(ACombo: TComboBox; const AItems: TArray<TLookup>): Integer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { Re-runs the search with the current filters. }
    procedure Reload;
    property OnOpen: TProc<string> read FOnOpen write FOnOpen;
  end;

implementation

{$R *.fmx}

constructor TCustomersFrame.Create(AOwner: TComponent);
begin
  inherited;
  FAlive := TAlive.Create;
  TypeCombo.Items.Add('All types');
  StatusCombo.Items.Add('All statuses');
  TypeCombo.ItemIndex := 0;
  StatusCombo.ItemIndex := 0;
  LoadLookups;
end;

destructor TCustomersFrame.Destroy;
begin
  FAlive.Kill;
  inherited;
end;

function TCustomersFrame.SelectedId(ACombo: TComboBox; const AItems: TArray<TLookup>): Integer;
begin
  Result := 0;
  var Index := ACombo.ItemIndex - 1;  // item 0 is "All"
  if (Index >= 0) and (Index < Length(AItems)) then
    Result := AItems[Index].Id;
end;

procedure TCustomersFrame.LoadLookups;
begin
  TAsync.Run<TLookups>(FAlive,
    function: TLookups
    begin
      Result := Crm.Lookups;
    end,
    procedure(ALookups: TLookups)
    begin
      FLoadingFilters := True;
      try
        TypeCombo.Items.Clear;
        StatusCombo.Items.Clear;
        TypeCombo.Items.Add('All types');
        StatusCombo.Items.Add('All statuses');
        FTypes := ALookups.Types;
        FStatuses := ALookups.Statuses;
        for var T in FTypes do
          TypeCombo.Items.Add(T.Name);
        for var S in FStatuses do
          StatusCombo.Items.Add(S.Name);
        TypeCombo.ItemIndex := 0;
        StatusCombo.ItemIndex := 0;
      finally
        FLoadingFilters := False;
      end;
      FLookupsLoaded := True;
      Reload;
    end,
    procedure(AError: string)
    begin
      CountLabel.Text := AError;
    end);
end;

procedure TCustomersFrame.Reload;
begin
  if not FLookupsLoaded then
  begin
    LoadLookups;  // first call, or the earlier attempt failed (e.g. settings were wrong)
    Exit;
  end;
  CountLabel.Text := 'Loading...';
  var Query := SearchEdit.Text;
  var TypeId := SelectedId(TypeCombo, FTypes);
  var StatusId := SelectedId(StatusCombo, FStatuses);
  TAsync.Run<TArray<TCustomerRow>>(FAlive,
    function: TArray<TCustomerRow>
    begin
      Result := Crm.Customers(Query, TypeId, StatusId);
    end,
    procedure(ARows: TArray<TCustomerRow>)
    begin
      FillList(ARows);
    end,
    procedure(AError: string)
    begin
      CountLabel.Text := AError;
    end);
end;

procedure TCustomersFrame.FillList(const ARows: TArray<TCustomerRow>);
begin
  List.BeginUpdate;
  try
    List.Clear;
    for var R in ARows do
    begin
      var Item := TListBoxItem.Create(List);
      Item.Parent := List;
      Item.StyleLookup := 'listboxitembottomdetail';
      Item.Height := 56;
      Item.Text := R.Name;
      Item.TagString := R.WaveId;

      var Detail := '';
      if R.TypeName <> '' then
        Detail := R.TypeName;
      if R.StatusName <> '' then
        Detail := Detail + IfThen(Detail <> '', ' - ', '') + R.StatusName;
      if R.UserCount > 0 then
        Detail := Detail + IfThen(Detail <> '', ' - ', '') + R.UserCount.ToString + ' users';
      if not R.InWave then
        Detail := Detail + IfThen(Detail <> '', ' - ', '') + 'not in Wave';
      if Detail = '' then
        Detail := 'Unclassified';
      Item.ItemData.Detail := Detail;

      // only this button opens the customer; tapping elsewhere on the row does nothing
      var Open := TButton.Create(Item);
      Open.Parent := Item;
      Open.Align := TAlignLayout.Right;
      Open.Width := 72;
      Open.Margins.Top := 8;
      Open.Margins.Bottom := 8;
      Open.Margins.Right := 8;
      Open.Text := 'Open';
      Open.TextSettings.Trimming := TTextTrimming.None;
      Open.TagString := R.WaveId;
      Open.OnClick := OpenButtonClick;
    end;
  finally
    List.EndUpdate;
  end;
  CountLabel.Text := Length(ARows).ToString + ' customers';
end;

procedure TCustomersFrame.SearchEditChangeTracking(Sender: TObject);
begin
  // wait for a pause in typing before asking the server
  SearchTimer.Enabled := False;
  SearchTimer.Enabled := True;
end;

procedure TCustomersFrame.SearchTimerTimer(Sender: TObject);
begin
  SearchTimer.Enabled := False;
  Reload;
end;

procedure TCustomersFrame.FilterChange(Sender: TObject);
begin
  if not FLoadingFilters then
    Reload;
end;

procedure TCustomersFrame.OpenButtonClick(Sender: TObject);
begin
  var Id := (Sender as TButton).TagString;
  if Assigned(FOnOpen) and (Id <> '') then
    FOnOpen(Id);
end;

end.
