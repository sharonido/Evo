unit UAverageAgeGraphForm;

interface

uses
  System.Classes, System.SysUtils, System.UITypes, FMX.Forms, FMX.Types,
  FMXTee.Chart,
  FMXTee.Engine, FMXTee.Series;

type
  TAverageAgeSample = record
    Step: Int64;
    AverageAge: Double;
    MaxAge: Integer;
  end;

  TAverageAgeSamples = array of TAverageAgeSample;

  TAverageAgeGraphForm = class(TForm)
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
  private
    FAgeChart: TChart;
    FAverageAgeSeries: TLineSeries;
    FMaxAgeSeries: TLineSeries;
  public
    procedure LoadSamples(const ASamples: TAverageAgeSamples);
  end;

implementation

{$R *.fmx}

procedure TAverageAgeGraphForm.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  Action := TCloseAction.caHide;
end;

procedure TAverageAgeGraphForm.FormCreate(Sender: TObject);
begin
  OnClose := FormClose;
  Caption := 'Average Monkey Age';
  Width := 900;
  Height := 600;

  FAgeChart := TChart.Create(Self);
  FAgeChart.Parent := Self;
  FAgeChart.Align := TAlignLayout.Client;
  FAgeChart.Title.Text.Clear;
  FAgeChart.Title.Text.Add('Monkey Age by Step');
  FAgeChart.Legend.Visible := True;
  FAgeChart.BottomAxis.Title.Caption := 'Steps';
  FAgeChart.LeftAxis.Title.Caption := 'Average age';
  FAgeChart.RightAxis.Title.Caption := 'Max age';
  FAgeChart.RightAxis.Visible := True;
  FAgeChart.View3D := False;

  FAverageAgeSeries := TLineSeries.Create(Self);
  FAverageAgeSeries.Title := 'Average age';
  FAverageAgeSeries.SeriesColor := TAlphaColors.Dodgerblue;
  FAgeChart.AddSeries(FAverageAgeSeries);

  FMaxAgeSeries := TLineSeries.Create(Self);
  FMaxAgeSeries.Title := 'Max age';
  FMaxAgeSeries.SeriesColor := TAlphaColors.Crimson;
  FMaxAgeSeries.VertAxis := aRightAxis;
  FAgeChart.AddSeries(FMaxAgeSeries);
end;

procedure TAverageAgeGraphForm.LoadSamples(
  const ASamples: TAverageAgeSamples);
var
  I: Integer;
begin
  FAverageAgeSeries.Clear;
  FMaxAgeSeries.Clear;
  for I := Low(ASamples) to High(ASamples) do
  begin
    FAverageAgeSeries.AddXY(ASamples[I].Step, ASamples[I].AverageAge);
    FMaxAgeSeries.AddXY(ASamples[I].Step, ASamples[I].MaxAge);
  end;
end;

end.
