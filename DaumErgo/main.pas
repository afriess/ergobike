unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  ExtCtrls, ActnList, Spin, LazSerial, LazSynaSer, MKnob, LedNumber;


const
  DevAdr =  #$01;
  Treten =  #$01;
  NTreten=  #$00;

type

  { TForm1 }

  TForm1 = class(TForm)
    ActionList: TActionList;
    BuConnect: TButton;
    BuDisconnect: TButton;
    BuTest: TButton;
    BUSpeedCalcTest: TButton;
    BuPowerCalcTest: TButton;
    EdGear1: TSpinEdit;
    ImageList: TImageList;
    LblGearH1: TLabel;
    lblRPMH: TLabel;
    lblRPMH1: TLabel;
    lblSlopeH: TLabel;
    lblWattH1: TLabel;
    LblWatt: TLabel;
    LblWattH: TLabel;
    LblSpeed: TLabel;
    LblSpeedH: TLabel;
    LblGearH: TLabel;
    LEDWatt: TLEDNumber;
    Memo: TMemo;
    MemoInfo1: TMemo;
    KnobWatt: TmKnob;
    PC: TPageControl;
    SerialFake: TLazSerial;
    EdGear: TSpinEdit;
    StatusBar1: TStatusBar;
    TBRPMTest: TTrackBar;
    TBSlopeTest: TTrackBar;
    TS_Tests: TTabSheet;
    ToolBar1: TToolBar;
    ToolButton1: TToolButton;
    TS_Serial: TTabSheet;
    TS_Msg: TTabSheet;
    TS_Ergo: TTabSheet;
    TBWatt: TTrackBar;
    TBRPM: TTrackBar;
    procedure BuConnectClick(Sender: TObject);
    procedure BuDisconnectClick(Sender: TObject);
    procedure BuPowerCalcTestClick(Sender: TObject);
    procedure BUSpeedCalcTestClick(Sender: TObject);
    procedure BuTestClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure PCChange(Sender: TObject);
    procedure SerialFakeRxData(Sender: TObject);
    procedure SerialFakeStatus(Sender: TObject; Reason: THookSerialReason;
      const Value: string);
    procedure TBRPMTestChange(Sender: TObject);
  private
    FInit : Boolean;
    function AnalyseTrames(Frame : string):boolean;

  public

  end;

var
  Form1: TForm1;

implementation
uses
  Math;

{$R *.lfm}
var
  FTempStr: String;
  CurPos: Integer;


{ TForm1 }

procedure DebugString(aMemo : TMemo; Str : string; Info:string  = '');
var
  Hstr : string;
  i: Integer;
begin
  Hstr := '';
  for i := 1 to length(Str) do begin
    Hstr := Hstr + ' ' +IntToHex(ord(Str[i]),2);
  end;
  aMemo.Append(Info + IntToStr(length(Str))+'<' + Hstr + '>');
end;

procedure TForm1.SerialFakeRxData(Sender: TObject);
var
  Str, Hstr : string;
  i: Integer;
begin
  Str :=  SerialFake.ReadData;
  FTempStr:= FTempStr + Str;
  DebugString(Memo,FTempStr);
  if not AnalyseTrames(FtempStr) then
    FTempStr:= '';
end;

procedure TForm1.BuConnectClick(Sender: TObject);
begin
  {$ifdef RasPi}
  SerialFake.Device:= '/dev/ttyUSB0';
  {$else}
  SerialFake.Device:= 'com3';
  {$endif}
  SerialFake.BaudRate:= br__9600;
  SerialFake.DataBits:= db8bits;
  SerialFake.StopBits:= sbOne;
  SerialFake.FlowControl:= fcNone;
  SerialFake.Open;
  Memo.Clear;
end;

procedure TForm1.BuDisconnectClick(Sender: TObject);
begin
  SerialFake.Close;
end;

procedure TForm1.BuPowerCalcTestClick(Sender: TObject);
Var
  afCD, afSin, afCDBike, afAFrame, afCATireV, afCATireH, afLoadV,
    afCCr, afCM,  hRider, M, MBik,
    T, Hn, cad, cCad, W, P, V,  cwaRider, aTireV, aTireH, vw,
    CwaBike, vw1, Ka, CrEff, CrV, CrH, Frg: Extended;
  Slope, adipos, CrDyn: ValReal;
  Slope10: integer;
begin
  Slope10 := TBSlopeTest.Position;    // 15 = 1.5 %
  cCad := 0.002; // fixwert ?!
  //
  afCD := 0.79;
  afSin := 0.85;
  afCDBike := 1.5;
  afAFrame := 0.052;
  afCATireV := 1.1;
  afCATireH := 0.9;
  afLoadV := 0.45;
  afCCr:= 1.0;
  afCM := 1.025;
  aTireV := 0.055;     // Tabelle Reifen
  aTireH := 0.055;     // Tabelle Reifen
  CrV     := 0.0046;    // Tabelle Reifen
  CrH := CrV;
  //
  hRider:=   1.72; // f.h   Größe Fahrer in m
  M     :=  71.3;  // f.M   Gewicht Fahrer in kg
  MBik  :=  12.0;  // f.mr  Gewicht Fahrrad in kg
  T     :=  20.0;  // f.T   Luft Temperatur in Grad Celisius
  Hn    := 350.0;  // f.Hn  Höhe über NN in m
  Slope := ArcTan((Slope10 * 0.1) * 0.01); // f.stg Steigung in Prozent
  W  := 0.0;       // f.W  Windgeschwindigkeit in km/h
  P  := 0.0;       // f.P  Leistung in W (<- wird gesucht !!)
  V := 0.0;
  TryStrToFloat(LblSpeed.caption,V); // f.V  Geschwindigeit
  V := V * 0.27778;
  cad := 50.0; // Cadence - Trittfrequenz pro / min
  //
  adipos := Sqrt(M/(hRider * 750));
  CrDyn := 0.1 * cos(Slope);

  CwaBike := afCDBike * (afCATireV * ATireV + afCATireH * ATireH + afAFrame);

  CrEff := afLoadV * afCCr * CrV + (1.0 -afLoadV) * CrH;
  Frg := 9.81 * (Mbik + M) * (CrEff * cos(Slope) + sin(slope));
  //
  vw := V+W;
  vw1 := vw;
  cwaRider := ( 1 + cad * cCad) * afCD * adipos * ((( hRider - adipos) * afSin) + adipos);
  Ka := 176.5 * exp(-Hn * 0.0001253) * (cwaRider + CwaBike) / (273 + T);
  //

  P := afCM * V * (Ka * (vw * vw1) + Frg + V * CrDyn);;
  LblWatt.Caption:= FloatToStr(P);
end;

procedure TForm1.BUSpeedCalcTestClick(Sender: TObject);
var
  Ratio,DistCm : Single;
  Gear : Integer;
begin
  Gear := EdGear.Value;
  Ratio := 1.75 + ( Gear - 1) * 0.098767;
  DistCm:= Ratio * 210.0;
  LblSpeed.caption := FloatToStr(TBRPMTest.Position * DistCm * 0.0006);
end;

procedure TForm1.BuTestClick(Sender: TObject);
var
  SendData : string;
begin
  SendData:= '123'+#$11+DevAdr;
  DebugString(Memo,SendData,'Test-');
  SerialFake.WriteData(SendData);
end;

procedure TForm1.FormActivate(Sender: TObject);
begin
  if not FInit then begin
    BuConnectClick(nil);
    FInit:= true;
  end;
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin

end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  FInit := false;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  BuDisconnectClick(nil);
end;

procedure TForm1.PCChange(Sender: TObject);
begin

end;

procedure TForm1.SerialFakeStatus(Sender: TObject; Reason: THookSerialReason;
  const Value: string);
begin
  case Reason of
    HR_SerialClose : StatusBar1.SimpleText := 'Port ' + Value + ' closed';
    HR_Connect :   StatusBar1.SimpleText := 'Port ' + Value + ' connected';
    HR_CanRead :   StatusBar1.SimpleText := 'CanRead : ' + Value ;
    HR_CanWrite :  StatusBar1.SimpleText := 'CanWrite : ' + Value ;
    HR_ReadCount : StatusBar1.SimpleText := 'ReadCount : ' + Value ;
    HR_WriteCount : StatusBar1.SimpleText := 'WriteCount : ' + Value ;
    HR_Wait :  StatusBar1.SimpleText := 'Wait : ' + Value ;
  end ;

end;

procedure TForm1.TBRPMTestChange(Sender: TObject);
begin

end;

function TForm1.AnalyseTrames(Frame: string): boolean;
var
  CurPos : integer;
  Temp : char;
  SendData : string;
  Watt,RPM,Tret, spd : integer;
begin
  Result := false;
  // Daum defintion
  //  $12 $adr   : Reset Dev          -> $12 $pedalstate
  //  $10 $adr   : Check Cockpit      -> $10 $adr
  //  $11 $dummy : Get Adress         -> $11 $adr
  //  $73 $adr   : Get Dev Version    -> $73 $adr $version
  //  $23 $adr   : Set Prg            -> $23 $?? $?? $pedalstate
  //  $21 $adr   : Start Prg          -> $21 $?? $pedalstate
  //  $22 $adr   : Stop Prg           -> $22 $?? $pedalstate
  //  unvollständig
  //  $64        : Set date
  //  $62        : SetTime
  //  $d3        ; Play Sound
  if length(frame) = 0 then
    exit; //==>> nichts zu tun
  if (ord(Frame[1]) = $12) then begin
    // Reset
    Memo.Append('Reset Dev Req');
    if length(frame) < 2 then
      result := true           // weitere zeichen anfordern
    else begin
      Memo.Append('');
      FTempStr := '';
      SendData:= #$12+DevAdr;
      DebugString(Memo,SendData,'Reset Dev Answ-');
      SerialFake.WriteData(SendData);
    end;
  end
  else if (ord(Frame[1]) = $11)then begin
    // Get Adress
    Memo.Append('Get Adress Req');
    //if length(frame) <= 1 then
    //  result := true           // weitere zeichen anfordern
    //else begin
      FTempStr := '';
      SendData:= #$11+DevAdr;
      //SendData:= #$47+#$11;
      DebugString(Memo,SendData,'Get Adress received Answ-');
      SerialFake.WriteData(SendData);
    //end;
  end
  else if (ord(Frame[1]) = $10) then begin
    // Check Cockpit
    Memo.Append('Check Cockpit Req');
    if length(frame) < 2 then
      result := true           // weitere zeichen anfordern
    else begin
      FTempStr := '';
      sleep(10);
      SendData:= #$10+DevAdr+#$99;
      DebugString(Memo,SendData,'Check Cockpit Answ-');
      SerialFake.WriteData(SendData);
    end;
  end
  else if (ord(Frame[1]) = $73) then begin
    // Check Cockpit
    Memo.Append('Get Version Req');
    if length(frame) < 2 then
      result := true           // weitere zeichen anfordern
    else begin
      FTempStr := '';
      sleep(10);
      SendData:= #$73+DevAdr+#$00+#$00+#$00+#$00+#$00+#$00+#$00+#$00+#$1E;
      DebugString(Memo,SendData,'Get Version Answ-');
      SerialFake.WriteData(SendData);
    end;
  end
  else if (ord(Frame[1]) = $23) then begin
    // Set Prog
    Memo.Append('Set Prog Req');
    if length(frame) < 3 then
      result := true           // weitere zeichen anfordern
    else begin
      Temp:= Frame[3];
      FTempStr := '';
      SendData:= #$23+DevAdr+Temp+NTreten;
      DebugString(Memo,SendData,'Set Prog Ans-');
      SerialFake.WriteData(SendData);
    end;
  end
  else if (ord(Frame[1]) = $21) then begin
    // Start Prog
    Memo.Append('Start Prog Req');
    if length(frame) < 2 then
      result := true           // weitere zeichen anfordern
    else begin
      FTempStr := '';
      SendData:= #$21+DevAdr+NTreten;
      DebugString(Memo,SendData,'Start Prog Answ-');
      SerialFake.WriteData(SendData);
    end;
  end
  else if (ord(Frame[1]) = $22)  then begin
    // Stop Prg
    Memo.Append('Stop Prg Req');
    if length(frame) < 2 then
      result := true           // weitere zeichen anfordern
    else begin
      FTempStr := '';
      SendData:= #$22+DevAdr+NTreten;
      DebugString(Memo,SendData,'Stop Prg Answ-');
      SerialFake.WriteData(SendData);
    end;
  end
  else if (ord(Frame[1]) = $62)  then begin
    // Set Date
    Memo.Append('Set Date Req');
    if length(frame) < 2 then
      result := true           // weitere zeichen anfordern
    else begin
      FTempStr := '';
      SendData:= #$62+DevAdr;
      DebugString(Memo,SendData,'Set Date Answ-');
      SerialFake.WriteData(SendData);
    end;
  end
  else if (ord(Frame[1]) = $51)  then begin
    // Set Power
    Memo.Append('Set Power Req');
    if length(frame) < 3 then
      result := true           // weitere zeichen anfordern
    else begin
      //TBWatt.Position :=
      KnobWatt.Position:= Ord(Frame[3]) * 5;
      LEDWatt.Caption:= IntToStr(KnobWatt.Position);
      FTempStr := '';
      SendData:= #$51+DevAdr+Frame[3];
      DebugString(Memo,SendData,'Set Power Answ-');
      SerialFake.WriteData(SendData);
    end;
  end
  else if (ord(Frame[1]) = $64)  then begin
    // Stop Prg
    Memo.Append('Set Time Req');
    if length(frame) < 2 then
      result := true           // weitere zeichen anfordern
    else begin
      FTempStr := '';
      SendData:= #$64+DevAdr;
      DebugString(Memo,SendData,'Set Time Answ-');
      SerialFake.WriteData(SendData);
    end;
  end
  else if (ord(Frame[1]) = $40)  then begin
    // Stop Prg
    Memo.Append('Query Run Data Req');
    if length(frame) < 2 then
      result := true           // weitere zeichen anfordern
    else begin
      FTempStr := '';
      //watt := TBWatt.Position div 5;
      watt := KnobWatt.Position div 5;
      RPM := TBRPM.Position;
      if (Watt < 5) then watt := 5;
      if (Watt > 80) then Watt := 80;
      if (RPM >= 5) then Tret:= 1
      else Tret:= 0;
      spd := round (RPM * ((1.75 + ( EdGear1.Value - 1) * 0.098767) * 210.0) * 0.0006);
      //                     PRG  PERS  Treten     Watt         RPM     spd     Dist   Tretzeit    joule   puls  zust gang relJoule
      SendData:= #$40+DevAdr+#$01+#$01+char(Tret)+char(watt)+char(RPM)+char(spd)+#$00+#$00+#$00+#$00+#$00+#$00+#$30+#$00+#$00+#$00+#$00;
      DebugString(Memo,SendData,'Suery Run Data Answ-');
      SerialFake.WriteData(SendData);
    end;
  end;


end;

end.

