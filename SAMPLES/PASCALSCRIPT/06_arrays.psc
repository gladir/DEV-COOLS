{ 06_arrays.psc - Tableaux statiques et dynamiques }

var
  I: Integer;
  Nombres: array[0..4] of Integer;
  Noms: array of String;

begin
  for I := 0 to 4 do
    Nombres[I] := I * I;

  for I := Low(Nombres) to High(Nombres) do
    WScript.Echo('Nombres[' + IntToStr(I) + '] = ' + IntToStr(Nombres[I]));

  SetLength(Noms, 3);
  Noms[0] := 'Ada';
  Noms[1] := 'Grace';
  Noms[2] := 'Linus';

  for I := 0 to Length(Noms) - 1 do
    WScript.Echo('Nom : ' + Noms[I]);
end.
