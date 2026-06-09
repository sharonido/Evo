unit UNeuralNet;

interface

type
  TNeuralNetConfig = record
    InputCount: Integer;
    Hidden1Count: Integer;
    Hidden2Count: Integer;
    Hidden3Count: Integer;
    OutputCount: Integer;
  end;

  TNeuralNetWeights = array of Double;
  TNeuralNetOutputs = array of Double;

  TNeuralNet = class
  private
    class function FormatJsonWeight(const AValue: Double): string; static;
    class function LayerWeightCount(const AInputCount,
      AOutputCount: Integer): Integer; static;
    class function RandomGaussian: Double; static;
    class procedure CheckConfig(const AConfig: TNeuralNetConfig); static;
    class procedure EvaluateLayer(const AInputs: TNeuralNetOutputs;
      const AOutputCount: Integer; const AWeights: TNeuralNetWeights;
      var AWeightIndex: Integer; const AUseSigmoid: Boolean;
      out AOutputs: TNeuralNetOutputs); static;
    class procedure FillRandomLayerWeights(var AWeights: TNeuralNetWeights;
      var AWeightIndex: Integer; const AInputCount,
      AOutputCount: Integer); static;
    class function Sigmoid(const AValue: Double): Double; static;
  public
    class function WeightCount(const AConfig: TNeuralNetConfig): Integer; static;
    class function CreateRandomWeights(
      const AConfig: TNeuralNetConfig): TNeuralNetWeights; static;
    class function CreateChildWeights(const AConfig: TNeuralNetConfig;
      const AMotherWeights, AFatherWeights: TNeuralNetWeights;
      const AMutationSigma: Double): TNeuralNetWeights; static;
    class function Evaluate(const AConfig: TNeuralNetConfig;
      const AWeights: TNeuralNetWeights;
      const AInputs: TNeuralNetOutputs): TNeuralNetOutputs; static;
    class function WeightsFromJson(const AConfig: TNeuralNetConfig;
      const AJson: string): TNeuralNetWeights; static;
    class function WeightsToJson(const AConfig: TNeuralNetConfig;
      const AWeights: TNeuralNetWeights): string; static;
  end;

implementation

uses
  System.Generics.Collections, System.JSON, System.Math, System.SysUtils;

{ TNeuralNet }

class procedure TNeuralNet.CheckConfig(const AConfig: TNeuralNetConfig);
begin
  if AConfig.InputCount <= 0 then
    raise EArgumentException.Create('Neural net input count must be positive.');
  if AConfig.Hidden1Count <= 0 then
    raise EArgumentException.Create('Neural net hidden layer 1 count must be positive.');
  if AConfig.Hidden2Count <= 0 then
    raise EArgumentException.Create('Neural net hidden layer 2 count must be positive.');
  if AConfig.Hidden3Count <= 0 then
    raise EArgumentException.Create('Neural net hidden layer 3 count must be positive.');
  if AConfig.OutputCount <= 0 then
    raise EArgumentException.Create('Neural net output count must be positive.');
end;

class function TNeuralNet.CreateChildWeights(const AConfig: TNeuralNetConfig;
  const AMotherWeights, AFatherWeights: TNeuralNetWeights;
  const AMutationSigma: Double): TNeuralNetWeights;
var
  I: Integer;
  RequiredCount: Integer;
begin
  RequiredCount := WeightCount(AConfig);
  if Length(AMotherWeights) <> RequiredCount then
    raise EArgumentException.Create('Mother neural net weight count does not match config.');
  if Length(AFatherWeights) <> RequiredCount then
    raise EArgumentException.Create('Father neural net weight count does not match config.');

  SetLength(Result, RequiredCount);
  for I := 0 to RequiredCount - 1 do
  begin
    if Random(2) = 0 then
      Result[I] := AMotherWeights[I]
    else
      Result[I] := AFatherWeights[I];

    if AMutationSigma > 0 then
      Result[I] := Result[I] + (RandomGaussian * AMutationSigma);
  end;
end;

class function TNeuralNet.CreateRandomWeights(
  const AConfig: TNeuralNetConfig): TNeuralNetWeights;
var
  WeightIndex: Integer;
begin
  CheckConfig(AConfig);
  SetLength(Result, WeightCount(AConfig));

  WeightIndex := 0;
  FillRandomLayerWeights(Result, WeightIndex, AConfig.InputCount,
    AConfig.Hidden1Count);
  FillRandomLayerWeights(Result, WeightIndex, AConfig.Hidden1Count,
    AConfig.Hidden2Count);
  FillRandomLayerWeights(Result, WeightIndex, AConfig.Hidden2Count,
    AConfig.Hidden3Count);
  FillRandomLayerWeights(Result, WeightIndex, AConfig.Hidden3Count,
    AConfig.OutputCount);
end;

class function TNeuralNet.Evaluate(const AConfig: TNeuralNetConfig;
  const AWeights: TNeuralNetWeights;
  const AInputs: TNeuralNetOutputs): TNeuralNetOutputs;
var
  Hidden1: TNeuralNetOutputs;
  Hidden2: TNeuralNetOutputs;
  Hidden3: TNeuralNetOutputs;
  RequiredCount: Integer;
  WeightIndex: Integer;
begin
  CheckConfig(AConfig);
  RequiredCount := WeightCount(AConfig);
  if Length(AWeights) <> RequiredCount then
    raise EArgumentException.Create('Neural net weight count does not match config.');
  if Length(AInputs) <> AConfig.InputCount then
    raise EArgumentException.Create('Neural net input count does not match config.');

  WeightIndex := 0;
  EvaluateLayer(AInputs, AConfig.Hidden1Count, AWeights, WeightIndex, False,
    Hidden1);
  EvaluateLayer(Hidden1, AConfig.Hidden2Count, AWeights, WeightIndex, False,
    Hidden2);
  EvaluateLayer(Hidden2, AConfig.Hidden3Count, AWeights, WeightIndex, False,
    Hidden3);
  EvaluateLayer(Hidden3, AConfig.OutputCount, AWeights, WeightIndex, True,
    Result);
end;

class procedure TNeuralNet.EvaluateLayer(const AInputs: TNeuralNetOutputs;
  const AOutputCount: Integer; const AWeights: TNeuralNetWeights;
  var AWeightIndex: Integer; const AUseSigmoid: Boolean;
  out AOutputs: TNeuralNetOutputs);
var
  InputIndex: Integer;
  OutputIndex: Integer;
  Sum: Double;
begin
  SetLength(AOutputs, AOutputCount);
  for OutputIndex := 0 to AOutputCount - 1 do
  begin
    Sum := 0;
    for InputIndex := 0 to Length(AInputs) - 1 do
    begin
      Sum := Sum + (AInputs[InputIndex] * AWeights[AWeightIndex]);
      Inc(AWeightIndex);
    end;

    Sum := Sum + AWeights[AWeightIndex];
    Inc(AWeightIndex);

    if AUseSigmoid then
      AOutputs[OutputIndex] := Sigmoid(Sum)
    else
      AOutputs[OutputIndex] := Tanh(Sum);
  end;
end;

class procedure TNeuralNet.FillRandomLayerWeights(
  var AWeights: TNeuralNetWeights; var AWeightIndex: Integer;
  const AInputCount, AOutputCount: Integer);
var
  InputIndex: Integer;
  OutputIndex: Integer;
  Sigma: Double;
begin
  Sigma := Sqrt(1 / AInputCount);

  for OutputIndex := 0 to AOutputCount - 1 do
  begin
    for InputIndex := 0 to AInputCount - 1 do
    begin
      AWeights[AWeightIndex] := RandomGaussian * Sigma;
      Inc(AWeightIndex);
    end;

    AWeights[AWeightIndex] := 0;
    Inc(AWeightIndex);
  end;
end;

class function TNeuralNet.FormatJsonWeight(const AValue: Double): string;
var
  FormatSettings: TFormatSettings;
begin
  FormatSettings := TFormatSettings.Invariant;
  Result := FormatFloat('0.00000', AValue, FormatSettings);
end;

class function TNeuralNet.LayerWeightCount(const AInputCount,
  AOutputCount: Integer): Integer;
begin
  Result := AOutputCount * (AInputCount + 1);
end;

class function TNeuralNet.RandomGaussian: Double;
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

class function TNeuralNet.Sigmoid(const AValue: Double): Double;
begin
  Result := 1 / (1 + Exp(-AValue));
end;

class function TNeuralNet.WeightsFromJson(const AConfig: TNeuralNetConfig;
  const AJson: string): TNeuralNetWeights;
var
  RootValue: TJSONValue;
  RootObject: TJSONObject;
  LayersArray: TJSONArray;
  LayerObject: TJSONObject;
  RowsArray: TJSONArray;
  RowArray: TJSONArray;
  LayerIndex: Integer;
  OutputIndex: Integer;
  InputIndex: Integer;
  WeightIndex: Integer;
  LayerInputCounts: array[0..3] of Integer;
  LayerOutputCounts: array[0..3] of Integer;
begin
  CheckConfig(AConfig);
  SetLength(Result, WeightCount(AConfig));

  RootValue := TJSONObject.ParseJSONValue(AJson);
  try
    if not (RootValue is TJSONObject) then
      raise EArgumentException.Create('Neural net JSON root must be an object.');

    RootObject := TJSONObject(RootValue);
    LayersArray := RootObject.GetValue<TJSONArray>('layers');
    if (LayersArray = nil) or (LayersArray.Count <> 4) then
      raise EArgumentException.Create('Neural net JSON must contain four layers.');

    LayerInputCounts[0] := AConfig.InputCount;
    LayerInputCounts[1] := AConfig.Hidden1Count;
    LayerInputCounts[2] := AConfig.Hidden2Count;
    LayerInputCounts[3] := AConfig.Hidden3Count;
    LayerOutputCounts[0] := AConfig.Hidden1Count;
    LayerOutputCounts[1] := AConfig.Hidden2Count;
    LayerOutputCounts[2] := AConfig.Hidden3Count;
    LayerOutputCounts[3] := AConfig.OutputCount;

    WeightIndex := 0;
    for LayerIndex := Low(LayerInputCounts) to High(LayerInputCounts) do
    begin
      if not (LayersArray.Items[LayerIndex] is TJSONObject) then
        raise EArgumentException.Create('Neural net JSON layer must be an object.');

      LayerObject := TJSONObject(LayersArray.Items[LayerIndex]);
      RowsArray := LayerObject.GetValue<TJSONArray>('weights');
      if (RowsArray = nil) or (RowsArray.Count <> LayerOutputCounts[LayerIndex]) then
        raise EArgumentException.Create('Neural net JSON layer row count does not match config.');

      for OutputIndex := 0 to LayerOutputCounts[LayerIndex] - 1 do
      begin
        if not (RowsArray.Items[OutputIndex] is TJSONArray) then
          raise EArgumentException.Create('Neural net JSON weight row must be an array.');

        RowArray := TJSONArray(RowsArray.Items[OutputIndex]);
        if RowArray.Count <> LayerInputCounts[LayerIndex] + 1 then
          raise EArgumentException.Create('Neural net JSON weight row length does not match config.');

        for InputIndex := 0 to LayerInputCounts[LayerIndex] do
        begin
          Result[WeightIndex] := RowArray.Items[InputIndex].AsType<Double>;
          Inc(WeightIndex);
        end;
      end;
    end;
  finally
    RootValue.Free;
  end;
end;

class function TNeuralNet.WeightsToJson(const AConfig: TNeuralNetConfig;
  const AWeights: TNeuralNetWeights): string;
var
  Builder: TStringBuilder;
  LayerIndex: Integer;
  OutputIndex: Integer;
  InputIndex: Integer;
  WeightIndex: Integer;
  LayerInputCounts: array[0..3] of Integer;
  LayerOutputCounts: array[0..3] of Integer;
  LayerLabels: array[0..3] of string;
begin
  CheckConfig(AConfig);
  if Length(AWeights) <> WeightCount(AConfig) then
    raise EArgumentException.Create('Neural net weight count does not match config.');

  LayerInputCounts[0] := AConfig.InputCount;
  LayerInputCounts[1] := AConfig.Hidden1Count;
  LayerInputCounts[2] := AConfig.Hidden2Count;
  LayerInputCounts[3] := AConfig.Hidden3Count;
  LayerOutputCounts[0] := AConfig.Hidden1Count;
  LayerOutputCounts[1] := AConfig.Hidden2Count;
  LayerOutputCounts[2] := AConfig.Hidden3Count;
  LayerOutputCounts[3] := AConfig.OutputCount;
  LayerLabels[0] := 'input_to_hidden_1';
  LayerLabels[1] := 'hidden_1_to_hidden_2';
  LayerLabels[2] := 'hidden_2_to_hidden_3';
  LayerLabels[3] := 'hidden_3_to_output';

  Builder := TStringBuilder.Create;
  try
    Builder.AppendLine('{');
    Builder.AppendLine('  "layers": [');

    WeightIndex := 0;
    for LayerIndex := Low(LayerInputCounts) to High(LayerInputCounts) do
    begin
      Builder.AppendLine('    {');
      Builder.AppendFormat('      "label": "%s",', [LayerLabels[LayerIndex]]).AppendLine;
      Builder.AppendFormat('      "input_count": %d,', [LayerInputCounts[LayerIndex]]).AppendLine;
      Builder.AppendFormat('      "output_count": %d,', [LayerOutputCounts[LayerIndex]]).AppendLine;
      Builder.AppendLine('      "weights": [');

      for OutputIndex := 0 to LayerOutputCounts[LayerIndex] - 1 do
      begin
        Builder.Append('        [');
        for InputIndex := 0 to LayerInputCounts[LayerIndex] do
        begin
          if InputIndex > 0 then
            Builder.Append(', ');
          Builder.Append(FormatJsonWeight(AWeights[WeightIndex]));
          Inc(WeightIndex);
        end;
        Builder.Append(']');
        if OutputIndex < LayerOutputCounts[LayerIndex] - 1 then
          Builder.Append(',');
        Builder.AppendLine;
      end;

      Builder.AppendLine('      ]');
      Builder.Append('    }');
      if LayerIndex < High(LayerInputCounts) then
        Builder.Append(',');
      Builder.AppendLine;
    end;

    Builder.AppendLine('  ]');
    Builder.Append('}');
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TNeuralNet.WeightCount(
  const AConfig: TNeuralNetConfig): Integer;
begin
  CheckConfig(AConfig);
  Result :=
    LayerWeightCount(AConfig.InputCount, AConfig.Hidden1Count) +
    LayerWeightCount(AConfig.Hidden1Count, AConfig.Hidden2Count) +
    LayerWeightCount(AConfig.Hidden2Count, AConfig.Hidden3Count) +
    LayerWeightCount(AConfig.Hidden3Count, AConfig.OutputCount);
end;

end.
