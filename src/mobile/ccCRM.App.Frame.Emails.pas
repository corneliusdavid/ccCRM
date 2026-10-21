unit ccCRM.App.Frame.Emails;

{ Builds the email list for the customers the home list is showing (its search and
  type/status filters) and either copies the BCC string or hands it to the phone's email app. }

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
    FilterLabel: TLabel;
    CountLabel: TLabel;
    ButtonLayout: TLayout;
    CopyButton: TButton;
    MailButton: TButton;
    BccMemo: TMemo;
    procedure BackButtonClick(Sender: TObject);
    procedure CopyButtonClick(Sender: TObject);
    procedure MailButtonClick(Sender: TObject);
  private
    FAlive: IAlive;
    FOnBack: TProc;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { Fetches the addresses for AFilter (the customer list's current filter). }
    procedure Load(const AFilter: TCustomerFilter);
    property OnBack: TProc read FOnBack write FOnBack;
  end;

implementation

{$R *.fmx}

constructor TEmailsFrame.Create(AOwner: TComponent);
begin
  inherited;
  FAlive := TAlive.Create;
  SetIcon(BackButton, TAppIcon.Back);
end;

destructor TEmailsFrame.Destroy;
begin
  FAlive.Kill;
  inherited;
end;

procedure TEmailsFrame.Load(const AFilter: TCustomerFilter);
begin
  FilterLabel.Text := AFilter.Caption;
  CountLabel.Text := 'Loading...';
  TAsync.Run<TEmailList>(FAlive,
    function: TEmailList
    begin
      Result := Crm.Emails(AFilter);
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
