unit UMonkeysForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.TabControl,
  FMX.StdCtrls, FMX.Gestures, FMX.Controls.Presentation, FMX.Layouts, FMX.Edit,
  FMX.EditBox, FMX.NumberBox, FMX.Objects, UMonkey, UWorld;

type
  TTabbedForm = class(TForm)
    TabControl: TTabControl;
    WorldTab: TTabItem;
    ConTab: TTabItem;
    NNTab: TTabItem;
    ControlBox: TGroupBox;
    ScrollBox1: TScrollBox;
    BStart: TButton;
    BPause: TButton;
    BReset: TButton;
    BStep: TButton;
    LTurnSpeed: TLabel;
    TurnSpeedTrack: TTrackBar;
    ConfigGroup: TGroupBox;
    StatGroupBox: TGroupBox;
    NSizeX: TNumberBox;
    LWorldSizeX: TLabel;
    NSizeY: TNumberBox;
    LWorldSizeY: TLabel;
    NLifespan: TNumberBox;
    LBaseLifespan: TLabel;
    NVisionSlots: TNumberBox;
    LVisionSlots: TLabel;
    NStrength: TNumberBox;
    LStrength: TLabel;
    NMatingCost: TNumberBox;
    LMatingCost: TLabel;
    NCombatGain: TNumberBox;
    LCombatGain: TLabel;
    NSigmaCombat: TNumberBox;
    LSigmaCombat: TLabel;
    NMutationSigma: TNumberBox;
    LMutationSigma: TLabel;
    NInitSigma: TNumberBox;
    LInitSigma: TLabel;
    NPopulationCount: TNumberBox;
    LPopulationCount: TLabel;
    PWorldBoard: TPaintBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BResetClick(Sender: TObject);
    procedure BStepClick(Sender: TObject);
    procedure PWorldBoardMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure PWorldBoardPaint(Sender: TObject; Canvas: TCanvas);
  private
    { Private declarations }
    FWorld: TWorld;
    FCellSize: Single;
    function BuildWorldConfig: TWorldConfig;
    procedure DrawMonkey(Canvas: TCanvas; const AX, AY: Integer;
      const ASex: TMonkeySex; const AIsPregnant: Boolean);
    function FormatMonkeyTraits(const ATraits: TMonkeyTraitSnapshot): string;
    function MonkeySexToText(const ASex: TMonkeySex): string;
    procedure RestartBoard;
  public
    { Public declarations }
  end;

var
  TabbedForm: TTabbedForm;

implementation

{$R *.fmx}

procedure TTabbedForm.FormCreate(Sender: TObject);
begin
  { This defines the default active tab at runtime }
  TabControl.ActiveTab := WorldTab;
  FWorld := TWorld.Create;
  RestartBoard;
end;

procedure TTabbedForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FWorld);
end;

procedure TTabbedForm.BResetClick(Sender: TObject);
begin
  RestartBoard;
end;

procedure TTabbedForm.BStepClick(Sender: TObject);
begin
  FWorld.RunWorldTurn;
  PWorldBoard.Repaint;
end;

procedure TTabbedForm.PWorldBoardMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  BoardX: Integer;
  BoardY: Integer;
  Traits: TMonkeyTraitSnapshot;
begin
  if Button <> TMouseButton.mbLeft then
    Exit;
  if FCellSize <= 0 then
    Exit;

  BoardX := Trunc(X / FCellSize);
  BoardY := Trunc(Y / FCellSize);

  if FWorld.TryGetMonkeyTraitsAt(BoardX, BoardY, Traits) then
    ShowMessage(FormatMonkeyTraits(Traits));
end;

procedure TTabbedForm.PWorldBoardPaint(Sender: TObject; Canvas: TCanvas);
var
  X: Integer;
  Y: Integer;
  I: Integer;
  CellRect: TRectF;
  Monkeys: UWorld.TWorldMonkeySnapshots;
begin
  Canvas.Fill.Color := TAlphaColors.White;
  Canvas.FillRect(PWorldBoard.LocalRect, 0, 0, [], 1);

  if FWorld = nil then
    Exit;

  for Y := 0 to FWorld.SizeY - 1 do
    for X := 0 to FWorld.SizeX - 1 do
    begin
      if Odd(X + Y) then
        Canvas.Fill.Color := $FFF2F2F2
      else
        Canvas.Fill.Color := TAlphaColors.White;

      CellRect := TRectF.Create(
        X * FCellSize,
        Y * FCellSize,
        (X + 1) * FCellSize,
        (Y + 1) * FCellSize);
      Canvas.FillRect(CellRect, 0, 0, [], 1);
    end;

  Monkeys := FWorld.GetMonkeySnapshots;
  for I := Low(Monkeys) to High(Monkeys) do
    DrawMonkey(Canvas, Monkeys[I].X, Monkeys[I].Y, Monkeys[I].Sex,
      Monkeys[I].IsPregnant);
end;

function TTabbedForm.BuildWorldConfig: TWorldConfig;
begin
  Result.SizeX := Round(NSizeX.Value);
  Result.SizeY := Round(NSizeY.Value);
  Result.BaseLifespan := NLifespan.Value;
  Result.VisionSlots := Round(NVisionSlots.Value);
  Result.InitialStrength := NStrength.Value;
  Result.MatingCost := NMatingCost.Value;
  Result.CombatGainPercent := NCombatGain.Value;
  Result.SigmaCombat := NSigmaCombat.Value;
  Result.MutationSigmaPercent := NMutationSigma.Value;
  Result.InitSigmaPercent := NInitSigma.Value;
  Result.PopulationCount := Round(NPopulationCount.Value);
end;

procedure TTabbedForm.DrawMonkey(Canvas: TCanvas; const AX, AY: Integer;
  const ASex: TMonkeySex; const AIsPregnant: Boolean);
var
  MonkeyRect: TRectF;
begin
  if AIsPregnant then
    Canvas.Fill.Color := TAlphaColors.Red
  else if ASex = msMale then
    Canvas.Fill.Color := $FF6495ED
  else
    Canvas.Fill.Color := $FFFF1493;

  MonkeyRect := TRectF.Create(
    AX * FCellSize,
    AY * FCellSize,
    (AX + 1) * FCellSize,
    (AY + 1) * FCellSize);
  Canvas.FillEllipse(MonkeyRect, 1);
end;

function TTabbedForm.FormatMonkeyTraits(
  const ATraits: TMonkeyTraitSnapshot): string;
begin
  Result :=
    Format('Id: %d', [ATraits.Id]) + sLineBreak +
    Format('Position: %d, %d', [ATraits.X, ATraits.Y]) + sLineBreak +
    'Sex: ' + MonkeySexToText(ATraits.Sex) + sLineBreak +
    Format('Mother Id: %d', [ATraits.MotherId]) + sLineBreak +
    Format('Father Id: %d', [ATraits.FatherId]) + sLineBreak +
    Format('Maternal grandmother Id: %d', [ATraits.MaternalGrandmotherId]) + sLineBreak +
    Format('Maternal grandfather Id: %d', [ATraits.MaternalGrandfatherId]) + sLineBreak +
    Format('Paternal grandmother Id: %d', [ATraits.PaternalGrandmotherId]) + sLineBreak +
    Format('Paternal grandfather Id: %d', [ATraits.PaternalGrandfatherId]) + sLineBreak +
    Format('Generation count: %d', [ATraits.GenCount]) + sLineBreak +
    Format('Strength: %.2f', [ATraits.Strength]) + sLineBreak +
    Format('Lifespan: %.2f', [ATraits.Lifespan]) + sLineBreak +
    Format('Age: %d', [ATraits.Age]) + sLineBreak +
    Format('Vision slots: %d', [ATraits.VisionSlots]) + sLineBreak +
    Format('Memory slots: %d', [ATraits.MemoryCount]) + sLineBreak +
    Format('Pregnant turns remaining: %d', [ATraits.PregnantTurnsRemaining]) + sLineBreak +
    Format('Pregnant: %s', [BoolToStr(ATraits.IsPregnant, True)]) + sLineBreak +
    Format('Alive: %s', [BoolToStr(ATraits.Alive, True)]);
end;

function TTabbedForm.MonkeySexToText(const ASex: TMonkeySex): string;
begin
  case ASex of
    msMale:
      Result := 'Male';
    msFemale:
      Result := 'Female';
  else
    Result := 'Unknown';
  end;
end;

procedure TTabbedForm.RestartBoard;
begin
  FWorld.Restart(BuildWorldConfig);
  FCellSize := 16;

  //PWorldBoard.Align := TAlignLayout.None;
  PWorldBoard.Position.X := 0;
  PWorldBoard.Position.Y := 0;
  PWorldBoard.Width := FWorld.SizeX * FCellSize;
  PWorldBoard.Height := FWorld.SizeY * FCellSize;
  PWorldBoard.Repaint;
end;

end.
