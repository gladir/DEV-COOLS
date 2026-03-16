{ test_crt_cursor.pas - Test curseur et effacement CRT }
program TestCrtCursor;

uses Crt;

var
  X, Y: Byte;
begin
  ClrScr;

  { Test GotoXY et WhereX/WhereY }
  GotoXY(1, 1);
  X := WhereX;
  Y := WhereY;
  WriteLn('Pos after GotoXY(1,1): X=', X, ' Y=', Y);

  GotoXY(5, 3);
  X := WhereX;
  Y := WhereY;
  WriteLn('Pos after GotoXY(5,3): X=', X, ' Y=', Y);

  { Test ClrEol }
  GotoXY(1, 5);
  Write('ABCDEFGHIJ');
  GotoXY(4, 5);
  ClrEol;
  GotoXY(1, 6);
  WriteLn('ClrEol from col 4');

  { Test Window }
  Window(1, 1, 80, 25);
  GotoXY(1, 8);
  WriteLn('Window(1,1,80,25) OK');

  WriteLn('Done.');
end.
