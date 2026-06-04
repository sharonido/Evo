program MonkeyWorld;

uses
  System.StartUpCopy,
  FMX.Forms,
  UMonkeysForm in 'UMonkeysForm.pas' {TabbedForm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TTabbedForm, TabbedForm);
  Application.Run;
end.
