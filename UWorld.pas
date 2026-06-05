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
    TotalStrength: Double;
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
    function AreCloseRelatives(const AFirst, ASecond: TMonkey): Boolean;
    function BoardIndex(const AX, AY: Integer): Integer;
    function BuildVisionForMonkey(const AMonkey: TMonkey;
      const AVisionDecision: TMonkeyVisionDecision): TMonkeyVisionSlots;
    function CombatWinProbability(const AAttacker, ADefender: TMonkey): Double;
    function CreateOffspring(const AMother, AFather: TMonkey): TMonkey;
    procedure ClearBoard;
    procedure CreateInitialPopulation;
    function FindEmptyCellNear(const ACenterX, ACenterY: Integer; out AX,
      AY: Integer): Boolean;
    function FindRandomEmptyCell(out AX, AY: Integer): Boolean;
    function FindMonkeyPosition(const AMonkey: TMonkey; out AX, AY: Integer): Boolean;
    function GetMonkeyCount: Integer;
    function GetSizeX: Integer;
    function GetSizeY: Integer;
    function IsInsideBoard(const AX, AY: Integer): Boolean;
    function MonkeyPriority(const AMonkey: TMonkey): Double;
    function MutateBySigmaPercent(const ABaseValue, ASigmaPercent: Double): Double;
    function RandomGaussian: Double;
    procedure ActivateMonkey(const AMonkey: TMonkey);
    procedure DirectionToDelta(const ADirection: Integer; out ADeltaX, ADeltaY: Integer);
    procedure RemoveDeadMonkeys;
    procedure ProcessDeliveries;
    procedure ResolveCombat(const AAttacker, ADefender: TMonkey;
      const ACurrentX, ACurrentY, ATargetX, ATargetY: Integer);
    procedure ResolveMating(const AMovingMonkey, ATargetMonkey: TMonkey;
      const AMovingMonkeyWantsToMate: Boolean);
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
  if not AMonkey.Alive then
    Exit;

  VisionDecision := AMonkey.CurrentVisionDecision;
  VisionSlots := BuildVisionForMonkey(AMonkey, VisionDecision);
  Action := AMonkey.DecideNextAction(VisionSlots);

  ResolveMonkeyAction(AMonkey, Action);
  if AMonkey.Alive then
  begin
    AMonkey.AdvanceAge;
    AMonkey.AdvancePregnancy;
  end;
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

function TWorld.AreCloseRelatives(const AFirst, ASecond: TMonkey): Boolean;

  function IsKnownId(const AId: TMonkeyId): Boolean;
  begin
    Result := AId <> 0;
  end;

  function HasParent(const AMonkey: TMonkey; const AParentId: TMonkeyId): Boolean;
  begin
    Result := IsKnownId(AParentId) and
      ((AMonkey.MotherId = AParentId) or (AMonkey.FatherId = AParentId));
  end;

  function HasGrandparent(const AMonkey: TMonkey;
    const AGrandparentId: TMonkeyId): Boolean;
  begin
    Result := IsKnownId(AGrandparentId) and
      ((AMonkey.MaternalGrandmotherId = AGrandparentId) or
      (AMonkey.MaternalGrandfatherId = AGrandparentId) or
      (AMonkey.PaternalGrandmotherId = AGrandparentId) or
      (AMonkey.PaternalGrandfatherId = AGrandparentId));
  end;

begin
  Result :=
    HasParent(AFirst, ASecond.Id) or
    HasParent(ASecond, AFirst.Id) or
    HasGrandparent(AFirst, ASecond.Id) or
    HasGrandparent(ASecond, AFirst.Id) or
    (IsKnownId(AFirst.MotherId) and (AFirst.MotherId = ASecond.MotherId)) or
    (IsKnownId(AFirst.FatherId) and (AFirst.FatherId = ASecond.FatherId));
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

function TWorld.CombatWinProbability(const AAttacker,
  ADefender: TMonkey): Double;
var
  Sigma: Double;
begin
  Sigma := Max(FConfig.SigmaCombat, 0.01);
  Result := 1 / (1 + Exp(-(AAttacker.TotalStrength - ADefender.TotalStrength) /
    Sigma));
end;

function TWorld.CreateOffspring(const AMother, AFather: TMonkey): TMonkey;
var
  Init: TMonkeyInit;
begin
  Inc(FNextMonkeyId);
  Init.Id := FNextMonkeyId;
  if Random(2) = 0 then
    Init.Sex := msMale
  else
    Init.Sex := msFemale;

  Init.MotherId := AMother.Id;
  Init.FatherId := AFather.Id;
  Init.MaternalGrandmotherId := AMother.MotherId;
  Init.MaternalGrandfatherId := AMother.FatherId;
  Init.PaternalGrandmotherId := AFather.MotherId;
  Init.PaternalGrandfatherId := AFather.FatherId;
  Init.GenCount := Max(AMother.GenCount, AFather.GenCount) + 1;
  Init.Strength := MutateBySigmaPercent((AMother.Strength + AFather.Strength) /
    2, FConfig.MutationSigmaPercent);
  Init.Lifespan := MutateBySigmaPercent((AMother.Lifespan + AFather.Lifespan) /
    2, FConfig.MutationSigmaPercent);
  Init.VisionSlots := FConfig.VisionSlots;

  Result := TMonkey.Create(Init);
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
    Init.Strength := MutateBySigmaPercent(FConfig.InitialStrength,
      FConfig.InitSigmaPercent);
    Init.Lifespan := MutateBySigmaPercent(FConfig.BaseLifespan,
      FConfig.InitSigmaPercent);
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

function TWorld.FindEmptyCellNear(const ACenterX, ACenterY: Integer; out AX,
  AY: Integer): Boolean;
var
  I: Integer;
  DirectionIndex: Integer;
  CandidateX: Integer;
  CandidateY: Integer;
  Directions: array[0..7] of Integer;
begin
  Result := False;

  for I := Low(Directions) to High(Directions) do
    Directions[I] := I;

  for I := High(Directions) downto Low(Directions) + 1 do
  begin
    DirectionIndex := Random(I + 1);
    CandidateX := Directions[I];
    Directions[I] := Directions[DirectionIndex];
    Directions[DirectionIndex] := CandidateX;
  end;

  for I := Low(Directions) to High(Directions) do
  begin
    case Directions[I] of
      0:
        begin
          CandidateX := ACenterX - 1;
          CandidateY := ACenterY - 1;
        end;
      1:
        begin
          CandidateX := ACenterX;
          CandidateY := ACenterY - 1;
        end;
      2:
        begin
          CandidateX := ACenterX + 1;
          CandidateY := ACenterY - 1;
        end;
      3:
        begin
          CandidateX := ACenterX - 1;
          CandidateY := ACenterY;
        end;
      4:
        begin
          CandidateX := ACenterX + 1;
          CandidateY := ACenterY;
        end;
      5:
        begin
          CandidateX := ACenterX - 1;
          CandidateY := ACenterY + 1;
        end;
      6:
        begin
          CandidateX := ACenterX;
          CandidateY := ACenterY + 1;
        end;
    else
      begin
        CandidateX := ACenterX + 1;
        CandidateY := ACenterY + 1;
      end;
    end;

    if IsInsideBoard(CandidateX, CandidateY) and
      (FBoard[BoardIndex(CandidateX, CandidateY)] = nil) then
    begin
      AX := CandidateX;
      AY := CandidateY;
      Exit(True);
    end;
  end;
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
  ATraits.TotalStrength := Monkey.TotalStrength;
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
  Result := AMonkey.TotalStrength;
end;

function TWorld.MutateBySigmaPercent(const ABaseValue,
  ASigmaPercent: Double): Double;
var
  Sigma: Double;
begin
  Sigma := Max(0, ASigmaPercent) / 100;
  Result := ABaseValue + (ABaseValue * Sigma * RandomGaussian);
  Result := Max(Result, 0.01);
end;

function TWorld.RandomGaussian: Double;
var
  U1: Double;
  U2: Double;
begin
  repeat
    U1 := Random;
  until U1 > 0;
  U2 := Random;

  Result := Sqrt(-2 * Ln(U1)) * Cos(2 * Pi * U2);
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

procedure TWorld.ProcessDeliveries;
var
  I: Integer;
  MotherX: Integer;
  MotherY: Integer;
  X: Integer;
  Y: Integer;
  Newborn: TMonkey;
begin
  for I := 0 to FMonkeys.Count - 1 do
    if FMonkeys[I].Alive and (FMonkeys[I].PregnantTurnsRemaining = 0) and
      (FMonkeys[I].UnbornChild <> nil) then
    begin
      if not FindMonkeyPosition(FMonkeys[I], MotherX, MotherY) then
        Continue;
      if not FindEmptyCellNear(MotherX, MotherY, X, Y) then
        Continue;

      Newborn := FMonkeys[I].ExtractUnbornChild;
      try
        FMonkeys.Add(Newborn);
        FBoard[BoardIndex(X, Y)] := Newborn;
      except
        Newborn.Free;
        raise;
      end;
    end;
end;

procedure TWorld.ResolveCombat(const AAttacker, ADefender: TMonkey;
  const ACurrentX, ACurrentY, ATargetX, ATargetY: Integer);
var
  AttackerWins: Boolean;
  CombatGain: Double;
begin
  AttackerWins := Random < CombatWinProbability(AAttacker, ADefender);
  CombatGain := Max(0, FConfig.CombatGainPercent) / 100;

  if AttackerWins then
  begin
    AAttacker.Strength := AAttacker.Strength + (ADefender.Strength *
      CombatGain);
    ADefender.Kill;
    FBoard[BoardIndex(ACurrentX, ACurrentY)] := nil;
    FBoard[BoardIndex(ATargetX, ATargetY)] := AAttacker;
    AAttacker.ShiftMemoryAfterMove(ATargetX - ACurrentX,
      ATargetY - ACurrentY);
  end
  else
  begin
    ADefender.Strength := ADefender.Strength + (AAttacker.Strength *
      CombatGain);
    AAttacker.Kill;
    FBoard[BoardIndex(ACurrentX, ACurrentY)] := nil;
  end;
end;

procedure TWorld.ResolveMating(const AMovingMonkey,
  ATargetMonkey: TMonkey; const AMovingMonkeyWantsToMate: Boolean);
var
  Female: TMonkey;
  Male: TMonkey;
  Newborn: TMonkey;
begin
  if not AMovingMonkeyWantsToMate then
    Exit;
  if AMovingMonkey.Sex = ATargetMonkey.Sex then
    Exit;

  if AMovingMonkey.Sex = msFemale then
  begin
    Female := AMovingMonkey;
    Male := ATargetMonkey;
  end
  else
  begin
    Female := ATargetMonkey;
    Male := AMovingMonkey;
  end;

  if Female.IsPregnant then
    Exit;
  if not Female.WantsToMateWith(Male) then
    Exit;
  if not Male.WantsToMateWith(Female) then
    Exit;

  Newborn := CreateOffspring(Female, Male);
  try
    Female.ApplyMatingCost(FConfig.MatingCost);
    Male.ApplyMatingCost(FConfig.MatingCost);

    if Female.Alive then
    begin
      Female.StartPregnancy(9, Newborn);
      Newborn := nil;
    end;
  finally
    Newborn.Free;
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
  TargetMonkey: TMonkey;
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

  TargetMonkey := FBoard[BoardIndex(TargetX, TargetY)];
  if TargetMonkey <> nil then
  begin
    if TargetMonkey = AMonkey then
      Exit;

    if AreCloseRelatives(AMonkey, TargetMonkey) then
      Exit;

    if AMonkey.Sex = TargetMonkey.Sex then
      ResolveCombat(AMonkey, TargetMonkey, CurrentX, CurrentY, TargetX,
        TargetY)
    else
      ResolveMating(AMonkey, TargetMonkey, AAction.WantsToMate);

    Exit;
  end;

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
  ProcessDeliveries;
end;

procedure TWorld.ShuffleMonkeys;
var
  I: Integer;
  J: Integer;
begin
  // Randomize equal-priority monkeys so ties do not always favor creation order.
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
