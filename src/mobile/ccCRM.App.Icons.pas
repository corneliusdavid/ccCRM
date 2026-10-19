unit ccCRM.App.Icons;

{ Toolbar icons drawn as vector paths (Google Material Design icons, Apache 2.0 licence), so
  they stay sharp at any screen density and don't depend on which glyphs the active style
  happens to include. Each icon takes its colour from the style's button text, so it matches
  whatever style book the form uses. }

interface

uses
  FMX.Types, FMX.StdCtrls, FMX.Objects;

type
  TAppIcon = (Back, Edit, Cancel, Save, Settings);

  { Coloured markers shown in list rows (not themed: the colour is part of the meaning). }
  TBadge = (Star, Frown);

{ Replaces the button's caption with AIcon; the old caption is kept as the hint. }
procedure SetIcon(AButton: TCustomButton; AIcon: TAppIcon);

{ Adds ABadge at the right-hand end of AParent (e.g. a list box item). }
function AddBadge(AParent: TFmxObject; ABadge: TBadge): TPath;

implementation

uses
  System.UITypes, FMX.Graphics;

const
  IconSize = 22;
  ButtonWidth = 48;  // the minimum comfortable touch target on Android

  { 24x24 Material icon paths. The leading "M 0 0 M 24 24" pins every icon to the same
    24x24 box, so a small glyph (the tick) isn't stretched larger than a big one (the gear). }
  IconPaths: array[TAppIcon] of string = (
    { Back }
    'M 0 0 M 24 24 M 20 11 H 7.83 l 5.59 -5.59 L 12 4 l -8 8 l 8 8 l 1.41 -1.41 L 7.83 13 ' +
    'H 20 v -2 z',
    { Edit }
    'M 0 0 M 24 24 M 3 17.25 V 21 h 3.75 L 17.81 9.94 l -3.75 -3.75 L 3 17.25 z M 20.71 ' +
    '7.04 c 0.39 -0.39 0.39 -1.02 0 -1.41 l -2.34 -2.34 c -0.39 -0.39 -1.02 -0.39 -1.41 0 ' +
    'l -1.83 1.83 l 3.75 3.75 l 1.83 -1.83 z',
    { Cancel }
    'M 0 0 M 24 24 M 19 6.41 L 17.59 5 L 12 10.59 L 6.41 5 L 5 6.41 L 10.59 12 L 5 17.59 ' +
    'L 6.41 19 L 12 13.41 L 17.59 19 L 19 17.59 L 13.41 12 z',
    { Save }
    'M 0 0 M 24 24 M 9 16.17 L 4.83 12 l -1.42 1.41 L 9 19 L 21 7 l -1.41 -1.41 z',
    { Settings }
    'M 0 0 M 24 24 M 19.14 12.94 c 0.04 -0.3 0.06 -0.61 0.06 -0.94 c 0 -0.32 -0.02 -0.64 ' +
    '-0.07 -0.94 l 2.03 -1.58 c 0.18 -0.14 0.23 -0.41 0.12 -0.61 l -1.92 -3.32 c -0.12 ' +
    '-0.22 -0.37 -0.29 -0.59 -0.22 l -2.39 0.96 c -0.5 -0.38 -1.03 -0.7 -1.62 -0.94 l ' +
    '-0.36 -2.54 c -0.04 -0.24 -0.24 -0.41 -0.48 -0.41 h -3.84 c -0.24 0 -0.43 0.17 -0.47 ' +
    '0.41 l -0.36 2.54 c -0.59 0.24 -1.13 0.57 -1.62 0.94 l -2.39 -0.96 c -0.22 -0.08 ' +
    '-0.47 0 -0.59 0.22 L 2.74 8.87 c -0.12 0.21 -0.08 0.47 0.12 0.61 l 2.03 1.58 c -0.05 ' +
    '0.3 -0.09 0.63 -0.09 0.94 s 0.02 0.64 0.07 0.94 l -2.03 1.58 c -0.18 0.14 -0.23 0.41 ' +
    '-0.12 0.61 l 1.92 3.32 c 0.12 0.22 0.37 0.29 0.59 0.22 l 2.39 -0.96 c 0.5 0.38 1.03 ' +
    '0.7 1.62 0.94 l 0.36 2.54 c 0.05 0.24 0.24 0.41 0.48 0.41 h 3.84 c 0.24 0 0.44 -0.17 ' +
    '0.47 -0.41 l 0.36 -2.54 c 0.59 -0.24 1.13 -0.56 1.62 -0.94 l 2.39 0.96 c 0.22 0.08 ' +
    '0.47 0 0.59 -0.22 l 1.92 -3.32 c 0.12 -0.22 0.07 -0.47 -0.12 -0.61 l -2.01 -1.58 z M ' +
    '12 15.6 c -1.98 0 -3.6 -1.62 -3.6 -3.6 s 1.62 -3.6 3.6 -3.6 s 3.6 1.62 3.6 3.6 s ' +
    '-1.62 3.6 -3.6 3.6 z'
  );

  BadgeSize = 22;

  BadgePaths: array[TBadge] of string = (
    { Star }
    'M 0 0 M 24 24 M 12 17.27 L 18.18 21 l -1.64 -7.03 L 22 9.24 l -7.19 -0.61 L 12 2 ' +
    'L 9.19 8.63 L 2 9.24 l 5.46 4.73 L 5.82 21 z',
    { Frown (sentiment_dissatisfied) }
    'M 0 0 M 24 24 M 14 9.5 a 1.5 1.5 0 1 0 3 0 a 1.5 1.5 0 1 0 -3 0 z ' +
    'M 7 9.5 a 1.5 1.5 0 1 0 3 0 a 1.5 1.5 0 1 0 -3 0 z ' +
    'M 11.99 2 C 6.47 2 2 6.48 2 12 S 6.47 22 11.99 22 C 17.52 22 22 17.52 22 12 ' +
    'S 17.52 2 11.99 2 z M 12 20 C 7.58 20 4 16.42 4 12 S 7.58 4 12 4 S 20 7.58 20 12 ' +
    'S 16.42 20 12 20 z M 12 14 c -2.33 0 -4.31 1.46 -5.11 3.5 h 10.22 ' +
    'c -0.8 -2.04 -2.78 -3.5 -5.11 -3.5 z'
  );

  BadgeColors: array[TBadge] of TAlphaColor = (
    $FFF5B800,  // Star: yellow
    $FF3A3A3A   // Frown: dark grey
  );

type
  TIconStyler = class
    class procedure ButtonApplyStyleLookup(Sender: TObject);
  end;

{ Runs whenever the button (re)applies its style, e.g. once it lands on a form with a style
  book, so the icon always follows the style's text colour. }
class procedure TIconStyler.ButtonApplyStyleLookup(Sender: TObject);
begin
  var Button := Sender as TCustomButton;
  if not (Button.TagObject is TPath) then
    Exit;
  var Text := Button.FindStyleResource('text');
  if Text is TText then
    TPath(Button.TagObject).Fill.Color := TText(Text).Color
  else
    TPath(Button.TagObject).Fill.Color := Button.ResultingTextSettings.FontColor;
end;

procedure SetIcon(AButton: TCustomButton; AIcon: TAppIcon);
begin
  var Path := TPath.Create(AButton);
  Path.Parent := AButton;
  Path.Align := TAlignLayout.Center;
  Path.Width := IconSize;
  Path.Height := IconSize;
  Path.HitTest := False;  // taps go to the button
  Path.WrapMode := TPathWrapMode.Fit;
  Path.Stroke.Kind := TBrushKind.None;
  Path.Data.Data := IconPaths[AIcon];

  AButton.TagObject := Path;
  AButton.Hint := AButton.Text;
  AButton.ShowHint := True;
  AButton.Text := '';
  AButton.Width := ButtonWidth;
  AButton.OnApplyStyleLookup := TIconStyler.ButtonApplyStyleLookup;
  TIconStyler.ButtonApplyStyleLookup(AButton);  // in case the style is already applied
end;

function AddBadge(AParent: TFmxObject; ABadge: TBadge): TPath;
begin
  Result := TPath.Create(AParent);
  Result.Parent := AParent;
  Result.Align := TAlignLayout.Right;
  Result.Width := BadgeSize;
  Result.Margins.Right := 12;
  Result.Margins.Top := 4;
  Result.Margins.Bottom := 4;
  Result.HitTest := False;
  Result.WrapMode := TPathWrapMode.Fit;
  Result.Stroke.Kind := TBrushKind.None;
  Result.Fill.Color := BadgeColors[ABadge];
  Result.Data.Data := BadgePaths[ABadge];
end;

end.
