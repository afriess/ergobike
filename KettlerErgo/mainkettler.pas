unit mainkettler;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  ExtCtrls, ActnList, Spin, LazSerial, LazSynaSer;


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
    ImageList: TImageList;
    lblRPMH1: TLabel;
    lblWattH1: TLabel;
    Memo: TMemo;
    PC: TPageControl;
    SerialFake: TLazSerial;
    StatusBar1: TStatusBar;
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
  if (Str <> '') and (Str <> #0) then begin
    FTempStr:= FTempStr + Str;
    DebugString(Memo,FTempStr);
    if not AnalyseTrames(FtempStr) then
      FTempStr:= '';
  end;
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
begin
end;

procedure TForm1.BUSpeedCalcTestClick(Sender: TObject);
begin
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
  // Kettler defintion
  // ID\r\n    : discover             -> ACK or RUN
  //                                     0             1           2          3   4   5    6    7
  // ST\r\n    : request all          -> heartrate \\s Cadence \\s speed*10 \\s \\s \\s \\s \\s Power
  // pw xx.x\r\n : set power          -> meaningless
  // cd\r\n    : Set PC mode          -> ACK or RUN

  if length(frame) = 0 then
    exit; //==>> nichts zu tun
  if length(frame) < 2 then begin
    result := true;           // weitere zeichen anfordern
    exit;
  end;
  if (LeftStr(Frame,2) = 'ID') then begin
    // Discover
    Memo.Append('Discover Dev Req');
    FTempStr := '';
    SendData:= 'ACK'+CR+LF;
    DebugString(Memo,SendData,'Discover Dev Answ-');
    SerialFake.WriteData(SendData);
  end
  else if (LeftStr(Frame,2)= 'cd')  then begin
    // set Pc mode
    Memo.Append('Set pcmode Req');
    if length(frame) < 4 then
      result := true           // weitere zeichen anfordern
    else begin
      FTempStr := '';
      SendData:= 'ACK'+CR+LF;        // send query back - in GC meaningless
      DebugString(Memo,SendData,'Set pcmode Answ-');
      SerialFake.WriteData(SendData);
    end;
  end
  else if (LeftStr(Frame,2)= 'pw')  then begin
    // set power
    Memo.Append('Set power Req');
    if length(frame) < 4 then
      result := true           // weitere zeichen anfordern
    else begin
      FTempStr := '';
      SendData:= Frame+CR+LF;        // send query back - in GC meaningless
      DebugString(Memo,SendData,'Set power Answ-');
      SerialFake.WriteData(SendData);
    end;
  end
  else if (LeftStr(Frame,2)= 'ST')  then begin
    // request all
    Memo.Append('Query Run Data Req');
    if length(frame) < 2 then
      result := true           // weitere zeichen anfordern
    else begin
      FTempStr := '';
      watt := TBWatt.Position div 5;
      RPM := TBRPM.Position;
      if (Watt < 5) then watt := 5;
      if (Watt > 80) then Watt := 80;
      if (RPM >= 5) then Tret:= 1
      else Tret:= 0;
      spd := round (RPM * ((1.75 + (0) * 0.098767) * 210.0) * 0.0006);
      //                                     0             1           2          3   4   5    6    7
      // ST\r\n    : request all          -> heartrate \\s Cadence \\s speed*10 \\s \\s \\s \\s \\s Power
      SendData:= '30'+#12+IntToStr(RPM)+#12+IntToStr(spd)+#12+#20+#12+#20+#12+#20+#12+#20+#12+intToStr(watt)+CR+LF;
      //                     PRG  PERS  Treten     Watt         RPM     spd     Dist   Tretzeit    joule   puls  zust gang relJoule
//      SendData:= #$40+DevAdr+#$01+#$01+char(Tret)+char(watt)+char(RPM)+char(spd)+#$00+#$00+#$00+#$00+#$00+#$00+#$30+#$00+#$00+#$00+#$00;
      DebugString(Memo,SendData,'Suery Run Data Answ-');
      SerialFake.WriteData(SendData);
    end;
  end;


end;

end.

