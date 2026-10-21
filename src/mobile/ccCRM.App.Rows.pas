unit ccCRM.App.Rows;

{ Icon buttons at the right-hand end of a list row (call, email, edit, delete, ...). Only the
  buttons act; tapping the row itself does nothing, so a stray tap never starts a call or
  deletes anything. Also the section headers between groups of rows. }

interface

uses
  System.Classes, FMX.ListBox, FMX.StdCtrls, ccCRM.App.Icons;

{ Adds a section header (Contact, Account, Log, ...) at the end of AList: white text on a
  black bar, which stands out on a phone better than the style's light grey. }
function AddGroupHeader(AList: TListBox; const AText: string): TListBoxGroupHeader;

{ Adds a button showing AIcon (AHint is its tooltip) to the left of any already on the row. }
function AddRowButton(AItem: TListBoxItem; AIcon: TAppIcon; const AHint: string;
  AOnClick: TNotifyEvent): TSpeedButton;

{ Total width of the row's buttons. }
function ButtonsWidth(AItem: TListBoxItem): Single;

{ Keeps the row's text clear of its buttons, so a long email address isn't drawn under them.
  Call it from the row's OnApplyStyleLookup if the row has a handler of its own; otherwise
  AddRowButton installs one that does just this. }
procedure FitTextToButtons(AItem: TListBoxItem);

implementation

uses
  System.Types, System.UITypes, FMX.Types, FMX.Controls, FMX.Graphics, FMX.Objects;

type
  TRowStyler = class
    class procedure ApplyStyleLookup(Sender: TObject);
    class procedure HeaderApplyStyleLookup(Sender: TObject);
  end;

class procedure TRowStyler.ApplyStyleLookup(Sender: TObject);
begin
  FitTextToButtons(Sender as TListBoxItem);
end;

{ The bar covers the style's own background and text; this keeps its text in the style's font
  and lined up where the style puts it. }
class procedure TRowStyler.HeaderApplyStyleLookup(Sender: TObject);
begin
  var Header := Sender as TListBoxGroupHeader;
  if not (Header.TagObject is TText) then
    Exit;
  var Caption := TText(Header.TagObject);
  var StyleText := Header.FindStyleResource('text');
  if StyleText is TText then
  begin
    Caption.Font.Family := TText(StyleText).Font.Family;
    Caption.Font.Size := TText(StyleText).Font.Size;
    var Left := Header.AbsoluteToLocal(TText(StyleText).LocalToAbsolute(PointF(0, 0))).X;
    if Left > 0 then
      Caption.Margins.Left := Left;
  end;
end;

function AddGroupHeader(AList: TListBox; const AText: string): TListBoxGroupHeader;
begin
  Result := TListBoxGroupHeader.Create(AList);
  Result.Parent := AList;
  Result.Text := AText;

  var Bar := TRectangle.Create(Result);
  Bar.Parent := Result;
  Bar.Align := TAlignLayout.Contents;
  Bar.HitTest := False;
  Bar.Fill.Color := TAlphaColors.Black;
  Bar.Stroke.Kind := TBrushKind.None;
  Bar.BringToFront;

  var Caption := TText.Create(Bar);
  Caption.Parent := Bar;
  Caption.Align := TAlignLayout.Client;
  Caption.Margins.Left := 8;
  Caption.HitTest := False;
  Caption.Text := AText;
  Caption.Color := TAlphaColors.White;
  Caption.Font.Style := [TFontStyle.fsBold];
  Caption.HorzTextAlign := TTextAlign.Leading;
  Caption.VertTextAlign := TTextAlign.Center;

  Result.TagObject := Caption;
  Result.OnApplyStyleLookup := TRowStyler.HeaderApplyStyleLookup;
end;

function AddRowButton(AItem: TListBoxItem; AIcon: TAppIcon; const AHint: string;
  AOnClick: TNotifyEvent): TSpeedButton;
begin
  var Count := 0;
  for var I := 0 to AItem.ChildrenCount - 1 do
    if AItem.Children[I] is TSpeedButton then
      Inc(Count);

  Result := TSpeedButton.Create(AItem);
  Result.Parent := AItem;
  Result.Align := TAlignLayout.Right;
  Result.Position.X := 10000 - 100 * Count;  // right-aligned controls are ordered by position
  Result.Text := AHint;
  Result.OnClick := AOnClick;
  SetIcon(Result, AIcon);

  if not Assigned(AItem.OnApplyStyleLookup) then
    AItem.OnApplyStyleLookup := TRowStyler.ApplyStyleLookup;
  FitTextToButtons(AItem);  // in case the style is already applied
end;

function ButtonsWidth(AItem: TListBoxItem): Single;
begin
  Result := 0;
  for var I := 0 to AItem.ChildrenCount - 1 do
    if AItem.Children[I] is TSpeedButton then
      Result := Result + TSpeedButton(AItem.Children[I]).Width;
end;

procedure FitTextToButtons(AItem: TListBoxItem);
begin
  var Room := ButtonsWidth(AItem);
  for var Name in ['text', 'detail'] do
  begin
    var Part := AItem.FindStyleResource(Name);
    if Part is TControl then
      TControl(Part).Margins.Right := Room;
  end;
end;

end.
