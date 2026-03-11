{ test_intr.pas - Test emulation interruptions (TODO 23) }
program TestIntr;
uses Dos;
type
  Registers = record
    AX, BX, CX, DX, BP, SI, DI, DS, ES, Flags: Word;
  end;
var
  Regs: Registers;
  Ch: Char;
begin
  { Test INT 10h AH=0Fh : lire mode video via Intr }
  Regs.AX := $0F00;  { AH=0Fh }
  Intr($10, Regs);
  WriteLn('Mode video = ', Lo(Regs.AX));

  { Test INT 10h AH=02h : positionner curseur via Intr }
  Regs.AX := $0200;  { AH=02h }
  Regs.BX := 0;      { BH=page 0 }
  Regs.DX := $0500;  { DH=5 (ligne), DL=0 (colonne) }
  Intr($10, Regs);

  { Test INT 10h AH=03h : lire position curseur }
  Regs.AX := $0300;  { AH=03h }
  Regs.BX := 0;
  Intr($10, Regs);
  WriteLn('Curseur ligne=', Hi(Regs.DX), ' col=', Lo(Regs.DX));

  { Test INT 10h AH=0Eh : ecrire caractere teletype }
  Regs.AX := $0E41;  { AH=0Eh, AL='A' }
  Regs.BX := 0;
  Intr($10, Regs);
  WriteLn;

  { Test INT 21h AH=30h : version DOS via MsDos }
  Regs.AX := $3000;
  MsDos(Regs);
  WriteLn('DOS version = ', Lo(Regs.AX), '.', Hi(Regs.AX));

  { Test INT 33h AX=0000h : initialiser souris }
  Regs.AX := $0000;
  Intr($33, Regs);
  If Regs.AX = $FFFF Then
    WriteLn('Souris detectee, boutons = ', Regs.BX)
  Else
    WriteLn('Pas de souris');

  WriteLn('Test interruptions termine.');
end.
