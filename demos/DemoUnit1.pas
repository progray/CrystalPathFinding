unit DemoUnit1;


// compiler directives
{$ifdef FPC}
  {$mode Delphi}
  {$asmmode Intel}
  {$define INLINESUPPORT}
{$else}
  {$if CompilerVersion >= 24}
    {$LEGACYIFEND ON}
  {$ifend}
  {$if CompilerVersion >= 15}
    {$WARN UNSAFE_CODE OFF}
    {$WARN UNSAFE_TYPE OFF}
    {$WARN UNSAFE_CAST OFF}
  {$ifend}
  {$if (CompilerVersion < 23)}
    {$define CPUX86}
  {$ifend}
  {$if (CompilerVersion >= 17)}
    {$define INLINESUPPORT}
  {$ifend}
  {$if CompilerVersion >= 21}
    {$WEAKLINKRTTI ON}
    {$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
  {$ifend}
  {$if (not Defined(NEXTGEN)) and (CompilerVersion >= 20)}
    {$define INTERNALCODEPAGE}
  {$ifend}
{$endif}
{$U-}{$V+}{$B-}{$X+}{$T+}{$P+}{$H+}{$J-}{$Z1}{$A4}
{$O+}{$R-}{$I-}{$Q-}{$W-}
{$if Defined(CPUX86) or Defined(CPUX64)}
  {$define CPUINTEL}
{$ifend}
{$if SizeOf(Pointer) = 8}
  {$define LARGEINT}
{$else}
  {$define SMALLINT}
{$ifend}
{$ifdef KOL_MCK}
  {$define KOL}
{$endif}


interface

{.$define USECPFDLL}

{$ifdef CPFDBG}
  {$undef USECPFDLL}
{$endif}

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Types, Dialogs, Math, ExtCtrls, StdCtrls, Spin, JPEG,
  {$ifdef USECPFDLL}cpf{$else}CrystalPathFinding{$endif};

{$R xp_manifest.res}

type
  TMainForm = class(TForm)
    pbMap: TPaintBox;
    gbTileWeigths: TGroupBox;
    pbTile1: TPaintBox;
    pbTile2: TPaintBox;
    pbTile3: TPaintBox;
    pbTile4: TPaintBox;
    sbTile1: TScrollBar;
    lbTile1: TLabel;
    cbUseWeights: TCheckBox;
    sbTile2: TScrollBar;
    lbTile2: TLabel;
    sbTile3: TScrollBar;
    lbTile3: TLabel;
    sbTile4: TScrollBar;
    lbTile4: TLabel;
    gbBarrierMode: TGroupBox;
    pbBarrier: TPaintBox;
    pbExclude: TPaintBox;
    gbSpeedTest: TGroupBox;
    seIterationsCount: TSpinEdit;
    btnSpeedTest: TButton;
    btnRandom: TButton;
    btnClear: TButton;
    lbDistance: TLabel;
    rgMapKind: TRadioGroup;
    gbOptions: TGroupBox;
    cbSectorTest: TCheckBox;
    cbCaching: TCheckBox;
    btnSave: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure OnTileClick(Sender: TObject);
    procedure OnTilePaint(Sender: TObject);
    procedure OnTileWeightChange(Sender: TObject);
    procedure pbMapPaint(Sender: TObject);
    procedure OnMapOptionChanged(Sender: TObject);
    procedure pbMapMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure btnSpeedTestClick(Sender: TObject);
    procedure cbUseWeightsClick(Sender: TObject);
    procedure pbMapMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure pbMapMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure btnClearClick(Sender: TObject);
    procedure btnRandomClick(Sender: TObject);
    procedure cbSectorTestClick(Sender: TObject);
    procedure rgMapKindClick(Sender: TObject);
    procedure pbMapDblClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
  private
    // internal data
    FUseWeights: Boolean;
    FSectorTest: Boolean;
    FCaching: Boolean;
    FExcludedPoints: array of TPoint;
    FStartPoint: TPoint;
    FFinishPoint: TPoint;
    FCursorPoint: TPoint;
    FMousePressed: TMouseButton;
    FTileMode: Byte;
    FBarrierMode: Byte;
    FMapKind: TTileMapKind;

    function PointCorrection(const P: TPoint): TPoint;
    function ScreenToMap(X, Y: Integer): TPoint;
    function MapToScreen(X, Y: Integer; Center: Boolean = True): TPoint;
    procedure RepaintBoxes(const PaintBoxes: array of TPaintBox);
    function ExcludePointPos(const Value: TPoint): Integer;
    procedure AddExcludedPoint(const Value: TPoint);
    procedure DeleteExcludedPoint(const Value: TPoint);
    procedure SetStartPoint(const Value: TPoint);
    procedure SetFinishPoint(const Value: TPoint);
    procedure SetBarrierMode(const Value: Byte);
    procedure SetTileMode(const Value: Byte);
    procedure SetMapKind(const Value: TTileMapKind);
  private
    // basic methods and properties
    procedure SaveMap;
    procedure RecreateMap;
    procedure FillMapBitmap(const Path: TTileMapPath; const JpgFileName: string = '');
    procedure ExecutePathFinding;

    property TileMode: Byte read FTileMode write SetTileMode;
    property BarrierMode: Byte read FBarrierMode write SetBarrierMode;
    property MapKind: TTileMapKind read FMapKind write SetMapKind;
    property StartPoint: TPoint read FStartPoint write SetStartPoint;
    property FinishPoint: TPoint read FFinishPoint write SetFinishPoint;
  end;


const
  TILES_COUNT = 4;
  TILE_SIZE = 30;
  FULL_TILE_SIZE = TILE_SIZE + TILE_SIZE div 3;
  MAP_WIDTH = 30;
  MAP_HEIGHT = 20;

var
  MainForm: TMainForm;
  TILE_MAP: array[0..MAP_HEIGHT - 1, 0..MAP_WIDTH - 1] of Byte;

  ProjectPath: string;
  MapBitmap: TBitmap;
  TileBitmaps: array[0..TILES_COUNT * 3 - 1] of TBitmap;
  WhiteCell, GreyCell: TBitmap;
  MaskHexagonal: TBitmap;

  // main CPF library objects: map and tile weights
  HWeights: TCPFHandle;
  HMap: TCPFHandle;
  
implementation

{$R *.dfm}

// some file compatibility routine
procedure IncrementTiles;
var
  i: Integer;
  P: PByte;
begin
  P := @TILE_MAP[0, 0];
  for i := 1 to MAP_HEIGHT * MAP_WIDTH do
  begin
    Inc(P^);
    Inc(P);
  end;
end;

// some file compatibility routine
procedure DecrementTiles;
var
  i: Integer;
  P: PByte;
begin
  P := @TILE_MAP[0, 0];
  for i := 1 to MAP_HEIGHT * MAP_WIDTH do
  begin
    Dec(P^);
    Inc(P);
  end;
end;

// use dialog form to edit point coordinates
function EditPoint(const Point: TPoint; const PointName: string): TPoint;
var
  Dialog: TForm;
  SpinX, SpinY: TSpinEdit;
  OnKeyDown: TKeyEvent;

  procedure DialogOnKeyDown(Dialog: TForm; Sender: TObject; var Key: Word;
    Shift: TShiftState) far;
  begin
    if (Key = VK_ESCAPE) then Dialog.Close;
  end;

  procedure SpinOnKeyDown(Dialog: TForm; Sender: TObject; var Key: Word;
    Shift: TShiftState) far;
  begin
    if (Key = VK_RETURN) then Dialog.ModalResult := mrOk;
  end;

begin
  Result := Point;

  Dialog := TForm.Create(nil);
  try
    TMethod(OnKeyDown).Data := Dialog;  
    Dialog.Caption := Format('%s point editor [%d, %d]', [PointName, Point.X, Point.Y]);
    Dialog.BorderStyle := bsDialog;
    Dialog.ClientHeight := 95;
    Dialog.ClientWidth := 242;
    Dialog.KeyPreview := True;
    TMethod(OnKeyDown).Code := @DialogOnKeyDown;
    Dialog.OnKeyDown := OnKeyDown;
    Dialog.Position := poScreenCenter;

    // buttons
    with TButton.Create(Dialog) do
    begin
      Parent := Dialog;
      Caption := 'Ok';
      SetBounds(66, 64, 75, 25);
      ModalResult := mrOk;
    end;
    with TButton.Create(Dialog) do
    begin
      Parent := Dialog;
      Caption := 'Cancel';
      SetBounds(153, 64, 75, 25);
      ModalResult := mrCancel;
    end;

    // spin edits
    TMethod(OnKeyDown).Code := @SpinOnKeyDown;
    SpinX := TSpinEdit.Create(Dialog);
    SpinX.Parent := Dialog;
    SpinX.SetBounds(44, 19, 79, 22);
    SpinX.MaxValue := 29;
    SpinX.Value := Point.X;
    SpinX.OnKeyDown := OnKeyDown;
    SpinY := TSpinEdit.Create(Dialog);
    SpinY.Parent := Dialog;
    SpinY.SetBounds(151, 19, 79, 22);
    SpinY.MaxValue := 19;
    SpinY.Value := Point.Y;
    SpinY.OnKeyDown := OnKeyDown;

    // labels
    with TLabel.Create(Dialog) do
    begin
      Parent := Dialog;
      Caption := 'X:';
      SetBounds(29, 23, 10, 13);
    end;
    with TLabel.Create(Dialog) do
    begin
      Parent := Dialog;
      Caption := 'Y:';
      SetBounds(136, 23, 10, 13);
    end;

    // show dialog
    if (Dialog.ShowModal = mrOk) then
    begin
      Result.X := SpinX.Value;
      Result.Y := SpinY.Value;
    end;
  finally
    Dialog.Free;
  end;
end;

function TMainForm.PointCorrection(const P: TPoint): TPoint;
begin
  Result := P;

  if (Result.X < 0) then Result.X := 0;
  if (Result.Y < 0) then Result.Y := 0;
  if (Result.X >= MAP_WIDTH) then Result.X := MAP_WIDTH - 1;
  if (Result.Y >= MAP_HEIGHT) then Result.Y := MAP_HEIGHT - 1;

  if (MapKind = mkHexagonal{60}) and (Result.Y and 1 = 1) and
    (Result.X = MAP_WIDTH - 1) then Dec(Result.X);
end;

function TMainForm.ScreenToMap(X, Y: Integer): TPoint;
begin
  Result.X := X div TILE_SIZE;
  Result.Y := Y div TILE_SIZE;

  if (MapKind = mkHexagonal{60}) then
  begin
    if (Result.Y and 1 = 1) then
    begin
      Result.X := (X-TILE_SIZE div 2) div TILE_SIZE;

      if (Result.X = MAP_WIDTH - 1) then Result.X := -1;
      if (X < TILE_SIZE div 2) then Result.X := -1;
    end;

    if (Y mod TILE_SIZE < (TILE_SIZE div 3)) then
    begin
      Result.X := Low(Integer);
      Result.Y := Low(Integer);
    end;
  end;
end;

function TMainForm.MapToScreen(X, Y: Integer; Center: Boolean = True): TPoint;
begin
  Result.X := X * TILE_SIZE;
  Result.Y := Y * TILE_SIZE;

  if (MapKind = mkHexagonal{60}) then
  begin
    if (Y and 1 = 1) then
      Inc(Result.X, TILE_SIZE div 2);

    if (Center) then
    begin
      Inc(Result.X, TILE_SIZE div 2 + 1);
      Inc(Result.Y, (TILE_SIZE * 4 div 3) div 2 - 1);
    end;
  end else
  if (Center) then
  begin
    Inc(Result.X, TILE_SIZE div 2);
    Inc(Result.Y, TILE_SIZE div 2);
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  i, Len: Integer;
  FileName: string;
  F: TFileStream;
  SmallCell: TBitmap;

  function LoadBitmap(const FileName: string): TBitmap;
  begin
    Result := TBitmap.Create;
    Result.LoadFromFile(FileName);
  end;

  function ReadInt: Integer;
  begin
    F.ReadBuffer(Result, SizeOf(Result));
  end;

  function ReadBool: Boolean;
  begin
    F.ReadBuffer(Result, SizeOf(Result));
  end;

begin
  Randomize;
  Application.Title := 'Crystal Path Finding';
  ProjectPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));

  for i := 0 to TILES_COUNT - 1 do
  begin
    SmallCell := TBitmap.Create;
    TileBitmaps[i * 3] := LoadBitmap(ProjectPath + IntToStr(i) + '_.bmp');
    TileBitmaps[i * 3 + 1] := SmallCell;
    TileBitmaps[i * 3 + 2] := LoadBitmap(ProjectPath + IntToStr(i) + '.bmp');

    SmallCell.PixelFormat := pf24bit;
    SmallCell.Width := TILE_SIZE;
    SmallCell.Height := TILE_SIZE;
    SetStretchBltMode(SmallCell.Canvas.Handle, HALFTONE);
    SmallCell.Canvas.CopyRect(Rect(0, 0, TILE_SIZE, TILE_SIZE),
      TileBitmaps[i * 3 + 2].Canvas, Rect(0, 0, FULL_TILE_SIZE, FULL_TILE_SIZE));
  end;
  WhiteCell := LoadBitmap('white.bmp');
  GreyCell := LoadBitmap('grey.bmp');
  MaskHexagonal := LoadBitmap('hex60.bmp');

  // data initialization
  HWeights := cpfCreateWeights;
  FUseWeights := True;
  FSectorTest := True;
  FCaching := False;
  FTileMode := 1;
  FillChar(TILE_MAP, SizeOf(TILE_MAP), 1);
  sbTile1.Position := Round(1.0 * 20);
  sbTile2.Position := Round(1.5 * 20);
  sbTile3.Position := Round(2.5 * 20);
  sbTile4.Position := Round(6.0 * 20);
  FStartPoint := Point(5, 9);
  FFinishPoint := Point(24, 9);
  FMousePressed := mbMiddle; // neutral value initialization

  // loading last map state from local "SAVE.dat" file
  FileName := ProjectPath + 'SAVE.dat';
  if (FileExists(FileName)) then
  begin
    F := TFileStream.Create(FileName, fmShareDenyNone);
    try
      F.Read(TILE_MAP, SizeOf(TILE_MAP));
      IncrementTiles;{compatibility routine};
      F.Read(FStartPoint, SizeOf(FStartPoint));
      F.Read(FFinishPoint, SizeOf(FFinishPoint));
      F.Read(FTileMode, SizeOf(FTileMode));
      F.Read(FBarrierMode, SizeOf(FBarrierMode));
      F.Read(FMapKind, SizeOf(FMapKind));
      if (Byte(FMapKind) > Byte(High(TTileMapKind))) then FMapKind := High(TTileMapKind);
      FStartPoint := PointCorrection(FStartPoint);
      FFinishPoint := PointCorrection(FFinishPoint);

      cbUseWeights.Checked := ReadBool;
      cbCaching.Checked := ReadBool;
      cbSectorTest.Checked := ReadBool;
      rgMapKind.ItemIndex := Byte(FMapKind);

      sbTile1.Position := ReadInt;
      sbTile2.Position := ReadInt;
      sbTile3.Position := ReadInt;
      sbTile4.Position := ReadInt;
      seIterationsCount.Value := ReadInt;

      Len := ReadInt;
      if (Len > 0) then
      begin
        SetLength(FExcludedPoints, Len);
        F.Read(pointer(FExcludedPoints)^, Len * SizeOf(TPoint));

        for i := 0 to Len - 1 do
          FExcludedPoints[i] := PointCorrection(FExcludedPoints[i]);
      end;
    finally
      F.Free;
    end;
  end;

  // raster map buffer
  MapBitmap := TBitmap.Create;
  MapBitmap.PixelFormat := pf24bit;
  MapBitmap.Width := MAP_WIDTH * TILE_SIZE;
  MapBitmap.Height := MAP_HEIGHT * TILE_SIZE;

  // create map, find path, repaint
  RecreateMap;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
var
  i: Integer;
begin
  // save current map state
  SaveMap();

  // remove allocated instances
  cpfDestroyWeights(HWeights);
  cpfDestroyMap(HMap);

  for i := 0 to TILES_COUNT * 3 - 1 do
  TileBitmaps[i].Free;

  MapBitmap.Free;

  WhiteCell.Free;
  GreyCell.Free;
  MaskHexagonal.Free;
end;

procedure TMainForm.SaveMap;
var
  F: TFileStream;
  Len: Integer;
  MapKind: Byte;

  procedure WriteInt(Value: Integer);
  begin
    F.WriteBuffer(Value, SizeOf(Value));
  end;

  procedure WriteBool(Value: Boolean);
  begin
    F.WriteBuffer(Value, SizeOf(Value));
  end;  
begin
  F := TFileStream.Create(ProjectPath + 'SAVE.dat', fmCreate);
  // compatibility routine
  DecrementTiles;
  try
    F.Write(TILE_MAP, SizeOf(TILE_MAP));
  finally
    IncrementTiles;
  end;
  F.Write(FStartPoint, SizeOf(FStartPoint));
  F.Write(FFinishPoint, SizeOf(FFinishPoint));
  F.Write(FTileMode, SizeOf(FTileMode));
  F.Write(FBarrierMode, SizeOf(FBarrierMode));
  // compatibility routine
  MapKind := Byte(FMapKind);
  if (FMapKind = mkHexagonal) then Inc(MapKind);
  F.Write(MapKind, SizeOf(MapKind));

  WriteBool(cbUseWeights.Checked);
  WriteBool(cbCaching.Checked);
  WriteBool(cbSectorTest.Checked);   

  WriteInt(sbTile1.Position);
  WriteInt(sbTile2.Position);
  WriteInt(sbTile3.Position);
  WriteInt(sbTile4.Position);
  WriteInt(seIterationsCount.Value);

  Len := Length(FExcludedPoints);
  WriteInt(Len);
  if (Len <> 0) then F.Write(Pointer(FExcludedPoints)^, Len * SizeOf(TPoint));
  F.Free;
end;  

procedure TMainForm.btnClearClick(Sender: TObject);
var
  BufMapBitmap: TBitmap;
begin
  BufMapBitmap := MapBitmap;
  MapBitmap := nil;

  begin
    FillChar(TILE_MAP, SizeOf(TILE_MAP), 1);
    sbTile1.Position := Round(1.0 * 20);
    sbTile2.Position := Round(1.5 * 20);
    sbTile3.Position := Round(2.5 * 20);
    sbTile4.Position := Round(6.0 * 20);
    FStartPoint := Point(5, 9);
    FFinishPoint := Point(24, 9);
    FExcludedPoints := nil;
    cbUseWeights.Checked := True;
    cbCaching.Checked := False;
    MapKind := mkSimple;
    cbSectorTest.Checked := True;
    seIterationsCount.Value := 1000;
  end;

  MapBitmap := BufMapBitmap;
  FTileMode := 1;
  FBarrierMode := 0;
  RecreateMap;
end;

procedure TMainForm.btnRandomClick(Sender: TObject);
var
  i, j: Integer;
  BufMapBitmap: TBitmap;

  function RandomBool: Boolean;
  begin
    Result := (Random(2) <> 0);
  end;

  function RandomPoint: TPoint;
  begin
    Result.X := Random(MAP_WIDTH);
    Result.Y := Random(MAP_HEIGHT);
    Result := PointCorrection(Result);
  end;
begin
  BufMapBitmap := MapBitmap;
  MapBitmap := nil;

  begin
    for i := 0 to MAP_WIDTH - 1 do
    for j := 0 to MAP_HEIGHT - 1 do
    begin
      TILE_MAP[j, i] := Random(TILES_COUNT + 1);
    end;
    sbTile1.Position := Random(200);
    sbTile2.Position := Random(200);
    sbTile3.Position := Random(200);
    sbTile4.Position := Random(200);
    cbUseWeights.Checked := RandomBool;
    MapKind := TTileMapKind(Random(Byte(High(TTileMapKind)) + 1));
    cbSectorTest.Checked := RandomBool;
    seIterationsCount.Value := Random(100000) + 1;
    FStartPoint := RandomPoint;
    FFinishPoint := RandomPoint;
    FExcludedPoints := nil;
    for i := 0 to Random(20) do AddExcludedPoint(RandomPoint);
  end;

  MapBitmap := BufMapBitmap;
  FTileMode := 1;
  FBarrierMode := 0;
  RecreateMap;
end;

procedure TMainForm.btnSaveClick(Sender: TObject);
begin
  SaveMap;
end;

procedure TMainForm.RepaintBoxes(const PaintBoxes: array of TPaintBox);
var
  i: Integer;
  PaintBox: TPaintBox;
begin
  for i := 0 to High(PaintBoxes) do
  begin
    PaintBox := PaintBoxes[i];
    if (Assigned(PaintBox.OnPaint)) then PaintBox.OnPaint(PaintBox);
  end;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) then Close;
end;

procedure TMainForm.pbMapPaint(Sender: TObject);
begin
  TPaintBox(Sender).Canvas.Draw(0, 0, MapBitmap);
end;

procedure TMainForm.RecreateMap();
begin
  if (HMap <> 0) then cpfDestroyMap(HMap);

  // create map
  HMap := cpfCreateMap(MAP_WIDTH, MAP_HEIGHT, FMapKind);

  // fill tiles
  cpfMapUpdate(HMap, @TILE_MAP[0, 0], 0, 0, MAP_WIDTH, MAP_HEIGHT);

  // calculate path and repaint map
  ExecutePathFinding;
end;

procedure TMainForm.cbUseWeightsClick(Sender: TObject);
begin
  FUseWeights := cbUseWeights.Checked;
  ExecutePathFinding;
end;

procedure TMainForm.cbSectorTestClick(Sender: TObject);
begin
  FSectorTest := cbSectorTest.Checked;
  ExecutePathFinding;
end;

procedure TMainForm.OnMapOptionChanged(Sender: TObject);
begin
  FCaching := cbCaching.Checked;
  ExecutePathFinding;
end;

procedure TMainForm.OnTileClick(Sender: TObject);
var
  TileNum: Integer;
begin
  TileNum := TPaintBox(Sender).Tag;

  if (TileNum <= 0) then
  begin
    // change clear mode
    BarrierMode := -TileNum;
  end else
  begin
    // change current tile 
    TileMode := TileNum;
  end;
end;

procedure TMainForm.rgMapKindClick(Sender: TObject);
begin
  MapKind := TTileMapKind(rgMapKind.ItemIndex);
end;

procedure TMainForm.OnTilePaint(Sender: TObject);
var
  PaintBox: TPaintBox;
  TileNum: Integer;
  Color: TColor;
  Active: Boolean;
  PaintBoxRect: TRect;
begin
  PaintBox := TPaintBox(Sender);
  TileNum := PaintBox.Tag;
  Color := TColor($FFFFFFFF);
  PaintBoxRect := Rect(0, 0, PaintBox.Width, PaintBox.Height);

  if (TileNum > 0) then
  begin
    if (cpfWeightGet(HWeights, TileNum) < 0.1) then Color := clWhite;
    Active := (TileMode = TileNum);
  end else
  begin
    if (TileNum = 0) then Color := clBlack
    else Color := clGray;

    Active := (BarrierMode = (-TileNum));
  end;

  if (Color = TColor($FFFFFFFF)) then
  begin
    PaintBox.Canvas.Draw(0, 0, TileBitmaps[(TileNum - 1) * 3]);
  end else
  begin
    PaintBox.Canvas.Brush.Style := bsSolid;
    PaintBox.Canvas.Brush.Color := Color;
    PaintBox.Canvas.FillRect(PaintBoxRect);
  end;

  if (Active) then
  begin
    with PaintBoxRect do
    begin
      Inc(Left, 2);
      Inc(Top, 2);
      Dec(Right, 1);
      Dec(Bottom, 1);
    end;         
    PaintBox.Canvas.Pen.Width := 4;
    PaintBox.Canvas.Pen.Color := clBlue;
    PaintBox.Canvas.Brush.Style := bsClear;
    PaintBox.Canvas.Rectangle(PaintBoxRect);
  end;
end;

procedure TMainForm.OnTileWeightChange(Sender: TObject);
var
  TileNum: Byte;
  Weight: Single;
begin
  TileNum := TScrollBar(Sender).Tag;
  Weight := TScrollBar(Sender).Position / 20;
  TLabel(FindComponent('lbTile' + IntToStr(TileNum))).Caption := Format('%0.2f', [Weight]);

  cpfWeightSet(HWeights, TileNum, Weight);
  RepaintBoxes([TPaintBox(FindComponent('pbTile' + IntToStr(TileNum)))]);
  if (FUseWeights) then ExecutePathFinding();
end;

procedure TMainForm.pbMapMouseDown(Sender: TObject; Button: TMouseButton;
                                    Shift: TShiftState; X, Y: Integer);
begin
  if (Button = mbMiddle) or (FMousePressed = Button) or (ssDouble in Shift) then Exit;

  // unfocus controls
  Windows.SetFocus(0);

  // store button
  FMousePressed := Button;

  // process mouse action
  FCursorPoint := ScreenToMap(X, Y);
  pbMapMouseMove(nil{the first time}, Shift, X, Y);
end;

procedure TMainForm.pbMapMouseUp(Sender: TObject; Button: TMouseButton;
                                  Shift: TShiftState; X, Y: Integer);
begin
  if (FMousePressed = Button) then
    FMousePressed := mbMiddle;
end;

procedure TMainForm.pbMapMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  P, LastCursorPoint: TPoint;
begin
  P := ScreenToMap(X, Y);
  if (P.X < 0) or (P.X >= MAP_WIDTH) or (P.Y < 0) or (P.Y >= MAP_HEIGHT) then Exit;
  if (Sender <> nil) and (FCursorPoint.X = P.X) and (FCursorPoint.Y = P.Y) then Exit;
  {$ifdef CPFDBG}
    {$WARN SYMBOL_PLATFORM OFF}
    if (System.DebugHook > 0) then
      Caption := TTileMapPtr(HMap).CellInformation(P.X, P.Y);
  {$endif}  
  LastCursorPoint := FCursorPoint;
  FCursorPoint := P;
  if (FMousePressed = mbMiddle) then Exit;

  // points
  if (FMousePressed = mbLeft) and (LastCursorPoint.X = FStartPoint.X) and
    (LastCursorPoint.Y = FStartPoint.Y) then
  begin
    StartPoint := P;
    Exit;
  end;
  if (FMousePressed = mbLeft) and (LastCursorPoint.X = FFinishPoint.X) and
    (LastCursorPoint.Y = FFinishPoint.Y) then
  begin
    FinishPoint := P;
    Exit;
  end;

  if (FMousePressed = mbLeft) then
  begin
    // tile
    if (TILE_MAP[P.Y, P.X] <> TileMode) then
    begin
      TILE_MAP[P.Y, P.X] := TileMode;
      cpfMapSetTile(HMap, P.X, P.Y, TileMode);
      ExecutePathFinding;
    end;
  end else
  begin
    // barrier or excluded point
    if (BarrierMode = 0) then
    begin
      if (TILE_MAP[P.Y, P.X] <> TILE_BARRIER) then
      begin
        TILE_MAP[P.Y, P.X] := TILE_BARRIER;
        cpfMapSetTile(HMap, P.X, P.Y, TILE_BARRIER);
        ExecutePathFinding;
      end;
    end else
    begin
      if (ExcludePointPos(P) >= 0) then DeleteExcludedPoint(P)
      else AddExcludedPoint(P);

      ExecutePathFinding;
    end;
  end;
end;

procedure TMainForm.pbMapDblClick(Sender: TObject);
var
  P: TPoint;
begin
  GetCursorPos(P);
  P := pbMap.ScreenToClient(P);
  P := ScreenToMap(P.X, P.Y);

  if (P.X = StartPoint.X) and (P.Y = StartPoint.Y) then
  begin
    StartPoint := EditPoint(StartPoint, 'Start');
    FMousePressed := mbMiddle;
  end else
  if (P.X = FinishPoint.X) and (P.Y = FinishPoint.Y) then
  begin
    FinishPoint := EditPoint(FinishPoint, 'Finish');
    FMousePressed := mbMiddle;
  end;
end;

function TMainForm.ExcludePointPos(const Value: TPoint): integer;
begin
  for Result := 0 to Length(FExcludedPoints) - 1 do
  with FExcludedPoints[Result] do
  if (X = Value.X) and (Y = Value.Y) then Exit;

  Result := -1;
end;

procedure TMainForm.AddExcludedPoint(const Value: TPoint);
var
  Len: integer;
begin
  if (ExcludePointPos(Value) >= 0) then Exit;

  Len := Length(FExcludedPoints);
  SetLength(FExcludedPoints, Len + 1);
  FExcludedPoints[Len] := Value;
end;

procedure TMainForm.DeleteExcludedPoint(const Value: TPoint);
var
  P, Len: integer;
begin
  P := ExcludePointPos(Value);
  if (P < 0) then Exit;

  Len := Length(FExcludedPoints) - 1;
  if (P <> Len) then FExcludedPoints[P] := FExcludedPoints[Len];
  SetLength(FExcludedPoints, Len);
end;

procedure TMainForm.SetStartPoint(const Value: TPoint);
var
  P: TPoint;
begin
  P := PointCorrection(Value);
  if (FStartPoint.X <> P.X) or (FStartPoint.Y <> P.Y) then
  begin
    FStartPoint := P;
    ExecutePathFinding;
  end;
end;

procedure TMainForm.SetFinishPoint(const Value: TPoint);
var
  P: TPoint;
begin
  P := PointCorrection(Value);
  if (FFinishPoint.X <> P.X) or (FFinishPoint.Y <> P.Y) then
  begin
    FFinishPoint := P;
    ExecutePathFinding;
  end;
end;

procedure TMainForm.SetTileMode(const Value: Byte);
begin
  if (FTileMode = Value) then Exit;
  FTileMode := Value;
  if (MapBitmap <> nil) then RepaintBoxes([pbTile1, pbTile2, pbTile3, pbTile4]);
end;

procedure TMainForm.SetBarrierMode(const Value: Byte);
begin
  if (FBarrierMode = Value) then Exit;
  FBarrierMode := Value;
  if (MapBitmap <> nil) then RepaintBoxes([pbBarrier, pbExclude]);
end;

procedure TMainForm.SetMapKind(const Value: TTileMapKind);
var
  i: Integer;
begin
  if (FMapKind = Value) then Exit;
  FMapKind := Value;
  rgMapKind.ItemIndex := Byte(Value);

  // points correction
  FStartPoint := PointCorrection(FStartPoint);
  FFinishPoint := PointCorrection(FFinishPoint);
  for i := 0 to Length(FExcludedPoints) - 1 do
    FExcludedPoints[i] := PointCorrection(FExcludedPoints[i]);

  // find new path and repaint map
  if (MapBitmap <> nil) then RecreateMap;
end;

// main method!
// execute finding path algorithm
// and repaint map
procedure TMainForm.ExecutePathFinding;
var
  Weights: TCPFHandle;
  Path: TTileMapPath;
  Params: TTileMapParams;
begin
  if (MapBitmap = nil) then Exit;

  // find path
  Weights := HWeights;
  if (not FUseWeights) then Weights := 0;
  try
    Params.Starts := @StartPoint;
    Params.StartsCount := 1;
    Params.Finish := FinishPoint;
    Params.Weights := {$ifNdef USECPFDLL}TTileMapWeights{$endif}(Weights);
    Params.Excludes := PPoint(FExcludedPoints);
    Params.ExcludesCount := Length(FExcludedPoints);

    Path := cpfFindPath(HMap, @Params, FSectorTest, FCaching);
  except
    SaveMap();
    Path.Count := 0;
    FillMapBitmap(Path, ProjectPath + 'map_exception.jpg');
    raise;
  end;

  // distance label
  lbDistance.Visible := (Path.Count <> 0);
  if (Path.Count <> 0) then lbDistance.Caption := Format('Distance: %0.2f', [Path.Distance]);

  // repaint map
  FillMapBitmap(Path);
  RepaintBoxes([pbMap]);
end;

procedure TMainForm.FillMapBitmap(const Path: TTileMapPath; const JpgFileName: string = '');
var
  TileNum: Byte;
  Hexagonal: Boolean;
  BitmapMask: TBitmap;
  i, j: Integer;
  P: TPoint;
  Canvas: TCanvas;
  JI: TJpegImage;
  UsedTiles: array[1..TILES_COUNT] of Boolean;

  procedure DrawBitmap(Bitmap: TBitmap);
  begin
    if (BitmapMask = nil) then
    begin
      Canvas.Draw(P.X, P.Y, Bitmap);
    end else
    begin
      MaskBlt(Canvas.Handle, P.X, P.Y, FULL_TILE_SIZE, FULL_TILE_SIZE,
              Bitmap.Canvas.Handle, 0, 0,
              BitmapMask.Handle, 0, 0, MakeRop4($00AA0029, SrcCopy));
    end;
  end;

  procedure DrawTile(X, Y: integer; TileNum: Byte {TILE_BARRIER = 0});
  begin
    P := MapToScreen(X, Y, False);
    if (P.X >= MAP_WIDTH * TILE_SIZE - TILE_SIZE div 2) or
       (P.Y >= MAP_HEIGHT * TILE_SIZE - TILE_SIZE div 2) then Exit;

    // no tile
    if (TileNum = TILE_BARRIER) or (not UsedTiles[TileNum]) then
    begin
      if (Hexagonal) then
      begin
        if (TileNum = TILE_BARRIER) then DrawBitmap(GreyCell)
        else DrawBitmap(WhiteCell);
      end else
      begin
        if (TileNum = TILE_BARRIER) then Canvas.Brush.Color := clGray
        else Canvas.Brush.Color := clWhite;

        Canvas.FillRect(Bounds(P.X, P.Y, TILE_SIZE, TILE_SIZE));
      end;

      Exit;
    end;

    // tile
    DrawBitmap(TileBitmaps[(TileNum - 1) * 3 + 1 + Ord(Hexagonal)]);
  end;

  procedure LineTo(const offsX, offsY: Integer);
  begin
    Inc(P.X, offsX);
    Inc(P.Y, offsY);
    Canvas.LineTo(P.X, P.Y);    
  end;

begin
  // analize pathless tiles
  for TileNum := 1 to TILES_COUNT do
  UsedTiles[TileNum] := (not FUseWeights) or (cpfWeightGet(HWeights, TileNum) >= 0.1);

  // hexagonal mask
  BitmapMask := nil;
  Hexagonal := (MapKind = mkHexagonal);
  if (Hexagonal) then BitmapMask := MaskHexagonal;

  // clear bitmap
  Canvas := MapBitmap.Canvas;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clBlack;
  Canvas.FillRect(Rect(0, 0, MapBitmap.Width, MapBitmap.Height));

  // render tiles
  for i := 0 to MAP_WIDTH - 1 do
  for j := 0 to MAP_HEIGHT - 1 do
  begin
    TileNum := TILE_MAP[j, i];
    if (TileNum >= 1) and (TileNum <= TILES_COUNT) then
      DrawTile(i, j, TileNum);
  end;

  // excluded points
  for i := 0 to Length(FExcludedPoints) - 1 do
  with FExcludedPoints[i] do
  DrawTile(X, Y, TILE_BARRIER);

  // lines
  Canvas.Pen.Width := 1;
  if (not Hexagonal) then
  begin
    Canvas.Pen.Color := clGray;

    for i := 1 to MAP_WIDTH - 1 do
    begin
      Canvas.MoveTo(i * TILE_SIZE, 0);
      Canvas.LineTo(i * TILE_SIZE, MAP_HEIGHT * TILE_SIZE);
    end;
    for j := 1 to MAP_HEIGHT - 1 do
    begin
      Canvas.MoveTo(0, j * TILE_SIZE);
      Canvas.LineTo(MAP_WIDTH * TILE_SIZE, j * TILE_SIZE);
    end;
  end else
  for i := 0 to MAP_WIDTH - 1 do
  for j := 0 to MAP_HEIGHT - 1 do
  begin
    // each hexagonal tile render
    Canvas.Pen.Color := TColor($B0B0B0);
    P := MapToScreen(i, j, false);

    // basic coordinates
    Inc(P.X, TILE_SIZE div 2);
    Canvas.MoveTo(P.X, P.Y);

    // 6 lines around
    LineTo(TILE_SIZE div 2, TILE_SIZE div 3);
    LineTo(0, (TILE_SIZE div 3) * 2);
    LineTo(-TILE_SIZE div 2, TILE_SIZE div 3);
    LineTo(-TILE_SIZE div 2, -TILE_SIZE div 3);
    LineTo(0, -(TILE_SIZE div 3) * 2);
    LineTo(TILE_SIZE div 2, -TILE_SIZE div 3);
  end;

  // path
  if (Path.Count > 1) then
  begin
    Canvas.Pen.Width := 2;
    Canvas.Pen.Color := clRed;
    with MapToScreen(Path.Points[0].X, Path.Points[0].Y) do
      Canvas.MoveTo(X, Y);

    for i := 1 to Path.Count - 1 do
    with MapToScreen(Path.Points[i].X, Path.Points[i].Y) do
      Canvas.LineTo(X, Y);
  end;

  // start point, finish point
  Canvas.Brush.Style := bsSolid;
  Canvas.Pen.Width := 2;
  Canvas.Brush.Color := clBlue;
  if (FMousePressed = mbLeft) and (FCursorPoint.X = FStartPoint.X) and
    (FCursorPoint.Y = FStartPoint.Y) then Canvas.Brush.Color := clAqua;
  Canvas.Pen.Color := clRed;
  P := MapToScreen(StartPoint.X, StartPoint.Y);
  Canvas.Ellipse(Bounds(P.X - 9, P.Y - 9, 20, 20));
  Canvas.Pen.Width := 2;
  Canvas.Brush.Color := clRed;
  if (FMousePressed = mbLeft) and (FCursorPoint.X = FFinishPoint.X) and
    (FCursorPoint.Y = FFinishPoint.Y) then Canvas.Brush.Color := clFuchsia;
  Canvas.Pen.Color := clBlue;
  P := MapToScreen(FinishPoint.X, FinishPoint.Y);
  Canvas.Ellipse(Bounds(P.X - 9, P.Y - 9, 20, 20));

  // save
  if (JpgFileName <> '') then
  begin
    JI := TJpegImage.Create;
    JI.Assign(MapBitmap);
      JI.SaveToFile(JpgFileName);
    JI.Free;
  end;
end;

procedure TMainForm.btnSpeedTestClick(Sender: TObject);
var
  i, Count: Integer;
  Time: Cardinal;
  Weights: TCPFHandle;
  Params: TTileMapParams;
begin
  if (MapBitmap = nil) then Exit;

  Weights := HWeights;
  if (not FUseWeights) then Weights := 0;

  Count := seIterationsCount.Value;
  Time := GetTickCount;
  begin
    Params.Starts := @StartPoint;
    Params.StartsCount := 1;
    Params.Finish := FinishPoint;
    Params.Weights := {$ifNdef USECPFDLL}TTileMapWeights{$endif}(Weights);
    Params.Excludes := PPoint(FExcludedPoints);
    Params.ExcludesCount := Length(FExcludedPoints);

    for i := 1 to Count do
      cpfFindPath(HMap, @Params, FSectorTest, FCaching){ExecutePathFinding(Show = False)};
  end;
  Time := GetTickCount - Time;

  ShowMessageFmt('The shortest path was calculated %d times for %d milliseconds', [Count, Time]);
end;


end.
