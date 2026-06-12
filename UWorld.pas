unit UWorld;

interface

uses
  System.Generics.Collections, UMonkey, UNeuralNet;

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
    FWorldStepCount: Int64;
    FDeadMonkeyCount: Int64;
    FCombatDeathCount: Int64;
    FBornMonkeyCount: Int64;
    FMaxGenCount: Integer;
    FMaxGenMonkeyId: TMonkeyId;
    FGenerationEnded: Boolean;
    FLastSurvivorWeightsJson: string;
    class function EnsureAtLeast(const AValue, AMinimum: Integer): Integer; static;
    procedure AddVisionSlot(var AVisionSlots: TMonkeyVisionSlots;
      const ASourceX, ASourceY, ARelativeX, ARelativeY: Integer);
    function AreCloseRelatives(const AFirst, ASecond: TMonkey): Boolean;
    function BoardIndex(const AX, AY: Integer): Integer;
    function BuildNeuralNetConfig(const AVisionSlots: Integer): TNeuralNetConfig;
    function BuildVisionForMonkey(const AMonkey: TMonkey;
      const AVisionDecision: TMonkeyVisionDecision): TMonkeyVisionSlots;
    function CombatWinProbability(const AAttacker, ADefender: TMonkey): Double;
    function CreateOffspring(const AMother, AFather: TMonkey): TMonkey;
    procedure ClearBoard;
    procedure CreateInitialPopulation(const ASeedWeights: TNeuralNetWeights);
    function FindEmptyCellNear(const ACenterX, ACenterY: Integer; out AX,
      AY: Integer): Boolean;
    function FindRandomEmptyCell(out AX, AY: Integer): Boolean;
    function FindMonkeyById(const AMonkeyId: TMonkeyId): TMonkey;
    function FindMonkeyPosition(const AMonkey: TMonkey; out AX, AY: Integer): Boolean;
    procedure FindLivingMaxGeneration(out AGenCount: Integer;
      out AMonkeyId: TMonkeyId);
    function GetLivingMaxGenCount: Integer;
    function GetLivingMaxGenMonkeyId: TMonkeyId;
    function GetMonkeyCount: Integer;
    function GetSizeX: Integer;
    function GetSizeY: Integer;
    function IsInsideBoard(const AX, AY: Integer): Boolean;
    function LoadSeedWeightsFromJsonFile(const AFileName: string;
      const AVisionSlots: Integer): TNeuralNetWeights;
    function MonkeyPriority(const AMonkey: TMonkey): Double;
    function MutateBySigmaPercent(const ABaseValue, ASigmaPercent: Double): Double;
    function MutateWeights(const ABaseWeights: TNeuralNetWeights): TNeuralNetWeights;
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
    procedure TrackMaxGeneration(const AMonkey: TMonkey);
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddMonkey(const AMonkey: TMonkey);
    function GetMonkeySnapshots: TWorldMonkeySnapshots;
    function TryGetMonkeyTraitsAt(const AX, AY: Integer;
      out ATraits: TMonkeyTraitSnapshot): Boolean;
    function TryGetMonkeyBrainAt(const AX, AY: Integer;
      out AConfig: TNeuralNetConfig; out AWeights: TNeuralNetWeights;
      out AInputs: TMonkeyNNInputs; out AOutputs: TNeuralNetOutputs): Boolean;
    function TryGetMonkeyWeightsJson(const AMonkeyId: TMonkeyId;
      out AJson: string): Boolean;
    procedure Restart(const AConfig: TWorldConfig);
    procedure RestartFromWeightsFile(const AConfig: TWorldConfig;
      const AFileName: string);
    procedure RunWorldTurn;
    procedure SaveLastSurvivorWeightsJsonToFile(const AFileName: string);
    procedure SaveMonkeyWeightsJsonToFile(const AMonkeyId: TMonkeyId;
      const AFileName: string);

    property Config: TWorldConfig read FConfig;
    property MonkeyCount: Integer read GetMonkeyCount;
    property WorldStepCount: Int64 read FWorldStepCount;
    property DeadMonkeyCount: Int64 read FDeadMonkeyCount;
    property CombatDeathCount: Int64 read FCombatDeathCount;
    property BornMonkeyCount: Int64 read FBornMonkeyCount;
    property LivingMaxGenCount: Integer read GetLivingMaxGenCount;
    property LivingMaxGenMonkeyId: TMonkeyId read GetLivingMaxGenMonkeyId;
    property MaxGenCount: Integer read FMaxGenCount;
    property MaxGenMonkeyId: TMonkeyId read FMaxGenMonkeyId;
    property GenerationEnded: Boolean read FGenerationEnded;
    property LastSurvivorWeightsJson: string read FLastSurvivorWeightsJson;
    property SizeX: Integer read GetSizeX;
    property SizeY: Integer read GetSizeY;
  end;

implementation

uses
  System.Generics.Defaults, System.IOUtils, System.Math, System.SysUtils,
  System.Types;

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
  AVisionSlots[SlotIndex].Strength := Monkey.TotalStrength;
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

function TWorld.BuildNeuralNetConfig(
  const AVisionSlots: Integer): TNeuralNetConfig;
var
  LayerNodeCount: Integer;
begin
  LayerNodeCount := (EnsureAtLeast(AVisionSlots, 1) * 12) + 5;

  Result.InputCount := LayerNodeCount;
  Result.Hidden1Count := LayerNodeCount;
  Result.Hidden2Count := LayerNodeCount;
  Result.Hidden3Count := LayerNodeCount;
  Result.OutputCount := 13;
end;

function TWorld.BuildVisionForMonkey(const AMonkey: TMonkey;
  const AVisionDecision: TMonkeyVisionDecision): TMonkeyVisionSlots;
var
  Candidates: TList<TPoint>;
  Candidate: TPoint;
  DirectionX: Integer;
  DirectionY: Integer;
  MonkeyX: Integer;
  MonkeyY: Integer;
  Radius: Integer;
  SearchRadius: Integer;

  procedure AddCandidate(const ARelativeX, ARelativeY: Integer);
  begin
    if (ARelativeX = 0) and (ARelativeY = 0) then
      Exit;
    Candidates.Add(TPoint.Create(ARelativeX, ARelativeY));
  end;

  procedure BuildNearCandidates;
  var
    LocalRelativeX: Integer;
    LocalRelativeY: Integer;
  begin
    Radius := 1;
    while Candidates.Count < AMonkey.VisionSlots do
    begin
      for LocalRelativeY := -Radius to Radius do
        for LocalRelativeX := -Radius to Radius do
        begin
          if Max(Abs(LocalRelativeX), Abs(LocalRelativeY)) <> Radius then
            Continue;
          AddCandidate(LocalRelativeX, LocalRelativeY);
        end;
      Inc(Radius);
    end;

    Candidates.Sort(TComparer<TPoint>.Construct(
      function(const Left, Right: TPoint): Integer
      begin
        Result := CompareValue(Max(Abs(Left.X), Abs(Left.Y)),
          Max(Abs(Right.X), Abs(Right.Y)));
        if Result <> 0 then
          Exit;

        Result := CompareValue(-(Left.X * DirectionX + Left.Y * DirectionY),
          -(Right.X * DirectionX + Right.Y * DirectionY));
        if Result <> 0 then
          Exit;

        Result := CompareValue(Abs(Left.X * DirectionY - Left.Y * DirectionX),
          Abs(Right.X * DirectionY - Right.Y * DirectionX));
      end));
  end;

  procedure BuildFarCandidates;
  var
    LocalRelativeX: Integer;
    LocalRelativeY: Integer;
  begin
    SearchRadius := Max(3, AMonkey.VisionSlots * 2);
    for LocalRelativeY := -SearchRadius to SearchRadius do
      for LocalRelativeX := -SearchRadius to SearchRadius do
        if (LocalRelativeX * DirectionX + LocalRelativeY * DirectionY) > 0 then
          AddCandidate(LocalRelativeX, LocalRelativeY);

    Candidates.Sort(TComparer<TPoint>.Construct(
      function(const Left, Right: TPoint): Integer
      begin
        Result := CompareValue(-(Left.X * DirectionX + Left.Y * DirectionY),
          -(Right.X * DirectionX + Right.Y * DirectionY));
        if Result <> 0 then
          Exit;

        Result := CompareValue(Abs(Left.X * DirectionY - Left.Y * DirectionX),
          Abs(Right.X * DirectionY - Right.Y * DirectionX));
        if Result <> 0 then
          Exit;

        Result := CompareValue(Max(Abs(Left.X), Abs(Left.Y)),
          Max(Abs(Right.X), Abs(Right.Y)));
      end));
  end;
begin
  SetLength(Result, 0);

  if not FindMonkeyPosition(AMonkey, MonkeyX, MonkeyY) then
    Exit;

  DirectionToDelta(AVisionDecision.Direction, DirectionX, DirectionY);
  if (DirectionX = 0) and (DirectionY = 0) then
    DirectionY := -1;

  Candidates := TList<TPoint>.Create;
  try
    if AVisionDecision.IsFar then
      BuildFarCandidates
    else
      BuildNearCandidates;

    for Candidate in Candidates do
    begin
      AddVisionSlot(Result, MonkeyX, MonkeyY, Candidate.X, Candidate.Y);
      if Length(Result) >= AMonkey.VisionSlots then
        Exit;
    end;
  finally
    Candidates.Free;
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
  Init.BrainWeights := TNeuralNet.CreateChildWeights(
    BuildNeuralNetConfig(Init.VisionSlots), AMother.BrainWeights,
    AFather.BrainWeights, Max(0, FConfig.MutationSigmaPercent) / 100);

  Result := TMonkey.Create(Init);
  TrackMaxGeneration(Result);
end;

procedure TWorld.ClearBoard;
begin
  SetLength(FBoard, 0);
  SetLength(FBoard, FConfig.SizeX * FConfig.SizeY);
end;

procedure TWorld.CreateInitialPopulation(const ASeedWeights: TNeuralNetWeights);
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
    if Length(ASeedWeights) = TNeuralNet.WeightCount(
      BuildNeuralNetConfig(Init.VisionSlots)) then
      Init.BrainWeights := MutateWeights(ASeedWeights)
    else
      Init.BrainWeights := TNeuralNet.CreateRandomWeights(
        BuildNeuralNetConfig(Init.VisionSlots));

    Monkey := TMonkey.Create(Init);
    TrackMaxGeneration(Monkey);
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

function TWorld.FindMonkeyById(const AMonkeyId: TMonkeyId): TMonkey;
var
  Monkey: TMonkey;
begin
  Result := nil;
  for Monkey in FMonkeys do
    if Monkey.Id = AMonkeyId then
      Exit(Monkey);
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

procedure TWorld.FindLivingMaxGeneration(out AGenCount: Integer;
  out AMonkeyId: TMonkeyId);
var
  Monkey: TMonkey;
begin
  AGenCount := -1;
  AMonkeyId := 0;

  for Monkey in FMonkeys do
    if Monkey.Alive and ((AGenCount < 0) or
      (Monkey.GenCount > AGenCount)) then
    begin
      AGenCount := Monkey.GenCount;
      AMonkeyId := Monkey.Id;
    end;
end;

function TWorld.GetLivingMaxGenCount: Integer;
var
  MonkeyId: TMonkeyId;
begin
  FindLivingMaxGeneration(Result, MonkeyId);
end;

function TWorld.GetLivingMaxGenMonkeyId: TMonkeyId;
var
  GenCount: Integer;
begin
  FindLivingMaxGeneration(GenCount, Result);
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

function TWorld.TryGetMonkeyBrainAt(const AX, AY: Integer;
  out AConfig: TNeuralNetConfig; out AWeights: TNeuralNetWeights;
  out AInputs: TMonkeyNNInputs; out AOutputs: TNeuralNetOutputs): Boolean;
var
  I: Integer;
  NeuralNetInputs: TNeuralNetOutputs;
  Monkey: TMonkey;
begin
  Result := False;
  AConfig.InputCount := 0;
  AConfig.Hidden1Count := 0;
  AConfig.Hidden2Count := 0;
  AConfig.Hidden3Count := 0;
  AConfig.OutputCount := 0;
  SetLength(AWeights, 0);
  SetLength(AInputs, 0);
  SetLength(AOutputs, 0);

  if not IsInsideBoard(AX, AY) then
    Exit;

  Monkey := FBoard[BoardIndex(AX, AY)];
  if Monkey = nil then
    Exit;

  AConfig := BuildNeuralNetConfig(Monkey.VisionSlots);
  AWeights := Monkey.BrainWeights;
  AInputs := Monkey.BuildNNInput;
  Result := (Length(AWeights) = TNeuralNet.WeightCount(AConfig)) and
    (Length(AInputs) = AConfig.InputCount);
  if Result then
  begin
    SetLength(NeuralNetInputs, Length(AInputs));
    for I := Low(AInputs) to High(AInputs) do
      NeuralNetInputs[I] := AInputs[I];
    AOutputs := TNeuralNet.Evaluate(AConfig, AWeights, NeuralNetInputs);
  end;
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

function TWorld.LoadSeedWeightsFromJsonFile(const AFileName: string;
  const AVisionSlots: Integer): TNeuralNetWeights;
var
  Config: TNeuralNetConfig;
  Json: string;
begin
  Config := BuildNeuralNetConfig(AVisionSlots);
  Json := TFile.ReadAllText(AFileName, TEncoding.UTF8);
  Result := TNeuralNet.WeightsFromJson(Config, Json);
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

function TWorld.MutateWeights(
  const ABaseWeights: TNeuralNetWeights): TNeuralNetWeights;
var
  I: Integer;
  Sigma: Double;
begin
  SetLength(Result, Length(ABaseWeights));
  Sigma := Max(0, FConfig.MutationSigmaPercent) / 100;
  for I := Low(ABaseWeights) to High(ABaseWeights) do
    Result[I] := ABaseWeights[I] + (RandomGaussian * Sigma);
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
  Json: string;
begin
  for I := FMonkeys.Count - 1 downto 0 do
    if not FMonkeys[I].Alive then
    begin
      if (FMonkeys.Count = 1) and TryGetMonkeyWeightsJson(FMonkeys[I].Id,
        Json) then
      begin
        FLastSurvivorWeightsJson := Json;
        FGenerationEnded := True;
      end;

      if FindMonkeyPosition(FMonkeys[I], X, Y) then
        FBoard[BoardIndex(X, Y)] := nil;
      Inc(FDeadMonkeyCount);
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
        Inc(FBornMonkeyCount);
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
    Inc(FCombatDeathCount);
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
    Inc(FCombatDeathCount);
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
  FWorldStepCount := 0;
  FDeadMonkeyCount := 0;
  FCombatDeathCount := 0;
  FBornMonkeyCount := 0;
  FMaxGenCount := -1;
  FMaxGenMonkeyId := 0;
  FGenerationEnded := False;
  FLastSurvivorWeightsJson := '';
  FMonkeys.Clear;
  ClearBoard;
  CreateInitialPopulation(nil);
end;

procedure TWorld.RestartFromWeightsFile(const AConfig: TWorldConfig;
  const AFileName: string);
var
  SeedWeights: TNeuralNetWeights;
begin
  FConfig := AConfig;

  FConfig.SizeX := EnsureAtLeast(FConfig.SizeX, 1);
  FConfig.SizeY := EnsureAtLeast(FConfig.SizeY, 1);
  FConfig.VisionSlots := EnsureAtLeast(FConfig.VisionSlots, 1);
  FConfig.PopulationCount := EnsureAtLeast(FConfig.PopulationCount, 0);

  SeedWeights := LoadSeedWeightsFromJsonFile(AFileName, FConfig.VisionSlots);

  FNextMonkeyId := 0;
  FWorldStepCount := 0;
  FDeadMonkeyCount := 0;
  FCombatDeathCount := 0;
  FBornMonkeyCount := 0;
  FMaxGenCount := -1;
  FMaxGenMonkeyId := 0;
  FGenerationEnded := False;
  FLastSurvivorWeightsJson := '';
  FMonkeys.Clear;
  ClearBoard;
  CreateInitialPopulation(SeedWeights);
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
  Inc(FWorldStepCount);
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

procedure TWorld.SaveMonkeyWeightsJsonToFile(const AMonkeyId: TMonkeyId;
  const AFileName: string);
var
  Json: string;
begin
  if not TryGetMonkeyWeightsJson(AMonkeyId, Json) then
    raise EArgumentException.CreateFmt('Monkey Id %d was not found.',
      [AMonkeyId]);

  TFile.WriteAllText(AFileName, Json, TEncoding.UTF8);
end;

procedure TWorld.SaveLastSurvivorWeightsJsonToFile(const AFileName: string);
begin
  if FLastSurvivorWeightsJson = '' then
    raise Exception.Create('No last survivor neural net JSON is available.');

  TFile.WriteAllText(AFileName, FLastSurvivorWeightsJson, TEncoding.UTF8);
end;

procedure TWorld.TrackMaxGeneration(const AMonkey: TMonkey);
begin
  if (AMonkey <> nil) and ((FMaxGenCount < 0) or
    (AMonkey.GenCount > FMaxGenCount)) then
  begin
    FMaxGenCount := AMonkey.GenCount;
    FMaxGenMonkeyId := AMonkey.Id;
  end;
end;

function TWorld.TryGetMonkeyWeightsJson(const AMonkeyId: TMonkeyId;
  out AJson: string): Boolean;
var
  Config: TNeuralNetConfig;
  Monkey: TMonkey;
  Weights: TNeuralNetWeights;
begin
  AJson := '';
  Monkey := FindMonkeyById(AMonkeyId);
  Result := Monkey <> nil;
  if not Result then
    Exit;

  Config := BuildNeuralNetConfig(Monkey.VisionSlots);
  Weights := Monkey.BrainWeights;
  AJson := TNeuralNet.WeightsToJson(Config, Weights);
end;

end.
