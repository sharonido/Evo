unit UWorld;

interface

uses
  UBaseMonkey, UBaseWorld, UMonkey, UNeuralNet;

type
  TWorld = class(TBaseWorld)
  private
    procedure AddVisionSlot(var AVisionSlots: TMonkeyVisionSlots;
      const ASourceX, ASourceY, ARelativeX, ARelativeY: Integer);
    function AreCloseRelatives(const AFirst, ASecond: TMonkey): Boolean;
    function BuildVisionForMonkey(const AMonkey: TMonkey;
      const AVisionDecision: TMonkeyVisionDecision): TMonkeyVisionSlots;
    function CombatWinProbability(const AAttacker, ADefender: TMonkey): Double;
    function CreateOffspring(const AMother, AFather: TMonkey): TMonkey;
    procedure CreateInitialPopulation(const AMotherWeights,
      AFatherWeights: TNeuralNetWeights);
    procedure EndGenerationWithMonkey(const AMonkey: TMonkey);
    procedure EndGenerationWithoutSurvivor;
    function LoadSeedWeightsFromJsonFile(const AFileName: string;
      const AVisionSlots: Integer): TNeuralNetWeights;
    function MonkeyPriority(const AMonkey: TMonkey): Double;
    function MutateBySigmaPercent(const ABaseValue, ASigmaPercent: Double): Double;
    function MutateWeights(const ABaseWeights: TNeuralNetWeights): TNeuralNetWeights;
    function SeedWeightsForInitialMonkey(const AConfig: TNeuralNetConfig;
      const AMotherWeights, AFatherWeights: TNeuralNetWeights): TNeuralNetWeights;
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
    procedure Restart(const AConfig: TWorldConfig);
    procedure RestartFromWeightsFile(const AConfig: TWorldConfig;
      const AFileName: string);
    procedure RestartFromParentWeightsFiles(const AConfig: TWorldConfig;
      const AMotherFileName, AFatherFileName: string);
    procedure RunWorldTurn;
    procedure SaveLastSurvivorWeightsJsonToFile(const AFileName: string);
    procedure SaveMaxGenerationWeightsJsonToFile(const AFileName: string);
  end;

implementation

uses
  System.Generics.Collections, System.Generics.Defaults, System.IOUtils,
  System.Math, System.SysUtils, System.Types;

{ TWorld }

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

procedure TWorld.CreateInitialPopulation(const AMotherWeights,
  AFatherWeights: TNeuralNetWeights);
var
  I: Integer;
  X: Integer;
  Y: Integer;
  Init: TMonkeyInit;
  NetConfig: TNeuralNetConfig;
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
    NetConfig := BuildNeuralNetConfig(Init.VisionSlots);
    Init.BrainWeights := SeedWeightsForInitialMonkey(NetConfig,
      AMotherWeights, AFatherWeights);

    Monkey := TMonkey.Create(Init);
    TrackMaxGeneration(Monkey);
    FMonkeys.Add(Monkey);
    FBoard[BoardIndex(X, Y)] := Monkey;
  end;
end;

procedure TWorld.EndGenerationWithMonkey(const AMonkey: TMonkey);
var
  Json: string;
begin
  if FGenerationEnded or (AMonkey = nil) or (not AMonkey.Alive) then
    Exit;
  if TryGetMonkeyWeightsJson(AMonkey.Id, Json) then
  begin
    TrackMaxGeneration(AMonkey);
    FLastSurvivorWeightsJson := Json;
    FGenerationEnded := True;
  end;
end;

procedure TWorld.EndGenerationWithoutSurvivor;
begin
  if FGenerationEnded then
    Exit;
  if FMaxGenWeightsJson = '' then
    Exit;

  FLastSurvivorWeightsJson := FMaxGenWeightsJson;
  FGenerationEnded := True;
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

function TWorld.SeedWeightsForInitialMonkey(const AConfig: TNeuralNetConfig;
  const AMotherWeights, AFatherWeights: TNeuralNetWeights): TNeuralNetWeights;
var
  RequiredCount: Integer;
begin
  RequiredCount := TNeuralNet.WeightCount(AConfig);

  if (Length(AMotherWeights) = RequiredCount) and
    (Length(AFatherWeights) = RequiredCount) then
    Result := TNeuralNet.CreateChildWeights(AConfig, AMotherWeights,
      AFatherWeights, Max(0, FConfig.MutationSigmaPercent) / 100)
  else if Length(AMotherWeights) = RequiredCount then
    Result := MutateWeights(AMotherWeights)
  else
    Result := TNeuralNet.CreateRandomWeights(AConfig);
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
  FMaxGenWeightsJson := '';
  FGenerationEnded := False;
  FLastSurvivorWeightsJson := '';
  FMonkeys.Clear;
  ClearBoard;
  CreateInitialPopulation(nil, nil);
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
  FMaxGenWeightsJson := '';
  FGenerationEnded := False;
  FLastSurvivorWeightsJson := '';
  FMonkeys.Clear;
  ClearBoard;
  CreateInitialPopulation(SeedWeights, nil);
end;

procedure TWorld.RestartFromParentWeightsFiles(const AConfig: TWorldConfig;
  const AMotherFileName, AFatherFileName: string);
var
  FatherWeights: TNeuralNetWeights;
  MotherWeights: TNeuralNetWeights;
begin
  FConfig := AConfig;

  FConfig.SizeX := EnsureAtLeast(FConfig.SizeX, 1);
  FConfig.SizeY := EnsureAtLeast(FConfig.SizeY, 1);
  FConfig.VisionSlots := EnsureAtLeast(FConfig.VisionSlots, 1);
  FConfig.PopulationCount := EnsureAtLeast(FConfig.PopulationCount, 0);

  MotherWeights := LoadSeedWeightsFromJsonFile(AMotherFileName,
    FConfig.VisionSlots);
  FatherWeights := LoadSeedWeightsFromJsonFile(AFatherFileName,
    FConfig.VisionSlots);

  FNextMonkeyId := 0;
  FWorldStepCount := 0;
  FDeadMonkeyCount := 0;
  FCombatDeathCount := 0;
  FBornMonkeyCount := 0;
  FMaxGenCount := -1;
  FMaxGenMonkeyId := 0;
  FMaxGenWeightsJson := '';
  FGenerationEnded := False;
  FLastSurvivorWeightsJson := '';
  FMonkeys.Clear;
  ClearBoard;
  CreateInitialPopulation(MotherWeights, FatherWeights);
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
  if FMonkeys.Count <= 1 then
  begin
    if FMonkeys.Count = 1 then
      EndGenerationWithMonkey(FMonkeys[0])
    else
      EndGenerationWithoutSurvivor;
  end;
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

procedure TWorld.SaveLastSurvivorWeightsJsonToFile(const AFileName: string);
begin
  if FLastSurvivorWeightsJson = '' then
    raise Exception.Create('No last survivor neural net JSON is available.');

  TFile.WriteAllText(AFileName, FLastSurvivorWeightsJson, TEncoding.UTF8);
end;

procedure TWorld.SaveMaxGenerationWeightsJsonToFile(const AFileName: string);
begin
  if FMaxGenWeightsJson = '' then
    raise Exception.Create('No max generation neural net JSON is available.');

  TFile.WriteAllText(AFileName, FMaxGenWeightsJson, TEncoding.UTF8);
end;

procedure TWorld.TrackMaxGeneration(const AMonkey: TMonkey);
var
  Config: TNeuralNetConfig;
  Weights: TNeuralNetWeights;
begin
  if (AMonkey <> nil) and ((FMaxGenCount < 0) or
    (AMonkey.GenCount > FMaxGenCount)) then
  begin
    FMaxGenCount := AMonkey.GenCount;
    FMaxGenMonkeyId := AMonkey.Id;
    Config := BuildNeuralNetConfig(AMonkey.VisionSlots);
    Weights := AMonkey.BrainWeights;
    if Length(Weights) = TNeuralNet.WeightCount(Config) then
      FMaxGenWeightsJson := TNeuralNet.WeightsToJson(Config, Weights)
    else
      FMaxGenWeightsJson := '';
  end;
end;

end.
