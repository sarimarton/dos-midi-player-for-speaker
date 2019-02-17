{$X+}
program PlayMIDI;
uses
  Crt, SMMIDI;

const
  Par :TParam = (Bip :10; Kitart :False);
  RegLen = 8;

  Log = False;
type
  TRegSor = record
    S :string[RegLen];
    Num :Integer;
  end;

  PMyConsol = ^TMyConsol;
  TMyConsol = object(TConsol)
    X1, Y1, X2, Y2 :Integer;
    Esemenysor :Integer;
    RegArray :array[1..20] of TRegSor;
    RegMax :Integer;

    LogFile :Text;
    procedure Write(S :string); virtual;
    procedure WriteLn(S :string); virtual;
    constructor Init(LogName :string; iX1, iY1, iX2, iY2 :Integer);
    destructor Done;
  end;

procedure TMyConsol.Write(S :string);
var
  I :Integer;
begin
  Window(X1, Y1, X2, Y2);
  I := 1;
  while (I <= RegMax) and (Copy(S, 1, RegLen) <> RegArray[I].S) do
    Inc(I);

  if (I > RegMax) then begin
    if (RegMax < 20) then begin
      Inc(RegMax);
      RegArray[RegMax].S := Copy(S, 1, RegLen);
    end;
  end;
  GotoXY(1, I);
  System.Write(S); ClrEol;

{  X1 := WhereX; Y1 := WhereY;}

  if Log then System.Write(LogFile, S);
end;

procedure TMyConsol.WriteLn(S :string);
begin
  Write(S);
  if Log then System.Write(LogFile, #13#10);
end;

constructor TMyConsol.Init(LogName :string; iX1, iY1, iX2, iY2 :Integer);
begin
  Assign(LogFile, LogName);
  if Log then ReWrite(LogFile);
  X1 := iX1;  Y1 := iY1;
  X2 := iX2;  Y2 := iY2;
  Esemenysor := 5;
  RegMax := 0;
{  ClrScr;}
end;

destructor TMyConsol.Done;
begin
  if Log then Close(LogFile);
end;

procedure Hiba(S :string);
begin
  WriteLn('Hiba: ', S);
  Halt(1);
end;

var
  MyMIDIPlayer :TMIDIPlayer;
  MyConsol     :PMyConsol;
  MidFile      :file;
begin
  ClrScr;
  WriteLn('MIDI-file lej tsz s - S ri M rton');
  WriteLn('---------------------------------');

  if ParamStr(1) = '' then Hiba('Kell egy file param‚ternek.');

  Assign(MidFile, ParamStr(1));
  {$I-}
  Reset(MidFile, 1);
  if IOResult <> 0 then Hiba('A file-t nem tudom megnyitni.');
  {$I+}

  MyConsol := New(PMyConsol, Init('Log.txt', 1, 3, 80, 25));

  MyMIDIPlayer.Init(MidFile, MyConsol, Par);
  MyMIDIPlayer.Con^.WriteLn('A file neve           : ' + ParamStr(1));
  MyMIDIPlayer.Play;
  MyMIDIPlayer.Done;

  Dispose(MyConsol, Done);

  Close(MidFile);
 end.