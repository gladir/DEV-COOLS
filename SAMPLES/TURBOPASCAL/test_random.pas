{ test_random.pas - Test de Random et Randomize }
program TestRandom;
var
  N1, N2, N3: Integer;
  I: Integer;
  AllOk: Boolean;
begin
  { Random(max) doit retourner une valeur entre 0 et max-1 }
  AllOk := True;
  For I := 1 to 10 do
  begin
    N1 := Random(100);
    If (N1 < 0) Or (N1 >= 100) Then
      AllOk := False;
  end;
  If AllOk Then
    WriteLn('Random(100) range: OK')
  Else
    WriteLn('Random(100) range: FAIL');

  { Random sans argument }
  N1 := Random;
  N2 := Random;
  WriteLn('Random = ', N1);
  WriteLn('Random = ', N2);

  { Randomize change la graine }
  Randomize;
  N1 := Random(1000);
  N2 := Random(1000);
  WriteLn('Apres Randomize:');
  WriteLn('Random(1000) = ', N1);
  WriteLn('Random(1000) = ', N2);

  WriteLn('Done.');
end.
