program ccCRMApp;

uses
  System.StartUpCopy,
  FMX.Forms,
  ccCRM.App.Types in 'ccCRM.App.Types.pas',
  ccCRM.App.Api in 'ccCRM.App.Api.pas',
  ccCRM.App.Platform in 'ccCRM.App.Platform.pas',
  ccCRM.App.Frame.Customers in 'ccCRM.App.Frame.Customers.pas' {CustomersFrame: TFrame},
  ccCRM.App.Frame.Detail in 'ccCRM.App.Frame.Detail.pas' {DetailFrame: TFrame},
  ccCRM.App.Frame.Edit in 'ccCRM.App.Frame.Edit.pas' {EditFrame: TFrame},
  ccCRM.App.Frame.Log in 'ccCRM.App.Frame.Log.pas' {LogFrame: TFrame},
  ccCRM.App.Frame.Emails in 'ccCRM.App.Frame.Emails.pas' {EmailsFrame: TFrame},
  ccCRM.App.Frame.Settings in 'ccCRM.App.Frame.Settings.pas' {SettingsFrame: TFrame},
  ccCRM.App.Main in 'ccCRM.App.Main.pas' {MainForm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
