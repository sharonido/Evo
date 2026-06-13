unit UMonkeysForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Diagnostics, System.Math, FMX.Types, FMX.Graphics, FMX.Controls,
  FMX.Forms, FMX.Dialogs, FMX.TabControl, FMX.StdCtrls,
  FMX.Gestures, FMX.Controls.Presentation, FMX.Layouts, FMX.Edit, FMX.EditBox,
  FMX.NumberBox, FMX.Objects, UAverageAgeGraphForm, UBaseMonkey,
  UBaseWorld, UMonkey, UNeuralNet, UNeuralNetFrame, UWorld;

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
    BMaxSpeed: TSpeedButton;
    LTurnSpeed: TLabel;
    TurnSpeedTrack: TTrackBar;
    LStepTime: TLabel;
    LGameCount: TLabel;
    LWorldStepCount: TLabel;
    LLiveMonkeyCount: TLabel;
    LDeadMonkeyCount: TLabel;
    LCombatDeathCount: TLabel;
    LBornMonkeyCount: TLabel;
    LLivingMaxGen: TLabel;
    LMaxGen: TLabel;
    LAllGamesMaxGen: TLabel;
    ConfigGroup: TGroupBox;
    StatGroupBox: TGroupBox;
    LAverageAge: TLabel;
    BAverageAgeGraph: TButton;
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
    SaveDjson: TSaveDialog;
    RoundRect1: TRoundRect;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BPauseClick(Sender: TObject);
    procedure BResetClick(Sender: TObject);
    procedure BStepClick(Sender: TObject);
    procedure BStartClick(Sender: TObject);
    procedure BAverageAgeGraphClick(Sender: TObject);
    procedure BMaxSpeedClick(Sender: TObject);
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
    FSelectedBrainMonkeyId: TMonkeyId;
    FGameCount: Integer;
    FAllGamesMaxGenCount: Integer;
    FAllGamesMaxGenMonkeyId: TMonkeyId;
    FLastStepTimeMs: Double;
    FLastViewRefresh: TStopwatch;
    FAverageAgeSamples: TAverageAgeSamples;
    FAverageAgeGraphForm: TAverageAgeGraphForm;
    function BuildWorldConfig: TWorldConfig;
    procedure BJsonSaveClick(Sender: TObject);
    function CalculateMonkeyAgeStats(out AAverageAge: Double;
      out AMaxAge: Integer): Boolean;
    procedure ClearAverageAgeSamples;
    procedure CreateMonkeyHoverBox;
    procedure DrawMonkey(Canvas: TCanvas; const AX, AY: Integer;
      const ASex: TMonkeySex; const AIsPregnant: Boolean);
    function EvolutionFileDirectory: string;
    function FindBestGenerationJsonFile(const ADirectory: string;
      out AFileName: string): Boolean;
    function FormatMonkeyTraits(const ATraits: TMonkeyTraitSnapshot): string;
    procedure HideMonkeyHoverBox;
    function MonkeySexToText(const ASex: TMonkeySex): string;
    procedure RecordAverageAgeSample;
    procedure RefreshWorldView(const AForce: Boolean);
    procedure RestartBoard;
    procedure RunWorldStep;
    function RunWorldStepCore: Boolean;
    procedure RunTimerTimer(Sender: TObject);
    procedure ShowMonkeyHoverBox(const AX, AY: Single;
      const ATraits: TMonkeyTraitSnapshot);
    procedure UpdateAverageAgeGraph;
    procedure UpdateRunTimerInterval;
    procedure UpdateWorldStatistics;
  public
  end;

var
  TabbedForm: TTabbedForm;

implementation

{$R *.fmx}

const
  MAX_SPEED_WORK_MILLISECONDS = 15;
  MAX_SPEED_REFRESH_MILLISECONDS = 200;
  MAX_SPEED_SAFETY_STEPS = 1000;

procedure TTabbedForm.FormCreate(Sender: TObject);
begin
  TabControl.ActiveTab := WorldTab;
  FWorld := TWorld.Create;
  FLastStepTimeMs := 0;
  FLastViewRefresh := TStopwatch.StartNew;
  FRunTimer := TTimer.Create(Self);
  FRunTimer.Enabled := False;
  FRunTimer.OnTimer := RunTimerTimer;
  UpdateRunTimerInterval;
  NeuralNetFrame1.BJsonSave.OnClick := BJsonSaveClick;
  CreateMonkeyHoverBox;
  RestartBoard;
end;

procedure TTabbedForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FAverageAgeGraphForm);
  FreeAndNil(FRunTimer);
  FreeAndNil(FMonkeyHoverBox);
  FreeAndNil(FWorld);
end;

procedure TTabbedForm.BPauseClick(Sender: TObject);
begin
  FRunTimer.Enabled := False;
end;

procedure TTabbedForm.BMaxSpeedClick(Sender: TObject);
begin
  UpdateRunTimerInterval;
end;

procedure TTabbedForm.BResetClick(Sender: TObject);
begin
  FRunTimer.Enabled := False;
  FGameCount := 0;
  FAllGamesMaxGenCount := -1;
  FAllGamesMaxGenMonkeyId := 0;
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

procedure TTabbedForm.BAverageAgeGraphClick(Sender: TObject);
begin
  FreeAndNil(FAverageAgeGraphForm);
  FAverageAgeGraphForm := TAverageAgeGraphForm.Create(Self);

  UpdateAverageAgeGraph;
  FAverageAgeGraphForm.Show;
  FAverageAgeGraphForm.BringToFront;
end;

procedure TTabbedForm.BJsonSaveClick(Sender: TObject);
begin
  if FSelectedBrainMonkeyId = 0 then
  begin
    ShowMessage('Select a monkey before saving its neural net JSON.');
    Exit;
  end;

  SaveDjson.DefaultExt := 'json';
  SaveDjson.Filter := 'JSON files (*.json)|*.json|All files (*.*)|*.*';
  SaveDjson.FileName := Format('monkey_%d_weights.json',
    [FSelectedBrainMonkeyId]);

  if SaveDjson.Execute then
    try
      FWorld.SaveMonkeyWeightsJsonToFile(FSelectedBrainMonkeyId,
        SaveDjson.FileName);
    except
      on E: Exception do
        ShowMessage('Could not save neural net JSON: ' + E.Message);
    end;
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

function TTabbedForm.CalculateMonkeyAgeStats(out AAverageAge: Double;
  out AMaxAge: Integer): Boolean;
var
  X: Integer;
  Y: Integer;
  TotalAge: Int64;
  Traits: TMonkeyTraitSnapshot;
begin
  Result := False;
  AAverageAge := 0;
  AMaxAge := 0;

  if (FWorld = nil) or (FWorld.MonkeyCount = 0) then
    Exit;

  TotalAge := 0;
  for Y := 0 to FWorld.SizeY - 1 do
    for X := 0 to FWorld.SizeX - 1 do
      if FWorld.TryGetMonkeyTraitsAt(X, Y, Traits) then
      begin
        Inc(TotalAge, Traits.Age);
        AMaxAge := Max(AMaxAge, Traits.Age);
      end;

  AAverageAge := TotalAge / FWorld.MonkeyCount;
  Result := True;
end;

procedure TTabbedForm.ClearAverageAgeSamples;
begin
  SetLength(FAverageAgeSamples, 0);
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
  if AIsPregnant then
  begin
    Canvas.Stroke.Color := TAlphaColors.Black;
    Canvas.Stroke.Thickness := 1;
    Canvas.DrawEllipse(MonkeyRect, 1);
  end;
end;

function TTabbedForm.EvolutionFileDirectory: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
end;

function TTabbedForm.FindBestGenerationJsonFile(const ADirectory: string;
  out AFileName: string): Boolean;
var
  BestGen: Integer;
  CurrentGen: Integer;
  FileGenText: string;
  SearchRec: TSearchRec;
begin
  Result := False;
  AFileName := '';
  BestGen := -1;

  if System.SysUtils.FindFirst(IncludeTrailingPathDelimiter(ADirectory) +
    'Gen*.json', faAnyFile, SearchRec) <> 0 then
    Exit;
  try
    repeat
      if (SearchRec.Attr and faDirectory) = 0 then
      begin
        FileGenText := Copy(SearchRec.Name, 4,
          Length(SearchRec.Name) - Length('Gen') - Length('.json'));
        if SameText(ExtractFileExt(SearchRec.Name), '.json') and
          TryStrToInt(FileGenText, CurrentGen) and (CurrentGen > BestGen) then
        begin
          BestGen := CurrentGen;
          AFileName := IncludeTrailingPathDelimiter(ADirectory) +
            SearchRec.Name;
          Result := True;
        end;
      end;
    until System.SysUtils.FindNext(SearchRec) <> 0;
  finally
    System.SysUtils.FindClose(SearchRec);
  end;
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
    FSelectedBrainMonkeyId := Traits.Id;
    NeuralNetFrame1.ShowMonkeyBrain(Traits, Config, Weights, Inputs, Outputs);
    TabControl.ActiveTab := NNTab;
    NeuralNetFrame1.ActivateGraphView;
  end
  else
  begin
    FSelectedBrainMonkeyId := 0;
    NeuralNetFrame1.ClearMonkeyBrain;
  end;
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
  Monkeys: UBaseWorld.TWorldMonkeySnapshots;
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
  if FGameCount <= 0 then
    FGameCount := 1;
  FSelectedBrainMonkeyId := 0;
  HideMonkeyHoverBox;
  NeuralNetFrame1.ClearMonkeyBrain;
  FLastStepTimeMs := 0;
  FLastViewRefresh := TStopwatch.StartNew;
  LStepTime.Text := 'Step time: -';
  ClearAverageAgeSamples;
  RecordAverageAgeSample;
  UpdateWorldStatistics;
  FCellSize := 16;

  PWorldBoard.Position.X := 0;
  PWorldBoard.Position.Y := 0;
  PWorldBoard.Width := FWorld.SizeX * FCellSize;
  PWorldBoard.Height := FWorld.SizeY * FCellSize;
  PWorldBoard.Repaint;
end;

procedure TTabbedForm.RunTimerTimer(Sender: TObject);
var
  BatchStopwatch: TStopwatch;
  StepsMade: Integer;
begin
  if (BMaxSpeed <> nil) and BMaxSpeed.IsPressed then
  begin
    StepsMade := 0;
    BatchStopwatch := TStopwatch.StartNew;

    repeat
      if not RunWorldStepCore then
        Break;
      Inc(StepsMade);
    until (not FRunTimer.Enabled) or (not BMaxSpeed.IsPressed) or
      (BatchStopwatch.ElapsedMilliseconds >= MAX_SPEED_WORK_MILLISECONDS) or
      (StepsMade >= MAX_SPEED_SAFETY_STEPS);

    if StepsMade > 0 then
      RefreshWorldView(False);
    Exit;
  end;

  RunWorldStep;
end;

procedure TTabbedForm.RunWorldStep;
begin
  if RunWorldStepCore then
    RefreshWorldView(True);
end;

function TTabbedForm.RunWorldStepCore: Boolean;
var
  BestGenJsonFileName: string;
  EvolutionDirectory: string;
  GenJsonFileName: string;
  LastJsonFileName: string;
  Stopwatch: TStopwatch;
begin
  Result := False;
  Stopwatch := TStopwatch.StartNew;
  FWorld.RunWorldTurn;
  Stopwatch.Stop;
  FLastStepTimeMs := Stopwatch.Elapsed.TotalMilliseconds;
  RecordAverageAgeSample;

  if FWorld.GenerationEnded then
  begin
    if FWorld.MaxGenCount > FAllGamesMaxGenCount then
    begin
      FAllGamesMaxGenCount := FWorld.MaxGenCount;
      FAllGamesMaxGenMonkeyId := FWorld.MaxGenMonkeyId;
    end;

    EvolutionDirectory := EvolutionFileDirectory;
    LastJsonFileName := EvolutionDirectory + 'last.json';
    GenJsonFileName := EvolutionDirectory + Format('Gen%d.json',
      [FWorld.MaxGenCount]);
    try
      FWorld.SaveLastSurvivorWeightsJsonToFile(LastJsonFileName);
      FWorld.SaveMaxGenerationWeightsJsonToFile(GenJsonFileName);
      if not FindBestGenerationJsonFile(EvolutionDirectory,
        BestGenJsonFileName) then
        BestGenJsonFileName := GenJsonFileName;
      FWorld.RestartFromParentWeightsFiles(BuildWorldConfig, LastJsonFileName,
        BestGenJsonFileName);
      ClearAverageAgeSamples;
      RecordAverageAgeSample;
      Inc(FGameCount);
      FSelectedBrainMonkeyId := 0;
      NeuralNetFrame1.ClearMonkeyBrain;
      FCellSize := 16;
      PWorldBoard.Width := FWorld.SizeX * FCellSize;
      PWorldBoard.Height := FWorld.SizeY * FCellSize;
    except
      on E: Exception do
      begin
        FRunTimer.Enabled := False;
        ShowMessage('Could not restart from evolution JSON files: ' +
          E.Message);
        Exit;
      end;
    end;
  end;

  Result := True;
end;

procedure TTabbedForm.RecordAverageAgeSample;
var
  AverageAge: Double;
  MaxAge: Integer;
  SampleCount: Integer;
begin
  if not CalculateMonkeyAgeStats(AverageAge, MaxAge) then
    Exit;
  SampleCount := Length(FAverageAgeSamples);
  if (SampleCount > 0) and

    (FAverageAgeSamples[SampleCount - 1].Step = FWorld.WorldStepCount) then
  begin
    FAverageAgeSamples[SampleCount - 1].AverageAge := AverageAge;
    FAverageAgeSamples[SampleCount - 1].MaxAge := MaxAge;
    Exit;
  end;

  SetLength(FAverageAgeSamples, SampleCount + 1);
  FAverageAgeSamples[SampleCount].Step := FWorld.WorldStepCount;
  FAverageAgeSamples[SampleCount].AverageAge := AverageAge;
  FAverageAgeSamples[SampleCount].MaxAge := MaxAge;
end;

procedure TTabbedForm.UpdateAverageAgeGraph;
begin
  if (FAverageAgeGraphForm <> nil) and FAverageAgeGraphForm.Visible then
    FAverageAgeGraphForm.LoadSamples(FAverageAgeSamples);
end;

procedure TTabbedForm.RefreshWorldView(const AForce: Boolean);
begin
  if (not AForce) and
    (FLastViewRefresh.ElapsedMilliseconds < MAX_SPEED_REFRESH_MILLISECONDS) then
    Exit;

  if FLastStepTimeMs > 0 then
    LStepTime.Text := Format('Step time: %.3f ms', [FLastStepTimeMs])
  else
    LStepTime.Text := 'Step time: -';

  UpdateWorldStatistics;
  UpdateAverageAgeGraph;
  HideMonkeyHoverBox;
  PWorldBoard.Repaint;
  FLastViewRefresh := TStopwatch.StartNew;
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

  if (BMaxSpeed <> nil) and BMaxSpeed.IsPressed then
  begin
    FRunTimer.Interval := 1;
    LTurnSpeed.Text := 'Turn speed: max';
    Exit;
  end;

  TurnsPerSecond := Max(1, TurnSpeedTrack.Value);
  FRunTimer.Interval := Max(1, Round(1000 / TurnsPerSecond));
  LTurnSpeed.Text := Format('Turn speed: %.0f steps/sec', [TurnsPerSecond]);
end;

procedure TTabbedForm.UpdateWorldStatistics;
var
  AverageAge: Double;
  MaxAge: Integer;
begin
  if FWorld = nil then
    Exit;

  LWorldStepCount.Text := Format('Steps: %d', [FWorld.WorldStepCount]);
  LGameCount.Text := Format('Games: %d', [FGameCount]);
  LLiveMonkeyCount.Text := Format('Live monkeys: %d', [FWorld.MonkeyCount]);
  if not CalculateMonkeyAgeStats(AverageAge, MaxAge) then
    LAverageAge.Text := 'Average age: -'
  else
    LAverageAge.Text := Format('Average age: %.1f', [AverageAge]);
  LDeadMonkeyCount.Text := Format('Dead monkeys: %d',
    [FWorld.DeadMonkeyCount]);
  LCombatDeathCount.Text := Format('Combat deaths: %d',
    [FWorld.CombatDeathCount]);
  LBornMonkeyCount.Text := Format('Born monkeys: %d',
    [FWorld.BornMonkeyCount]);
  if FWorld.LivingMaxGenMonkeyId = 0 then
    LLivingMaxGen.Text := 'Living max gen: none'
  else
    LLivingMaxGen.Text := Format('Living max gen: %d, Id: %d',
      [FWorld.LivingMaxGenCount, FWorld.LivingMaxGenMonkeyId]);

  if FWorld.MaxGenMonkeyId = 0 then
    LMaxGen.Text := 'Max gen: none'
  else
    LMaxGen.Text := Format('Max gen: %d, Id: %d',
      [FWorld.MaxGenCount, FWorld.MaxGenMonkeyId]);

  if FAllGamesMaxGenMonkeyId = 0 then
    LAllGamesMaxGen.Text := 'All games max gen: none'
  else
    LAllGamesMaxGen.Text := Format('All games max gen: %d, Id: %d',
      [FAllGamesMaxGenCount, FAllGamesMaxGenMonkeyId]);
end;

end.
