unit UMonkeysForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Diagnostics, System.Math, FMX.Types, FMX.Graphics, FMX.Controls,
  FMX.Forms, FMX.Dialogs, FMX.TabControl, FMX.StdCtrls, FMX.Gestures,
  FMX.Controls.Presentation, FMX.Layouts, FMX.Edit, FMX.EditBox,
  FMX.NumberBox, FMX.Objects, UMonkey, UNeuralNet, UNeuralNetFrame, UWorld;

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
    LStepTime: TLabel;
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
    NeuralNetFrame1: TNeuralNetFrame;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BPauseClick(Sender: TObject);
    procedure BResetClick(Sender: TObject);
    procedure BStepClick(Sender: TObject);
    procedure BStartClick(Sender: TObject);
    procedure PWorldBoardMouseLeave(Sender: TObject);
    procedure PWorldBoardMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Single);
    procedure PWorldBoardMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure PWorldBoardPaint(Sender: TObject; Canvas: TCanvas);
    procedure TurnSpeedTrackChange(Sender: TObject);
  private
    FWorld: TWorld;
    FCellSize: Single;
    FMonkeyHoverBox: TRectangle;
    FMonkeyHoverText: TText;
    FRunTimer: TTimer;
    function BuildWorldConfig: TWorldConfig;
    procedure CreateMonkeyHoverBox;
    procedure DrawMonkey(Canvas: TCanvas; const AX, AY: Integer;
      const ASex: TMonkeySex; const AIsPregnant: Boolean);
    function FormatMonkeyTraits(const ATraits: TMonkeyTraitSnapshot): string;
    procedure HideMonkeyHoverBox;
    function MonkeySexToText(const ASex: TMonkeySex): string;
    procedure RestartBoard;
    procedure RunWorldStep;
    procedure RunTimerTimer(Sender: TObject);
    procedure ShowMonkeyHoverBox(const AX, AY: Single;
      const ATraits: TMonkeyTraitSnapshot);
    procedure UpdateRunTimerInterval;
  public
  end;

var
  TabbedForm: TTabbedForm;

implementation

{$R *.fmx}

procedure TTabbedForm.FormCreate(Sender: TObject);
begin
  TabControl.ActiveTab := WorldTab;
  FWorld := TWorld.Create;
  FRunTimer := TTimer.Create(Self);
  FRunTimer.Enabled := False;
  FRunTimer.OnTimer := RunTimerTimer;
  UpdateRunTimerInterval;
  CreateMonkeyHoverBox;
  RestartBoard;
end;

procedure TTabbedForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FRunTimer);
  FreeAndNil(FMonkeyHoverBox);
  FreeAndNil(FWorld);
end;

procedure TTabbedForm.BPauseClick(Sender: TObject);
begin
  FRunTimer.Enabled := False;
end;

procedure TTabbedForm.BResetClick(Sender: TObject);
begin
  FRunTimer.Enabled := False;
  RestartBoard;
end;

procedure TTabbedForm.BStepClick(Sender: TObject);
begin
  FRunTimer.Enabled := False;
  RunWorldStep;
end;

procedure TTabbedForm.BStartClick(Sender: TObject);
begin
  UpdateRunTimerInterval;
  FRunTimer.Enabled := True;
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

procedure TTabbedForm.CreateMonkeyHoverBox;
begin
  FMonkeyHoverBox := TRectangle.Create(Self);
  FMonkeyHoverBox.Parent := WorldTab;
  FMonkeyHoverBox.Visible := False;
  FMonkeyHoverBox.HitTest := False;
  FMonkeyHoverBox.Width := 300;
  FMonkeyHoverBox.Height := 360;
  FMonkeyHoverBox.Fill.Color := $EEFFFFFF;
  FMonkeyHoverBox.Stroke.Color := $FF808080;
  FMonkeyHoverBox.XRadius := 4;
  FMonkeyHoverBox.YRadius := 4;

  FMonkeyHoverText := TText.Create(FMonkeyHoverBox);
  FMonkeyHoverText.Parent := FMonkeyHoverBox;
  FMonkeyHoverText.HitTest := False;
  FMonkeyHoverText.Position.X := 8;
  FMonkeyHoverText.Position.Y := 8;
  FMonkeyHoverText.Width := FMonkeyHoverBox.Width - 16;
  FMonkeyHoverText.Height := FMonkeyHoverBox.Height - 16;
  FMonkeyHoverText.TextSettings.Font.Size := 12;
  FMonkeyHoverText.TextSettings.FontColor := TAlphaColors.Black;
  FMonkeyHoverText.TextSettings.HorzAlign := TTextAlign.Leading;
  FMonkeyHoverText.TextSettings.VertAlign := TTextAlign.Leading;
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
    Format('Maternal grandmother Id: %d',
      [ATraits.MaternalGrandmotherId]) + sLineBreak +
    Format('Maternal grandfather Id: %d',
      [ATraits.MaternalGrandfatherId]) + sLineBreak +
    Format('Paternal grandmother Id: %d',
      [ATraits.PaternalGrandmotherId]) + sLineBreak +
    Format('Paternal grandfather Id: %d',
      [ATraits.PaternalGrandfatherId]) + sLineBreak +
    Format('Generation count: %d', [ATraits.GenCount]) + sLineBreak +
    Format('Strength: %.2f', [ATraits.Strength]) + sLineBreak +
    Format('Total strength: %.2f', [ATraits.TotalStrength]) + sLineBreak +
    Format('Lifespan: %.2f', [ATraits.Lifespan]) + sLineBreak +
    Format('Age: %d', [ATraits.Age]) + sLineBreak +
    Format('Vision slots: %d', [ATraits.VisionSlots]) + sLineBreak +
    Format('Memory slots: %d', [ATraits.MemoryCount]) + sLineBreak +
    Format('Pregnant turns remaining: %d',
      [ATraits.PregnantTurnsRemaining]) + sLineBreak +
    Format('Pregnant: %s', [BoolToStr(ATraits.IsPregnant, True)]) + sLineBreak +
    Format('Alive: %s', [BoolToStr(ATraits.Alive, True)]);
end;

procedure TTabbedForm.HideMonkeyHoverBox;
begin
  if FMonkeyHoverBox <> nil then
    FMonkeyHoverBox.Visible := False;
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

procedure TTabbedForm.PWorldBoardMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  BoardX: Integer;
  BoardY: Integer;
  Config: TNeuralNetConfig;
  Inputs: TMonkeyNNInputs;
  Outputs: TNeuralNetOutputs;
  Traits: TMonkeyTraitSnapshot;
  Weights: TNeuralNetWeights;
begin
  if Button <> TMouseButton.mbLeft then
    Exit;
  if FCellSize <= 0 then
    Exit;

  BoardX := Trunc(X / FCellSize);
  BoardY := Trunc(Y / FCellSize);

  if FWorld.TryGetMonkeyBrainAt(BoardX, BoardY, Config, Weights, Inputs,
    Outputs) and FWorld.TryGetMonkeyTraitsAt(BoardX, BoardY, Traits) then
  begin
    NeuralNetFrame1.ShowMonkeyBrain(Traits, Config, Weights, Inputs, Outputs);
    TabControl.ActiveTab := NNTab;
    NeuralNetFrame1.ActivateGraphView;
  end
  else
    NeuralNetFrame1.ClearMonkeyBrain;
end;

procedure TTabbedForm.PWorldBoardMouseLeave(Sender: TObject);
begin
  HideMonkeyHoverBox;
end;

procedure TTabbedForm.PWorldBoardMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Single);
var
  BoardX: Integer;
  BoardY: Integer;
  Traits: TMonkeyTraitSnapshot;
begin
  if FCellSize <= 0 then
  begin
    HideMonkeyHoverBox;
    Exit;
  end;

  BoardX := Trunc(X / FCellSize);
  BoardY := Trunc(Y / FCellSize);

  if FWorld.TryGetMonkeyTraitsAt(BoardX, BoardY, Traits) then
    ShowMonkeyHoverBox(X, Y, Traits)
  else
    HideMonkeyHoverBox;
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

procedure TTabbedForm.RestartBoard;
begin
  FWorld.Restart(BuildWorldConfig);
  HideMonkeyHoverBox;
  NeuralNetFrame1.ClearMonkeyBrain;
  LStepTime.Text := 'Step time: -';
  FCellSize := 16;

  PWorldBoard.Position.X := 0;
  PWorldBoard.Position.Y := 0;
  PWorldBoard.Width := FWorld.SizeX * FCellSize;
  PWorldBoard.Height := FWorld.SizeY * FCellSize;
  PWorldBoard.Repaint;
end;

procedure TTabbedForm.RunTimerTimer(Sender: TObject);
begin
  RunWorldStep;
end;

procedure TTabbedForm.RunWorldStep;
var
  Stopwatch: TStopwatch;
begin
  Stopwatch := TStopwatch.StartNew;
  FWorld.RunWorldTurn;
  Stopwatch.Stop;
  LStepTime.Text := Format('Step time: %.3f ms',
    [Stopwatch.Elapsed.TotalMilliseconds]);

  HideMonkeyHoverBox;
  PWorldBoard.Repaint;
end;

procedure TTabbedForm.ShowMonkeyHoverBox(const AX, AY: Single;
  const ATraits: TMonkeyTraitSnapshot);
var
  BoardPoint: TPointF;
  PopupPoint: TPointF;
begin
  if (FMonkeyHoverBox = nil) or (FMonkeyHoverText = nil) then
    Exit;

  FMonkeyHoverText.Text := FormatMonkeyTraits(ATraits);

  BoardPoint := PWorldBoard.LocalToAbsolute(TPointF.Create(AX + 16, AY + 16));
  PopupPoint := WorldTab.AbsoluteToLocal(BoardPoint);

  if PopupPoint.X + FMonkeyHoverBox.Width > WorldTab.Width then
    PopupPoint.X := PopupPoint.X - FMonkeyHoverBox.Width - 32;
  if PopupPoint.Y + FMonkeyHoverBox.Height > WorldTab.Height then
    PopupPoint.Y := WorldTab.Height - FMonkeyHoverBox.Height - 8;
  if PopupPoint.X < 8 then
    PopupPoint.X := 8;
  if PopupPoint.Y < 8 then
    PopupPoint.Y := 8;

  FMonkeyHoverBox.Position.X := PopupPoint.X;
  FMonkeyHoverBox.Position.Y := PopupPoint.Y;
  FMonkeyHoverBox.BringToFront;
  FMonkeyHoverBox.Visible := True;
end;

procedure TTabbedForm.TurnSpeedTrackChange(Sender: TObject);
begin
  UpdateRunTimerInterval;
end;

procedure TTabbedForm.UpdateRunTimerInterval;
var
  TurnsPerSecond: Double;
begin
  if FRunTimer = nil then
    Exit;

  TurnsPerSecond := Max(1, TurnSpeedTrack.Value);
  FRunTimer.Interval := Max(1, Round(1000 / TurnsPerSecond));
  LTurnSpeed.Text := Format('Turn speed: %.0f steps/sec', [TurnsPerSecond]);
end;

end.
