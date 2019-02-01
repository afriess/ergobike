unit mainDaum;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  ExtCtrls, ActnList, Spin, XMLPropStorage, ValEdit, IDEWindowIntf, LazSerial,
  LazSynaSer, MKnob, LedNumber;


const
  DevAdr =  #$01;
  Treten =  #$01;
  NTreten=  #$00;

  DevType= #$1E;

  // Cockpittypen Classic Line
  CockpitUnknown = 0;
  CockpitCardio  = 10;    // $0A
  CockpitFitness = 20;    // $14
  CockpitVitaDeLuxe = 30; // $1E
  Cockpit8008    = 40;    // $28
  Cockpit8080    = 50;    // $32
  CockpitTherapiy = 60;   // $3C


type

  TPerson = record
    Num,
    Age,
    Sex,
    Height,
    Weight,
    Fat,
    CoachGrade,
    CoachFreq,
    MaxWatt,
    MaxPulse,
    MaxTime,
    MaxDist,
    MaxCal : Byte;
  end;

  TPersonArr = array[0..4] of TPerson;

  { TMainForm }

  TMainForm = class(TForm)
    ActQuit: TAction;
    ActionList: TActionList;
    BuConnect: TButton;
    BuDisconnect: TButton;
    BuTest: TButton;
    CBAutoCon: TCheckBox;
    CBBikeType: TComboBox;
    EdGear1: TSpinEdit;
    EdSerialPort: TEdit;
    ImageList: TImageList;
    KnobPulse: TmKnob;
    LblPrg: TLabel;
    LblPers: TLabel;
    LblSlope: TLabel;
    LblGearH1: TLabel;
    lblRPMH1: TLabel;
    LblSpeed: TLabel;
    lblWattH1: TLabel;
    lblPulse: TLabel;
    LEDRPM: TLEDNumber;
    LEDSpeed: TLEDNumber;
    LEDWatt: TLEDNumber;
    LEDSlope: TLEDNumber;
    LEDPulse: TLEDNumber;
    Memo: TMemo;
    KnobWatt: TmKnob;
    PC: TPageControl;
    SerialFake: TLazSerial;
    StatusBar1: TStatusBar;
    Timer1: TTimer;
    ToolBar: TToolBar;
    ToolButton1: TToolButton;
    TS_Serial: TTabSheet;
    TS_Msg: TTabSheet;
    TS_Ergo: TTabSheet;
    TBRPM: TTrackBar;
    VLEPerson: TValueListEditor;
    XMLPropStorage1: TXMLPropStorage;
    procedure ActQuitExecute(Sender: TObject);
    procedure BuConnectClick(Sender: TObject);
    procedure BuDisconnectClick(Sender: TObject);
    procedure BuTestClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure KnobPulseChange(Sender: TObject; AValue: Longint);
    procedure LblSlopeClick(Sender: TObject);
    procedure PCChange(Sender: TObject);
    procedure SerialFakeRxData(Sender: TObject);
    procedure SerialFakeStatus(Sender: TObject; Reason: THookSerialReason;
      const Value: string);
    procedure TBRPMChange(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    FInit : Boolean;
    //
    Personen : TPersonArr;
    AktPers,                 // actual person
    AktPrg,                  // actual prg
    Tret,                    // 0=Stop 1=Cycling
    BikeType: Byte;          // GearTyp 0=Roadbike,1=MountainBike
    Dist1,
    Dist2,
    Time1,
    Time2 : byte;
    //
    Gear, RPM, Spd, Pulse : integer;
    Slope : single;
    TimeRun, TimeDiff, AktTime, LastTime : QWord;
    DistanceRun: double;
    function AnalyseTrames(Frame : string):boolean;
    procedure AnzPersonValues(APerson : TPerson);
    procedure ResetPrg;
    function BytesToSingle(B1,B2,B3,B4: Byte):single;
  public

  end;

var
  MainForm: TMainForm;

implementation
uses
  Math;

{$R *.lfm}
var
  FTempStr: String;
  CurPos: Integer;


{ TMainForm }

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

procedure TMainForm.SerialFakeRxData(Sender: TObject);
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

procedure TMainForm.BuConnectClick(Sender: TObject);
begin
  SerialFake.Device:= EdSerialPort.Text;
  SerialFake.BaudRate:= br__9600;
  SerialFake.DataBits:= db8bits;
  SerialFake.StopBits:= sbOne;
  SerialFake.FlowControl:= fcNone;
  SerialFake.Open;
  Memo.Clear;
end;

procedure TMainForm.ActQuitExecute(Sender: TObject);
begin
  close;
end;

procedure TMainForm.BuDisconnectClick(Sender: TObject);
begin
  SerialFake.Close;
end;

procedure TMainForm.BuTestClick(Sender: TObject);
var
  SendData : string;
begin
  SendData:= '123'+#$11+DevAdr;
  DebugString(Memo,SendData,'Test-');
  SerialFake.WriteData(SendData);
end;

procedure TMainForm.FormActivate(Sender: TObject);
begin
  if not FInit then begin
    // default values
    Slope:= 0.0;
    Spd:= 0;
    RPM:= 0;

    LastTime := GetTickCount64; // get Time in ms
    // AutoConnect
    if CBAutoCon.Checked then
      BuConnectClick(nil);
    // Start processing
    Timer1.Enabled:= true;
    FInit:= true;
  end;

end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin

end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FInit := false;
  if (EdSerialPort.Text = '') then
  {$ifdef RasPi}
    EdSerialPort.Text:= '/dev/ttyUSB0';
  {$else}
    EdSerialPort.Text:= 'com3';
  {$endif}
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  BuDisconnectClick(nil);
end;

procedure TMainForm.KnobPulseChange(Sender: TObject; AValue: Longint);
begin
   Pulse:= KnobPulse.Position;
   LEDPulse.Caption:= Pulse.ToString;
end;

procedure TMainForm.LblSlopeClick(Sender: TObject);
begin

end;

procedure TMainForm.PCChange(Sender: TObject);
begin

end;

procedure TMainForm.SerialFakeStatus(Sender: TObject; Reason: THookSerialReason;
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

procedure TMainForm.TBRPMChange(Sender: TObject);
begin
  LEDRPM.Caption:= IntToStr(TBRPM.Position);
end;

procedure TMainForm.Timer1Timer(Sender: TObject);
var
  DeltaTime : Qword;
  Geschw_ms, Distance : double;
begin
  Timer1.Enabled:= false;
  try
    AktTime := GetTickCount64; // get Time in ms
    RPM := TBRPM.Position;
    Gear := EdGear1.Value;
    // Check if spinning
    if (RPM >= 5) then begin
      // We are cycling
      Tret:= 1;
      // Calculate Speed
      Spd := round (RPM * ((1.75 + (Gear - 1) * 0.098767) * 210.0) * 0.0006);

      DeltaTime:= AktTime - LastTime; // Delta in ms
      TimeRun := TimeRun + DeltaTime;  // Runtime in ms

      // Calculate distance
      Geschw_ms := RPM * ((1.75 + (Gear - 1) * 0.098767) * 210.0) * 0.0006 * 3.6; // Speed meter per second
      Distance := (Deltatime/1000{sec}) * Geschw_ms{m/sec};

      DistanceRun:= DistanceRun + Distance; // in meter

      // Show
      LEDSpeed.Caption:= Spd.ToString;

      // Calc for Bike
      Dist1 := round(DistanceRun / 1000.0) and $FF;               // in 100 m parts
      Dist2 := (round(DistanceRun / 1000.0) shr 8) and $FF;

      Time1 :=  round(TimeRun / 1000.0) and $FF;                   // in second
      Time2 :=  (round(TimeRun / 1000.0)shr 8) and $FF;

    end
    else begin
      // We stopped
      Tret:= 0;
      Spd := 0;
    end;
    LastTime:= AktTime;

  finally
    Timer1.Enabled:= True;
  end;
end;

function TMainForm.AnalyseTrames(Frame: string): boolean;
var
  CurPos : integer;
  Temp : char;
  TempB : Byte;
  SendData : string;
  Watt : integer;
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
  // 130 $82     : Get Config         -> $82 byte2 16bytesdata
  if length(frame) = 0 then
    exit; //==>> nichts zu tun
  if (ord(Frame[1]) = $12) then begin
    // Reset
    Memo.Append('Reset Dev Req');
    if length(frame) < 2 then
      result := true           // weitere zeichen anfordern
    else begin
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
      SendData:= #$73+DevAdr+#$02+#$03+#$04+#$05+#$06+#$07+#$08+#$09+DevType;
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
      AktPrg:= ord(Frame[3]);
      LblPrg.Caption:= 'Program: '+AktPrg.ToString;
      FTempStr := '';
      SendData:= #$23+DevAdr+Chr(AktPrg)+NTreten;
      DebugString(Memo,SendData,'Set Prog Ans-');
      SerialFake.WriteData(SendData);
    end;
  end
  else if (ord(Frame[1]) = $24) then begin
    // Set Person
    Memo.Append('Set Person Req');
    if length(frame) < 15 then
      result := true           // weitere zeichen anfordern
    else begin
      TempB := ord(Frame[3]);
      AktPers:= TempB;
      LblPers.Caption:= 'Person: '+AktPers.ToString;
      if ((TempB >= Low(Personen)) and (TempB <= High(Personen))) then begin
        with Personen[TempB] do begin
          Num         := TempB;
          Age         := ord(Frame[4]);
          Sex         := ord(Frame[5]);
          Height      := ord(Frame[6]);
          Weight      := ord(Frame[7]);
          Fat         := ord(Frame[8]);
          CoachGrade  := ord(Frame[9]);
          CoachFreq   := ord(Frame[10]);
          MaxWatt     := ord(Frame[11]);
          MaxPulse    := ord(Frame[12]);
          MaxTime     := ord(Frame[13]);
          MaxDist     := ord(Frame[14]);
          MaxCal      := ord(Frame[15]);
        end;
      end;
      FTempStr := '';
      SendData:= Frame+NTreten;// #$24+DevAdr+Chr(AktPrg);
      DebugString(Memo,SendData,'Set Person Ans-');
      SerialFake.WriteData(SendData);
      AnzPersonValues(Personen[TempB]);
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
      ResetPrg;
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
  else if (ord(Frame[1]) = $37)  then begin
    // Get Config
    Memo.Append('Get Config Req');
    if length(frame) < 10 then
      result := true           // weitere zeichen anfordern
    else begin
      FTempStr := '';
      SendData:= #$37+DevAdr+#$09+#$08+#$07+#$06+#$05+#$04+#$03+#$02+#$01;
      DebugString(Memo,SendData,'Set Config Answ-');
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
      LEDWatt.Caption := IntToStr(KnobWatt.Position);
      RPM := TBRPM.Position;
      if (Watt < 5) then watt := 5;
      if (Watt > 80) then Watt := 80;
      //                         PRG         PERS         Treten       Watt       RPM     spd            Dist                   Tretzeit           joule      puls         zust  gang       relJoule
      SendData:= #$40+DevAdr+char(AktPrg)+char(AktPers)+char(Tret)+char(watt)+char(RPM)+char(spd)+char(Dist1)+char(Dist2)+char(Time1)+char(Time2)+ #$00+#$00+ char(Pulse)+ #$00+char(Gear)+ #$00+#$00;
      DebugString(Memo,SendData,'Suery Run Data Answ-');
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
  else if (ord(Frame[1]) = $53)  then begin
    // Set Gear
    Memo.Append('Set Gang Req');
    if length(frame) < 3 then
      result := true           // weitere zeichen anfordern
    else begin
      //TBWatt.Position :=
      EdGear1.Value:= Ord(Frame[3]);
      FTempStr := '';
      SendData:= #$53+DevAdr+Frame[3];
      DebugString(Memo,SendData,'Set Gang Answ-');
      SerialFake.WriteData(SendData);
    end;
  end
  else if (ord(Frame[1]) = $55)  then begin
    // Set Slope
    Memo.Append('Set Slope Req');
    if length(frame) < 6 then
      result := true           // weitere zeichen anfordern
    else begin
      Slope:= BytesToSingle(ord(Frame[3]),ord(Frame[4]),ord(Frame[5]),ord(Frame[6]));
      LEDSlope.Caption:= FloatToStrF(Slope,ffFixed,4,2);
      FTempStr := '';
      SendData:= #$55+DevAdr+Frame[3]+Frame[4]+Frame[5]+Frame[6];
      DebugString(Memo,SendData,'Set Slope Answ-');
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
  else if (ord(Frame[1]) = $69) then begin
    // Set Startparam
    Memo.Append('Set Startparam Req');
    if length(frame) < 5 then
      result := true           // weitere zeichen anfordern
    else begin
      BikeType:= ord(Frame[4]); // GearTyp 0=Roadbike,1=MountainBike
      FTempStr := '';
      SendData:= Frame; // ;
      DebugString(Memo,SendData,'Set Startparam Ans-');
      SerialFake.WriteData(SendData);
    end;
  end;


end;

procedure TMainForm.AnzPersonValues(APerson: TPerson);
begin
  VLEPerson.Clear;
  VLEPerson.InsertRow('Num',Aperson.Num.ToString,true);
  VLEPerson.InsertRow('Age',Aperson.Age.ToString,true);
  VLEPerson.InsertRow('Sex',Aperson.Sex.ToString,true);
  VLEPerson.InsertRow('Height',Aperson.Height .ToString,true);
  VLEPerson.InsertRow('Weight',Aperson.Weight.ToString,true);
  VLEPerson.InsertRow('Fat',Aperson.Fat.ToString,true);
  VLEPerson.InsertRow('CoachGrade',Aperson.CoachGrade.ToString,true);
  VLEPerson.InsertRow('CoachFreq',Aperson.CoachFreq.ToString,true);
  VLEPerson.InsertRow('MaxWatt',Aperson.MaxWatt.ToString,true);
  VLEPerson.InsertRow('MaxPulse',Aperson.MaxPulse.ToString,true);
  VLEPerson.InsertRow('MaxTime',Aperson.MaxTime.ToString,true);
  VLEPerson.InsertRow('MaxDist',Aperson.MaxDist.ToString,true);
  VLEPerson.InsertRow('MaxCal',Aperson.MaxCal.ToString,true);
end;

procedure TMainForm.ResetPrg;
begin
  LastTime:= GetTickCount64;
  TimeRun:= 0;
  DistanceRun:= 0;
end;

function TMainForm.BytesToSingle(B1, B2, B3, B4: Byte): single;
var
  buf : array[0..3] of byte;
  ASingle : Single absolute buf;
begin
  buf[0] := B1;
  buf[1] := B2;
  buf[2] := B3;
  buf[3] := B4;
  Result := ASingle;
end;

end.

