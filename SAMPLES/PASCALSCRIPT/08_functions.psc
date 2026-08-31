{ 08_functions.psc - Fonctions et recursion }

function Doubler(Valeur: Integer): Integer;
begin
  Result := Valeur * 2;
end;

function Factorielle(Valeur: Integer): Integer;
begin
  if Valeur <= 1 then
    Result := 1
  else
    Result := Valeur * Factorielle(Valeur - 1);
end;

begin
  WScript.Echo('Doubler(7) = ' + IntToStr(Doubler(7)));
  WScript.Echo('Factorielle(5) = ' + IntToStr(Factorielle(5)));
end.
