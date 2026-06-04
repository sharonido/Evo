unit UMonkeysForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.TabControl,
  FMX.StdCtrls, FMX.Gestures, FMX.Controls.Presentation, FMX.Layouts, FMX.Edit,
  FMX.EditBox, FMX.NumberBox, FMX.Objects;

type
  TTabbedForm = class(TForm)
    TabControl: TTabControl;
    WorldTab: TTabItem;
    ConTab: TTabItem;
    NNTab: TTabItem;
    GroupBox1: TGroupBox;
    ScrollBox1: TScrollBox;
    Button1: TButton;
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
    procedure PWorldBoardPaint(Sender: TObject; Canvas: TCanvas);
  private
    { Private declarations }
    FBoardSizeX: Integer;
    FBoardSizeY: Integer;
    FCellSize: Single;
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
  RestartBoard;
end;

procedure TTabbedForm.PWorldBoardPaint(Sender: TObject; Canvas: TCanvas);
var
  X: Integer;
  Y: Integer;
  CellRect: TRectF;
begin
  Canvas.Fill.Color := TAlphaColors.White;
  Canvas.FillRect(PWorldBoard.LocalRect, 0, 0, [], 1);

  for Y := 0 to FBoardSizeY - 1 do
    for X := 0 to FBoardSizeX - 1 do
    begin
      if Odd(X + Y) then
        Canvas.Fill.Color := TAlphaColors.Lightgray
      else
        Canvas.Fill.Color := TAlphaColors.White;

      CellRect := TRectF.Create(
        X * FCellSize,
        Y * FCellSize,
        (X + 1) * FCellSize,
        (Y + 1) * FCellSize);
      Canvas.FillRect(CellRect, 0, 0, [], 1);
    end;
end;

procedure TTabbedForm.RestartBoard;
begin
  FBoardSizeX := Round(NSizeX.Value);
  FBoardSizeY := Round(NSizeY.Value);
  FCellSize := 16;

  if FBoardSizeX < 1 then
    FBoardSizeX := 1;
  if FBoardSizeY < 1 then
    FBoardSizeY := 1;

  //PWorldBoard.Align := TAlignLayout.None;
  PWorldBoard.Position.X := 0;
  PWorldBoard.Position.Y := 0;
  PWorldBoard.Width := FBoardSizeX * FCellSize;
  PWorldBoard.Height := FBoardSizeY * FCellSize;
  PWorldBoard.Repaint;
end;

end.
