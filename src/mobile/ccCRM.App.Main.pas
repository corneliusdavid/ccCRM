unit ccCRM.App.Main;

{ Main form: a toolbar, a host layout and a TFrameStand. The customer list is the permanent
  base page; every other screen (detail, edit, log, email list, settings) is a frame stood on
  top of it and closed with Back (toolbar button or the Android back key). }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Layouts, FMX.DialogService, System.Math, FrameStand, ccCRM.App.Types, ccCRM.App.Api,
  ccCRM.App.Frame.Customers, ccCRM.App.Frame.Detail, ccCRM.App.Frame.Edit,
  ccCRM.App.Frame.Log, ccCRM.App.Frame.Emails, ccCRM.App.Frame.Settings,
  ccCRM.App.Frame.Contacts, ccCRM.App.Frame.ContactEdit, SubjectStand, ccCRM.App.Icons, ccCRM.App.Platform;

type
  TMainForm = class(TForm)
    Bar: TToolBar;
    TitleLabel: TLabel;
    SettingsButton: TSpeedButton;
    EmailsButton: TSpeedButton;
    Host: TLayout;
    FrameStand1: TFrameStand;
    ccStyleBook: TStyleBook;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    procedure SettingsButtonClick(Sender: TObject);
    procedure EmailsButtonClick(Sender: TObject);
  private
    InfoButton: TSpeedButton;
    RefreshButton: TSpeedButton;
    FCustomers: TCustomersFrame;
    FPages: TList<TFrame>;   // open pages above the customer list; topmost last
    function TopPage: TFrame;
    procedure UpdateBar;
    procedure ClosePage(AFrame: TFrame);
    function Open<T: TFrame>(const AConfig: TProc<T>): T;
    procedure OpenDetail(const AWaveId: string);
    procedure OpenEdit(ADetailFrame: TDetailFrame; const ADetail: TCustomerDetail);
    procedure OpenLog(ADetailFrame: TDetailFrame; const AWaveId: string; const AEntry: TLogEntry);
    procedure OpenContacts(ADetailFrame: TDetailFrame; const AWaveId: string);
    procedure OpenContactEdit(AContactsFrame: TContactsFrame; const AWaveId: string;
      const AContact: TContactRec);
    procedure OpenSettings;
    procedure OpenEmails;
    function AddBarButton(AIcon: TAppIcon; const AHint: string;
      AOnClick: TNotifyEvent): TSpeedButton;
    procedure InfoButtonClick(Sender: TObject);
    procedure RefreshButtonClick(Sender: TObject);
  public
    destructor Destroy; override;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}
{$R *.XLgXhdpiTb.fmx ANDROID}
{$R *.LgXhdpiTb.fmx ANDROID}
{$R *.LgXhdpiPh.fmx ANDROID}

const
  RepoUrl = 'https://github.com/corneliusdavid/ccCRM';

destructor TMainForm.Destroy;
begin
  FPages.Free;
  inherited;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FPages := TList<TFrame>.Create;
  SetIcon(SettingsButton, TAppIcon.Settings);
  InfoButton := AddBarButton(TAppIcon.Info, 'About', InfoButtonClick);
  RefreshButton := AddBarButton(TAppIcon.Refresh, 'Refresh', RefreshButtonClick);
  UpdateBar;
  FCustomers := FrameStand1.NewAndShow<TCustomersFrame>(Host, '',
    procedure(F: TCustomersFrame)
    begin
      F.Align := TAlignLayout.Client;  // fill the host, whatever the window or screen size
      F.OnOpen :=
        procedure(AWaveId: string)
        begin
          OpenDetail(AWaveId);
        end;
    end).Frame;
  if not Crm.Settings.IsConfigured then
    OpenSettings;
end;

{ Icon button on the left of the toolbar (made in code rather than in the .fmx so the
  per-device views don't need them too). }
function TMainForm.AddBarButton(AIcon: TAppIcon; const AHint: string;
  AOnClick: TNotifyEvent): TSpeedButton;
begin
  Result := TSpeedButton.Create(Self);
  Result.Parent := Bar;
  Result.Align := TAlignLayout.Left;
  Result.Text := AHint;
  Result.OnClick := AOnClick;
  SetIcon(Result, AIcon);
end;

function TMainForm.TopPage: TFrame;
begin
  if FPages.Count > 0 then
    Result := FPages.Last
  else
    Result := FCustomers;
end;

{ Frames have no background, so only the topmost page is kept visible; otherwise the
  pages underneath show (and can be clicked) through it. }
procedure TMainForm.ClosePage(AFrame: TFrame);
begin
  FPages.Remove(AFrame);
  var Info := FrameStand1.FrameInfo(AFrame);
  if Info <> nil then
    Info.HideAndClose;
  TopPage.Visible := True;
  UpdateBar;
end;

{ The toolbar buttons (Info and Refresh on the left, Emails and Settings on the right) are only
  offered on the customer list, not on pages stood on top of it. Aligned controls are ordered
  by their current position, which goes stale while hidden, so each is pushed back into place
  every time. The title gets a margin on whichever side has fewer buttons, so it stays centred
  in the bar. }
procedure TMainForm.UpdateBar;
begin
  var Home := FPages.Count = 0;
  InfoButton.Visible := Home;
  RefreshButton.Visible := Home;
  EmailsButton.Visible := Home;
  SettingsButton.Visible := Home;
  if Home then
  begin
    InfoButton.Position.X := 0;
    RefreshButton.Position.X := InfoButton.Width;
    EmailsButton.Position.X := 0;
    SettingsButton.Position.X := Bar.Width;
    var LeftWidth := InfoButton.Width + RefreshButton.Width;
    var RightWidth := EmailsButton.Width + SettingsButton.Width;
    TitleLabel.Margins.Left := Max(0, RightWidth - LeftWidth);
    TitleLabel.Margins.Right := Max(0, LeftWidth - RightWidth);
  end
  else
  begin
    TitleLabel.Margins.Left := 0;
    TitleLabel.Margins.Right := 0;
  end;
end;

function TMainForm.Open<T>(const AConfig: TProc<T>): T;
begin
  TopPage.Visible := False;
  Result := FrameStand1.NewAndShow<T>(Host, '',
    procedure(F: T)
    begin
      F.Align := TAlignLayout.Client;  // every page fills the host
      if Assigned(AConfig) then
        AConfig(F);
    end).Frame;
  FPages.Add(Result);
  UpdateBar;
end;

procedure TMainForm.OpenDetail(const AWaveId: string);
begin
  Open<TDetailFrame>(
    procedure(F: TDetailFrame)
    begin
      F.OnBack :=
        procedure
        begin
          ClosePage(F);
          FCustomers.Reload;  // type/status/user count may have changed
        end;
      F.OnEdit :=
        procedure(ADetail: TCustomerDetail)
        begin
          OpenEdit(F, ADetail);
        end;
      F.OnAddLog :=
        procedure(AId: string)
        begin
          OpenLog(F, AId, Default(TLogEntry));
        end;
      F.OnEditLog :=
        procedure(AEntry: TLogEntry)
        begin
          OpenLog(F, AWaveId, AEntry);
        end;
      F.OnDeleted :=
        procedure
        begin
          ClosePage(F);
          FCustomers.Reload;
        end;
      F.OnContacts :=
        procedure(AId: string)
        begin
          OpenContacts(F, AId);
        end;
      F.Load(AWaveId);
    end);
end;

procedure TMainForm.OpenEdit(ADetailFrame: TDetailFrame; const ADetail: TCustomerDetail);
begin
  Open<TEditFrame>(
    procedure(F: TEditFrame)
    begin
      F.LoadFrom(ADetail);
      F.OnCancel :=
        procedure
        begin
          ClosePage(F);
        end;
      F.OnSaved :=
        procedure
        begin
          ClosePage(F);
          ADetailFrame.Reload;
        end;
    end);
end;

procedure TMainForm.OpenLog(ADetailFrame: TDetailFrame; const AWaveId: string;
  const AEntry: TLogEntry);
begin
  Open<TLogFrame>(
    procedure(F: TLogFrame)
    begin
      F.Start(AWaveId, AEntry);
      F.OnCancel :=
        procedure
        begin
          ClosePage(F);
        end;
      F.OnSaved :=
        procedure
        begin
          ClosePage(F);
          ADetailFrame.Reload;
        end;
    end);
end;

procedure TMainForm.OpenContacts(ADetailFrame: TDetailFrame; const AWaveId: string);
begin
  Open<TContactsFrame>(
    procedure(F: TContactsFrame)
    begin
      F.OnBack :=
        procedure
        begin
          ClosePage(F);
          ADetailFrame.Reload;  // the People section may have changed
        end;
      F.OnEditContact :=
        procedure(AContact: TContactRec)
        begin
          OpenContactEdit(F, AWaveId, AContact);
        end;
      F.Load(AWaveId);
    end);
end;

procedure TMainForm.OpenContactEdit(AContactsFrame: TContactsFrame; const AWaveId: string;
  const AContact: TContactRec);
begin
  Open<TContactEditFrame>(
    procedure(F: TContactEditFrame)
    begin
      F.Start(AWaveId, AContact);
      F.OnCancel :=
        procedure
        begin
          ClosePage(F);
        end;
      F.OnSaved :=
        procedure
        begin
          ClosePage(F);
          AContactsFrame.Reload;
        end;
    end);
end;

procedure TMainForm.OpenSettings;
begin
  Open<TSettingsFrame>(
    procedure(F: TSettingsFrame)
    begin
      F.OnBack :=
        procedure
        begin
          ClosePage(F);
        end;
      F.OnSaved :=
        procedure
        begin
          ClosePage(F);
          FCustomers.Reload;
        end;
      F.OnSynced :=
        procedure
        begin
          FCustomers.Reload;  // the list is underneath; it's current when Settings closes
        end;
    end);
end;

procedure TMainForm.OpenEmails;
begin
  Open<TEmailsFrame>(
    procedure(F: TEmailsFrame)
    begin
      F.OnBack :=
        procedure
        begin
          ClosePage(F);
        end;
      F.Load(FCustomers.Filter);  // only the customers the list is showing
    end);
end;

procedure TMainForm.InfoButtonClick(Sender: TObject);
begin
  TDialogService.MessageDialog(
    'ccCRM is a personal CRM for Cornelius Concepts.' + sLineBreak + sLineBreak +
    'It''s open source on GitHub, so you''re welcome to clone it for your own purposes:' +
    sLineBreak + RepoUrl + sLineBreak + sLineBreak + 'Open the GitHub page now?',
    TMsgDlgType.mtInformation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0,
    procedure(const AResult: TModalResult)
    begin
      if AResult = mrYes then
        OpenUrl(RepoUrl);
    end);
end;

procedure TMainForm.RefreshButtonClick(Sender: TObject);
begin
  FCustomers.RefreshAll;
end;

procedure TMainForm.SettingsButtonClick(Sender: TObject);
begin
  OpenSettings;
end;

procedure TMainForm.EmailsButtonClick(Sender: TObject);
begin
  OpenEmails;
end;

{ Android hardware back: close the topmost page instead of leaving the app. }
procedure TMainForm.FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
  Shift: TShiftState);
begin
  if (Key = vkHardwareBack) and (FPages.Count > 0) then
  begin
    ClosePage(FPages.Last);
    Key := 0;
  end;
end;

end.
