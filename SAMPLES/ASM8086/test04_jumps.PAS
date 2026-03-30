{ Genere par ASM2PAS v1.0 a partir de SAMPLES/ASM8086/test04_jumps.ASM }
Program test04_jumps;

Uses Dos;

Var
  { Registres 16 bits }
  RegAX, RegBX, RegCX, RegDX : Word;
  RegSI, RegDI, RegBP, RegSP : Word;
  RegDS, RegES, RegSS, RegCS : Word;
  { Flags }
  FlagCF, FlagZF, FlagSF, FlagOF : Boolean;
  FlagDF, FlagPF, FlagAF : Boolean;
  { Variables de sauvegarde PUSH/POP }
  SaveRegAX, SaveRegBX, SaveRegCX, SaveRegDX : Word;
  SaveRegSI, SaveRegDI, SaveRegBP, SaveRegSP : Word;
  SaveFlags : Word;
  { Sauvegarde individuelle des flags (PUSHF/POPF) }
  SaveFlagCF, SaveFlagZF, SaveFlagSF, SaveFlagOF : Boolean;
  SaveFlagDF, SaveFlagPF, SaveFlagAF : Boolean;
  { Variables temporaires }
  TmpL : LongInt;
  TmpW : Word;
  { Simulation memoire pour acces Mem[] }
  Mem : Array[0..65535] of Byte;
  MemW : Array[0..32767] of Word absolute Mem;
  counter : Word;

Label START, skip_this, less_label, equal_label, greater_label, done_cmp;

BEGIN
  START:
  RegAX := 0 (* @DATA *);
  RegDS := RegAX;
  Goto skip_this;
  RegAX := $03E7;
  skip_this:
  RegCX := $0A;
  While RegCX <> 0 do Begin Inc(counter);
  Dec(RegCX); End; { While loop_start }
  RegAX := $05;
  Begin FlagZF := (RegAX) = ($0A); FlagCF := (RegAX) < ($0A); FlagSF := (RegAX) - ($0A) < 0; FlagOF := False; End;
  If RegAX = $0A Then Goto equal_label;
  If (not FlagZF) and (FlagSF = FlagOF) Then Goto greater_label;
  If FlagSF <> FlagOF Then Goto less_label;
  less_label:
  RegBX := $01;
  Goto done_cmp;
  equal_label:
  RegBX := $00;
  Goto done_cmp;
  greater_label:
  RegBX := $02;
  done_cmp:
  RegAX := (RegAX and $00FF) or (Word(76) shl 8);
  Halt(Lo(RegAX)); { INT 21h/AH=4C }
END.
