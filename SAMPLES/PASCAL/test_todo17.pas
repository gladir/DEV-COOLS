Program test_todo17;
{ Test TODO 17 : blocs ASM avec traduction 8086 -> 80386 }
Var
  x : Integer;
  y : Integer;
  z : Integer;

Begin
  x := 10;
  y := 20;

  { Bloc ASM simple avec instructions 8086 }
  Asm
    MOV AX, 42;
    ADD AX, BX;
    SUB CX, DX;
    INC SI;
    DEC DI;
    PUSH AX;
    POP BX;
    XOR AX, AX;
    NOP;
    CLD;
    CBW;
    CWD;
    PUSHF;
    POPF;
  End;

  { Bloc ASM avec acces aux variables Pascal }
  Asm
    MOV AX, x;
    ADD AX, y;
    MOV z, AX;
  End;

  WriteLn('z = ', z);

  { Bloc ASM avec labels }
  Asm
    XOR AX, AX;
    CMP AX, 0;
    JE done;
    INC AX;
  done:
    NOP;
  End;

  { Bloc ASM avec LEA et XCHG }
  Asm
    MOV AX, 5;
    MOV BX, 10;
    XCHG AX, BX;
    LEA SI, [BX+4];
  End;

  WriteLn('Test ASM OK');
End.
