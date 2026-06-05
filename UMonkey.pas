unit UMonkey;

interface

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
    FMemory: TMonkeyMemorySlots;
    FCurrentVision: TMonkeyVisionDecision;
    FPregnantTurnsRemaining: Integer;
    FAlive: Boolean;

    class function EnsureAtLeast(const AValue, AMinimum: Integer): Integer; static;
    class function EnsurePositive(const AValue, ADefault: Double): Double; static;
    function CellStateAsNNValue(const ASlot: TMonkeyMemorySlot): Double;
    function FindMemorySlot(const ARelativeX, ARelativeY: Integer): Integer;
    function FindUnknownMemorySlot: Integer;
    function GetIsPregnant: Boolean;
    function GetMemoryCount: Integer;
    function SexAsNNValue(const ASlot: TMonkeyMemorySlot): Double;
    procedure ClearMemorySlot(var ASlot: TMonkeyMemorySlot);
    procedure InitializeMemory;
    procedure StoreVisionSlot(const AVisionSlot: TMonkeyVisionSlot);
  public
    constructor Create(const AInit: TMonkeyInit);

    function BuildNNInput: TMonkeyNNInputs;
    function CurrentVisionDecision: TMonkeyVisionDecision;
    function DecideNextAction(const AVisionSlots: TMonkeyVisionSlots): TMonkeyActionDecision;
    function IsNaturalDeathDue: Boolean;
    procedure AdvanceAge;
    procedure ClearMemory;
    procedure Kill;
    procedure StartPregnancy(const ATurns: Integer);
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
    property Lifespan: Double read FLifespan write FLifespan;
    property Age: Integer read FAge;
    property VisionSlots: Integer read FVisionSlots;
    property CurrentVision: TMonkeyVisionDecision read FCurrentVision;
    property MemoryCount: Integer read GetMemoryCount;
    property PregnantTurnsRemaining: Integer read FPregnantTurnsRemaining;
    property IsPregnant: Boolean read GetIsPregnant;
    property Alive: Boolean read FAlive;
  end;

implementation

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
  FCurrentVision := TMonkeyVisionDecision.Default;
  InitializeMemory;
  FAge := 0;
  FPregnantTurnsRemaining := 0;
  FAlive := True;
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

function TMonkey.BuildNNInput: TMonkeyNNInputs;
var
  I: Integer;
  InputIndex: Integer;
begin
  SetLength(Result, Length(FMemory) * 2);
  InputIndex := 0;

  for I := Low(FMemory) to High(FMemory) do
  begin
    Result[InputIndex] := SexAsNNValue(FMemory[I]);
    Inc(InputIndex);
    Result[InputIndex] := CellStateAsNNValue(FMemory[I]);
    Inc(InputIndex);
  end;
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
  ASlot.RelativeX := 0;
  ASlot.RelativeY := 0;
  ASlot.State := mcsUnknown;
  ASlot.Sex := msMale;
  ASlot.Strength := 0;
  ASlot.LastSeenAge := -1;
end;

function TMonkey.CurrentVisionDecision: TMonkeyVisionDecision;
begin
  Result := FCurrentVision;
end;

function TMonkey.DecideNextAction(
  const AVisionSlots: TMonkeyVisionSlots): TMonkeyActionDecision;
begin
  UpdateMemoryFromVision(AVisionSlots);
  BuildNNInput;

  Result := TMonkeyActionDecision.Stay(FCurrentVision);
  Result.MoveDirection := 1;
  FCurrentVision := Result.NextVision;
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

function TMonkey.FindMemorySlot(const ARelativeX, ARelativeY: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;

  for I := Low(FMemory) to High(FMemory) do
    if (FMemory[I].State <> mcsUnknown) and
      (FMemory[I].RelativeX = ARelativeX) and
      (FMemory[I].RelativeY = ARelativeY) then
      Exit(I);
end;

function TMonkey.FindUnknownMemorySlot: Integer;
var
  I: Integer;
begin
  Result := -1;

  for I := Low(FMemory) to High(FMemory) do
    if FMemory[I].State = mcsUnknown then
      Exit(I);
end;

function TMonkey.GetIsPregnant: Boolean;
begin
  Result := FPregnantTurnsRemaining > 0;
end;

function TMonkey.GetMemoryCount: Integer;
begin
  Result := Length(FMemory);
end;

procedure TMonkey.InitializeMemory;
begin
  SetLength(FMemory, FVisionSlots * 6);
  ClearMemory;
end;

function TMonkey.IsNaturalDeathDue: Boolean;
begin
  Result := FAge >= Round(FLifespan);
end;

procedure TMonkey.Kill;
begin
  FAlive := False;
end;

procedure TMonkey.StartPregnancy(const ATurns: Integer);
begin
  if FSex <> msFemale then
    Exit;

  FPregnantTurnsRemaining := EnsureAtLeast(ATurns, 0);
end;

function TMonkey.SexAsNNValue(const ASlot: TMonkeyMemorySlot): Double;
begin
  if ASlot.State <> mcsOccupied then
    Exit(0);

  case ASlot.Sex of
    msMale:
      Result := 0;
    msFemale:
      Result := 1;
  else
    Result := 0;
  end;
end;

procedure TMonkey.ShiftMemoryAfterMove(const ADeltaX, ADeltaY: Integer);
var
  I: Integer;
begin
  for I := Low(FMemory) to High(FMemory) do
    if FMemory[I].State <> mcsUnknown then
    begin
      Dec(FMemory[I].RelativeX, ADeltaX);
      Dec(FMemory[I].RelativeY, ADeltaY);
    end;
end;

procedure TMonkey.StoreVisionSlot(const AVisionSlot: TMonkeyVisionSlot);
var
  MemoryIndex: Integer;
begin
  MemoryIndex := FindMemorySlot(AVisionSlot.RelativeX, AVisionSlot.RelativeY);
  if MemoryIndex < 0 then
    MemoryIndex := FindUnknownMemorySlot;
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
