unit UBaseWorld;

interface

uses
  System.Generics.Collections, UBaseMonkey, UMonkey, UNeuralNet;

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

  TBaseWorld = class
  protected
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
    FMaxGenWeightsJson: string;
    FGenerationEnded: Boolean;
    FLastSurvivorWeightsJson: string;
    class function EnsureAtLeast(const AValue, AMinimum: Integer): Integer; static;
    function BoardIndex(const AX, AY: Integer): Integer;
    function BuildNeuralNetConfig(const AVisionSlots: Integer): TNeuralNetConfig;
    procedure ClearBoard;
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
  System.IOUtils, System.Math, System.SysUtils;

{ TBaseWorld }

constructor TBaseWorld.Create;
begin
  inherited Create;
  FMonkeys := TObjectList<TMonkey>.Create(True);
  Randomize;
end;

destructor TBaseWorld.Destroy;
begin
  FMonkeys.Free;
  inherited Destroy;
end;

procedure TBaseWorld.AddMonkey(const AMonkey: TMonkey);
begin
  FMonkeys.Add(AMonkey);
end;

function TBaseWorld.BoardIndex(const AX, AY: Integer): Integer;
begin
  Result := (AY * FConfig.SizeX) + AX;
end;

function TBaseWorld.BuildNeuralNetConfig(
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

procedure TBaseWorld.ClearBoard;
begin
  SetLength(FBoard, 0);
  SetLength(FBoard, FConfig.SizeX * FConfig.SizeY);
end;

class function TBaseWorld.EnsureAtLeast(const AValue,
  AMinimum: Integer): Integer;
begin
  Result := AValue;
  if Result < AMinimum then
    Result := AMinimum;
end;

function TBaseWorld.FindEmptyCellNear(const ACenterX, ACenterY: Integer; out AX,
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

function TBaseWorld.FindRandomEmptyCell(out AX, AY: Integer): Boolean;
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

function TBaseWorld.FindMonkeyById(const AMonkeyId: TMonkeyId): TMonkey;
var
  Monkey: TMonkey;
begin
  Result := nil;
  for Monkey in FMonkeys do
    if Monkey.Id = AMonkeyId then
      Exit(Monkey);
end;

function TBaseWorld.FindMonkeyPosition(const AMonkey: TMonkey; out AX,
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

procedure TBaseWorld.FindLivingMaxGeneration(out AGenCount: Integer;
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

function TBaseWorld.GetLivingMaxGenCount: Integer;
var
  MonkeyId: TMonkeyId;
begin
  FindLivingMaxGeneration(Result, MonkeyId);
end;

function TBaseWorld.GetLivingMaxGenMonkeyId: TMonkeyId;
var
  GenCount: Integer;
begin
  FindLivingMaxGeneration(GenCount, Result);
end;

function TBaseWorld.GetMonkeyCount: Integer;
begin
  Result := FMonkeys.Count;
end;

function TBaseWorld.GetMonkeySnapshots: TWorldMonkeySnapshots;
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

function TBaseWorld.TryGetMonkeyTraitsAt(const AX, AY: Integer;
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

function TBaseWorld.TryGetMonkeyBrainAt(const AX, AY: Integer;
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

function TBaseWorld.GetSizeX: Integer;
begin
  Result := FConfig.SizeX;
end;

function TBaseWorld.GetSizeY: Integer;
begin
  Result := FConfig.SizeY;
end;

function TBaseWorld.IsInsideBoard(const AX, AY: Integer): Boolean;
begin
  Result := (AX >= 0) and (AY >= 0) and
    (AX < FConfig.SizeX) and (AY < FConfig.SizeY);
end;

procedure TBaseWorld.SaveMonkeyWeightsJsonToFile(const AMonkeyId: TMonkeyId;
  const AFileName: string);
var
  Json: string;
begin
  if not TryGetMonkeyWeightsJson(AMonkeyId, Json) then
    raise EArgumentException.CreateFmt('Monkey Id %d was not found.',
      [AMonkeyId]);

  TFile.WriteAllText(AFileName, Json, TEncoding.UTF8);
end;

function TBaseWorld.TryGetMonkeyWeightsJson(const AMonkeyId: TMonkeyId;
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
