{ ============================================================ }
{ CRAYRUN.PAS - Simulateur minimal Cray-1 pour fichiers .abs  }
{                                                              }
{ Charge un fichier COS Absolute Binary genere par TPCW32 et   }
{ execute les instructions Cray-1 generees par le backend      }
{ DEST_CRAY1. Implemente uniquement le sous-ensemble emis par  }
{ BcAssembleCray1 (Phases 2c-2i).                              }
{                                                              }
{ Opcodes supportes :                                           }
{   $01 ERR    halt erreur                                      }
{   $04 EX     trap COS (j<<3|k = service)                      }
{          0 = print char (S1)                                  }
{          1 = print int (S1)                                   }
{          2 = newline                                          }
{          3 = print string (S1 = adresse parcel)               }
{          7 = halt normal                                      }
{   $05 J      saut absolu imm22                                }
{   $09 JSZ    saut si Si == 0                                  }
{   $0A JSN    saut si Si <> 0                                  }
{   $0B JSP    saut si Si >= 0                                  }
{   $0C JSM    saut si Si < 0                                   }
{   $20 MOVS   Si <- Sj                                         }
{   $30 ADDS   Si <- Sj + Sk                                    }
{   $31 SUBS   Si <- Sj - Sk                                    }
{   $34 ANDS   Si <- Sj AND Sk                                  }
{   $35 XORS   Si <- Sj XOR Sk                                  }
{   $36 ORS    Si <- Sj OR  Sk                                  }
{   $40 LDS    Si <- M(imm22)                                   }
{   $48 STS    M(imm22) <- Si                                   }
{   $60 LDIMM  Si <- imm22 (signe sur 22 bits)                  }
{                                                              }
{ Compilation : fpc -Mtp CRAYRUN.PAS                            }
{ Usage       : CRAYRUN fichier.abs [-PC=N] [-trace]            }
{ ============================================================ }
Program CrayRun;

Const
  MAX_PARCELS = 65536;
  HALT_OK     = 0;
  HALT_ERR    = 1;

Type
  TParcel = Word;

Var
  Mem      : Array[0..MAX_PARCELS - 1] Of TParcel;
  Reg      : Array[0..7] Of LongInt;          { S0..S7, S0=0 }
  PC       : LongInt;                          { compteur en parcels }
  CodeWords, DataWords, EntryAddr : LongInt;
  TotalParcels : LongInt;
  Trace    : Boolean;
  Running  : Boolean;
  ExitCode : Integer;
  StartPC  : LongInt;
  PCSpec   : Boolean;

{ -- Lecture mot 64 bits big-endian -- }
Function Read64BE(Var F: File): LongInt;
Var
  W: Array[0..7] Of Byte;
Begin
  BlockRead(F, W, 8);
  { On suppose la valeur tient dans 32 bits (LongInt) }
  Read64BE := (LongInt(W[4]) Shl 24) Or (LongInt(W[5]) Shl 16) Or
              (LongInt(W[6]) Shl 8) Or LongInt(W[7]);
End;

Procedure LoadAbs(Const FileName: String);
Var
  F: File;
  Sig: Array[0..7] Of Byte;
  PB: Array[0..1] Of Byte;
  I: LongInt;
Begin
  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('Erreur : impossible d''ouvrir ', FileName);
    Halt(2);
  End;

  BlockRead(F, Sig, 8);
  If (Sig[0] <> Ord('C')) Or (Sig[1] <> Ord('R')) Or
     (Sig[2] <> Ord('A')) Or (Sig[3] <> Ord('Y')) Or
     (Sig[4] <> Ord('-')) Or (Sig[5] <> Ord('1')) Then
  Begin
    WriteLn('Erreur : signature CRAY-1 absente.');
    Close(F);
    Halt(3);
  End;

  CodeWords  := Read64BE(F);
  DataWords  := Read64BE(F);
  EntryAddr  := Read64BE(F);

  TotalParcels := (CodeWords + DataWords) * 4;
  If TotalParcels > MAX_PARCELS Then
  Begin
    WriteLn('Erreur : image trop grande (', TotalParcels, ' parcels).');
    Close(F);
    Halt(4);
  End;

  For I := 0 To MAX_PARCELS - 1 Do Mem[I] := 0;

  For I := 0 To TotalParcels - 1 Do
  Begin
    BlockRead(F, PB, 2);
    Mem[I] := (Word(PB[0]) Shl 8) Or Word(PB[1]);
  End;
  Close(F);

  WriteLn('[CRAYRUN] ', FileName, ' charge : ',
          CodeWords, ' code words, ', DataWords, ' data words, entry $',
          HexStr(EntryAddr, 4));
End;

{ Sign-extend 22 bits vers LongInt }
Function SignExt22(V: LongInt): LongInt;
Begin
  V := V And $3FFFFF;
  If (V And $200000) <> 0 Then
    SignExt22 := V Or LongInt($FFC00000)
  Else
    SignExt22 := V;
End;

Procedure PrintInt(V: LongInt);
Begin
  Write(V);
End;

Procedure DoTrap(Service: Integer);
Var
  Addr: LongInt;
  C: Byte;
Begin
  Case Service Of
    0: { print char S1 }
       Write(Chr(Reg[1] And $FF));
    1: { print int S1 }
       PrintInt(Reg[1]);
    2: { newline }
       WriteLn;
    3: { print string : S1 = adresse parcel, octet par parcel jusqu'a 0 }
       Begin
         Addr := Reg[1] And $FFFF;
         While Addr < MAX_PARCELS Do
         Begin
           C := Mem[Addr] And $FF;
           If C = 0 Then Break;
           Write(Chr(C));
           Inc(Addr);
         End;
       End;
    7: { halt normal }
       Begin Running := False; ExitCode := HALT_OK; End;
  Else
    WriteLn;
    WriteLn('[CRAYRUN] Trap service inconnu : ', Service, ' au PC $',
            HexStr(PC, 4));
  End;
End;

Procedure Step;
Var
  P0, P1: TParcel;
  Op, I, J, K: Integer;
  Imm22: LongInt;
  Service: Integer;
Begin
  If (PC < 0) Or (PC >= MAX_PARCELS) Then
  Begin
    WriteLn;
    WriteLn('[CRAYRUN] PC hors limites : $', HexStr(PC, 4));
    Running := False;
    ExitCode := HALT_ERR;
    Exit;
  End;
  P0 := Mem[PC];
  Op := (P0 Shr 9) And $7F;
  I  := (P0 Shr 6) And $07;
  J  := (P0 Shr 3) And $07;
  K  := P0 And $07;

  If Trace Then
    WriteLn('[T] PC=$', HexStr(PC, 4), ' P0=', HexStr(P0, 4),
            ' op=$', HexStr(Op, 2), ' i=', I, ' j=', J, ' k=', K,
            ' S1=', Reg[1]);

  Case Op Of
    $01: { ERR }
      Begin
        WriteLn;
        WriteLn('[CRAYRUN] ERR rencontre au PC $', HexStr(PC, 4));
        Running := False;
        ExitCode := HALT_ERR;
      End;

    $04: { EX trap }
      Begin
        Service := (J Shl 3) Or K;
        DoTrap(Service);
        Inc(PC);
      End;

    $05, $09, $0A, $0B, $0C: { jumps format2 imm22 }
      Begin
        P1 := Mem[PC + 1];
        Imm22 := ((LongInt(J) Shl 19) Or (LongInt(K) Shl 16) Or P1) And $3FFFFF;
        Case Op Of
          $05: PC := Imm22;                                 { J }
          $09: If Reg[I] = 0 Then PC := Imm22 Else PC := PC + 2; { JSZ }
          $0A: If Reg[I] <> 0 Then PC := Imm22 Else PC := PC + 2; { JSN }
          $0B: If Reg[I] >= 0 Then PC := Imm22 Else PC := PC + 2; { JSP }
          $0C: If Reg[I] < 0 Then PC := Imm22 Else PC := PC + 2;  { JSM }
        End;
      End;

    $20: { MOVS Si <- Sj }
      Begin Reg[I] := Reg[J]; If I = 0 Then Reg[0] := 0; Inc(PC); End;

    $30: { ADDS }
      Begin Reg[I] := Reg[J] + Reg[K]; If I = 0 Then Reg[0] := 0; Inc(PC); End;
    $31: { SUBS }
      Begin Reg[I] := Reg[J] - Reg[K]; If I = 0 Then Reg[0] := 0; Inc(PC); End;
    $34: { ANDS }
      Begin Reg[I] := Reg[J] And Reg[K]; If I = 0 Then Reg[0] := 0; Inc(PC); End;
    $35: { XORS }
      Begin Reg[I] := Reg[J] Xor Reg[K]; If I = 0 Then Reg[0] := 0; Inc(PC); End;
    $36: { ORS }
      Begin Reg[I] := Reg[J] Or Reg[K]; If I = 0 Then Reg[0] := 0; Inc(PC); End;

    $40: { LDS Si <- M(imm22) }
      Begin
        P1 := Mem[PC + 1];
        Imm22 := ((LongInt(J) Shl 19) Or (LongInt(K) Shl 16) Or P1) And $3FFFFF;
        If Imm22 < MAX_PARCELS Then
          Reg[I] := SmallInt(Mem[Imm22])  { lecture 16-bit signe pour test }
        Else
          Reg[I] := 0;
        If I = 0 Then Reg[0] := 0;
        PC := PC + 2;
      End;

    $48: { STS M(imm22) <- Si }
      Begin
        P1 := Mem[PC + 1];
        Imm22 := ((LongInt(J) Shl 19) Or (LongInt(K) Shl 16) Or P1) And $3FFFFF;
        If Imm22 < MAX_PARCELS Then
          Mem[Imm22] := Reg[I] And $FFFF;
        PC := PC + 2;
      End;

    $60: { LDIMM Si <- imm22 sign-extend }
      Begin
        P1 := Mem[PC + 1];
        Imm22 := (LongInt(J) Shl 19) Or (LongInt(K) Shl 16) Or P1;
        Reg[I] := SignExt22(Imm22);
        If I = 0 Then Reg[0] := 0;
        PC := PC + 2;
      End;

  Else
    WriteLn;
    WriteLn('[CRAYRUN] Opcode non implemente : $', HexStr(Op, 2),
            ' au PC $', HexStr(PC, 4), ' (parcel ', HexStr(P0, 4), ')');
    Running := False;
    ExitCode := HALT_ERR;
  End;
End;

Procedure Run;
Var
  StepCount: LongInt;
Begin
  Reg[0] := 0;
  PC := StartPC;
  Running := True;
  ExitCode := HALT_OK;
  StepCount := 0;
  While Running And (StepCount < 1000000) Do
  Begin
    Step;
    Inc(StepCount);
  End;
  If StepCount >= 1000000 Then
  Begin
    WriteLn;
    WriteLn('[CRAYRUN] Limite d''instructions atteinte (', StepCount, ').');
    ExitCode := HALT_ERR;
  End
  Else If Trace Then
    WriteLn('[CRAYRUN] Termine apres ', StepCount, ' instructions.');
End;

Var
  FileName: String;
  Arg     : String;
  N, Code : Integer;
  V       : LongInt;
Begin
  Trace    := False;
  PCSpec   := False;
  StartPC  := 0;
  FileName := '';

  For N := 1 To ParamCount Do
  Begin
    Arg := ParamStr(N);
    If (Arg = '-trace') Or (Arg = '-TRACE') Then
      Trace := True
    Else If (Copy(Arg, 1, 4) = '-PC=') Or (Copy(Arg, 1, 4) = '-pc=') Then
    Begin
      Val(Copy(Arg, 5, 32), V, Code);
      If Code = 0 Then Begin StartPC := V; PCSpec := True; End;
    End
    Else
      FileName := Arg;
  End;

  If FileName = '' Then
  Begin
    WriteLn('Usage : CRAYRUN fichier.abs [-PC=N] [-trace]');
    Halt(1);
  End;

  LoadAbs(FileName);

  If Not PCSpec Then StartPC := 0; { execute le code utilisateur a parcel 0 }

  WriteLn('[CRAYRUN] Demarrage execution PC=$', HexStr(StartPC, 4));
  WriteLn('-------- sortie programme --------');
  Run;
  WriteLn;
  WriteLn('---------- fin sortie ------------');
  WriteLn('[CRAYRUN] Code retour : ', ExitCode);
  Halt(ExitCode);
End.
