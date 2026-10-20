unit ccCRM.App.Rows;

{ Icon buttons at the right-hand end of a list row (call, email, edit, delete, ...). Only the
  buttons act; tapping the row itself does nothing, so a stray tap never starts a call or
  deletes anything. }

interface

uses
  System.Classes, FMX.ListBox, FMX.StdCtrls, ccCRM.App.Icons;

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
  FMX.Types, FMX.Controls;

type
  TRowStyler = class
    class procedure ApplyStyleLookup(Sender: TObject);
  end;

class procedure TRowStyler.ApplyStyleLookup(Sender: TObject);
begin
  FitTextToButtons(Sender as TListBoxItem);
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
