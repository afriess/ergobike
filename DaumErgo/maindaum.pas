unit mainDaum;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  ExtCtrls, ActnList, Spin, XMLPropStorage, IDEWindowIntf, LazSerial,
  LazSynaSer, MKnob, LedNumber;


const
  DevAdr =  #$01;
  Treten =  #$01;
  NTreten=  #$00;

  // Cockpittypen Classic Line
  CockpitUnknown = 0;
  CockpitCardio  = 10;    // $0A
  CockpitFitness = 20;    // $14
  CockpitVitaDeLuxe = 30; // $1E
  Cockpit8008    = 40;    // $28
  Cockpit8080    = 50;    // $32
  CockpitTherapiy = 60;   // $3C


type

  { TMainForm }

  TMainForm = class(TForm)
    ActQuit: TAction;
    ActionList: TActionList;
    BuConnect: TButton;
    BuDisconnect: TButton;
    BuTest: TButton;
    CBAutoCon: TCheckBox;
    EdGear1: TSpinEdit;
    EdSerialPort: TEdit;
    ImageList: TImageList;
    LblGearH1: TLabel;
    lblRPMH1: TLabel;
    lblWattH1: TLabel;
    LEDRPM: TLEDNumber;
    LEDWatt: TLEDNumber;
    Memo: TMemo;
    KnobWatt: TmKnob;
    PC: TPageControl;
    SerialFake: TLazSerial;
    StatusBar1: TStatusBar;
    ToolBar: TToolBar;
    ToolButton1: TToolButton;
    TS_Serial: TTabSheet;
    TS_Msg: TTabSheet;
    TS_Ergo: TTabSheet;
    TBRPM: TTrackBar;
    XMLPropStorage1: TXMLPropStorage;
    procedure ActQuitExecute(Sender: TObject);
    procedure BuConnectClick(Sender: TObject);
    procedure BuDisconnectClick(Sender: TObject);
    procedure BuTestClick(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure PCChange(Sender: TObject);
    procedure SerialFakeRxData(Sender: TObject);
    procedure SerialFakeStatus(Sender: TObject; Reason: THookSerialReason;
      const Value: string);
    procedure TBRPMChange(Sender: TObject);
  private
    FInit : Boolean;
    AktPrg : byte;
    function AnalyseTrames(Frame : string):boolean;

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
    if CBAutoCon.Checked then
      BuConnectClick(nil);
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

function TMainForm.AnalyseTrames(Frame: string): boolean;
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
  // 130 $82     : Get Config         -> $82 byte2 16bytesdata
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
      SendData:= #$73+#$02+#$03+#$04+#$05+#$06+#$07+#$08+#$09+#$1E+#$00;
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
      FTempStr := '';
      SendData:= #$23+DevAdr+Chr(AktPrg)+NTreten;
      DebugString(Memo,SendData,'Set Prog Ans-');
      SerialFake.WriteData(SendData);
    end;
  end
  else if (ord(Frame[1]) = $24) then begin
    // Set Person
    Memo.Append('Set Pers Req');
    if length(frame) < 15 then
      result := true           // weitere zeichen anfordern
    else begin
      Temp:= Frame[3];
      FTempStr := '';
      SendData:= Frame;// #$24+DevAdr+Chr(AktPrg);
      DebugString(Memo,SendData,'Set Pers Ans-');
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
  //else if (ord(Frame[1]) = $37)  then begin
  //  // Get Config
  //  Memo.Append('Get Config Req');
  //  if length(frame) < 18 then
  //    result := true           // weitere zeichen anfordern
  //  else begin
  //    FTempStr := '';
  //    SendData:= #$37+#$00+#$00+#$00+#$00+#$00+#$00+#$00+#$00+#$00+#$00+#$00+#$00+#$00+#$00+#$00+#$00+#$00;
  //    DebugString(Memo,SendData,'Set Config Answ-');
  //    SerialFake.WriteData(SendData);
  //  end;
  //end
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

