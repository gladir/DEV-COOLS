#!/usr/bin/env python3
"""Porte dans DEVENV.PAS le noyau 68000 de DEVPAC.PAS (instructions, indicateurs, exceptions) sous le nom StCpu_*.
Ce noyau n'est utilise que pour la cible Atari ST (-CATARIST) ; le noyau M68K_* d'origine, partage par Amiga et
-C68000, reste intact.

  python3 OSSPAS_TESTS/devenv_port_st_cpu.py DEVPAC.PAS DEVENV.PAS

Le bloc genere est place entre deux marques, juste avant M68K_RunOneChunk ; relancer le script le remplace.
"""
import re,sys,os
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import pascal_prefix
BEGIN_MARK='{ ===== DEBUT NOYAU 68000 ATARI ST (StCpu_, porte de DEVPAC.PAS par devenv_port_st_cpu.py) ===== }'
END_MARK='{ ===== FIN NOYAU 68000 ATARI ST ===== }'
PRELUDE=r'''
Const
 MemSize = $100000;                 { 1 Mo : meme memoire que M68K_Mem }
Var
 AddrErr, BusErr: Boolean;
 BusAddr: LongInt;
Function IntStr(V: LongInt): String;
Begin IntStr := IntToStr(V); End;
Function Hex6(V: LongInt): String;
Begin Hex6 := M68K_HexN(V, 6); End;
Function Rd8(A: LongInt): Byte;
Begin Rd8 := M68K_Read8(A); End;
Function Rd16(A: LongInt): LongInt;
Begin Rd16 := M68K_Read16(A); End;
Function Rd32(A: LongInt): LongInt;
Begin Rd32 := M68K_Read32(A); End;
Procedure Wr8(A: LongInt; V: Byte);
Begin M68K_Write8(A, V); End;
Procedure Wr16(A: LongInt; V: LongInt);
Begin M68K_Write16(A, Word(V And $FFFF)); End;
Procedure Wr32(A: LongInt; V: LongInt);
Begin M68K_Write32(A, V); End;
Function ShrL(V: LongInt; N: Integer): LongInt;
Begin
 If N <= 0 Then ShrL := V
 Else If N >= 32 Then ShrL := 0
 Else Begin
  V := V Shr N;
  If N > 0 Then V := V And ((LongInt(1) Shl (32 - N)) - 1);
  ShrL := V;
 End;
End;
'''
LA_PRELUDE=r'''
Const
 SW = 640;
 SH = 400;
 StScrBase = $90000;               { ecran monochrome 640x400 : 32000 octets (Physbase / Logbase) }
 LINEA_VARS = $98800;              { variables de la ligne A (A0 apres $A000) }
 LA_PTSIN  = LINEA_VARS + $300;
 LA_INTIN  = LINEA_VARS + $400;
 LA_CONTRL = LINEA_VARS + $440;
 LA_FONTS  = $99000;               { tableau de pointeurs sur les polices (A1 apres $A000) }
 LA_FH     = $99010;               { 3 en-tetes de police de 88 octets }
 LA_F8DAT  = $99400;               { forme 8x8 : 256 x 8 octets }
 LA_F16DAT = $99C00;               { forme 8x16 : 256 x 16 octets }
@@FONT@@
Type
 TMfdb = Record
  Addr: LongInt;
  W, H, WW, Stand, Planes: Integer;
 End;
Var
 Font8: Array[0..255, 0..7] Of Byte;
 CX1, CY1, CX2, CY2: Integer;
 CurHotX, CurHotY: Integer;
 CurMask, CurData: Array[0..15] Of Word;
 MouseHidden: Integer;
 FloodCol: Integer;
 StGfx: Boolean;                   { l'ecran bitmap est affiche dans l'onglet }
 StFirst: Boolean;
 StShadow: Array[0..31999] Of Byte;
 StCX, StCY, StEsc, StEscA: Integer;
 StRev: Boolean;

Procedure CheckFonts;
Begin
 Move(Font8Emb, Font8, SizeOf(Font8));
End;

Function Min2(A, B: LongInt): LongInt;
Begin If A < B Then Min2 := A Else Min2 := B; End;
Function Max2(A, B: LongInt): LongInt;
Begin If A > B Then Max2 := A Else Max2 := B; End;
Function Clamp(V, A, B: LongInt): LongInt;
Begin If V < A Then Clamp := A Else If V > B Then Clamp := B Else Clamp := V; End;

Procedure BPix(X, Y: Integer; V: Boolean);
Var A: LongInt; B: Byte;
Begin
 If (X < 0) Or (X >= SW) Or (Y < 0) Or (Y >= SH) Then Exit;
 A := StScrBase + LongInt(Y) * 80 + (X Shr 3);
 B := Rd8(A);
 If V Then B := B Or (128 Shr (X And 7)) Else B := B And Not (128 Shr (X And 7));
 Wr8(A, B);
End;

Function BGet(X, Y: Integer): Boolean;
Begin
 BGet := False;
 If (X < 0) Or (X >= SW) Or (Y < 0) Or (Y >= SH) Then Exit;
 BGet := (Rd8(StScrBase + LongInt(Y) * 80 + (X Shr 3)) And (128 Shr (X And 7))) <> 0;
End;

Procedure SetClip(X1, Y1, X2, Y2: Integer);
Begin
 CX1 := Max2(0, X1); CY1 := Max2(0, Y1); CX2 := Min2(SW - 1, X2); CY2 := Min2(SH - 1, Y2);
End;

Function RopBit(Mode: Integer; S, D: Boolean): Boolean;
Begin
 Case Mode Of
  0: RopBit := False;
  1: RopBit := S And D;
  2: RopBit := S And Not D;
  3: RopBit := S;
  4: RopBit := Not S And D;
  5: RopBit := D;
  6: RopBit := S Xor D;
  7: RopBit := S Or D;
  8: RopBit := Not (S Or D);
  9: RopBit := Not (S Xor D);
  10: RopBit := Not D;
  11: RopBit := S Or Not D;
  12: RopBit := Not S;
  13: RopBit := Not S Or D;
  14: RopBit := Not (S And D);
 Else RopBit := True;
 End;
End;

Function ColBit(C: Integer): Boolean;
Begin ColBit := C <> 0; End;

Procedure ReadMfdb(P: LongInt; Var M: TMfdb);
Begin
 If P = 0 Then Begin
  M.Addr := 0; M.W := SW; M.H := SH; M.WW := 40; M.Stand := 0; M.Planes := 1; Exit;
 End;
 M.Addr := Rd32(P); M.W := SExt(Rd16(P + 4), 2); M.H := SExt(Rd16(P + 6), 2);
 M.WW := SExt(Rd16(P + 8), 2); M.Stand := Rd16(P + 10); M.Planes := SExt(Rd16(P + 12), 2);
 If M.Planes < 1 Then M.Planes := 1;
End;

Function MBit(Const M: TMfdb; X, Y: Integer): Boolean;
Var A: LongInt;
Begin
 If M.Addr = 0 Then MBit := BGet(X, Y)
 Else Begin
  A := M.Addr + LongInt(Y) * M.WW * 2 * M.Planes + (X Shr 3);
  MBit := (Rd8(A) And (128 Shr (X And 7))) <> 0;
 End;
End;

Procedure MPut(Const M: TMfdb; X, Y: Integer; V: Boolean);
Var A: LongInt; B: Byte;
Begin
 If M.Addr = 0 Then Begin
  If (X >= CX1) And (X <= CX2) And (Y >= CY1) And (Y <= CY2) Then BPix(X, Y, V);
 End Else Begin
  A := M.Addr + LongInt(Y) * M.WW * 2 * M.Planes + (X Shr 3);
  B := Rd8(A);
  If V Then B := B Or (128 Shr (X And 7)) Else B := B And Not (128 Shr (X And 7));
  Wr8(A, B);
 End;
End;

Procedure CopyRaster(Const Src, Dst: TMfdb; SX1, SY1, SX2, SY2, DX1, DY1: Integer; Mode: Integer;
                     Trans: Boolean; Fg, Bg: Integer);
Var W, H, X, Y, X0, X1_, XS, Y0, Y1_, YS: Integer; S, D, R: Boolean;
Begin
 If SX2 < SX1 Then Begin X := SX1; SX1 := SX2; SX2 := X; End;
 If SY2 < SY1 Then Begin Y := SY1; SY1 := SY2; SY2 := Y; End;
 W := SX2 - SX1 + 1; H := SY2 - SY1 + 1;
 If (W <= 0) Or (H <= 0) Then Exit;
 If (DY1 > SY1) And (Src.Addr = Dst.Addr) Then Begin Y0 := H - 1; Y1_ := 0; YS := -1; End
 Else Begin Y0 := 0; Y1_ := H - 1; YS := 1; End;
 If (DX1 > SX1) And (Src.Addr = Dst.Addr) Then Begin X0 := W - 1; X1_ := 0; XS := -1; End
 Else Begin X0 := 0; X1_ := W - 1; XS := 1; End;
 Y := Y0;
 While True Do Begin
  X := X0;
  While True Do Begin
   S := MBit(Src, SX1 + X, SY1 + Y);
   D := MBit(Dst, DX1 + X, DY1 + Y);
   If Trans Then Begin
    Case Mode Of
     1: If S Then R := ColBit(Fg) Else R := ColBit(Bg);
     2: If S Then R := ColBit(Fg) Else R := D;
     3: If S Then R := Not D Else R := D;
     4: If S Then R := D Else R := ColBit(Fg);
    Else R := S;
    End;
    MPut(Dst, DX1 + X, DY1 + Y, R);
   End Else MPut(Dst, DX1 + X, DY1 + Y, RopBit(Mode, S, D));
   If X = X1_ Then Break;
   X := X + XS;
  End;
  If Y = Y1_ Then Break;
  Y := Y + YS;
 End;
End;

{ remplissage par germe (region de meme couleur que le germe, 4-connexe, par lignes) }
Procedure FloodFill(X, Y: Integer; Border: Integer);
Var Stack: Array[0..511, 0..1] Of Integer; SP, L, R, I, XX: Integer; Seed, Fc: Boolean;
 Function Stop(Xp, Yp: Integer): Boolean;
 Begin Stop := BGet(Xp, Yp) <> Seed; End;
Begin
 Seed := BGet(X, Y); Fc := FloodCol <> 0;
 If (X < CX1) Or (X > CX2) Or (Y < CY1) Or (Y > CY2) Then Exit;
 If Seed = Fc Then Exit;
 SP := 0; Stack[0, 0] := X; Stack[0, 1] := Y; SP := 1;
 While SP > 0 Do Begin
  Dec(SP); XX := Stack[SP, 0]; Y := Stack[SP, 1];
  If (Y < CY1) Or (Y > CY2) Then Continue;
  If Stop(XX, Y) Then Continue;
  L := XX; R := XX;
  While (L > CX1) And Not Stop(L - 1, Y) Do Dec(L);
  While (R < CX2) And Not Stop(R + 1, Y) Do Inc(R);
  For I := L To R Do BPix(I, Y, Fc);
  For I := L To R Do Begin
   If SP >= 510 Then Break;
   If (Y > CY1) And Not Stop(I, Y - 1) And ((I = L) Or Stop(I - 1, Y - 1)) Then Begin
    Stack[SP, 0] := I; Stack[SP, 1] := Y - 1; Inc(SP); End;
   If (Y < CY2) And Not Stop(I, Y + 1) And ((I = L) Or Stop(I - 1, Y + 1)) Then Begin
    Stack[SP, 0] := I; Stack[SP, 1] := Y + 1; Inc(SP); End;
  End;
 End;
End;
'''
TAIL=r'''
{ ---- liaison avec le reste de l'emulateur DEVENV ---- }
Procedure StCpuLoad;
Var I: Integer;
Begin
 For I := 0 To 7 Do Begin
  Rg[I] := M68K_D[I];
  Rg[8 + I] := M68K_A[I];
 End;
 PC := M68K_PC;
 SRv := M68K_SR;
End;

Procedure StCpuStore;
Var I: Integer;
Begin
 For I := 0 To 7 Do Begin
  M68K_D[I] := Rg[I];
  M68K_A[I] := Rg[8 + I];
 End;
 M68K_PC := PC;
 M68K_SR := SRv;
End;



{ ---- chargeur de programmes GEMDOS (.PRG) : basepage, relocation, pile, ligne de commande ---- }
Const
 StHiTpa    = $A0000;              { fin de la zone programme (le tas GEMDOS commence ici) }
Var
 StBasePage: LongInt;              { adresse de la basepage : $1000 (texte en $1100) pour un programme relogeable ; }
                                   { $9F000 pour un programme sans table de relocation (TPCW32), charge en $0 }
 StExitStub: LongInt;              { clr.w -(sp) ; trap #1 : retour d'un programme par RTS }
 StUserSP: LongInt;                { pile utilisateur initiale }
 StTextBase: LongInt;              { adresse du texte du programme charge }

Function StLoadPRG(Const Name, Tail: String; Var Entry: LongInt): Boolean;
Var
 F: File;
 Hdr: Array[0..27] Of Byte;
 Buf: Array[0..4095] Of Byte;
 Tl, Dl, Bl, Sl, Tb, Cur, Todo, Chunk, K: LongInt;
 N: Word;
 B: Byte;
 HasReloc: Boolean;
 Function L(O: Integer): LongInt;
 Begin L := (LongInt(Hdr[O]) Shl 24) Or (LongInt(Hdr[O + 1]) Shl 16) Or (LongInt(Hdr[O + 2]) Shl 8) Or Hdr[O + 3]; End;
 Function NextByte: Byte;
 Var C: Byte; R: Word;
 Begin
  BlockRead(F, C, 1, R);
  If R = 0 Then NextByte := 0 Else NextByte := C;
 End;
Begin
 StLoadPRG := False;
 Entry := -1;
 Assign(F, Name);
 {$I-} Reset(F, 1); {$I+}
 If IOResult <> 0 Then Exit;
 BlockRead(F, Hdr, 28, N);
 If (N < 28) Or (Hdr[0] <> $60) Or (Hdr[1] <> $1A) Then Begin Close(F); Exit; End;
 Tl := L(2); Dl := L(6); Bl := L(10); Sl := L(14);
 { table de relocation presente ? sinon (programme TPCW32) le texte est charge a l'adresse 0 }
 HasReloc := False;
 If (Hdr[26] = 0) And (Hdr[27] = 0) Then Begin
  {$I-} Seek(F, 28 + Tl + Dl + Sl); {$I+}
  If IOResult = 0 Then Begin
   BlockRead(F, Buf, 4, N);
   If (N = 4) And ((Buf[0] Or Buf[1] Or Buf[2] Or Buf[3]) <> 0) Then HasReloc := True;
  End;
  {$I-} Seek(F, 28); {$I+}
 End;
 If HasReloc Then Begin StBasePage := $1000; StExitStub := $0F00; Tb := StBasePage + $100; End
 Else Begin StBasePage := $9F000; StExitStub := $9EF00; Tb := 0; End;
 If (Tl < 0) Or (Dl < 0) Or (Bl < 0) Or (Tb + Tl + Dl + Bl > $8F000) Then Begin Close(F); Exit; End;
 FillChar(M68K_Mem[0], StHiTpa, 0);
 { texte + donnees, par blocs de 4 Ko (le bloc d'un seul tenant depasserait la limite de BlockRead) }
 Cur := Tb; Todo := Tl + Dl;
 While Todo > 0 Do Begin
  If Todo > SizeOf(Buf) Then Chunk := SizeOf(Buf) Else Chunk := Todo;
  BlockRead(F, Buf, Chunk, N);
  If N = 0 Then Break;
  Move(Buf, M68K_Mem[Cur], N);
  Inc(Cur, N); Dec(Todo, N);
 End;
 { table de relocation : apres les symboles }
 If HasReloc Then Begin      { le programme est relogeable }
  {$I-} Seek(F, 28 + Tl + Dl + Sl); {$I+}
  If IOResult = 0 Then Begin
   BlockRead(F, Buf, 4, N);
   If N = 4 Then Begin
    Cur := (LongInt(Buf[0]) Shl 24) Or (LongInt(Buf[1]) Shl 16) Or (LongInt(Buf[2]) Shl 8) Or Buf[3];
    If Cur <> 0 Then Begin
     Repeat
      If (Cur >= 0) And (Cur + 4 <= Tl + Dl) Then
       M68K_Write32(Tb + Cur, M68K_Read32(Tb + Cur) + Tb);
      Repeat
       B := NextByte;
       If B = 1 Then Cur := Cur + 254;
      Until B <> 1;
      If B <> 0 Then Cur := Cur + B;
     Until B = 0;
    End;
   End;
  End;
 End;
 Close(F);
 { basepage }
 M68K_Write32(StBasePage + $00, StBasePage);          { p_lowtpa }
 M68K_Write32(StBasePage + $04, StHiTpa);             { p_hitpa }
 M68K_Write32(StBasePage + $08, Tb);                  { p_tbase }
 M68K_Write32(StBasePage + $0C, Tl);                  { p_tlen }
 M68K_Write32(StBasePage + $10, Tb + Tl);             { p_dbase }
 M68K_Write32(StBasePage + $14, Dl);                  { p_dlen }
 M68K_Write32(StBasePage + $18, Tb + Tl + Dl);        { p_bbase }
 M68K_Write32(StBasePage + $1C, Bl);                  { p_blen }
 M68K_Write32(StBasePage + $20, StBasePage + $80);    { p_dta }
 M68K_Write32(StBasePage + $24, 0);                   { p_parent }
 If Length(Tail) > 126 Then K := 126 Else K := Length(Tail);
 M68K_Write8(StBasePage + $80, K);
 For N := 1 To K Do M68K_Write8(StBasePage + $80 + N, Ord(Tail[N]));
 { retour par RTS : pile = adresse de sortie puis basepage (convention GEMDOS) }
 M68K_Write16(StExitStub, $4267);                     { clr.w -(sp) }
 M68K_Write16(StExitStub + 2, $4E41);                 { trap #1 }
 StUserSP := StHiTpa - 8;
 M68K_Write32(StUserSP, StExitStub);
 M68K_Write32(StUserSP + 4, StBasePage);
 StTextBase := Tb;
 Entry := Tb;
 StLoadPRG := True;
End;


{ ---- GEMDOS (fichiers, repertoires, memoire, date et heure), BIOS et XBIOS de l'Atari ST ---- }
Const
 StHeapLo = $A0000;                { tas GEMDOS (Malloc) : $A0000 .. $EFFFF }
 StHeapHi = $F0000;
 StBxKbdv = $F0400;                { table des vecteurs du clavier (Kbdvbase) }
 StBxRts  = $F0480;                { RTS : cible des vecteurs inutilises }
 StBxIorec = $F0500;               { trois structures IOREC (RS232, clavier, MIDI) }
 StBxIobuf = $F0600;               { leurs tampons (3 x 256 octets) }
 StBxKeyt = $F0A00;                { tables clavier (normal, Maj, Verr.Maj) }
Type
 StBlk = Record A, S: LongInt; End;
Var
 StFH: Array[6..21] Of File;
 StFUsed: Array[6..21] Of Boolean;
 StBlks: Array[1..64] Of StBlk;
 StNBlks: Integer;
 StCwd: String;                    { repertoire courant TOS (sans lecteur) }
 StDrv: Integer;
 StRoot: String;                   { racine du lecteur : repertoire de travail de DEVENV au lancement }
 StSfDir, StSfPat: String;
 StSfAttr: Integer;
 StSfRec: SearchRec;
 StDta: LongInt;
 StClockAdj: LongInt;
 StBxInit: Boolean;
 StPal: Array[0..15] Of Integer;
 StGi: Array[0..15] Of Byte;
 StKbRate, StPrt: Integer;

Function PW(N: Integer): LongInt;
Begin PW := Rd16(Rg[15] + N); End;
Function PL(N: Integer): LongInt;
Begin PL := Rd32(Rg[15] + N); End;

Function StUpper(Const S: String): String;
Var I: Integer; T: String;
Begin
 T := S;
 For I := 1 To Length(T) Do T[I] := UpCase(T[I]);
 StUpper := T;
End;

Function StCStr(A: LongInt): String;
Var S: String;
Begin
 S := '';
 While (Rd8(A) <> 0) And (Length(S) < 250) Do Begin S := S + Chr(Rd8(A)); Inc(A); End;
 StCStr := S;
End;

Procedure StPutStr(A: LongInt; Const S: String);
Var I: Integer;
Begin
 For I := 1 To Length(S) Do Wr8(A + I - 1, Ord(S[I]));
 Wr8(A + Length(S), 0);
End;

{ nom TOS -> chemin hote : lecteur retire, \ -> /, chemin relatif complete par le repertoire courant, casse resolue }
Function StHostPath(Const S0: String): String;
Var S, Cur, Comp, Full: String; I: Integer; Found: Boolean; Sr: SearchRec;
Begin
 S := S0;
 While (Length(S) > 0) And (S[Length(S)] = ' ') Do Delete(S, Length(S), 1);
 If (Length(S) >= 2) And (S[2] = ':') Then Delete(S, 1, 2);
 For I := 1 To Length(S) Do If S[I] = '/' Then S[I] := '\';
 If (S = '') Or (S[1] <> '\') Then Begin
  If StCwd = '\' Then Full := '\' + S Else Full := StCwd + '\' + S;
 End Else Full := S;
 If StRoot = '' Then Begin GetDir(0, StRoot); If (StRoot <> '') And (StRoot[Length(StRoot)] <> '/') And (StRoot[Length(StRoot)] <> '\') Then StRoot := StRoot + '/'; End;
 Cur := StRoot;
 I := 1;
 While I <= Length(Full) Do Begin
  Comp := '';
  While (I <= Length(Full)) And (Full[I] = '\') Do Inc(I);
  While (I <= Length(Full)) And (Full[I] <> '\') Do Begin Comp := Comp + Full[I]; Inc(I); End;
  If (Comp = '') Or (Comp = '.') Then
  Else Begin
   Found := False;
   {$I-}
   FindFirst(Cur + '*', AnyFile, Sr);
   {$I+}
   While DosError = 0 Do Begin
    If StUpper(Sr.Name) = StUpper(Comp) Then Begin Comp := Sr.Name; Found := True; Break; End;
    FindNext(Sr);
   End;
   If Found Then Begin
    Cur := Cur + Comp;
    If I <= Length(Full) Then Cur := Cur + '/';
   End Else Begin
    Cur := Cur + Comp;
    If I <= Length(Full) Then Cur := Cur + '/';
   End;
  End;
 End;
 If (Cur <> '') And (Cur[Length(Cur)] = '/') And (Length(Cur) > 1) And (Cur <> StRoot) Then Delete(Cur, Length(Cur), 1);
 StHostPath := Cur;
End;

{ fichier a creer : nom en majuscules (sauf s'il existe deja) }
Function StCreatePath(Const S0: String): String;
Var H: String; I, P: Integer; F: File; Ex: Boolean;
Begin
 H := StHostPath(S0);
 Assign(F, H);
 {$I-} Reset(F, 1); {$I+}
 Ex := IOResult = 0;
 If Ex Then Close(F)
 Else Begin
  P := 0;
  For I := 1 To Length(H) Do If H[I] = '/' Then P := I;
  H := Copy(H, 1, P) + StUpper(Copy(H, P + 1, 200));
 End;
 StCreatePath := H;
End;

Function StMatch(Const Pat, Nm: String): Boolean;
 Function M(P, N: Integer): Boolean;
 Begin
  While P <= Length(Pat) Do Begin
   If Pat[P] = '*' Then Begin
    While (P <= Length(Pat)) And (Pat[P] = '*') Do Inc(P);
    If P > Length(Pat) Then Begin M := True; Exit; End;
    While N <= Length(Nm) + 1 Do Begin
     If M(P, N) Then Begin M := True; Exit; End;
     Inc(N);
    End;
    M := False; Exit;
   End Else If N > Length(Nm) Then Begin M := False; Exit; End
   Else If (Pat[P] <> '?') And (Pat[P] <> Nm[N]) Then Begin M := False; Exit; End;
   Inc(P); Inc(N);
  End;
  M := N > Length(Nm);
 End;
Begin
 If Pat = '*.*' Then StMatch := True Else StMatch := M(1, 1);
End;

Function StNextMatch(First: Boolean): Boolean;
Begin
 StNextMatch := False;
 If First Then Begin
  {$I-} FindFirst(StSfDir + '*', AnyFile, StSfRec); {$I+}
 End Else Begin
  {$I-} FindNext(StSfRec); {$I+}
 End;
 While DosError = 0 Do Begin
  If StMatch(StSfPat, StUpper(StSfRec.Name)) And (StSfRec.Name <> '.') And (StSfRec.Name <> '..') And
     (((StSfRec.Attr And Directory) = 0) Or ((StSfAttr And $10) <> 0)) And
     ((StSfRec.Attr And $8) = 0) Then Begin
   StNextMatch := True; Exit;
  End;
  {$I-} FindNext(StSfRec); {$I+}
 End;
End;

Procedure StFillDta;
Var N: String;
Begin
 Wr8(StDta + 21, StSfRec.Attr And $27);
 Wr16(StDta + 22, StSfRec.Time And $FFFF);
 Wr16(StDta + 24, (StSfRec.Time Shr 16) And $FFFF);
 Wr32(StDta + 26, StSfRec.Size);
 N := StUpper(StSfRec.Name);
 If Length(N) > 12 Then N := Copy(N, 1, 12);
 StPutStr(StDta + 30, N);
End;

Function StNowSecs: LongInt;
Var Y, Mo, D, Dw, H, Mi, S, S100: Word;
Begin
 GetDate(Y, Mo, D, Dw);
 GetTime(H, Mi, S, S100);
 StNowSecs := LongInt(H) * 3600 + Mi * 60 + S + StClockAdj;
End;

Function StAlloc(N: LongInt): LongInt;
Var I, J: Integer; Lo, Hi, Best: LongInt; T: StBlk;
Begin
 StAlloc := 0;
 If (N <= 0) Or (StNBlks >= 64) Then Exit;
 N := (N + 3) And (Not 3);
 Lo := StHeapLo;
 For I := 0 To StNBlks Do Begin
  If I < StNBlks Then Hi := StBlks[I + 1].A Else Hi := StHeapHi;
  If Hi - Lo >= N Then Begin
   Inc(StNBlks);
   For J := StNBlks DownTo I + 2 Do StBlks[J] := StBlks[J - 1];
   StBlks[I + 1].A := Lo; StBlks[I + 1].S := N;
   FillChar(M68K_Mem[Lo], N, 0);
   StAlloc := Lo; Exit;
  End;
  If I < StNBlks Then Lo := StBlks[I + 1].A + StBlks[I + 1].S;
 End;
 Best := 0;
End;

Function StLargest: LongInt;
Var I: Integer; Lo, Hi, Best: LongInt;
Begin
 Best := 0; Lo := StHeapLo;
 For I := 0 To StNBlks Do Begin
  If I < StNBlks Then Hi := StBlks[I + 1].A Else Hi := StHeapHi;
  If Hi - Lo > Best Then Best := Hi - Lo;
  If I < StNBlks Then Lo := StBlks[I + 1].A + StBlks[I + 1].S;
 End;
 StLargest := Best;
End;

Function StFreeSlot: Integer;
Var I: Integer;
Begin
 StFreeSlot := -1;
 For I := 6 To 21 Do If Not StFUsed[I] Then Begin StFreeSlot := I; Exit; End;
End;

{ retourne True si la fonction GEMDOS est traitee ici (D0 = resultat) }
Function StGemdos: Boolean;
Var Fn: Word; H, I, J, K: Integer; S, S2: String; A, Cnt, Done, Pos2, T: LongInt; F: File; N: Word; At: Word;
    Buf: Array[0..4095] Of Byte; Mode: Integer; Yy, Mm, Dd, Dw: Word;
Begin
 StGemdos := True;
 Fn := Rd16(Rg[15]);
 Case Fn Of
  $0E: Begin StDrv := PW(2) And 15; Rg[0] := 5; End;
  $19: Rg[0] := StDrv;
  $1A: StDta := PL(2);
  $2F: Rg[0] := StDta;
  $2A: Begin
        { Tgetdate }
        Rg[0] := 0;
        GetDate(Yy, Mm, Dd, Dw);
        Rg[0] := ((LongInt(Yy) - 1980) Shl 9) Or (LongInt(Mm) Shl 5) Or Dd;
       End;
  $2B: Rg[0] := 0;
  $2C: Begin
        T := StNowSecs Mod 86400;
        Rg[0] := ((T Div 3600) Shl 11) Or (((T Div 60) Mod 60) Shl 5) Or ((T Mod 60) Div 2);
       End;
  $2D: Begin
        T := PW(2);
        StClockAdj := (T Shr 11) * 3600 + ((T Shr 5) And 63) * 60 + (T And 31) * 2 - (StNowSecs - StClockAdj) Mod 86400;
        Rg[0] := 0;
       End;
  $36: Begin
        A := PL(2);
        Wr32(A, 20000); Wr32(A + 4, 40000); Wr32(A + 8, 512); Wr32(A + 12, 2);
        Rg[0] := 0;
       End;
  $39: Begin
        {$I-} MkDir(StCreatePath(StCStr(PL(2)))); {$I+}
        If IOResult <> 0 Then Rg[0] := -36 Else Rg[0] := 0;
       End;
  $3A: Begin
        {$I-} RmDir(StHostPath(StCStr(PL(2)))); {$I+}
        If IOResult <> 0 Then Rg[0] := -36 Else Rg[0] := 0;
       End;
  $3B: Begin
        S := StCStr(PL(2));
        If (Length(S) >= 2) And (S[2] = ':') Then Delete(S, 1, 2);
        For I := 1 To Length(S) Do If S[I] = '/' Then S[I] := '\';
        Done := 0;
        {$I-} FindFirst(StHostPath(S), Directory, StSfRec); {$I+}
        If (S = '') Or (S = '\') Or ((DosError = 0) And ((StSfRec.Attr And Directory) <> 0)) Then Begin
         If (S = '') Or (S[1] <> '\') Then Begin If StCwd = '\' Then S := '\' + S Else S := StCwd + '\' + S; End;
         While (Length(S) > 1) And (S[Length(S)] = '\') Do Delete(S, Length(S), 1);
         StCwd := S; Rg[0] := 0;
        End Else Rg[0] := -34;
       End;
  $3C: Begin
        H := StFreeSlot;
        If H < 0 Then Rg[0] := -35
        Else Begin
         Assign(StFH[H], StCreatePath(StCStr(PL(2))));
         {$I-} Rewrite(StFH[H], 1); {$I+}
         If IOResult <> 0 Then Rg[0] := -36 Else Begin StFUsed[H] := True; Rg[0] := H; End;
        End;
       End;
  $3D: Begin
        H := StFreeSlot;
        If H < 0 Then Rg[0] := -35
        Else Begin
         S := StHostPath(StCStr(PL(2)));
         Assign(StFH[H], S);
         If (PW(6) And 3) = 0 Then FileMode := 0 Else FileMode := 2;
         {$I-} Reset(StFH[H], 1); {$I+}
         FileMode := 2;
         If IOResult <> 0 Then Rg[0] := -33 Else Begin StFUsed[H] := True; Rg[0] := H; End;
        End;
       End;
  $3E: Begin
        H := PW(2);
        If (H >= 6) And (H <= 21) And StFUsed[H] Then Begin
         {$I-} Close(StFH[H]); {$I+}
         If IOResult <> 0 Then ;
         StFUsed[H] := False; Rg[0] := 0;
        End Else If H < 6 Then StGemdos := False Else Rg[0] := -37;
       End;
  $3F: Begin
        H := SmallInt(PW(2)); Cnt := PL(4); A := PL(8);
        If (H >= 6) And (H <= 21) And StFUsed[H] Then Begin
         Done := 0;
         If Cnt < 0 Then Cnt := 0;
         While Cnt > 0 Do Begin
          If Cnt > SizeOf(Buf) Then K := SizeOf(Buf) Else K := Cnt;
          {$I-} BlockRead(StFH[H], Buf, K, N); {$I+}
          If IOResult <> 0 Then Begin N := 0; End;
          For I := 0 To N - 1 Do Wr8(A + Done + I, Buf[I]);
          Done := Done + N; Cnt := Cnt - N;
          If N < K Then Break;
         End;
         Rg[0] := Done;
        End Else If (H >= 0) And (H < 6) Then StGemdos := False Else Rg[0] := -37;
       End;
  $40: Begin
        H := SmallInt(PW(2)); Cnt := PL(4); A := PL(8);
        If (H >= 6) And (H <= 21) And StFUsed[H] Then Begin
         Done := 0;
         While Cnt > 0 Do Begin
          If Cnt > SizeOf(Buf) Then K := SizeOf(Buf) Else K := Cnt;
          For I := 0 To K - 1 Do Buf[I] := Rd8(A + Done + I);
          {$I-} BlockWrite(StFH[H], Buf, K, N); {$I+}
          If IOResult <> 0 Then N := 0;
          Done := Done + N; Cnt := Cnt - N;
          If N < K Then Break;
         End;
         Rg[0] := Done;
        End Else If (H >= 0) And (H < 6) Then StGemdos := False Else Rg[0] := -37;
       End;
  $41: Begin
        S := StHostPath(StCStr(PL(2)));
        Assign(F, S);
        {$I-} Reset(F, 1); {$I+}
        If IOResult <> 0 Then Rg[0] := -33
        Else Begin
         Close(F);
         {$I-} Erase(F); {$I+}
         If IOResult <> 0 Then Rg[0] := -36 Else Rg[0] := 0;
        End;
       End;
  $42: Begin
        Pos2 := PL(2); H := PW(6); Mode := PW(8);
        If (H >= 6) And (H <= 21) And StFUsed[H] Then Begin
         If Mode = 1 Then Pos2 := Pos2 + FilePos(StFH[H])
         Else If Mode = 2 Then Pos2 := Pos2 + FileSize(StFH[H]);
         If Pos2 < 0 Then Pos2 := 0;
         {$I-} Seek(StFH[H], Pos2); {$I+}
         If IOResult <> 0 Then Rg[0] := -64 Else Rg[0] := Pos2;
        End Else If H < 6 Then Rg[0] := 0 Else Rg[0] := -37;
       End;
  $43: Begin
        S := StHostPath(StCStr(PL(2)));
        Assign(F, S);
        {$I-} Reset(F, 1); {$I+}
        If IOResult = 0 Then Begin
         Close(F);
         At := 0;
         {$I-} GetFAttr(F, At); {$I+}
         If IOResult <> 0 Then At := 0;
         Rg[0] := At And $27;
        End Else Begin
         {$I-} FindFirst(S, Directory, StSfRec); {$I+}
         If (DosError = 0) And ((StSfRec.Attr And Directory) <> 0) Then Rg[0] := $10 Else Rg[0] := -33;
        End;
       End;
  $47: Begin
        S := StCwd;
        StPutStr(PL(2), S);
        Rg[0] := 0;
       End;
  $48: Begin
        Cnt := PL(2);
        If Cnt = -1 Then Rg[0] := StLargest
        Else Rg[0] := StAlloc(Cnt);
       End;
  $49: Begin
        A := PL(2); Rg[0] := -40;
        For I := 1 To StNBlks Do
         If StBlks[I].A = A Then Begin
          For J := I To StNBlks - 1 Do StBlks[J] := StBlks[J + 1];
          Dec(StNBlks); Rg[0] := 0; Break;
         End;
       End;
  $4A: Begin
        A := PL(4); Cnt := PL(8); Rg[0] := 0;
        For I := 1 To StNBlks Do
         If StBlks[I].A = A Then Begin If Cnt < StBlks[I].S Then StBlks[I].S := (Cnt + 3) And (Not 3); End;
       End;
  $4E: Begin
        S := StCStr(PL(2));
        StSfAttr := PW(6);
        For I := 1 To Length(S) Do If S[I] = '/' Then S[I] := '\';
        If (Length(S) >= 2) And (S[2] = ':') Then Delete(S, 1, 2);
        J := 0;
        For I := 1 To Length(S) Do If S[I] = '\' Then J := I;
        If J > 0 Then Begin
         If J = 1 Then StSfDir := StHostPath('\') Else StSfDir := StHostPath(Copy(S, 1, J - 1));
         StSfPat := StUpper(Copy(S, J + 1, 100));
        End Else Begin StSfDir := StHostPath(''); StSfPat := StUpper(S); End;
        If (StSfDir <> '') And (StSfDir[Length(StSfDir)] <> '/') Then StSfDir := StSfDir + '/';
        If StNextMatch(True) Then Begin StFillDta; Rg[0] := 0; End Else Rg[0] := -33;
       End;
  $4F: Begin
        If StNextMatch(False) Then Begin StFillDta; Rg[0] := 0; End Else Rg[0] := -49;
       End;
  $56: Begin
        S := StHostPath(StCStr(PL(4)));
        S2 := StCreatePath(StCStr(PL(8)));
        Assign(F, S);
        {$I-} Reset(F, 1); {$I+}
        If IOResult <> 0 Then Rg[0] := -33
        Else Begin
         Close(F);
         {$I-} Rename(F, S2); {$I+}
         If IOResult <> 0 Then Rg[0] := -36 Else Rg[0] := 0;
        End;
       End;
  $57: Begin
        A := PL(2); H := PW(6);
        If (PW(8) = 0) And (H >= 6) And (H <= 21) And StFUsed[H] Then Begin
         T := 0;
         {$I-} GetFTime(StFH[H], T); {$I+}
         If IOResult <> 0 Then T := 0;
         Wr16(A, T And $FFFF); Wr16(A + 2, (T Shr 16) And $FFFF);
        End;
        Rg[0] := 0;
       End;
 Else StGemdos := False;
 End;
End;


Procedure StBxSetup;
Var
 Us1, Us2: String;
 I, K: Integer;
Begin
 StBxInit := True;
 Us1 := #0#27 + '1234567890-=' + #8#9 + 'qwertyuiop[]' + #13#0 + 'asdfghjkl;' + #39 + '`' + #0 + '\' + 'zxcvbnm,./' + #0#0#0 + ' ';
 Us2 := #0#27 + '!@#$%^&*()_+' + #8#9 + 'QWERTYUIOP{}' + #13#0 + 'ASDFGHJKL:"~' + #0 + '|' + 'ZXCVBNM<>?' + #0#0#0 + ' ';
 For I := 0 To 8 Do Wr32(StBxKbdv + I * 4, StBxRts);
 Wr16(StBxRts, $4E75);
 For I := 0 To 2 Do Begin
  Wr32(StBxIorec + I * 14, StBxIobuf + I * 256);
  Wr16(StBxIorec + I * 14 + 4, 256);
  Wr16(StBxIorec + I * 14 + 10, 64);
  Wr16(StBxIorec + I * 14 + 12, 192);
 End;
 For K := 1 To Length(Us1) Do Begin
  Wr8(StBxKeyt + K, Ord(Us1[K])); Wr8(StBxKeyt + 128 + K, Ord(Us2[K]));
  If (Us1[K] >= 'a') And (Us1[K] <= 'z') Then Wr8(StBxKeyt + 256 + K, Ord(Us2[K])) Else Wr8(StBxKeyt + 256 + K, Ord(Us1[K]));
 End;
 For I := 0 To 15 Do StPal[I] := 0;
 StPal[0] := $777;
 For I := 0 To 15 Do StGi[I] := 0;
 StGi[7] := $FF; StGi[14] := $FF;
 StKbRate := $0F0F; StPrt := 0;
End;

{ retourne True si la fonction BIOS est traitee ici }
Function StBios: Boolean;
Var Fn, N: Word; A: LongInt;
Begin
 StBios := True;
 If Not StBxInit Then StBxSetup;
 Fn := Rd16(Rg[15]);
 Case Fn Of
  0: Begin A := PL(2); Wr32(A, 0); Wr32(A + 4, 0); Wr32(A + 8, 0); Rg[0] := 0; End;
  5: Begin
      N := PW(2); A := PL(4);
      If N < $200 Then Begin
       Rg[0] := Rd32(N * 4);
       If A <> -1 Then Wr32(N * 4, A);
      End Else Rg[0] := 0;
     End;
  6: Rg[0] := 20;
  8: Rg[0] := -1;
  10: Rg[0] := 5;                          { Drvmap : A: et C: }
 Else StBios := False;
 End;
End;

{ retourne True si la fonction XBIOS est traitee ici }
Function StXbios: Boolean;
Var Fn: Word; A: LongInt; I, V: Integer; Y, Mo, D, Dw, Hh, Mi, Se, Hs: Word;
Begin
 StXbios := True;
 If Not StBxInit Then StBxSetup;
 Fn := Rd16(Rg[15]);
 Case Fn Of
  0: Rg[0] := 0;
  6: Begin A := PL(2); For I := 0 To 15 Do StPal[I] := SmallInt(Rd16(A + I * 2)); Rg[0] := 0; End;
  7: Begin
      I := PW(2) And 15;
      Rg[0] := StPal[I] And $FFFF;
      V := SmallInt(PW(4));
      If V >= 0 Then StPal[I] := V And $777;
     End;
  14: Begin I := PW(2); If I > 2 Then I := 0; Rg[0] := StBxIorec + I * 14; End;
  15: Rg[0] := 0;
  16: Rg[0] := StBxKeyt;
  22: Rg[0] := 0;
  23: Begin
       GetDate(Y, Mo, D, Dw); GetTime(Hh, Mi, Se, Hs);
       Rg[0] := ((LongInt(Y) - 1980) Shl 25) Or (LongInt(Mo) Shl 21) Or (LongInt(D) Shl 16) Or
                (LongInt(Hh) Shl 11) Or (LongInt(Mi) Shl 5) Or (LongInt(Se) Div 2);
      End;
  24: Rg[0] := 0;
  26, 27: Rg[0] := 0;
  28: Begin
       I := PW(4);
       If (I And $80) <> 0 Then StGi[I And 15] := PW(2) And $FF;
       Rg[0] := StGi[I And 15];
      End;
  29: Begin StGi[14] := StGi[14] And (PW(2) And $FF); Rg[0] := 0; End;
  30: Begin StGi[14] := StGi[14] Or (PW(2) And $FF); Rg[0] := 0; End;
  31, 32, 36: Rg[0] := 0;
  33: Begin Rg[0] := StPrt; If SmallInt(PW(2)) >= 0 Then StPrt := PW(2); End;
  34: Rg[0] := StBxKbdv;
  35: Begin
       Rg[0] := StKbRate;
       If SmallInt(PW(2)) >= 0 Then StKbRate := ((PW(2) And $FF) Shl 8) Or (PW(4) And $FF);
      End;
 Else StXbios := False;
 End;
End;


{ ---- ecran bitmap : terminal VT52 (80 x 25 cellules de 8 x 16) et dessin dans l'onglet ---- }
Procedure StShowGfx;
Begin
 StGfx := True;
 StFirst := True;
 StCX := 0; StCY := 0; StEsc := 0; StRev := False;
 CheckFonts;
 FillChar(StShadow, SizeOf(StShadow), $A5);
End;

Procedure StGlyph(Col, Row: Integer; Ch: Byte);
Var Y: Integer; B: Byte;
Begin
 If (Col < 0) Or (Col >= 80) Or (Row < 0) Or (Row >= 25) Then Exit;
 For Y := 0 To 15 Do Begin
  B := Font8[Ch, Y Shr 1];
  If StRev Then B := Not B;
  Wr8(StScrBase + LongInt(Row * 16 + Y) * 80 + Col, B);
 End;
End;

Procedure StScrollUp;
Begin
 Move(M68K_Mem[StScrBase + 16 * 80], M68K_Mem[StScrBase], 24 * 16 * 80);
 FillChar(M68K_Mem[StScrBase + 24 * 16 * 80], 16 * 80, 0);
End;

Procedure StClearRows(R1, R2: Integer);
Begin
 If R1 < 0 Then R1 := 0;
 If R2 > 24 Then R2 := 24;
 If R2 >= R1 Then FillChar(M68K_Mem[StScrBase + LongInt(R1) * 16 * 80], (R2 - R1 + 1) * 16 * 80, 0);
End;

Procedure StNewLine;
Begin
 Inc(StCY);
 If StCY > 24 Then Begin StScrollUp; StCY := 24; End;
End;

{ sortie console VT52 sur l'ecran bitmap (sous-ensemble : ESC A B C D E H J K Y p q) }
Procedure StConPut(C: Byte);
Var I: Integer; Sv: Boolean;
Begin
 If StEsc = 1 Then Begin
  StEsc := 0;
  Case Chr(C) Of
   'A': If StCY > 0 Then Dec(StCY);
   'B': If StCY < 24 Then Inc(StCY);
   'C': If StCX < 79 Then Inc(StCX);
   'D': If StCX > 0 Then Dec(StCX);
   'E': Begin StClearRows(0, 24); StCX := 0; StCY := 0; End;
   'H': Begin StCX := 0; StCY := 0; End;
   'J': Begin
         Sv := StRev; StRev := False;
         For I := StCX To 79 Do StGlyph(I, StCY, 32);
         StClearRows(StCY + 1, 24); StRev := Sv;
        End;
   'K': Begin Sv := StRev; StRev := False; For I := StCX To 79 Do StGlyph(I, StCY, 32); StRev := Sv; End;
   'Y': StEsc := 2;
   'p': StRev := True;
   'q': StRev := False;
   'b', 'c': StEsc := 4;
  End;
  Exit;
 End;
 If StEsc = 2 Then Begin StEscA := C - 32; StEsc := 3; Exit; End;
 If StEsc = 3 Then Begin
  StEsc := 0;
  StCY := Clamp(StEscA, 0, 24); StCX := Clamp(C - 32, 0, 79);
  Exit;
 End;
 If StEsc = 4 Then Begin StEsc := 0; Exit; End;
 Case C Of
  27: StEsc := 1;
  13: StCX := 0;
  10: StNewLine;
  8: If StCX > 0 Then Dec(StCX);
  9: StCX := (StCX + 8) And Not 7;
  7: ;
 Else
  If C >= 32 Then Begin
   If StCX > 79 Then Begin StCX := 0; StNewLine; End;
   StGlyph(StCX, StCY, C);
   Inc(StCX);
   If StCX > 79 Then Begin StCX := 0; StNewLine; End;
  End;
 End;
 If StCX > 79 Then StCX := 79;
End;

{ sorties console GEMDOS/BIOS redirigees vers l'ecran bitmap quand il est affiche ; True si la fonction est traitee }
Function StConTrap(N: Integer): Boolean;
Var Fn: Word; A, Cnt: LongInt; H: Integer;
Begin
 StConTrap := False;
 Fn := Rd16(Rg[15]);
 If N = 1 Then Begin
  Case Fn Of
   2: Begin StConPut(PW(2) And $FF); Rg[0] := 0; StConTrap := True; End;
   6: If PW(2) <> $FF Then Begin StConPut(PW(2) And $FF); Rg[0] := 0; StConTrap := True; End;
   9: Begin
       A := PL(2);
       While (Rd8(A) <> 0) Do Begin StConPut(Rd8(A)); Inc(A); End;
       Rg[0] := 0; StConTrap := True;
      End;
   $40: Begin
         H := SmallInt(PW(2));
         If (H = 1) Or (H = 2) Or (H = 0) Or (H < 0) Then Begin
          Cnt := PL(4); A := PL(8);
          While Cnt > 0 Do Begin StConPut(Rd8(A)); Inc(A); Dec(Cnt); End;
          Rg[0] := PL(4); StConTrap := True;
         End;
        End;
  End;
 End Else If (N = 13) And (Fn = 3) And (PW(2) = 2) Then Begin
  StConPut(PW(4) And $FF); Rg[0] := 0; StConTrap := True;
 End;
End;

{ dessin de l'ecran bitmap dans l'onglet (seuls les octets modifies sont redessines) }
Procedure StDraw(Var P: TEmulatorPanel);
Var Y, XB, Bit, GX, GY: Integer; B, O: Byte; A: LongInt; Full: Boolean;
Begin
 Full := StFirst;
 P.PanelX := 0;
 P.PanelY := MENUBAR_HEIGHT + TOOLBAR_HEIGHT + TAB_HEIGHT;
 GX := P.PanelX; GY := P.PanelY + 22;
 If StFirst Then Begin
  DrawFilledRect(P.PanelX - 2, P.PanelY - 2, P.PanelX + SW + 2, P.PanelY + 22 + SH + 2, CLR_BACKGROUND);
  StFirst := False;
 End;
 DrawFilledRect(P.PanelX, P.PanelY, P.PanelX + SW, P.PanelY + 20, CLR_TITLEBAR_ACTIVE);
 DrawText(P.PanelX + 6, P.PanelY + 4, 'Atari ST 640x400   PC=$' + M68K_HexN(M68K_PC, 6), CLR_HIGHLIGHTTEXT);
 DrawText(P.PanelX + SW - 60, P.PanelY + 4, '[Esc]', CLR_HIGHLIGHTTEXT);
 A := StScrBase;
 For Y := 0 To SH - 1 Do
  For XB := 0 To 79 Do Begin
   B := M68K_Mem[A + LongInt(Y) * 80 + XB];
   O := StShadow[Y * 80 + XB];
   If Full Then O := Not B;      { premiere image : tous les points sont dessines }
   If B <> O Then Begin
    StShadow[Y * 80 + XB] := B;
    For Bit := 0 To 7 Do
     If ((B Xor O) And (128 Shr Bit)) <> 0 Then Begin
      If (B And (128 Shr Bit)) <> 0 Then PutPixel(GX + XB * 8 + Bit, GY + Y, CLR_EDITOR_TEXT)
      Else PutPixel(GX + XB * 8 + Bit, GY + Y, 15);
     End;
   End;
  End;
 P.LastGridW := SW;
 P.LastGridH := 22 + SH;
End;

{ appele par DrawEmulatorPanel : dessine l'ecran bitmap s'il est affiche ; retourne True dans ce cas }
Function StDrawIfGfx(Var P: TEmulatorPanel): Boolean;
Begin
 StDrawIfGfx := StGfx;
 If StGfx Then StDraw(P);
End;

{ TRAP #n : les services Atari ST (GEMDOS, AES/VDI, BIOS, XBIOS) sont ceux de M68K_DoTrap }
Procedure DoTrap(N: Integer);
Begin
 { GEMDOS, BIOS et XBIOS de l'ST : implementation complete ci-dessus ; le reste (console, Pterm, AES/VDI) : M68K_DoTrap }
 If StGfx And StConTrap(N) Then Exit;
 If (N = 1) And StGemdos Then Exit;
 If (N = 13) And StBios Then Exit;
 If (N = 14) And ((Rd16(Rg[15]) = 2) Or (Rd16(Rg[15]) = 3)) Then Begin
  { Physbase / Logbase : le programme va dessiner : l'ecran bitmap remplace le texte }
  If Not StGfx Then StShowGfx;
  Rg[0] := StScrBase;
  Exit;
 End;
 If (N = 14) And StXbios Then Exit;
 StCpuStore;
 M68K_DoTrap(N);
 StCpuLoad;
 If M68K_Halted And (StopReason = STOP_NONE) Then Begin
  StopReason := STOP_EXIT;
  ExitCode := M68K_ExitCode;
 End;
End;

Procedure DoLineA(Op: LongInt);
Begin
 If Not StGfx Then StShowGfx;
 LaDispatch(Op And $FFF);
End;

Procedure HleLibCheck;
Begin
End;

Procedure IrqCheck;
Begin
End;

{ prepare le noyau a partir de l'etat M68K_* (appele au chargement du programme) }
Procedure StCpuInit;
Var AddrErrI: Integer;
Begin
 StNBlks := 0;
 For AddrErrI := 6 To 21 Do StFUsed[AddrErrI] := False;
 StCwd := '\\';
 StDrv := 2;
 StRoot := '';
 StDta := StBasePage + $80;
 StClockAdj := 0;
 StBxInit := False;
 StGfx := False;
 FloodCol := 1;
 MouseHidden := 0;
 SingleStack := True;
 M68K_A[7] := StUserSP;
 Rg[15] := StUserSP;
 MonTrap := False;
 PendVec := -1;
 NBps := 0;
 TraceOver := False;
 StopReason := STOP_NONE;
 StopMsg := '';
 ExitCode := 0;
 InstrCount := 0;
 AddrErr := False;
 BusErr := False;
End;

{ execute au plus N instructions ; positionne M68K_Halted quand le programme se termine }
Procedure StCpuRun(Var P: TEmulatorPanel; N: LongInt);
Var K: LongInt;
Begin
 StCpuLoad;
 StopReason := STOP_NONE;
 K := 0;
 While (StopReason = STOP_NONE) And (K < N) And (Not M68K_Halted) Do Begin
  Step;
  Inc(K);
 End;
 StCpuStore;
 Inc(P.TotalSteps, K);
 Inc(M68K_Cycles, K);
 If StopReason <> STOP_NONE Then Begin
  If StopReason = STOP_FAULT Then Begin
   EmuVScr_PutChar(P, #13); EmuVScr_PutChar(P, #10);
   P.CurFg := 12;
   EmuVScr_WriteStr(P, StopMsg);
   P.CurFg := 7;
   M68K_ExitCode := 1;
  End;
  M68K_Halted := True;
 End;
End;
'''
def main(devpac,devenv):
    s=open(devpac,encoding='latin-1').read()
    i=s.index('{                      EMULATEUR MOTOROLA 68000                          }')
    i=s.rindex('{ ====',0,i)
    j=s.index('Function IsBreakpoint(A: LongInt): Boolean;')
    region=s[i:j]
    # le 'Forward' de DoTrap etc. est satisfait par TAIL
    # ligne A : polices, variables, primitives et TEXTBLT de DEVPAC.PAS (memes sources que les tests)
    la0=s.index('Procedure LineAFontHeader')
    la1=s.index('Procedure DoLineA(Op: LongInt);\nVar F: Integer; Col: Integer;')
    la=s[la0:la1]
    la=la.replace(' CheckFonts;\n','').replace('Wr32(LINEA_VARS-$22,DrawBase)','Wr32(LINEA_VARS-$22,StScrBase)')
    a15=la.index('  15: Begin')
    a15e=la.index(' End;\nEnd;',a15)
    la=la[:a15]+'''  15: Begin
       { remplissage par germe : point dans PTSIN }
       Pt:=Rd32(LINEA_VARS+12);
       FloodCol:=LaW(24) And 1;
       SetClip(0,0,SW-1,SH-1);
       If LaW(54)<>0 Then SetClip(LaW(56),LaW(58),LaW(60),LaW(62));
       FloodFill(SExt(Rd16(Pt),2),SExt(Rd16(Pt+2),2),-1);
      End;
'''+la[a15e:]
    font=open(os.path.join(os.path.dirname(os.path.abspath(__file__)),'font8x8_st.txt')).read()
    text=PRELUDE+'\n'+region+'\n'+LA_PRELUDE.replace('@@FONT@@',font)+'\n'+la+'\n'+TAIL
    t,G=pascal_prefix.rename(text,'StCpu_')
    block=BEGIN_MARK+'\n'+t+'\n'+END_MARK+'\n\n'
    d=open(devenv,encoding='latin-1').read()
    if BEGIN_MARK in d:
        a=d.index(BEGIN_MARK); b=d.index(END_MARK)+len(END_MARK)+2
        d=d[:a]+block+d[b:]
    else:
        mark="{ Mode test (-emu:ATARIST avec DEVENV_EMUQUIT)"
        assert d.count(mark)==1
        d=d.replace(mark,block+mark,1)
    open(devenv,'w',encoding='latin-1').write(d)
    print('noyau porte :',len(t.split('\n')),'lignes,',len(G),'identifiants StCpu_')
if __name__=='__main__':
    main(sys.argv[1],sys.argv[2])
