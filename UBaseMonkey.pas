unit UBaseMonkey;

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

  TBaseMonkey = class
  protected
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
    FAlive: Boolean;

    class function EnsureAtLeast(const AValue, AMinimum: Integer): Integer; static;
    class function EnsurePositive(const AValue, ADefault: Double): Double; static;
    procedure ClearMemorySlot(var ASlot: TMonkeyMemorySlot);
    function FindMemorySlot(const ARelativeX, ARelativeY: Integer): Integer;
    function GetBrainWeights: TNeuralNetWeights;
    function GetMemoryCount: Integer;
    function GetTotalStrength: Double;
    procedure InitializeMemory;
  public
    constructor Create(const AInit: TMonkeyInit);

    function CurrentVisionDecision: TMonkeyVisionDecision;
    function IsNaturalDeathDue: Boolean;
    procedure AdvanceAge;
    procedure ApplyMatingCost(const ATurnCost: Double);
    procedure ClearMemory;
    procedure Kill;

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

{ TBaseMonkey }

constructor TBaseMonkey.Create(const AInit: TMonkeyInit);
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
  FAlive := True;
end;

procedure TBaseMonkey.AdvanceAge;
begin
  if not FAlive then
    Exit;

  Inc(FAge);
  if IsNaturalDeathDue then
    Kill;
end;

procedure TBaseMonkey.ApplyMatingCost(const ATurnCost: Double);
begin
  if not FAlive then
    Exit;

  FLifespan := EnsurePositive(FLifespan - Max(0, ATurnCost), 0.01);
  if IsNaturalDeathDue then
    Kill;
end;

procedure TBaseMonkey.ClearMemory;
var
  I: Integer;
begin
  for I := Low(FMemory) to High(FMemory) do
    ClearMemorySlot(FMemory[I]);
end;

procedure TBaseMonkey.ClearMemorySlot(var ASlot: TMonkeyMemorySlot);
begin
  ASlot.State := mcsUnknown;
  ASlot.Sex := msMale;
  ASlot.Strength := 0;
  ASlot.LastSeenAge := -1;
end;

function TBaseMonkey.CurrentVisionDecision: TMonkeyVisionDecision;
begin
  Result := FCurrentVision;
end;

class function TBaseMonkey.EnsureAtLeast(const AValue,
  AMinimum: Integer): Integer;
begin
  Result := AValue;
  if Result < AMinimum then
    Result := AMinimum;
end;

class function TBaseMonkey.EnsurePositive(const AValue,
  ADefault: Double): Double;
begin
  Result := AValue;
  if Result <= 0 then
    Result := ADefault;
end;

function TBaseMonkey.FindMemorySlot(const ARelativeX,
  ARelativeY: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;

  for I := Low(FMemory) to High(FMemory) do
    if (FMemory[I].RelativeX = ARelativeX) and
      (FMemory[I].RelativeY = ARelativeY) then
      Exit(I);
end;

function TBaseMonkey.GetBrainWeights: TNeuralNetWeights;
begin
  Result := Copy(FBrainWeights);
end;

function TBaseMonkey.GetMemoryCount: Integer;
begin
  Result := Length(FMemory);
end;

function TBaseMonkey.GetTotalStrength: Double;
var
  HalfLifespan: Double;
begin
  HalfLifespan := FLifespan / 2;
  if FAge < HalfLifespan then
    Result := FStrength + FAge
  else
    Result := FStrength - FAge + HalfLifespan;
end;

procedure TBaseMonkey.InitializeMemory;
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

function TBaseMonkey.IsNaturalDeathDue: Boolean;
begin
  Result := FAge >= Round(FLifespan);
end;

procedure TBaseMonkey.Kill;
begin
  FAlive := False;
end;

end.
