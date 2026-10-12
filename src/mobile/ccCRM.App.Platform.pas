unit ccCRM.App.Platform;

{ Small platform helpers: open a tel:/mailto:/http URL with the system, and copy text. }

interface

procedure OpenUrl(const AUrl: string);
procedure CopyToClipboard(const AText: string);

implementation

uses
  System.SysUtils, FMX.Platform,
{$IF Defined(ANDROID)}
  Androidapi.Helpers, Androidapi.JNI.GraphicsContentViewText, Androidapi.JNI.Net,
  Androidapi.JNI.JavaTypes;
{$ELSEIF Defined(IOS)}
  Macapi.Helpers, iOSapi.Foundation, FMX.Helpers.iOS;
{$ELSEIF Defined(MSWINDOWS)}
  Winapi.Windows, Winapi.ShellAPI;
{$ELSE}
  FMX.Dialogs;
{$ENDIF}

procedure OpenUrl(const AUrl: string);
begin
{$IF Defined(ANDROID)}
  var Intent := TJIntent.JavaClass.init(TJIntent.JavaClass.ACTION_VIEW,
    TJnet_Uri.JavaClass.parse(StringToJString(AUrl)));
  TAndroidHelper.Activity.startActivity(Intent);
{$ELSEIF Defined(IOS)}
  TiOSHelper.SharedApplication.openURL(StrToNSUrl(AUrl));
{$ELSEIF Defined(MSWINDOWS)}
  ShellExecute(0, 'open', PChar(AUrl), nil, nil, SW_SHOWNORMAL);
{$ELSE}
  ShowMessage(AUrl);
{$ENDIF}
end;

procedure CopyToClipboard(const AText: string);
begin
  var Svc: IFMXClipboardService;
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Svc) then
    Svc.SetClipboard(AText);
end;

end.
