{ 12_exceptions.psc - Gestion des exceptions }

var
  A, B, Resultat: Integer;

begin
  A := 10;
  B := 0;

  try
    Resultat := A div B;
    WScript.Echo('Resultat = ' + IntToStr(Resultat));
  except
    WScript.Echo('Une division par zero a ete interceptee.');
  end;

  WScript.Echo('Le script continue normalement.');
end.
