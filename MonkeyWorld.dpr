program MonkeyWorld;

uses
  System.StartUpCopy,
  FMX.Forms,
  UMonkeysForm in 'UMonkeysForm.pas' {TabbedForm},
  UWorld in 'UWorld.pas',
  UMonkey in 'UMonkey.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TTabbedForm, TabbedForm);
  Application.Run;
end.
