{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Emulateur Motorola 68000
                Charge et execute du code objet S-Record genere par ASM68
}

{ ---------------------------------------------------------------------------- }
{  ARCHITECTURE GENERALE                                                       }
{ ---------------------------------------------------------------------------- }
{  1. Memoire    : tableau de 1 Mo, acces big-endian (Read8/16/32, Write8/16/32)}
{  2. Registres  : D0-D7 (donnees), A0-A7 (adresses), PC, SR                  }
{  3. Decodage   : EA (mode/reg), conditions, tailles                          }
{  4. Instructions: MOVE, ADD, SUB, CMP, AND, OR, EOR, MULU, MULS, DIVU, DIVS }
{                  Shift/Rotate, Bcc, BSR, JMP, JSR, RTS, TRAP, MOVEM, LEA ... }
{  5. TRAP #15   : convention Easy68k (D0=9 halt, D0=14 print, D0=13 printnum) }
{  6. Chargement : fichier S-Record (S0, S1, S5, S9)                           }
{ ---------------------------------------------------------------------------- }

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

Program M68K_EMU;

Const
  MEM_SIZE   = $100000;    { 1 Mo }
  MAX_CYCLES = 100000;
  CCR_C      = $01;        { Carry }
  CCR_V      = $02;        { Overflow }
  CCR_Z      = $04;        { Zero }
  CCR_N      = $08;        { Negative }
  CCR_X      = $10;        { Extend }

Var
  D:         Array[0..7] of LongInt;  { Data registers D0-D7 }
  A:         Array[0..7] of LongInt;  { Address registers A0-A7 }
  PC:        LongInt;                 { Program counter }
  SR:        Word;                    { Status register }
  Mem:       Array[0..MEM_SIZE-1] of Byte;
  Halted:    Boolean;
  ExitCode_: Integer;
  Verbose:   Boolean;
  Cycles:    LongInt;

{ ========================================================================== }
{  Utilitaires 32 bits                                                       }
{ ========================================================================== }

Function And32(a, b: LongInt): LongInt;
Begin
  And32 := a And b;
End;

Function Or32(a, b: LongInt): LongInt;
Begin
  Or32 := a Or b;
End;

Function Xor32(a, b: LongInt): LongInt;
Begin
  Xor32 := a Xor b;
End;

Function Not32(a: LongInt): LongInt;
Begin
  Not32 := Not a;
End;

Function Shl32(a: LongInt; n: Integer): LongInt;
Begin
  If n >= 32 Then
    Shl32 := 0
  Else If n = 0 Then
    Shl32 := a
  Else
    Shl32 := LongInt(a Shl n);
End;

Function Shr32(a: LongInt; n: Integer): LongInt;
Begin
  If n >= 32 Then
    Shr32 := 0
  Else If n = 0 Then
    Shr32 := a
  Else
    { Logical shift right - cast to unsigned-like behavior }
    Shr32 := LongInt((a Shr 1) And $7FFFFFFF) Shr (n - 1);
End;

{ Mask to N bits (unsigned) }
Function Mask32(v: LongInt): LongInt;
Begin
  Mask32 := v; { LongInt is already 32-bit; wraps naturally }
End;

{ ========================================================================== }
{  Acces memoire (big-endian, adresses sur 20 bits)                          }
{ ========================================================================== }

Function Read8(addr: LongInt): Byte;
Begin
  addr := addr And LongInt(MEM_SIZE - 1);
  Read8 := Mem[addr];
End;

Function Read16(addr: LongInt): Word;
Begin
  addr := addr And LongInt(MEM_SIZE - 1);
  Read16 := Word(Mem[addr]) Shl 8 Or Mem[addr + 1];
End;

Function Read32(addr: LongInt): LongInt;
Begin
  addr := addr And LongInt(MEM_SIZE - 1);
  Read32 := LongInt(Mem[addr]) Shl 24 Or
            LongInt(Mem[addr + 1]) Shl 16 Or
            LongInt(Mem[addr + 2]) Shl 8 Or
            LongInt(Mem[addr + 3]);
End;

Procedure Write8(addr: LongInt; val: Byte);
Begin
  addr := addr And LongInt(MEM_SIZE - 1);
  Mem[addr] := val And $FF;
End;

Procedure Write16(addr: LongInt; val: Word);
Begin
  addr := addr And LongInt(MEM_SIZE - 1);
  Mem[addr]     := Byte(val Shr 8);
  Mem[addr + 1] := Byte(val And $FF);
End;

Procedure Write32(addr, val: LongInt);
Var
  a: LongInt;
Begin
  a := addr And LongInt(MEM_SIZE - 1);
  Mem[a]     := Byte(Shr32(val, 24) And $FF);
  Mem[a + 1] := Byte(Shr32(val, 16) And $FF);
  Mem[a + 2] := Byte(Shr32(val, 8) And $FF);
  Mem[a + 3] := Byte(val And $FF);
End;

{ ========================================================================== }
{  Registres avec masquage                                                   }
{ ========================================================================== }

Function GetD(n, size: Integer): LongInt;
Begin
  Case size Of
    1: GetD := D[n] And $FF;
    2: GetD := D[n] And $FFFF;
  Else
    GetD := D[n];
  End;
End;

Procedure SetD(n: Integer; val: LongInt; size: Integer);
Begin
  Case size Of
    1: D[n] := (D[n] And LongInt($FFFFFF00)) Or (val And $FF);
    2: D[n] := (D[n] And LongInt($FFFF0000)) Or (val And $FFFF);
  Else
    D[n] := val;
  End;
End;

Function SignExtend(val: LongInt; size: Integer): LongInt;
Begin
  Case size Of
    1: Begin
         val := val And $FF;
         If val And $80 <> 0 Then
           SignExtend := val Or LongInt($FFFFFF00)
         Else
           SignExtend := val;
       End;
    2: Begin
         val := val And $FFFF;
         If val And $8000 <> 0 Then
           SignExtend := val Or LongInt($FFFF0000)
         Else
           SignExtend := val;
       End;
  Else
    SignExtend := val;
  End;
End;

Function ToSigned(val: LongInt; size: Integer): LongInt;
Begin
  Case size Of
    1: Begin
         val := val And $FF;
         If val And $80 <> 0 Then
           ToSigned := val - $100
         Else
           ToSigned := val;
       End;
    2: Begin
         val := val And $FFFF;
         If val And $8000 <> 0 Then
           ToSigned := val - $10000
         Else
           ToSigned := val;
       End;
  Else
    ToSigned := val; { Already signed 32-bit }
  End;
End;

Function SizeMask(size: Integer): LongInt;
Begin
  Case size Of
    1: SizeMask := $FF;
    2: SizeMask := $FFFF;
  Else
    SizeMask := LongInt($FFFFFFFF);
  End;
End;

Function SignBit(size: Integer): LongInt;
Begin
  Case size Of
    1: SignBit := $80;
    2: SignBit := $8000;
  Else
    SignBit := LongInt($80000000);
  End;
End;

{ ========================================================================== }
{  CCR (Condition Code Register)                                             }
{ ========================================================================== }

Procedure SetFlagsNZ(val: LongInt; size: Integer);
Var
  msk, sgn: LongInt;
  v: LongInt;
Begin
  msk := SizeMask(size);
  sgn := SignBit(size);
  v := val And msk;
  SR := SR And (Not (CCR_N Or CCR_Z));
  If v = 0 Then
    SR := SR Or CCR_Z;
  If v And sgn <> 0 Then
    SR := SR Or CCR_N;
End;

Procedure SetFlagsNZVC(result: LongInt; size: Integer; carry, overflow: Boolean);
Begin
  SetFlagsNZ(result, size);
  SR := SR And (Not (CCR_V Or CCR_C));
  If carry Then
    SR := SR Or CCR_C;
  If overflow Then
    SR := SR Or CCR_V;
End;

{ ========================================================================== }
{  Lecture instruction                                                        }
{ ========================================================================== }

Function Fetch16: Word;
Var
  v: Word;
Begin
  v := Read16(PC);
  PC := PC + 2;
  Fetch16 := v;
End;

{ ========================================================================== }
{  Taille par champ de bits                                                   }
{ ========================================================================== }

Function OpSize(bits: Integer): Integer;
Begin
  Case bits Of
    0: OpSize := 1;
    1: OpSize := 2;
    2: OpSize := 4;
  Else
    OpSize := 2; { fallback }
  End;
End;

{ ========================================================================== }
{  Evaluation des conditions                                                  }
{ ========================================================================== }

Function TestCC(cc: Integer): Boolean;
Var
  C, V, Z, N: Boolean;
Begin
  C := (SR And CCR_C) <> 0;
  V := (SR And CCR_V) <> 0;
  Z := (SR And CCR_Z) <> 0;
  N := (SR And CCR_N) <> 0;
  Case cc Of
     0: TestCC := True;
     1: TestCC := False;
     2: TestCC := (Not C) And (Not Z);
     3: TestCC := C Or Z;
     4: TestCC := Not C;
     5: TestCC := C;
     6: TestCC := Not Z;
     7: TestCC := Z;
     8: TestCC := Not V;
     9: TestCC := V;
    10: TestCC := Not N;
    11: TestCC := N;
    12: TestCC := N = V;
    13: TestCC := N <> V;
    14: TestCC := (Not Z) And (N = V);
    15: TestCC := Z Or (N <> V);
  Else
    TestCC := False;
  End;
End;

{ ========================================================================== }
{  Lecture/Ecriture EA (Effective Address)                                    }
{ ========================================================================== }

{ ReadMem helper for a given size }
Function ReadMem(addr: LongInt; size: Integer): LongInt;
Begin
  Case size Of
    1: ReadMem := Read8(addr);
    2: ReadMem := Read16(addr);
  Else
    ReadMem := Read32(addr);
  End;
End;

Procedure WriteMem(addr, val: LongInt; size: Integer);
Begin
  Case size Of
    1: Write8(addr, Byte(val And $FF));
    2: Write16(addr, Word(val And $FFFF));
  Else
    Write32(addr, val);
  End;
End;

Function ReadEA(mode, reg, size: Integer; Var addr: LongInt): LongInt;
Var
  inc_, dec_: Integer;
  disp: LongInt;
  ext: Word;
  idx_reg: Integer;
  idx_is_a, idx_long: Boolean;
  idx_val: LongInt;
  pc_save: LongInt;
  hi, lo: Word;
Begin
  addr := -1; { default: register mode }
  Case mode Of
    0: { Dn }
      ReadEA := GetD(reg, size);
    1: { An }
      ReadEA := A[reg];
    2: Begin { (An) }
         addr := A[reg];
         ReadEA := ReadMem(addr, size);
       End;
    3: Begin { (An)+ }
         addr := A[reg];
         ReadEA := ReadMem(addr, size);
         If size = 1 Then Begin
           If reg = 7 Then inc_ := 2 Else inc_ := 1;
         End Else If size = 2 Then
           inc_ := 2
         Else
           inc_ := 4;
         A[reg] := A[reg] + inc_;
       End;
    4: Begin { -(An) }
         If size = 1 Then Begin
           If reg = 7 Then dec_ := 2 Else dec_ := 1;
         End Else If size = 2 Then
           dec_ := 2
         Else
           dec_ := 4;
         A[reg] := A[reg] - dec_;
         addr := A[reg];
         ReadEA := ReadMem(addr, size);
       End;
    5: Begin { d16(An) }
         disp := SignExtend(Fetch16, 2);
         addr := A[reg] + disp;
         ReadEA := ReadMem(addr, size);
       End;
    6: Begin { d8(An,Xn) }
         ext := Fetch16;
         disp := SignExtend(ext And $FF, 1);
         idx_reg := (ext Shr 12) And 7;
         idx_is_a := (ext And $8000) <> 0;
         idx_long := (ext And $0800) <> 0;
         If idx_is_a Then
           idx_val := A[idx_reg]
         Else
           idx_val := D[idx_reg];
         If Not idx_long Then
           idx_val := SignExtend(idx_val And $FFFF, 2);
         addr := A[reg] + disp + idx_val;
         ReadEA := ReadMem(addr, size);
       End;
    7: Begin { Special modes }
         Case reg Of
           0: Begin { xxx.W }
                addr := SignExtend(Fetch16, 2);
                ReadEA := ReadMem(addr, size);
              End;
           1: Begin { xxx.L }
                hi := Fetch16;
                lo := Fetch16;
                addr := LongInt(hi) Shl 16 Or lo;
                ReadEA := ReadMem(addr, size);
              End;
           2: Begin { d16(PC) }
                pc_save := PC;
                disp := SignExtend(Fetch16, 2);
                addr := pc_save + disp;
                ReadEA := ReadMem(addr, size);
              End;
           3: Begin { d8(PC,Xn) }
                pc_save := PC;
                ext := Fetch16;
                disp := SignExtend(ext And $FF, 1);
                idx_reg := (ext Shr 12) And 7;
                idx_is_a := (ext And $8000) <> 0;
                idx_long := (ext And $0800) <> 0;
                If idx_is_a Then
                  idx_val := A[idx_reg]
                Else
                  idx_val := D[idx_reg];
                If Not idx_long Then
                  idx_val := SignExtend(idx_val And $FFFF, 2);
                addr := pc_save + disp + idx_val;
                ReadEA := ReadMem(addr, size);
              End;
           4: Begin { #imm }
                If size = 1 Then
                  ReadEA := Fetch16 And $FF
                Else If size = 2 Then
                  ReadEA := Fetch16
                Else Begin
                  hi := Fetch16;
                  lo := Fetch16;
                  ReadEA := LongInt(hi) Shl 16 Or lo;
                End;
              End;
         Else
           ReadEA := 0;
         End;
       End;
  Else
    ReadEA := 0;
  End;
End;

Procedure WriteEA(mode, reg: Integer; val: LongInt; size: Integer);
Var
  inc_, dec_: Integer;
  disp: LongInt;
  addr: LongInt;
  hi, lo: Word;
Begin
  Case mode Of
    0: SetD(reg, val, size);
    1: A[reg] := val;
    2: WriteMem(A[reg], val, size);
    3: Begin { (An)+ }
         WriteMem(A[reg], val, size);
         If size = 1 Then Begin
           If reg = 7 Then inc_ := 2 Else inc_ := 1;
         End Else If size = 2 Then
           inc_ := 2
         Else
           inc_ := 4;
         A[reg] := A[reg] + inc_;
       End;
    4: Begin { -(An) }
         If size = 1 Then Begin
           If reg = 7 Then dec_ := 2 Else dec_ := 1;
         End Else If size = 2 Then
           dec_ := 2
         Else
           dec_ := 4;
         A[reg] := A[reg] - dec_;
         WriteMem(A[reg], val, size);
       End;
    5: Begin { d16(An) }
         disp := SignExtend(Fetch16, 2);
         addr := A[reg] + disp;
         WriteMem(addr, val, size);
       End;
    7: Begin
         Case reg Of
           0: Begin { xxx.W }
                addr := SignExtend(Fetch16, 2);
                WriteMem(addr, val, size);
              End;
           1: Begin { xxx.L }
                hi := Fetch16;
                lo := Fetch16;
                addr := LongInt(hi) Shl 16 Or lo;
                WriteMem(addr, val, size);
              End;
         End;
       End;
  End;
End;

Function CalcEAAddr(mode, reg: Integer): LongInt;
Var
  disp: LongInt;
  ext: Word;
  idx_reg: Integer;
  idx_is_a, idx_long: Boolean;
  idx_val: LongInt;
  pc_save: LongInt;
  hi, lo: Word;
Begin
  Case mode Of
    2: CalcEAAddr := A[reg];
    5: Begin
         disp := SignExtend(Fetch16, 2);
         CalcEAAddr := A[reg] + disp;
       End;
    6: Begin
         ext := Fetch16;
         disp := SignExtend(ext And $FF, 1);
         idx_reg := (ext Shr 12) And 7;
         idx_is_a := (ext And $8000) <> 0;
         idx_long := (ext And $0800) <> 0;
         If idx_is_a Then
           idx_val := A[idx_reg]
         Else
           idx_val := D[idx_reg];
         If Not idx_long Then
           idx_val := SignExtend(idx_val And $FFFF, 2);
         CalcEAAddr := A[reg] + disp + idx_val;
       End;
    7: Begin
         Case reg Of
           0: CalcEAAddr := SignExtend(Fetch16, 2);
           1: Begin
                hi := Fetch16;
                lo := Fetch16;
                CalcEAAddr := LongInt(hi) Shl 16 Or lo;
              End;
           2: Begin
                pc_save := PC;
                disp := SignExtend(Fetch16, 2);
                CalcEAAddr := pc_save + disp;
              End;
           3: Begin
                pc_save := PC;
                ext := Fetch16;
                disp := SignExtend(ext And $FF, 1);
                idx_reg := (ext Shr 12) And 7;
                idx_is_a := (ext And $8000) <> 0;
                idx_long := (ext And $0800) <> 0;
                If idx_is_a Then
                  idx_val := A[idx_reg]
                Else
                  idx_val := D[idx_reg];
                If Not idx_long Then
                  idx_val := SignExtend(idx_val And $FFFF, 2);
                CalcEAAddr := pc_save + disp + idx_val;
              End;
         Else
           CalcEAAddr := 0;
         End;
       End;
  Else
    CalcEAAddr := 0;
  End;
End;

{ ========================================================================== }
{  Convertit un LongInt en chaine hexadecimale de N chiffres                 }
{ ========================================================================== }

Function HexN(v: LongInt; n: Integer): String;
Const
  Digits: String = '0123456789ABCDEF';
Var
  s: String;
  i: Integer;
Begin
  s := '';
  For i := 1 To n Do Begin
    s := Digits[(v And $F) + 1] + s;
    v := Shr32(v, 4);
  End;
  HexN := s;
End;

Function LongToStr(v: LongInt): String;
Var
  s: String;
Begin
  Str(v, s);
  LongToStr := s;
End;

{ ========================================================================== }
{  TRAP #15 handler (convention Easy68k)                                     }
{ ========================================================================== }

Function DoTrap(vector: Integer): Boolean;
Var
  func: Integer;
  adr: LongInt;
  c: Byte;
  i: Integer;
  val: LongInt;
Begin
  DoTrap := True;
  If vector = 15 Then Begin
    func := D[0] And $FF;
    Case func Of
      9: Begin { Halt program }
           If Verbose Then
             WriteLn('  TRAP #15: Fin du programme');
           Halted := True;
           ExitCode_ := 0;
         End;
      14: Begin { Print ASCIZ string at A1 }
            adr := A[1];
            For i := 0 To 4095 Do Begin
              c := Read8(adr + i);
              If c = 0 Then Break;
              Write(Chr(c));
            End;
          End;
      13: Begin { Print D1 as decimal }
            val := ToSigned(D[1], 4);
            Write(val);
          End;
    End;
  End;
End;

{ ========================================================================== }
{  MOVEM                                                                      }
{ ========================================================================== }

Procedure ExecMovem(direction, size, ea_mode, ea_reg: Integer; mask: Word);
Var
  i: Integer;
  val: LongInt;
  addr: LongInt;
Begin
  If direction = 0 Then Begin { Register to memory }
    If ea_mode = 4 Then Begin { -(An) predecrement }
      For i := 15 DownTo 0 Do Begin
        If mask And (1 Shl (15 - i)) <> 0 Then Begin
          If i < 8 Then
            val := D[i]
          Else
            val := A[i - 8];
          A[ea_reg] := A[ea_reg] - size;
          If size = 2 Then
            Write16(A[ea_reg], Word(val And $FFFF))
          Else
            Write32(A[ea_reg], val);
        End;
      End;
    End Else Begin
      addr := CalcEAAddr(ea_mode, ea_reg);
      For i := 0 To 15 Do Begin
        If mask And (1 Shl i) <> 0 Then Begin
          If i < 8 Then
            val := D[i]
          Else
            val := A[i - 8];
          If size = 2 Then
            Write16(addr, Word(val And $FFFF))
          Else
            Write32(addr, val);
          addr := addr + size;
        End;
      End;
    End;
  End Else Begin { Memory to register }
    If ea_mode = 3 Then Begin { (An)+ postincrement }
      addr := A[ea_reg];
      For i := 0 To 15 Do Begin
        If mask And (1 Shl i) <> 0 Then Begin
          If size = 2 Then
            val := SignExtend(Read16(addr), 2)
          Else
            val := Read32(addr);
          If i < 8 Then
            D[i] := val
          Else
            A[i - 8] := val;
          addr := addr + size;
        End;
      End;
      A[ea_reg] := addr;
    End Else Begin
      addr := CalcEAAddr(ea_mode, ea_reg);
      For i := 0 To 15 Do Begin
        If mask And (1 Shl i) <> 0 Then Begin
          If size = 2 Then
            val := SignExtend(Read16(addr), 2)
          Else
            val := Read32(addr);
          If i < 8 Then
            D[i] := val
          Else
            A[i - 8] := val;
          addr := addr + size;
        End;
      End;
    End;
  End;
End;

{ ========================================================================== }
{  MOVE (top4 = 1,2,3)                                                       }
{ ========================================================================== }

Function ExecMove(opcode: Word): Boolean;
Var
  top4: Integer;
  size: Integer;
  src_mode, src_reg, dst_mode, dst_reg: Integer;
  val: LongInt;
  addr: LongInt;
Begin
  ExecMove := True;
  top4 := (opcode Shr 12) And $F;
  Case top4 Of
    1: size := 1;  { MOVE.B }
    3: size := 2;  { MOVE.W }
    2: size := 4;  { MOVE.L }
  Else
    size := 2;
  End;

  src_mode := (opcode Shr 3) And 7;
  src_reg  := opcode And 7;
  dst_reg  := (opcode Shr 9) And 7;
  dst_mode := (opcode Shr 6) And 7;

  val := ReadEA(src_mode, src_reg, size, addr);

  If dst_mode = 1 Then Begin { MOVEA }
    If size = 2 Then
      val := SignExtend(val, 2);
    A[dst_reg] := val;
  End Else Begin
    WriteEA(dst_mode, dst_reg, val, size);
    SetFlagsNZVC(val, size, False, False);
  End;
End;

{ ========================================================================== }
{  Misc 0100                                                                  }
{ ========================================================================== }

Function Exec0100(opcode: Word): Boolean;
Var
  reg, ea_mode, ea_reg: Integer;
  sz_bits, size: Integer;
  val, result_: LongInt;
  addr: LongInt;
  msk: LongInt;
  x: Integer;
  carry: Boolean;
  v: LongInt;
  disp: LongInt;
  direction, sz_bit: Integer;
  regmask: Word;
Begin
  Exec0100 := True;

  { LEA: 0100 rrr 111 EEE EEE }
  If (opcode And $F1C0) = $41C0 Then Begin
    reg := (opcode Shr 9) And 7;
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    A[reg] := CalcEAAddr(ea_mode, ea_reg);
    Exit;
  End;

  { SWAP: 0100 1000 0100 0 rrr }
  If (opcode And $FFF8) = $4840 Then Begin
    reg := opcode And 7;
    v := D[reg];
    D[reg] := ((v And $FFFF) Shl 16) Or (Shr32(v, 16) And $FFFF);
    SetFlagsNZVC(D[reg], 4, False, False);
    Exit;
  End;

  { PEA: 0100 1000 01 EEE EEE }
  If (opcode And $FFC0) = $4840 Then Begin
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    addr := CalcEAAddr(ea_mode, ea_reg);
    A[7] := A[7] - 4;
    Write32(A[7], addr);
    Exit;
  End;

  { NBCD: 0100 1000 00 EEE EEE }
  If (opcode And $FFC0) = $4800 Then Begin
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    val := ReadEA(ea_mode, ea_reg, 1, addr);
    If SR And CCR_X <> 0 Then x := 1 Else x := 0;
    v := (0 - (val And $0F) - x) And $FF;
    If v > 9 Then
      v := (v - 6) And $FF;
    result_ := v;
    v := (0 - ((val Shr 4) And $0F)) And $FF;
    If result_ > $0F Then
      v := (v - 1) And $FF;
    If v > 9 Then
      v := (v - 6) And $FF;
    result_ := ((v And $0F) Shl 4) Or (result_ And $0F);
    carry := (val <> 0) Or (x <> 0);
    WriteEA(ea_mode, ea_reg, result_, 1);
    If result_ <> 0 Then
      SR := SR And (Not CCR_Z);
    If carry Then
      SR := SR Or (CCR_C Or CCR_X)
    Else
      SR := SR And (Not (CCR_C Or CCR_X));
    Exit;
  End;

  { NEGX: 0100 0000 ss EEE EEE (ss != 11) }
  If ((opcode And $FF00) = $4000) And (((opcode Shr 6) And 3) < 3) Then Begin
    sz_bits := (opcode Shr 6) And 3;
    size := OpSize(sz_bits);
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    If SR And CCR_X <> 0 Then x := 1 Else x := 0;
    msk := SizeMask(size);
    result_ := (0 - val - x) And msk;
    WriteEA(ea_mode, ea_reg, result_, size);
    carry := (val <> 0) Or (x <> 0);
    SetFlagsNZVC(result_, size, carry, False);
    If carry Then
      SR := SR Or CCR_X;
    If result_ <> 0 Then
      SR := SR And (Not CCR_Z);
    Exit;
  End;

  { MOVE from CCR: 0100 0010 11 EEE EEE }
  If (opcode And $FFC0) = $42C0 Then Begin
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    WriteEA(ea_mode, ea_reg, SR And $FF, 2);
    Exit;
  End;

  { CLR: 0100 0010 ss EEE EEE (ss != 11) }
  If ((opcode And $FF00) = $4200) And (((opcode Shr 6) And 3) < 3) Then Begin
    sz_bits := (opcode Shr 6) And 3;
    size := OpSize(sz_bits);
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    WriteEA(ea_mode, ea_reg, 0, size);
    SR := (SR And (Not (CCR_N Or CCR_V Or CCR_C))) Or CCR_Z;
    Exit;
  End;

  { NEG: 0100 0100 ss EEE EEE (ss != 11) }
  If ((opcode And $FF00) = $4400) And (((opcode Shr 6) And 3) < 3) Then Begin
    sz_bits := (opcode Shr 6) And 3;
    size := OpSize(sz_bits);
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    msk := SizeMask(size);
    result_ := (0 - ToSigned(val, size)) And msk;
    WriteEA(ea_mode, ea_reg, result_, size);
    SetFlagsNZVC(result_, size, result_ <> 0, False);
    Exit;
  End;

  { NOT: 0100 0110 ss EEE EEE (ss != 11) }
  If ((opcode And $FF00) = $4600) And (((opcode Shr 6) And 3) < 3) Then Begin
    sz_bits := (opcode Shr 6) And 3;
    size := OpSize(sz_bits);
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    msk := SizeMask(size);
    result_ := (Not val) And msk;
    WriteEA(ea_mode, ea_reg, result_, size);
    SetFlagsNZVC(result_, size, False, False);
    Exit;
  End;

  { TAS: 0100 1010 11 EEE EEE }
  If (opcode And $FFC0) = $4AC0 Then Begin
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    val := ReadEA(ea_mode, ea_reg, 1, addr);
    SetFlagsNZVC(val, 1, False, False);
    result_ := val Or $80;
    WriteEA(ea_mode, ea_reg, result_, 1);
    Exit;
  End;

  { TST: 0100 1010 ss EEE EEE (ss != 11) }
  If ((opcode And $FF00) = $4A00) And (((opcode Shr 6) And 3) < 3) Then Begin
    sz_bits := (opcode Shr 6) And 3;
    size := OpSize(sz_bits);
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    SetFlagsNZVC(val, size, False, False);
    Exit;
  End;

  { EXT.W: 0100 1000 1000 0 rrr }
  If (opcode And $FFF8) = $4880 Then Begin
    reg := opcode And 7;
    v := D[reg] And $FF;
    If v And $80 <> 0 Then
      v := v Or $FF00;
    D[reg] := (D[reg] And LongInt($FFFF0000)) Or (v And $FFFF);
    SetFlagsNZVC(v, 2, False, False);
    Exit;
  End;

  { EXT.L: 0100 1000 1100 0 rrr }
  If (opcode And $FFF8) = $48C0 Then Begin
    reg := opcode And 7;
    v := D[reg] And $FFFF;
    If v And $8000 <> 0 Then
      v := v Or LongInt($FFFF0000);
    D[reg] := v;
    SetFlagsNZVC(v, 4, False, False);
    Exit;
  End;

  { LINK: 0100 1110 0101 0 rrr }
  If (opcode And $FFF8) = $4E50 Then Begin
    reg := opcode And 7;
    disp := SignExtend(Fetch16, 2);
    A[7] := A[7] - 4;
    Write32(A[7], A[reg]);
    A[reg] := A[7];
    A[7] := A[7] + disp;
    Exit;
  End;

  { UNLK: 0100 1110 0101 1 rrr }
  If (opcode And $FFF8) = $4E58 Then Begin
    reg := opcode And 7;
    A[7] := A[reg];
    A[reg] := Read32(A[7]);
    A[7] := A[7] + 4;
    Exit;
  End;

  { JMP: 0100 1110 11 EEE EEE }
  If (opcode And $FFC0) = $4EC0 Then Begin
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    PC := CalcEAAddr(ea_mode, ea_reg);
    Exit;
  End;

  { JSR: 0100 1110 10 EEE EEE }
  If (opcode And $FFC0) = $4E80 Then Begin
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    addr := CalcEAAddr(ea_mode, ea_reg);
    A[7] := A[7] - 4;
    Write32(A[7], PC);
    PC := addr;
    Exit;
  End;

  { MOVEM: 0100 1x00 1s EEE EEE }
  If (opcode And $FB80) = $4880 Then Begin
    direction := (opcode Shr 10) And 1;
    sz_bit := (opcode Shr 6) And 1;
    If sz_bit <> 0 Then size := 4 Else size := 2;
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    regmask := Fetch16;
    ExecMovem(direction, size, ea_mode, ea_reg, regmask);
    Exit;
  End;

  { MOVE from SR: 0100 0000 11 EEE EEE }
  If (opcode And $FFC0) = $40C0 Then Begin
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    WriteEA(ea_mode, ea_reg, SR, 2);
    Exit;
  End;

  { MOVE to CCR: 0100 0100 11 EEE EEE }
  If (opcode And $FFC0) = $44C0 Then Begin
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    val := ReadEA(ea_mode, ea_reg, 2, addr);
    SR := (SR And $FF00) Or Word(val And $FF);
    Exit;
  End;

  { MOVE to SR: 0100 0110 11 EEE EEE }
  If (opcode And $FFC0) = $46C0 Then Begin
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    val := ReadEA(ea_mode, ea_reg, 2, addr);
    SR := Word(val And $FFFF);
    Exit;
  End;

  { CHK: 0100 rrr 110 EEE EEE }
  If (opcode And $F1C0) = $4180 Then Begin
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    val := ReadEA(ea_mode, ea_reg, 2, addr); { consume ext words }
    Exit;
  End;

  { RESET: 0100 1110 0111 0000 }
  If opcode = $4E70 Then
    Exit;

  { STOP: 0100 1110 0111 0010 }
  If opcode = $4E72 Then Begin
    SR := Fetch16;
    Halted := True;
    ExitCode_ := 0;
    Exit;
  End;

  { MOVE USP: 0100 1110 0110 x rrr }
  If (opcode And $FFF0) = $4E60 Then
    Exit;

  { Unimplemented }
  WriteLn('Erreur: Instruction 0100 non implementee: $', HexN(opcode, 4));
  Halted := True;
  ExitCode_ := 1;
  Exec0100 := False;
End;

{ ========================================================================== }
{  ADDQ/SUBQ/Scc/DBcc (top4=5)                                               }
{ ========================================================================== }

Function Exec0101(opcode: Word): Boolean;
Var
  sz_bits, size, cc: Integer;
  data3: Integer;
  is_sub: Boolean;
  ea_mode, ea_reg: Integer;
  val, result_: LongInt;
  msk: LongInt;
  disp: LongInt;
  dn: LongInt;
  addr: LongInt;
Begin
  Exec0101 := True;
  sz_bits := (opcode Shr 6) And 3;

  { Scc / DBcc: sz_bits = 3 }
  If sz_bits = 3 Then Begin
    cc := (opcode Shr 8) And $F;
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    If ea_mode = 1 Then Begin { DBcc }
      disp := SignExtend(Fetch16, 2);
      If Not TestCC(cc) Then Begin
        dn := (D[ea_reg] And $FFFF) - 1;
        D[ea_reg] := (D[ea_reg] And LongInt($FFFF0000)) Or (dn And $FFFF);
        If (dn And $FFFF) <> $FFFF Then
          PC := PC - 2 + disp;
      End;
    End Else Begin { Scc }
      If TestCC(cc) Then
        WriteEA(ea_mode, ea_reg, $FF, 1)
      Else
        WriteEA(ea_mode, ea_reg, $00, 1);
    End;
    Exit;
  End;

  size := OpSize(sz_bits);
  data3 := (opcode Shr 9) And 7;
  If data3 = 0 Then data3 := 8;
  is_sub := ((opcode Shr 8) And 1) <> 0;
  ea_mode := (opcode Shr 3) And 7;
  ea_reg  := opcode And 7;

  If ea_mode = 1 Then Begin { ADDQ/SUBQ to An }
    If is_sub Then
      A[ea_reg] := A[ea_reg] - data3
    Else
      A[ea_reg] := A[ea_reg] + data3;
    Exit;
  End;

  val := ReadEA(ea_mode, ea_reg, size, addr);
  msk := SizeMask(size);
  If is_sub Then
    result_ := (val - data3) And msk
  Else
    result_ := (val + data3) And msk;
  WriteEA(ea_mode, ea_reg, result_, size);
  SetFlagsNZVC(result_, size, False, False);
End;

{ ========================================================================== }
{  Bcc/BRA/BSR (top4=6)                                                      }
{ ========================================================================== }

Function ExecBcc(opcode: Word): Boolean;
Var
  cc: Integer;
  disp8: Integer;
  disp: LongInt;
Begin
  ExecBcc := True;
  cc := (opcode Shr 8) And $F;
  disp8 := opcode And $FF;

  If disp8 = 0 Then
    disp := SignExtend(Fetch16, 2)
  Else If disp8 = $FF Then Begin
    WriteLn('Erreur: BCC long displacement non supporte');
    Halted := True;
    ExitCode_ := 1;
    ExecBcc := False;
    Exit;
  End Else
    disp := SignExtend(disp8, 1);

  If cc = 1 Then Begin { BSR }
    A[7] := A[7] - 4;
    Write32(A[7], PC);
    If disp8 = 0 Then
      PC := PC - 2 + disp
    Else
      PC := PC + disp;
    Exit;
  End;

  If TestCC(cc) Then Begin
    If disp8 = 0 Then
      PC := PC - 2 + disp
    Else
      PC := PC + disp;
  End;
End;

{ ========================================================================== }
{  OR/DIV/SBCD (top4=8)                                                       }
{ ========================================================================== }

Function Exec1000(opcode: Word): Boolean;
Var
  reg, opmode, ea_mode, ea_reg: Integer;
  val, result_: LongInt;
  addr: LongInt;
  msk: LongInt;
  size: Integer;
  dividend_u: LongInt;
  quotient_u, remainder_u: LongInt;
  dividend_s, divisor_s: LongInt;
  quotient_s, remainder_s: LongInt;
Begin
  Exec1000 := True;
  reg := (opcode Shr 9) And 7;
  opmode := (opcode Shr 6) And 7;
  ea_mode := (opcode Shr 3) And 7;
  ea_reg  := opcode And 7;

  { SBCD: simplified }
  If (opcode And $F1F0) = $8100 Then
    Exit;

  { DIVU: opmode=3 }
  If opmode = 3 Then Begin
    val := ReadEA(ea_mode, ea_reg, 2, addr) And $FFFF;
    If val = 0 Then Begin
      WriteLn('Erreur: Division par zero (DIVU)');
      Halted := True;
      ExitCode_ := 1;
      Exec1000 := False;
      Exit;
    End;
    { Unsigned division: D[reg] is treated as unsigned 32-bit }
    { Use careful unsigned division with LongInt }
    dividend_u := D[reg];
    { For unsigned 32-bit div by 16-bit, handle sign bit }
    If dividend_u >= 0 Then Begin
      quotient_u := dividend_u Div val;
      remainder_u := dividend_u Mod val;
    End Else Begin
      { dividend_u is negative as LongInt but represents large unsigned }
      { Use: (dividend_u + 2^32) div val }
      { = (dividend_u div val) + correction }
      { Easier: split into two halves }
      quotient_u := (Shr32(dividend_u, 1) Div val) * 2;
      remainder_u := dividend_u - quotient_u * val;
      If remainder_u < 0 Then Begin
        remainder_u := remainder_u + val;
        Dec(quotient_u);
      End;
      While remainder_u >= val Do Begin
        remainder_u := remainder_u - val;
        Inc(quotient_u);
      End;
    End;
    If quotient_u > $FFFF Then
      SR := SR Or CCR_V
    Else Begin
      D[reg] := ((remainder_u And $FFFF) Shl 16) Or (quotient_u And $FFFF);
      SetFlagsNZVC(quotient_u, 2, False, False);
    End;
    Exit;
  End;

  { DIVS: opmode=7 }
  If opmode = 7 Then Begin
    val := ReadEA(ea_mode, ea_reg, 2, addr);
    divisor_s := ToSigned(val, 2);
    If divisor_s = 0 Then Begin
      WriteLn('Erreur: Division par zero (DIVS)');
      Halted := True;
      ExitCode_ := 1;
      Exec1000 := False;
      Exit;
    End;
    dividend_s := ToSigned(D[reg], 4);
    quotient_s := dividend_s Div divisor_s;
    { Pascal truncates toward zero, which is what we want }
    remainder_s := dividend_s - quotient_s * divisor_s;
    If (quotient_s < -32768) Or (quotient_s > 32767) Then
      SR := SR Or CCR_V
    Else Begin
      D[reg] := ((remainder_s And $FFFF) Shl 16) Or (quotient_s And $FFFF);
      SetFlagsNZVC(quotient_s And $FFFF, 2, False, False);
    End;
    Exit;
  End;

  { OR <ea>,Dn (opmode 0,1,2) }
  If opmode In [0, 1, 2] Then Begin
    size := OpSize(opmode);
    val := ReadEA(ea_mode, ea_reg, size, addr);
    msk := SizeMask(size);
    result_ := (GetD(reg, size) Or val) And msk;
    SetD(reg, result_, size);
    SetFlagsNZVC(result_, size, False, False);
    Exit;
  End;

  { OR Dn,<ea> (opmode 4,5,6) }
  If opmode In [4, 5, 6] Then Begin
    size := OpSize(opmode - 4);
    val := ReadEA(ea_mode, ea_reg, size, addr);
    msk := SizeMask(size);
    result_ := (GetD(reg, size) Or val) And msk;
    WriteEA(ea_mode, ea_reg, result_, size);
    SetFlagsNZVC(result_, size, False, False);
    Exit;
  End;

  WriteLn('Erreur: OR/DIV non implemente: $', HexN(opcode, 4));
  Halted := True;
  ExitCode_ := 1;
  Exec1000 := False;
End;

{ ========================================================================== }
{  ADD/SUB (top4=9/D)                                                         }
{ ========================================================================== }

Function ExecAddSub(opcode: Word; is_add: Boolean): Boolean;
Var
  reg, opmode, ea_mode, ea_reg: Integer;
  size: Integer;
  val, dn, result_: LongInt;
  msk: LongInt;
  x: Integer;
  rm: Integer;
  src_val, dst_val: LongInt;
  dec_: Integer;
  addr: LongInt;
Begin
  ExecAddSub := True;
  reg := (opcode Shr 9) And 7;
  opmode := (opcode Shr 6) And 7;
  ea_mode := (opcode Shr 3) And 7;
  ea_reg  := opcode And 7;

  { ADDA/SUBA: opmode 3 (word) or 7 (long) }
  If (opmode = 3) Or (opmode = 7) Then Begin
    If opmode = 3 Then size := 2 Else size := 4;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    If size = 2 Then
      val := SignExtend(val, 2);
    If is_add Then
      A[reg] := A[reg] + val
    Else
      A[reg] := A[reg] - val;
    Exit;
  End;

  { ADD/SUB <ea>,Dn (opmode 0,1,2) }
  If opmode In [0, 1, 2] Then Begin
    size := OpSize(opmode);
    val := ReadEA(ea_mode, ea_reg, size, addr);
    dn := GetD(reg, size);
    msk := SizeMask(size);
    If is_add Then
      result_ := (dn + val) And msk
    Else
      result_ := (dn - val) And msk;
    SetD(reg, result_, size);
    SetFlagsNZVC(result_, size, False, False);
    Exit;
  End;

  { ADDX/SUBX: opmode 4,5,6 with bits 5-4=00 }
  If (opmode In [4, 5, 6]) And ((opcode And $0030) = $0000) Then Begin
    size := OpSize(opmode - 4);
    msk := SizeMask(size);
    rm := (opcode Shr 3) And 1;
    If SR And CCR_X <> 0 Then x := 1 Else x := 0;
    If rm = 0 Then Begin
      src_val := GetD(ea_reg, size);
      dst_val := GetD(reg, size);
      If is_add Then
        result_ := (dst_val + src_val + x) And msk
      Else
        result_ := (dst_val - src_val - x) And msk;
      SetD(reg, result_, size);
    End Else Begin
      dec_ := size;
      If (ea_reg = 7) And (size = 1) Then dec_ := 2;
      A[ea_reg] := A[ea_reg] - dec_;
      dec_ := size;
      If (reg = 7) And (size = 1) Then dec_ := 2;
      A[reg] := A[reg] - dec_;
      src_val := ReadMem(A[ea_reg], size);
      dst_val := ReadMem(A[reg], size);
      If is_add Then
        result_ := (dst_val + src_val + x) And msk
      Else
        result_ := (dst_val - src_val - x) And msk;
      WriteMem(A[reg], result_, size);
    End;
    SetFlagsNZVC(result_, size, False, False);
    If result_ <> 0 Then
      SR := SR And (Not CCR_Z);
    Exit;
  End;

  { ADD/SUB Dn,<ea> (opmode 4,5,6) }
  If opmode In [4, 5, 6] Then Begin
    size := OpSize(opmode - 4);
    val := ReadEA(ea_mode, ea_reg, size, addr);
    dn := GetD(reg, size);
    msk := SizeMask(size);
    If is_add Then
      result_ := (val + dn) And msk
    Else
      result_ := (val - dn) And msk;
    WriteEA(ea_mode, ea_reg, result_, size);
    SetFlagsNZVC(result_, size, False, False);
    Exit;
  End;

  WriteLn('Erreur: ADD/SUB non implemente: opmode=', opmode);
  Halted := True;
  ExitCode_ := 1;
  ExecAddSub := False;
End;

{ ========================================================================== }
{  CMP/EOR (top4=$B)                                                          }
{ ========================================================================== }

Function Exec1011(opcode: Word): Boolean;
Var
  reg, opmode, ea_mode, ea_reg: Integer;
  size: Integer;
  val, dn, result_: LongInt;
  msk: LongInt;
  addr: LongInt;
Begin
  Exec1011 := True;
  reg := (opcode Shr 9) And 7;
  opmode := (opcode Shr 6) And 7;
  ea_mode := (opcode Shr 3) And 7;
  ea_reg  := opcode And 7;

  { CMPA: opmode 3 (word) or 7 (long) }
  If (opmode = 3) Or (opmode = 7) Then Begin
    If opmode = 3 Then size := 2 Else size := 4;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    If size = 2 Then
      val := SignExtend(val, 2);
    result_ := A[reg] - val;
    SetFlagsNZVC(result_, 4, False, False);
    Exit;
  End;

  { CMP: opmode 0,1,2 }
  If opmode In [0, 1, 2] Then Begin
    size := OpSize(opmode);
    val := ReadEA(ea_mode, ea_reg, size, addr);
    dn := GetD(reg, size);
    msk := SizeMask(size);
    result_ := (dn - val) And msk;
    SetFlagsNZVC(result_, size, False, False);
    Exit;
  End;

  { EOR: opmode 4,5,6 }
  If opmode In [4, 5, 6] Then Begin
    size := OpSize(opmode - 4);
    val := ReadEA(ea_mode, ea_reg, size, addr);
    dn := GetD(reg, size);
    msk := SizeMask(size);
    result_ := (dn Xor val) And msk;
    WriteEA(ea_mode, ea_reg, result_, size);
    SetFlagsNZVC(result_, size, False, False);
    Exit;
  End;

  WriteLn('Erreur: CMP/EOR non implemente: opmode=', opmode);
  Halted := True;
  ExitCode_ := 1;
  Exec1011 := False;
End;

{ ========================================================================== }
{  AND/MUL/ABCD/EXG (top4=$C)                                                }
{ ========================================================================== }

Function Exec1100(opcode: Word): Boolean;
Var
  reg, opmode, ea_mode, ea_reg: Integer;
  size: Integer;
  val, result_: LongInt;
  msk: LongInt;
  exg_mode: Integer;
  tmp: LongInt;
  a_s, b_s: LongInt;
  addr: LongInt;
Begin
  Exec1100 := True;
  reg := (opcode Shr 9) And 7;
  opmode := (opcode Shr 6) And 7;
  ea_mode := (opcode Shr 3) And 7;
  ea_reg  := opcode And 7;

  { EXG: 1100 xxx 1 ooooo yyy }
  If (opcode And $F130) = $C100 Then Begin
    exg_mode := (opcode Shr 3) And $1F;
    Case exg_mode Of
      $08: Begin { Dx,Dy }
             tmp := D[reg];
             D[reg] := D[ea_reg];
             D[ea_reg] := tmp;
           End;
      $09: Begin { Ax,Ay }
             tmp := A[reg];
             A[reg] := A[ea_reg];
             A[ea_reg] := tmp;
           End;
      $11: Begin { Dx,Ay }
             tmp := D[reg];
             D[reg] := A[ea_reg];
             A[ea_reg] := tmp;
           End;
    End;
    Exit;
  End;

  { ABCD: simplified }
  If (opcode And $F1F0) = $C100 Then
    Exit;

  { MULU: opmode=3 }
  If opmode = 3 Then Begin
    val := ReadEA(ea_mode, ea_reg, 2, addr) And $FFFF;
    result_ := (D[reg] And $FFFF) * val;
    D[reg] := result_;
    SetFlagsNZVC(result_, 4, False, False);
    Exit;
  End;

  { MULS: opmode=7 }
  If opmode = 7 Then Begin
    val := ReadEA(ea_mode, ea_reg, 2, addr);
    a_s := ToSigned(D[reg] And $FFFF, 2);
    b_s := ToSigned(val And $FFFF, 2);
    result_ := a_s * b_s;
    D[reg] := result_;
    SetFlagsNZVC(result_, 4, False, False);
    Exit;
  End;

  { AND <ea>,Dn (opmode 0,1,2) }
  If opmode In [0, 1, 2] Then Begin
    size := OpSize(opmode);
    val := ReadEA(ea_mode, ea_reg, size, addr);
    msk := SizeMask(size);
    result_ := (GetD(reg, size) And val) And msk;
    SetD(reg, result_, size);
    SetFlagsNZVC(result_, size, False, False);
    Exit;
  End;

  { AND Dn,<ea> (opmode 4,5,6) }
  If opmode In [4, 5, 6] Then Begin
    size := OpSize(opmode - 4);
    val := ReadEA(ea_mode, ea_reg, size, addr);
    msk := SizeMask(size);
    result_ := (GetD(reg, size) And val) And msk;
    WriteEA(ea_mode, ea_reg, result_, size);
    SetFlagsNZVC(result_, size, False, False);
    Exit;
  End;

  WriteLn('Erreur: AND/MUL non implemente: $', HexN(opcode, 4));
  Halted := True;
  ExitCode_ := 1;
  Exec1100 := False;
End;

{ ========================================================================== }
{  Shift/Rotate (top4=$E)                                                     }
{ ========================================================================== }

Function ExecShift(opcode: Word): Boolean;
Var
  direction, stype: Integer;
  ea_mode, ea_reg: Integer;
  val: LongInt;
  carry_bit: Boolean;
  result_: LongInt;
  x_bit: Integer;
  count_reg_flag: Boolean;
  sz_bits, size, reg, creg: Integer;
  count: Integer;
  msk, sgn: LongInt;
  c: Integer;
  addr: LongInt;
  i: Integer;
Begin
  ExecShift := True;

  { Memory shift (1 bit) }
  If ((opcode Shr 6) And 3) = 3 Then Begin
    direction := (opcode Shr 8) And 1; { 0=right, 1=left }
    stype := (opcode Shr 9) And 3;
    ea_mode := (opcode Shr 3) And 7;
    ea_reg  := opcode And 7;
    val := ReadEA(ea_mode, ea_reg, 2, addr);

    If direction = 0 Then Begin { Right }
      carry_bit := (val And 1) <> 0;
      Case stype Of
        0: result_ := (val Shr 1) Or (val And $8000); { ASR }
        1: result_ := val Shr 1;                       { LSR }
        2: Begin { ROXR }
             If SR And CCR_X <> 0 Then x_bit := 1 Else x_bit := 0;
             result_ := (val Shr 1) Or (x_bit Shl 15);
           End;
        3: result_ := (val Shr 1) Or ((val And 1) Shl 15); { ROR }
      Else
        result_ := val;
      End;
    End Else Begin { Left }
      carry_bit := ((val Shr 15) And 1) <> 0;
      Case stype Of
        0: result_ := (val Shl 1) And $FFFF; { ASL }
        1: result_ := (val Shl 1) And $FFFF; { LSL }
        2: Begin { ROXL }
             If SR And CCR_X <> 0 Then x_bit := 1 Else x_bit := 0;
             result_ := ((val Shl 1) Or x_bit) And $FFFF;
           End;
        3: Begin { ROL }
             c := (val Shr 15) And 1;
             result_ := ((val Shl 1) Or c) And $FFFF;
           End;
      Else
        result_ := val;
      End;
    End;

    WriteEA(ea_mode, ea_reg, result_, 2);
    SetFlagsNZVC(result_, 2, carry_bit, False);
    Exit;
  End;

  { Register shift }
  count_reg_flag := ((opcode Shr 5) And 1) <> 0;
  direction := (opcode Shr 8) And 1;
  stype := (opcode Shr 3) And 3;
  sz_bits := (opcode Shr 6) And 3;
  size := OpSize(sz_bits);
  reg := opcode And 7;
  creg := (opcode Shr 9) And 7;

  If count_reg_flag Then
    count := D[creg] And 63
  Else Begin
    count := creg;
    If count = 0 Then count := 8;
  End;

  msk := SizeMask(size);
  sgn := SignBit(size);
  val := GetD(reg, size);
  carry_bit := False;

  For i := 1 To count Do Begin
    If direction = 0 Then Begin { Right }
      carry_bit := (val And 1) <> 0;
      Case stype Of
        0: val := (val Shr 1) Or (val And sgn); { ASR }
        1: val := val Shr 1;                     { LSR }
        2: Begin { ROXR }
             If SR And CCR_X <> 0 Then x_bit := 1 Else x_bit := 0;
             c := val And 1;
             val := (val Shr 1) Or (x_bit * sgn);
             carry_bit := c <> 0;
           End;
        3: Begin { ROR }
             c := val And 1;
             val := (val Shr 1) Or (c * sgn);
             carry_bit := c <> 0;
           End;
      End;
    End Else Begin { Left }
      carry_bit := (val And sgn) <> 0;
      Case stype Of
        0: val := (val Shl 1) And msk; { ASL }
        1: val := (val Shl 1) And msk; { LSL }
        2: Begin { ROXL }
             If SR And CCR_X <> 0 Then x_bit := 1 Else x_bit := 0;
             carry_bit := (val And sgn) <> 0;
             val := ((val Shl 1) Or x_bit) And msk;
           End;
        3: Begin { ROL }
             If (val And sgn) <> 0 Then c := 1 Else c := 0;
             val := ((val Shl 1) Or c) And msk;
             carry_bit := c <> 0;
           End;
      End;
    End;
  End;

  SetD(reg, val, size);
  SetFlagsNZVC(val, size, carry_bit, False);
End;

{ ========================================================================== }
{  Immediate / Bit manip (top4=0)                                             }
{ ========================================================================== }

Function Exec0000(opcode: Word): Boolean;
Var
  ea_mode, ea_reg: Integer;
  sz_bits, size: Integer;
  imm, val, result_: LongInt;
  msk: LongInt;
  bit_: LongInt;
  mask_bit: LongInt;
  dreg: Integer;
  addr: LongInt;
  hi, lo: Word;
Begin
  Exec0000 := True;
  ea_mode := (opcode Shr 3) And 7;
  ea_reg  := opcode And 7;

  { ORI: 0000 0000 ss EEE EEE }
  If (opcode And $FF00) = $0000 Then Begin
    sz_bits := (opcode Shr 6) And 3;
    { ORI to CCR }
    If opcode = $003C Then Begin
      imm := Fetch16 And $FF;
      SR := (SR And $FF00) Or ((SR Or imm) And $FF);
      Exit;
    End;
    { ORI to SR }
    If opcode = $007C Then Begin
      imm := Fetch16;
      SR := SR Or imm;
      Exit;
    End;
    size := OpSize(sz_bits);
    If size <= 2 Then Begin
      imm := Fetch16;
      If size = 1 Then imm := imm And $FF;
    End Else Begin
      hi := Fetch16; lo := Fetch16;
      imm := LongInt(hi) Shl 16 Or lo;
    End;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    msk := SizeMask(size);
    result_ := (val Or imm) And msk;
    WriteEA(ea_mode, ea_reg, result_, size);
    SetFlagsNZVC(result_, size, False, False);
    Exit;
  End;

  { ANDI: 0000 0010 ss EEE EEE }
  If (opcode And $FF00) = $0200 Then Begin
    sz_bits := (opcode Shr 6) And 3;
    If opcode = $023C Then Begin { ANDI to CCR }
      imm := Fetch16 And $FF;
      SR := (SR And $FF00) Or ((SR And imm) And $FF);
      Exit;
    End;
    If opcode = $027C Then Begin { ANDI to SR }
      imm := Fetch16;
      SR := SR And imm;
      Exit;
    End;
    size := OpSize(sz_bits);
    If size <= 2 Then Begin
      imm := Fetch16;
      If size = 1 Then imm := imm And $FF;
    End Else Begin
      hi := Fetch16; lo := Fetch16;
      imm := LongInt(hi) Shl 16 Or lo;
    End;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    msk := SizeMask(size);
    result_ := (val And imm) And msk;
    WriteEA(ea_mode, ea_reg, result_, size);
    SetFlagsNZVC(result_, size, False, False);
    Exit;
  End;

  { SUBI: 0000 0100 ss EEE EEE }
  If (opcode And $FF00) = $0400 Then Begin
    sz_bits := (opcode Shr 6) And 3;
    size := OpSize(sz_bits);
    If size <= 2 Then Begin
      imm := Fetch16;
      If size = 1 Then imm := imm And $FF;
    End Else Begin
      hi := Fetch16; lo := Fetch16;
      imm := LongInt(hi) Shl 16 Or lo;
    End;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    msk := SizeMask(size);
    result_ := (val - imm) And msk;
    WriteEA(ea_mode, ea_reg, result_, size);
    SetFlagsNZVC(result_, size, False, False);
    Exit;
  End;

  { ADDI: 0000 0110 ss EEE EEE }
  If (opcode And $FF00) = $0600 Then Begin
    sz_bits := (opcode Shr 6) And 3;
    size := OpSize(sz_bits);
    If size <= 2 Then Begin
      imm := Fetch16;
      If size = 1 Then imm := imm And $FF;
    End Else Begin
      hi := Fetch16; lo := Fetch16;
      imm := LongInt(hi) Shl 16 Or lo;
    End;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    msk := SizeMask(size);
    result_ := (val + imm) And msk;
    WriteEA(ea_mode, ea_reg, result_, size);
    SetFlagsNZVC(result_, size, False, False);
    Exit;
  End;

  { EORI: 0000 1010 ss EEE EEE }
  If (opcode And $FF00) = $0A00 Then Begin
    sz_bits := (opcode Shr 6) And 3;
    If opcode = $0A3C Then Begin { EORI to CCR }
      imm := Fetch16 And $FF;
      SR := (SR And $FF00) Or ((SR Xor imm) And $FF);
      Exit;
    End;
    size := OpSize(sz_bits);
    If size <= 2 Then Begin
      imm := Fetch16;
      If size = 1 Then imm := imm And $FF;
    End Else Begin
      hi := Fetch16; lo := Fetch16;
      imm := LongInt(hi) Shl 16 Or lo;
    End;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    msk := SizeMask(size);
    result_ := (val Xor imm) And msk;
    WriteEA(ea_mode, ea_reg, result_, size);
    SetFlagsNZVC(result_, size, False, False);
    Exit;
  End;

  { CMPI: 0000 1100 ss EEE EEE }
  If (opcode And $FF00) = $0C00 Then Begin
    sz_bits := (opcode Shr 6) And 3;
    size := OpSize(sz_bits);
    If size <= 2 Then Begin
      imm := Fetch16;
      If size = 1 Then imm := imm And $FF;
    End Else Begin
      hi := Fetch16; lo := Fetch16;
      imm := LongInt(hi) Shl 16 Or lo;
    End;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    msk := SizeMask(size);
    result_ := (val - imm) And msk;
    SetFlagsNZVC(result_, size, False, False);
    Exit;
  End;

  { BTST #imm: 0000 1000 00 EEE EEE }
  If (opcode And $FFC0) = $0800 Then Begin
    bit_ := Fetch16 And $FF;
    If ea_mode = 0 Then size := 4 Else size := 1;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    If ea_mode = 0 Then
      mask_bit := LongInt(1) Shl (bit_ And 31)
    Else
      mask_bit := LongInt(1) Shl (bit_ And 7);
    If val And mask_bit <> 0 Then
      SR := SR And (Not CCR_Z)
    Else
      SR := SR Or CCR_Z;
    Exit;
  End;

  { BCHG #imm: 0000 1000 01 EEE EEE }
  If (opcode And $FFC0) = $0840 Then Begin
    bit_ := Fetch16 And $FF;
    If ea_mode = 0 Then size := 4 Else size := 1;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    If ea_mode = 0 Then
      mask_bit := LongInt(1) Shl (bit_ And 31)
    Else
      mask_bit := LongInt(1) Shl (bit_ And 7);
    If val And mask_bit <> 0 Then
      SR := SR And (Not CCR_Z)
    Else
      SR := SR Or CCR_Z;
    result_ := val Xor mask_bit;
    WriteEA(ea_mode, ea_reg, result_, size);
    Exit;
  End;

  { BCLR #imm: 0000 1000 10 EEE EEE }
  If (opcode And $FFC0) = $0880 Then Begin
    bit_ := Fetch16 And $FF;
    If ea_mode = 0 Then size := 4 Else size := 1;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    If ea_mode = 0 Then
      mask_bit := LongInt(1) Shl (bit_ And 31)
    Else
      mask_bit := LongInt(1) Shl (bit_ And 7);
    If val And mask_bit <> 0 Then
      SR := SR And (Not CCR_Z)
    Else
      SR := SR Or CCR_Z;
    result_ := val And (Not mask_bit);
    WriteEA(ea_mode, ea_reg, result_, size);
    Exit;
  End;

  { BSET #imm: 0000 1000 11 EEE EEE }
  If (opcode And $FFC0) = $08C0 Then Begin
    bit_ := Fetch16 And $FF;
    If ea_mode = 0 Then size := 4 Else size := 1;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    If ea_mode = 0 Then
      mask_bit := LongInt(1) Shl (bit_ And 31)
    Else
      mask_bit := LongInt(1) Shl (bit_ And 7);
    If val And mask_bit <> 0 Then
      SR := SR And (Not CCR_Z)
    Else
      SR := SR Or CCR_Z;
    result_ := val Or mask_bit;
    WriteEA(ea_mode, ea_reg, result_, size);
    Exit;
  End;

  { BTST Dn: 0000 rrr 100 EEE EEE }
  If (opcode And $F1C0) = $0100 Then Begin
    dreg := (opcode Shr 9) And 7;
    bit_ := D[dreg];
    If ea_mode = 0 Then size := 4 Else size := 1;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    If ea_mode = 0 Then
      mask_bit := LongInt(1) Shl (bit_ And 31)
    Else
      mask_bit := LongInt(1) Shl (bit_ And 7);
    If val And mask_bit <> 0 Then
      SR := SR And (Not CCR_Z)
    Else
      SR := SR Or CCR_Z;
    Exit;
  End;

  { BCHG Dn: 0000 rrr 101 EEE EEE }
  If (opcode And $F1C0) = $0140 Then Begin
    dreg := (opcode Shr 9) And 7;
    bit_ := D[dreg];
    If ea_mode = 0 Then size := 4 Else size := 1;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    If ea_mode = 0 Then
      mask_bit := LongInt(1) Shl (bit_ And 31)
    Else
      mask_bit := LongInt(1) Shl (bit_ And 7);
    If val And mask_bit <> 0 Then
      SR := SR And (Not CCR_Z)
    Else
      SR := SR Or CCR_Z;
    result_ := val Xor mask_bit;
    WriteEA(ea_mode, ea_reg, result_, size);
    Exit;
  End;

  { BCLR Dn: 0000 rrr 110 EEE EEE }
  If (opcode And $F1C0) = $0180 Then Begin
    dreg := (opcode Shr 9) And 7;
    bit_ := D[dreg];
    If ea_mode = 0 Then size := 4 Else size := 1;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    If ea_mode = 0 Then
      mask_bit := LongInt(1) Shl (bit_ And 31)
    Else
      mask_bit := LongInt(1) Shl (bit_ And 7);
    If val And mask_bit <> 0 Then
      SR := SR And (Not CCR_Z)
    Else
      SR := SR Or CCR_Z;
    result_ := val And (Not mask_bit);
    WriteEA(ea_mode, ea_reg, result_, size);
    Exit;
  End;

  { BSET Dn: 0000 rrr 111 EEE EEE }
  If (opcode And $F1C0) = $01C0 Then Begin
    dreg := (opcode Shr 9) And 7;
    bit_ := D[dreg];
    If ea_mode = 0 Then size := 4 Else size := 1;
    val := ReadEA(ea_mode, ea_reg, size, addr);
    If ea_mode = 0 Then
      mask_bit := LongInt(1) Shl (bit_ And 31)
    Else
      mask_bit := LongInt(1) Shl (bit_ And 7);
    If val And mask_bit <> 0 Then
      SR := SR And (Not CCR_Z)
    Else
      SR := SR Or CCR_Z;
    result_ := val Or mask_bit;
    WriteEA(ea_mode, ea_reg, result_, size);
    Exit;
  End;

  { MOVEP: 0000 rrr 1xx 001 rrr }
  If (opcode And $F138) = $0108 Then Begin
    imm := Fetch16; { consume displacement }
    Exit;
  End;

  WriteLn('Erreur: Instruction 0000 non implementee: $', HexN(opcode, 4));
  Halted := True;
  ExitCode_ := 1;
  Exec0000 := False;
End;

{ ========================================================================== }
{  Execution d'une instruction                                                }
{ ========================================================================== }

Function Step: Boolean;
Var
  opcode: Word;
  top4: Integer;
  pc_before: LongInt;
  reg: Integer;
  data: LongInt;
  sr_low: Word;
Begin
  Step := True;
  If Halted Then Begin
    Step := False;
    Exit;
  End;
  Inc(Cycles);
  pc_before := PC;
  opcode := Fetch16;

  If Verbose Then
    WriteLn('  PC=$', HexN(pc_before, 6),
            ' op=$', HexN(opcode, 4),
            ' D0=$', HexN(D[0], 8),
            ' D1=$', HexN(D[1], 8),
            ' A7=$', HexN(A[7], 8),
            ' SR=$', HexN(SR, 4));

  top4 := (opcode Shr 12) And $F;

  { Special opcodes }
  If opcode = $4E71 Then Exit; { NOP }

  If opcode = $4E75 Then Begin { RTS }
    PC := Read32(A[7]);
    A[7] := A[7] + 4;
    Exit;
  End;

  If opcode = $4E76 Then Begin { TRAPV }
    If SR And CCR_V <> 0 Then Begin
      WriteLn('Erreur: TRAPV: overflow trap');
      Halted := True;
      ExitCode_ := 1;
      Step := False;
    End;
    Exit;
  End;

  If opcode = $4E77 Then Begin { RTR }
    sr_low := Read16(A[7]);
    A[7] := A[7] + 2;
    SR := (SR And $FF00) Or (sr_low And $FF);
    PC := Read32(A[7]);
    A[7] := A[7] + 4;
    Exit;
  End;

  If opcode = $4AFC Then Begin { ILLEGAL }
    WriteLn('Erreur: Instruction ILLEGAL executee');
    Halted := True;
    ExitCode_ := 1;
    Step := False;
    Exit;
  End;

  { TRAP #vector }
  If (opcode And $FFF0) = $4E40 Then Begin
    Step := DoTrap(opcode And $F);
    Exit;
  End;

  { MOVE (top4 = 1,2,3) }
  If (top4 = 1) Or (top4 = 2) Or (top4 = 3) Then Begin
    Step := ExecMove(opcode);
    Exit;
  End;

  { Misc 0100 }
  If top4 = 4 Then Begin
    Step := Exec0100(opcode);
    Exit;
  End;

  { ADDQ/SUBQ/Scc/DBcc }
  If top4 = 5 Then Begin
    Step := Exec0101(opcode);
    Exit;
  End;

  { Bcc/BRA/BSR }
  If top4 = 6 Then Begin
    Step := ExecBcc(opcode);
    Exit;
  End;

  { MOVEQ }
  If top4 = 7 Then Begin
    reg := (opcode Shr 9) And 7;
    data := opcode And $FF;
    If data And $80 <> 0 Then
      data := data Or LongInt($FFFFFF00);
    D[reg] := data;
    SetFlagsNZVC(D[reg], 4, False, False);
    Exit;
  End;

  { OR/DIV/SBCD }
  If top4 = 8 Then Begin
    Step := Exec1000(opcode);
    Exit;
  End;

  { SUB/SUBA }
  If top4 = 9 Then Begin
    Step := ExecAddSub(opcode, False);
    Exit;
  End;

  { A-line }
  If top4 = $A Then Begin
    WriteLn('Erreur: Instruction A-line non supportee: $', HexN(opcode, 4));
    Halted := True;
    ExitCode_ := 1;
    Step := False;
    Exit;
  End;

  { CMP/EOR }
  If top4 = $B Then Begin
    Step := Exec1011(opcode);
    Exit;
  End;

  { AND/MUL/ABCD/EXG }
  If top4 = $C Then Begin
    Step := Exec1100(opcode);
    Exit;
  End;

  { ADD/ADDA }
  If top4 = $D Then Begin
    Step := ExecAddSub(opcode, True);
    Exit;
  End;

  { Shift/Rotate }
  If top4 = $E Then Begin
    Step := ExecShift(opcode);
    Exit;
  End;

  { Bit manip / Immediate }
  If top4 = 0 Then Begin
    Step := Exec0000(opcode);
    Exit;
  End;

  WriteLn('Erreur: Instruction non implementee: $', HexN(opcode, 4),
          ' a PC=$', HexN(pc_before, 6));
  Halted := True;
  ExitCode_ := 1;
  Step := False;
End;

{ ========================================================================== }
{  Boucle d'execution                                                         }
{ ========================================================================== }

Function Run(max_cyc: LongInt): Integer;
Begin
  While (Not Halted) And (Cycles < max_cyc) Do Begin
    If Not Step Then
      Break;
  End;
  If (Not Halted) And (Cycles >= max_cyc) Then Begin
    WriteLn('Erreur: limite de ', max_cyc, ' cycles atteinte (boucle infinie?)');
    ExitCode_ := 1;
  End;
  Run := ExitCode_;
End;

{ ========================================================================== }
{  Chargement S-Record                                                        }
{ ========================================================================== }

Function HexVal(c: Char): Byte;
Begin
  Case c Of
    '0'..'9': HexVal := Ord(c) - Ord('0');
    'A'..'F': HexVal := Ord(c) - Ord('A') + 10;
    'a'..'f': HexVal := Ord(c) - Ord('a') + 10;
  Else
    HexVal := 0;
  End;
End;

Function HexByte(Var s: String; pos: Integer): Byte;
Begin
  HexByte := HexVal(s[pos]) Shl 4 Or HexVal(s[pos + 1]);
End;

Function HexWord(Var s: String; pos: Integer): Word;
Begin
  HexWord := Word(HexByte(s, pos)) Shl 8 Or HexByte(s, pos + 2);
End;

Function LoadSRecord(Const filename: String; Var entryAddr: LongInt): Boolean;
Var
  f: Text;
  line: String;
  count: Integer;
  addr: Word;
  i: Integer;
  b: Byte;
Begin
  LoadSRecord := False;
  entryAddr := -1;
  Assign(f, filename);
  Reset(f);
  If IOResult <> 0 Then Begin
    WriteLn('Erreur: impossible d''ouvrir ', filename);
    Exit;
  End;
  While Not Eof(f) Do Begin
    ReadLn(f, line);
    If Length(line) < 2 Then Continue;
    If (line[1] = 'S') And (line[2] = '0') Then
      Continue; { Header }
    If (line[1] = 'S') And (line[2] = '5') Then
      Continue; { Record count }
    If (line[1] = 'S') And (line[2] = '1') Then Begin
      count := HexByte(line, 3);
      addr := HexWord(line, 5);
      { data bytes: count - 3 (2 addr + 1 checksum) }
      For i := 0 To count - 4 Do Begin
        b := HexByte(line, 9 + i * 2);
        Mem[addr + i] := b;
      End;
    End;
    If (line[1] = 'S') And (line[2] = '9') Then Begin
      entryAddr := HexWord(line, 5);
      LoadSRecord := True;
    End;
  End;
  Close(f);
  If entryAddr >= 0 Then
    LoadSRecord := True;
End;

{ ========================================================================== }
{  Programme principal                                                        }
{ ========================================================================== }

Var
  i: Integer;
  filename: String;
  max_cyc: LongInt;
  entry: LongInt;
  code: Integer;
  arg: String;
  vc: Integer;
Begin
  { Initialisation }
  Verbose := False;
  max_cyc := MAX_CYCLES;
  filename := '';

  For i := 0 To 7 Do Begin
    D[i] := 0;
    A[i] := 0;
  End;
  PC := 0;
  SR := $2000;
  Halted := False;
  ExitCode_ := 0;
  Cycles := 0;
  A[7] := $0FF000;
  FillChar(Mem, SizeOf(Mem), 0);

  { Parse arguments }
  For i := 1 To ParamCount Do Begin
    arg := ParamStr(i);
    If (arg = '--verbose') Or (arg = '-v') Then
      Verbose := True
    Else If arg = '--max-cycles' Then Begin
      If i < ParamCount Then Begin
        Val(ParamStr(i + 1), max_cyc, vc);
      End;
    End Else If arg[1] <> '-' Then Begin
      If filename = '' Then
        filename := arg;
    End;
  End;

  If filename = '' Then Begin
    WriteLn('Usage: M68K_EMU fichier.S68 [--verbose] [--max-cycles N]');
    Halt(1);
  End;

  If Not LoadSRecord(filename, entry) Then Begin
    WriteLn('Erreur: pas d''adresse d''entree (S9) dans ', filename);
    Halt(1);
  End;

  PC := entry;
  If Verbose Then
    WriteLn('Chargement de ', filename, ', entree a $', HexN(entry, 6));

  code := Run(max_cyc);

  If Verbose Then Begin
    WriteLn('Cycles: ', Cycles);
    WriteLn('D0=$', HexN(D[0], 8), ' D1=$', HexN(D[1], 8),
            ' D2=$', HexN(D[2], 8), ' D3=$', HexN(D[3], 8));
    WriteLn('D4=$', HexN(D[4], 8), ' D5=$', HexN(D[5], 8),
            ' D6=$', HexN(D[6], 8), ' D7=$', HexN(D[7], 8));
    WriteLn('A0=$', HexN(A[0], 8), ' A1=$', HexN(A[1], 8),
            ' A2=$', HexN(A[2], 8), ' A3=$', HexN(A[3], 8));
    WriteLn('A4=$', HexN(A[4], 8), ' A5=$', HexN(A[5], 8),
            ' A6=$', HexN(A[6], 8), ' A7=$', HexN(A[7], 8));
  End;

  Halt(code);
End.
