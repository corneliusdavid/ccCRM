unit ccCRM.App.Frame.Emails;

{ Builds the email list for a type/status (default: Active ABS Cloud) and either copies the
  BCC string or hands it to the phone's email app. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.NetEncoding,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.ListBox, FMX.Layouts, FMX.Memo, FMX.Memo.Types,
  FMX.ScrollBox, ccCRM.App.Types, ccCRM.App.Api, ccCRM.App.Platform, ccCRM.App.Icons;

type
  TEmailsFrame = class(TFrame)
    Bar: TToolBar;
    BackButton: TSpeedButton;
    TitleLabel: TLabel;
    Form: TLayout;
    TypeCombo: TComboBox;
    StatusCombo: TComboBox;
    CountLabel: TLabel;
    ButtonLayout: TLayout;
    CopyButton: TButton;
    MailButton: TButton;
    BccMemo: TMemo;
    procedure BackButtonClick(Sender: TObject);
    procedure FilterChange(Sender: TObject);
    procedure CopyButtonClick(Sender: TObject);
    procedure MailButtonClick(Sender: TObject);
  private
    FAlive: IAlive;
    FBusy: Boolean;
    FOnBack: TProc;
    procedure LoadLookups;
    procedure Reload;
    function ComboName(ACombo: TComboBox): string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property OnBack: TProc read FOnBack write FOnBack;
  end;

implementation

{$R *.fmx}

constructor TEmailsFrame.Create(AOwner: TComponent);
begin
  inherited;
  FAlive := TAlive.Create;
  SetIcon(BackButton, TAppIcon.Back);
  TypeCombo.Items.Add('Any type');
  StatusCombo.Items.Add('Any status');
  TypeCombo.ItemIndex := 0;
  StatusCombo.ItemIndex := 0;
  LoadLookups;
end;

destructor TEmailsFrame.Destroy;
begin
  FAlive.Kill;
  inherited;
end;

{ Empty string for "Any ..." (item 0), otherwise the selected name. }
function TEmailsFrame.ComboName(ACombo: TComboBox): string;
begin
  Result := '';
  if ACombo.ItemIndex > 0 then
    Result := ACombo.Items[ACombo.ItemIndex];
end;

procedure TEmailsFrame.LoadLookups;
begin
  TAsync.Run<TLookups>(FAlive,
    function: TLookups
    begin
      Result := Crm.Lookups;
    end,
    procedure(ALookups: TLookups)
    begin
      FBusy := True;
      try
        for var T in ALookups.Types do
          TypeCombo.Items.Add(T.Name);
        for var S in ALookups.Statuses do
          StatusCombo.Items.Add(S.Name);
        // the common case: current ABS Cloud customers
        var I := TypeCombo.Items.IndexOf('ABS Cloud');
        if I >= 0 then
          TypeCombo.ItemIndex := I;
        I := StatusCombo.Items.IndexOf('Active');
        if I >= 0 then
          StatusCombo.ItemIndex := I;
      finally
        FBusy := False;
      end;
      Reload;
    end,
    procedure(AError: string)
    begin
      CountLabel.Text := AError;
    end);
end;

procedure TEmailsFrame.Reload;
begin
  CountLabel.Text := 'Loading...';
  var TypeName := ComboName(TypeCombo);
  var StatusName := ComboName(StatusCombo);
  TAsync.Run<TEmailList>(FAlive,
    function: TEmailList
    begin
      Result := Crm.Emails(TypeName, StatusName);
    end,
    procedure(AList: TEmailList)
    begin
      CountLabel.Text := AList.Count.ToString + ' addresses';
      BccMemo.Text := AList.Bcc;
    end,
    procedure(AError: string)
    begin
      CountLabel.Text := AError;
      BccMemo.Text := '';
    end);
end;

procedure TEmailsFrame.FilterChange(Sender: TObject);
begin
  if not FBusy then
    Reload;
end;

procedure TEmailsFrame.CopyButtonClick(Sender: TObject);
begin
  if BccMemo.Text <> '' then
  begin
    CopyToClipboard(BccMemo.Text);
    CountLabel.Text := 'Copied ' + CountLabel.Text;
  end;
end;

procedure TEmailsFrame.MailButtonClick(Sender: TObject);
begin
  if BccMemo.Text <> '' then
    OpenUrl('mailto:?bcc=' + TNetEncoding.URL.Encode(BccMemo.Text.Replace('; ', ',')));
end;

procedure TEmailsFrame.BackButtonClick(Sender: TObject);
begin
  if Assigned(FOnBack) then
    FOnBack();
end;

end.
