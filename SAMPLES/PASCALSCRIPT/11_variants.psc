{ 11_variants.psc - Variants, conversions et types }

var
  Valeur: Variant;

begin
  Valeur := 42;
  WScript.Echo('Entier : ' + VarToStr(Valeur));

  Valeur := 123.75;
  WScript.Echo('Reel   : ' + VarToStr(Valeur));

  Valeur := 'PascalScript';
  WScript.Echo('Chaine : ' + VarToStr(Valeur));

  Valeur := True;
  WScript.Echo('Booleen: ' + VarToStr(Valeur));
end.
