unit pingrid;


{$mode objfpc}{$H+}

interface

uses
  LCLType, SysUtils, Classes, math, Types, Graphics, Controls, Grids;

type

  PNumCell = ^TNumCell;
  TNumCell = record
    Id: integer;
    Tag: integer;
    Col: longint;
    Row: longint;
    Next: PNumCell;
  end;

  PMergeCell = ^TMergeCell;
  TMergeCell = record
    Rect: TRect;
    Col: integer;
    Row: integer;
    Next: PMergeCell;
  end;

  PColorCell = ^TColorCell;
  TColorCell = record
    Color: TColor;
    Col: longint;
    Row: longint;
    Next: PColorCell;
  end;

  {TPinDragObject}
  TPinDragObject = class(TDragControlObject)
  private
    FDragCell: TDragImageList;
  protected
    function GetDragImages: TDragImageList; override;
  public
    constructor Create(AControl: TControl); override;
    destructor Destroy; override;
  end;

  { TPinGrid }
  TPinGrid = class(TStringGrid)
  private
    FCanEdit: Boolean;
    FExchangeCells: Boolean;
    FColorStart: PColorCell;
    FColorPointer: PColorCell;
    FMergeStart: PMergeCell;
    FMergePointer: PMergeCell;
    FSourceCol: Integer;
    FSourceRow: Integer;
    FNumStart: PNumCell;
    FNumPointer: PNumCell;
    function GetColorCell(ACol, ARow: integer): TColor;
    function GetIdCell(ACol, ARow: integer): integer;
    function GetMerged(ACol, ARow: integer): TRect;
    function GetTagCell(ACol, ARow: integer): integer;
    procedure SetColorCell(ACol, ARow: integer; const AValue: TColor);
    procedure SetIdCell(ACol, ARow: integer; const AValue: integer);
    procedure SetMerged(ACol, ARow: integer; AValue: TRect);
    procedure SetTagCell(ACol, ARow: integer; const AValue: integer);
  protected
    procedure CalcCellExtent(ACol, ARow: Integer; var ARect: TRect); override;
    procedure DoEditorShow; override;
    procedure DrawAllRows; override;
    procedure DrawCellText(aCol, aRow: Integer; aRect: TRect; aState: TGridDrawState; aText: String); override;
    procedure DrawFocusRect(ACol, ARow:Integer; ARect:TRect); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
    procedure DragOver(Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean); override;
    procedure DrawCell(aCol, aRow: Integer; aRect: TRect; aState: TGridDrawState); override;
    procedure MoveSelection; override;
    procedure PrepareCanvas(aCol, aRow: Integer; aState: TGridDrawState); override;
    procedure SetEditText(aCol, aRow: Longint; const aValue: string); override;
    function GetCells(ACol, ARow: Integer): string; override;
    function GetEditText(aCol, aRow: Integer): string; override;
    function IsMerged(ACol, ARow: integer; out L, T, R, B: Integer): Boolean; overload;
    property Merged[ACol, ARow: integer]: TRect read GetMerged write SetMerged;

  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure DragDrop(Source: TObject; X, Y: Integer); override;
    procedure DoStartDrag(var DragObject: TDragObject); override;
    procedure MergeCells(ALeft, ATop, ARight, ABottom: integer);
    procedure UnMergeCells(ACol, ARow: integer);
    procedure EraseAllMerge(APreserveTitles: Boolean = True);
    function PegaRect(ACol, ARow:integer): string;
    function IsMerged(ACol, ARow: Integer): Boolean; overload;
    property CanEdit: Boolean read FCanEdit write FCanEdit;
    property ColorCell[ACol, ARow: integer]: TColor read GetColorCell write SetColorCell;
    property IdCell[ACol, ARow: integer]: integer read GetIdCell write SetIdCell;
    property TagCell[ACol, ARow: integer]: integer read GetTagCell write SetTagCell;
  published
    property ExchangeCells: Boolean read FExchangeCells write FExchangeCells;
  end;

implementation

{ TPinDragObject }

function TPinDragObject.GetDragImages: TDragImageList;
begin
  Result := FDragCell;
end;

constructor TPinDragObject.Create(AControl: TControl);
var
  aRect: TRect;
  x, y: LongInt;
  Bitmap: TBitmap;
begin
  inherited Create(AControl);
  FDragCell := TDragImageList.Create(AControl);
  AlwaysShowDragImages := True;
  with AControl as TPinGrid do
  begin
    aRect := CellRect(FSourceCol, FSourceRow);
    x := CellRect(FSourceCol, FSourceRow).Left;
    y := CellRect(FSourceCol, FSourceRow).Top;
  end;
  Bitmap := TBitmap.Create;
  Bitmap.Width := aRect.Right - aRect.Left;
  Bitmap.Height := aRect.Bottom - aRect.Top;
  if AControl is TWinControl then
    (AControl as TWinControl).PaintTo(Bitmap.Canvas, -x, -y);
  FDragCell.Width := Bitmap.Width;
  FDragCell.Height := Bitmap.Height;
  FDragCell.Add(Bitmap, nil);
  FDragCell.DragHotspot := Point(Bitmap.Width, Bitmap.Height);
  Bitmap.Free;
end;

destructor TPinDragObject.Destroy;
begin
  if Assigned(FDragCell) then
    FDragCell.Free;
  inherited Destroy;
end;

constructor TPinGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  New(FNumStart);
  FNumStart^.Next := nil;
  New(FColorStart);
  FColorStart^.Next := nil;
  New(FMergeStart);
  FMergeStart^.Next := nil;
  FCanEdit := True;
end;

destructor TPinGrid.Destroy;
begin
  FNumPointer := FNumStart^.Next;
  while FNumPointer <> nil do
  begin
    FNumStart^.Next := FNumPointer^.Next;
    Dispose(FNumPointer);
    FNumPointer := FNumStart^.Next;
  end;
  Dispose(FNumStart);

  FColorPointer := FColorStart^.Next;
  while FColorPointer <> nil do
  begin
    FColorStart^.Next := FColorPointer^.Next;
    Dispose(FColorPointer);
    FColorPointer := FColorStart^.Next;
  end;
  Dispose(FColorStart);

  FMergePointer := FMergeStart^.Next;
  while FMergePointer <> nil do
  begin
    FMergeStart^.Next := FMergePointer^.Next;
    Dispose(FMergePointer);
    FMergePointer := FMergeStart^.Next;
  end;
  Dispose(FMergeStart);
  inherited Destroy;
end;

procedure TPinGrid.DragDrop(Source: TObject; X, Y: Integer);
var
  VDestCol, VDestRow: Longint;
  VBackCell: String;
  VBackTagCell, VBackIDCell, L, T, R, B: Integer;
  VBackColorCell: TColor;
begin
  Initialize(VDestCol);
  Initialize(VDestRow);
  MouseToCell(X, Y, VDestCol, VDestRow);
  if IsMerged(VDestCol, VDestRow, L, T, R, B) then
  begin
    VDestCol := L;
    VDestRow := R;
  end;
  if (FSourceCol <> VDestCol) or (FSourceRow <> VDestRow) then
  begin
    VBackCell := Cells[VDestCol, VDestRow];
    VBackIDCell := GetIdCell(VDestCol, VDestRow);
    VBackTagCell := GetTagCell(VDestCol, VDestRow);
    VBackColorCell := GetColorCell(VDestCol, VDestRow);

    Cells[VDestCol, VDestRow] := Cells[FSourceCol, FSourceRow];
    Cells[FSourceCol, FSourceRow] := VBackCell;

    IdCell[VDestCol, VDestRow] := IdCell[FSourceCol, FSourceRow];
    IdCell[FSourceCol, FSourceRow] := VBackIDCell;

    TagCell[VDestCol, VDestRow] := GetTagCell(FSourceCol, FSourceRow);
    TagCell[FSourceCol, FSourceRow]:= VBackTagCell;

    ColorCell[VDestCol, VDestRow] := GetColorCell(FSourceCol, FSourceRow);
    ColorCell[FSourceCol, FSourceRow]:= VBackColorCell;
  end;
  inherited DragDrop(Source, X, Y);
end;

procedure TPinGrid.DoStartDrag(var DragObject: TDragObject);
begin
  DragObject := TPinDragObject.Create(Self);
  inherited DoStartDrag(DragObject);
end;

procedure TPinGrid.MergeCells(ALeft, ATop, ARight, ABottom: integer);
var
  VCol, VRow: Integer;
begin
  for VCol := ALeft to ARight do
    for VRow := ATop to ABottom do
      Merged[VCol, VRow] := Rect(ALeft, ATop, ARight, ABottom);
  InvalidateGrid;
end;

procedure TPinGrid.UnMergeCells(ACol, ARow: integer);
var
  VRect: TRect;
  i, j: LongInt;
begin
  if not IsMerged(ACol, ARow) then Exit;
  VRect := Merged[ACol, ARow];
  for i := VRect.Left to VRect.Right do
    for j := VRect.Top to VRect.Bottom do
      Merged[i,j] := Rect(i, j, i, j);
  InvalidateGrid;
end;

procedure TPinGrid.EraseAllMerge(APreserveTitles: Boolean);
var
  CStart, RStart, i, j: Integer;
begin
  CStart := ifthen(APreserveTitles, FixedCols, 0);
  RStart := ifthen(APreserveTitles, FixedRows, 0);
  for i := CStart to  ColCount - 1 do
    for j := RStart to RowCount - 1 do
      UnMergeCells(i, j);
end;

function TPinGrid.PegaRect(ACol, ARow: integer): string;
var
  VRect: TRect;
begin
  VRect := GetMerged(ACol, ARow);
  Result := 'L: '+VRect.Left.ToString + ' - T: '+VRect.Top.ToString + #13 +
            'R: '+VRect.Right.ToString + ' - B: '+VRect.Bottom.ToString;
end;

function TPinGrid.GetTagCell(ACol, ARow: integer): integer;
begin
  Result := 0;
  FNumPointer := FNumStart^.Next;
  while (FNumPointer <> nil) and (Result = 0) do
  begin
    if (FNumPointer^.Col = ACol) and (FNumPointer^.Row = ARow) then
      Result := FNumPointer^.Tag
    else
      FNumPointer := FNumPointer^.Next;
  end;
end;

function TPinGrid.GetColorCell(ACol, ARow: integer): TColor;
begin
  Result := clNone;
  FColorPointer := FColorStart^.Next;
  while (FColorPointer <> nil) and (Result = clNone) do
  begin
    if (FColorPointer^.Col = ACol) and (FColorPointer^.Row = ARow) then
      Result := FColorPointer^.Color
    else
      FColorPointer := FColorPointer^.Next;
  end;
end;

function TPinGrid.GetIdCell(ACol, ARow: integer): integer;
begin
  Result := 0;
  FNumPointer := FNumStart^.Next;
  while (FNumPointer <> nil) and (Result = 0) do
  begin
    if (FNumPointer^.Col = ACol) and (FNumPointer^.Row = ARow) then
      Result := FNumPointer^.Id
    else
      FNumPointer := FNumPointer^.Next;
  end;
end;

function TPinGrid.GetMerged(ACol, ARow: integer): TRect;
begin
  Result := Rect(ACol, ARow, ACol, ARow);
  FMergePointer := FMergeStart^.Next;
  while (FMergePointer <> nil) and (Result.Left = Result.Right) and (Result.Top = Result.Bottom) do
  begin
    if (FMergePointer^.Col = ACol) and (FMergePointer^.Row = ARow) then
      Result := FMergePointer^.Rect
    else
      FMergePointer := FMergePointer^.Next;
  end;
end;

procedure TPinGrid.SetColorCell(ACol, ARow: integer; const AValue: TColor);
var
  P: PColorCell;
  Done: Boolean;
begin
  if AValue = clNone then
  begin
    if GetColorCell(ACol, ARow) <> clNone then
    begin
      FColorPointer := FColorStart^.Next;
      P := FColorStart;
      while FColorPointer <> nil do
      begin
        if (FColorPointer^.Col = ACol) and (FColorPointer^.Row = ARow) then
        begin
          P^.Next := FColorPointer^.Next;
          Dispose(FColorPointer);
          FColorPointer := nil;
        end
        else
        begin
          P := FColorPointer;
          FColorPointer := FColorPointer^.Next;
        end;
      end;
    end;
  end
  else
  begin
    Done := False;
    FColorPointer := FColorStart^.Next;
    while (FColorPointer <> nil) and (not Done) do
    begin
      if (FColorPointer^.Col = ACol) and (FColorPointer^.Row = ARow) then
      begin
        FColorPointer^.Color := AValue;
        Done := True;
      end;
      FColorPointer := FColorPointer^.Next;
    end;
    if not Done then
    begin
      New(FColorPointer);
      FColorPointer^.Next := FColorStart^.Next;
      FColorStart^.Next := FColorPointer;
      FColorPointer^.Col := ACol;
      FColorPointer^.Row := ARow;
      FColorPointer^.Color := AValue;
    end;
  end;
  Invalidate;
end;

procedure TPinGrid.SetIdCell(ACol, ARow: integer; const AValue: integer);
var
  P: PNumCell;
  Done: Boolean;
begin
  if AValue = 0 then
  begin
    if GetIdCell(ACol, ARow) <> 0 then
    begin
      FNumPointer := FNumStart^.Next;
      P := FNumStart;
      while FNumPointer <> nil do
      begin
        if (FNumPointer^.Col = ACol) and (FNumPointer^.Row = ARow) then
        begin
          P^.Next := FNumPointer^.Next;
          Dispose(FNumPointer);
          FNumPointer := nil;
        end
        else
        begin
          P := FNumPointer;
          FNumPointer := FNumPointer^.Next;
        end;
      end;
    end;
  end
  else
  begin
    Done := False;
    FNumPointer := FNumStart^.Next;
    while (FNumPointer <> nil) and (not Done) do
    begin
      if (FNumPointer^.Col = ACol) and (FNumPointer^.Row = ARow) then
      begin
        FNumPointer^.Id := AValue;
        Done := True;
      end;
      FNumPointer := FNumPointer^.Next;
    end;
    if not Done then
    begin
      New(FNumPointer);
      FNumPointer^.Next := FNumStart^.Next;
      FNumStart^.Next := FNumPointer;
      FNumPointer^.Col := ACol;
      FNumPointer^.Row := ARow;
      FNumPointer^.Id := AValue;
    end;
  end;
end;

procedure TPinGrid.SetMerged(ACol, ARow: integer; AValue: TRect);
var
  VMerged, Done: Boolean;
  RC: TRect;
  P: PMergeCell;
begin
  VMerged := (AValue.Left <> AValue.Right) or (AValue.Top <> AValue.Bottom);
  if not VMerged then
  begin
    RC := GetMerged(ACol, ARow);
    if (RC.Left <> RC.Right) or (RC.Top <> RC.Bottom)  then
    begin
      FMergePointer := FMergeStart^.Next;
      P := FMergeStart;
      while FMergePointer <> nil do
      begin
        if (FMergePointer^.Col = ACol) and (FMergePointer^.Row = ARow) then
        begin
          P^.Next := FMergePointer^.Next;
          Dispose(FMergePointer);
          FMergePointer := nil;
        end
        else
        begin
          P := FMergePointer;
          FMergePointer := FMergePointer^.Next;
        end;
      end;
    end;
  end
  else
  begin
    Done := False;
    FMergePointer := FMergeStart^.Next;
    while (FMergePointer <> nil) and (not Done) do
    begin
      if (FMergePointer^.Col = ACol) and (FMergePointer^.Row = ARow) then
      begin
        FMergePointer^.Rect := AValue;
        Done := True;
      end;
      FMergePointer := FMergePointer^.Next;
    end;
    if not Done then
    begin
      New(FMergePointer);
      FMergePointer^.Next := FMergeStart^.Next;
      FMergeStart^.Next := FMergePointer;
      FMergePointer^.Col := ACol;
      FMergePointer^.Row := ARow;
      FMergePointer^.Rect := AValue;
    end;
  end;
end;

procedure TPinGrid.SetTagCell(ACol, ARow: integer; const AValue: integer);
var
  P: PNumCell;
  Done: Boolean;
begin
  if AValue = 0 then
  begin
    if GetTagCell(ACol, ARow) <> 0 then
    begin
      FNumPointer := FNumStart^.Next;
      P := FNumStart;
      while FNumPointer <> nil do
      begin
        if (FNumPointer^.Col = ACol) and (FNumPointer^.Row = ARow) then
        begin
          P^.Next := FNumPointer^.Next;
          Dispose(FNumPointer);
          FNumPointer := nil;
        end
        else
        begin
          P := FNumPointer;
          FNumPointer := FNumPointer^.Next;
        end;
      end;
    end;
  end
  else
  begin
    Done := False;
    FNumPointer := FNumStart^.Next;
    while (FNumPointer <> nil) and (not Done) do
    begin
      if (FNumPointer^.Col = ACol) and (FNumPointer^.Row = ARow) then
      begin
        FNumPointer^.Tag := AValue;
        Done := True;
      end;
      FNumPointer := FNumPointer^.Next;
    end;
    if not Done then
    begin
      New(FNumPointer);
      FNumPointer^.Next := FNumStart^.Next;
      FNumStart^.Next := FNumPointer;
      FNumPointer^.Col := ACol;
      FNumPointer^.Row := ARow;
      FNumPointer^.Tag := AValue;
    end;
  end;
end;

procedure TPinGrid.CalcCellExtent(ACol, ARow: Integer; var ARect: TRect);
var
  VRect: TRect;
begin
  if IsMerged(ACol, ARow) then
  begin
    VRect := GetMerged(Acol, ARow);
    ARect.TopLeft := CellRect(VRect.Left, VRect.Top).TopLeft;
    ARect.BottomRight := CellRect(VRect.Right, VRect.Bottom).BottomRight;
  end;
  inherited CalcCellExtent(ACol, ARow, ARect);
end;

procedure TPinGrid.DoEditorShow;
var
  R: TRect;
begin
  inherited DoEditorShow;
  Initialize(R);
  if goColSpanning in Options then begin
    CalcCellExtent(Col, Row, R);
    Editor.SetBounds(R.Left, R.Top, R.Right-R.Left-1, R.Bottom-R.Top-1);
  end;
end;

procedure TPinGrid.DrawAllRows;
var
  L, T, R, B: integer;
  VRect: TRect;
begin
  inherited DrawAllRows;
  if FocusRectVisible and IsMerged(Col, Row, L, T, R, B) then begin
    VRect.TopLeft := CellRect(L, T).TopLeft;
    VRect.BottomRight := CellRect(R, B).BottomRight;
    DrawFocusRect(L, T, VRect);
  end;
end;

procedure TPinGrid.DrawCellText(aCol, aRow: Integer; aRect: TRect;
  aState: TGridDrawState; aText: String);
//var
//  VHandled: Boolean;
begin
  //VHandled := False;
  //if Assigned(FOnDrawCellText) then
  //  FOnDrawCellText(Self, ACol, ARow, ARect, AState, AText, handled);
  //if not handled then
    inherited DrawCellText(aCol, aRow, aRect, aState, aText);
end;

procedure TPinGrid.DrawFocusRect(ACol, ARow: Integer; ARect: TRect);
begin
  CalcCellExtent(ACol, ARow, ARect);
  inherited DrawFocusRect(ACol, ARow, ARect);
end;

procedure TPinGrid.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
var
  ACol, ARow: integer;
begin
  if (Button = mbRight) then
  begin
    Initialize(ACol);
    Initialize(ARow);
    MouseToCell(X, Y, ACol, ARow);
    if (ARow >= FixedRows) and (ACol >= FixedCols) then
    begin
      Col := ACol;
      Row := ARow;
    end;
  end;
  if (ssCtrl in Shift) and (FExchangeCells) then
  begin
    MouseToCell(X, Y, FSourceCol, FSourceRow);
    if (FSourceCol > 0) and (FSourceRow > 0) then
      BeginDrag(False, 4);
  end;
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TPinGrid.DragOver(Source: TObject; X, Y: Integer; State: TDragState;
  var Accept: Boolean);
var
  CurrentCol, CurrentRow: Longint;
begin
  Initialize(CurrentCol);
  Initialize(CurrentRow);
  MouseToCell(X, Y, CurrentCol, CurrentRow);
  Accept := (Source is TPinDragObject) and (CurrentCol > 0) and (CurrentRow > 0);
  if Assigned(OnDragOver) then
    inherited DragOver(Source, X, Y, State, Accept);
end;

procedure TPinGrid.DrawCell(aCol, aRow: Integer; aRect: TRect;
  aState: TGridDrawState);
var
  VColorCell: TColor;
  VCell: String;
begin
  inherited DrawCell(aCol, aRow, aRect, aState);
  VColorCell := GetColorCell(aCol, aRow);
  if VColorCell <> clNone then
  begin
    VCell := Self.Cells[aCol, aRow];
    with Canvas do
    begin
      Brush.Color := VColorCell;
      FillRect(aRect);
      TextRect(aRect, aRect.Left+3, aRect.Top, VCell);
    end;
  end;
end;

procedure TPinGrid.MoveSelection;
begin
  inherited MoveSelection;
  InvalidateGrid;
end;

procedure TPinGrid.PrepareCanvas(aCol, aRow: Integer; aState: TGridDrawState);
var
  L, T, R, B: integer;
begin
  if IsMerged(ACol, ARow, L, T, R, B) and
     (Col >= L) and (Col <= R) and (Row >= T) and (Row <= B) and
     not ((ACol = Col) and (ARow = Row)) then
     AState := AState + [gdSelected, gdFocused];
  inherited PrepareCanvas(aCol, aRow, aState);
end;

procedure TPinGrid.SetEditText(aCol, aRow: Longint; const aValue: string);
var
  L, T, R, B: integer;
begin
  if IsMerged(ACol, ARow, L, T, R, B) then
    inherited SetEditText(L, T, aValue)
  else
    inherited SetEditText(aCol, aRow, aValue);
end;

function TPinGrid.GetCells(ACol, ARow: Integer): string;
var
  L, T, R, B: integer;
begin
  if IsMerged(ACol, ARow, L, T, R, B) then
    Result := inherited GetCells(L, T)
  else
    Result := inherited GetCells(ACol, ARow);
end;

function TPinGrid.GetEditText(aCol, aRow: Integer): string;
begin
  Result := GetCells(ACol, ARow);
  if Assigned(OnGetEditText) then OnGetEditText(self, ACol, ARow, Result);
end;

function TPinGrid.IsMerged(ACol, ARow: integer; out L, T, R, B: Integer
  ): Boolean;
var
  VRect: TRect;
begin
  VRect := GetMerged(ACol, ARow);
  L := VRect.Left;
  T := VRect.Top;
  R := VRect.Right;
  B := VRect.Bottom;
  Result := (L <> R) or (T <> B);
end;

function TPinGrid.IsMerged(ACol, ARow: Integer): Boolean;
var
  L, T, R, B: integer;
begin
  Result := IsMerged(ACol, ARow, L, T, R, B);
end;

end.
