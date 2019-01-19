unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls;

type

  { TForm1 }

  TForm1 = class(TForm)
    BuGetIP: TButton;
    BuGetIPList: TButton;
    Memo1: TMemo;
    procedure BuGetIPClick(Sender: TObject);
    procedure BuGetIPListClick(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;

implementation

uses
  Process;

{$R *.lfm}


function GetIPAddress: string;
var
  theProcess: TProcess;
  AddressString: AnsiString;
begin
  try
    theProcess := TProcess.Create(nil);
    theProcess.Executable := 'hostname';
    //theProcess.Parameters.Add('-I');
    theProcess.Parameters.Add('--all-ip-addresses');
    theProcess.Options := [poUsePipes,poWaitOnExit];
    theProcess.Execute;
    if theProcess.Output.NumBytesAvailable > 0 then
    begin
      SetLength(AddressString{%H-}, theProcess.Output.NumBytesAvailable);
      theProcess.Output.ReadBuffer(AddressString[1], theProcess.Output.NumBytesAvailable);
    end;
    GetIPAddress := AddressString;
  finally
    theProcess.Free;
  end;
end;



function GetIpAddrList: string;
var
  AProcess: TProcess;
  s: string;
  sl: TStringList;
  i, n: integer;

begin
  Result:='';
  sl:=TStringList.Create();
  {$IFDEF WINDOWS}
  AProcess:=TProcess.Create(nil);
  AProcess.Executable := 'ipconfig.exe';
  AProcess.Options := AProcess.Options + [poUsePipes, poNoConsole];
  try
    AProcess.Execute();
    Sleep(500); // poWaitOnExit not working as expected
    sl.LoadFromStream(AProcess.Output);
  finally
    AProcess.Free();
  end;
  for i:=0 to sl.Count-1 do
  begin
    if (Pos('IPv4', sl[i])=0) and (Pos('IP-', sl[i])=0) and (Pos('IP Address', sl[i])=0) then Continue;
    s:=sl[i];
    s:=Trim(Copy(s, Pos(':', s)+1, 999));
    if Pos(':', s)>0 then Continue; // IPv6
    Result:=Result+s+'  ';
  end;
  {$ENDIF}
  {$IFDEF UNIX}
  AProcess:=TProcess.Create(nil);
  AProcess.Executable := '/sbin/ifconfig';
  AProcess.Parameters.Add('-a');
  AProcess.Options := AProcess.Options + [poUsePipes, poWaitOnExit];
  try
    AProcess.Execute();
    sl.LoadFromStream(AProcess.Output);
  finally
    AProcess.Free();
  end;

  for i:=0 to sl.Count-1 do
  begin
    n:=Pos('inet ', sl[i]);
    if n=0 then Continue;
    s:=sl[i];
    s:=Copy(s, n+Length('inet '), 999);
    Result:=Result+Trim(Copy(s, 1, Pos(' ', s)))+'  ';
  end;
  {$ENDIF}
  sl.Free();
end;

{ TForm1 }

procedure TForm1.BuGetIPClick(Sender: TObject);
var
  str : String;
begin
  str := GetIPAddress;
  Memo1.Append(str);
end;

procedure TForm1.BuGetIPListClick(Sender: TObject);
var
  str : String;
begin
  str := GetIpAddrList;
  Memo1.Append(str);
end;

end.

