unit UMonkey;

interface

uses
  UNeuralNet;

type
  TMonkeyId = Int64;

  TMonkeySex = (msMale, msFemale);

  TMonkeyCellState = (mcsUnknown, mcsEmpty, mcsOccupied, mcsBlocked);

  TMonkeyVisionSlot = record
    RelativeX: Integer;
    RelativeY: Integer;
    State: TMonkeyCellState;
    Sex: TMonkeySex;
    Strength: Double;
  end;

  TMonkeyVisionSlots = array of TMonkeyVisionSlot;

  TMonkeyMemorySlot = record
    RelativeX: Integer;
    RelativeY: Integer;
    State: TMonkeyCellState;
    Sex: TMonkeySex;
    Strength: Double;
    LastSeenAge: Integer;
  end;

  TMonkeyMemorySlots = array of TMonkeyMemorySlot;
  TMonkeyNNInputs = array of Double;

  TMonkeyStrategy = (stEid, stAgo, stSuperAgo);

  TMonkeyVisionDecision = record
    IsFar: Boolean;
    Direction: Integer;
    class function Default: TMonkeyVisionDecision; static;
  end;

  TMonkeyActionDecision = record
    MoveDirection: Integer;
    WantsToMate: Boolean;
    NextVision: TMonkeyVisionDecision;
    class function Stay(const ANextVision: TMonkeyVisionDecision): TMonkeyActionDecision; static;
  end;

  TMonkeyInit = record
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
    VisionSlots: Integer;
    BrainWeights: TNeuralNetWeights;
  end;

  TMonkey = class
  private
    FId: TMonkeyId;
    FSex: TMonkeySex;
    FMotherId: TMonkeyId;
    FFatherId: TMonkeyId;
    FMaternalGrandmotherId: TMonkeyId;
    FMaternalGrandfatherId: TMonkeyId;
    FPaternalGrandmotherId: TMonkeyId;
    FPaternalGrandfatherId: TMonkeyId;
    FGenCount: Integer;
    FStrength: Double;
    FLifespan: Double;
    FAge: Integer;
    FVisionSlots: Integer;
    FBrainWeights: TNeuralNetWeights;
    FMemory: TMonkeyMemorySlots;
    FCurrentVision: TMonkeyVisionDecision;
    FLastMoveDirection: Integer;
    FUnbornChild: TMonkey;
    FPregnantTurnsRemaining: Integer;
    FAlive: Boolean;

    class function EnsureAtLeast(const AValue, AMinimum: Integer): Integer; static;
    class function EnsurePositive(const AValue, ADefault: Double): Double; static;
    class function WinningOutputIndex(const AOutputs: TNeuralNetOutputs;
      const AStartIndex, ACount: Integer): Integer; static;
    function BuildNeuralNetConfig: TNeuralNetConfig;
    function CellStateAsNNValue(const ASlot: TMonkeyMemorySlot): Double;
    function DecodeActionFromOutputs(
      const AOutputs: TNeuralNetOutputs): TMonkeyActionDecision;
    function DirectionAwayFrom(const ADirection: Integer): Integer;
    function DirectionFromDelta(const ADeltaX, ADeltaY: Integer): Integer;
    procedure DirectionToDelta(const ADirection: Integer; out ADeltaX,
      ADeltaY: Integer);
    function EidStrategyMove: Integer;
    function EvaluateBrain(const AInputs: TMonkeyNNInputs): TNeuralNetOutputs;
    function FindMemorySlot(const ARelativeX, ARelativeY: Integer): Integer;
    function FindClosestMonkeyInMemory(out AMemorySlot: TMonkeyMemorySlot): Boolean;
    function FindClosestMonkeyInDirection(const ADirection: Integer;
      out AMemorySlot: TMonkeyMemorySlot): Boolean;
    function GetIsPregnant: Boolean;
    function GetMemoryCount: Integer;
    function GetTotalStrength: Double;
    function GetBrainWeights: TNeuralNetWeights;
    function AgoStrategyMove: Integer;
    function AvoidBlockedMove(const ADirection: Integer): Integer;
    function IsBlockedMove(const ADirection: Integer): Boolean;
    function MoveForTarget(const ARelativeX, ARelativeY: Integer;
      const ATargetSex: TMonkeySex; const ATargetStrength: Double): Integer;
    function SexAsNNValue(const ASlot: TMonkeyMemorySlot): Double;
    function SuperAgoStrategyMove: Integer;
    procedure ClearMemorySlot(var ASlot: TMonkeyMemorySlot);
    procedure InitializeMemory;
    procedure StoreVisionSlot(const AVisionSlot: TMonkeyVisionSlot);
  public
    constructor Create(const AInit: TMonkeyInit);
    destructor Destroy; override;

    function BuildNNInput: TMonkeyNNInputs;
    function CurrentVisionDecision: TMonkeyVisionDecision;
    function DecideNextAction(const AVisionSlots: TMonkeyVisionSlots): TMonkeyActionDecision;
    function ExtractUnbornChild: TMonkey;
    function IsNaturalDeathDue: Boolean;
    function WantsToMateWith(const AMate: TMonkey): Boolean;
    procedure AdvanceAge;
    procedure ClearMemory;
    procedure DiscardUnbornChild;
    procedure ApplyMatingCost(const ATurnCost: Double);
    procedure Kill;
    procedure StartPregnancy(const ATurns: Integer; const AUnbornChild: TMonkey);
    procedure AdvancePregnancy;
    procedure ShiftMemoryAfterMove(const ADeltaX, ADeltaY: Integer);
    procedure UpdateMemoryFromVision(const AVisionSlots: TMonkeyVisionSlots);

    property Id: TMonkeyId read FId;
    property Sex: TMonkeySex read FSex;
    property MotherId: TMonkeyId read FMotherId;
    property FatherId: TMonkeyId read FFatherId;
    property MaternalGrandmotherId: TMonkeyId read FMaternalGrandmotherId;
    property MaternalGrandfatherId: TMonkeyId read FMaternalGrandfatherId;
    property PaternalGrandmotherId: TMonkeyId read FPaternalGrandmotherId;
    property PaternalGrandfatherId: TMonkeyId read FPaternalGrandfatherId;
    property GenCount: Integer read FGenCount;
    property Strength: Double read FStrength write FStrength;
    property TotalStrength: Double read GetTotalStrength;
    property Lifespan: Double read FLifespan write FLifespan;
    property Age: Integer read FAge;
    property VisionSlots: Integer read FVisionSlots;
    property BrainWeights: TNeuralNetWeights read GetBrainWeights;
    property CurrentVision: TMonkeyVisionDecision read FCurrentVision;
    property MemoryCount: Integer read GetMemoryCount;
    property UnbornChild: TMonkey read FUnbornChild;
    property PregnantTurnsRemaining: Integer read FPregnantTurnsRemaining;
    property IsPregnant: Boolean read GetIsPregnant;
    property Alive: Boolean read FAlive;
  end;

implementation

uses
  System.Math;

{ TMonkeyVisionDecision }

class function TMonkeyVisionDecision.Default: TMonkeyVisionDecision;
begin
  Result.IsFar := False;
  Result.Direction := 1;
end;

{ TMonkeyActionDecision }

class function TMonkeyActionDecision.Stay(
  const ANextVision: TMonkeyVisionDecision): TMonkeyActionDecision;
begin
  Result.MoveDirection := 0;
  Result.WantsToMate := False;
  Result.NextVision := ANextVision;
end;

{ TMonkey }

constructor TMonkey.Create(const AInit: TMonkeyInit);
begin
  inherited Create;

  FId := AInit.Id;
  FSex := AInit.Sex;
  FMotherId := AInit.MotherId;
  FFatherId := AInit.FatherId;
  FMaternalGrandmotherId := AInit.MaternalGrandmotherId;
  FMaternalGrandfatherId := AInit.MaternalGrandfatherId;
  FPaternalGrandmotherId := AInit.PaternalGrandmotherId;
  FPaternalGrandfatherId := AInit.PaternalGrandfatherId;
  FGenCount := EnsureAtLeast(AInit.GenCount, 0);
  FStrength := EnsurePositive(AInit.Strength, 1);
  FLifespan := EnsurePositive(AInit.Lifespan, 1);
  FVisionSlots := EnsureAtLeast(AInit.VisionSlots, 1);
  FBrainWeights := Copy(AInit.BrainWeights);
  FCurrentVision := TMonkeyVisionDecision.Default;
  FLastMoveDirection := 0;
  InitializeMemory;
  FAge := 0;
  FUnbornChild := nil;
  FPregnantTurnsRemaining := 0;
  FAlive := True;
end;

destructor TMonkey.Destroy;
begin
  DiscardUnbornChild;
  inherited Destroy;
end;

procedure TMonkey.AdvanceAge;
begin
  if not FAlive then
    Exit;

  Inc(FAge);
  if IsNaturalDeathDue then
    Kill;
end;

procedure TMonkey.AdvancePregnancy;
begin
  if FPregnantTurnsRemaining > 0 then
    Dec(FPregnantTurnsRemaining);
end;

procedure TMonkey.ApplyMatingCost(const ATurnCost: Double);
begin
  if not FAlive then
    Exit;

  FLifespan := EnsurePositive(FLifespan - Max(0, ATurnCost), 0.01);
  if IsNaturalDeathDue then
    Kill;
end;

function TMonkey.BuildNNInput: TMonkeyNNInputs;
var
  I: Integer;
  InputIndex: Integer;
begin
  SetLength(Result, 5 + (Length(FMemory) * 2));
  InputIndex := 0;

  if FLifespan > 0 then
    Result[InputIndex] := FAge / FLifespan
  else
    Result[InputIndex] := 0;
  Inc(InputIndex);

  if FSex = msFemale then
    Result[InputIndex] := 1
  else
    Result[InputIndex] := 0;
  Inc(InputIndex);

  Result[InputIndex] := FStrength;
  Inc(InputIndex);
  Result[InputIndex] := GetTotalStrength;
  Inc(InputIndex);

  if IsPregnant then
    Result[InputIndex] := 1
  else
    Result[InputIndex] := 0;
  Inc(InputIndex);

  for I := Low(FMemory) to High(FMemory) do
  begin
    Result[InputIndex] := SexAsNNValue(FMemory[I]);
    Inc(InputIndex);
    Result[InputIndex] := CellStateAsNNValue(FMemory[I]);
    Inc(InputIndex);
  end;
end;

function TMonkey.BuildNeuralNetConfig: TNeuralNetConfig;
var
  LayerNodeCount: Integer;
begin
  LayerNodeCount := (EnsureAtLeast(FVisionSlots, 1) * 12) + 5;

  Result.InputCount := LayerNodeCount;
  Result.Hidden1Count := LayerNodeCount;
  Result.Hidden2Count := LayerNodeCount;
  Result.Hidden3Count := LayerNodeCount;
  Result.OutputCount := 13;
end;

function TMonkey.CellStateAsNNValue(const ASlot: TMonkeyMemorySlot): Double;
begin
  case ASlot.State of
    mcsUnknown:
      Result := -1;
    mcsEmpty:
      Result := 0;
    mcsOccupied:
      Result := ASlot.Strength;
    mcsBlocked:
      Result := -2;
  else
    Result := 0;
  end;
end;

procedure TMonkey.ClearMemory;
var
  I: Integer;
begin
  for I := Low(FMemory) to High(FMemory) do
    ClearMemorySlot(FMemory[I]);
end;

procedure TMonkey.ClearMemorySlot(var ASlot: TMonkeyMemorySlot);
begin
  ASlot.State := mcsUnknown;
  ASlot.Sex := msMale;
  ASlot.Strength := 0;
  ASlot.LastSeenAge := -1;
end;

function TMonkey.CurrentVisionDecision: TMonkeyVisionDecision;
begin
  Result := FCurrentVision;
end;

function TMonkey.DirectionAwayFrom(const ADirection: Integer): Integer;
begin
  case ADirection of
    1: Result := 5;
    2: Result := 6;
    3: Result := 7;
    4: Result := 8;
    5: Result := 1;
    6: Result := 2;
    7: Result := 3;
    8: Result := 4;
  else
    Result := 0;
  end;
end;

function TMonkey.DirectionFromDelta(const ADeltaX, ADeltaY: Integer): Integer;
var
  DeltaX: Integer;
  DeltaY: Integer;
begin
  DeltaX := Sign(ADeltaX);
  DeltaY := Sign(ADeltaY);

  if (DeltaX = 0) and (DeltaY < 0) then
    Result := 1
  else if (DeltaX > 0) and (DeltaY < 0) then
    Result := 2
  else if (DeltaX > 0) and (DeltaY = 0) then
    Result := 3
  else if (DeltaX > 0) and (DeltaY > 0) then
    Result := 4
  else if (DeltaX = 0) and (DeltaY > 0) then
    Result := 5
  else if (DeltaX < 0) and (DeltaY > 0) then
    Result := 6
  else if (DeltaX < 0) and (DeltaY = 0) then
    Result := 7
  else if (DeltaX < 0) and (DeltaY < 0) then
    Result := 8
  else
    Result := 0;
end;

procedure TMonkey.DirectionToDelta(const ADirection: Integer; out ADeltaX,
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

function TMonkey.DecideNextAction(
  const AVisionSlots: TMonkeyVisionSlots): TMonkeyActionDecision;
var
  Inputs: TMonkeyNNInputs;
  Outputs: TNeuralNetOutputs;
begin
  UpdateMemoryFromVision(AVisionSlots);

  Inputs := BuildNNInput;
  Outputs := EvaluateBrain(Inputs);
  Result := DecodeActionFromOutputs(Outputs);
  FCurrentVision := Result.NextVision;
end;

function TMonkey.DecodeActionFromOutputs(
  const AOutputs: TNeuralNetOutputs): TMonkeyActionDecision;
begin
  Result := TMonkeyActionDecision.Stay(FCurrentVision);
  if Length(AOutputs) < 13 then
    Exit;

  case TMonkeyStrategy(WinningOutputIndex(AOutputs, 0, 3)) of
    stEid:
      Result.MoveDirection := EidStrategyMove;
    stAgo:
      Result.MoveDirection := AgoStrategyMove;
    stSuperAgo:
      Result.MoveDirection := SuperAgoStrategyMove;
  end;

  Result.WantsToMate := AOutputs[3] >= 0.5;
  Result.NextVision.IsFar := AOutputs[4] >= 0.5;
  Result.NextVision.Direction := WinningOutputIndex(AOutputs, 5, 8) + 1;
end;

class function TMonkey.WinningOutputIndex(const AOutputs: TNeuralNetOutputs;
  const AStartIndex, ACount: Integer): Integer;
var
  I: Integer;
  WinnerValue: Double;
begin
  Result := 0;
  if (ACount <= 0) or (AStartIndex < 0) or
    (AStartIndex + ACount > Length(AOutputs)) then
    Exit;

  WinnerValue := AOutputs[AStartIndex];
  for I := 1 to ACount - 1 do
    if AOutputs[AStartIndex + I] > WinnerValue then
    begin
      Result := I;
      WinnerValue := AOutputs[AStartIndex + I];
    end;
end;

procedure TMonkey.DiscardUnbornChild;
begin
  FUnbornChild.Free;
  FUnbornChild := nil;
  FPregnantTurnsRemaining := 0;
end;

class function TMonkey.EnsureAtLeast(const AValue, AMinimum: Integer): Integer;
begin
  Result := AValue;
  if Result < AMinimum then
    Result := AMinimum;
end;

class function TMonkey.EnsurePositive(const AValue, ADefault: Double): Double;
begin
  Result := AValue;
  if Result <= 0 then
    Result := ADefault;
end;

function TMonkey.AgoStrategyMove: Integer;
var
  BestCount: Integer;
  Counts: array[1..8] of Integer;
  Direction: Integer;
  I: Integer;
  Slot: TMonkeyMemorySlot;
  SlotDirection: Integer;
  TieCount: Integer;
begin
  FillChar(Counts, SizeOf(Counts), 0);
  BestCount := 0;
  TieCount := 0;
  Direction := 0;

  for I := Low(FMemory) to High(FMemory) do
    if FMemory[I].State = mcsOccupied then
    begin
      SlotDirection := DirectionFromDelta(FMemory[I].RelativeX,
        FMemory[I].RelativeY);
      if SlotDirection > 0 then
      begin
        Inc(Counts[SlotDirection]);
        if Counts[SlotDirection] > BestCount then
          BestCount := Counts[SlotDirection];
      end;
    end;

  if BestCount = 0 then
    Exit(AvoidBlockedMove(FLastMoveDirection));

  for I := Low(Counts) to High(Counts) do
    if Counts[I] = BestCount then
    begin
      Inc(TieCount);
      if Random(TieCount) = 0 then
        Direction := I;
    end;

  if FindClosestMonkeyInDirection(Direction, Slot) then
    Result := MoveForTarget(Slot.RelativeX, Slot.RelativeY, Slot.Sex,
      Slot.Strength)
  else
    Result := AvoidBlockedMove(FLastMoveDirection);
end;

function TMonkey.AvoidBlockedMove(const ADirection: Integer): Integer;
begin
  Result := ADirection;
  if IsBlockedMove(Result) then
    Result := DirectionAwayFrom(Result);
end;

function TMonkey.EidStrategyMove: Integer;
var
  Slot: TMonkeyMemorySlot;
begin
  if FindClosestMonkeyInMemory(Slot) then
    Result := MoveForTarget(Slot.RelativeX, Slot.RelativeY, Slot.Sex,
      Slot.Strength)
  else
    Result := AvoidBlockedMove(FLastMoveDirection);
end;

function TMonkey.EvaluateBrain(
  const AInputs: TMonkeyNNInputs): TNeuralNetOutputs;
var
  Config: TNeuralNetConfig;
  I: Integer;
  NeuralNetInputs: TNeuralNetOutputs;
begin
  Config := BuildNeuralNetConfig;
  if (Length(FBrainWeights) <> TNeuralNet.WeightCount(Config)) or
    (Length(AInputs) <> Config.InputCount) then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(NeuralNetInputs, Length(AInputs));
  for I := Low(AInputs) to High(AInputs) do
    NeuralNetInputs[I] := AInputs[I];

  Result := TNeuralNet.Evaluate(Config, FBrainWeights, NeuralNetInputs);
end;

function TMonkey.FindClosestMonkeyInMemory(
  out AMemorySlot: TMonkeyMemorySlot): Boolean;
var
  CandidateDistance: Integer;
  Distance: Integer;
  I: Integer;
  TieCount: Integer;
begin
  Result := False;
  CandidateDistance := MaxInt;
  TieCount := 0;

  for I := Low(FMemory) to High(FMemory) do
    if FMemory[I].State = mcsOccupied then
    begin
      Distance := Max(Abs(FMemory[I].RelativeX), Abs(FMemory[I].RelativeY));
      if (not Result) or (Distance < CandidateDistance) then
      begin
        Result := True;
        CandidateDistance := Distance;
        TieCount := 1;
        AMemorySlot := FMemory[I];
      end
      else if Distance = CandidateDistance then
      begin
        Inc(TieCount);
        if Random(TieCount) = 0 then
          AMemorySlot := FMemory[I];
      end;
    end;
end;

function TMonkey.FindClosestMonkeyInDirection(const ADirection: Integer;
  out AMemorySlot: TMonkeyMemorySlot): Boolean;
var
  CandidateDistance: Integer;
  Distance: Integer;
  I: Integer;
  SlotDirection: Integer;
  TieCount: Integer;
begin
  Result := False;
  CandidateDistance := MaxInt;
  TieCount := 0;

  for I := Low(FMemory) to High(FMemory) do
    if FMemory[I].State = mcsOccupied then
    begin
      SlotDirection := DirectionFromDelta(FMemory[I].RelativeX,
        FMemory[I].RelativeY);
      if SlotDirection <> ADirection then
        Continue;

      Distance := Max(Abs(FMemory[I].RelativeX), Abs(FMemory[I].RelativeY));
      if (not Result) or (Distance < CandidateDistance) then
      begin
        Result := True;
        CandidateDistance := Distance;
        TieCount := 1;
        AMemorySlot := FMemory[I];
      end
      else if Distance = CandidateDistance then
      begin
        Inc(TieCount);
        if Random(TieCount) = 0 then
          AMemorySlot := FMemory[I];
      end;
    end;
end;

function TMonkey.FindMemorySlot(const ARelativeX, ARelativeY: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;

  for I := Low(FMemory) to High(FMemory) do
    if (FMemory[I].RelativeX = ARelativeX) and
      (FMemory[I].RelativeY = ARelativeY) then
      Exit(I);
end;

function TMonkey.ExtractUnbornChild: TMonkey;
begin
  Result := FUnbornChild;
  FUnbornChild := nil;
  FPregnantTurnsRemaining := 0;
end;

function TMonkey.GetIsPregnant: Boolean;
begin
  Result := FPregnantTurnsRemaining > 0;
end;

function TMonkey.GetBrainWeights: TNeuralNetWeights;
begin
  Result := Copy(FBrainWeights);
end;

function TMonkey.GetMemoryCount: Integer;
begin
  Result := Length(FMemory);
end;

function TMonkey.GetTotalStrength: Double;
var
  HalfLifespan: Double;
begin
  HalfLifespan := FLifespan / 2;
  if FAge < HalfLifespan then
    Result := FStrength + FAge
  else
    Result := FStrength - FAge + HalfLifespan;
end;

function TMonkey.IsBlockedMove(const ADirection: Integer): Boolean;
var
  DeltaX: Integer;
  DeltaY: Integer;
  MemoryIndex: Integer;
begin
  Result := False;
  DirectionToDelta(ADirection, DeltaX, DeltaY);
  if (DeltaX = 0) and (DeltaY = 0) then
    Exit;

  MemoryIndex := FindMemorySlot(DeltaX, DeltaY);
  Result := (MemoryIndex >= 0) and (FMemory[MemoryIndex].State = mcsBlocked);
end;

function TMonkey.MoveForTarget(const ARelativeX, ARelativeY: Integer;
  const ATargetSex: TMonkeySex; const ATargetStrength: Double): Integer;
var
  Direction: Integer;
begin
  Direction := DirectionFromDelta(ARelativeX, ARelativeY);
  if Direction = 0 then
    Exit(0);

  if ATargetSex <> FSex then
    Result := Direction
  else if ATargetStrength > GetTotalStrength then
    Result := DirectionAwayFrom(Direction)
  else
    Result := Direction;

  Result := AvoidBlockedMove(Result);
end;

procedure TMonkey.InitializeMemory;
var
  MemoryIndex: Integer;
  Radius: Integer;
  RelativeX: Integer;
  RelativeY: Integer;
begin
  SetLength(FMemory, FVisionSlots * 6);
  MemoryIndex := 0;
  Radius := 1;

  while MemoryIndex < Length(FMemory) do
  begin
    for RelativeY := -Radius to Radius do
      for RelativeX := -Radius to Radius do
      begin
        if (RelativeX = 0) and (RelativeY = 0) then
          Continue;
        if Max(Abs(RelativeX), Abs(RelativeY)) <> Radius then
          Continue;

        FMemory[MemoryIndex].RelativeX := RelativeX;
        FMemory[MemoryIndex].RelativeY := RelativeY;
        ClearMemorySlot(FMemory[MemoryIndex]);
        Inc(MemoryIndex);
        if MemoryIndex >= Length(FMemory) then
          Exit;
      end;

    Inc(Radius);
  end;
end;

function TMonkey.IsNaturalDeathDue: Boolean;
begin
  Result := FAge >= Round(FLifespan);
end;

procedure TMonkey.Kill;
begin
  FAlive := False;
end;

procedure TMonkey.StartPregnancy(const ATurns: Integer;
  const AUnbornChild: TMonkey);
begin
  if FSex <> msFemale then
    Exit;
  if IsPregnant then
    Exit;
  if AUnbornChild = nil then
    Exit;

  DiscardUnbornChild;
  FUnbornChild := AUnbornChild;
  FPregnantTurnsRemaining := EnsureAtLeast(ATurns, 0);
end;

function TMonkey.WantsToMateWith(const AMate: TMonkey): Boolean;
begin
  Result := FAlive and (AMate <> nil) and AMate.Alive and
    (FSex <> AMate.Sex) and not IsPregnant;
end;

function TMonkey.SexAsNNValue(const ASlot: TMonkeyMemorySlot): Double;
begin
  if ASlot.State <> mcsOccupied then
    Exit(0);

  case ASlot.Sex of
    msMale:
      Result := -1;
    msFemale:
      Result := 1;
  else
    Result := 0;
  end;
end;

function TMonkey.SuperAgoStrategyMove: Integer;
var
  BestDirection: Integer;
  DeltaX: Integer;
  DeltaY: Integer;
  Direction: Integer;
  DirectionStrength: Double;
  FemaleStrength: array[1..8] of Double;
  I: Integer;
  MaleStrength: array[1..8] of Double;
  StrongestDirectionStrength: Double;
  TargetSex: TMonkeySex;
  TieCount: Integer;
begin
  FillChar(FemaleStrength, SizeOf(FemaleStrength), 0);
  FillChar(MaleStrength, SizeOf(MaleStrength), 0);

  for I := Low(FMemory) to High(FMemory) do
    if FMemory[I].State = mcsOccupied then
    begin
      Direction := DirectionFromDelta(FMemory[I].RelativeX,
        FMemory[I].RelativeY);
      if Direction <= 0 then
        Continue;

      if FMemory[I].Sex = msFemale then
        FemaleStrength[Direction] := FemaleStrength[Direction] +
          FMemory[I].Strength
      else
        MaleStrength[Direction] := MaleStrength[Direction] +
          FMemory[I].Strength;
    end;

  BestDirection := 0;
  StrongestDirectionStrength := 0;
  TieCount := 0;
  for Direction := Low(MaleStrength) to High(MaleStrength) do
  begin
    DirectionStrength := Max(MaleStrength[Direction],
      FemaleStrength[Direction]);
    if DirectionStrength <= 0 then
      Continue;

    if (BestDirection = 0) or
      (DirectionStrength > StrongestDirectionStrength) then
    begin
      BestDirection := Direction;
      StrongestDirectionStrength := DirectionStrength;
      TieCount := 1;
    end
    else if SameValue(DirectionStrength, StrongestDirectionStrength) then
    begin
      Inc(TieCount);
      if Random(TieCount) = 0 then
        BestDirection := Direction;
    end;
  end;

  if BestDirection = 0 then
    Exit(AvoidBlockedMove(FLastMoveDirection));

  if FemaleStrength[BestDirection] > MaleStrength[BestDirection] then
  begin
    TargetSex := msFemale;
    DirectionStrength := FemaleStrength[BestDirection];
  end
  else
  begin
    TargetSex := msMale;
    DirectionStrength := MaleStrength[BestDirection];
  end;

  DirectionToDelta(BestDirection, DeltaX, DeltaY);
  Result := MoveForTarget(DeltaX, DeltaY, TargetSex, DirectionStrength);
end;

procedure TMonkey.ShiftMemoryAfterMove(const ADeltaX, ADeltaY: Integer);
var
  I: Integer;
  NewMemory: TMonkeyMemorySlots;
  NewIndex: Integer;
begin
  FLastMoveDirection := DirectionFromDelta(ADeltaX, ADeltaY);
  NewMemory := Copy(FMemory);
  InitializeMemory;

  for I := Low(FMemory) to High(FMemory) do
    ClearMemorySlot(FMemory[I]);

  for I := Low(NewMemory) to High(NewMemory) do
    if NewMemory[I].State <> mcsUnknown then
    begin
      Dec(NewMemory[I].RelativeX, ADeltaX);
      Dec(NewMemory[I].RelativeY, ADeltaY);
      NewIndex := FindMemorySlot(NewMemory[I].RelativeX,
        NewMemory[I].RelativeY);
      if NewIndex >= 0 then
        FMemory[NewIndex] := NewMemory[I];
    end;
end;

procedure TMonkey.StoreVisionSlot(const AVisionSlot: TMonkeyVisionSlot);
var
  MemoryIndex: Integer;
begin
  MemoryIndex := FindMemorySlot(AVisionSlot.RelativeX, AVisionSlot.RelativeY);
  if MemoryIndex < 0 then
    Exit;

  FMemory[MemoryIndex].RelativeX := AVisionSlot.RelativeX;
  FMemory[MemoryIndex].RelativeY := AVisionSlot.RelativeY;
  FMemory[MemoryIndex].State := AVisionSlot.State;
  FMemory[MemoryIndex].Sex := AVisionSlot.Sex;
  FMemory[MemoryIndex].Strength := AVisionSlot.Strength;
  FMemory[MemoryIndex].LastSeenAge := FAge;
end;

procedure TMonkey.UpdateMemoryFromVision(const AVisionSlots: TMonkeyVisionSlots);
var
  I: Integer;
begin
  for I := Low(AVisionSlots) to High(AVisionSlots) do
    StoreVisionSlot(AVisionSlots[I]);
end;

end.
