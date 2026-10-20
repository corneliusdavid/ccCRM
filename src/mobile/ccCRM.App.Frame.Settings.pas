unit ccCRM.App.Frame.Settings;

{ Server address and RAD Server application credentials, plus a connection test and a
  "sync from Wave now" button (calls the sync resource on the server). }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, FMX.Types, FMX.Controls,
  FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Controls.Presentation, FMX.Edit,
  FMX.Layouts, ccCRM.App.Types, ccCRM.App.Api, ccCRM.App.Icons;

type
  TSettingsFrame = class(TFrame)
    Bar: TToolBar;
    BackButton: TSpeedButton;
    SaveButton: TSpeedButton;
    TitleLabel: TLabel;
    Form: TLayout;
    UrlLabel: TLabel;
    UrlEdit: TEdit;
    IdLabel: TLabel;
    IdEdit: TEdit;
    SecretLabel: TLabel;
    SecretEdit: TEdit;
    TestButton: TButton;
    SyncButton: TButton;
    ResultLabel: TLabel;
    procedure BackButtonClick(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
    procedure TestButtonClick(Sender: TObject);
    procedure SyncButtonClick(Sender: TObject);
  private
    FAlive: IAlive;
    FOnBack: TProc;
    FOnSaved: TProc;
    FOnSynced: TProc;
    procedure Store;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property OnBack: TProc read FOnBack write FOnBack;
    property OnSaved: TProc read FOnSaved write FOnSaved;
    { A sync with Wave finished; customers may have been added, changed or marked missing. }
    property OnSynced: TProc read FOnSynced write FOnSynced;
  end;

implementation

{$R *.fmx}

constructor TSettingsFrame.Create(AOwner: TComponent);
begin
  inherited;
  FAlive := TAlive.Create;
  SetIcon(BackButton, TAppIcon.Back);
  SetIcon(SaveButton, TAppIcon.Save);
  var S := Crm.Settings;
  UrlEdit.Text := S.BaseUrl;
  IdEdit.Text := S.AppId;
  SecretEdit.Text := S.AppSecret;
end;

destructor TSettingsFrame.Destroy;
begin
  FAlive.Kill;
  inherited;
end;

procedure TSettingsFrame.Store;
begin
  var S := Default(TAppSettings);
  S.BaseUrl := Trim(UrlEdit.Text);
  S.AppId := Trim(IdEdit.Text);
  S.AppSecret := Trim(SecretEdit.Text);
  Crm.SaveSettings(S);
end;

procedure TSettingsFrame.SaveButtonClick(Sender: TObject);
begin
  Store;
  if Assigned(FOnSaved) then
    FOnSaved();
end;

procedure TSettingsFrame.BackButtonClick(Sender: TObject);
begin
  if Assigned(FOnBack) then
    FOnBack();
end;

procedure TSettingsFrame.TestButtonClick(Sender: TObject);
begin
  Store;
  ResultLabel.Text := 'Testing...';
  TAsync.Run<TLookups>(FAlive,
    function: TLookups
    begin
      Result := Crm.Lookups(True);
    end,
    procedure(ALookups: TLookups)
    begin
      ResultLabel.Text := Format('Connected. %d types, %d statuses.',
        [Length(ALookups.Types), Length(ALookups.Statuses)]);
    end,
    procedure(AError: string)
    begin
      ResultLabel.Text := AError;
    end);
end;

procedure TSettingsFrame.SyncButtonClick(Sender: TObject);
begin
  Store;
  ResultLabel.Text := 'Syncing with Wave...';
  SyncButton.Enabled := False;
  TAsync.Run<string>(FAlive,
    function: string
    begin
      Result := Crm.SyncNow;
    end,
    procedure(ASummary: string)
    begin
      SyncButton.Enabled := True;
      ResultLabel.Text := 'Sync done: ' + ASummary;
      if Assigned(FOnSynced) then
        FOnSynced();
    end,
    procedure(AError: string)
    begin
      SyncButton.Enabled := True;
      ResultLabel.Text := AError;
    end);
end;

end.
