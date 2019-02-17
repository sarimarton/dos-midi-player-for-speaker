{$X+}
Unit SMMIDI;

interface
uses Crt;

type
  TParam = record
    Bip :LongInt;
    Kitart :Boolean;
  end;
const
  CParam :TParam = (Bip :10; Kitart :False);

type
  { MIDI-tîmb }
  PMTomb = ^TMTomb;
  TMTomb = record
    Tipus :array[1..4] of Char;
    Hossz :LongInt;
    Tomb :^Byte;
  end;

type
  PTimer = ^TTimer;
  TTimer = object
    private
      MicroSec :LongInt;
      Negyedosztas :LongInt;
      Keses :LongInt;
    public
    function Sec(Time :LongInt) :Real;
    procedure Delay(Time :LongInt);
    procedure Kesleltetes(MilliSec :LongInt);
    procedure InitTempo(IMicroSec :LongInt);
    procedure InitNegyedosztas(HanyEgyseg :LongInt);
    procedure Init;
  end;

  PConsol = ^TConsol;
  TConsol = object
    procedure Write(S :string); virtual;
    procedure WriteLn(S :string); virtual;
    constructor Init;
    destructor Done;
  end;

{  PKevero = ^TKevero;
  TKevero = object
    procedure Leut(Csatorna, Billentyu);
    procedure Kienged(Csatorna, Billentyu);
  end;}

  PMIDIPlayer = ^TMIDIPlayer;
  TMIDIPlayer = object
    F :^file;
    Param :TParam;
    Statusz :Byte;
    Statusztartas :Boolean;
    MentettStatusz :Byte;
    Statuszmentes :Boolean;
    Adat    :Byte;
    Herz    :array[0..127] of Real;

    Timer   :TTimer;
    Con     :PConsol;

    procedure SPP(Ertek :Word); virtual;
    procedure SongSelect(DalSzama :Byte); virtual;

    procedure NoteOn(Billentyu, Velocity :Byte); virtual;
    procedure NoteOff(Billentyu, Velocity :Byte); virtual;
    function Osszevont(A, B :Word) :Word;
    procedure PitchBend(Ertek :Word); virtual;
    procedure PolyphonicPressure(Billentyu, Ertek :Byte); virtual;
    procedure ChannelPressure(Ertek :Byte); virtual;
    procedure ProgramChange(Ertek :Byte); virtual;
    procedure ControlChange(Controller, Ertek :Byte); virtual;
    procedure Tempovaltas(B1, B2, B3 :Byte);
    procedure SMPTE_Offset(hr, mn, se, fr, ff :Byte);
    procedure UtemElojegyzes(Szamlalo, Log2Nevezo, MetronomBeosztas, Negyedosztas :Byte);
    procedure Elojegyzes(KeresztBe, DurMoll :ShortInt);

    procedure Hiba(S :string); virtual;
    procedure DisposeTomb(P :PMTomb);

    function TurnWord(W :Word) :Word;
    function TurnLong(L :LongInt) :LongInt;
    function ReadWord :Word;
    function ReadLong :LongInt;
    function NextTomb :PMTomb;
    function NextVHS :LongInt;
    function NextAdat2 :Byte;
    function NextSzoveg(Hossz :LongInt) :string;

    function StatuszE(B :Byte) :Boolean;

    procedure SEM;
    procedure MetaUzenet(UzenetKod :Byte);
    procedure SRTM(UzenetKod :Byte);

    function NextAdat :Byte;
    procedure NextEsemeny;

    constructor Init(var MIDIFile :file; ICon :PConsol; IParam :TParam);
    procedure Play;
    destructor Done;
  end;





{ ----------------------------------------------------------- }
implementation

function Str(L :LongInt) :string;
var
  S :string;
begin
  System.Str(L:0, S);
  Str := S;
end;

function StrReal(R :Real) :string;
var
  S :string;
begin
  System.Str(R:0:2, S);
  StrReal := S;
end;

procedure TConsol.Write(S :string);
begin
  System.Write(S);
end;

procedure TConsol.WriteLn(S :string);
begin
  Write(S + #13#10);
end;

constructor TConsol.Init;
begin
end;

destructor TConsol.Done;
begin
end;

procedure TTimer.Init;
begin
  Negyedosztas := 120;
  MicroSec := 6000000;
  Keses := 0;
end;

procedure TTimer.Kesleltetes(MilliSec :LongInt);
begin
  Keses := Keses + MilliSec;
end;

function TTimer.Sec(Time :LongInt) :Real;
begin
  Sec := Time * ((MicroSec / 1000000) / Negyedosztas);
end;

procedure TTimer.Delay(Time :LongInt);
var
  Milli :Real;
begin
  Milli := Time * ((MicroSec / 1000) / Negyedosztas);
  if (Keses > Milli) then
    Keses := Keses - Round(Milli)
  else begin
    Crt.Delay(Round(Milli) - Keses);
    Keses := 0;
  end;
end;

procedure TTimer.InitTempo(IMicroSec :LongInt);
begin
  MicroSec := IMicroSec;
end;

procedure TTimer.InitNegyedosztas(HanyEgyseg :LongInt);
begin
  Negyedosztas := HanyEgyseg;
end;


procedure TMIDIPlayer.Hiba(S :string);
begin
  Con^.WriteLn('Hiba:'#13#10 + S);
  Halt(1);
end;

{ A MIDI-file-ban a sz†mok †br†zol†s†n†l a helyiÇrtÇkek sorrendje }
{ a pascal-sz†m†br†zol†s†Çnak a ford°tottja (az elsì byte a legmagasabb) }
{ A kîvetkezì kÇt fÅggvÇny megford°tja a sz†m byte-jainak sorrendjÇt, }
{ teh†t oda-vissza konvert†l }
function TMIDIPlayer.TurnWord(W :Word) :Word;
begin
  TurnWord := Hi(W) + $100 * Lo(W);
end;

function TMIDIPlayer.TurnLong(L :LongInt) :LongInt;
var
  A :array[1..2] of Word;
  W :Word;
begin
  Move(L, A, 4);
  W := TurnWord(A[2]);
  A[2] := TurnWord(A[1]);
  A[1] := W;
  Move(A, L, 4);
  TurnLong := L;
end;

function TMIDIPlayer.ReadWord :Word;
var
  W :Word;
begin
  BlockRead(F^, W, 2);
  ReadWord := TurnWord(W);
end;

function TMIDIPlayer.ReadLong :LongInt;
var
  L :LongInt;
begin
  BlockRead(F^, L, 4);
  ReadLong := TurnLong(L);
end;

procedure TMIDIPlayer.DisposeTomb(P :PMTomb);
begin
  FreeMem(P^.Tomb, P^.Hossz);
  Dispose(P);
end;


{ ----------------------------------------------------------- }



{ LÇtrehoz egy PMTombot Çs annak feltîlti "Tomb^" mezìjÇt F^-bìl }
function TMIDIPlayer.NextTomb :PMTomb;
var
  P :PMTomb;
  V :Word;
begin
  New(P);
  BlockRead(F^, P^.Tipus, 4);
  P^.Hossz := ReadLong;

  GetMem(P^.Tomb, P^.Hossz);
  BlockRead(F^, P^.Tomb^, P^.Hossz, V);

  if (V <> P^.Hossz) then
    Hiba('A beolvasott tîmb mÇrete nem egyezik a fejben megadottal.');

  NextTomb := P;
end;


{ ----------------------------------------------------------- }



{ V†ltoz¢ Hossz£s†g£ Sz†mot olvas be F^-bìl }
function TMIDIPlayer.NextVHS :LongInt;
var
  A :array[1..4] of Byte;
  I, J :Integer;
  L, K :LongInt;
begin
  I := 1;
  BlockRead(F^, A[I], 1);
  while (A[I] and $80) = $80 do begin
    Inc(I);
    if (I > 4) then
      Hiba('Hib†s v†ltoz¢ hossz£s†g£ sz†mot olvastam.');
    BlockRead(F^, A[I], 1);
  end;

  L := A[I];
{  for I := 2 to I do begin
    K := A[I];
    J := 7 * (I - 1);
    L := L or ((127 shl J) and (K shl J));
  end;}

  for J := (I - 1) downto 1 do begin
    K := A[J] - $80;
    L := L or (K shl (7 * (I - J)));
  end;

  NextVHS := L;
end;


{ ----------------------------------------------------------- }


{ True, ha B st†tuszbyte, False, ha adat. }
function TMIDIPlayer.StatuszE(B :Byte) :Boolean;
begin
  StatuszE := ((B and $80) = $80);
end;

function TMIDIPlayer.NextAdat2 :Byte;
begin
  if not Statusztartas then
    BlockRead(F^, Adat, 1);
  Statusztartas := False;
  NextAdat2 := Adat;
end;

procedure TMIDIPlayer.SEM;
var
  Hossz :LongInt;
  P :^Byte;
begin
  Hossz := NextVHS;
  GetMem(P, Hossz);
  BlockRead(F^, P^, Hossz);
  FreeMem(P, Hossz);
end;

function TMIDIPlayer.NextSzoveg(Hossz :LongInt) :string;
var
  I :LongInt;
  C :Char;
  S :string;
begin
  S := '';
  for I := 1 to Hossz do begin
    C := Char(NextAdat2);
    if (I <= 255) then S := S + C;
  end;
  NextSzoveg := S;
end;

procedure TMIDIPlayer.Tempovaltas(B1, B2, B3 :Byte);
var
  L :LongInt;
begin
  L := B1;
  L := (L shl 8) + B2;
  L := (L shl 8) + B3;
  Timer.InitTempo(L);
  Con^.WriteLn('Temp¢v†ltoztat†s      : ' + Str(L) + ' mikrosec/negyed');
end;

procedure TMIDIPlayer.SMPTE_Offset(hr, mn, se, fr, ff :Byte);
begin
  Con^.WriteLn('SMPTE Offset (a dal ind°t†s†nak pontos ideje): ' +
    'hr=' + Str(hr) + ' mn=' + Str(mn) + ' se=' + Str(se) +
    ' fr=' + Str(fr) + ' ff=' + Str(ff));
end;


procedure TMIDIPlayer.UtemElojegyzes(Szamlalo, Log2Nevezo, MetronomBeosztas, Negyedosztas :Byte);
begin
  Con^.WriteLn('ötemelìjegyzÇs        : ' + Str(Szamlalo) + '/' +
    Str(1 shl Log2Nevezo) + '-os-es');
  Con^.WriteLn('A metron¢m beoszt†sa MIDI-¢r†ban : ' + Str(MetronomBeosztas));
  Con^.WriteLn('A zenei negyedet      : ' + Str(Negyedosztas) +
    ' harminckettedre lehet osztani');
end;

procedure TMIDIPlayer.Elojegyzes(KeresztBe, DurMoll :ShortInt);
var
  S :string;
begin
  S := 'ElìjegyzÇs            : ';
  if (KeresztBe < 0) then S := S + Str(0 - KeresztBe) + ' b; '
    else S := S + Str(KeresztBe) + ' #; ';
  if (DurMoll = 0) then S := S + 'd£r'
    else S := S + 'moll';
  Con^.WriteLn(S);
end;

procedure TMIDIPlayer.MetaUzenet(UzenetKod :Byte);
var
  Hossz, I, J :LongInt;
begin
  Hossz := NextVHS;
  case UzenetKod of
    $00 :Con^.WriteLn('A dal azonos°t¢k¢dja  : ' + Str(NextAdat2) + Str($100 * NextAdat2));
    $01 :Con^.WriteLn('èltal†nos szîveges Åzenet: ' + NextSzoveg(Hossz));
    $02 :Con^.WriteLn('Copyright Åzenet      : ' + NextSzoveg(Hossz));
    $03 :Con^.WriteLn('A dal/s†v neve        : ' + NextSzoveg(Hossz));
    $04 :Con^.WriteLn('A hangszer neve       : ' + NextSzoveg(Hossz));
    $05 :Con^.WriteLn('A dal megfelelì rÇszÇn Çneklendì szîveg: ' + NextSzoveg(Hossz));
    $06 :Con^.WriteLn('Jelzì                 : ' + NextSzoveg(Hossz));
    $07 :Con^.WriteLn('Kîvetìpont            : ' + NextSzoveg(Hossz));
    $20 :Con^.WriteLn('MIDI-csatorna         : ' + Str(NextAdat2));
    $2F :Con^.WriteLn('S†v vÇge');
    $51 :Tempovaltas(NextAdat2, NextAdat2, NextAdat2);
    $54 :SMPTE_Offset(NextAdat2, NextAdat2, NextAdat2, NextAdat2, NextAdat2);
    $58 :UtemElojegyzes(NextAdat2, NextAdat2, NextAdat2, NextAdat2);
    $59 :Elojegyzes(NextAdat2, NextAdat2);
    $7F :Con^.WriteLn('Dalszerkesztì-specifikus metaÅzenet: ' + NextSzoveg(Hossz));
    else Con^.WriteLn('Ismeretlen t°pus£ metaÅzenet (sz†ma: ' + Str(UzenetKod) + '): ' + NextSzoveg(Hossz));
  end;
end;

{ Song Position Pointer }
procedure TMIDIPlayer.SPP(Ertek :Word);
begin
end;

procedure TMIDIPlayer.SongSelect(DalSzama :Byte);
begin
end;

function TMIDIPlayer.Osszevont(A, B :Word) :Word;
begin
  Osszevont := A or ((127 shl 7) and (B shl 7));
end;



{ ------------------------------------------------------------- }



procedure TMIDIPlayer.NoteOn(Billentyu, Velocity :Byte);
begin
  Con^.WriteLn('Note on               : billentyu: ' + Str(Billentyu) +
    '; ÅtÇserãssÇg: ' + Str(Velocity));

  if (Velocity = 0) then
    NoSound
  else begin
    Sound(Round(Herz[Billentyu]));
    Delay(Param.Bip);
    Timer.Kesleltetes(Param.Bip);
    if not (Param.Kitart) then NoSound;
  end;
end;

procedure TMIDIPlayer.NoteOff(Billentyu, Velocity :Byte);
begin
  Con^.WriteLn('Note off              : billentyu: ' + Str(Billentyu) +
    '; engedÇserãssÇg: ' + Str(Velocity));

  NoSound;
end;

procedure TMIDIPlayer.PitchBend(Ertek :Word);
begin
end;

procedure TMIDIPlayer.PolyphonicPressure(Billentyu, Ertek :Byte);
begin
end;

procedure TMIDIPlayer.ChannelPressure(Ertek :Byte);
begin
end;

procedure TMIDIPlayer.ProgramChange(Ertek :Byte);
begin
end;

procedure TMIDIPlayer.ControlChange(Controller, Ertek :Byte);
begin
end;


{ ------------------------------------------------------------- }

{ SRTM - System Real Time Messages - Val¢s idejñ rendszerÅzenetek }
procedure TMIDIPlayer.SRTM(UzenetKod :Byte);
begin
  case UzenetKod of
    $F8 :Con^.WriteLn('Timing Clock');
    $FA :Con^.WriteLn('Start');
    $FC :Con^.WriteLn('Stop');
    $FB :Con^.WriteLn('Continue');
    $FE :Con^.WriteLn('Active Sensing');
{    $FF :Con^.WriteLn('System Reset!');}
  end;
end;

function TMIDIPlayer.NextAdat :Byte;
begin
  NextAdat2;
  while StatuszE(Adat) do begin
    SRTM(Adat);
    Adat := NextAdat;
  end;
  NextAdat := Adat;
end;

procedure TMIDIPlayer.NextEsemeny;
begin
  if Statuszmentes then begin
    Statusz := MentettStatusz;
    Statuszmentes := False;
  end;

  BlockRead(F^, Adat, 1);
  if StatuszE(Adat) then begin
    if (Adat = $FF) then begin
      MentettStatusz := Statusz;
      Statuszmentes := True;
    end;
    Statusz := Adat;
    Statusztartas := False;
  end
  else Statusztartas := True;

  { CVM - Channel Voice Messages - Hang-jellegñ csatornaÅzenetek }
  case (Statusz and $F0) of
    $90 :NoteOn(NextAdat, NextAdat);
    $80 :NoteOff(NextAdat, NextAdat);
    $E0 :PitchBend(Osszevont(NextAdat, NextAdat));
    $A0 :PolyphonicPressure(NextAdat, NextAdat);
    $D0 :ChannelPressure(NextAdat);
    $C0 :ProgramChange(NextAdat);
    $B0 :ControlChange(NextAdat, NextAdat);

    { SCM - System Common Messages - Egyszerñ rendszerÅzenetek }
    $F0 :case Statusz of
      $F1 :Con^.WriteLn('MIDI Time Code (MTC) Quarter-Frame');
      $F2 :SPP(Osszevont(NextAdat, NextAdat));
      $F3 :SongSelect(NextAdat);
      $F6 :Con^.WriteLn('Tune Request (înhangol†s)');
      $FF :MetaUzenet(NextAdat);
      $F0 :SEM;
      else SRTM(Statusz);
    end;
  end;
end;



{ ----------------------------------------------------------- }


procedure TMIDIPlayer.Play;
type
  { A fej adatbyte-jai (TMTomb.Tomb^. ...) }
  TFejTomb = record
    Formatum :Word;
    SavokSzama :Word;
    IEgys :Word;
  end;
var
  MTipus :Byte;
  Fejlec :PMTomb;
  Info :TFejTomb;

  SavTipus :array[1..4] of Char;
  SavHossz :LongInt;

  SavSzaml :LongInt; { a s†vokat sz†ml†lja egy for-next-ben }

  FP :LongInt;      { a file poz°ci¢ja mentetik bele, hogy a s†vhosszt szem elìtt tartsuk }
  Time :LongInt;    { az esemÇny elìtt eltelt idì (idìegysÇg * ez) }
  EsSzaml :LongInt; { esemÇnysz†ml†l¢ }

  Osszido :LongInt;
begin
  Fejlec := NextTomb;
  Move(Fejlec^.Tomb^, Info, 6);
  with Info do begin
    Formatum := TurnWord(Formatum);
    SavokSzama := TurnWord(SavokSzama);
    IEgys := TurnWord(IEgys);
  end;
{  Con^.WriteLn('A fejlÇc t°pusjelzìje : ', Fejlec^.Tipus);
  Con^.WriteLn('A fejlÇc hossza       : ' + Str(Fejlec^.Hossz));}
  Con^.WriteLn('MIDI type             : ' + Str(Info.Formatum));
  Con^.WriteLn('S†vok sz†ma           : ' + Str(Info.SavokSzama));

  if (Info.IEgys and $8000) = 0 then begin
    Con^.WriteLn('IdìegysÇg             : a negyedhang ' + Str(Info.IEgys) + '-ad-od-ed-îd rÇsze');
    Timer.InitNegyedosztas(Info.IEgys);
  end else begin
    Con^.WriteLn('IdìegysÇg             : a felsì 7 bit: ' + Str(ShortInt(Hi(Info.IEgys) - $80)) +
      ', az als¢ 8: ' + Str(Lo(Info.IEgys)));
    Hiba('Ezt az idìegysÇgt°pust nem tudom dek¢dolni.');
  end;
  DisposeTomb(Fejlec);

  for SavSzaml := 1 to Info.SavokSzama do
  begin
{    Con^.Write(Str(SavSzaml) + '. s†v, ');}
    BlockRead(F^, SavTipus, 4);
{    Con^.Write('t°pus: ''' + Str(SavTipus) + ''', ');}
    if (SavTipus <> 'MTrk') then
      Hiba('A s†v t°pusa nem ''MTrk''.');
    SavHossz := ReadLong;

{    Con^.WriteLn('hossza byte-okban: ' + Str(SavHossz));
    Con^.WriteLn('EsemÇnyei:');}

    FP := FilePos(F^);
    EsSzaml := 0;
    OsszIdo := 0;

    while (FilePos(F^) + 1) <= (FP + SavHossz) do begin
      Inc(EsSzaml);
      Time := NextVHS;
      Inc(OsszIdo, Time);

      Con^.WriteLn('EsemÇny               : ' + Str(EsSzaml) + '.');
      Con^.WriteLn('Eltelendã idìegysÇg   : ' + Str(Time));
      Con^.WriteLn('Eltelt idã            : ' + StrReal(Timer.Sec(OsszIdo)) + ' mp');

      Timer.Delay(Time);

      NextEsemeny;

      if KeyPressed and (ReadKey = #27) then Hiba('ESC †ltal megszak°tva');
    end;
  end;

  if EOF(F^) then Con^.WriteLn('KÇsz, minden rendben.');
end;

constructor TMIDIPlayer.Init(var MIDIFile :file; ICon :PConsol; IParam :TParam);
var
  I :Integer;
const
  Szorzo = 1.05946309435929526;
begin
  F := @MIDIFile;
  Con := ICon;
  Param := IParam;

  Herz[45] := 440;
  for I := 44 downto 0 do
    Herz[I] := Herz[I + 1] / Szorzo;
  for I := 46 to 127 do
    Herz[I] := Herz[I - 1] * Szorzo;

  Timer.Init;

  Statusztartas := False;
  Statuszmentes := False;
end;

destructor TMIDIPlayer.Done;
begin
end;

end.