{ Test lexer with VAX Pascal features }
Program LexTest(Output);

Const
  MaxItems = 100;
  OctalVal = 377B;
  HexChar  = #XFF;
  OctChar  = #O15;

Type
  Color = (Red, Green, Blue);
  Range = 0..777B;

Var
  s : Varying [80] Of Char;
  n : Integer;
  r : Real;

Begin
  n := 42;
  r := 3.14E+2;
  s := 'Hello' || ' World';
  n := n ** 2;
  If (n > 0) AndIf (n < MaxItems) Then
    WriteLn(s);
  Case n Of
    1 : WriteLn('one');
    Others : WriteLn('other');
  End;
End.
