program MonkeyWorld;

uses
  System.StartUpCopy,
  FMX.Forms,
  UMonkeysForm in 'UMonkeysForm.pas' {TabbedForm},
  UBaseMonkey in 'UBaseMonkey.pas',
  UBaseWorld in 'UBaseWorld.pas',
  UWorld in 'UWorld.pas',
  UMonkey in 'UMonkey.pas',
  UNeuralNet in 'UNeuralNet.pas',
  UNeuralNetFrame in 'UNeuralNetFrame.pas' {NeuralNetFrame: TFrame},
  UAverageAgeGraphForm in 'UAverageAgeGraphForm.pas' {AverageAgeGraphForm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TTabbedForm, TabbedForm);
  Application.Run;
end.
