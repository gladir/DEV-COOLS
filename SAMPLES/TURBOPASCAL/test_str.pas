{ test_str.pas - Test de la procedure Str }
program TestStr;
var
  S: String;
  N: Integer;
begin
  { Str avec entier positif }
  N := 42;
  Str(N, S);
  WriteLn('Str(42) = ', S);

  { Str avec entier negatif }
  N := -7;
  Str(N, S);
  WriteLn('Str(-7) = ', S);

  { Str avec zero }
  N := 0;
  Str(N, S);
  WriteLn('Str(0) = ', S);

  { Str avec grand nombre }
  N := 12345;
  Str(N, S);
  WriteLn('Str(12345) = ', S);

  { Str avec expression }
  Str(100, S);
  WriteLn('Str(100) = ', S);

  { Str avec formatage }
  Str(42:6, S);
  WriteLn('Str(42:6) = [', S, ']');

  WriteLn('Done.');
end.
