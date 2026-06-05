unit UWorld;

interface

uses
  System.Generics.Collections, UMonkey;

type
  TWorldMonkeySnapshot = record
    X: Integer;
    Y: Integer;
    Sex: TMonkeySex;
    IsPregnant: Boolean;
  end;

  TWorldMonkeySnapshots = array of TWorldMonkeySnapshot;
  TMonkeyBoard = array of TMonkey;

  TMonkeyTraitSnapshot = record
    X: Integer;
    Y: Integer;
    Id: TMonkeyId;
    Sex: TMonkeySex;
    MotherId: TMonkeyId;
    FatherId: TMonkeyId;
    MaternalGrandmotherId: TMonkeyId;
    MaternalGrandfatherId: TMonkeyId;
    PaternalGrandmotherId: TMonkeyId;
    PaternalGrandfatherId: TMonkeyId;
    GenCount: Integer;
    Strength: Double;
    Lifespan: Double;
    Age: Integer;
    VisionSlots: Integer;
    MemoryCount: Integer;
    PregnantTurnsRemaining: Integer;
    IsPregnant: Boolean;
    Alive: Boolean;
  end;

  TWorldConfig = record
    SizeX: Integer;
    SizeY: Integer;
    BaseLifespan: Double;
    VisionSlots: Integer;
    InitialStrength: Double;
    MatingCost: Double;
    CombatGainPercent: Double;
    SigmaCombat: Double;
    MutationSigmaPercent: Double;
    InitSigmaPercent: Double;
    PopulationCount: Integer;
  end;

  TWorld = class
  private
    FConfig: TWorldConfig;
    FMonkeys: TObjectList<TMonkey>;
    FBoard: TMonkeyBoard;
    FNextMonkeyId: TMonkeyId;
    class function EnsureAtLeast(const AValue, AMinimum: Integer): Integer; static;
    procedure AddVisionSlot(var AVisionSlots: TMonkeyVisionSlots;
      const ASourceX, ASourceY, ARelativeX, ARelativeY: Integer);
    function BoardIndex(const AX, AY: Integer): Integer;
    function BuildVisionForMonkey(const AMonkey: TMonkey;
      const AVisionDecision: TMonkeyVisionDecision): TMonkeyVisionSlots;
    procedure ClearBoard;
    procedure CreateInitialPopulation;
    function FindRandomEmptyCell(out AX, AY: Integer): Boolean;
    function FindMonkeyPosition(const AMonkey: TMonkey; out AX, AY: Integer): Boolean;
    function GetMonkeyCount: Integer;
    function GetSizeX: Integer;
    function GetSizeY: Integer;
    function IsInsideBoard(const AX, AY: Integer): Boolean;
    function MonkeyPriority(const AMonkey: TMonkey): Double;
    procedure ActivateMonkey(const AMonkey: TMonkey);
    procedure DirectionToDelta(const ADirection: Integer; out ADeltaX, ADeltaY: Integer);
    procedure RemoveDeadMonkeys;
    procedure ResolveMonkeyAction(const AMonkey: TMonkey;
      const AAction: TMonkeyActionDecision);
    procedure ShuffleMonkeys;
    procedure SortMonkeysForTurn;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddMonkey(const AMonkey: TMonkey);
    function GetMonkeySnapshots: TWorldMonkeySnapshots;
    function TryGetMonkeyTraitsAt(const AX, AY: Integer;
      out ATraits: TMonkeyTraitSnapshot): Boolean;
    procedure Restart(const AConfig: TWorldConfig);
    procedure RunWorldTurn;

    property Config: TWorldConfig read FConfig;
    property MonkeyCount: Integer read GetMonkeyCount;
    property SizeX: Integer read GetSizeX;
    property SizeY: Integer read GetSizeY;
  end;

implementation

uses
  System.Generics.Defaults, System.Math, System.SysUtils;

{ TWorld }

constructor TWorld.Create;
begin
  inherited Create;
  FMonkeys := TObjectList<TMonkey>.Create(True);
  Randomize;
end;

destructor TWorld.Destroy;
begin
  FMonkeys.Free;
  inherited Destroy;
end;

procedure TWorld.ActivateMonkey(const AMonkey: TMonkey);
var
  VisionDecision: TMonkeyVisionDecision;
  VisionSlots: TMonkeyVisionSlots;
  Action: TMonkeyActionDecision;
begin
  VisionDecision := AMonkey.CurrentVisionDecision;
  VisionSlots := BuildVisionForMonkey(AMonkey, VisionDecision);
  Action := AMonkey.DecideNextAction(VisionSlots);

  ResolveMonkeyAction(AMonkey, Action);
  AMonkey.AdvanceAge;
  AMonkey.AdvancePregnancy;
end;

procedure TWorld.AddMonkey(const AMonkey: TMonkey);
begin
  FMonkeys.Add(AMonkey);
end;

procedure TWorld.AddVisionSlot(var AVisionSlots: TMonkeyVisionSlots;
  const ASourceX, ASourceY, ARelativeX, ARelativeY: Integer);
var
  SlotIndex: Integer;
  WorldX: Integer;
  WorldY: Integer;
  Monkey: TMonkey;
begin
  SlotIndex := Length(AVisionSlots);
  SetLength(AVisionSlots, SlotIndex + 1);

  WorldX := ASourceX + ARelativeX;
  WorldY := ASourceY + ARelativeY;

  AVisionSlots[SlotIndex].RelativeX := ARelativeX;
  AVisionSlots[SlotIndex].RelativeY := ARelativeY;
  AVisionSlots[SlotIndex].Sex := msMale;
  AVisionSlots[SlotIndex].Strength := 0;

  if not IsInsideBoard(WorldX, WorldY) then
  begin
    AVisionSlots[SlotIndex].State := mcsBlocked;
    Exit;
  end;

  Monkey := FBoard[BoardIndex(WorldX, WorldY)];
  if Monkey = nil then
  begin
    AVisionSlots[SlotIndex].State := mcsEmpty;
    Exit;
  end;

  AVisionSlots[SlotIndex].State := mcsOccupied;
  AVisionSlots[SlotIndex].Sex := Monkey.Sex;
  AVisionSlots[SlotIndex].Strength := Monkey.Strength;
end;

function TWorld.BoardIndex(const AX, AY: Integer): Integer;
begin
  Result := (AY * FConfig.SizeX) + AX;
end;

function TWorld.BuildVisionForMonkey(const AMonkey: TMonkey;
  const AVisionDecision: TMonkeyVisionDecision): TMonkeyVisionSlots;
var
  MonkeyX: Integer;
  MonkeyY: Integer;
  Radius: Integer;
  RelativeX: Integer;
  RelativeY: Integer;
begin
  SetLength(Result, 0);

  if not FindMonkeyPosition(AMonkey, MonkeyX, MonkeyY) then
    Exit;

  Radius := 1;
  while Length(Result) < AMonkey.VisionSlots do
  begin
    for RelativeY := -Radius to Radius do
      for RelativeX := -Radius to Radius do
      begin
        if (RelativeX = 0) and (RelativeY = 0) then
          Continue;
        if Max(Abs(RelativeX), Abs(RelativeY)) <> Radius then
          Continue;

        AddVisionSlot(Result, MonkeyX, MonkeyY, RelativeX, RelativeY);
        if Length(Result) >= AMonkey.VisionSlots then
          Exit;
      end;

    Inc(Radius);
  end;
end;

procedure TWorld.ClearBoard;
begin
  SetLength(FBoard, FConfig.SizeX * FConfig.SizeY);
end;

procedure TWorld.CreateInitialPopulation;
var
  I: Integer;
  X: Integer;
  Y: Integer;
  Init: TMonkeyInit;
  Monkey: TMonkey;
begin
  for I := 0 to FConfig.PopulationCount - 1 do
  begin
    if not FindRandomEmptyCell(X, Y) then
      Exit;

    Inc(FNextMonkeyId);
    Init.Id := FNextMonkeyId;
    if Random(2) = 0 then
      Init.Sex := msMale
    else
      Init.Sex := msFemale;
    Init.MotherId := 0;
    Init.FatherId := 0;
    Init.MaternalGrandmotherId := 0;
    Init.MaternalGrandfatherId := 0;
    Init.PaternalGrandmotherId := 0;
    Init.PaternalGrandfatherId := 0;
    Init.GenCount := 0;
    Init.Strength := FConfig.InitialStrength;
    Init.Lifespan := FConfig.BaseLifespan;
    Init.VisionSlots := FConfig.VisionSlots;

    Monkey := TMonkey.Create(Init);
    FMonkeys.Add(Monkey);
    FBoard[BoardIndex(X, Y)] := Monkey;
  end;
end;

class function TWorld.EnsureAtLeast(const AValue, AMinimum: Integer): Integer;
begin
  Result := AValue;
  if Result < AMinimum then
    Result := AMinimum;
end;

function TWorld.FindRandomEmptyCell(out AX, AY: Integer): Boolean;
var
  I: Integer;
  X: Integer;
  Y: Integer;
  Attempts: Integer;
begin
  Result := False;
  if Length(FBoard) = 0 then
    Exit;

  Attempts := FConfig.SizeX * FConfig.SizeY * 2;
  for I := 0 to Attempts - 1 do
  begin
    X := Random(FConfig.SizeX);
    Y := Random(FConfig.SizeY);
    if FBoard[BoardIndex(X, Y)] = nil then
    begin
      AX := X;
      AY := Y;
      Exit(True);
    end;
  end;

  for Y := 0 to FConfig.SizeY - 1 do
    for X := 0 to FConfig.SizeX - 1 do
      if FBoard[BoardIndex(X, Y)] = nil then
      begin
        AX := X;
        AY := Y;
        Exit(True);
      end;
end;

function TWorld.FindMonkeyPosition(const AMonkey: TMonkey; out AX,
  AY: Integer): Boolean;
var
  X: Integer;
  Y: Integer;
begin
  Result := False;

  for Y := 0 to FConfig.SizeY - 1 do
    for X := 0 to FConfig.SizeX - 1 do
      if FBoard[BoardIndex(X, Y)] = AMonkey then
      begin
        AX := X;
        AY := Y;
        Exit(True);
      end;
end;

function TWorld.GetMonkeyCount: Integer;
begin
  Result := FMonkeys.Count;
end;

function TWorld.GetMonkeySnapshots: TWorldMonkeySnapshots;
var
  X: Integer;
  Y: Integer;
  Monkey: TMonkey;
begin
  SetLength(Result, 0);

  for Y := 0 to FConfig.SizeY - 1 do
    for X := 0 to FConfig.SizeX - 1 do
    begin
      Monkey := FBoard[BoardIndex(X, Y)];
      if Monkey <> nil then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)].X := X;
        Result[High(Result)].Y := Y;
        Result[High(Result)].Sex := Monkey.Sex;
        Result[High(Result)].IsPregnant := Monkey.IsPregnant;
      end;
    end;
end;

function TWorld.TryGetMonkeyTraitsAt(const AX, AY: Integer;
  out ATraits: TMonkeyTraitSnapshot): Boolean;
var
  Monkey: TMonkey;
begin
  Result := False;

  if not IsInsideBoard(AX, AY) then
    Exit;

  Monkey := FBoard[BoardIndex(AX, AY)];
  if Monkey = nil then
    Exit;

  ATraits.X := AX;
  ATraits.Y := AY;
  ATraits.Id := Monkey.Id;
  ATraits.Sex := Monkey.Sex;
  ATraits.MotherId := Monkey.MotherId;
  ATraits.FatherId := Monkey.FatherId;
  ATraits.MaternalGrandmotherId := Monkey.MaternalGrandmotherId;
  ATraits.MaternalGrandfatherId := Monkey.MaternalGrandfatherId;
  ATraits.PaternalGrandmotherId := Monkey.PaternalGrandmotherId;
  ATraits.PaternalGrandfatherId := Monkey.PaternalGrandfatherId;
  ATraits.GenCount := Monkey.GenCount;
  ATraits.Strength := Monkey.Strength;
  ATraits.Lifespan := Monkey.Lifespan;
  ATraits.Age := Monkey.Age;
  ATraits.VisionSlots := Monkey.VisionSlots;
  ATraits.MemoryCount := Monkey.MemoryCount;
  ATraits.PregnantTurnsRemaining := Monkey.PregnantTurnsRemaining;
  ATraits.IsPregnant := Monkey.IsPregnant;
  ATraits.Alive := Monkey.Alive;

  Result := True;
end;

function TWorld.GetSizeX: Integer;
begin
  Result := FConfig.SizeX;
end;

function TWorld.GetSizeY: Integer;
begin
  Result := FConfig.SizeY;
end;

function TWorld.IsInsideBoard(const AX, AY: Integer): Boolean;
begin
  Result := (AX >= 0) and (AY >= 0) and
    (AX < FConfig.SizeX) and (AY < FConfig.SizeY);
end;

function TWorld.MonkeyPriority(const AMonkey: TMonkey): Double;
begin
  Result := AMonkey.Strength + AMonkey.Age;
end;

procedure TWorld.DirectionToDelta(const ADirection: Integer; out ADeltaX,
  ADeltaY: Integer);
begin
  ADeltaX := 0;
  ADeltaY := 0;

  case ADirection of
    1:
      ADeltaY := -1;
    2:
      begin
        ADeltaX := 1;
        ADeltaY := -1;
      end;
    3:
      ADeltaX := 1;
    4:
      begin
        ADeltaX := 1;
        ADeltaY := 1;
      end;
    5:
      ADeltaY := 1;
    6:
      begin
        ADeltaX := -1;
        ADeltaY := 1;
      end;
    7:
      ADeltaX := -1;
    8:
      begin
        ADeltaX := -1;
        ADeltaY := -1;
      end;
  end;
end;

procedure TWorld.RemoveDeadMonkeys;
var
  I: Integer;
  X: Integer;
  Y: Integer;
begin
  for I := FMonkeys.Count - 1 downto 0 do
    if not FMonkeys[I].Alive then
    begin
      if FindMonkeyPosition(FMonkeys[I], X, Y) then
        FBoard[BoardIndex(X, Y)] := nil;
      FMonkeys.Delete(I);
    end;
end;

procedure TWorld.Restart(const AConfig: TWorldConfig);
begin
  FConfig := AConfig;

  FConfig.SizeX := EnsureAtLeast(FConfig.SizeX, 1);
  FConfig.SizeY := EnsureAtLeast(FConfig.SizeY, 1);
  FConfig.VisionSlots := EnsureAtLeast(FConfig.VisionSlots, 1);
  FConfig.PopulationCount := EnsureAtLeast(FConfig.PopulationCount, 0);

  FNextMonkeyId := 0;
  FMonkeys.Clear;
  ClearBoard;
  CreateInitialPopulation;
end;

procedure TWorld.ResolveMonkeyAction(const AMonkey: TMonkey;
  const AAction: TMonkeyActionDecision);
var
  CurrentX: Integer;
  CurrentY: Integer;
  DeltaX: Integer;
  DeltaY: Integer;
  TargetX: Integer;
  TargetY: Integer;
begin
  DirectionToDelta(AAction.MoveDirection, DeltaX, DeltaY);
  if (DeltaX = 0) and (DeltaY = 0) then
    Exit;

  if not FindMonkeyPosition(AMonkey, CurrentX, CurrentY) then
    Exit;

  TargetX := CurrentX + DeltaX;
  TargetY := CurrentY + DeltaY;
  if not IsInsideBoard(TargetX, TargetY) then
    Exit;

  if FBoard[BoardIndex(TargetX, TargetY)] <> nil then
    Exit;

  FBoard[BoardIndex(CurrentX, CurrentY)] := nil;
  FBoard[BoardIndex(TargetX, TargetY)] := AMonkey;
  AMonkey.ShiftMemoryAfterMove(DeltaX, DeltaY);
end;

procedure TWorld.RunWorldTurn;
var
  I: Integer;
begin
  SortMonkeysForTurn;

  for I := 0 to FMonkeys.Count - 1 do
    ActivateMonkey(FMonkeys[I]);

  RemoveDeadMonkeys;
end;

procedure TWorld.ShuffleMonkeys;
var
  I: Integer;
  J: Integer;
begin
  for I := FMonkeys.Count - 1 downto 1 do
  begin
    J := Random(I + 1);
    FMonkeys.Exchange(I, J);
  end;
end;

procedure TWorld.SortMonkeysForTurn;
begin
  ShuffleMonkeys;
  FMonkeys.Sort(TComparer<TMonkey>.Construct(
    function(const Left, Right: TMonkey): Integer
    begin
      Result := CompareValue(MonkeyPriority(Right), MonkeyPriority(Left));
    end));
end;

end.
