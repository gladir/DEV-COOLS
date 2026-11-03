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
PRELUDE='''
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
TAIL='''
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

{ TRAP #n : les services Atari ST (GEMDOS, AES/VDI, BIOS, XBIOS) sont ceux de M68K_DoTrap }
Procedure DoTrap(N: Integer);
Begin
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
 { ligne A : tolerance (comme l'ancien noyau) jusqu'a l'implementation des primitives }
 Inc(M68K_DbgUnknown);
 M68K_DbgLastBad := CurOpPC;
 Rg[0] := 0;
End;

Procedure HleLibCheck;
Begin
End;

Procedure IrqCheck;
Begin
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
 If (Tl < 0) Or (Dl < 0) Or (Bl < 0) Or (Tb + Tl + Dl + Bl > StHiTpa - $2000) Then Begin Close(F); Exit; End;
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

{ prepare le noyau a partir de l'etat M68K_* (appele au chargement du programme) }
Procedure StCpuInit;
Begin
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
    text=PRELUDE+'\n'+region+'\n'+TAIL
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
