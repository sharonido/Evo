unit UNeuralNetFrame;

interface

uses
  System.Classes, System.Generics.Collections, System.Generics.Defaults,
  System.Math, System.SysUtils, System.Types, System.UITypes, FMX.Controls,
  FMX.Forms, FMX.Graphics, FMX.Memo, FMX.Memo.Types, FMX.Objects,
  FMX.ScrollBox, FMX.StdCtrls, FMX.TabControl, FMX.Types, UBaseMonkey,
  UMonkey, UBaseWorld, UNeuralNet, FMX.Controls.Presentation, FMX.Dialogs;

type
  TNeuralNetFrame = class(TFrame)
    TabControl1: TTabControl;
    TabNNView: TTabItem;
    GroupViewControl: TGroupBox;
    PaintBoxNNGraphView: TPaintBox;
    TabNNJson: TTabItem;
    GroupBoxNNJsonControl: TGroupBox;
    MemoJson: TMemo;
    BJsonSave: TButton;
    procedure PaintBoxNNGraphViewMouseLeave(Sender: TObject);
    procedure PaintBoxNNGraphViewMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Single);
    procedure PaintBoxNNGraphViewPaint(Sender: TObject; Canvas: TCanvas);
  private
    FNNInputHoverBox: TRectangle;
    FNNInputHoverText: TText;
    FNNGraphInfoText: TText;
    FHasSelectedNNGraph: Boolean;
    FSelectedMonkeyTraits: TMonkeyTraitSnapshot;
    FSelectedNNConfig: TNeuralNetConfig;
    FSelectedNNWeights: TNeuralNetWeights;
    FSelectedNNInputs: TMonkeyNNInputs;
    FSelectedNNOutputs: TNeuralNetOutputs;
    FNNInputNodePositions: array of TPointF;
    FNNOutputNodePositions: array of TPointF;
    FNNInputNodeRadius: Single;
    FNNOutputNodeRadius: Single;
    procedure ClearNodePositions;
    procedure CreateNNGraphInfoText;
    procedure CreateNNInputHoverBox;
    function DirectionOptionText(const ADirection: Integer): string;
    procedure DrawNNGraph(Canvas: TCanvas);
    procedure HideNNInputHoverBox;
    function MonkeySexToText(const ASex: TMonkeySex): string;
    function NNInputDescription(const AInputIndex: Integer): string;
    procedure ShowNNInputHoverBox(const AInputIndex: Integer);
    function TryGetNNInputAt(const AX, AY: Single;
      out AInputIndex: Integer): Boolean;
    function TryGetNNOutputAt(const AX, AY: Single;
      out AOutputIndex: Integer): Boolean;
    procedure UpdateMemoJson;
    procedure UpdateNNGraphInfoText;
    function WinningOutputIndex(const AStartIndex, ACount: Integer): Integer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ActivateGraphView;
    procedure ClearMonkeyBrain;
    procedure ShowMonkeyBrain(const ATraits: TMonkeyTraitSnapshot;
      const AConfig: TNeuralNetConfig; const AWeights: TNeuralNetWeights;
      const AInputs: TMonkeyNNInputs; const AOutputs: TNeuralNetOutputs);
  end;

implementation

{$R *.fmx}

procedure TNeuralNetFrame.ActivateGraphView;
begin
  TabControl1.ActiveTab := TabNNView;
end;

procedure TNeuralNetFrame.ClearMonkeyBrain;
begin
  FHasSelectedNNGraph := False;
  FSelectedNNConfig.InputCount := 0;
  FSelectedNNConfig.Hidden1Count := 0;
  FSelectedNNConfig.Hidden2Count := 0;
  FSelectedNNConfig.Hidden3Count := 0;
  FSelectedNNConfig.OutputCount := 0;
  SetLength(FSelectedNNWeights, 0);
  SetLength(FSelectedNNInputs, 0);
  SetLength(FSelectedNNOutputs, 0);
  ClearNodePositions;
  HideNNInputHoverBox;
  UpdateNNGraphInfoText;
  UpdateMemoJson;
  PaintBoxNNGraphView.Repaint;
end;

procedure TNeuralNetFrame.ClearNodePositions;
begin
  SetLength(FNNInputNodePositions, 0);
  SetLength(FNNOutputNodePositions, 0);
  FNNInputNodeRadius := 0;
  FNNOutputNodeRadius := 0;
end;

procedure TNeuralNetFrame.CreateNNGraphInfoText;
begin
  FNNGraphInfoText := TText.Create(Self);
  FNNGraphInfoText.Parent := GroupViewControl;
  FNNGraphInfoText.HitTest := False;
  FNNGraphInfoText.Position.X := 8;
  FNNGraphInfoText.Position.Y := 24;
  FNNGraphInfoText.Width := GroupViewControl.Width - 16;
  FNNGraphInfoText.Height := GroupViewControl.Height - 32;
  FNNGraphInfoText.TextSettings.Font.Size := 11;
  FNNGraphInfoText.TextSettings.FontColor := TAlphaColors.Black;
  FNNGraphInfoText.TextSettings.HorzAlign := TTextAlign.Leading;
  FNNGraphInfoText.TextSettings.VertAlign := TTextAlign.Leading;
  UpdateNNGraphInfoText;
end;

procedure TNeuralNetFrame.CreateNNInputHoverBox;
begin
  FNNInputHoverBox := TRectangle.Create(Self);
  FNNInputHoverBox.Parent := PaintBoxNNGraphView;
  FNNInputHoverBox.Visible := False;
  FNNInputHoverBox.HitTest := False;
  FNNInputHoverBox.Width := 240;
  FNNInputHoverBox.Height := 86;
  FNNInputHoverBox.Fill.Color := $EEFFFFFF;
  FNNInputHoverBox.Stroke.Color := $FF808080;
  FNNInputHoverBox.XRadius := 4;
  FNNInputHoverBox.YRadius := 4;

  FNNInputHoverText := TText.Create(FNNInputHoverBox);
  FNNInputHoverText.Parent := FNNInputHoverBox;
  FNNInputHoverText.HitTest := False;
  FNNInputHoverText.Position.X := 8;
  FNNInputHoverText.Position.Y := 8;
  FNNInputHoverText.Width := FNNInputHoverBox.Width - 16;
  FNNInputHoverText.Height := FNNInputHoverBox.Height - 16;
  FNNInputHoverText.TextSettings.Font.Size := 12;
  FNNInputHoverText.TextSettings.FontColor := TAlphaColors.Black;
  FNNInputHoverText.TextSettings.HorzAlign := TTextAlign.Leading;
  FNNInputHoverText.TextSettings.VertAlign := TTextAlign.Leading;
end;

destructor TNeuralNetFrame.Destroy;
begin
  FreeAndNil(FNNInputHoverBox);
  inherited Destroy;
end;

function TNeuralNetFrame.DirectionOptionText(
  const ADirection: Integer): string;
begin
  case ADirection of
    0: Result := 'Stay';
    1: Result := 'North';
    2: Result := 'NE';
    3: Result := 'East';
    4: Result := 'SE';
    5: Result := 'South';
    6: Result := 'SW';
    7: Result := 'West';
    8: Result := 'NW';
  else
    Result := 'Unknown';
  end;
end;

procedure TNeuralNetFrame.DrawNNGraph(Canvas: TCanvas);
type
  TNNNodePositions = array of TPointF;
  TNNLayerPositions = array[0..4] of TNNNodePositions;
  TNNLayerCounts = array[0..4] of Integer;
var
  LayerCounts: TNNLayerCounts;
  LayerPositions: TNNLayerPositions;
  GraphRect: TRectF;
  ContentWidth: Single;
  ContentHeight: Single;
  MarginX: Single;
  MarginY: Single;
  NodeRadius: Single;
  OutputNodeRadius: Single;
  MaxLayerCount: Integer;
  LayerIndex: Integer;
  NodeIndex: Integer;
  InputNodeIndex: Integer;
  AbsWeights: array of Double;
  WeightIndex: Integer;
  Threshold: Double;

  function LayerColor(const ALayerIndex: Integer): TAlphaColor;
  begin
    case ALayerIndex of
      0: Result := $FF2EAD4A;
      4: Result := $FF3A78D8;
    else
      Result := $FFE14A3B;
    end;
  end;

  procedure BuildLayerPositions;
  var
    LocalLayerIndex: Integer;
    LocalNodeIndex: Integer;
    X: Single;
    Y: Single;
    StepX: Single;
  begin
    for LocalLayerIndex := Low(LayerCounts) to High(LayerCounts) do
    begin
      SetLength(LayerPositions[LocalLayerIndex], LayerCounts[LocalLayerIndex]);
      if LayerCounts[LocalLayerIndex] <= 0 then
        Continue;

      Y := MarginY + (ContentHeight * LocalLayerIndex / 4);
      if LayerCounts[LocalLayerIndex] = 1 then
        StepX := 0
      else
        StepX := ContentWidth / (LayerCounts[LocalLayerIndex] - 1);

      for LocalNodeIndex := 0 to LayerCounts[LocalLayerIndex] - 1 do
      begin
        if LayerCounts[LocalLayerIndex] = 1 then
          X := GraphRect.Width / 2
        else
          X := MarginX + (StepX * LocalNodeIndex);
        LayerPositions[LocalLayerIndex][LocalNodeIndex] := TPointF.Create(X, Y);
      end;
    end;
  end;

  function CalculateLayerThreshold(const AStartWeightIndex, AInputLayerIndex,
    AOutputLayerIndex: Integer): Double;
  var
    LocalAbsWeightIndex: Integer;
    LocalWeightIndex: Integer;
    InputIndex: Integer;
    OutputIndex: Integer;
    TopCount: Integer;
  begin
    SetLength(AbsWeights, LayerCounts[AInputLayerIndex] *
      LayerCounts[AOutputLayerIndex]);
    LocalAbsWeightIndex := 0;
    LocalWeightIndex := AStartWeightIndex;

    for OutputIndex := 0 to LayerCounts[AOutputLayerIndex] - 1 do
    begin
      for InputIndex := 0 to LayerCounts[AInputLayerIndex] - 1 do
      begin
        AbsWeights[LocalAbsWeightIndex] :=
          Abs(FSelectedNNWeights[LocalWeightIndex]);
        Inc(LocalAbsWeightIndex);
        Inc(LocalWeightIndex);
      end;
      Inc(LocalWeightIndex);
    end;

    TArray.Sort<Double>(AbsWeights, TComparer<Double>.Construct(
      function(const Left, Right: Double): Integer
      begin
        Result := CompareValue(Right, Left);
      end));

    TopCount := EnsureRange(Ceil(Length(AbsWeights) * 0.05), 1,
      Length(AbsWeights));
    Result := AbsWeights[TopCount - 1];
  end;

  procedure DrawLayerWeights(const AInputLayerIndex,
    AOutputLayerIndex: Integer);
  var
    InputIndex: Integer;
    OutputIndex: Integer;
    WeightValue: Double;
    AbsWeightValue: Double;
  begin
    for OutputIndex := 0 to LayerCounts[AOutputLayerIndex] - 1 do
    begin
      for InputIndex := 0 to LayerCounts[AInputLayerIndex] - 1 do
      begin
        WeightValue := FSelectedNNWeights[WeightIndex];
        AbsWeightValue := Abs(WeightValue);
        if AbsWeightValue >= Threshold then
        begin
          Canvas.Stroke.Kind := TBrushKind.Solid;
          if WeightValue >= 0 then
            Canvas.Stroke.Color := $CC2E7D32
          else
            Canvas.Stroke.Color := $CCB32626;
          Canvas.Stroke.Thickness := EnsureRange(0.2 + (AbsWeightValue * 1.5),
            0.2, 0.9);
          Canvas.DrawLine(LayerPositions[AInputLayerIndex][InputIndex],
            LayerPositions[AOutputLayerIndex][OutputIndex], 1);
        end;
        Inc(WeightIndex);
      end;
      Inc(WeightIndex);
    end;
  end;

  procedure DrawInputLabels;
  const
    SelfInputCount = 5;
    DirectionLabels: array[0..7] of string = (
      'North', 'NE', 'East', 'SE', 'South', 'SW', 'West', 'NW');
  var
    DirectionIndex: Integer;
    FirstInput: Integer;
    LastInput: Integer;
    MemoryInputCount: Integer;
    LabelCenterX: Single;
    LabelRect: TRectF;

    procedure DrawLabelForRange(const AFirstInput, ALastInput: Integer;
      const ALabel: string);
    begin
      if (AFirstInput < 0) or (ALastInput >= Length(LayerPositions[0])) or
        (AFirstInput > ALastInput) then
        Exit;

      LabelCenterX := (LayerPositions[0][AFirstInput].X +
        LayerPositions[0][ALastInput].X) / 2;
      LabelRect := TRectF.Create(LabelCenterX - 34, 4, LabelCenterX + 34,
        MarginY - NodeRadius - 4);
      Canvas.FillText(LabelRect, ALabel, False, 1, [], TTextAlign.Center,
        TTextAlign.Trailing);
    end;

  begin
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := $FF333333;
    Canvas.Font.Size := 10;
    Canvas.Font.Style := [];

    DrawLabelForRange(0, Min(SelfInputCount - 1, LayerCounts[0] - 1), 'Self');
    MemoryInputCount := LayerCounts[0] - SelfInputCount;
    if MemoryInputCount <= 0 then
      Exit;

    for DirectionIndex := Low(DirectionLabels) to High(DirectionLabels) do
    begin
      FirstInput := SelfInputCount + Floor(MemoryInputCount *
        DirectionIndex / Length(DirectionLabels));
      LastInput := SelfInputCount + Floor(MemoryInputCount *
        (DirectionIndex + 1) / Length(DirectionLabels)) - 1;
      DrawLabelForRange(FirstInput, LastInput, DirectionLabels[DirectionIndex]);
    end;
  end;

  procedure DrawOutputLabels;
  const
    OutputLabels: array[0..12] of string = (
      'Eid', 'Ago', 'SuperAgo', 'Mate', 'V:Range', 'V:N', 'V:NE', 'V:E',
      'V:SE', 'V:S', 'V:SW', 'V:W', 'V:NW');
  var
    OutputIndex: Integer;
    LabelRect: TRectF;
  begin
    Canvas.Fill.Kind := TBrushKind.Solid;
    Canvas.Fill.Color := $FF333333;
    Canvas.Font.Size := 8;
    Canvas.Font.Style := [];
    for OutputIndex := Low(OutputLabels) to High(OutputLabels) do
      if OutputIndex < Length(LayerPositions[4]) then
      begin
        LabelRect := TRectF.Create(
          LayerPositions[4][OutputIndex].X - 34,
          LayerPositions[4][OutputIndex].Y + OutputNodeRadius + 8,
          LayerPositions[4][OutputIndex].X + 34,
          LayerPositions[4][OutputIndex].Y + OutputNodeRadius + 38);
        Canvas.FillText(LabelRect, OutputLabels[OutputIndex],
          False, 1, [], TTextAlign.Center, TTextAlign.Leading);
      end;
  end;

begin
  GraphRect := PaintBoxNNGraphView.LocalRect;
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := TAlphaColors.White;
  Canvas.FillRect(GraphRect, 0, 0, [], 1);

  if (not FHasSelectedNNGraph) or (Length(FSelectedNNWeights) = 0) then
  begin
    ClearNodePositions;
    Canvas.Fill.Color := $FF555555;
    Canvas.FillText(GraphRect, 'Click a monkey in the world to view its NN.',
      False, 1, [], TTextAlign.Center, TTextAlign.Center);
    Exit;
  end;

  LayerCounts[0] := FSelectedNNConfig.InputCount;
  LayerCounts[1] := FSelectedNNConfig.Hidden1Count;
  LayerCounts[2] := FSelectedNNConfig.Hidden2Count;
  LayerCounts[3] := FSelectedNNConfig.Hidden3Count;
  LayerCounts[4] := FSelectedNNConfig.OutputCount;

  MaxLayerCount := 1;
  for LayerIndex := Low(LayerCounts) to High(LayerCounts) do
    MaxLayerCount := Max(MaxLayerCount, LayerCounts[LayerIndex]);

  MarginX := 40;
  MarginY := 56;
  ContentWidth := Max(1, GraphRect.Width - (MarginX * 2));
  ContentHeight := Max(1, GraphRect.Height - MarginY - 48);
  NodeRadius := EnsureRange((ContentWidth / MaxLayerCount) * 0.3, 2, 7);
  OutputNodeRadius := Max(NodeRadius * 3, 12);

  BuildLayerPositions;
  SetLength(FNNInputNodePositions, Length(LayerPositions[0]));
  for InputNodeIndex := Low(LayerPositions[0]) to High(LayerPositions[0]) do
    FNNInputNodePositions[InputNodeIndex] := LayerPositions[0][InputNodeIndex];
  SetLength(FNNOutputNodePositions, Length(LayerPositions[4]));
  for InputNodeIndex := Low(LayerPositions[4]) to High(LayerPositions[4]) do
    FNNOutputNodePositions[InputNodeIndex] := LayerPositions[4][InputNodeIndex];
  FNNInputNodeRadius := NodeRadius;
  FNNOutputNodeRadius := OutputNodeRadius;

  WeightIndex := 0;
  Threshold := CalculateLayerThreshold(WeightIndex, 0, 1);
  DrawLayerWeights(0, 1);
  Threshold := CalculateLayerThreshold(WeightIndex, 1, 2);
  DrawLayerWeights(1, 2);
  Threshold := CalculateLayerThreshold(WeightIndex, 2, 3);
  DrawLayerWeights(2, 3);
  Threshold := CalculateLayerThreshold(WeightIndex, 3, 4);
  DrawLayerWeights(3, 4);

  Canvas.Stroke.Color := TAlphaColors.Black;
  Canvas.Stroke.Thickness := 1;
  for LayerIndex := Low(LayerCounts) to High(LayerCounts) do
  begin
    for NodeIndex := 0 to LayerCounts[LayerIndex] - 1 do
    begin
      Canvas.Fill.Color := LayerColor(LayerIndex);
      if (LayerIndex = 4) and
        (((NodeIndex >= 0) and (NodeIndex <= 2) and
        (NodeIndex = WinningOutputIndex(0, 3))) or
        ((NodeIndex >= 5) and (NodeIndex <= 12) and
        (NodeIndex = WinningOutputIndex(5, 8) + 5))) then
        Canvas.Fill.Color := TAlphaColors.Black;

      if LayerIndex = 4 then
      begin
        Canvas.FillEllipse(TRectF.Create(
          LayerPositions[LayerIndex][NodeIndex].X - OutputNodeRadius,
          LayerPositions[LayerIndex][NodeIndex].Y - OutputNodeRadius,
          LayerPositions[LayerIndex][NodeIndex].X + OutputNodeRadius,
          LayerPositions[LayerIndex][NodeIndex].Y + OutputNodeRadius), 1);
        Canvas.DrawEllipse(TRectF.Create(
          LayerPositions[LayerIndex][NodeIndex].X - OutputNodeRadius,
          LayerPositions[LayerIndex][NodeIndex].Y - OutputNodeRadius,
          LayerPositions[LayerIndex][NodeIndex].X + OutputNodeRadius,
          LayerPositions[LayerIndex][NodeIndex].Y + OutputNodeRadius), 1);
      end
      else
        Canvas.FillEllipse(TRectF.Create(
          LayerPositions[LayerIndex][NodeIndex].X - NodeRadius,
          LayerPositions[LayerIndex][NodeIndex].Y - NodeRadius,
          LayerPositions[LayerIndex][NodeIndex].X + NodeRadius,
          LayerPositions[LayerIndex][NodeIndex].Y + NodeRadius), 1);
    end;
  end;

  DrawInputLabels;
  DrawOutputLabels;
end;

constructor TNeuralNetFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  CreateNNGraphInfoText;
  CreateNNInputHoverBox;
  ClearMonkeyBrain;
end;

procedure TNeuralNetFrame.HideNNInputHoverBox;
begin
  if FNNInputHoverBox <> nil then
    FNNInputHoverBox.Visible := False;
end;

function TNeuralNetFrame.MonkeySexToText(const ASex: TMonkeySex): string;
begin
  case ASex of
    msMale: Result := 'Male';
    msFemale: Result := 'Female';
  else
    Result := 'Unknown';
  end;
end;

function TNeuralNetFrame.NNInputDescription(
  const AInputIndex: Integer): string;
const
  SelfInputCount = 5;
  DirectionLabels: array[0..7] of string = (
    'North', 'NE', 'East', 'SE', 'South', 'SW', 'West', 'NW');
var
  MemoryInputIndex: Integer;
  MemorySlotIndex: Integer;
  MemorySlotCount: Integer;
  DirectionIndex: Integer;
  ComponentText: string;
begin
  case AInputIndex of
    0: Exit('Self: age / lifespan');
    1: Exit('Self: sex (female=1, male=0)');
    2: Exit('Self: strength');
    3: Exit('Self: total strength');
    4: Exit('Self: pregnant (yes=1, no=0)');
  end;

  MemoryInputIndex := AInputIndex - SelfInputCount;
  if MemoryInputIndex < 0 then
    Exit('Unknown input');

  MemorySlotIndex := MemoryInputIndex div 2;
  MemorySlotCount := Max(1, (Length(FSelectedNNInputs) - SelfInputCount) div 2);
  DirectionIndex := EnsureRange(Floor(MemorySlotIndex *
    Length(DirectionLabels) / MemorySlotCount), Low(DirectionLabels),
    High(DirectionLabels));

  if Odd(MemoryInputIndex) then
    ComponentText := 'cell state / strength'
  else
    ComponentText := 'seen monkey sex';

  Result := Format('%s memory slot %d: %s',
    [DirectionLabels[DirectionIndex], MemorySlotIndex + 1, ComponentText]);
end;

procedure TNeuralNetFrame.PaintBoxNNGraphViewMouseLeave(Sender: TObject);
begin
  HideNNInputHoverBox;
end;

procedure TNeuralNetFrame.PaintBoxNNGraphViewMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Single);
var
  InputIndex: Integer;
  OutputIndex: Integer;
begin
  if TryGetNNInputAt(X, Y, InputIndex) then
    ShowNNInputHoverBox(InputIndex)
  else if TryGetNNOutputAt(X, Y, OutputIndex) then
    ShowNNInputHoverBox(-(OutputIndex + 1))
  else
    HideNNInputHoverBox;
end;

procedure TNeuralNetFrame.PaintBoxNNGraphViewPaint(Sender: TObject;
  Canvas: TCanvas);
begin
  DrawNNGraph(Canvas);
end;

procedure TNeuralNetFrame.ShowMonkeyBrain(const ATraits: TMonkeyTraitSnapshot;
  const AConfig: TNeuralNetConfig; const AWeights: TNeuralNetWeights;
  const AInputs: TMonkeyNNInputs; const AOutputs: TNeuralNetOutputs);
begin
  FHasSelectedNNGraph := True;
  FSelectedMonkeyTraits := ATraits;
  FSelectedNNConfig := AConfig;
  FSelectedNNWeights := Copy(AWeights);
  FSelectedNNInputs := Copy(AInputs);
  FSelectedNNOutputs := Copy(AOutputs);
  UpdateNNGraphInfoText;
  UpdateMemoJson;
  ActivateGraphView;
  PaintBoxNNGraphView.Repaint;
end;

procedure TNeuralNetFrame.ShowNNInputHoverBox(const AInputIndex: Integer);
var
  OutputIndex: Integer;
  WinnerIndex: Integer;
  DirectionValue: Integer;
  PopupPoint: TPointF;
begin
  if (FNNInputHoverBox = nil) or (FNNInputHoverText = nil) then
    Exit;

  if FNNInputHoverBox.Parent <> PaintBoxNNGraphView then
    FNNInputHoverBox.Parent := PaintBoxNNGraphView;

  if AInputIndex >= 0 then
  begin
    if AInputIndex >= Length(FSelectedNNInputs) then
      Exit;

    FNNInputHoverText.Text :=
      NNInputDescription(AInputIndex) + sLineBreak +
      Format('Input index: %d', [AInputIndex]) + sLineBreak +
      Format('Value: %.5f', [FSelectedNNInputs[AInputIndex]]);
  end
  else
  begin
    OutputIndex := -(AInputIndex + 1);
    if (OutputIndex < 0) or (OutputIndex >= Length(FSelectedNNOutputs)) then
      Exit;

    if (OutputIndex >= 0) and (OutputIndex <= 2) then
    begin
      WinnerIndex := WinningOutputIndex(0, 3);
      FNNInputHoverText.Text :=
        Format('Output: strategy %d', [OutputIndex]) + sLineBreak +
        Format('Winner strategy index: %d', [WinnerIndex]);
    end
    else if OutputIndex = 3 then
    begin
      if FSelectedNNOutputs[OutputIndex] >= 0.5 then
        FNNInputHoverText.Text := 'Output: mate yes/no' + sLineBreak +
          'Decoded: yes'
      else
        FNNInputHoverText.Text := 'Output: mate yes/no' + sLineBreak +
          'Decoded: no';
    end
    else if OutputIndex = 4 then
    begin
      if FSelectedNNOutputs[OutputIndex] >= 0.5 then
        FNNInputHoverText.Text := 'Output: vision far/near' + sLineBreak +
          'Decoded: far'
      else
        FNNInputHoverText.Text := 'Output: vision far/near' + sLineBreak +
          'Decoded: near';
    end
    else if (OutputIndex >= 5) and (OutputIndex <= 12) then
    begin
      WinnerIndex := WinningOutputIndex(5, 8) + 5;
      DirectionValue := OutputIndex - 4;
      FNNInputHoverText.Text :=
        Format('Output: vision direction %d = %s', [DirectionValue,
        DirectionOptionText(DirectionValue)]) + sLineBreak +
        Format('Winner: %d = %s', [WinnerIndex - 4,
        DirectionOptionText(WinnerIndex - 4)]);
    end
    else
      FNNInputHoverText.Text := 'Output';

    FNNInputHoverText.Text := FNNInputHoverText.Text + sLineBreak +
      Format('Output index: %d', [OutputIndex]) + sLineBreak +
      Format('Value: %.5f', [FSelectedNNOutputs[OutputIndex]]);
  end;

  PopupPoint := TPointF.Create(
    (PaintBoxNNGraphView.Width - FNNInputHoverBox.Width) / 2,
    Max(220, PaintBoxNNGraphView.Height / 2));

  if PopupPoint.X + FNNInputHoverBox.Width > PaintBoxNNGraphView.Width - 8 then
    PopupPoint.X := PaintBoxNNGraphView.Width - FNNInputHoverBox.Width - 8;
  if PopupPoint.Y + FNNInputHoverBox.Height > PaintBoxNNGraphView.Height - 8 then
    PopupPoint.Y := PaintBoxNNGraphView.Height - FNNInputHoverBox.Height - 8;
  PopupPoint.X := Max(8, PopupPoint.X);
  PopupPoint.Y := Max(8, PopupPoint.Y);

  FNNInputHoverBox.Position.X := PopupPoint.X;
  FNNInputHoverBox.Position.Y := PopupPoint.Y;
  FNNInputHoverBox.BringToFront;
  FNNInputHoverBox.Visible := True;
end;

function TNeuralNetFrame.TryGetNNInputAt(const AX, AY: Single;
  out AInputIndex: Integer): Boolean;
var
  I: Integer;
  HitRadius: Single;
begin
  Result := False;
  AInputIndex := -1;
  if not FHasSelectedNNGraph then
    Exit;

  HitRadius := Max(FNNOutputNodeRadius + 4, 7);
  for I := Low(FNNInputNodePositions) to High(FNNInputNodePositions) do
    if (Sqr(AX - FNNInputNodePositions[I].X) +
      Sqr(AY - FNNInputNodePositions[I].Y)) <= Sqr(HitRadius) then
    begin
      AInputIndex := I;
      Exit(I < Length(FSelectedNNInputs));
    end;
end;

function TNeuralNetFrame.TryGetNNOutputAt(const AX, AY: Single;
  out AOutputIndex: Integer): Boolean;
var
  I: Integer;
  HitRadius: Single;
begin
  Result := False;
  AOutputIndex := -1;
  if not FHasSelectedNNGraph then
    Exit;

  HitRadius := Max(FNNInputNodeRadius + 4, 7);
  for I := Low(FNNOutputNodePositions) to High(FNNOutputNodePositions) do
    if (Sqr(AX - FNNOutputNodePositions[I].X) +
      Sqr(AY - FNNOutputNodePositions[I].Y)) <= Sqr(HitRadius) then
    begin
      AOutputIndex := I;
      Exit(I < Length(FSelectedNNOutputs));
    end;
end;

procedure TNeuralNetFrame.UpdateMemoJson;
begin
  if FHasSelectedNNGraph then
    MemoJson.Text := TNeuralNet.WeightsToJson(FSelectedNNConfig,
      FSelectedNNWeights)
  else
    MemoJson.Text := '';
end;

procedure TNeuralNetFrame.UpdateNNGraphInfoText;
begin
  if FNNGraphInfoText = nil then
    Exit;

  if FHasSelectedNNGraph then
    FNNGraphInfoText.Text :=
      'Selected monkey' + sLineBreak +
      Format('Id: %d', [FSelectedMonkeyTraits.Id]) + sLineBreak +
      'Sex: ' + MonkeySexToText(FSelectedMonkeyTraits.Sex) + sLineBreak +
      Format('Age: %d', [FSelectedMonkeyTraits.Age]) + sLineBreak +
      Format('Total strength: %.2f',
        [FSelectedMonkeyTraits.TotalStrength]) + sLineBreak + sLineBreak +
      'Lines' + sLineBreak +
      'Green: positive weight' + sLineBreak +
      'Red: negative weight' + sLineBreak +
      'Thickness: weight strength' + sLineBreak +
      'Black output: winner' + sLineBreak +
      'Strongest 5% per layer'
  else
    FNNGraphInfoText.Text :=
      'Selected monkey' + sLineBreak +
      'None' + sLineBreak + sLineBreak +
      'Lines' + sLineBreak +
      'Green: positive weight' + sLineBreak +
      'Red: negative weight' + sLineBreak +
      'Thickness: weight strength' + sLineBreak +
      'Black output: winner' + sLineBreak +
      'Strongest 5% per layer';
end;

function TNeuralNetFrame.WinningOutputIndex(const AStartIndex,
  ACount: Integer): Integer;
var
  I: Integer;
  WinnerValue: Double;
begin
  Result := 0;
  if (ACount <= 0) or (AStartIndex < 0) or
    (AStartIndex + ACount > Length(FSelectedNNOutputs)) then
    Exit;

  WinnerValue := FSelectedNNOutputs[AStartIndex];
  for I := 1 to ACount - 1 do
    if FSelectedNNOutputs[AStartIndex + I] > WinnerValue then
    begin
      Result := I;
      WinnerValue := FSelectedNNOutputs[AStartIndex + I];
    end;
end;

end.
