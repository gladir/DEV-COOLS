{ test_expressions.pas - Test des expressions primaires (TODO 10) }
program TestExpressions;

var
  S: String;
  N: Integer;
  B: Boolean;
  R: Real;
  Ch: Char;
  Arr: Array[1..5] of Integer;
  Arr0: Array[0..3] of Integer;

begin
  { Transtypage }
  N := Integer(3.14);
  N := Byte(300);
  N := Word(70000);
  Ch := Char(65);
  B := Boolean(1);
  S := String(42);

  { Constantes predefinies }
  N := MaxInt;
  N := MaxLongInt;
  R := Pi;

  { Fonctions standard : mathematiques }
  R := Abs(-5);
  R := Sqr(4);
  R := Sqrt(16.0);
  N := Round(3.7);
  N := Trunc(3.9);
  R := Sin(1.0);
  R := Cos(0.0);
  R := ArcTan(1.0);
  R := Ln(2.718);
  R := Exp(1.0);
  R := Frac(3.7);

  { Fonctions standard : ordinales }
  N := Ord('A');
  Ch := Chr(66);
  N := Pred(5);
  N := Succ(5);
  B := Odd(7);

  { Fonctions standard : chaines }
  S := 'Hello World';
  N := Length(S);
  Ch := UpCase('a');
  N := Pos('World', S);
  S := Copy(S, 1, 5);
  S := Concat('Hello', ' ', 'World');

  { Fonctions standard : bits }
  N := Lo(1000);
  N := Hi(1000);

  { Acces caractere de chaine (index base 1 -> base 0) }
  S := 'ABCDE';
  Ch := S[1];
  Ch := S[3];

  { Acces tableau (index base 1 -> base 0) }
  Arr[1] := 10;
  Arr[5] := 50;
  N := Arr[3];

  { Acces tableau base 0 (pas d ajustement) }
  Arr0[0] := 100;
  N := Arr0[0];

  { Inc / Dec }
  N := 10;
  Inc(N);
  Dec(N);
  Inc(N, 5);
  Dec(N, 3);

  { Random }
  N := Random(100);

  WriteLn('Test expressions done');
end.
