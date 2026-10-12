unit ccCRM.App.Main;

{ Main form: a toolbar, a host layout and a TFrameStand. The customer list is the permanent
  base page; every other screen (detail, edit, log, email list, settings) is a frame stood on
  top of it and closed with Back (toolbar button or the Android back key). }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Generics.Collections,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Layouts, FrameStand, ccCRM.App.Types, ccCRM.App.Api,
  ccCRM.App.Frame.Customers, ccCRM.App.Frame.Detail, ccCRM.App.Frame.Edit,
  ccCRM.App.Frame.Log, ccCRM.App.Frame.Emails, ccCRM.App.Frame.Settings, SubjectStand;

type
  TMainForm = class(TForm)
    Bar: TToolBar;
    TitleLabel: TLabel;
    SettingsButton: TSpeedButton;
    EmailsButton: TSpeedButton;
    Host: TLayout;
    FrameStand1: TFrameStand;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    procedure SettingsButtonClick(Sender: TObject);
    procedure EmailsButtonClick(Sender: TObject);
  private
    FCustomers: TCustomersFrame;
    FPages: TList<TFrame>;   // open pages above the customer list; topmost last
    procedure ClosePage(AFrame: TFrame);
    function Open<T: TFrame>(const AConfig: TProc<T>): T;
    procedure OpenDetail(const AWaveId: string);
    procedure OpenEdit(ADetailFrame: TDetailFrame; const ADetail: TCustomerDetail);
    procedure OpenLog(ADetailFrame: TDetailFrame; const AWaveId: string);
    procedure OpenSettings;
    procedure OpenEmails;
  public
    destructor Destroy; override;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

destructor TMainForm.Destroy;
begin
  FPages.Free;
  inherited;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FPages := TList<TFrame>.Create;
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

procedure TMainForm.ClosePage(AFrame: TFrame);
begin
  FPages.Remove(AFrame);
  var Info := FrameStand1.FrameInfo(AFrame);
  if Info <> nil then
    Info.HideAndClose;
end;

function TMainForm.Open<T>(const AConfig: TProc<T>): T;
begin
  Result := FrameStand1.NewAndShow<T>(Host, '',
    procedure(F: T)
    begin
      F.Align := TAlignLayout.Client;  // every page fills the host
      if Assigned(AConfig) then
        AConfig(F);
    end).Frame;
  FPages.Add(Result);
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
          OpenLog(F, AId);
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

procedure TMainForm.OpenLog(ADetailFrame: TDetailFrame; const AWaveId: string);
begin
  Open<TLogFrame>(
    procedure(F: TLogFrame)
    begin
      F.Start(AWaveId);
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
    end);
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
