{ test_ordinal.pas - Test des fonctions ordinales }
program TestOrdinal;
var
  N: Integer;
  Ch: Char;
begin
  { Chr }
  Ch := Chr(65);
  WriteLn('Chr(65) = ', Ch);
  Ch := Chr(48);
  WriteLn('Chr(48) = ', Ch);

  { Succ }
  N := Succ(5);
  WriteLn('Succ(5) = ', N);
  N := Succ(0);
  WriteLn('Succ(0) = ', N);

  { Pred }
  N := Pred(5);
  WriteLn('Pred(5) = ', N);
  N := Pred(10);
  WriteLn('Pred(10) = ', N);

  { Lo / Hi }
  N := Lo(258);
  WriteLn('Lo(258) = ', N);
  N := Hi(258);
  WriteLn('Hi(258) = ', N);

  { Odd used in ordinal context }
  If Odd(3) Then
    WriteLn('Odd(3) = TRUE')
  Else
    WriteLn('Odd(3) = FALSE');

  If Odd(4) Then
    WriteLn('Odd(4) = TRUE')
  Else
    WriteLn('Odd(4) = FALSE');

  WriteLn('Done.');
end.
